#!/bin/bash

# Project root to use for self referencing other files
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"

# Project repo url
REPO="https://github.com/beeftornado/dev-strap.git"

# Git location
GIT="$( which git )"

# OS type detection
PLATFORM='unknown'
unamestr=$( uname )
if [[ "$unamestr" == 'Linux' ]]; then
   PLATFORM='linux'
elif [[ "$unamestr" == 'FreeBSD' ]]; then
   PLATFORM='freebsd'
elif [[ "$unamestr" == 'Darwin' ]]; then
   PLATFORM='osx'
fi

# Place to dump project during install
if [[ $PLATFORM == 'linux' ]]; then
  TMP_DIR="$( mktemp -d )"
else
  TMP_DIR="$( mktemp -d -t devstrap )"
fi

# Automatically remove temporary directory when exits
trap "rm -rf $TMP_DIR" EXIT

# Download the project
$GIT clone $REPO $TMP_DIR && cd $TMP_DIR

# Run the setup script
SETUP_FILE=$ROOT/src/oses/$PLATFORM.sh
if [[ -e $SETUP_FILE ]]
then
  . $SETUP_FILE
else
  echo "Error: Missing setup file for $PLATFORM"
  exit 1
fi

exit 0
