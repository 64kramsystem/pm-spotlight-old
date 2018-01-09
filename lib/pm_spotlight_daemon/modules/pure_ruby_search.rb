module PmSpotlightDaemon
  module Modules
    # Pure Ruby file search.
    #
    # Searches files like GNU `find`, around 3 times as slow (for my average use case), but without
    # the need to use subshells.
    #
    # Using pure Ruby is actually a requirement for being able to terminate the search on demand,
    # as it's not always possible to terminate and clean forked processes.
    #
    # The code has been profiled and optimized. For performance reasons, it is limited in its
    # functionality.
    #
    class PureRubySearch

      class InterruptSearch < StandardError; end

      STOP_SIGNAL = 'S'

      # paths:
      #   an array composed of: String, or `{String => maxdepth}`; `maxdepth` is in GNU `find`
      #   format - `1` will search the children, but not enter subdirectories.
      #   paths must be absolute.
      # include_directories:
      #   perform matching against the directories as well
      # skip_paths:
      #   absolute paths
      #
      def initialize(paths, include_directories: false, skip_paths: [])
        @paths = paths
        @include_directories = include_directories
        @skip_paths = skip_paths
      end

      # GNU `find`-style finder.
      #
      # Returns an array of string; if the search is interrupted, nil is returned.
      #
      # pattern:
      #   matches a file when is it found as substring of the basename; supports the `*` wildcard;
      #   case insensitive
      #
      def search(pattern, stop_signal_reader)
        # Mutable design in this case is a tradeoff with simpler code.
        result = []
        pattern_regex = Regexp.new(Regexp.escape(pattern).gsub('\*', '.*'))

        @paths.each do |path_entry|
          path, maxdepth = decode_path_entry(path_entry)

          # Very interesting. If we match directories, we need to do it in the the parent enumeration,
          # since we may not enter a given directory due to maxdepth, but for the root paths, there is
          # no parent enumeration - so we perform the match here (which, in a way, is the parent
          # enumeration).
          result << path if @include_directories && name_matches?(pattern_regex, File.basename(path))

          if !skip_path?(path)
            recursive_find(path, pattern_regex, result, stop_signal_reader, maxdepth: maxdepth)
          end
        end

        result
      rescue InterruptSearch
        nil
      end

      private

      # For the format, see #find comment.
      #
      def decode_path_entry(path_entry)
        if path_entry.is_a?(Hash)
          path_entry.to_a.first
        else
          path_entry
        end
      end

      def recursive_find(path, pattern_regex, result, stop_signal_reader, maxdepth:)
        Dir.foreach(path) do |file_basename|
          raise InterruptSearch if search_interrupted?(stop_signal_reader)

          next if special_file?(file_basename)

          # File.join takes ~11.2% of the running time; string interpolation around half.
          file_fullname = "#{path}/#{file_basename}"

          # This test is actually incredibly slow, taking 25% of the running time.
          # Looking at the MRI source code, there's nothing to do (without significant effort), since
          # the method is simply to test the file stat.
          # Interestingly, File.file? takes virtually zero time, very likely because the stats for the
          # file are in memory/cached.
          if File.directory?(file_fullname)
            # WATCH OUT! We use the maxdepth convention: it requires a maxdepth of 2 to enter
            # subdirectories.
            if maxdepth.nil? || maxdepth > 1
              child_maxdepth = maxdepth - 1 if maxdepth

              recursive_find(file_fullname, pattern_regex, result, stop_signal_reader, maxdepth: maxdepth)
            end
          end

          if name_matches?(pattern_regex, file_basename)
            result << file_fullname if File.file?(file_fullname) || @include_directories
          end
        end
      rescue Errno::EACCES
        # Ignore inaccessible files
      end

      def search_interrupted?(stop_signal_reader)
        stop_signal_reader.read_nonblock(1) == STOP_SIGNAL
      rescue IO::EAGAINWaitReadable
        false
      end

      def special_file?(file_basename)
        file_basename == '.' || file_basename == '..'
      end

      def skip_path?(file_fullname)
        @skip_paths.any? { |skip_path| file_fullname.start_with?(skip_path) }
      end

      def name_matches?(pattern_regex, file_basename)
        # File.fnmatch takes ~15% of the running time; regex matching ~5%.
        file_basename =~ pattern_regex
      end

      def will_exceed_depth?(node_depth, branch_maxdepth)
        node_depth + 1 > branch_maxdepth
      end
    end
  end
end
