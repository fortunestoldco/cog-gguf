#!/bin/bash
set -e

set_install_dir() {
  # Set install directory to default without prompting
  INSTALL_DIR="/usr/local/bin"
  if [ ! -d "$INSTALL_DIR" ]; then
    echo "The directory $INSTALL_DIR does not exist."
    exit 1
  fi
  # Expand abbreviations in INSTALL_DIR
  INSTALL_DIR=$(cd "$INSTALL_DIR"; pwd)
}

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

user_can_sudo() {
  # Check if sudo is installed
  command_exists $SUDO || return 1
  # Termux can't run sudo, so we can detect it and exit the function early.
  case "$PREFIX" in
  *com.termux*) return 1 ;;
  esac
  # The following command has 3 parts:
  #
  # 1. Run `sudo` with `-v`. Does the following:
  #    • with privilege: asks for a password immediately.
  #    • without privilege: exits with error code 1 and prints the message:
  #      Sorry, user <username> may not run sudo on <hostname>
  #
  # 2. Pass `-n` to `sudo` to tell it to not ask for a password. If the
  #    password is not required, the command will finish with exit code 0.
  #    If one is required, sudo will exit with error code 1 and print the
  #    message:
  #    sudo: a password is required
  #
  # 3. Check for the words "may not run sudo" in the output to really tell
  #    whether the user has privileges or not. For that we have to make sure
  #    to run `sudo` in the default locale (with `LANG=`) so that the message
  #    stays consistent regardless of the user's locale.
  #
  ! LANG= $SUDO -n -v 2>&1 | grep -q "may not run $SUDO"
}

check_docker() {
  if ! command_exists docker; then
    echo "Docker is not installed on your system. Please install Docker before proceeding."
    exit 1
  fi

  if ! docker run hello-world >/dev/null 2>&1; then
    echo "WARNING: Docker engine is not running, or docker cannot be run without sudo. Please setup Docker so that your user has permission to run it: https://docs.docker.com/engine/install/linux-postinstall/"
  fi
}

setup_cog() {
  COG_LOCATION="${INSTALL_DIR}/cog"
  BINARY_URI="https://github.com/replicate/cog/releases/latest/download/cog_$(uname -s)_$(uname -m)"
  
  # Delete existing file without prompting
  if [ -f "$COG_LOCATION" ]; then
    $SUDO rm $COG_LOCATION
  fi
  
  if command_exists curl; then
    $SUDO curl -o $COG_LOCATION -L $BINARY_URI
  elif command_exists wget; then
    $SUDO wget $BINARY_URI -O $COG_LOCATION
  elif command_exists fetch; then
    $SUDO fetch -o $COG_LOCATION $BINARY_URI
  else
    echo "One of curl, wget, or fetch must be present for this installer to work."
    exit 1
  fi
  
  if [ "$(cat $COG_LOCATION)" = "Not Found" ]; then
    echo "Error: Cog binary not found at ${BINARY_URI}. Check releases to see if a binary is available for your system."
    rm $COG_LOCATION
    exit 1
  fi

  $SUDO chmod +x $COG_LOCATION

  SHELL_NAME=$(basename "$SHELL")
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Adding $INSTALL_DIR to PATH in .$SHELL_NAME"rc
    echo "" >> ~/.$SHELL_NAME"rc"
    echo "# Created by \`cog\` install script on $(date)" >> ~/.$SHELL_NAME"rc"
    echo "export PATH=\$PATH:$INSTALL_DIR" >> ~/.$SHELL_NAME"rc"
    source ~/.$SHELL_NAME"rc"
  fi
}

print_success() {
  echo "Successfully installed cog. Run \`cog login\` to configure Replicate access"
}

main() {
  # Skip macOS check/prompt - just proceed with installation
  set_install_dir

  # Skip existing cog check/prompt - proceed with installation

  # Check the users sudo privileges
  if [ -z "${SUDO+set}" ]; then
    SUDO="sudo"
  fi
  if [ ! user_can_sudo ] && [ "${SUDO}" != "" ]; then
    echo "You need sudo permissions to run this install script. Please try again as a sudoer."
    exit 1
  fi

  check_docker
  setup_cog

  if command_exists cog; then
    print_success
  else
    echo 'Error: cog not installed.'
    exit 1
  fi
}

main "$@"
