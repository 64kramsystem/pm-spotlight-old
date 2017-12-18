#!/usr/bin/env ruby

require 'simple_scripting/argv'

require_relative 'spotlight_operation_constants'

class SpotlightClientCommandlineDecoder
  include SpotlightOperationConstants

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
  include SpotlightOperationConstants

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
      IO.write(FIFO_FILENAME, command)
    else
      raise "Unexpected command: #{command.inspect}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command = SpotlightClientCommandlineDecoder.new.decode
  SpotlightClient.new.execute(command)
end
