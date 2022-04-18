# Poor Man's Spotlight (Ruby version; old)

PMsS is a minimal desktop search service for Debian/Ubuntu machines, designed to simply open files/directories, without any indexing.

![Example](/extra/example.png?raw=true)

## Status

Due to limitations of the project as it had been developed, I've written a [new (Rust) version](https://github.com/64kramsystem/pm-spotlight).

The Ruby problems were:

1. Ruby was not well-suited to run GUI programs; due to its non-parallel nature, intensive background threads caused the GUI thread to lag noticeably
2. Ruby-Tk is not well maintained (the last version, 0.4.0, was unstable)
3. Ruby-Tk was very slow to start (on two machines I've tested)
4. System-wide programs are better packaged as executable, rather than Ruby programs (that require version management)

Point 1 should be solved by running background tasks via [Ractor](https://docs.ruby-lang.org/en/3.0/Ractor.html), which didn't exist when this project was developed.

Point 2 and 3 should be solved by changing the GUI library to [FXRuby](https://github.com/larskanis/fxruby), which, when I wrote the project, had a showstopper bug (it has probably been fixed later).

Point 4 is not a big deal, but a single executable is a much more solid solution, and it can't be achieved in Ruby (even if possible, it'll likely make the startup slow; additionally, Ruby packers are not popular anymore - the most common has been discontinued).

My current plan is to rewrite this project with updated versions of Ruby and FXRuby (which solve the problems 1-3), and publish an article about writing GUIs in the two languages.

## Usage

The user types the global hotkey (typically, `Super+space`), which will open a widget; by typing a string (e.g. `game`), a list of matching files/directories will be dynamically presented (e.g. the file `game_of_life.md` and the directory `my_games`); they can be opened by scrolling with the arrows and clicking enter.

The search locations are configured by the user in the configuration file.

## Installation

PMsS requires a Ruby interpreter with Tcl/Tk support; on Ubuntu, the easiest way is to use the BrightBox precompiled ruby interpreter:

```sh
$ sudo add-apt-repository -y ppa:brightbox/ruby-ng
$ sudo apt install ruby2.3-tcltk
```

Currently, versions 2.0 to 2.3 are available.

After this, execute the following from the PMsS directory:

```sh
bundle install
utils/configure.sh
```

By default, PMsS will search in the `Desktop` directory, and the top-level directories of `$HOME`.

## Configuration

After executing the configuration script, one should configure the search paths, which are configured in "$HOME/.spotlightd"; this is an example:

```
search_paths=Desktop:studies:/home/myuser{1}:/usr/local/src
skip_paths=Desktop/temp_dir
```

The format is:

- when a path doesn't start with `/`, it is relative to the home dir
- in order to enforce a certain search depth, place it a the end of a path, between curly braces, e.g. `/home/myuser{1}` will find files and directories under `/home/myuser`, but won't recursively search inside the directories.

The above example will:

- include `$HOME/Desktop` and its subdirectories
- include `$HOME/studies` and its subdirectories
- include `$HOME` top-level files, without recursion; for example, `$HOME/games` will be included, but not `$HOME/games/metroid`
- include `/usr/local/src` and its subdirectories
- skip `Desktop/temp_dir`

## Design

The purpose of this project is, beside my personal usage, to provide an example for Ruby simple GUIs development, and message-based concurrent programming.

### Architecture

PMsS's architecture has been inspired by the microservices philosophy, and Golang; it's a shared-nothing composition of independent services (running in threads), which communicate via messages sent through pipes:

- `GlobalManager`: initializes/coordinates the services
  - `CommandsListener`: listens for GUI commands (show/quit)
  - `SearchService`: listen for patterns; sends the list of matching files
    - `FindSearch`: the current search backend, which uses `find`
  - `TkInterface`: listens for GUI commands and for find results; sends patterns typed by the user

This gives significant advantages (for example, services can be swapped trivially, as long as they respect the messaging protocols), but also some complexities (at least a basic message brokering needs to be implemented).

### GUI Toolkit

Tk has been used because years ago, when I wrote this tool, I tried all the other GUI frameworks, and they had limitations (e.g. Shoes 3 was missing a listener) and/or bugs (e.g. FXRuby had a showstopper bug). Things may have changed in the meanwhile (FXRuby fixed the crucial bug after some time; Shoes 3 may have developed the missing listener).

The GUI toolkit will be replaced in the future with something easier to install, and possibly better documented (Tk has a very nice tutorial, but it misses threading information, for which there is little information around).

### Other

This project is in my `script` category (no public users and little complexity), therefore has no testing, although I use it very frequently.

For my testing practices, see other projects, like [Spreadbase](https://github.com/saveriomiroddi/spreadbase) and [Geet](https://github.com/saveriomiroddi/geet).

## Plan

Plans are provided through GibHub issues.

Long-term plans are:

- review the GUI toolkits, and switch if another GUI toolkit provides easier packaging
- package as gem
