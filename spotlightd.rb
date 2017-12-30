#!/usr/bin/env ruby

require 'tk'
require 'shellwords'
require 'open3'

require_relative 'configuration_loader'
require_relative 'find_finder'
require_relative 'tk_interface'

if $PROGRAM_NAME == __FILE__

  search_paths, skip_paths, include_directories = ConfigurationLoader.new.load

  finder = FindFinder.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)

  TkInterface.new(finder).show

end
