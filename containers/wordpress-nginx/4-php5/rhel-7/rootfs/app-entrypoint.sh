#!/bin/bash -e

. /opt/bitnami/base/functions
. /opt/bitnami/base/helpers

print_welcome_page

if [[ "$1" == "nami" && "$2" == "start" ]] || [[ "$1" == "./run.sh" ]]; then
  . /init.sh
  nami_initialize nginx php mysql-client wordpress
  info "Starting wordpress... "
fi

exec tini -- "$@"
