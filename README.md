# Poor Man's Spotglight

PMsS is a minimal desktop search service for Debian/Ubuntu machines, designed to simply open files/directories, without any indexing.

![Example](/extra/example.png?raw=true)

## Usage

The user types the global hotkey (typically, `Super+space`), which will open a widget; by typing a string (e.g. `game`), a list of matching files/directories will be dynamically presented (e.g. the file `game_of_life.md` and the directory `my_games`); they can be opened by scrolling with the arrows and clicking enter.

The search locations are configurated by the user in the configuration file.

## Installation

PMsS requires a Ruby with Tcl/TK support; on Ubuntu, the easiest way is to use the BrightBox precompiled ruby interpreter:

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
- in order ot enforce a certain search depth, place it a the end of a path, between curly braces, e.g. `/home/myuser{1}` will find files and directories under `/home/myuser`, but won't recursively search inside the directories.

The above example will:

- include `$HOME/Desktop` and its subdirectories
- include `$HOME/studies` and its subdirectories
- include `$HOME` top-level files, without recursion; for example, `$HOME/games` will be included, but not `$HOME/games/metroid`
- include `/usr/local/src` and its subdirectories
- skip `Desktop/temp_dir`

## Design

PMsS is programmed in Ruby, and uses the Tk, so it requires a Ruby interpreter with Tcl/Tk support (`ruby2.3-tcltk` in Ubuntu).

The daemon is written in the simplest possible way, both the GUI (without threading) and the search (which uses Linux's `find`).
The client is written in ruby for convenience, and it's trivial (it supports the commands `show` and `quit`).

Tk has been used because years ago, when I wrote this tool, I tried all the other GUI frameworks, and they all had limitations (e.g. `Shoes`) and/or bugs (e.g. `FXRuby`). Things may have changed in the meanwhile (`FXRuby` fixed the bug after some time).

This project has no testing, as it was originally written for internal use, although I use it very heavily.

Its purpose (as open source project) is to provide an example for writing a simple Ruby GUI application.

For my testing practices, see other projects, like [Spreadbase](https://github.com/saveriomiroddi/spreadbase) and [Geet](https://github.com/saveriomiroddi/geet).

## Plan

Plans are provided through GibHub issues. The current priority is to redesign the daemon to use threading/IPC.

Long-term plans are:

- re-evaluation of the GUI toolkit
- packaging
