#!/usr/bin/env ruby

require 'simple_scripting/argv'

require_relative 'fifo_metadata'

class SpotlightClientCommandlineDecoder
  include FifoMetadata

  LONG_HELP = <<~STR
    Usage: spotlight_client.rb <operation>

    Valid operations: #{COMMAND_SHOW}, #{COMMAND_QUIT}
  STR

  def decode
    cmdline_options = SimpleScripting::Argv.decode('command', long_help: LONG_HELP) || exit
    cmdline_options.fetch(:command)
  end
end

class SpotlightClient
  include FifoMetadata

  def execute(command)
    check_file
    send_command(command)
  end

  private

  def check_file
    raise "FIFO file not found!" if ! File.exists?(FIFO_FILENAME)
  end

  def send_command(command)
    case command
    when COMMAND_SHOW, COMMAND_QUIT
      write_to_named_pipe(FIFO_FILENAME, command)
    else
      raise "Unexpected command: #{command.inspect}"
    end
  end

  def write_to_named_pipe(filename, content)
    # Non-blocking write. In case there is no reader on the other side of the pipe, at least this
    # process won't hang.
    # File::RDWR aliases `w+`; both don't make the nonblocking nature explicit.
    open(filename, File::RDWR) { |f| f.puts(content) }
  end
end

if $PROGRAM_NAME == __FILE__
  command = SpotlightClientCommandlineDecoder.new.decode
  SpotlightClient.new.execute(command)
end
