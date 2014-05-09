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

echo

confirm "Do you want python setup and configured (python, pip, virtualenv)?"
SETUP_PYTHON=$?

confirm "Do you want nodejs setup and configured (node, nvm)?"
SETUP_NODEJS=$?

confirm "Do you want ruby setup and configured (ruby, rvm)?"
SETUP_RUBY=$?

confirm "Do you want database support (mysql, mongo)?"
SETUP_DB=$?

#confirm "Do you want to install the list of suggested homebrew apps? (see Brewfile)"
#SETUP_BREWFILE=$?

echo

step "Installing homebrew: "
if [ ! -f /usr/local/bin/brew ]; then
  try ruby -e "$(\curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
fi
next

#step "Checking homebrew: "
#try brew doctor > /dev/null
#try brew prune > /dev/null
#next

step "Bootstrapping homebrew: "
egrep "PATH.*/usr/local/bin" ~/.bashrc >/dev/null
if [[ $? -ne 0 ]]; then
  try echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
fi
next

step "Installing python: "
if [[ $SETUP_PYTHON -eq 1 ]]; then
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
if [[ $SETUP_PYTHON -eq 1 ]]; then
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
fi
next

step "Installing mysql: "
if [[ $SETUP_DB -eq 1 ]]; then
    brew list mysql > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install mysql > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing mongodb: "
if [[ $SETUP_DB -eq 1 ]]; then
    brew list mongodb > /dev/null 2>/dev/null
    if [[ $? -ne 0 ]]; then
      try brew install mongodb > /dev/null 2>/dev/null
    fi
    next
else
    skip
fi

step "Installing node version manager: "
if [[ $SETUP_NODEJS -eq 1 ]]; then
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
if [[ $SETUP_NODEJS -eq 1 ]]; then
    try nvm install 0.10 > /dev/null 2>/dev/null
    try nvm alias default v0.10 >/dev/null 2>/dev/null
    next
else
    skip
fi

step "Installing python virtual env: "
if [[ $SETUP_PYTHON -eq 1 ]]; then
    try pip install virtualenv virtualenvwrapper > /dev/null 2>/dev/null
    next
else
    skip
fi

step "Bootstrapping virtualenvwrapper: "
if [[ $SETUP_PYTHON -eq 1 ]]; then
    # Find the virtualenvwrapper shell script
    if [ -f /usr/local/bin/virtualenvwrapper.sh ]; then
      VE_WRAPPER_LOC="/usr/local/bin/virtualenvwrapper.sh"
    fi
    if [ -f /usr/local/share/python/virtualenvwrapper.sh ]; then
      VE_WRAPPER_LOC="/usr/local/share/python/virtualenvwrapper.sh"
    fi
    try source $VE_WRAPPER_LOC > /dev/null 2>/dev/null

    egrep "PATH.*/usr/local/share/npm/bin" ~/.bashrc >/dev/null
    if [[ $? -ne 0 ]]; then
      try echo 'export PATH=/usr/local/share/npm/bin:$PATH' >> ~/.bashrc
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

step "Installing ruby version manager: "
if [[ $SETUP_RUBY -eq 1 ]]; then
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
if [[ $SETUP_RUBY -eq 1 ]]; then
    try $RVM_PATH/bin/rvm install 1.9.2 > /dev/null 2>/tmp/ruby-install.err
    if [[ $? -ne 0 ]]; then
        cat /tmp/ruby-install.err
        rm /tmp/ruby-install.err
    fi
    next
else
    skip
fi

exit 0

echo -n "Type the name for your python virtual environment followed by [ENTER]:"
read vname

mkvirtualenv "$vname"
workon "$vname"

if [ -f requirements.txt ]; then
  # install required python modules
  pip install -r requirements.txt -i https://pypi.prod.hulu.com/simple
fi
if [ -f src/requirements.txt ]; then
  # install required python modules
  pip install -r src/requirements.txt -i https://pypi.prod.hulu.com/simple
fi

if [ -f package.json ]; then
  # install node.js and npm package manager (for node.js packages)
  npm install .   # if there's a package.json file
else
  # ...and if not
  npm install coffee-script@1.4.0 -g
  npm install less -g
  npm install uglify-js -g
fi

echo ""
echo "To work on this project in the future, you will need to run:"
echo ""
echo "workon $vname"
echo ""

echo "DONE!"
