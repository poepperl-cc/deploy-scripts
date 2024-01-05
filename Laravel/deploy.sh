#!/bin/bash

OLD_PWD=$(pwd)

# Edit the settings below, so the script fits your needs
APACHEUSER=www-data
APACHEGROUP=www-data

# Function to display help text
show_help() {
  echo "Usage: $0 [OPTIONS] [DIRECTORY]"
  echo "Deploy and update the git-repo in the specified DIRECTORY. If no directory is given, the current directory will be used."
  echo
  echo "Options:"
  echo "  -h, --help    Display this help text"
  echo "  -f            Force update, checkout and installation of PHP an JS dependencies"
  echo "  -p            Fix file permissions only"
  exit 0
}

permissions() {
  echo Fixing permissions of $(pwd) ...

  sudo su <<-EOF
  chown -R $APACHEUSER:$APACHEGROUP .
  find . -type f -exec chmod 664 {} \;
  find . -type d -exec chmod 775 {} \;
  chmod a+x artisan
EOF
}

# Parse options
options=$(getopt -o hfp --long help -n "$0" -- "$@")

eval set -- "$options"

ONLY_FIX_PERMISSIONS=false
FORCE=false

# Durchlaufe die Argumente
while true; do
  case "$1" in
    -f)
      FORCE=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    -p)
      ONLY_FIX_PERMISSIONS=true
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      show_help
      exit 1
      ;;
  esac
done

if [ $# -eq 0 ]; then
    DIRECTORY="$OLD_PWD"
else 
    DIRECTORY="$1"
fi

cd "$DIRECTORY"

if [ $ONLY_FIX_PERMISSIONS = true ]; then
    permissions
    cd "$OLD_PWD"
    exit 0
fi

echo Deploying $(pwd) ...

git fetch --all

UPSTREAM='@{u}'
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

if [ $LOCAL = $REMOTE ]&& [ "$FORCE" = false ]; then
    echo "Up-to-date" 
elif [ $LOCAL = $BASE ] || [ "$FORCE" = true ]; then
    permissions

    git pull
    composer install
    npm i

    php artisan cache:clear
    php artisan view:clear
    php artisan config:clear
    php artisan event:clear
    php artisan route:clear

    php artisan view:cache
    php artisan config:cache
    php artisan event:cache
    php artisan route:cache
    
    permissions

    php artisan queue:restart

elif [ $REMOTE = $BASE ]; then
    echo "Need to push"
else
    echo "Branches have diverged, you must merge them prior to deploying."
fi

cd "$OLD_PWD"