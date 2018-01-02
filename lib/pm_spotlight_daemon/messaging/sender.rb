module PmSpotlightDaemon
  module Messaging
    # See Receiver documentation.
    #
    class Sender
      TERMINATOR = "\x00"

      def send_message(message)
        message + TERMINATOR
      end
    end
  end
end
