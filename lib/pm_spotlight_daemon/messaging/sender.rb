module PmSpotlightDaemon
  module Messaging
    # See Receiver documentation.
    #
    class Sender
      TERMINATOR = "\x00"

      def serialize(search_result)
        search_result.join("\n") + TERMINATOR
      end
    end
  end
end
