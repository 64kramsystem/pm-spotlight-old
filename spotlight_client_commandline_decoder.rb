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
