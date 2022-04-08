#!/bin/bash
#
# Bitnami Grafana library

# shellcheck disable=SC1091

# Load generic libraries
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libvalidations.sh

########################
# Print the value of a Grafana environment variable
# Globals:
#   GF_*
#   GRAFANA_CFG_*
# Arguments:
#   None
# Returns:
#   The value in the environment variable
#########################
grafana_env_var_value() {
    local -r name="${1:?missing name}"
    local gf_env_var="GF_${name}"
    local grafana_cfg_env_var="GRAFANA_CFG_${name}"
    if [[ -n "${!gf_env_var:-}" ]]; then
        echo "${!gf_env_var:-}"
    elif [[ -n "${!grafana_cfg_env_var}" ]]; then
        echo "${!grafana_cfg_env_var:-}"
    else
        error "${gf_env_var} or ${grafana_cfg_env_var} must be set"
    fi
}

########################
# Validate settings in GRAFANA_* env vars
# Globals:
#   GRAFANA_*
# Arguments:
#   None
# Returns:
#   0 if the validation succeeded, 1 otherwise
#########################
grafana_validate() {
    debug "Validating settings in GRAFANA_* environment variables..."
    local error_code=0

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }
    check_path_exists() {
        if [[ ! -e "$1" ]]; then
            print_validation_error "The directory ${1} does not exist"
        fi
    }

    # Validate user inputs
    [[ -e "$GF_OP_PATHS_CONFIG" ]] || check_path_exists "$(grafana_env_var_value PATHS_CONFIG)"
    [[ -e "$GF_OP_PATHS_DATA" ]] || check_path_exists "$(grafana_env_var_value PATHS_DATA)"
    [[ -e "$GF_OP_PATHS_LOGS" ]] || check_path_exists "$(grafana_env_var_value PATHS_LOGS)"
    [[ -e "$GF_OP_PATHS_PROVISIONING" ]] || check_path_exists "$(grafana_env_var_value PATHS_PROVISIONING)"

    return "$error_code"
}

########################
# Ensure Grafana is initialized
# Globals:
#   GRAFANA_*
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_initialize() {
    # Ensure compatibility with Grafana Operator
    local grafana_var grafana_operator_var
    for path_suffix in "config" "data" "logs" "provisioning"; do
        grafana_var="GF_PATHS_${path_suffix^^}"
        grafana_operator_var="GF_OP_PATHS_${path_suffix^^}"
        if [[ -e "${!grafana_operator_var}" && "${!grafana_operator_var}" != "${!grafana_var}" ]]; then
            info "Ensuring ${!grafana_operator_var} points to ${!grafana_var}"
            rm -rf "${!grafana_var}"
            ln -sfn "${!grafana_operator_var}" "${!grafana_var}"
        fi
    done

    if am_i_root; then
        for dir in "$GF_PATHS_DATA" "$GF_PATHS_LOGS" "$GF_PATHS_PLUGINS"; do
            is_mounted_dir_empty "$dir" && configure_permissions_ownership "$dir" -d "775" -f "664" -u "$GRAFANA_DAEMON_USER"
        done
    fi

    # Install plugins in a Grafana operator-compatible environment, useful to for starting the image as an init container
    # Based on https://github.com/grafana-operator/grafana-operator/blob/master/controllers/grafana/pluginsHelper.go
    if [[ -d "$GF_OP_PLUGINS_INIT_DIR" ]]; then
        info "Detected mounted plugins directory at '${GF_OP_PLUGINS_INIT_DIR}'. The container will exit after installing plugins as grafana-operator."
        if [[ -n "$GF_INSTALL_PLUGINS" ]]; then
            GF_PATHS_PLUGINS="$GF_OP_PLUGINS_INIT_DIR" grafana_install_plugins
        else
            warn "There are no plugins to install"
        fi
        return 255
    fi

    # Recover plugins installed when building the image
    if [[ ! -e "$(grafana_env_var_value PATHS_PLUGINS)" ]] || [[ -z "$(ls -A "$(grafana_env_var_value PATHS_PLUGINS)")" ]]; then
        mkdir -p "$(grafana_env_var_value PATHS_PLUGINS)"
        if [[ -e "$GRAFANA_DEFAULT_PLUGINS_DIR" ]] && [[ -n "$(ls -A "$GRAFANA_DEFAULT_PLUGINS_DIR")" ]]; then
            cp -r "$GRAFANA_DEFAULT_PLUGINS_DIR"/* "$(grafana_env_var_value PATHS_PLUGINS)"
        fi
    fi

    # Configure configuration file based on environment variables
    grafana_configure_from_environment_variables

    # Install plugins
    grafana_install_plugins

    # Avoid exit code of previous commands to affect the result of this function
    true
}

########################
# Update Grafana config file with settings provided via environment variables
# Globals:
#   GRAFANA_CFG_*
#   GF_PATHS_CONFIG
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_configure_from_environment_variables() {
    local section_key_pair section key value
    # Map environment variables to config properties
    for var in "${!GRAFANA_CFG_@}"; do
        section_key_pair="$(sed 's/^GRAFANA_CFG_//g' <<< "$var" | tr '[:upper:]' '[:lower:]')"
        section="${section_key_pair/_*}"
        key="${section_key_pair#*_}"
        value="${!var}"
        grafana_conf_set "$section" "$key" "$value"
    done
}

########################
# Update a single configuration in Grafana's config file
# Globals:
#   GF_PATHS_CONFIG
# Arguments:
#   $1 - section
#   $2 - key
#   $3 - value
# Returns:
#   None
#########################
grafana_conf_set() {
    local -r section="${1:?missing key}"
    local -r key="${2:?missing key}"
    local -r value="${3:-}"
    debug "Setting configuration ${section}.${key} with value '${value}' to configuration file"
    ini-file set --section "$section" --key "$key" --value "$value" "$(grafana_env_var_value PATHS_CONFIG)"
}

########################
# Install plugins
# Globals:
#   GRAFANA_*
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_install_plugins() {
    [[ -z "$GF_INSTALL_PLUGINS" ]] && return

    local -a plugin_list
    read -r -a plugin_list <<< "$(tr ',;' ' ' <<< "${GF_INSTALL_PLUGINS}")"
    if [[ "${#plugin_list[@]}" -le 0 ]]; then
        warn "There are no plugins to install"
        return
    fi

    local plugin_id plugin_version
    local -a grafana_plugin_install_args
    local -a plugin_url_array
    local -a plugin_id_version_array
    for plugin in "${plugin_list[@]}"; do
        plugin_id="$plugin"
        plugin_version=""
        grafana_plugin_install_args=("--pluginsDir" "$(grafana_env_var_value PATHS_PLUGINS)")
        is_boolean_yes "$GF_INSTALL_PLUGINS_SKIP_TLS" && grafana_plugin_install_args+=("--insecure")
        if grep -q '=' <<< "$plugin"; then
            read -r -a plugin_url_array <<< "$(tr '=' ' ' <<< "${plugin}")"
            info "Installing plugin ${plugin_url_array[0]} from URL ${plugin_url_array[1]}"
            plugin_id="${plugin_url_array[0]}"
            grafana_plugin_install_args+=("--pluginUrl" "${plugin_url_array[1]}")
        elif grep ':' <<< "$plugin"; then
            read -r -a plugin_id_version_array <<< "$(tr ':' ' ' <<< "${plugin}")"
            plugin_id="${plugin_id_version_array[0]}"
            plugin_version="${plugin_id_version_array[1]}"
            info "Installing plugin ${plugin_id} @ ${plugin_version}"
        else
            info "Installing plugin ${plugin_id}"
        fi
        grafana_plugin_install_args+=("plugins" "install" "${plugin_id}")
        if [[ -n "$plugin_version" ]]; then
            grafana_plugin_install_args+=("$plugin_version")
        fi
        grafana-cli "${grafana_plugin_install_args[@]}"
    done
}

########################
# Check if Grafana is running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_grafana_running() {
    local pid
    pid="$(get_pid_from_file "$GRAFANA_PID_FILE")"
    if [[ -n "$pid" ]]; then
        is_service_running "$pid"
    else
        false
    fi
}

########################
# Check if Grafana is not running
# Arguments:
#   None
# Returns:
#   Boolean
#########################
is_grafana_not_running() {
    ! is_grafana_running
}

########################
# Stop Grafana
# Arguments:
#   None
# Returns:
#   None
#########################
grafana_stop() {
    is_grafana_not_running && return

    info "Stopping Grafana"
    stop_service_using_pid "$GRAFANA_PID_FILE"
}
