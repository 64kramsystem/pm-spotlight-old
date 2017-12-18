require 'simple_scripting/argv'
require 'simple_scripting/configuration'

class ConfigurationLoader
  CMDLINE_LONG_HELP = <<~STR
    Poor man's spotlight. The executable used for opening the files is the default one as configurad in Ubuntu.

    Search/skip paths are defined in sav_scripts as 'search_paths' and 'skip_paths', with entries separated by ':'.
    Skip paths are optional.

    Paths including ':' are not supported.
  STR

  def load
    configuration = SimpleScripting::Configuration.load

    cmdline_options = SimpleScripting::Argv.decode(
      ['-d', '--include-directories', 'Include directories in the search'],
      long_help: CMDLINE_LONG_HELP
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
