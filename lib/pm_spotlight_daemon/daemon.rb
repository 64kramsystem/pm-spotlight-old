#!/usr/bin/env ruby

require_relative 'utils/configuration_loader'
require_relative 'modules/find_finder'
require_relative 'modules/tk_interface'

if $PROGRAM_NAME == __FILE__

  search_paths, skip_paths, include_directories = PmSpotlightDaemon::Utils::ConfigurationLoader.new.load

  finder = PmSpotlightDaemon::Modules::FindFinder.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)

  PmSpotlightDaemon::Modules::TkInterface.new(finder).show

end
