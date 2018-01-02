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

      def initialize(service_instance, message_description, reader, read_limit)
        @service_name = extract_service_name(service_instance)
        @message_description = message_description
        @buffer = ""
        @reader = reader
        @read_limit = read_limit
      end

      # Blocking read.
      #
      # Waits until a full message is in the buffer; if a full message and a partial message are in the
      # buffer, the full message is returned.
      #
      def read_last_message
        loop do
          puts "#{@service_name}: waiting for #{@message_description} data..."

          data_read = blocking_pipe_read(@reader, @read_limit)

          @buffer << data_read

          puts "#{@service_name}: read #{data_read.bytesize} #{@message_description} bytes..."

          if @buffer.include?(TERMINATOR)
            last_message, @buffer = extract_message_from_buffer(@buffer)
            return last_message
          end
        end
      end

      def read_last_message_nonblock(&block)
        @buffer << @reader.read_nonblock(@read_limit)

        if @buffer.include?(TERMINATOR)
          last_message, @buffer = extract_message_from_buffer(@buffer)
          yield last_message
        end
      rescue IO::WaitReadable, IO::EAGAINWaitReadable
        # nothing available at the moment.
      end

      private

      def extract_service_name(service_instance)
        service_instance.class.to_s.split('::').last
      end

      def blocking_pipe_read(reader, read_buffer_size)
        reader.read_nonblock(read_buffer_size)
      rescue IO::WaitReadable, IO::EAGAINWaitReadable
        IO.select([reader])
        retry
      end

      def extract_message_from_buffer(buffer)
        puts "#{@service_name}: found a full message in the #{@message_description} buffer..."

        buffer_messages = buffer.split(TERMINATOR, -1)

        # If TERMINATOR is the last character, `[-1]` is an empty string.
        new_buffer = buffer_messages[-1]
        last_message = buffer_messages[-2]

        [last_message, new_buffer]
      end
    end
  end
end
