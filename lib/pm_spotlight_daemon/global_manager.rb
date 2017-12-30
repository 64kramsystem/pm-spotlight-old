require_relative 'modules/find_finder'
require_relative 'modules/tk_interface'

module PmSpotlightDaemon
  class GlobalManager
    def initialize(search_paths, skip_paths: [], include_directories: true)
      @search_paths = search_paths
      @skip_paths = skip_paths
      @include_directories = include_directories
    end

    def start
      finder = PmSpotlightDaemon::Modules::FindFinder.new(@search_paths, skip_paths: @skip_paths, include_directories: @include_directories)

      PmSpotlightDaemon::Modules::TkInterface.new(finder).show
    end
  end
end