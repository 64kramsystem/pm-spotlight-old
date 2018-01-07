require_relative '../messaging/consumer'
require_relative '../messaging/publisher'
require_relative '../../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  module Modules
    class BasicFilenamesSorter
      include PmSpotlightShared::SharedConfiguration

      def initialize(raw_search_result_reader, sorted_search_result_writer)
        @raw_search_result_consumer = PmSpotlightDaemon::Messaging::Consumer.new(
          self, 'raw search result', raw_search_result_reader, LIMIT_SEARCH_RESULT_MESSAGE_SIZE
        )
        @sorted_search_result_publisher = PmSpotlightDaemon::Messaging::Publisher.new(
          self, 'sorted search result', sorted_search_result_writer
        )
      end

      def listen
        while true
          raw_search_result_message = @raw_search_result_consumer.consume_last_message

          # This message contains both the pattern and the result; this sorter uses it.
          pattern, *raw_search_result_entries = raw_search_result_message.split("\n")

          sorted_search_result = sort_entries(raw_search_result_entries, pattern)

          sorted_search_result_message = sorted_search_result.join("\n")

          @sorted_search_result_publisher.publish_message(sorted_search_result_message)
        end
      end

      private

      def sort_entries(entries, pattern)
        exact_matches = []

        entries.delete_if do |entry|
          exact_match = File.basename(entry) == pattern

          if exact_match
            exact_matches << entry
            true
          end
        end

        entries.unshift(*exact_matches)
      end
    end
  end
end
