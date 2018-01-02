require 'thread'

module PmSpotlightDaemon
  module Messaging
    # See Receiver documentation.
    #
    class Sender
      TERMINATOR = "\x00"

      def initialize(writer)
        @writer = writer
        @sending_semaphore = Mutex.new
      end

      # Thread-safe; will send only an message at a time.
      #
      def send_message(message)
        raise "Terminator (#{TERMINATOR.inspect}) is not accepted in messages" if message.include?(TERMINATOR)

        encoded_message = message + TERMINATOR

        @sending_semaphore.synchronize do
          @writer.write(encoded_message)
          @writer.flush
        end
      end
    end
  end
end
