require_relative 'commands_listener'
require_relative 'search_manager'
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

      search_pattern_writer, search_result_reader = init_search_manager

      interface_thread = init_interface(commands_reader, search_pattern_writer, search_result_reader)

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

    def init_search_manager
      search_result_reader, search_result_writer = IO.pipe
      search_pattern_reader, search_pattern_writer = IO.pipe

      Thread.new do
        search_manager = PmSpotlightDaemon::SearchManager.new(
          search_pattern_reader, search_result_writer,
          @search_paths, skip_paths: @skip_paths, include_directories: @include_directories
        )

        search_manager.listen
      end

      [search_pattern_writer, search_result_reader]
    end

    def init_interface(commands_reader, search_pattern_writer, search_result_reader)
      Thread.new do
        PmSpotlightDaemon::Modules::TkInterface.new(commands_reader, search_pattern_writer, search_result_reader).start
      end
    end
  end
end
