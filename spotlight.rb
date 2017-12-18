#!/usr/bin/env ruby

require 'tk'
require 'simple_scripting/argv'
require 'simple_scripting/configuration'
require 'shellwords'

class ConfigurationLoader
  def load
    configuration = SimpleScripting::Configuration.load

    cmdline_options = SimpleScripting::Argv.decode(
      ['-d', '--include-directories', 'Include directories in the search'],
      long_help: Spotlight::CMDLINE_LONG_HELP
    ) || exit

    search_paths = configuration.search_paths.full_paths.map(&method(:decode_path))

    skip_paths = configuration.skip_paths.full_paths
    include_directories = cmdline_options[:include_directories]

    [search_paths, skip_paths, include_directories]
  end

  private

  def decode_path(path)
    if path =~ /(.*?)\{(\d+)\}$/
      {$1 => $2.to_i}
    else
      path
    end
  end
end

class Finder
  # search_paths: an array composed of: String, or `{String => depth}` (for limiting depth)
  #
  def initialize(raw_search_paths, include_directories: false, skip_paths: [])
    @search_paths = aggregate_search_paths_by_depth(raw_search_paths)
    @include_directories = include_directories
    @skip_paths = skip_paths
  end

  def find_files(raw_pattern)
    entries = @search_paths.flat_map do |depth, search_paths|
      find_files_with_depth(raw_pattern, depth, search_paths)
    end

    entries.uniq!

    sort_entries(entries, raw_pattern)
  end

  private

  def aggregate_search_paths_by_depth(raw_search_paths)
    aggregated_paths = Hash.new { |hash, key| hash[key] = [] }

    raw_search_paths.each do |search_paths_entry|
      if search_paths_entry.is_a?(Hash)
        aggregated_paths[search_paths_entry.values.first] << search_paths_entry.keys.first
      else
        aggregated_paths[nil] << search_paths_entry
      end
    end

    aggregated_paths
  end

  def find_files_with_depth(raw_pattern, depth, search_paths)
    search_paths_option = search_paths.map(&:shellescape).join(' ')
    pattern_option = "-iname " + "*#{raw_pattern}*".shellescape
    file_type_option = '-type f' unless @include_directories

    skip_paths_option = @skip_paths.to_a.map do |path|
      path_with_pattern = File.join(path, '*')
      ' -not -path ' + path_with_pattern.shellescape
    end.join(' ')

    depth_option = "-maxdepth #{depth}" if depth

    command = "find #{search_paths_option} #{depth_option} #{pattern_option} #{file_type_option} #{skip_paths_option}"

    `#{command}`.chomp.split("\n")
  end

  def sort_entries(entries, raw_pattern)
    exact_matches = []

    entries.delete_if do |entry|
      exact_match = File.basename(entry) == raw_pattern

      if exact_match
        exact_matches << entry
        true
      end
    end

    entries.unshift(*exact_matches)
  end
end

class Spotlight
  CMDLINE_LONG_HELP = <<~STR
    Poor man's spotlight. The executable used for opening the files is the default one as configurad in Ubuntu.

    Search/skip paths are defined in sav_scripts as 'search_paths' and 'skip_paths', with entries separated by ':'.
    Skip paths are optional.

    Paths including ':' are not supported.
  STR

  KEYCODE_ESC        = 9
  KEYCODE_ENTER      = 36
  KEYCODE_ARROW_DOWN = 116

  def initialize(finder)
    @finder = finder

    @entries_list_array  = []
    @entries_list_v      = TkVariable.new
    @pattern_input_v     = TkVariable.new

    instantiate_widgets
    bind_events
  end

  def show
    @pattern_input.focus

    Tk.mainloop
  end

  private

  #####################
  # GUI building
  #####################

  def instantiate_widgets
    pattern_input_v = @pattern_input_v
    entries_list_v = @entries_list_v

    @root = TkRoot.new { title "Poor man's Spotlight!" }
    TkGrid.columnconfigure(@root, 0, minsize: 400)

    content_frame = Tk::Tile::Frame.new(@root) { padding '10 10 10 10' }.grid(sticky: 'nsew')
    TkGrid.columnconfigure(@root, 0, weight: 1)
    TkGrid.rowconfigure(@root, 0, weight: 1)

    @pattern_input = Tk::Tile::Entry.new(content_frame) do
      textvariable pattern_input_v
    end.grid(column: 1, row: 1, sticky: 'nsew')

    @entries_list = TkListbox.new(content_frame) do
      listvariable entries_list_v
    end.grid(column: 1, row: 2, sticky: 'nsew')

    # Expand both widgets horizontally
    #
    TkGrid.columnconfigure(content_frame, 1, weight: 1)

    # Only the list expands vertically
    #
    TkGrid.rowconfigure(content_frame, 2, weight: 1)
  end

  def bind_events
    @root.bind('Key') do |event|
      close_gui if event.keycode == KEYCODE_ESC
    end

    @pattern_input.bind('Key') do |event|
      unless @entries_list_array.empty?
        if event.keycode == KEYCODE_ENTER
          open_file @entries_list_array[0]
        elsif event.keycode == KEYCODE_ARROW_DOWN
          # Don't do fancy things for now. Note that there is no direct support for moving
          # the cursor (which is different from setting the selection)
          #
          @entries_list.focus
        end
      end
    end

    @entries_list.bind('Key') do |event|
      if event.keycode == KEYCODE_ENTER
        open_file @entries_list_array[@entries_list.curselection[0]]
      end
    end

    # Binding a key event is not appropriate:
    #
    #  1. doesn't handle some events, e.g. mouse paste
    #  2. is raised before the key value is actually inserted
    #
    @pattern_input_v.trace('w') do
      # Empty list while (before) searching, in case it takes long
      #
      @entries_list_v.value = []

      @entries_list_array = find_files_for_pattern(@pattern_input_v.value)

      @entries_list_v.value = @entries_list_array.map { |entry| transform_entry_text(entry) }

      @entries_list.selection_set 0
    end
  end

  #####################
  # Other helpers
  #####################

  def close_gui
    @root.destroy
  end

  def open_file(filename)
    close_gui
    fork { `xdg-open #{filename.shellescape}` }
  end

  def find_files_for_pattern(pattern)
    if pattern == ''
      []
    else
      @finder.find_files(pattern)
    end
  end

  # Display the parent directory only, not the entire tree.
  #
  def transform_entry_text(text)
    # It's possible that a file is at the root level, thus the '||'
    #
    text[%r{[^/]*/[^/]*$}] || text
  end
end

if $PROGRAM_NAME == __FILE__

  search_paths, skip_paths, include_directories = ConfigurationLoader.new.load

  finder = Finder.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)

  Spotlight.new(finder).show

end
