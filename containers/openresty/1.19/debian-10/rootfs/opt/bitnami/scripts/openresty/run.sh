#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose

# Load libraries
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libopenresty.sh

# Load OpenResty environment variables
. /opt/bitnami/scripts/openresty-env.sh

info "** Starting OpenResty **"
exec "${OPENRESTY_BIN_DIR}/openresty" -c "$OPENRESTY_CONF_FILE" -g "daemon off;"
