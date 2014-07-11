# Project root to use for self referencing other files
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"

# Project version
DEV_STRAP_VERSION="0.1"

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
