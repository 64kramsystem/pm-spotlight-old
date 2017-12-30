module PmSpotlightDaemon
  module Serialization
    # See FindResultDeserializer documentation.
    #
    class FindResultSerializer
      TERMINATOR = "\x00"

      def serialize(find_result)
        find_result.join("\n") + TERMINATOR
      end
    end
  end
end
