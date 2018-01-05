require 'thread'

module PmSpotlightDaemon
  module Messaging
    # See Consumer documentation.
    #
    class Publisher
      TERMINATOR = "\x00"

      def initialize(service_instance, message_description, writer)
        @service_name = extract_service_name(service_instance)
        @message_description = message_description
        @writer = writer
        @sending_semaphore = Mutex.new
      end

      # Thread-safe; will send only an message at a time.
      #
      def publish_message(message)
        raise "Terminator (#{TERMINATOR.inspect}) is not accepted in messages" if message.include?(TERMINATOR)

        puts "#{@service_name}: sending #{@message_description} (#{message.bytesize} [+ #{TERMINATOR.bytesize}] bytes)"

        encoded_message = message + TERMINATOR

        @sending_semaphore.synchronize do
          @writer.write(encoded_message)
          @writer.flush
        end
      end

      private

      def extract_service_name(service_instance)
        service_instance.class.to_s.split('::').last
      end
    end
  end
end
