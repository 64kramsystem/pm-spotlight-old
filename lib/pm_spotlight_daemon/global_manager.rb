require_relative 'commands_listener'
require_relative 'find_manager'
require_relative 'modules/tk_interface'

module PmSpotlightDaemon
  class GlobalManager
    def initialize(search_paths, skip_paths: [], include_directories: true)
      @search_paths = search_paths
      @skip_paths = skip_paths
      @include_directories = include_directories
    end

    def start
      Thread.abort_on_exception = true

      commands_reader = init_commands_listener

      find_pattern_writer, find_result_reader = init_find_manager

      interface_thread = init_interface(commands_reader, find_pattern_writer, find_result_reader)

      interface_thread.join
    end

    private

    def init_commands_listener
      commands_reader, commands_writer = IO.pipe

      Thread.new do
        commands_listener = PmSpotlightDaemon::CommandsListener.new(commands_writer)
        commands_listener.listen
      end

      commands_reader
    end

    def init_find_manager
      find_result_reader, find_result_writer = IO.pipe
      find_pattern_reader, find_pattern_writer = IO.pipe

      Thread.new do
        find_manager = PmSpotlightDaemon::FindManager.new(
          find_pattern_reader, find_result_writer,
          @search_paths, skip_paths: @skip_paths, include_directories: @include_directories
        )

        find_manager.listen
      end

      [find_pattern_writer, find_result_reader]
    end

    def init_interface(commands_reader, find_pattern_writer, find_result_reader)
      Thread.new do
        PmSpotlightDaemon::Modules::TkInterface.new(commands_reader, find_pattern_writer, find_result_reader).start
      end
    end
  end
end
