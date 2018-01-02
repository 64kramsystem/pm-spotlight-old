module PmSpotlightDaemon
  module Messaging
    # See Receiver documentation.
    #
    class Sender
      TERMINATOR = "\x00"

      def send_message(message)
        raise "Terminator (#{TERMINATOR.inspect}) is not accepted in messages" if message.include?(TERMINATOR)

        message + TERMINATOR
      end
    end
  end
end
