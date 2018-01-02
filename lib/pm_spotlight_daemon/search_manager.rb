require_relative 'modules/find_search'
require_relative 'messaging/sender'
require_relative '../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  class SearchManager
    include PmSpotlightShared::SharedConfiguration

    def initialize(search_pattern_reader, search_result_writer, search_paths, skip_paths: [], include_directories: true)
      @search_pattern_receiver = PmSpotlightDaemon::Messaging::Receiver.new(self, 'pattern', search_pattern_reader, PATTERN_SIZE_LIMIT)
      @search_result_sender = PmSpotlightDaemon::Messaging::Sender.new(self, 'search result', search_result_writer)

      @search = PmSpotlightDaemon::Modules::FindSearch.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)
    end

    def listen
      while true
        pattern = @search_pattern_receiver.read_last_message

        search_result = search_files(pattern)
        search_result = limit_result(search_result, LIMIT_SEARCH_RESULT_MESSAGE_SIZE)

        search_result_message = search_result.join("\n")

        @search_result_sender.send_message(search_result_message)
      end
    end

    private

    def search_files(pattern)
      return [] if pattern.strip.empty?

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
