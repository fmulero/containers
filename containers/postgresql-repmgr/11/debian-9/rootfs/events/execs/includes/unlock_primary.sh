#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purpose
# shellcheck disable=SC2154

echo "$header Unlocking primary..."
rm -f "$REPMGR_PRIMARY_ROLE_LOCK_FILE_NAME"
