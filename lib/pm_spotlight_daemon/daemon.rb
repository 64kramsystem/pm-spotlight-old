#!/usr/bin/env ruby

require_relative 'utils/configuration_loader'
require_relative 'global_manager'

if $PROGRAM_NAME == __FILE__
  search_paths, skip_paths, include_directories = PmSpotlightDaemon::Utils::ConfigurationLoader.new.load

  manager = PmSpotlightDaemon::GlobalManager.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)

  manager.start
end
