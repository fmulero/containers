#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

readonly query="SELECT upstream_node_id FROM repmgr.nodes WHERE node_id=$(repmgr_get_node_id)"
readonly new_upstream_node_id="$(echo "$query" | BITNAMI_DEBUG=true postgresql_execute "$REPMGR_DATABASE" "$POSTGRESQL_REPLICATION_USER" "$POSTGRESQL_REPLICATION_PASSWORD" "" "" "-tA")"
if [[ -n "$new_upstream_node_id" ]]; then
    # shellcheck disable=SC2154
    echo "$header Locking standby (new_upstream_node_id=$new_upstream_node_id)..."
    echo "$new_upstream_node_id" > "$REPMGR_STANDBY_ROLE_LOCK_FILE_NAME"
fi
