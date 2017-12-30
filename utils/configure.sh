#!/bin/bash

set -o errexit

# VARIABLES/CONSTANTS ##########################################################

configfile_filename="$HOME/.spotlightd"
launcher_filename="$HOME/.config/autostart/Spotlightd.desktop"

spotlight_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

default_configuration="\
search_paths=Desktop:$HOME{1}
skip_paths="

startup_init_content="\
[Desktop Entry]
Type=Application
Name=Spotlightd
Comment=Spotlight daemon
X-GNOME-Autostart-enabled=true
Exec=$spotlight_directory/lib/pm_spotlight_daemon/daemon.rb -d"

# HELPERS ######################################################################

function print_introduction() {
  whiptail --msgbox "\
Hello! This script will install Poor Man's Spotlight in your system.

It will perform two operations:

- create a configuration file ($configfile_filename) with a basic configuration
- create a launcher file ($launcher_filename)
- explain how to bind a global hotkey to the client

Spoglightd can be uninstalled by just deleting the two files, and unbinding the hotkey.

Press OK to continue, or Esc to cancel." 20 90
}

function create_configuration_file() {
  echo "$default_configuration" > "$configfile_filename"
}

function create_startup_file() {
  echo "$startup_init_content" > "$launcher_filename"
}

function print_customization_information() {
  whiptail --msgbox "\
The installation is completed! Now you'll need to bind the client to a global hotkey.

The exact steps depend on your desktop environment; the procedure is simply to bind the command:

    $spotlight_directory/lib/pm_spotlight_client/client.rb show

to a key combination (e.g. Super+space).

On XFCE, for example:

- open the keyboard settings (XFCE Main menu -> \`Keyboard\` -> \`Application Shortcuts\`
- click on \`Add\`
- type \`/path/to/lib/pm_spotlight_client/client.rb show\`, and OK
- type Super+space

Bye!" 20 89
}

# MAIN #########################################################################

print_introduction
create_configuration_file
create_startup_file
print_customization_information
