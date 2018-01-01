require 'fileutils'
require 'open3'

require_relative '../pm_spotlight_shared/shared_configuration'

module PmSpotlightDaemon
  class CommandsListener
    include PmSpotlightShared::SharedConfiguration

    def initialize(commands_writer)
      @commands_writer = commands_writer

      create_fifo_file
    end

    def listen
      while true
        puts "CommandsListener: waiting for command from the FIFO file..."

        command = IO.read(FIFO_FILENAME.shellescape).rstrip

        puts "CommandsListener: has read a #{command.inspect} command from the FIFO file; sending it to commands_writer"

        @commands_writer.write(command)
        @commands_writer.flush
      end
    end

    private

    def create_fifo_file
      if ! File.exists?(FIFO_FILENAME)
        config_dir = File.dirname(FIFO_FILENAME)

        FileUtils.mkdir_p(config_dir) if ! Dir.exists?(config_dir)

        checked_shell_execution "mkfifo #{FIFO_FILENAME.shellescape}"
      end
    end

    def checked_shell_execution(command)
      Open3.popen3(command) do |_, _, stderr, wait_thread|
        stderr_content = stderr.read
        raise stderr_content if ! wait_thread.value.success?
      end
    end
  end
end
