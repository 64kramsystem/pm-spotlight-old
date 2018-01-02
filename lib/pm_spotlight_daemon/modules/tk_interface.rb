require 'tk'

require_relative '../../pm_spotlight_shared/shared_configuration'
require_relative '../messaging/receiver'
require_relative '../utils/files_opener'

module PmSpotlightDaemon
  module Modules
    class TkInterface
      ICON_FILE = File.join(__dir__, '..', 'resources', 'telescope-icon.gif')

      KEYCODE_ESC        = 9
      KEYCODE_ENTER      = 36
      KEYCODE_ARROW_DOWN = 116

      include PmSpotlightShared::SharedConfiguration

      def initialize(commands_reader, search_pattern_writer, search_result_reader)
        @commands_reader = commands_reader
        @search_pattern_sender = PmSpotlightDaemon::Messaging::Sender.new(search_pattern_writer)
        @search_results_receiver = PmSpotlightDaemon::Messaging::Receiver.new(search_result_reader, LIMIT_SEARCH_RESULT_MESSAGE_SIZE)

        @entries_list_array  = []
        @entries_list_v      = TkVariable.new
        @pattern_input_v     = TkVariable.new

        instantiate_widgets
        bind_keyboard_events

        poll_commands_reader
        poll_search_result_reader
      end

      def start
        start_interface_hidden
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
          if @pattern_input_v.value.size > PATTERN_SIZE_LIMIT
            @pattern_input_v.value = @pattern_input_v.value[0, PATTERN_SIZE_LIMIT]
          else
            # Empty list while (before) searching, in case it takes long
            #
            @entries_list_v.value = []

            puts "TkInterface: sending #{@pattern_input_v.value.inspect} through search_pattern_sender"

            @search_pattern_sender.send_message(@pattern_input_v.value)
          end
        end
      end

      def start_interface_hidden
        hide_gui
        Tk.mainloop
      end

      #####################
      # Readers polling
      #####################

      def poll_commands_reader
        @root.after(EVENTS_POLL_TIME) do
          begin
            command = @commands_reader.read_nonblock(MAX_COMMANDS_BYTESIZE)

            puts "TkInterface: has read a #{command.inspect} command from commands_reader"

            case command
            when COMMAND_SHOW
              show_gui
            when COMMAND_QUIT
              destroy_gui
            else
              raise "Unexpected command: #{command.inspect}"
            end
          rescue IO::WaitReadable, IO::EAGAINWaitReadable
            # nothing available at the moment.
          ensure
            poll_commands_reader
          end
        end
      end

      def poll_search_result_reader
        @root.after(SEARCH_RESULT_POLL_TIME) do
          @search_results_receiver.read_last_message_nonblock do |last_search_result|
            @entries_list_array = last_search_result.split("\n")
            @entries_list_v.value = @entries_list_array.map { |entry| transform_entry_text(entry) }

            @entries_list.selection_set 0
          end

          poll_search_result_reader
        end
      end

      #####################
      # Other helpers
      #####################

      def hide_gui
        @root.withdraw
      end

      def show_gui
        @pattern_input.focus
        @pattern_input_v.value = ''
        @root.deiconify
      end

      def destroy_gui
        @root.destroy
      end

      def open_file(filename)
        hide_gui

        Thread.new do
          PmSpotlightDaemon::Utils::FilesOpener.new.open_in_background(filename)
        end
      end

      def deserialize_search_result(serialized_search_result)
        if serialized_search_result == NO_FILES_FOUND_MESSAGE
          []
        else
          serialized_search_result.split("\n")
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
  end
end
