require 'fileutils'
require 'tk'
require 'open3'
require 'shellwords'

require_relative '../../pm_spotlight_shared/shared_configuration'
require_relative '../serialization/find_result_deserializer'

module PmSpotlightDaemon
  module Modules
    class TkInterface
      ICON_FILE = File.join(__dir__, '..', 'resources', 'telescope-icon.gif')

      KEYCODE_ESC        = 9
      KEYCODE_ENTER      = 36
      KEYCODE_ARROW_DOWN = 116

      include PmSpotlightShared::SharedConfiguration

      def initialize(find_pattern_writer, find_result_reader)
        @find_pattern_writer = find_pattern_writer
        @find_result_deserializer = PmSpotlightDaemon::Serialization::FindResultDeserializer.new(find_result_reader, LIMIT_FIND_RESULT_MESSAGE_SIZE)

        @entries_list_array  = []
        @entries_list_v      = TkVariable.new
        @pattern_input_v     = TkVariable.new

        instantiate_widgets
        bind_keyboard_events

        create_fifo_file

        poll_find_result_reader
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

        icon = TkPhotoImage.new('file' => ICON_FILE)
        @root.iconphoto(icon)

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

          puts "TkInterface: sending #{@pattern_input_v.value.inspect} to find_pattern_writer"

          @find_pattern_writer.write(@pattern_input_v.value)
          @find_pattern_writer.flush
        end
      end

      def create_fifo_file
        if ! File.exists?(FIFO_FILENAME)
          config_dir = File.dirname(FIFO_FILENAME)

          FileUtils.mkdir_p(config_dir) if ! Dir.exists?(config_dir)

          checked_shell_execution "mkfifo #{FIFO_FILENAME.shellescape}"
        end
      end

      def listen_process_events(first_start:)
        puts "TkInterface: reading command from FIFO..."

        command = IO.read(FIFO_FILENAME.shellescape).rstrip

        case command
        when COMMAND_SHOW
          show_gui(first_start: first_start)
        when COMMAND_QUIT
          close_gui
          delete_fifo_file
        else
          $stderr.puts "Unexpected command: #{command.inspect}"
        end
      end

      def poll_find_result_reader
        @root.after(FIND_RESULT_POLL_TIME) do
          @find_result_deserializer.buffered_deserialize do |last_find_result|
            @entries_list_array = last_find_result
            @entries_list_v.value = last_find_result.map { |entry| transform_entry_text(entry) }

            @entries_list.selection_set 0
          end

          poll_find_result_reader
        end
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

        execute_in_background(filename)

        listen_process_events(first_start: false)
      end

      def deserialize_find_result(serialized_find_result)
        if serialized_find_result == NO_FILES_FOUND_MESSAGE
          []
        else
          serialized_find_result.split("\n")
        end
      end

      # Display the parent directory only, not the entire tree.
      #
      def transform_entry_text(text)
        # It's possible that a file is at the root level, thus the '||'
        #
        text[%r{[^/]*/[^/]*$}] || text
      end

      # Choosing the right API is not simple, also because it depends on the spotlightd GUI architecture
      # (and on `xdg-open`).
      # With the current (experimental) architecture:
      #
      # - `fork()` doesn't work, as it raises an error about X multithreading on the second invocation
      # - backticks (``` `` ```) will block (eg. when opening a libreoffice document)
      #
      # Interestingly, while `system()` is a blocking API like the backticks, it doesn't block; the only
      # thing that may be related is that `system()` doesn't read the stdout, although it's not clear
      # who `xdg-open` relates to it, since it has no visible output.
      #
      # Note that `system()` won't block because `xdg-open` forks the target application and exits.
      #
      def execute_in_background(filename)
        system "xdg-open #{filename.shellescape}"
      end

      def checked_shell_execution(command)
        Open3.popen3(command) do |_, _, stderr, wait_thread|
          stderr_content = stderr.read
          raise stderr_content if ! wait_thread.value.success?
        end
      end
    end
  end
end
