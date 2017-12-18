# Poor Man's Spotglight

PMsS is a minimal desktop search service for Linux machines.

## Usage

PMSsS's purpose it have a fast way of searching files/directories in the configured locations, through substring matching.

The application is divided into a daemon and a client. The user typically binds the client to a global key (e.g. `Super+Space`), then types a substring (eg. `game` will match the file `game_of_life.md` and the directory `my_games`), and selects from a dynamically updated list.

## Configuration

Sample configuration (generation):

```sh
echo '
search_paths=Desktop:studies:/home/myuser{1}:/usr/local/src
skip_paths=Desktop/temp_dir
' > ~/.spotlightd

echo '[Desktop Entry]
Type=Application
Name=Spotlightd
Comment=Spotlight daemon
X-GNOME-Autostart-enabled=true
Exec=/home/saverio/code/pm-spotlight/spotlightd.rb -d

' > ~/.config/autostart/Spotlightd.desktop
```

Finally, the command `spotlight_client.rb show` must be associated to a global key (e.g. `Super+Space`).

Format of `~/.spotlightd`:

- when a path doesn't start with `/`, it is relative to the home dir
- in order ot enforce a certain search depth, place it a the end of a path, between curly braces, e.g. `/home/myuser{1}` will find files and directories under `/home/myuser`, but won't recursively search inside the directories.

## Design

PMsS is programmed in Ruby, and uses the Tk, so it requires a Ruby interpreter with Tcl/Tk support (`ruby2.3-tcltk` in Ubuntu).

The daemon is written in the simplest possible way, both the GUI (without threading) and the search (which uses Linux's `find`).
The client is written in ruby for convenience, and it's trivial (it supports the commands `show` and `quit`).

Tk has been used because years ago, when I wrote this tool, I tried all the other GUI frameworks, and they all had limitations (e.g. `Shoes`) and/or bugs (e.g. `FXRuby`). Things may have changed in the meanwhile (`FXRuby` fixed the bug after some time).

This project has no testing, as it was originally written for internal use, although I use it very heavily.

Its purpose (as open source project) is to provide an example for writing a simple Ruby GUI application.

I will expand the documentation of it, make a configuration tool, and package it in a gem; if the project will be forked, I will add testing.  
For my testing practices, see other projects, like [Spreadbase](https://github.com/saveriomiroddi/spreadbase) and [Geet](https://github.com/saveriomiroddi/geet).
