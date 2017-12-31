module PmSpotlightDaemon
  module Serialization
    # See SearchResultDeserializer documentation.
    #
    class SearchResultSerializer
      TERMINATOR = "\x00"

      def serialize(search_result)
        search_result.join("\n") + TERMINATOR
      end
    end
  end
end
