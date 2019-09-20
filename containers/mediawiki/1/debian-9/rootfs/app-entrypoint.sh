#!/bin/bash -e

. /opt/bitnami/base/functions
. /opt/bitnami/base/helpers

print_welcome_page

if [[ "$1" == "nami" && "$2" == "start" ]] || [[ "$1" == "/init.sh" ]]; then
  . /mediawiki-init.sh
  nami_initialize apache php mysql-client mediawiki
  info "Starting mediawiki... "
fi

exec tini -- "$@"
