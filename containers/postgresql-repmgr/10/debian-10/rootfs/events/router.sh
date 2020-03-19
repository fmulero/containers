#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose

# Load libraries
. /opt/bitnami/scripts/librepmgr.sh
. /opt/bitnami/scripts/libpostgresql.sh

eval "$(repmgr_env)"
eval "$(postgresql_env)"

echo "[REPMGR EVENT] Node id: $1; Event type: $2; Success [1|0]: $3; Time: $4;  Details: $5"
event_script="$REPMGR_EVENTS_DIR/execs/$2.sh"
echo "Looking for the script: $event_script"
if [[ -f "$event_script" ]]; then
    echo "[REPMGR EVENT] will execute script '$event_script' for the event"
    . "$event_script"
else
    echo "[REPMGR EVENT] no script '$event_script' found. Skipping..."
fi
