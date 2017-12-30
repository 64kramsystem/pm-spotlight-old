require 'simple_scripting/argv'

require_relative '../../pm_spotlight_shared/shared_configuration'

module PmSpotlightClient
  module Utils
    class CommandlineDecoder
      include PmSpotlightShared::SharedConfiguration

      LONG_HELP = <<~STR
        Usage: spotlight_client.rb <operation>

        Valid operations: #{COMMAND_SHOW}, #{COMMAND_QUIT}
      STR

      def decode
        cmdline_options = SimpleScripting::Argv.decode('command', long_help: LONG_HELP) || exit
        cmdline_options.fetch(:command)
      end
    end
  end
end
