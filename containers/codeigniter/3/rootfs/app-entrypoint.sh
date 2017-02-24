#!/bin/bash -e
. /opt/bitnami/base/functions

print_welcome_page
check_for_updates &

PROJECT_DIRECTORY=/app/$CODEIGNITER_PROJECT_NAME
DEPLOY="$@"

echo "Starting application ..."

if [ "$1" == "php" -a "$2" == "-S" ] ; then
    if [ ! -d $PROJECT_DIRECTORY ] ; then
      log "Creating example Codeigniter application"
      nami execute codeigniter createProject --databaseServerHost $MARIADB_HOST --databaseServerPort $MARIADB_PORT --databaseAdminUser $MARIADB_USER $CODEIGNITER_PROJECT_NAME | grep -v undefined
      log "Codeigniter app created"
    else
      log "App already created"
      cd $PROJECT_DIRECTORY
    fi
  DEPLOY="$@ -t $PROJECT_DIRECTORY"
fi

exec tini -- $DEPLOY
