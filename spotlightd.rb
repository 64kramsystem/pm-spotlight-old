#!/usr/bin/env ruby

require 'tk'
require 'shellwords'
require 'open3'

require_relative 'configuration_loader'
require_relative 'find_finder'
require_relative 'fifo_metadata'

class Spotlight
  KEYCODE_ESC        = 9
  KEYCODE_ENTER      = 36
  KEYCODE_ARROW_DOWN = 116

  include FifoMetadata

  def initialize(finder)
    @finder = finder

    @entries_list_array  = []
    @entries_list_v      = TkVariable.new
    @pattern_input_v     = TkVariable.new

    instantiate_widgets
    bind_keyboard_events

    create_fifo_file
    trap_process_signals
  end

  def show
    listen_process_events(first_start: true)
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

  def bind_keyboard_events
    @root.bind('Key') do |event|
      if event.keycode == KEYCODE_ESC
        hide_gui
        listen_process_events(first_start: false)
      end
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

  def create_fifo_file
    if ! File.exists?(FIFO_FILENAME)
      checked_shell_execution "mkfifo #{FIFO_FILENAME.shellescape}"
    end
  end

  def delete_fifo_file
    File.delete(FIFO_FILENAME)
  end

  def listen_process_events(first_start:)
    command = IO.read(FIFO_FILENAME.shellescape).rstrip

    case command
    when COMMAND_SHOW
      show_gui(first_start: first_start)
    when COMMAND_QUIT
      close_gui
      delete_fifo_file
    else
      raise "Unexpected command: #{command.inspect}"
    end
  end

  def trap_process_signals
    trap('INT') { delete_fifo_file; raise Interrupt }
    trap('TERM') { delete_fifo_file }
  end

  #####################
  # Other helpers
  #####################

  def hide_gui
    @root.withdraw
  end

  def show_gui(first_start:)
    @pattern_input.focus

    if first_start
      Tk.mainloop
    else
      @pattern_input_v.value = ''
      @root.deiconify
    end
  end

  def close_gui
    @root.destroy
  end

  def open_file(filename)
    hide_gui

    # Can't use Kernel#fork, as it will cause as threading problem with Tk - this
    # method is invoked from the Tk loop.
    #
    `xdg-open #{filename.shellescape} &`

    listen_process_events(first_start: false)
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

  def checked_shell_execution(command)
    Open3.popen3(command) do |_, _, stderr, wait_thread|
      stderr_content = stderr.read
      raise stderr_content if ! wait_thread.value.success?
    end
  end
end

if $PROGRAM_NAME == __FILE__

  search_paths, skip_paths, include_directories = ConfigurationLoader.new.load

  finder = FindFinder.new(search_paths, skip_paths: skip_paths, include_directories: include_directories)

  Spotlight.new(finder).show

end
