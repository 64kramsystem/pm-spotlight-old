require_relative 'modules/find_search'
require_relative 'messaging/sender'
require_relative '../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  class SearchManager
    include PmSpotlightShared::SharedConfiguration

    def initialize(search_pattern_reader, search_result_writer, search_paths, skip_paths: [], include_directories: true)
      @search_pattern_reader = search_pattern_reader
      @search_result_sender = PmSpotlightDaemon::Messaging::Sender.new(search_result_writer)

      @search = PmSpotlightDaemon::Modules::FindSearch.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)
    end

    def listen
      while true
        puts "SearchManager: waiting for data from search_pattern_reader"

        pattern = blocking_pipe_read(@search_pattern_reader, PATTERN_SIZE_LIMIT)

        puts "SearchManager: has read #{pattern.inspect} from search_pattern_reader"

        search_result = search_files(pattern)
        search_result = limit_result(search_result, LIMIT_SEARCH_RESULT_MESSAGE_SIZE)

        search_result_message = search_result.join("\n")

        puts "SearchManager: sending #{search_result_message.bytesize} bytes through search_result_sender"

        @search_result_sender.send_message(search_result_message)
      end
    end

    private

    def blocking_pipe_read(reader, read_buffer_size)
      reader.read_nonblock(read_buffer_size)
    rescue IO::WaitReadable, IO::EAGAINWaitReadable
      IO.select([@search_pattern_reader])
      retry
    end

    def search_files(pattern)
      return '' if pattern.strip.empty?

      @search.search_files(pattern)
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
