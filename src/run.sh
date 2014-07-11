#!/bin/bash

. config.sh

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
