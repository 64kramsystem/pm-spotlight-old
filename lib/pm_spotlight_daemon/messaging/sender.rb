module PmSpotlightDaemon
  module Messaging
    # See Receiver documentation.
    #
    class Sender
      TERMINATOR = "\x00"

      def initialize(writer)
        @writer = writer
      end

      def send_message(message)
        raise "Terminator (#{TERMINATOR.inspect}) is not accepted in messages" if message.include?(TERMINATOR)

        encoded_message = message + TERMINATOR

        @writer.write(encoded_message)
        @writer.flush
      end
    end
  end
end
