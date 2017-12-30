require_relative 'modules/find_finder'
require_relative 'serialization/find_result_serializer'
require_relative '../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  class FindManager
    include PmSpotlightShared::SharedConfiguration

    def initialize(find_pattern_reader, find_result_writer, search_paths, skip_paths: [], include_directories: true)
      @find_pattern_reader = find_pattern_reader
      @find_result_writer = find_result_writer

      @finder = PmSpotlightDaemon::Modules::FindFinder.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)
    end

    def listen
      while true
        puts "FindManager: waiting for data from find_pattern_reader"

        pattern = blocking_pipe_read(@find_pattern_reader, PATTERN_SIZE_LIMIT)

        puts "FindManager: has read #{pattern.inspect} from find_pattern_reader"

        find_result = find_files_for_pattern(pattern)
        find_result = limit_result(find_result, LIMIT_FIND_RESULT_MESSAGE_SIZE)

        serialized_find_result = PmSpotlightDaemon::Serialization::FindResultSerializer.new.serialize(find_result)

        puts "FindManager: writing #{serialized_find_result.bytesize} bytes to find_result_writer"

        @find_result_writer.write(serialized_find_result)
        @find_result_writer.flush
      end
    end

    private

    def blocking_pipe_read(reader, read_buffer_size)
      reader.read_nonblock(read_buffer_size)
    rescue IO::WaitReadable, IO::EAGAINWaitReadable
      IO.select([@search_pattern_reader])
      retry
    end

    def find_files_for_pattern(pattern)
      return '' if pattern.strip.empty?

      @finder.find_files(pattern)
    end

    def limit_result(full_result, limit)
      # Naive and wasteful algorithm, but this is not a bottleneck.
      full_result.each_with_object([]) do |filename, limited_result|
        break limited_result if limited_result.join("\n").bytesize + filename.bytesize > limit

        limited_result << filename
      end
    end
  end
end
