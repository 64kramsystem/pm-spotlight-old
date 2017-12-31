module PmSpotlightShared
  module SharedConfiguration
    COMMAND_SHOW = 'show'.freeze
    COMMAND_QUIT = 'quit'.freeze

    MAX_COMMANDS_BYTESIZE = [COMMAND_SHOW, COMMAND_QUIT].map(&:bytesize).max

    FIFO_FILENAME = File.expand_path('~/.config/spotlightd/commands.fifo').freeze

    EVENTS_POLL_TIME = 100 # in milliseconds
    SEARCH_RESULT_POLL_TIME = 100 # in milliseconds

    NO_FILES_FOUND_MESSAGE = "\x00"

    LIMIT_SEARCH_RESULT_MESSAGE_SIZE = 2**16 # in bytes

    PATTERN_SIZE_LIMIT = 32
  end
end
