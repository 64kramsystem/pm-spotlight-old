require 'shellwords'

module PmSpotlightDaemon
  module Modules
    # Search backed by GNU `find` executed in a subshell. It's faster than pure ruby, but it's not
    # always possible to terminate and clean forked processes (see InterruptibleJobScheduler in
    # the `openscripts` project).
    #
    class FindSearch
      # search_paths: an array composed of: String, or `{String => depth}` (for limiting depth)
      #
      def initialize(raw_search_paths, include_directories: false, skip_paths: [])
        @search_paths = aggregate_search_paths_by_depth(raw_search_paths)
        @include_directories = include_directories
        @skip_paths = skip_paths
      end

      def search(raw_pattern)
        entries = @search_paths.flat_map do |depth, search_paths|
          find_files_with_depth(raw_pattern, depth, search_paths)
        end

        entries.uniq
      end

      private

      def aggregate_search_paths_by_depth(raw_search_paths)
        aggregated_paths = Hash.new { |hash, key| hash[key] = [] }

        raw_search_paths.each do |search_paths_entry|
          if search_paths_entry.is_a?(Hash)
            aggregated_paths[search_paths_entry.values.first] << search_paths_entry.keys.first
          else
            aggregated_paths[nil] << search_paths_entry
          end
        end

        aggregated_paths
      end

      def find_files_with_depth(raw_pattern, depth, search_paths)
        search_paths_option = search_paths.map(&:shellescape).join(' ')
        pattern_option = "-iname " + "*#{raw_pattern}*".shellescape
        file_type_option = '-type f' unless @include_directories

        skip_paths_option = @skip_paths.to_a.map do |path|
          path_with_pattern = File.join(path, '*')
          ' -not -path ' + path_with_pattern.shellescape
        end.join(' ')

        depth_option = "-maxdepth #{depth}" if depth

        command = "find #{search_paths_option} #{depth_option} #{pattern_option} #{file_type_option} #{skip_paths_option}"

        `#{command}`.chomp.split("\n")
      end
    end
  end
end
