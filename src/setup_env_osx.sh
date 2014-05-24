#!/bin/bash

. ./functions.sh

# Use step(), try(), and next() to perform a series of commands and print
# [  OK  ] or [FAILED] at the end. The step as a whole fails if any individual
# command fails.
#
# Example:
#     step "Remounting / and /boot as read-write:"
#     try mount -o remount,rw /
#     try mount -o remount,rw /boot
#     next

# Clean the screen
clear

cat ../logo

echo

# OSX version requirement
if [[ ! $(sw_vers -productVersion | egrep '10.[89]')  ]]
then
  echo "This script is only certified for OSX versions 10.8 (Mountain Lion) and 10.9 (Mavericks), aborting..."
  exit 1
fi

# Disk space requirement
df -H / | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | while read output;
do
  usep=$(echo $output | awk '{ print $1}' | cut -d'%' -f1  )
  partition=$(echo $output | awk '{ print $2 }' )
  if [ $usep -ge 90 ]; then
    echo "Running out of space \"$partition ($usep%)\" on $(hostname) on $(date)"
    echo "Aborting..."
    exit 1
  fi
done

# Continuation
echo "This program will do its best to configure your system for application "
echo "development. It can be used for new or on existing setups."
echo
echo "Please submit bug or feature requests to https://github.com/beeftornado/dev-strap"
echo
echo "You will be presented with a menu where you can pick and choose the components you want."
echo

confirm "To continue, we require Homebrew. If you already have it, great, if not we will install it for you. Continue?"
CONTINUE=$?

echo

if [[ $CONTINUE -eq 1 ]]; then

  step "Installing homebrew: "
  if [ ! -f /usr/local/bin/brew ]; then
    try ruby -e "$(\curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
    next
  else
    skip
  fi

else
  echo "Aborting."
  exit 0
fi

step "Installing whiptail (pretty menu): "
if [ ! -f /usr/local/bin/whiptail ]; then
  try brew install newt
  next
else
  skip
fi

menu=(whiptail --separate-output --title "Install Options" --checklist "\nSelect the dev options you want (I recommend having all):\n\n[spacebar] = toggle on/off" 0 0 0)
options=(1 "Python, pip, virtualenv" on
        2 "NodeJS, NVM" on
        3 "Ruby, RVM" on
        4 "Mysql, Mongo" on
        5 "Common dependencies from Homebrew" on
        6 "Development tools (apps like editors)" on
        7 "Additional apps everyone should have (like chrome)" on
        8 "Internet Explorer VM (will be prompted for versions later)" off)
choices=$("${menu[@]}" "${options[@]}" 2>&1 > /dev/tty)

if [[ $? -ne 0 ]]; then
  echo "Aborting..."
  exit 1
fi

choice_count=$(echo "$choices" | grep -v '^$' | wc -l)
if [ $choice_count -eq 0 ]; then
  echo "Nothing selected."
  exit 0
fi

for choice in $choices
do
  case $choice in
  1)
      SETUP_PYTHON=0
  ;;
  2)
      SETUP_NODEJS=0
  ;;
  3)
      SETUP_RUBY=0
  ;;
  4)
      SETUP_DB=0
  ;;
  5)
      SETUP_HOMEBREW_COMMONS=0
  ;;
  6)
      SETUP_DEV_APPS=0
  ;;
  7)
      SETUP_COMMON_APPS=0
  ;;
  esac
done


step "Bootstrapping homebrew: "
egrep "PATH.*/usr/local/bin" ~/.bashrc >/dev/null
if [[ $? -ne 0 ]]; then
  try echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
  next
else
  skip
fi

step "Installing python: "
if [[ $SETUP_PYTHON ]]; then
    try brew install python > /dev/null 2>/dev/null
    PYTHON_VERSION=$(python -V 2>&1 | /usr/bin/awk -F' ' '{print $2}')
    vercomp $PYTHON_VERSION "2.7"
    if [[ $? -eq 2 ]]; then
      # user's python version is less then 2.7
      try brew upgrade python > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing pip: "
if [[ $SETUP_PYTHON ]]; then
    if [ ! -f /usr/local/bin/pip ]; then
      try sudo easy_install pip > /dev/null 2>/dev/null
    fi
    PIP_VERSION=$(/usr/local/bin/pip -V | /usr/bin/awk -F' ' '{print $2}')
    vercomp $PIP_VERSION "1.5"
    if [[ $? -eq 2 ]]; then
      # user's pip version is less then 1.5
      try /usr/local/bin/pip install --upgrade pip > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing gevent dependency libevent: "
brew list libevent > /dev/null 2>/dev/null
if [[ $? -ne 0 ]]; then
  try brew install libevent > /dev/null 2>/dev/null
  next
else
  skip
fi

step "Installing mysql: "
if [[ $SETUP_DB ]]; then
    brew list mysql > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install mysql > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing mongodb: "
if [[ $SETUP_DB ]]; then
    brew list mongodb > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install mongodb > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing node version manager: "
if [[ $SETUP_NODEJS ]]; then
    nvm --version > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
        # missing nvm
        try curl -s https://raw.github.com/creationix/nvm/master/install.sh | sh > /dev/null 2>/dev/null
        try source ~/.nvm/nvm.sh > /dev/null 2>/dev/null
    else
        NVM_VERSION=$(nvm --version | /usr/bin/awk -F' ' '{print $2}' | /usr/bin/awk -F'v' '{print $2}')
        vercomp $NVM_VERSION "0.4"
        if [[ $? -eq 2 ]]; then
            # user's nvm version is less then 0.4
            try curl -s https://raw.github.com/creationix/nvm/master/install.sh | sh > /dev/null 2>/dev/null
            try source ~/.nvm/nvm.sh > /dev/null 2>/dev/null
        fi
    fi
    next
else
    skip
fi

step "Installing nodejs v0.10: "
if [[ $SETUP_NODEJS ]]; then
    try nvm install 0.10 > /dev/null 2>/dev/null
    try nvm alias default v0.10 >/dev/null 2>/dev/null

    egrep "PATH.*/usr/local/share/npm/bin" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo 'export PATH=/usr/local/share/npm/bin:$PATH' >> ~/.bashrc
    fi

    next
else
    skip
fi

step "Installing python virtual env: "
if [[ $SETUP_PYTHON ]]; then
    try pip install virtualenv virtualenvwrapper > /dev/null 2>/dev/null
    next
else
    skip
fi

step "Bootstrapping virtualenvwrapper: "
if [[ $SETUP_PYTHON ]]; then
    # Find the virtualenvwrapper shell script
    if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
      VE_WRAPPER_LOC="/usr/local/bin/virtualenvwrapper.sh"
    fi
    if [ -f /usr/local/share/python/virtualenvwrapper.sh ]; then
      VE_WRAPPER_LOC="/usr/local/share/python/virtualenvwrapper.sh"
    fi
    try source $VE_WRAPPER_LOC > /dev/null 2>/dev/null

    egrep "export VIRTUALENVWRAPPER_PYTHON=" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo 'export VIRTUALENVWRAPPER_PYTHON=/usr/local/bin/python' >> ~/.bashrc
    fi

    egrep "source ${VE_WRAPPER_LOC}" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo "source ${VE_WRAPPER_LOC}" >> ~/.bashrc
    fi
    next
else
    skip
fi

step "Installing ruby version manager: "
if [[ $SETUP_RUBY ]]; then
    RVM_PATH=$(echo $rvm_path 2>&1)
    if [ -e $RVM_PATH ]; then
        # User already has rvm
        RVM_VERSION=$(echo $rvm_version | awk -F' ' '{print $1}')
        vercomp $RVM_VERSION "1.25"
        if [[ $? -eq 2 ]]; then
            # Upgrade rvm
            try $RVM_PATH/bin/rvm get stable > /dev/null 2>/dev/null
        fi
    else
        # User needs rvm
        try \curl -sSL https://get.rvm.io | bash -s stable > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing ruby: "
if [[ $SETUP_RUBY ]]; then
    RUBY_VER=$(ruby -v | awk -F' ' '{print $2}' | awk -F'p' '{print $1}')
    vercomp "$RUBY_VER" 1.9.2
    if [ $? -eq 2 ]; then
      try $RVM_PATH/bin/rvm install 1.9.2 > /dev/null 2>/tmp/ruby-install.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/ruby-install.err
          rm /tmp/ruby-install.err
      fi
    fi
    next
else
    skip
fi

exit 0
