require_relative '../modules/find_search'
require_relative '../messaging/consumer'
require_relative '../messaging/publisher'
require_relative '../../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  module Services

    # Manages the search.
    #
    # The previous search result is cached, when a pattern is an extension of the previous, the
    # result can be extracted from the cache, rather than performing a new search.
    #
    # There are two conditions:
    #
    # 1. on the previous search, the result must not have been cut
    # 2. the SearchService filtering must match the Search module used
    #
    class SearchService
      include PmSpotlightShared::SharedConfiguration

      def initialize(search_pattern_reader, search_result_writer, search_paths, skip_paths: [], include_directories: true)
        @search_pattern_consumer = PmSpotlightDaemon::Messaging::Consumer.new(self, 'pattern', search_pattern_reader, PATTERN_SIZE_LIMIT)
        @search_result_publisher = PmSpotlightDaemon::Messaging::Publisher.new(self, 'search result', search_result_writer)

        @search = PmSpotlightDaemon::Modules::FindSearch.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)

        @last_search_pattern = nil
        @last_search_result = nil
      end

      def listen
        while true
          pattern = @search_pattern_consumer.consume_last_message

          if pattern.strip.empty?
            search_result = []
            limit_reached = true # prevent this result from being cached
          elsif can_use_previous_result?(pattern)
            search_result = extract_new_result_as_subset_of_previous(pattern)
            limit_reached = false
          else
            search_result = search_files(pattern)
            search_result, limit_reached = limit_result(search_result, LIMIT_SEARCH_RESULT_MESSAGE_SIZE)
          end

          update_cached_data(pattern, search_result, limit_reached)

          # This message contains both the pattern and the result; the pattern may be used by the
          # sorter.
          search_result_message = pattern + "\n" + search_result.join("\n")

          @search_result_publisher.publish_message(search_result_message)
        end
      end

      private

      def can_use_previous_result?(pattern)
        !pattern.empty? && @last_search_pattern && pattern.start_with?(@last_search_pattern)
      end

      def extract_new_result_as_subset_of_previous(pattern)
        @last_search_result.select do |filename|
          File.basename(filename).downcase.include?(pattern.downcase)
        end
      end

      def update_cached_data(pattern, search_result, limit_reached)
        # If the limit has been reached, a more specific pattern may include failes which were
        # after the cutoff.
        if limit_reached
          @last_search_pattern = nil
          @last_search_result = nil
        else
          @last_search_pattern = pattern
          @last_search_result = search_result
        end
      end

      def search_files(pattern)
        @search.search_files(pattern)
      end

      def limit_result(full_result, limit)
        # Naive and wasteful algorithm, but this is not a bottleneck.
        result = full_result.each_with_object([]) do |filename, limited_result|
          return [limited_result, true] if limited_result.join("\n").bytesize + filename.bytesize > limit

          limited_result << filename
        end

        [result, false]
      end
    end
  end
end
