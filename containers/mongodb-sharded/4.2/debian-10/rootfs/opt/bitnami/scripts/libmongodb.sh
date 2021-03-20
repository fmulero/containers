#!/bin/bash

#
# Bitnami MongoDB library

# shellcheck disable=SC1091
# shellcheck disable=SC2120
# shellcheck disable=SC2119

# Load Generic Libraries
. /opt/bitnami/scripts/libfile.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libservice.sh
. /opt/bitnami/scripts/libvalidations.sh
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/libnet.sh

########################
# Validate settings in MONGODB_* env. variables
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_validate() {
    info "Validating settings in MONGODB_* env vars..."

    local error_message=""
    local -r replicaset_error_message="In order to configure MongoDB replica set authentication you \
need to provide the MONGODB_REPLICA_SET_KEY on every node, specify MONGODB_ROOT_PASSWORD \
in the primary node and MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD in the rest of nodes"
    local error_code=0

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }

    if [[ -n "$MONGODB_REPLICA_SET_MODE" ]]; then
        if [[ -z "$MONGODB_ADVERTISED_HOSTNAME" ]]; then
            warn "In order to use hostnames instead of IPs your should set MONGODB_ADVERTISED_HOSTNAME"
        fi
        if [[ "$MONGODB_REPLICA_SET_MODE" =~ ^(secondary|arbiter|hidden) ]]; then
            if [[ -z "$MONGODB_INITIAL_PRIMARY_HOST" ]]; then
                error_message="In order to configure MongoDB as a secondary or arbiter node \
you need to provide the MONGODB_INITIAL_PRIMARY_HOST env var"
                print_validation_error "$error_message"
            fi
            if { [[ -n "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" ]] && [[ -z "$MONGODB_REPLICA_SET_KEY" ]]; } || \
               { [[ -z "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" ]] && [[ -n "$MONGODB_REPLICA_SET_KEY" ]]; }; then
                print_validation_error "$replicaset_error_message"
            fi
            if [[ -n "$MONGODB_ROOT_PASSWORD" ]]; then
                error_message="MONGODB_ROOT_PASSWORD shouldn't be set on a 'non-primary' node"
                print_validation_error "$error_message"
            fi
        elif [[ "$MONGODB_REPLICA_SET_MODE" = "primary" ]]; then
            if { [[ -n "$MONGODB_ROOT_PASSWORD" ]] && [[ -z "$MONGODB_REPLICA_SET_KEY" ]] ;} || \
               { [[ -z "$MONGODB_ROOT_PASSWORD" ]] && [[ -n "$MONGODB_REPLICA_SET_KEY" ]] ;}; then
                print_validation_error "$replicaset_error_message"
            fi
            if [[ -n "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" ]]; then
                error_message="MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD shouldn't be set on a 'primary' node"
                print_validation_error "$error_message"
            fi
            if [[ -z "$MONGODB_ROOT_PASSWORD" ]] && ! is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
                error_message="The MONGODB_ROOT_PASSWORD environment variable is empty or not set. \
Set the environment variable ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. \
This is only recommended for development."
                print_validation_error "$error_message"
            fi
        else
            error_message="You set the environment variable MONGODB_REPLICA_SET_MODE with an invalid value. \
Available options are 'primary/secondary/arbiter/hidden'"
            print_validation_error "$error_message"
        fi
    fi

    if [[ -n "$MONGODB_REPLICA_SET_KEY" ]] && (( ${#MONGODB_REPLICA_SET_KEY} < 5 )); then
        error_message="MONGODB_REPLICA_SET_KEY must be, at least, 5 characters long!"
        print_validation_error "$error_message"
    fi

    if is_boolean_yes "$ALLOW_EMPTY_PASSWORD"; then
        warn "You set the environment variable ALLOW_EMPTY_PASSWORD=${ALLOW_EMPTY_PASSWORD}. For safety reasons, do not use this flag in a production environment."
    elif [[ -n "$MONGODB_USERNAME" ]] && [[ -z "$MONGODB_PASSWORD" ]]; then
        error_message="The MONGODB_PASSWORD environment variable is empty or not set. Set the environment variable ALLOW_EMPTY_PASSWORD=yes to allow the container to be started with blank passwords. This is only recommended for development."
        print_validation_error "$error_message"
    fi

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

########################
# Copy mounted configuration files
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_copy_mounted_config() {
    if ! is_dir_empty "$MONGODB_MOUNTED_CONF_DIR"; then
        if ! cp -Lr "$MONGODB_MOUNTED_CONF_DIR"/* "$MONGODB_CONF_DIR"; then
            error "Issue copying mounted configuration files from $MONGODB_MOUNTED_CONF_DIR to $MONGODB_CONF_DIR. Make sure you are not mounting configuration files in $MONGODB_CONF_DIR and $MONGODB_MOUNTED_CONF_DIR at the same time"
            exit 1
        fi
    fi
}

########################
# Execute an arbitrary query/queries against the running MongoDB service
# Stdin:
#   Query/queries to execute
# Arguments:
#   $1 - User to run queries
#   $2 - Password
#   $3 - Database where to run the queries
#   $4 - Host (default to result of get_mongo_hostname function)
#   $5 - Port (default $MONGODB_PORT_NUMBER)
#   $6 - Extra arguments (default $MONGODB_CLIENT_EXTRA_FLAGS)
# Returns:
#   None
########################
mongodb_execute() {
    local -r user="${1:-}"
    local -r password="${2:-}"
    local -r database="${3:-}"
    local -r host="${4:-$(get_mongo_hostname)}"
    local -r port="${5:-$MONGODB_PORT_NUMBER}"
    local -r extra_args="${6:-$MONGODB_CLIENT_EXTRA_FLAGS}"
    local result
    local final_user="$user"
    # If password is empty it means no auth, do not specify user
    [[ -z "$password" ]] && final_user=""

    local -a args=("--host" "$host" "--port" "$port")
    [[ -n "$final_user" ]] && args+=("-u" "$final_user")
    [[ -n "$password" ]] && args+=("-p" "$password")
    [[ -n "$extra_args" ]] && args+=($extra_args)
    [[ -n "$database" ]] && args+=("$database")

    "$MONGODB_BIN_DIR/mongo" "${args[@]}"
}

########################
# Determine the hostname by which to contact the locally running mongo daemon
# Returns:
#   The value of $MONGODB_ADVERTISED_HOSTNAME or the current host address
########################
get_mongo_hostname() {
    if [[ -n "$MONGODB_ADVERTISED_HOSTNAME" ]]; then
        echo "$MONGODB_ADVERTISED_HOSTNAME"
    else
        get_machine_ip
    fi
}

########################
# Drop local Database
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_drop_local_database() {
    info "Dropping local database to reset replica set setup..."

    local command=("mongodb_execute")
    [[ -n "$MONGODB_PASSWORD" ]] && command=("${command[@]}" "$MONGODB_USERNAME" "$MONGODB_PASSWORD")
    "${command[@]}" <<EOF
db.getSiblingDB('local').dropDatabase()
EOF
}

########################
# Check if MongoDB is running
# Globals:
#   MONGODB_PID_FILE
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_mongodb_running() {
    local pid
    pid="$(get_pid_from_file "$MONGODB_PID_FILE")"

    if [[ -z "$pid" ]]; then
        false
    else
        is_service_running "$pid"
    fi
}

########################
# Check if MongoDB is not running
# Globals:
#   MONGODB_PID_FILE
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_mongodb_not_running() {
    ! is_mongodb_running
    return "$?"
}

########################
# Retart MongoDB service
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_restart() {
    mongodb_stop
    mongodb_start_bg
}

########################
# Start MongoDB server in the background and waits until it's ready
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - Path to MongoDB configuration file
# Returns:
#   None
#########################
mongodb_start_bg() {
    # Use '--fork' option to enable daemon mode
    # ref: https://docs.mongodb.com/manual/reference/program/mongod/#cmdoption-mongod-fork
    local -r conf_file="${1:-$MONGODB_CONF_FILE}"
    local flags=("--fork" "--config=$conf_file")
    [[ -z "${MONGODB_EXTRA_FLAGS:-}" ]] || flags+=(${MONGODB_EXTRA_FLAGS})

    debug "Starting MongoDB in background..."

    is_mongodb_running && return

    if am_i_root; then
        debug_execute gosu "$MONGODB_DAEMON_USER" "$MONGODB_BIN_DIR/mongod" "${flags[@]}"
    else
       debug_execute "$MONGODB_BIN_DIR/mongod" "${flags[@]}"
    fi

    # wait until the server is up and answering queries
    if ! retry_while "mongodb_is_mongodb_started" "$MONGODB_MAX_TIMEOUT"; then
        error "MongoDB did not start"
        exit 1
    fi
}

########################
# Check if mongo is accepting requests
# Globals:
#   MONGODB_DATABASE
# Arguments:
#   None
# Returns:
#   Boolean
#########################
mongodb_is_mongodb_started() {
    local result

    result=$(mongodb_execute 2>/dev/null <<EOF
db
EOF
)
   [[ -n "$result" ]]
}

########################
# Stop MongoDB
# Globals:
#   MONGODB_PID_FILE
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_stop() {
    ! is_mongodb_running && return
    info "Stopping MongoDB..."

    stop_service_using_pid "$MONGODB_PID_FILE"
    if ! retry_while "is_mongodb_not_running" "$MONGODB_MAX_TIMEOUT"; then
        error "MongoDB failed to stop"
        exit 1
    fi
}

########################
# Apply regex in MongoDB configuration file
# Globals:
#   MONGODB_CONF_FILE
# Arguments:
#   $1 - match regex
#   $2 - substitute regex
# Returns:
#   None
#########################
mongodb_config_apply_regex() {
    local -r match_regex="${1:?match_regex is required}"
    local -r substitute_regex="${2:?substitute_regex is required}"
    local -r conf_file_path="${3:-$MONGODB_CONF_FILE}"
    local mongodb_conf

    mongodb_conf="$(sed -E "s@$match_regex@$substitute_regex@" "$conf_file_path")"
    echo "$mongodb_conf" > "$conf_file_path"
}

########################
# Change common logging settings
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_set_log_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"
    if ! mongodb_is_file_external "$conf_file_name"; then
        if [[ -n "$MONGODB_DISABLE_SYSTEM_LOG" ]]; then
            mongodb_config_apply_regex "quiet:.*" "quiet: $({ is_boolean_yes "$MONGODB_DISABLE_SYSTEM_LOG" && echo 'true';} || echo 'false')" "$conf_file_path"
        fi
        if [[ -n "$MONGODB_SYSTEM_LOG_VERBOSITY" ]]; then
            mongodb_config_apply_regex "verbosity:.*" "verbosity: $MONGODB_SYSTEM_LOG_VERBOSITY" "$conf_file_path"
        fi
    else
        debug "$conf_file_name mounted. Skipping setting log settings"
    fi
}

########################
# Change common storage settings
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_set_storage_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    if ! mongodb_is_file_external "$conf_file_name"; then
        if [[ -n "$MONGODB_ENABLE_DIRECTORY_PER_DB" ]]; then
            mongodb_config_apply_regex "directoryPerDB:.*" "directoryPerDB: $({ is_boolean_yes "$MONGODB_ENABLE_DIRECTORY_PER_DB" && echo 'true';} || echo 'false')" "$conf_file_path"
        fi
    else
        debug "$conf_file_name mounted. Skipping setting storage settings"
    fi
}

########################
# Change common network settings
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_set_net_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    if ! mongodb_is_file_external "$conf_file_name"; then
        if [[ -n "$MONGODB_PORT_NUMBER" ]]; then
            mongodb_config_apply_regex "port:.*" "port: $MONGODB_PORT_NUMBER" "$conf_file_path"
        fi
        if [[ -n "$MONGODB_ENABLE_IPV6" ]]; then
            mongodb_config_apply_regex "directoryPerDB:.*" "directoryPerDB: $({ is_boolean_yes "$MONGODB_ENABLE_IPV6" && echo 'true';} || echo 'false')" "$conf_file_path"
        fi
    else
        debug "$conf_file_name mounted. Skipping setting port and IPv6 settings"
    fi
}
########################
# Change bind ip address to 0.0.0.0
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_set_listen_all_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    if ! mongodb_is_file_external "$conf_file_name"; then
        mongodb_config_apply_regex "#?bindIp:.*" "#bindIp:" "$conf_file_path"
        mongodb_config_apply_regex "#?bindIpAll:.*" "bindIpAll: true" "$conf_file_path"
    else
        debug "$conf_file_name mounted. Skipping IP binding to all addresses"
    fi
}

########################
# Disable javascript
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_disable_javascript_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    if ! mongodb_is_file_external "$conf_file_name"; then
        mongodb_config_apply_regex "#?security:" "security:\n  javascriptEnabled: false" "$conf_file_path"
    else
        debug "$conf_file_name mounted. Skipping disabling javascript"
    fi
}


########################
# Enable Auth
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Return
#   None
#########################
mongodb_set_auth_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    local authorization

    if ! mongodb_is_file_external "$conf_file_name"; then
        if [[ -n "$MONGODB_ROOT_PASSWORD" ]] || [[ -n "$MONGODB_PASSWORD" ]]; then
            authorization="$(yq read "$MONGODB_CONF_FILE" security.authorization)"
            if [[ "$authorization" = "disabled" ]]; then

                info "Enabling authentication..."
                # TODO: replace 'sed' calls with 'yq' once 'yq write' does not remove comments
                mongodb_config_apply_regex "#?authorization:.*" "authorization: enabled" "$conf_file_path"
                mongodb_config_apply_regex "#?enableLocalhostAuthBypass:.*" "enableLocalhostAuthBypass: false" "$conf_file_path"
            fi
        fi
    else
        debug "$conf_file_name mounted. Skipping authorization enabling"
    fi
}

########################
# Enable ReplicaSetMode
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_set_replicasetmode_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    if ! mongodb_is_file_external "$conf_file_name"; then
        mongodb_config_apply_regex "#?replication:.*" "replication:" "$conf_file_path"
        mongodb_config_apply_regex "#?replSetName:" "replSetName:" "$conf_file_path"
        mongodb_config_apply_regex "#?enableMajorityReadConcern:.*" "enableMajorityReadConcern:" "$conf_file_path"
        if [[ -n "$MONGODB_REPLICA_SET_NAME" ]]; then
            mongodb_config_apply_regex "replSetName:.*" "replSetName: $MONGODB_REPLICA_SET_NAME" "$conf_file_path"
        fi
        if [[ -n "$MONGODB_ENABLE_MAJORITY_READ" ]]; then
            mongodb_config_apply_regex "enableMajorityReadConcern:.*" "enableMajorityReadConcern: $({ is_boolean_yes "$MONGODB_ENABLE_MAJORITY_READ" && echo 'true';} || echo 'false')" "$conf_file_path"
        fi
    else
        debug "$conf_file_name mounted. Skipping replicaset mode enabling"
    fi
}

########################
# Create the appropriate users
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_create_users() {
    local result

    info "Creating users..."
    if [[ -n "$MONGODB_ROOT_PASSWORD" ]] && ! [[ "$MONGODB_REPLICA_SET_MODE"  =~ ^(secondary|arbiter|hidden) ]]; then
        info "Creating root user..."
        result=$(mongodb_execute "" "" "" "127.0.0.1" <<EOF
db.getSiblingDB('admin').createUser({ user: 'root', pwd: '$MONGODB_ROOT_PASSWORD', roles: [{role: 'root', db: 'admin'}] })
EOF
)
    fi

    if [[ -n "$MONGODB_USERNAME" ]] && [[ -n "$MONGODB_PASSWORD" ]] && [[ -n "$MONGODB_DATABASE" ]]; then
        info "Creating '$MONGODB_USERNAME' user..."

        result=$(mongodb_execute 'root' "$MONGODB_ROOT_PASSWORD" "" "127.0.0.1" <<EOF
db.getSiblingDB('$MONGODB_DATABASE').createUser({ user: '$MONGODB_USERNAME', pwd: '$MONGODB_PASSWORD', roles: [{role: 'readWrite', db: '$MONGODB_DATABASE'}] })
EOF
)
    fi
    info "Users created"
}

########################
# Set the path to the keyfile in mongodb.conf
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_set_keyfile_conf() {
    local -r conf_file_path="${1:-$MONGODB_CONF_FILE}"
    local -r conf_file_name="${conf_file_path#"$MONGODB_CONF_DIR"}"

    if ! mongodb_is_file_external "$conf_file_name"; then
        mongodb_config_apply_regex "#?keyFile:.*" "keyFile: $MONGODB_KEY_FILE" "$conf_file_path"
    else
        debug "$conf_file_name mounted. Skipping keyfile location configuration"
    fi
}

########################
# Create the replica set key file
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - key
# Returns:
#   None
#########################
mongodb_create_keyfile() {
    local -r key="${1:?key is required}"

    if ! mongodb_is_file_external "keyfile"; then
        info "Writing keyfile for replica set authentication..."
        echo "$key" > "$MONGODB_KEY_FILE"

        chmod 600 "$MONGODB_KEY_FILE"

        if am_i_root; then
            configure_permissions "$MONGODB_KEY_FILE" "$MONGODB_DAEMON_USER" "$MONGODB_DAEMON_GROUP" "" "600"
        else
            chmod 600 "$MONGODB_KEY_FILE"
        fi
    else
        debug "keyfile mounted. Skipping keyfile generation"
    fi
}

########################
# Get if primary node is initialized
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - node
# Returns:
#   None
#########################
mongodb_is_primary_node_initiated() {
    local node="${1:?node is required}"
    local result
    result=$(mongodb_execute "root" "$MONGODB_ROOT_PASSWORD" "admin" "127.0.0.1" "$MONGODB_PORT_NUMBER" <<EOF
rs.initiate({"_id":"$MONGODB_REPLICA_SET_NAME", "members":[{"_id":0,"host":"$node:$MONGODB_PORT_NUMBER","priority":5}]})
EOF
)

    # Code 23 is considered OK
    # It indicates that the node is already initialized
    if grep -q "\"code\" : 23" <<< "$result"; then
        warn "Node already initialized."
        return 0
    fi

    if ! grep -q "\"ok\" : 1" <<< "$result"; then
        warn "Problem initiating replica set
            request: rs.initiate({\"_id\":\"$MONGODB_REPLICA_SET_NAME\", \"members\":[{\"_id\":0,\"host\":\"$node:$MONGODB_PORT_NUMBER\",\"priority\":5}]})
            response: $result"
        return 1
    fi
}


########################
# Get if secondary node is pending
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - node
# Returns:
#   Boolean
#########################
mongodb_is_secondary_node_pending() {
    local node="${1:?node is required}"
    local result

    result=$(mongodb_execute "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" "admin" "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" <<EOF
rs.add('$node:$MONGODB_PORT_NUMBER')
EOF
)
    # Error code 103 is considered OK.
    # It indicates a possiblely desynced configuration,
    # which will become resynced when the secondary joins the replicaset.
    if grep -q "\"code\" : 103" <<< "$result"; then
        warn "The ReplicaSet configuration is not aligned with primary node's configuration. Starting secondary node so it syncs with ReplicaSet..."
        return 0
    fi
    grep -q "\"ok\" : 1" <<< "$result"
}

########################
# Get if hidden node is pending
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - node
# Returns:
#   Boolean
#########################
mongodb_is_hidden_node_pending() {
    local node="${1:?node is required}"
    local result

    result=$(mongodb_execute "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" "admin" "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" <<EOF
rs.add({host: '$node:$MONGODB_PORT_NUMBER', hidden: true, priority: 0})
EOF
)
    # Error code 103 is considered OK.
    # It indicates a possiblely desynced configuration,
    # which will become resynced when the hidden joins the replicaset.
    if grep -q "\"code\" : 103" <<< "$result"; then
        warn "The ReplicaSet configuration is not aligned with primary node's configuration. Starting hidden node so it syncs with ReplicaSet..."
        return 0
    fi
    grep -q "\"ok\" : 1" <<< "$result"
}

########################
# Get if arbiter node is pending
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - node
# Returns:
#   Boolean
#########################
mongodb_is_arbiter_node_pending() {
    local node="${1:?node is required}"
    local result

    result=$(mongodb_execute "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" "admin" "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" <<EOF
rs.addArb('$node:$MONGODB_PORT_NUMBER')
EOF
)
    grep -q "\"ok\" : 1" <<< "$result"
}

########################
# Configure primary node
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - node
# Returns:
#   None
#########################
mongodb_configure_primary() {
    local -r node="${1:?node is required}"

    info "Configuring MongoDB primary node"
    wait-for-port --timeout 360 "$MONGODB_PORT_NUMBER"

    if ! retry_while "mongodb_is_primary_node_initiated $node" "$MONGODB_MAX_TIMEOUT"; then
        error "MongoDB primary node failed to get configured"
        exit 1
    fi
}

########################
# Wait for Confirmation
# Globals:
#   None
# Arguments:
#   $1 - node
# Returns:
#   Boolean
#########################
mongodb_wait_confirmation() {
    local -r node="${1:?node is required}"

    debug "Waiting until ${node} is added to the replica set..."
    if ! retry_while "mongodb_node_currently_in_cluster ${node}" "$MONGODB_MAX_TIMEOUT"; then
        error "Unable to confirm that ${node} has been added to the replica set!"
        exit 1
    else
        info "Node ${node} is confirmed!"
    fi
}

########################
# Check if primary node is ready
# Globals:
#   None
# Returns:
#   None
#########################
mongodb_is_primary_node_up() {
    local -r host="${1:?node is required}"
    local -r port="${2:?port is required}"
    local -r user="${3:?user is required}"
    local -r password="${4:-}"

    debug "Validating $host as primary node..."

    result=$(mongodb_execute "$user" "$password" "admin" "$host" "$port" <<EOF
db.isMaster().ismaster
EOF
)
    grep -q "true" <<< "$result"
}

########################
# Check if a MongoDB node is running
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   Boolean
#########################
mongodb_is_node_available() {
    local -r host="${1:?node is required}"
    local -r port="${2:?port is required}"
    local -r user="${3:?user is required}"
    local -r password="${4:-}"

    local result
    result=$(mongodb_execute "$user" "$password" "admin" "$host" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" <<EOF
db.getUsers()
EOF
)
    if ! grep -q "\"user\" :" <<< "$result"; then
        # If no password was provided on first run
        # it may be the case that DB is up but has no users
        [[ -z $password ]] && grep -q "\[\ \]" <<< "$result"
    fi
}

########################
# Wait for node
# Globals:
#   MONGODB_*
# Returns:
#   Boolean
#########################
mongodb_wait_for_node() {
    local -r host="${1:?node is required}"
    local -r port="${2:?port is required}"
    local -r user="${3:?user is required}"
    local -r password="${4:-}"
    debug "Waiting for primary node..."

    info "Trying to connect to MongoDB server $host..."
    if ! retry_while "wait-for-port --host $host --timeout 10 $port" "$MONGODB_MAX_TIMEOUT"; then
        error "Unable to connect to host $host"
        exit 1
    else
        info "Found MongoDB server listening at $host:$port !"
    fi

    if ! retry_while "mongodb_is_node_available $host $port $user $password" "$MONGODB_MAX_TIMEOUT"; then
        error "Node $host did not become available"
        exit 1
    else
        info "MongoDB server listening and working at $host:$port !"
    fi
}

########################
# Wait for primary node
# Globals:
#   MONGODB_*
# Returns:
#   Boolean
#########################
mongodb_wait_for_primary_node() {
    local -r host="${1:?node is required}"
    local -r port="${2:?port is required}"
    local -r user="${3:?user is required}"
    local -r password="${4:-}"
    debug "Waiting for primary node..."

    mongodb_wait_for_node "$host" "$port" "$user" "$password"

    debug "Waiting for primary host $host to be ready..."
    if ! retry_while "mongodb_is_primary_node_up $host $port $user $password" "$MONGODB_MAX_TIMEOUT"; then
        error "Unable to validate $host as primary node in the replica set scenario!"
        exit 1
    else
        info "Primary node ready."
    fi
}

########################
# Configure secondary node
# Globals:
#   None
# Arguments:
#   $1 - node
# Returns:
#   None
#########################
mongodb_configure_secondary() {
    local -r node="${1:?node is required}"

    mongodb_wait_for_primary_node "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD"

    if mongodb_node_currently_in_cluster "$node"; then
        info "Node currently in the cluster"
    else
        info "Adding node to the cluster"
        if ! retry_while "mongodb_is_secondary_node_pending $node" "$MONGODB_MAX_TIMEOUT"; then
            error "Secondary node did not get ready"
            exit 1
        fi
        mongodb_wait_confirmation "$node"
    fi
}

########################
# Configure hidden node
# Globals:
#   None
# Arguments:
#   $1 - node
# Returns:
#   None
#########################
mongodb_configure_hidden() {
    local -r node="${1:?node is required}"

    mongodb_wait_for_primary_node "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD"

    if mongodb_node_currently_in_cluster "$node"; then
        info "Node currently in the cluster"
    else
        info "Adding hidden node to the cluster"
        if ! retry_while "mongodb_is_hidden_node_pending $node" "$MONGODB_MAX_TIMEOUT"; then
            error "Hidden node did not get ready"
            exit 1
        fi
        mongodb_wait_confirmation "$node"
    fi
}


########################
# Configure arbiter node
# Globals:
#   None
# Arguments:
#   $1 - node
# Returns:
#   None
#########################
mongodb_configure_arbiter() {
    local -r node="${1:?node is required}"
    mongodb_wait_for_primary_node "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD"

    if mongodb_node_currently_in_cluster "$node"; then
        info "Node currently in the cluster"
    else
        info "Configuring MongoDB arbiter node"
        if ! retry_while "mongodb_is_arbiter_node_pending $node" "$MONGODB_MAX_TIMEOUT"; then
            error "Arbiter node did not get ready"
            exit 1
        fi
        mongodb_wait_confirmation "$node"
    fi
}

########################
# Get if the replica set in synced
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_is_not_in_sync(){
    local result

    result=$(mongodb_execute "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" "admin" "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" <<EOF
db.printSlaveReplicationInfo()
EOF
)

    grep -q -E "^[[:space:]]*0 secs" <<< "$result"
}

########################
# Wait until initial data sync complete
# Globals:
#   MONGODB_LOG_FILE
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_wait_until_sync_complete() {
    info "Waiting until initial data sync is complete..."

    if ! retry_while "mongodb_is_not_in_sync" "$MONGODB_MAX_TIMEOUT" 1; then
        error "Initial data sync did not finish after $MONGODB_MAX_TIMEOUT seconds"
        exit 1
    else
        info "initial data sync completed"
    fi
}

########################
# Get current status of the replicaset
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - node
# Returns:
#   None
#########################
mongodb_node_currently_in_cluster() {
    local -r node="${1:?node is required}"
    local result

    result=$(mongodb_execute "$MONGODB_INITIAL_PRIMARY_ROOT_USER" "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" "admin" "$MONGODB_INITIAL_PRIMARY_HOST" "$MONGODB_INITIAL_PRIMARY_PORT_NUMBER" <<EOF
rs.status().members
EOF
)
    grep -q -E "\"${node}(:[0-9]+)?\"" <<< "$result"
}

########################
# Configure Replica Set
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_configure_replica_set() {
    local node

    info "Configuring MongoDB replica set..."

    node=$(get_mongo_hostname)
    mongodb_restart

    case "$MONGODB_REPLICA_SET_MODE" in
        "primary" )
            mongodb_configure_primary "$node"
            ;;
        "secondary")
            mongodb_configure_secondary "$node"
            ;;
        "arbiter")
            mongodb_configure_arbiter "$node"
            ;;
        "hidden")
            mongodb_configure_hidden "$node"
            ;;
        "dynamic")
            # Do nothing
            ;;
    esac

    if [[ "$MONGODB_REPLICA_SET_MODE" = "secondary" ]]; then
        mongodb_wait_until_sync_complete
    fi
}


########################
# Configure permisions
# Globals:
#   None
# Arguments:
#   $1 - path array
#   $2 - user
#   $3 - group
#   $4 - mode for directories
#   $5 - mode for files
# Returns:
#   None
#########################
configure_permissions() {
    local -r path=${1:?path is required}
    local -r user=${2:?user is required}
    local -r group=${3:?group is required}
    local -r dir_mode=${4:-false}
    local -r file_mode=${5:-false}

    if [[ -e "$path" ]]; then
        if [[ -n $dir_mode ]] && [[ -n $file_mode ]]; then
            find -L "$path" -type d -exec chmod "$dir_mode" {} \;
        fi
        if [[ -n $file_mode ]]; then
            find -L "$path" -type f -exec chmod "$file_mode" {} \;
        fi
        chown -LR "$user":"$group" "$path"
    else
        warn "$path do not exist."
    fi
}

###############
# Initialize MongoDB service
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_initialize() {
    info "Initializing MongoDB..."

    rm -f "$MONGODB_PID_FILE"
    mongodb_copy_mounted_config
    mongodb_set_net_conf
    mongodb_set_log_conf
    mongodb_set_storage_conf
    is_boolean_yes "$MONGODB_DISABLE_JAVASCRIPT" && mongodb_disable_javascript_conf

    if is_dir_empty "$MONGODB_DATA_DIR/db"; then
        info "Deploying MongoDB from scratch..."
        ensure_dir_exists "$MONGODB_DATA_DIR/db"
        am_i_root && chown -R "$MONGODB_DAEMON_USER" "$MONGODB_DATA_DIR/db"

        mongodb_start_bg
        mongodb_create_users
        if [[ -n "$MONGODB_REPLICA_SET_MODE" ]]; then
            if [[ -n "$MONGODB_REPLICA_SET_KEY" ]]; then
                mongodb_create_keyfile "$MONGODB_REPLICA_SET_KEY"
                mongodb_set_keyfile_conf
            fi
            mongodb_set_replicasetmode_conf
            mongodb_set_listen_all_conf
            mongodb_configure_replica_set
        fi

        mongodb_stop
    else
        mongodb_set_auth_conf
        info "Deploying MongoDB with persisted data..."
        if [[ -n "$MONGODB_REPLICA_SET_MODE" ]]; then
            if [[ -n "$MONGODB_REPLICA_SET_KEY" ]]; then
                mongodb_create_keyfile "$MONGODB_REPLICA_SET_KEY"
                mongodb_set_keyfile_conf
            fi
            if [[ "$MONGODB_REPLICA_SET_MODE" = "dynamic" ]]; then
                mongodb_ensure_dynamic_mode_consistency
            fi
            mongodb_set_replicasetmode_conf
        fi
    fi

    mongodb_set_auth_conf
}

########################
# Check that the dynamic instance configuration is consistent
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_ensure_dynamic_mode_consistency() {
    if grep -q -E "^[[:space:]]*replSetName: $MONGODB_REPLICA_SET_NAME" "$MONGODB_CONF_FILE"; then
            info "ReplicaSetMode set to \"dynamic\" and replSetName different from config file."
            info "Dropping local database ..."
            mongodb_start_bg
            mongodb_drop_local_database
            mongodb_stop
    fi
}

########################
# Check if a givemongodb_sharded_is_join_shard_pendingted externally
# Globals:
#   MONGODB_*
# Arguments:
#   $1 - Filename
# Returns:
#   true if the file was mounted externally, false otherwise
#########################
mongodb_is_file_external() {
    local -r filename="${1:?file_is_missing}"
    if [[ -f "${MONGODB_MOUNTED_CONF_DIR}/${filename}" ]] || { [[ -f "${MONGODB_CONF_DIR}/${filename}" ]] && ! test -w "${MONGODB_CONF_DIR}/${filename}" ;}; then
        true
    else
        false
    fi
}

########################
# Run custom initialization scripts
# Globals:
#   MONGODB_*
# Arguments:
#   None
# Returns:
#   None
#########################
mongodb_custom_init_scripts() {
    local run_custom_init_scripts="no"
    if [[ -n "$MONGODB_REPLICA_SET_MODE" ]]; then
        if [[ "$MONGODB_REPLICA_SET_MODE" != "primary" ]]; then
            debug "Skipping loading custom scripts on non-primary nodes..."
        elif [[ -n $(find "$MONGODB_INITSCRIPTS_DIR/" -type f -regex ".*\.\(sh\|js\|js.gz\)") ]]; then
            if [[ -f "$MONGODB_VOLUME_DIR/mongodb/.user_scripts_initialized" ]]; then
                debug "Skipping loading custom scripts on container restarts..."
            else
                run_custom_init_scripts="yes"
            fi
        fi
    elif [[ -n $(find "$MONGODB_INITSCRIPTS_DIR/" -type f -regex ".*\.\(sh\|js\|js.gz\)") ]]; then
        if [[ -f "$MONGODB_VOLUME_DIR/mongodb/.user_scripts_initialized" ]]; then
            debug "Skipping loading custom scripts on container restarts..."
        else
            run_custom_init_scripts="yes"
        fi
    fi
    if is_boolean_yes "$run_custom_init_scripts"; then
        info "Loading user's custom files from $MONGODB_INITSCRIPTS_DIR ...";
        mongodb_start_bg
        local -r tmp_file=/tmp/filelist
        local mongo_user
        local mongo_pass
        if [[ -n "$MONGODB_ROOT_PASSWORD" ]];then
            mongo_user=root
            mongo_pass="$MONGODB_ROOT_PASSWORD"
        elif [[ -n "$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD" ]];then
            mongo_user=root
            mongo_pass="$MONGODB_INITIAL_PRIMARY_ROOT_PASSWORD"
        else
            mongo_user="$MONGODB_USERNAME"
            mongo_pass="$MONGODB_PASSWORD"
        fi
        find "$MONGODB_INITSCRIPTS_DIR" -type f -regex ".*\.\(sh\|js\|js.gz\)" | sort > $tmp_file
        while read -r f; do
            case "$f" in
                *.sh)
                    if [[ -x "$f" ]]; then
                        debug "Executing $f"; "$f"
                    else
                        debug "Sourcing $f"; . "$f"
                    fi
                    ;;
                *.js)    debug "Executing $f"; mongodb_execute "$mongo_user" "$mongo_pass" < "$f";;
                *.js.gz) debug "Executing $f"; gunzip -c "$f" | mongodb_execute "$mongo_user" "$mongo_pass";;
                *)        debug "Ignoring $f" ;;
            esac
        done < $tmp_file
        touch "$MONGODB_VOLUME_DIR"/mongodb/.user_scripts_initialized
    fi
}
