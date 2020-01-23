#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose
# shellcheck disable=SC1090
# shellcheck disable=SC1091

. "$REPMGR_EVENTS_DIR/execs/includes/anotate_event_processing.sh"
. "$REPMGR_EVENTS_DIR/execs/includes/unlock_primary.sh"
