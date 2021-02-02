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
export KAFKA_BASE_DIR="${KAFKA_BASE_DIR:-/opt/bitnami/kafka}"
export KAFKA_VOLUME_DIR="${KAFKA_VOLUME_DIR:-/bitnami/kafka}"
export KAFKA_HOME="$KAFKA_BASE_DIR"
export KAFKA_OPTS="${KAFKA_OPTS:-}"
export KAFKA_LOG_DIR="$KAFKA_BASE_DIR"/logs
export KAFKA_CONF_DIR="${KAFKA_CONF_DIR:-"$KAFKA_BASE_DIR"/config}"
export KAFKA_CONF_FILE="$KAFKA_CONF_DIR"/server.properties
export KAFKA_MOUNTED_CONF_DIR="${KAFKA_MOUNTED_CONF_DIR:-${KAFKA_VOLUME_DIR}/config}"
export KAFKA_CERTS_DIR="$KAFKA_CONF_DIR"/certs
export KAFKA_DATA_DIR="$KAFKA_VOLUME_DIR"/data
export KAFKA_INITSCRIPTS_DIR=/docker-entrypoint-initdb.d
export KAFKA_DAEMON_USER="kafka"
export KAFKA_DAEMON_GROUP="kafka"
export PATH="${KAFKA_BASE_DIR}/bin:$PATH"
export ALLOW_PLAINTEXT_LISTENER="${ALLOW_PLAINTEXT_LISTENER:-no}"
export KAFKA_INTER_BROKER_USER="${KAFKA_INTER_BROKER_USER:-user}"
export KAFKA_INTER_BROKER_PASSWORD="${KAFKA_INTER_BROKER_PASSWORD:-bitnami}"
export KAFKA_CLIENT_USER="${KAFKA_CLIENT_USER:-}"
export KAFKA_CLIENT_PASSWORD="${KAFKA_CLIENT_PASSWORD:-}"
export KAFKA_HEAP_OPTS="${KAFKA_HEAP_OPTS:-"-Xmx1024m -Xms1024m"}"
export KAFKA_ZOOKEEPER_PROTOCOL="${KAFKA_ZOOKEEPER_PROTOCOL:-"PLAINTEXT"}"
export KAFKA_ZOOKEEPER_PASSWORD="${KAFKA_ZOOKEEPER_PASSWORD:-}"
export KAFKA_ZOOKEEPER_USER="${KAFKA_ZOOKEEPER_USER:-}"
export KAFKA_ZOOKEEPER_TLS_KEYSTORE_PASSWORD="${KAFKA_ZOOKEEPER_TLS_KEYSTORE_PASSWORD:-}"
export KAFKA_ZOOKEEPER_TLS_TRUSTSTORE_PASSWORD="${KAFKA_ZOOKEEPER_TLS_TRUSTSTORE_PASSWORD:-}"
export KAFKA_ZOOKEEPER_TLS_VERIFY_HOSTNAME="${KAFKA_ZOOKEEPER_TLS_VERIFY_HOSTNAME:-"true"}"
export KAFKA_ZOOKEEPER_TLS_TYPE="${KAFKA_ZOOKEEPER_TLS_TYPE:-JKS}"
export KAFKA_ZOOKEEPER_TLS_TYPE="${KAFKA_ZOOKEEPER_TLS_TYPE^^}"
export KAFKA_CFG_ADVERTISED_LISTENERS="${KAFKA_CFG_ADVERTISED_LISTENERS:-"PLAINTEXT://:9092"}"
export KAFKA_CFG_LISTENERS="${KAFKA_CFG_LISTENERS:-"PLAINTEXT://:9092"}"
export KAFKA_CFG_ZOOKEEPER_CONNECT="${KAFKA_CFG_ZOOKEEPER_CONNECT:-"localhost:2181"}"
export KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE="${KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE:-"true"}"
export KAFKA_CFG_SASL_ENABLED_MECHANISMS="${KAFKA_CFG_SASL_ENABLED_MECHANISMS:-PLAIN,SCRAM-SHA-256,SCRAM-SHA-512}"
export KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL="${KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL:-}"
export KAFKA_CFG_TLS_TYPE="${KAFKA_CFG_TLS_TYPE:-JKS}"
export KAFKA_CFG_TLS_TYPE="${KAFKA_CFG_TLS_TYPE^^}"
export KAFKA_CFG_TLS_CLIENT_AUTH="${KAFKA_CFG_TLS_CLIENT_AUTH:-required}"
EOF
    # Make compatible KAFKA_CLIENT_USERS/PASSWORDS with the old KAFKA_CLIENT_USER/PASSWORD
    [[ -n "${KAFKA_CLIENT_USER:-}" ]] && KAFKA_CLIENT_USERS="${KAFKA_CLIENT_USER:-},${KAFKA_CLIENT_USERS:-}"
    [[ -n "${KAFKA_CLIENT_PASSWORD:-}" ]] && KAFKA_CLIENT_PASSWORDS="${KAFKA_CLIENT_PASSWORD:-},${KAFKA_CLIENT_PASSWORDS:-}"
    cat <<"EOF"
export KAFKA_CLIENT_USERS="${KAFKA_CLIENT_USERS:-user}"
export KAFKA_CLIENT_PASSWORDS="${KAFKA_CLIENT_PASSWORDS:-bitnami}"
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
    check_multi_value() {
        if [[ " ${2} " != *" ${!1} "* ]]; then
            print_validation_error "The allowed values for ${1} are: ${2}"
        fi
    }

    if [[ ${KAFKA_CFG_LISTENERS:-} =~ INTERNAL://:([0-9]*) ]]; then
        internal_port="${BASH_REMATCH[1]}"
        check_allowed_listener_port "$internal_port"
    fi
    if [[ ${KAFKA_CFG_LISTENERS:-} =~ CLIENT://:([0-9]*) ]]; then
        client_port="${BASH_REMATCH[1]}"
        check_allowed_listener_port "$client_port"
    fi
    [[ -n ${internal_port:-} && -n ${client_port:-} ]] && check_conflicting_listener_ports "$internal_port" "$client_port"
    if [[ -n "${KAFKA_PORT_NUMBER:-}" ]] || [[ -n "${KAFKA_CFG_PORT:-}" ]]; then
        warn "The environment variables KAFKA_PORT_NUMBER and KAFKA_CFG_PORT are deprecated, you can specify the port number to use for each listener using the KAFKA_CFG_LISTENERS environment variable instead."
    fi

    read -r -a users <<< "$(tr ',;' ' ' <<< "${KAFKA_CLIENT_USERS}")"
    read -r -a passwords <<< "$(tr ',;' ' ' <<< "${KAFKA_CLIENT_PASSWORDS}")"
    if [[ "${#users[@]}" -ne "${#passwords[@]}" ]]; then
        print_validation_error "Specify the same number of passwords on KAFKA_CLIENT_PASSWORDS as the number of users on KAFKA_CLIENT_USERS!"
    fi

    if is_boolean_yes "$ALLOW_PLAINTEXT_LISTENER"; then
        warn "You set the environment variable ALLOW_PLAINTEXT_LISTENER=$ALLOW_PLAINTEXT_LISTENER. For safety reasons, do not use this flag in a production environment."
    fi
    if [[ "${KAFKA_CFG_LISTENERS:-}" =~ SSL ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SSL ]]; then
        if ([[ ! -f "$KAFKA_CERTS_DIR"/kafka.keystore.jks ]] || [[ ! -f "$KAFKA_CERTS_DIR"/kafka.truststore.jks ]]) \
            && ([[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/kafka.keystore.jks ]] || [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/kafka.truststore.jks ]]) \
            && ([[ ! -f "$KAFKA_CERTS_DIR"kafka.keystore.pem ]] || [[ ! -f "$KAFKA_CERTS_DIR"/certs/kafka.truststore.pem ]]) \
            && ([[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/kafka.keystore.pem ]] || [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/kafka.truststore.pem ]]); then
            print_validation_error "In order to configure the TLS encryption for Kafka you must mount your kafka.keystore.jks (or kafka.keystore.pem) and kafka.truststore.jks (or kafka.trustsore.pem) certificates to the ${KAFKA_MOUNTED_CONF_DIR}/certs directory."
        fi
    elif [[ "${KAFKA_CFG_LISTENERS:-}" =~ SASL ]] || [[ "${KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP:-}" =~ SASL ]]; then
        if [[ -z "$KAFKA_CLIENT_PASSWORD" && -z "$KAFKA_CLIENT_PASSWORDS" ]] && [[ -z "$KAFKA_INTER_BROKER_PASSWORD" ]]; then
            print_validation_error "In order to configure SASL authentication for Kafka, you must provide the SASL credentials. Set the environment variables KAFKA_CLIENT_USERS and KAFKA_CLIENT_PASSWORDS, to configure the credentials for SASL authentication with clients, or set the environment variables KAFKA_INTER_BROKER_USER and KAFKA_INTER_BROKER_PASSWORD, to configure the credentials for SASL authentication between brokers."
        fi
    elif ! is_boolean_yes "$ALLOW_PLAINTEXT_LISTENER"; then
        print_validation_error "The KAFKA_CFG_LISTENERS environment variable does not configure a secure listener. Set the environment variable ALLOW_PLAINTEXT_LISTENER=yes to allow the container to be started with a plaintext listener. This is only recommended for development."
    fi
    if [[ "${KAFKA_ZOOKEEPER_PROTOCOL}" =~ SSL ]]; then
        if [[ ! -f "$KAFKA_CERTS_DIR"/zookeeper.truststore.jks ]] && [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/zookeeper.truststore.jks ]] \
            && [[ ! -f "$KAFKA_CERTS_DIR"/zookeeper.truststore.pem ]] && [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/zookeeper.truststore.pem ]]; then
            print_validation_error "In order to configure the TLS encryption for Zookeeper you must mount your zookeeper.truststore.jks (or zookeeper.truststore.pem) certificates to the ${KAFKA_MOUNTED_CONF_DIR}/certs directory."
        fi
        if [[ ! -f "$KAFKA_CERTS_DIR"/zookeeper.keystore.jks ]] && [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/zookeeper.keystore.jks ]] \
            && [[ ! -f "$KAFKA_CERTS_DIR"/zookeeper.keystore.pem ]] && [[ ! -f "$KAFKA_MOUNTED_CONF_DIR"/certs/zookeeper.keystore.pem ]]; then
            warn "In order to configure the mTLS for Zookeeper you must mount your zookeeper.keystore.jks (or zookeeper.keystore.pem) certificates to the ${KAFKA_MOUNTED_CONF_DIR}/certs directory."
        fi
    elif [[ "${KAFKA_ZOOKEEPER_PROTOCOL}" =~ SASL ]]; then
        if [[ -z "$KAFKA_ZOOKEEPER_USER" ]] || [[ -z "$KAFKA_ZOOKEEPER_PASSWORD" ]]; then
            print_validation_error "In order to configure SASL authentication for Kafka, you must provide the SASL credentials. Set the environment variables KAFKA_ZOOKEEPER_USER and KAFKA_ZOOKEEPER_PASSWORD, to configure the credentials for SASL authentication with Zookeeper."
        fi
    elif ! is_boolean_yes "$ALLOW_PLAINTEXT_LISTENER"; then
         print_validation_error "The KAFKA_ZOOKEEPER_PROTOCOL environment variable does not configure a secure protocol. Set the environment variable ALLOW_PLAINTEXT_LISTENER=yes to allow the container to be started with a plaintext listener. This is only recommended for development."
    fi
    check_multi_value "KAFKA_CFG_TLS_TYPE" "JKS PEM"
    check_multi_value "KAFKA_CFG_TLS_CLIENT_AUTH" "none requested required"
    [[ "$error_code" -eq 0 ]] || return "$error_code"
}

########################
# Generate JAAS authentication file
# Globals:
#   KAFKA_*
# Arguments:
#   $1 - Authentication protocol to use for the internal listener
#   $2 - Authentication protocol to use for the client listener
# Returns:
#   None
#########################
kafka_generate_jaas_authentication_file() {
    local -r internal_protocol="${1:-}"
    local -r client_protocol="${2:-}"

    if [[ ! -f "${KAFKA_CONF_DIR}/kafka_jaas.conf" ]]; then
        info "Generating JAAS authentication file"

        read -r -a users <<< "$(tr ',;' ' ' <<< "${KAFKA_CLIENT_USERS:-}")"
        read -r -a passwords <<< "$(tr ',;' ' ' <<< "${KAFKA_CLIENT_PASSWORDS:-}")"

        if [[ "${client_protocol:-}" =~ SASL ]]; then
            if [[ "${KAFKA_CFG_SASL_ENABLED_MECHANISMS:-}" =~ PLAIN ]]; then
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaClient {
   org.apache.kafka.common.security.plain.PlainLoginModule required
EOF
            else
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaClient {
   org.apache.kafka.common.security.plain.ScramLoginModule required
EOF
            fi
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   username="${users[0]:-}"
   password="${passwords[0]:-}";
   };
EOF
        fi
        if [[ "${client_protocol:-}" =~ SASL ]] && [[ "${internal_protocol:-}" =~ SASL ]]; then
            if [[ "${KAFKA_CFG_SASL_ENABLED_MECHANISMS:-}" =~ PLAIN ]] && [[ "${KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL:-}" =~ PLAIN ]]; then
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   username="${KAFKA_INTER_BROKER_USER:-}"
   password="${KAFKA_INTER_BROKER_PASSWORD:-}"
   user_${KAFKA_INTER_BROKER_USER:-}="${KAFKA_INTER_BROKER_PASSWORD:-}"
EOF
                for (( i=0; i<${#users[@]}; i++ )); do
                    if [[ "$i" -eq "(( ${#users[@]} - 1 ))" ]]; then
                        cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   user_${users[i]:-}="${passwords[i]:-}";
EOF
                    else
                        cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   user_${users[i]:-}="${passwords[i]:-}"
EOF
                    fi
                done
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   org.apache.kafka.common.security.scram.ScramLoginModule required;
   };
EOF
            else
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="${KAFKA_INTER_BROKER_USER:-}"
   password="${KAFKA_INTER_BROKER_PASSWORD:-}";
   };
EOF
            fi
        elif [[ "${client_protocol:-}" =~ SASL ]]; then
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.plain.PlainLoginModule required
EOF
            if [[ "${KAFKA_CFG_SASL_ENABLED_MECHANISMS:-}" =~ PLAIN ]]; then
                for (( i=0; i<${#users[@]}; i++ )); do
                    if [[ "$i" -eq "(( ${#users[@]} - 1 ))" ]]; then
                        cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   user_${users[i]:-}="${passwords[i]:-}";
EOF
                else
                    cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   user_${users[i]:-}="${passwords[i]:-}"
EOF
                    fi
                done
            fi
            cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
   org.apache.kafka.common.security.scram.ScramLoginModule required;
   };
EOF
        elif [[ "${internal_protocol:-}" =~ SASL ]]; then
            if [[ "${KAFKA_CFG_SASL_ENABLED_MECHANISMS:-}" =~ PLAIN ]] && [[ "${KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL:-}" =~ PLAIN ]]; then
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.plain.PlainLoginModule required
   username="${KAFKA_INTER_BROKER_USER:-}"
   password="${KAFKA_INTER_BROKER_PASSWORD:-}"
   user_${KAFKA_INTER_BROKER_USER:-}="${KAFKA_INTER_BROKER_PASSWORD:-}";
   org.apache.kafka.common.security.scram.ScramLoginModule required;
   };
EOF
            else
                cat >> "${KAFKA_CONF_DIR}/kafka_jaas.conf" <<EOF
KafkaServer {
   org.apache.kafka.common.security.scram.ScramLoginModule required
   username="${KAFKA_INTER_BROKER_USER:-}"
   password="${KAFKA_INTER_BROKER_PASSWORD:-}";
   };
EOF
            fi
        fi
        if [[ "${KAFKA_ZOOKEEPER_PROTOCOL}" =~ SASL ]] && [[ -n "$KAFKA_ZOOKEEPER_USER" ]] && [[ -n "$KAFKA_ZOOKEEPER_PASSWORD" ]]; then
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
        warn "The following environment variables will be ignored: KAFKA_CLIENT_USERS, KAFKA_CLIENT_PASSWORDS, KAFKA_INTER_BROKER_USER, KAFKA_INTER_BROKER_PASSWORD, KAFKA_ZOOKEEPER_USER and KAFKA_ZOOKEEPER_PASSWORD"
    fi
}

########################
# Create users in zookeper when using SASL_SCRAM
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_create_sasl_scram_zookeeper_users() {
    export KAFKA_OPTS="-Djava.security.auth.login.config=${KAFKA_CONF_DIR}/kafka_jaas.conf"
    info "Creating users in Zookeeper"
    read -r -a users <<< "$(tr ',;' ' ' <<< "${KAFKA_CLIENT_USERS}")"
    read -r -a passwords <<< "$(tr ',;' ' ' <<< "${KAFKA_CLIENT_PASSWORDS}")"
    if [[ "${KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL:-}" =~ SCRAM-SHA ]]; then
        users+=("${KAFKA_INTER_BROKER_USER}")
        passwords+=("${KAFKA_INTER_BROKER_PASSWORD}")
    fi
    for (( i=0; i<${#users[@]}; i++ )); do
        debug "Creating user ${users[i]} in zookeeper"
        # Ref: https://docs.confluent.io/current/kafka/authentication_sasl/authentication_sasl_scram.html#sasl-scram-overview
        debug_execute kafka-configs.sh --zookeeper "$KAFKA_CFG_ZOOKEEPER_CONNECT" --alter --add-config "SCRAM-SHA-256=[iterations=8192,password=${passwords[i]}],SCRAM-SHA-512=[password=${passwords[i]}]" --entity-type users --entity-name "${users[i]}"
    done
}

########################
# Configure Kafka SSL settings
# Globals:
#   KAFKA_*
# Arguments:
#   None
# Returns:
#   None
#########################
kafka_configure_ssl() {
    local -r ext="${KAFKA_CFG_TLS_TYPE,,}"

    # Set Kafka configuration
    kafka_server_conf_set ssl.keystore.type "$KAFKA_CFG_TLS_TYPE"
    kafka_server_conf_set ssl.keystore.location "$KAFKA_CERTS_DIR"/kafka.keystore."$ext"
    kafka_server_conf_set ssl.key.password "$KAFKA_CERTIFICATE_PASSWORD"
    kafka_server_conf_set ssl.truststore.type "$KAFKA_CFG_TLS_TYPE"
    kafka_server_conf_set ssl.truststore.location "$KAFKA_CERTS_DIR"/kafka.truststore."$ext"
    # Set producer/consumer configuration
    kafka_producer_consumer_conf_set ssl.keystore.type "$KAFKA_CFG_TLS_TYPE"
    kafka_producer_consumer_conf_set ssl.keystore.location "$KAFKA_CERTS_DIR"/kafka.keystore."$ext"
    kafka_producer_consumer_conf_set ssl.key.password "$KAFKA_CERTIFICATE_PASSWORD"
    kafka_producer_consumer_conf_set ssl.truststore.type "$KAFKA_CFG_TLS_TYPE"
    kafka_producer_consumer_conf_set ssl.truststore.location "$KAFKA_CERTS_DIR"/kafka.truststore."$ext"
    # keystore and truststore passwords are only compatible with JKS files
    if [[ "$KAFKA_CFG_TLS_TYPE" == "JKS" ]]; then
        kafka_server_conf_set ssl.keystore.password "$KAFKA_CERTIFICATE_PASSWORD"
        kafka_server_conf_set ssl.truststore.password "$KAFKA_CERTIFICATE_PASSWORD"
        kafka_producer_consumer_conf_set ssl.keystore.password "$KAFKA_CERTIFICATE_PASSWORD"
        kafka_producer_consumer_conf_set ssl.truststore.password "$KAFKA_CERTIFICATE_PASSWORD"
    fi
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

    if [[ "${allowed_protocols[*]}" =~ $protocol ]]; then
        kafka_server_conf_set security.inter.broker.protocol "$protocol"
        if [[ "$protocol" = "PLAINTEXT" ]]; then
            warn "Inter-broker communications are configured as PLAINTEXT. This is not safe for production environments."
        fi
        if [[ "$protocol" = "SASL_PLAINTEXT" ]] || [[ "$protocol" = "SASL_SSL" ]]; then
            # IMPORTANT: Do not confuse SASL/PLAIN with PLAINTEXT
            # For more information, see: https://docs.confluent.io/current/kafka/authentication_sasl/authentication_sasl_plain.html#sasl-plain-overview)
            if [[ -n "$KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL" ]]; then
                kafka_server_conf_set sasl.mechanism.inter.broker.protocol "$KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL"
            else
                error "When using SASL for inter broker comunication the mechanism should be provided at KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL"
                exit 1
              fi
        fi
        if [[ "$protocol" = "SASL_SSL" ]] || [[ "$protocol" = "SSL" ]]; then
            kafka_configure_ssl
            # We need to enable 2 way authentication on SASL_SSL so brokers authenticate each other.
            # It won't affect client communications unless the SSL protocol is for them.
            kafka_server_conf_set ssl.client.auth "$KAFKA_CFG_TLS_CLIENT_AUTH"
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

    if [[ "${allowed_protocols[*]}" =~ ${protocol} ]]; then
        kafka_server_conf_set security.inter.broker.protocol "$protocol"
        if [[ "$protocol" = "PLAINTEXT" ]]; then
            warn "Client communications are configured using PLAINTEXT listeners. For safety reasons, do not use this in a production environment."
        fi
        if [[ "$protocol" = "SASL_PLAINTEXT" ]] || [[ "$protocol" = "SASL_SSL" ]]; then
            # The below lines would need to be updated to support other SASL implementations (i.e. GSSAPI)
            # IMPORTANT: Do not confuse SASL/PLAIN with PLAINTEXT
            # For more information, see: https://docs.confluent.io/current/kafka/authentication_sasl/authentication_sasl_plain.html#sasl-plain-overview)
            kafka_server_conf_set sasl.mechanism.inter.broker.protocol "$KAFKA_CFG_SASL_MECHANISM_INTER_BROKER_PROTOCOL"
        fi
        if [[ "$protocol" = "SASL_SSL" ]] || [[ "$protocol" = "SSL" ]]; then
            kafka_configure_ssl
        fi
        if [[ "$protocol" = "SSL" ]]; then
            kafka_server_conf_set ssl.client.auth "$KAFKA_CFG_TLS_CLIENT_AUTH"
        fi
    else
        error "Authentication protocol ${protocol} is not supported!"
        exit 1
    fi
}

########################
# Get Zookeeper TLS settings
# Globals:
#   KAFKA_ZOOKEEPER_TLS_*
# Arguments:
#   None
# Returns:
#   String
#########################
zookeeper_get_tls_config() {
    # Note that ZooKeeper does not support a key password different from the keystore password,
    # so be sure to set the key password in the keystore to be identical to the keystore password;
    # otherwise the connection attempt to Zookeeper will fail.
    local -r ext="${KAFKA_ZOOKEEPER_TLS_TYPE,,}"
    local keystore_location=""
    if [[ -f "$KAFKA_CERTS_DIR"/zookeeper.keystore."$ext" ]]; then
        keystore_location="${KAFKA_CERTS_DIR}/zookeeper.keystore.${ext}"
    fi

    echo "-Dzookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty \
          -Dzookeeper.client.secure=true \
          -Dzookeeper.ssl.keyStore.location=${keystore_location} \
          -Dzookeeper.ssl.keyStore.password=$KAFKA_ZOOKEEPER_TLS_KEYSTORE_PASSWORD \
          -Dzookeeper.ssl.trustStore.location=${KAFKA_CERTS_DIR}/zookeeper.truststore.${ext} \
          -Dzookeeper.ssl.trustStore.password=$KAFKA_ZOOKEEPER_TLS_TRUSTSTORE_PASSWORD \
          -Dzookeeper.ssl.hostnameVerification=$KAFKA_ZOOKEEPER_TLS_VERIFY_HOSTNAME"
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

        # Exception for the camel case in this environment variable
        [[ "$var" == "KAFKA_CFG_ZOOKEEPER_CLIENTCNXNSOCKET" ]] && key="zookeeper.clientCnxnSocket"

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

        if [[ "${internal_protocol:-}" =~ "SASL" || "${client_protocol:-}" =~ "SASL" ]]  || [[ "${KAFKA_ZOOKEEPER_PROTOCOL}" =~ SASL ]]; then
            if [[ -n "$KAFKA_CFG_SASL_ENABLED_MECHANISMS" ]]; then
                kafka_server_conf_set sasl.enabled.mechanisms "$KAFKA_CFG_SASL_ENABLED_MECHANISMS"
                kafka_generate_jaas_authentication_file "${internal_protocol:-}" "${client_protocol:-}"
                [[ "$KAFKA_CFG_SASL_ENABLED_MECHANISMS" =~ "SCRAM" ]] && kafka_create_sasl_scram_zookeeper_users
            else
                print_validation_error "Specified SASL protocol but no SASL mechanisms provided in KAFKA_CFG_SASL_ENABLED_MECHANISMS"
            fi
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
