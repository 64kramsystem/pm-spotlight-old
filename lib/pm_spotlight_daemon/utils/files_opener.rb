module PmSpotlightDaemon
  module Utils
    class FilesOpener
      def open_in_background(filename)
        # An interesting problem came up here.  .
        #
        # The program `xdg-open` will invoke the system program associated to a certain file type, and
        # exit immediately.
        #
        # There are a few options for executing it, the blocking being `system()` and backticks (``).
        # For unspecified reasons, while both should exit immediately (as `xdg-open` does), the former
        # does, but the second doesn't, and block until the system program exists.
        #
        # For this reason, we use `system()`.
        #
        # `fork()` will also work, but it needs to be invoked from a thread (if executed from a Tk
        # event), otherwise it will cause problems.
        #
        system 'xdg-open', filename.shellescape
      end
    end
  end
end