#!/bin/bash
#
# Bitnami Kafka library

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/bitnami/scripts/libfile.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libvalidations.sh

# Functions

########################
# Set a configuration setting value to a file
# Globals:
#   None
# Arguments:
#   $1 - file
#   $2 - key
#   $3 - values (array)
# Returns:
#   None
#########################
kafka_common_conf_set() {
    local file="${1:?missing file}"
    local key="${2:?missing key}"
    shift
    shift
    local values=("$@")

    if [[ "${#values[@]}" -eq 0 ]]; then
        stderr_print "missing value"
        return 1
    elif [[ "${#values[@]}" -ne 1 ]]; then
        for i in "${!values[@]}"; do
            kafka_common_conf_set "$file" "${key[$i]}" "${values[$i]}"
        done
    else
        value="${values[0]}"
        # Check if the value was set before
        if grep -q "^[#\\s]*$key\s*=.*" "$file"; then
            # Update the existing key
            replace_in_file "$file" "^[#\\s]*${key}\s*=.*" "${key}=${value}" false
        else
            # Add a new key
            printf '\n%s=%s' "$key" "$value" >>"$file"
        fi
    fi
}

########################
# Set a configuration setting value to server.properties
# Globals:
#   KAFKA_CONF_FILE
# Arguments:
#   $1 - key
#   $2 - values (array)
# Returns:
#   None
#########################
kafka_server_conf_set() {
    kafka_common_conf_set "$KAFKA_CONF_FILE" "$@"
}

########################
# Set a configuration setting value to producer.properties and consumer.properties
# Globals:
#   KAFKA_CONF_DIR
# Arguments:
#   $1 - key
#   $2 - values (array)
# Returns:
#   None
#########################
kafka_producer_consumer_conf_set() {
    kafka_common_conf_set "$KAFKA_CONF_DIR/producer.properties" "$@"
    kafka_common_conf_set "$KAFKA_CONF_DIR/consumer.properties" "$@"
}

########################
# Load global variables used on Kafka configuration
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   Series of exports to be used as 'eval' arguments
#########################
kafka_env() {
    cat <<"EOF"
export KAFKA_BASE_DIR="/opt/bitnami/kafka"
export KAFKA_VOLUME_DIR="/bitnami/kafka"
export KAFKA_HOME="$KAFKA_BASE_DIR"
export KAFKA_LOG_DIR="$KAFKA_BASE_DIR"/logs
export KAFKA_CONF_DIR="$KAFKA_BASE_DIR"/config
export KAFKA_CONF_FILE="$KAFKA_CONF_DIR"/server.properties
export KAFKA_MOUNTED_CONF_DIR="${KAFKA_MOUNTED_CONF_DIR:-${KAFKA_VOLUME_DIR}/config}"
export KAFKA_DATA_DIR="$KAFKA_VOLUME_DIR"/data
export KAFKA_INITSCRIPTS_DIR=/docker-entrypoint-initdb.d
export KAFKA_DAEMON_USER="kafka"
export KAFKA_DAEMON_GROUP="kafka"
export PATH="${KAFKA_BASE_DIR}/bin:$PATH"
export ALLOW_PLAINTEXT_LISTENER="${ALLOW_PLAINTEXT_LISTENER:-no}"
export KAFKA_INTER_BROKER_USER="${KAFKA_INTER_BROKER_USER:-user}"
export KAFKA_INTER_BROKER_PASSWORD="${KAFKA_INTER_BROKER_PASSWORD:-bitnami}"
export KAFKA_CLIENT_USER="${KAFKA_CLIENT_USER:-user}"
export KAFKA_CLIENT_PASSWORD="${KAFKA_CLIENT_PASSWORD:-bitnami}"
export KAFKA_HEAP_OPTS="${KAFKA_HEAP_OPTS:-"-Xmx1024m -Xms1024m"}"
export KAFKA_ZOOKEEPER_PASSWORD="${KAFKA_ZOOKEEPER_PASSWORD:-}"
export KAFKA_ZOOKEEPER_USER="${KAFKA_ZOOKEEPER_USER:-}"
export KAFKA_CFG_ADVERTISED_LISTENERS="${KAFKA_CFG_ADVERTISED_LISTENERS:-"PLAINTEXT://:9092"}"
export KAFKA_CFG_LISTENERS="${KAFKA_CFG_LISTENERS:-"PLAINTEXT://:9092"}"
export KAFKA_CFG_ZOOKEEPER_CONNECT="${KAFKA_CFG_ZOOKEEPER_CONNECT:-"localhost:2181"}"
export KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE="${KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE:-"true"}"
EOF
}

########################
# Create alias for environment variable, so both can be used
# Globals:
#   None
# Arguments:
#   $1 - Alias environment variable name
#   $2 - Original environment variable name
# Returns:
#   None
#########################
kafka_declare_alias_env() {
    local -r alias="${1:?missing environment variable alias}"
    local -r original="${2:?missing original environment variable}"
    if printenv "${original}" > /dev/null; then
        export "$alias"="${!original:-}"
    fi
}

########################
# Map Kafka legacy environment variables to the new names
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_create_alias_environment_variables() {
    suffixes=(
        "ADVERTISED_LISTENERS"
        "BROKER_ID"
        "DEFAULT_REPLICATION_FACTOR"
        "DELETE_TOPIC_ENABLE"
        "INTER_BROKER_LISTENER_NAME"
        "LISTENERS"
        "LISTENER_SECURITY_PROTOCOL_MAP"
        "LOG_DIRS"
        "LOG_FLUSH_INTERVAL_MESSAGES"
        "LOG_FLUSH_INTERVAL_MS"
        "LOG_MESSAGE_FORMAT_VERSION"
        "LOG_RETENTION_BYTES"
        "LOG_RETENTION_CHECK_INTERVALS_MS"
        "LOG_RETENTION_HOURS"
        "LOG_SEGMENT_BYTES"
        "MESSAGE_MAX_BYTES"
        "NUM_IO_THREADS"
        "NUM_NETWORK_THREADS"
        "NUM_PARTITIONS"
        "NUM_RECOVERY_THREADS_PER_DATA_DIR"
        "OFFSETS_TOPIC_REPLICATION_FACTOR"
        "SOCKET_RECEIVE_BUFFER_BYTES"
        "SOCKET_REQUEST_MAX_BYTES"
        "SOCKET_SEND_BUFFER_BYTES"
        "SSL_ENDPOINT_IDENTIFICATION_ALGORITHM"
        "TRANSACTION_STATE_LOG_MIN_ISR"
        "TRANSACTION_STATE_LOG_REPLICATION_FACTOR"
        "ZOOKEEPER_CONNECT"
        "ZOOKEEPER_CONNECTION_TIMEOUT_MS"
    )
    kafka_declare_alias_env "KAFKA_CFG_LOG_DIRS" "KAFKA_LOGS_DIRS"
    kafka_declare_alias_env "KAFKA_CFG_LOG_SEGMENT_BYTES" "KAFKA_SEGMENT_BYTES"
    kafka_declare_alias_env "KAFKA_CFG_MESSAGE_MAX_BYTES" "KAFKA_MAX_MESSAGE_BYTES"
    kafka_declare_alias_env "KAFKA_CFG_ZOOKEEPER_CONNECTION_TIMEOUT_MS" "KAFKA_ZOOKEEPER_CONNECT_TIMEOUT_MS"
    kafka_declare_alias_env "KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE" "KAFKA_AUTO_CREATE_TOPICS_ENABLE"
    kafka_declare_alias_env "KAFKA_CLIENT_USER" "KAFKA_BROKER_USER"
    kafka_declare_alias_env "KAFKA_CLIENT_PASSWORD" "KAFKA_BROKER_PASSWORD"
    for s in "${suffixes[@]}"; do
        kafka_declare_alias_env "KAFKA_CFG_${s}" "KAFKA_${s}"
    done
}

########################
# Validate settings in KAFKA_* env vars
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_validate() {
    debug "Validating settings in KAFKA_* env vars..."
    local error_code=0
    local internal_port
    local client_port

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }
    check_allowed_listener_port() {
        local -r total="$#"
        for i in $(seq 1 "$((total - 1))"); do
            for j in $(seq "$((i + 1))" "$total"); do
                if (( "${!i}" == "${!j}" )); then
                    print_validation_error "There are listeners bound to the same port"
                fi
            done
        done
    }
    check_conflicting_listener_ports() {
        local validate_port_args=()
        ! am_i_root && validate_port_args+=("-unprivileged")
        if ! err=$(validate_port "${validate_port_args[@]}" "$1"); then
            print_validation_error "An invalid port was specified in the environment variable KAFKA_CFG_LISTENERS: $err"
        fi
    }

    if [[ "${KAFKA_CFG_LISTENERS:-}" =~ INTERNAL:\/\/:([0-9]*) ]]; then
        internal_port="${BASH_REMATCH[1]}"
        check_allowed_listener_port "$internal_port"
    fi
    if [[ "${KAFKA_CFG_LISTENERS:-}" =~ CLIENT:\/\/:([0-9]*) ]]; then
        client_port="${BASH_REMATCH[1]}"
        check_allowed_listener_port "$client_port"
    fi
    [[ -n "${internal_port:-}" && -n "${client_port:-}" ]] && check_conflicting_listener_ports "$internal_port" "$client_port"
    if [[ -n "${KAFKA_PORT_NUMBER:-}" ]] || [[ -n "${KAFKA_CFG_PORT:-}" ]]; then
        warn "The environment variables KAFKA_PORT_NUMBER and KAFKA_CFG_PORT are deprecated, you can specify the port number to use for each listener using the KAFKA_CFG_LISTENERS environment variable instead."
    fi

    if is_boolean_yes "$ALLOW_PLAINTEXT_LISTENER"; then
        warn "You set the environment variable ALLOW_PLAINTEXT_LISTENER=$ALLOW_PLAINTEXT_LISTENER. For safety reasons, do not use this flag in a production environment."
    fi
    if [[ "${KAFKA_CFG_LISTENERS:-}" =~ SSL ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SSL ]]; then
        # DEPRECATED. Check for jks files in old conf directory to maintain compatibility with Helm chart.
        if ([[ ! -f "$KAFKA_BASE_DIR"/conf/certs/kafka.keystore.jks ]] || [[ ! -f "$KAFKA_BASE_DIR"/conf/certs/kafka.truststore.jks ]]) \
            && ([[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/kafka.keystore.jks ]] || [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/kafka.truststore.jks ]]); then
            print_validation_error "In order to configure the TLS encryption for Kafka you must mount your kafka.keystore.jks and kafka.truststore.jks certificates to the ${KAFKA_MOUNTED_CONF_DIR}/certs directory."
        fi
    elif [[ "${KAFKA_CFG_LISTENERS:-}" =~ SASL ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SASL ]]; then
        if [[ -z "$KAFKA_CLIENT_PASSWORD" ]] && [[ -z "$KAFKA_INTER_BROKER_PASSWORD" ]]; then
            print_validation_error "In order to configure SASL authentication for Kafka, you must provide the SASL credentials. Set the environment variables KAFKA_CLIENT_USER and KAFKA_CLIENT_PASSWORD, to configure the credentials for SASL authentication with clients, or set the environment variables KAFKA_INTER_BROKER_USER and KAFKA_INTER_BROKER_PASSWORD, to configure the credentials for SASL authentication between brokers."
        fi
    elif ! is_boolean_yes "$ALLOW_PLAINTEXT_LISTENER"; then
        print_validation_error "The KAFKA_CFG_LISTENERS environment variable does not configure a secure listener. Set the environment variable ALLOW_PLAINTEXT_LISTENER=yes to allow the container to be started with a plaintext listener. This is only recommended for development."
    fi

    [[ "$error_code" -eq 0 ]] || return "$error_code"
}

########################
# Generate JAAS authentication file
# Globals:
#   KAFKA_*
# Arguments:
#   $1 - Authentication protocol to use for the internal listener
#   $1 - Authentication protocol to use for the client listener
# Returns:
#   None
#########################
kafka_generate_jaas_authentication_file() {
    local -r internal_protocol="${1:?missing internal_protocol}"
    local -r client_protocol="${2:?missing client_protocol}"

    if [[ ! -f "${KAFKA_CONF_DIR}/kafka_jaas.conf" ]]; then
        info "Generating JAAS authentication file"
        if [[ "$client_protocol" =~ "SASL" ]]; then
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaClient {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   username="${KAFKA_CLIENT_USER:-}"
   password="${KAFKA_CLIENT_PASSWORD:-}";
   };
EOF
        fi
        if [[ "$client_protocol" =~ "SASL" ]] && [[ "$internal_protocol" =~ "SASL" ]]; then
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   username="${KAFKA_INTER_BROKER_USER:-}"
   password="${KAFKA_INTER_BROKER_PASSWORD:-}"
   user_${KAFKA_INTER_BROKER_USER:-}="${KAFKA_INTER_BROKER_PASSWORD:-}"
   user_${KAFKA_CLIENT_USER:-}="${KAFKA_CLIENT_PASSWORD:-}";

   org.apache.kafka.common.security.scram.ScramLoginModule required;
   };
EOF
        elif [[ "$client_protocol" =~ "SASL" ]]; then
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   user_${KAFKA_CLIENT_USER:-}="${KAFKA_CLIENT_PASSWORD:-}";

   org.apache.kafka.common.security.scram.ScramLoginModule required;
   };
EOF
        elif [[ "$internal_protocol" =~ "SASL" ]]; then
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   username="${KAFKA_INTER_BROKER_USER:-}"
   password="${KAFKA_INTER_BROKER_PASSWORD:-}"
   user_${KAFKA_INTER_BROKER_USER:-}="${KAFKA_INTER_BROKER_PASSWORD:-}";

   org.apache.kafka.common.security.scram.ScramLoginModule required;
   };
EOF
        fi
        if [[ -n "$KAFKA_ZOOKEEPER_USER" ]] && [[ -n "$KAFKA_ZOOKEEPER_PASSWORD" ]]; then
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
Client {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   username="${KAFKA_ZOOKEEPER_USER:-}"
   password="${KAFKA_ZOOKEEPER_PASSWORD:-}";
   };
EOF
        fi
    else
        info "Custom JAAS authentication file detected. Skipping generation."
        warn "The following environment variables will be ignored: KAFKA_CLIENT_USER, KAFKA_CLIENT_PASSWORD, KAFKA_INTER_BROKER_USER, KAFKA_INTER_BROKER_PASSWORD, KAFKA_ZOOKEEPER_USER and KAFKA_ZOOKEEPER_PASSWORD"
    fi
}

########################
# Configure Kafka SSL settings
# Globals:
#   KAFKA_CERTIFICATE_PASSWORD
#   KAFKA_CONF_DIR
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_configure_ssl() {
    # Set Kafka configuration
    kafka_server_conf_set ssl.keystore.location "$KAFKA_CONF_DIR"/certs/kafka.keystore.jks
    kafka_server_conf_set ssl.keystore.password "$KAFKA_CERTIFICATE_PASSWORD"
    kafka_server_conf_set ssl.key.password "$KAFKA_CERTIFICATE_PASSWORD"
    kafka_server_conf_set ssl.truststore.location "$KAFKA_CONF_DIR"/certs/kafka.truststore.jks
    kafka_server_conf_set ssl.truststore.password "$KAFKA_CERTIFICATE_PASSWORD"
    # Set producer/consumer configuration
    kafka_producer_consumer_conf_set ssl.keystore.location "$KAFKA_CONF_DIR"/certs/kafka.keystore.jks
    kafka_producer_consumer_conf_set ssl.keystore.password "$KAFKA_CERTIFICATE_PASSWORD"
    kafka_producer_consumer_conf_set ssl.truststore.location "$KAFKA_CONF_DIR"/certs/kafka.truststore.jks
    kafka_producer_consumer_conf_set ssl.truststore.password "$KAFKA_CERTIFICATE_PASSWORD"
    kafka_producer_consumer_conf_set ssl.key.password "$KAFKA_CERTIFICATE_PASSWORD"
}

########################
# Configure Kafka for inter-broker communications
# Globals:
#   None
# Arguments:
#   $1 - Authentication protocol to use for the internal listener
# Returns:
#   None
#########################
kafka_configure_internal_communications() {
    local -r protocol="${1:?missing environment variable protocol}"
    local -r allowed_protocols=("PLAINTEXT" "SASL_PLAINTEXT" "SASL_SSL" "SSL")
    info "Configuring Kafka for inter-broker communications with ${protocol} authentication."

    if [[ " ${allowed_protocols[*]} " =~ " ${protocol} " ]]; then
        kafka_server_conf_set security.inter.broker.protocol "$protocol"
        if [[ "$protocol" = "PLAINTEXT" ]]; then
            warn "Inter-broker communications are configured as PLAINTEXT. This is not safe for production environments."
        fi
        if [[ "$protocol" = "SASL_PLAINTEXT" ]] || [[ "$protocol" = "SASL_SSL" ]]; then
            # The below lines would need to be updated to support other SASL implementations (i.e. GSSAPI)
            # IMPORTANT: Do not confuse SASL/PLAIN with PLAINTEXT
            # For more information, see: https://docs.confluent.io/current/kafka/authentication_sasl/authentication_sasl_plain.html#sasl-plain-overview)
            kafka_server_conf_set sasl.mechanism.inter.broker.protocol PLAIN
        fi
        if [[ "$protocol" = "SASL_SSL" ]] || [[ "$protocol" = "SSL" ]]; then
            kafka_configure_ssl
            # We need to enable 2 way authentication on SASL_SSL so brokers authenticate each other.
            # It won't affect client communications unless the SSL protocol is for them.
            kafka_server_conf_set ssl.client.auth required
        fi
    else
        error "Authentication protocol ${protocol} is not supported!"
        exit 1
    fi
}

########################
# Configure Kafka for client communications
# Globals:
#   None
# Arguments:
#   $1 - Authentication protocol to use for the client listener
# Returns:
#   None
#########################
kafka_configure_client_communications() {
    local -r protocol="${1:?missing environment variable protocol}"
    local -r allowed_protocols=("PLAINTEXT" "SASL_PLAINTEXT" "SASL_SSL" "SSL")
    info "Configuring Kafka for client communications with ${protocol} authentication."

    if [[ " ${allowed_protocols[*]} " =~ " ${protocol} " ]]; then
        kafka_server_conf_set security.inter.broker.protocol "$protocol"
        if [[ "$protocol" = "PLAINTEXT" ]]; then
            warn "Client communications are configured using PLAINTEXT listeners. For safety reasons, do not use this in a production environment."
        fi
        if [[ "$protocol" = "SASL_PLAINTEXT" ]] || [[ "$protocol" = "SASL_SSL" ]]; then
            # The below lines would need to be updated to support other SASL implementations (i.e. GSSAPI)
            # IMPORTANT: Do not confuse SASL/PLAIN with PLAINTEXT
            # For more information, see: https://docs.confluent.io/current/kafka/authentication_sasl/authentication_sasl_plain.html#sasl-plain-overview)
            kafka_server_conf_set sasl.mechanism.inter.broker.protocol PLAIN
        fi
        if [[ "$protocol" = "SASL_SSL" ]] || [[ "$protocol" = "SSL" ]]; then
            kafka_configure_ssl
        fi
        if [[ "$protocol" = "SSL" ]]; then
            kafka_server_conf_set ssl.client.auth required
        fi
    else
        error "Authentication protocol ${protocol} is not supported!"
        exit 1
    fi
}

########################
# Configure Kafka configuration files from environment variables
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_configure_from_environment_variables() {
    # Map environment variables to config properties
    for var in "${!KAFKA_CFG_@}"; do
        key="$(echo "$var" | sed -e 's/^KAFKA_CFG_//g' -e 's/_/\./g' | tr '[:upper:]' '[:lower:]')"
        value="${!var}"
        kafka_server_conf_set "$key" "$value"
    done
}

########################
# Initialize Kafka
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_initialize() {
    info "Initializing Kafka..."
    # DEPRECATED. Copy files in old conf directory to maintain compatibility with Helm chart.
    if ! is_dir_empty "$KAFKA_BASE_DIR"/conf; then
        warn "Detected files mounted to $KAFKA_BASE_DIR/conf. This is deprecated and files should be mounted to $KAFKA_MOUNTED_CONF_DIR."
        cp -Lr "$KAFKA_BASE_DIR"/conf/* "$KAFKA_CONF_DIR"
    fi
    # Check for mounted configuration files
    if ! is_dir_empty "$KAFKA_MOUNTED_CONF_DIR"; then
        cp -Lr "$KAFKA_MOUNTED_CONF_DIR"/* "$KAFKA_CONF_DIR"
    fi
    # DEPRECATED. Check for server.properties file in old conf directory to maintain compatibility with Helm chart.
    if [[ ! -f "$KAFKA_BASE_DIR"/conf/server.properties ]] && [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/server.properties ]]; then
        info "No injected configuration files found, creating default config files"
        kafka_server_conf_set log.dirs "$KAFKA_DATA_DIR"
        kafka_configure_from_environment_variables
        # When setting up a Kafka cluster with N brokers, we have several listeners:
        # - INTERNAL: used for inter-broker communications
        # - CLIENT: used for communications with consumers/producers within the same network
        # - (optional) EXTERNAL: used for communications with consumers/producers on different networks
        local internal_protocol
        local client_protocol
        if [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" = *"INTERNAL"* ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" = *"CLIENT"* ]]; then
            if [[ ${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-} =~ INTERNAL:([a-zA-Z_]*) ]]; then
                internal_protocol="${BASH_REMATCH[1]}"
                kafka_configure_internal_communications "$internal_protocol"
            fi
            if [[ ${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-} =~ CLIENT:([a-zA-Z_]*) ]]; then
                client_protocol="${BASH_REMATCH[1]}"
                kafka_configure_client_communications "$client_protocol"
            fi
        fi
        if [[ "${internal_protocol:-}" =~ "SASL" ]] || [[ "${client_protocol:-}" =~ "SASL" ]] || [[ -n "$KAFKA_ZOOKEEPER_USER" && -n "$KAFKA_ZOOKEEPER_PASSWORD" ]]; then
            kafka_server_conf_set sasl.enabled.mechanisms PLAIN,SCRAM-SHA-256,SCRAM-SHA-512
            kafka_generate_jaas_authentication_file "$internal_protocol" "$client_protocol"
        fi
        # Remove security.inter.broker.protocol if KAFKA_CFG_INTER_BROKER_LISTENER_NAME is configured
        if [[ -n "${KAFKA_CFG_INTER_BROKER_LISTENER_NAME:-}" ]]; then
            remove_in_file "$KAFKA_CONF_FILE" "security.inter.broker.protocol" false
        fi
    fi
}

########################
# Run custom initialization scripts
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_custom_init_scripts() {
    if [[ -n $(find "${KAFKA_INITSCRIPTS_DIR}/" -type f -regex ".*\.\(sh\)") ]] && [[ ! -f "${KAFKA_VOLUME_DIR}/.user_scripts_initialized" ]] ; then
        info "Loading user's custom files from $KAFKA_INITSCRIPTS_DIR";
        for f in /docker-entrypoint-initdb.d/*; do
            debug "Executing $f"
            case "$f" in
                *.sh)
                    if [[ -x "$f" ]]; then
                        if ! "$f"; then
                            error "Failed executing $f"
                            return 1
                        fi
                    else
                        warn "Sourcing $f as it is not executable by the current user, any error may cause initialization to fail"
                        . "$f"
                    fi
                    ;;
                *)
                    warn "Skipping $f, supported formats are: .sh"
                    ;;
            esac
        done
        touch "$KAFKA_VOLUME_DIR"/.user_scripts_initialized
    fi
}
