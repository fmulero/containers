#!/bin/bash
#
# Environment configuration for keycloak

# The values for all environment variables will be set in the below order of precedence
# 1. Custom environment variables defined below after Bitnami defaults
# 2. Constants defined in this file (environment variables with no default), i.e. BITNAMI_ROOT_DIR
# 3. Environment variables overridden via external files using *_FILE variables (see below)
# 4. Environment variables set externally (i.e. current Bash context/Dockerfile/userdata)

export BITNAMI_ROOT_DIR="/opt/bitnami"
export BITNAMI_VOLUME_DIR="/bitnami"

# Logging configuration
export MODULE="${MODULE:-keycloak}"
export BITNAMI_DEBUG="${BITNAMI_DEBUG:-false}"

# By setting an environment variable matching *_FILE to a file path, the prefixed environment
# variable will be overridden with the value specified in that file
keycloak_env_vars=(
    KEYCLOAK_ADMIN_USER
    KEYCLOAK_ADMIN_PASSWORD
    KEYCLOAK_PORT
    KEYCLOAK_BIND_ADDRESS
    KEYCLOAK_INIT_MAX_RETRIES
    KEYCLOAK_CACHE_OWNERS_COUNT
    KEYCLOAK_AUTH_CACHE_OWNERS_COUNT
    KEYCLOAK_JGROUPS_DISCOVERY_PROTOCOL
    KEYCLOAK_JGROUPS_DISCOVERY_PROPERTIES
    KEYCLOAK_JGROUPS_TRANSPORT_STACK
    KEYCLOAK_ENABLE_STATISTICS
    KEYCLOAK_ENABLE_TLS
    KEYCLOAK_TLS_TRUSTSTORE_FILE
    KEYCLOAK_TLS_TRUSTSTORE_PASSWORD
    KEYCLOAK_TLS_KEYSTORE_FILE
    KEYCLOAK_TLS_KEYSTORE_PASSWORD
    KEYCLOAK_LOG_LEVEL
    KEYCLOAK_ROOT_LOG_LEVEL
    KEYCLOAK_PROXY_ADDRESS_FORWARDING
    KEYCLOAK_CREATE_ADMIN_USER
    KEYCLOAK_DATABASE_HOST
    KEYCLOAK_DATABASE_PORT
    KEYCLOAK_DATABASE_USER
    KEYCLOAK_DATABASE_NAME
    KEYCLOAK_DATABASE_PASSWORD
    KEYCLOAK_DAEMON_USER
    KEYCLOAK_DAEMON_GROUP
    KEYCLOAK_USER
    KEYCLOAK_PASSWORD
    CACHE_OWNERS_COUNT
    CACHE_OWNERS_AUTH_SESSIONS_COUNT
    JGROUPS_DISCOVERY_PROTOCOL
    JGROUPS_DISCOVERY_PROPERTIES
    JGROUPS_TRANSPORT_STACK
    PROXY_ADDRESS_FORWARDING
    DB_ADDR
    DB_PORT
    DB_USER
    DB_DATABASE
    DB_PASSWORD
)
for env_var in "${keycloak_env_vars[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        export "${env_var}=$(< "${!file_env_var}")"
        unset "${file_env_var}"
    fi
done
unset keycloak_env_vars

# Paths
export BITNAMI_VOLUME_DIR="/bitnami"
export JAVA_HOME="/opt/bitnami/java"
export KEYCLOAK_BASE_DIR="/opt/bitnami/keycloak"
export KEYCLOAK_BIN_DIR="$KEYCLOAK_BASE_DIR/bin"
export KEYCLOAK_STANDALONE_DIR="$KEYCLOAK_BASE_DIR/standalone"
export KEYCLOAK_LOG_DIR="$KEYCLOAK_STANDALONE_DIR/log"
export KEYCLOAK_TMP_DIR="$KEYCLOAK_STANDALONE_DIR/tmp"
export KEYCLOAK_DOMAIN_TMP_DIR="$KEYCLOAK_BASE_DIR/domain/tmp"
export KEYCLOAK_DATA_DIR="$KEYCLOAK_STANDALONE_DIR/data"
export KEYCLOAK_DEPLOYMENTS_DIR="$KEYCLOAK_STANDALONE_DIR/deployments"
export WILDFLY_BASE_DIR="/opt/bitnami/wildfly"
export KEYCLOAK_CONF_DIR="$KEYCLOAK_STANDALONE_DIR/configuration"
export KEYCLOAK_INITSCRIPTS_DIR="/docker-entrypoint-initdb.d"
export KEYCLOAK_VOLUME_DIR="/bitnami/keycloak"
export KEYCLOAK_CONF_FILE="standalone-ha.xml"
export KEYCLOAK_DEFAULT_CONF_FILE="standalone-ha-default.xml"

# Keycloak configuration
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-"${KEYCLOAK_USER:-}"}"
export KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-user}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-"${KEYCLOAK_PASSWORD:-}"}"
export KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-bitnami}"
export KEYCLOAK_PORT="${KEYCLOAK_PORT:-8080}"
export KEYCLOAK_BIND_ADDRESS="${KEYCLOAK_BIND_ADDRESS:-0.0.0.0}"
export KEYCLOAK_INIT_MAX_RETRIES="${KEYCLOAK_INIT_MAX_RETRIES:-10}"
KEYCLOAK_CACHE_OWNERS_COUNT="${KEYCLOAK_CACHE_OWNERS_COUNT:-"${CACHE_OWNERS_COUNT:-}"}"
export KEYCLOAK_CACHE_OWNERS_COUNT="${KEYCLOAK_CACHE_OWNERS_COUNT:-1}"
KEYCLOAK_AUTH_CACHE_OWNERS_COUNT="${KEYCLOAK_AUTH_CACHE_OWNERS_COUNT:-"${CACHE_OWNERS_AUTH_SESSIONS_COUNT:-}"}"
export KEYCLOAK_AUTH_CACHE_OWNERS_COUNT="${KEYCLOAK_AUTH_CACHE_OWNERS_COUNT:-1}"
KEYCLOAK_JGROUPS_DISCOVERY_PROTOCOL="${KEYCLOAK_JGROUPS_DISCOVERY_PROTOCOL:-"${JGROUPS_DISCOVERY_PROTOCOL:-}"}"
export KEYCLOAK_JGROUPS_DISCOVERY_PROTOCOL="${KEYCLOAK_JGROUPS_DISCOVERY_PROTOCOL:-}"
KEYCLOAK_JGROUPS_DISCOVERY_PROPERTIES="${KEYCLOAK_JGROUPS_DISCOVERY_PROPERTIES:-"${JGROUPS_DISCOVERY_PROPERTIES:-}"}"
export KEYCLOAK_JGROUPS_DISCOVERY_PROPERTIES="${KEYCLOAK_JGROUPS_DISCOVERY_PROPERTIES:-}"
KEYCLOAK_JGROUPS_TRANSPORT_STACK="${KEYCLOAK_JGROUPS_TRANSPORT_STACK:-"${JGROUPS_TRANSPORT_STACK:-}"}"
export KEYCLOAK_JGROUPS_TRANSPORT_STACK="${KEYCLOAK_JGROUPS_TRANSPORT_STACK:-tcp}"
export KEYCLOAK_ENABLE_STATISTICS="${KEYCLOAK_ENABLE_STATISTICS:-false}"
export KEYCLOAK_ENABLE_TLS="${KEYCLOAK_ENABLE_TLS:-false}"
export KEYCLOAK_TLS_TRUSTSTORE_FILE="${KEYCLOAK_TLS_TRUSTSTORE_FILE:-}"
export KEYCLOAK_TLS_TRUSTSTORE_PASSWORD="${KEYCLOAK_TLS_TRUSTSTORE_PASSWORD:-}"
export KEYCLOAK_TLS_KEYSTORE_FILE="${KEYCLOAK_TLS_KEYSTORE_FILE:-}"
export KEYCLOAK_TLS_KEYSTORE_PASSWORD="${KEYCLOAK_TLS_KEYSTORE_PASSWORD:-}"
export KEYCLOAK_LOG_LEVEL="${KEYCLOAK_LOG_LEVEL:-INFO}"
export KEYCLOAK_ROOT_LOG_LEVEL="${KEYCLOAK_ROOT_LOG_LEVEL:-INFO}"
KEYCLOAK_PROXY_ADDRESS_FORWARDING="${KEYCLOAK_PROXY_ADDRESS_FORWARDING:-"${PROXY_ADDRESS_FORWARDING:-}"}"
export KEYCLOAK_PROXY_ADDRESS_FORWARDING="${KEYCLOAK_PROXY_ADDRESS_FORWARDING:-false}"
export KEYCLOAK_CREATE_ADMIN_USER="${KEYCLOAK_CREATE_ADMIN_USER:-true}"
KEYCLOAK_DATABASE_HOST="${KEYCLOAK_DATABASE_HOST:-"${DB_ADDR:-}"}"
export KEYCLOAK_DATABASE_HOST="${KEYCLOAK_DATABASE_HOST:-postgresql}"
KEYCLOAK_DATABASE_PORT="${KEYCLOAK_DATABASE_PORT:-"${DB_PORT:-}"}"
export KEYCLOAK_DATABASE_PORT="${KEYCLOAK_DATABASE_PORT:-5432}"
KEYCLOAK_DATABASE_USER="${KEYCLOAK_DATABASE_USER:-"${DB_USER:-}"}"
export KEYCLOAK_DATABASE_USER="${KEYCLOAK_DATABASE_USER:-bn_keycloak}"
KEYCLOAK_DATABASE_NAME="${KEYCLOAK_DATABASE_NAME:-"${DB_DATABASE:-}"}"
export KEYCLOAK_DATABASE_NAME="${KEYCLOAK_DATABASE_NAME:-bitnami_keycloak}"
KEYCLOAK_DATABASE_PASSWORD="${KEYCLOAK_DATABASE_PASSWORD:-"${DB_PASSWORD:-}"}"
export KEYCLOAK_DATABASE_PASSWORD="${KEYCLOAK_DATABASE_PASSWORD:-}"

# System users (when running with a privileged user)
export KEYCLOAK_DAEMON_USER="${KEYCLOAK_DAEMON_USER:-keycloak}"
export KEYCLOAK_DAEMON_GROUP="${KEYCLOAK_DAEMON_GROUP:-keycloak}"

# Custom environment variables may be defined below
