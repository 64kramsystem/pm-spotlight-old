module PmSpotlightDaemon
  module Messaging
    # A trivial serializer, used for de/serializing the messages containing the find results.
    #
    # It requires the messages not to contain null bytes (`\x00`), since they're used as message
    # terminator; this is acceptable since filenames don't contain it (it's illegal).
    #
    # On deserializing, if performs two functions:
    #
    # 1. if multiple messages are received, it releases only the last one;
    # 2. it buffers the incoming messages; if only part is received, it waits for the remainder
    #    before releasing it.
    #
    class Receiver
      TERMINATOR = "\x00"

      def initialize(reader, read_limit)
        @buffer = ""
        @reader = reader
        @read_limit = read_limit
      end

      def read_last_message_nonblock(&block)
        serialized_search_result = @reader.read_nonblock(@read_limit)

        @buffer << serialized_search_result

        if @buffer[-1] == TERMINATOR
          puts "Receiver: received a message terminator; current buffer size: #{@buffer.bytesize}"

          all_messages = @buffer.split(TERMINATOR, -1)
          last_message = all_messages[-2] # last message is the empty token "after" the ending terminator

          @buffer = ""

          yield last_message
        end
      rescue IO::WaitReadable, IO::EAGAINWaitReadable
        # nothing available at the moment.
      end
    end
  end
end
