module PmSpotlightShared
  module SharedConfiguration
    COMMAND_SHOW = 'show'.freeze
    COMMAND_QUIT = 'quit'.freeze

    FIFO_FILENAME = File.expand_path('~/.config/spotlightd/commands.fifo').freeze

    LIMIT_FIND_RESULT_MESSAGE_SIZE = 2**16 # in bytes
  end
end
