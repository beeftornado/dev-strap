#!/bin/bash

# Set _DEBUG="on" to turn on debugging

. $( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )/config.sh
. $ROOT/src/utilities/functions.sh

DEBUG set -x

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

cat $ROOT/logo

echo

# OSX version requirement
if [[ ! $(sw_vers -productVersion | egrep '10.([89]|10)')  ]]
then
  echo "This script is only certified for OSX versions 10.8 (Mountain Lion), 10.9 (Mavericks), and 10.10 (Yosemite), aborting..."
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
echo "ATTENTION"
echo "---------"
echo "To continue, we require Homebrew, a package management tool for OSX. If you already have it, great,"
echo "if not we will install it for you."
echo
confirm "Continue?"
CONTINUE=$?

echo

if [[ $CONTINUE -eq 1 ]]; then

  step "Installing homebrew: "
  if [ ! -f /usr/local/bin/brew ]; then
    try ruby -e "$(\curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
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
  # Test if whiptail broken
  whiptail -v > /dev/null 2>/dev/null
  if [[ $? -ne 0 ]]; then
    try brew reinstall newt
    next
  else
    skip
  fi
fi

menu=(whiptail --separate-output --title "Install Options" --checklist "\nSelect the dev options you want (I recommend having all):\n\n[spacebar] = toggle on/off" 0 0 0)
options=(1 "Python with pyenv (version manager), pip, and virtualenv" on
        2 "NodeJS with nvm (version manager) and npm" on
        3 "Ruby with rvm (version manager)" on
        4 "Java 6 with jenv (version manager)" on
        5 "Java 7 with jenv (version manager)" on
        6 "Mysql and Mongo" on
        7 "Common libraries from Homebrew" on
        8 "Scala with svm (version manager) and sbt" off
        9 "Development tools (apps like editors and IDEs)" off
        10 "Additional apps for normal people (like chrome, adium, vlc)" off
        11 "beeftornado's additional specialty apps" off
        12 "Internet Explorer VM (will be prompted for versions later)" off
        13 "C# IDE Xamarin Studio" off)
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
      SETUP_JDK6=0
  ;;
  5)
      SETUP_JDK7=0
  ;;
  6)
      SETUP_DB=0
  ;;
  7)
      SETUP_HOMEBREW_COMMONS=0
  ;;
  8)
      SETUP_SCALA=0
  ;;
  9)
      SETUP_DEV_APPS=0
  ;;
  10)
      SETUP_COMMON_APPS=0
  ;;
  11)
      SETUP_SPECIALTY_APPS=0
  ;;
  12)
      SETUP_IE=0
  ;;
  13)
      SETUP_XAMARIN=0
  ;;
  esac
done


step "Bootstrapping homebrew: "
try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then brew $in || true; fi; fi; done < $ROOT/brew/Brewfile-Init > /dev/null 2>/tmp/dev-strap.err)
if [[ $? -ne 0 ]]; then
    cat /tmp/dev-strap.err
    rm /tmp/dev-strap.err
fi
egrep "PATH.*/usr/local/bin" ~/.bashrc >/dev/null
if [[ $? -ne 0 ]]; then
  try echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
  try source ~/.bashrc
fi
next

step "Installing python: "
if [[ $SETUP_PYTHON ]]; then
    if [[ ! $(which pyenv) ]]; then
      try brew install pyenv > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
    fi

    if [[ $(which python) ]]; then
      # User has a python exe
      PYTHON_VERSION=$(python -V 2>&1 | /usr/bin/awk -F' ' '{print $2}')
      vercomp $PYTHON_VERSION "2.7"
      if [[ $? -eq 2 ]]; then
        # user's python version is less then 2.7
        #try brew upgrade python > /dev/null 2>/tmp/dev-strap.err
        try pyenv install 2.7.8 > /dev/null 2>/tmp/dev-strap.err
        if [[ $? -ne 0 ]]; then
            cat /tmp/dev-strap.err
            rm /tmp/dev-strap.err
        fi
      fi
    else
      # no python
      try pyenv install 2.7.8 > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
    fi
    next
else
    skip
fi

eval "$(pyenv init -)"
pyenv shell 2.7.8
PIP=$(pyenv which pip)

step "Installing pip: "
if [[ $SETUP_PYTHON ]]; then
    if [ ! -f $PIP ]; then
      try sudo easy_install pip > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
    fi
    PIP_VERSION=$($PIP -V | /usr/bin/awk -F' ' '{print $2}')
    vercomp $PIP_VERSION "1.5"
    if [[ $? -eq 2 ]]; then
      # user's pip version is less then 1.5
      try $PIP install --upgrade pip > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
    fi
    next
else
    skip
fi

step "Installing python virtual env: "
if [[ $SETUP_PYTHON ]]; then
  if [[ ! $(which virtualenv) ]]; then
    try $PIP install virtualenv virtualenvwrapper >/tmp/dev-strap.err 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
    fi
  fi
  next
else
  skip
fi

step "Bootstrapping virtualenvwrapper: "
if [[ $SETUP_PYTHON ]]; then
    # Find the virtualenvwrapper shell script
    $(which virtualenvwrapper.sh)
    try $(which virtualenvwrapper.sh) >/tmp/dev-strap.err 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
    fi

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

step "Installing gevent dependency libevent: "
brew list libevent > /dev/null 2>/dev/null
if [[ $? -ne 0 ]]; then
  try brew install libevent > /dev/null 2>/tmp/dev-strap.err
  if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
  fi
  next
else
  skip
fi

step "Installing common required libraries: "
if [[ $SETUP_HOMEBREW_COMMONS ]]; then
  try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then brew $in || true; fi; fi; done < $ROOT/brew/Brewfile-Dependencies > /dev/null 2>/tmp/dev-strap.err)
  if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
  fi
  next
else
  skip
fi

step "Installing mysql: "
if [[ $SETUP_DB ]]; then
    brew list mysql > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install mysql > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
    fi
    next
else
    skip
fi

step "Installing mongodb: "
if [[ $SETUP_DB ]]; then
    brew list mongodb > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install mongodb > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
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
        #try curl -s https://raw.github.com/creationix/nvm/master/install.sh | sh > /dev/null 2>/dev/null
        #try source ~/.nvm/nvm.sh > /dev/null 2>/dev/null
        try brew install nvm > /dev/null 2>/tmp/dev-strap.err
        if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
        fi
    else
        NVM_VERSION=$(nvm --version | /usr/bin/awk -F' ' '{print $2}' | /usr/bin/awk -F'v' '{print $2}')
        vercomp $NVM_VERSION "0.4"
        if [[ $? -eq 2 ]]; then
            # user's nvm version is less then 0.4
            try brew install nvm > /dev/null 2>/tmp/dev-strap.err
            if [[ $? -ne 0 ]]; then
              cat /tmp/dev-strap.err
              rm /tmp/dev-strap.err
            fi
        fi
    fi
    export NVM_DIR=~/.nvm
    source $(brew --prefix nvm)/nvm.sh
    egrep "export NVM_DIR=~/\.nvm" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo 'export NVM_DIR=~/.nvm' >> ~/.bashrc
    fi
    egrep "source \$\(brew --prefix nvm\)/nvm\.sh" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo 'source $(brew --prefix nvm)/nvm.sh' >> ~/.bashrc
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

step "Installing java version manager: "
if [[ $SETUP_JDK6 || $SETUP_JDK7 ]]; then
    brew list jenv > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install jenv > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
      else
        eval "$(jenv init -)"
      fi
      egrep "\$HOME/\.jenv/bin" ~/.bashrc >/dev/null
      if [[ $? -ne 0 ]]; then
        try echo 'export PATH="$HOME/.jenv/bin:$PATH"' >> ~/.bashrc
        try echo 'eval "$(jenv init -)"' >> ~/.bashrc
      fi
    fi
    next
else
    skip
fi

step "Installing java 6: "
if [[ $SETUP_JDK6 ]]; then
    jenv versions | grep '1.6' > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew cask install java6 > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      else
        jenv add /Library/Java/Home
      fi
    fi
    next
else
    skip
fi

step "Installing java 7: "
if [[ $SETUP_JDK7 ]]; then
    jenv versions | grep '1.7' > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew cask install java7 > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
        cat /tmp/dev-strap.err
        rm /tmp/dev-strap.err
      else
        EXACT_JAVA7_VERSION=$(brew cask info java7 | grep java7: | awk -F' ' '{print $2}')
        jenv add /Library/Java/JavaVirtualMachines/jdk${EXACT_JAVA7_VERSION}.jdk/Contents/Home/
      fi
    fi
    next
else
    skip
fi

step "Installing Scala: "
if [[ $SETUP_SCALA ]]; then
  if [[ ! $(which svm) ]]; then
    try curl https://raw.githubusercontent.com/yuroyoro/svm/master/svm -o /usr/local/bin/svm > /dev/null 2>/dev/null
    try chmod 755 /usr/local/bin/svm
    egrep "export SCALA_HOME=~/\.svm/current/rt" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo 'export SCALA_HOME=~/.svm/current/rt' >> ~/.bashrc
      try echo 'export PATH=$SCALA_HOME/bin:$PATH' >> ~/.bashrc
    fi
    export SCALA_HOME=~/.svm/current/rt
    export PATH=$SCALA_HOME/bin:$PATH
  fi

  if [[ ! $(svm list | grep 2.9.2) ]]; then
    try svm install 2.9.2 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
    fi
  fi

  if [[ ! $(svm list | grep 2.9.3) ]]; then
    try svm install 2.9.3 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
    fi
  fi

  if [[ ! $(svm list | grep 2.10.5) ]]; then
    try svm install 2.10.5 2>/tmp/dev-strap.err
    if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
    fi
  fi

  if [[ ! $(which sbt) ]]; then
    try brew install sbt
  fi

  next
else
  skip
fi

step "Installing various developer tools: "
if [[ $SETUP_DEV_APPS ]]; then
  try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then brew $in || true; fi; fi; done < $ROOT/brew/Brewfile-DevApps > /dev/null 2>/tmp/dev-strap.err)
  if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
  fi
  next
else
  skip
fi

step "Installing various everyday applications: "
if [[ $SETUP_COMMON_APPS ]]; then
  try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then brew $in || true; fi; fi; done < $ROOT/brew/Brewfile-EverydayApps > /dev/null 2>/tmp/dev-strap.err)
  if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
  fi
  next
else
  skip
fi

step "Installing special applications: "
if [[ $SETUP_SPECIALTY_APPS ]]; then
  try $(while read in; do echo "$in" | grep '#' > /dev/null; if [ $? -ne 0 ]; then if [ "$in" != "" ]; then brew $in || true; fi; fi; done < $ROOT/brew/Brewfile-PersonalApps > /dev/null 2>/tmp/dev-strap.err)
  if [[ $? -ne 0 ]]; then
      cat /tmp/dev-strap.err
      rm /tmp/dev-strap.err
  fi
  next
else
  skip
fi

step "Installing Internet Explorer VMs: "
if [[ $SETUP_IE ]]; then
  # Prompt user for versions wanted
  menu=(whiptail --separate-output --title "Internet Explorer Setup" --checklist "\nSelect the versions of Internet Explorer to install:\n\n[spacebar] = toggle on/off" 0 0 0)
  options=(1 "Internet Explorer 6 w/ winXP" off
          2 "Internet Explorer 7 w/ winXP" off
          3 "Internet Explorer 8 w/ winXP" off
          4 "Internet Explorer 9 w/ win7" off
          5 "Internet Explorer 10 w/ win7" off
          6 "Internet Explorer 11 w/ win7" on)
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

  SELECTED_IE_VERSIONS=""

  for choice in $choices
  do
    case $choice in
    1)
        SELECTED_IE_VERSIONS="$SELECTED_IE_VERSIONS 6"
    ;;
    2)
        SELECTED_IE_VERSIONS="$SELECTED_IE_VERSIONS 7"
    ;;
    3)
        SELECTED_IE_VERSIONS="$SELECTED_IE_VERSIONS 8"
    ;;
    4)
        SELECTED_IE_VERSIONS="$SELECTED_IE_VERSIONS 9"
    ;;
    5)
        SELECTED_IE_VERSIONS="$SELECTED_IE_VERSIONS 10"
    ;;
    6)
        SELECTED_IE_VERSIONS="$SELECTED_IE_VERSIONS 11"
    ;;
    esac
  done

  SELECTED_IE_VERSIONS=$(echo $SELECTED_IE_VERSIONS | sed 's/^ *//')

  # Requires virtual box
  stat /Applications/VirtualBox.app > /dev/null 2>/dev/null
  if [[ $? -ne 0 ]]; then
    stat ~/Applications/VirtualBox.app > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      # No virtualbox install it
      try brew cask install virtualbox > /dev/null 2>/tmp/dev-strap.err
      if [[ $? -ne 0 ]]; then
          cat /tmp/dev-strap.err
          rm /tmp/dev-strap.err
      fi
    fi
  fi

  try curl -s https://raw.githubusercontent.com/xdissent/ievms/master/ievms.sh | env IEVMS_VERSIONS="$SELECTED_IE_VERSIONS" bash
  next
else
  skip
fi

step "Installing .NET development IDE Xamarin Studio: "
if [[ $SETUP_XAMARIN ]]; then
  try brew cask install xamarin-studio > /dev/null 2>/dev/null
  try brew cask install mono-mdk > /dev/null 2>/dev/null
  next
else
  skip
fi

exit 0
