require_relative '../modules/pure_ruby_search'
require_relative '../messaging/consumer'
require_relative '../messaging/publisher'
require_relative '../../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  module Services
    class SearchService
      include PmSpotlightShared::SharedConfiguration

      INTERRUPT_SEARCH_THREAD_VARIABLE = 'search_interrupted'

      def initialize(search_pattern_reader, search_result_writer, search_paths, skip_paths: [], include_directories: true)
        @search_pattern_consumer = PmSpotlightDaemon::Messaging::Consumer.new(self, 'pattern', search_pattern_reader, PATTERN_SIZE_LIMIT)
        @search_result_publisher = PmSpotlightDaemon::Messaging::Publisher.new(self, 'search result', search_result_writer)

        @result_write_mutex = Mutex.new
        @active_thread = nil

        # The search instance is shared, but the only state it has is the interruption variable,
        # which is thread-local.
        @search = PmSpotlightDaemon::Modules::PureRubySearch.new(
          search_paths, skip_paths: skip_paths, include_directories: include_directories
        )
      end

      def listen
        while true
          pattern = @search_pattern_consumer.consume_last_message
          pattern = pattern.strip

          interrupt_active_search if existing_active_search?

          # This is actually a quite important optimization, since an empty pattern is sent
          # on the first GUI run, and when the user cleans the pattern.
          if pattern.empty?
            send_result(pattern, [])
          else
            @active_thread = schedule_search(pattern)
          end
        end
      end

      private

      def existing_active_search?
        !@active_thread.nil?
      end

      def process_pattern(raw_pattern)
        "*#{pattern.strip}*"
      end

      def interrupt_active_search
        @active_thread.thread_variable_set(INTERRUPT_SEARCH_THREAD_VARIABLE, true)

        # After interrupting it, it's not a service concern anymore.
        @active_thread = nil
      end

      def send_result(pattern, result)
        # This message contains both the pattern and the result; the pattern may be used by the
        # sorter.
        search_result_message = pattern + "\n" + result.join("\n")

        @result_write_mutex.synchronize do
          @search_result_publisher.publish_message(search_result_message)
        end
      end

      def schedule_search(pattern)
        Thread.new do
          result = @search.search("*#{pattern}*")

          # If the interruption happens here, for simplicity, we consider it too late.
          # Sending a result takes negligible time, anyway.
          if result
            result = limit_result(result, LIMIT_SEARCH_RESULT_MESSAGE_SIZE)

            send_result(pattern, result)
          end
        end
      end

      def limit_result(full_result, limit)
        # Naive and wasteful algorithm; this is not a bottleneck, but especially, it's an edge
        # case. It could be moved toe the search module(s) as optimization, but it's not worth.
        full_result.each_with_object([]) do |filename, limited_result|
          break limited_result if limited_result.join("\n").bytesize + filename.bytesize > limit

          limited_result << filename
        end
      end
    end
  end
end
