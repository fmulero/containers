#!/bin/bash -e
. /opt/bitnami/base/functions
. /opt/bitnami/base/helpers

print_welcome_page
check_for_updates &

# Adding cron entries
ln -fs /opt/bitnami/moodle/conf/cron /etc/cron.d/moodle

if [[ "$1" == "nami" && "$2" == "start" ]] || [[ "$1" == "/init.sh" ]]; then
  nami_initialize apache php moodle
  info "Starting moodle..."
fi

exec tini -- "$@"
