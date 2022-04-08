#!/bin/bash

# shellcheck disable=SC1090,SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose

# Load Ghost environment
. /opt/bitnami/scripts/ghost-env.sh

# Load libraries
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libghost.sh

# Constants
declare -a args=("run" "$@")

info "** Starting Ghost **"
cd "$GHOST_BASE_DIR" || false
if am_i_root; then
    exec gosu "$GHOST_DAEMON_USER" ghost "${args[@]}"
else
    exec ghost "${args[@]}"
fi
