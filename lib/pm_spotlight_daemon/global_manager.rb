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

      find_manager_thread, find_pattern_writer, find_result_reader = init_find_manager

      init_interface(find_pattern_writer, find_result_reader)

      find_manager_thread.join
    end

    private

    def init_find_manager
      find_result_reader, find_result_writer = IO.pipe
      find_pattern_reader, find_pattern_writer = IO.pipe

      find_manager_thread = Thread.new do
        find_manager = PmSpotlightDaemon::FindManager.new(
          find_pattern_reader, find_result_writer,
          @search_paths, skip_paths: @skip_paths, include_directories: @include_directories
        )

        find_manager.listen
      end

      [find_manager_thread, find_pattern_writer, find_result_reader]
    end

    def init_interface(find_pattern_writer, find_result_reader)
      Thread.new do
        PmSpotlightDaemon::Modules::TkInterface.new(find_pattern_writer, find_result_reader).show
      end
    end
  end
end