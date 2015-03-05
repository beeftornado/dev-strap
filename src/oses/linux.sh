#!/bin/bash
sudo apt-get install build-essential
sudo apt-get install libreadline-gplv2-dev libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev
sudo apt-get install libmysqlclient-dev python-dev
sudo apt-get install libevent-dev
sudo apt-get install python
sudo easy_install pip

# mssql drivers (if you need them, but nice to have)
sudo apt-get install unixodbc-dev libmyodbc odbc-postgresql tdsodbc unixodbc-bin

sudo apt-get install python-software-properties python g++ make
sudo add-apt-repository ppa:chris-lea/node.js
sudo apt-get update
sudo apt-get install nodejs

sudo pip install virtualenv virtualenvwrapper

source /usr/local/bin/virtualenvwrapper.sh

echo "export WORKON_HOME=\"$HOME/.virtualenvs\"" >> ~/.bashrc
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc

echo -n "Type the name for your python virtual environment followed by [ENTER]:"
read vname

mkvirtualenv "$vname"
workon "$vname"

if [ -f requirements.txt ]; then
    # install required python modules
    pip install -r requirements.txt
fi
if [ -f src/requirements.txt ]; then
    # install required python modules
    pip install -r src/requirements.txt
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

sudo apt-get install mongodb

echo "DONE"
