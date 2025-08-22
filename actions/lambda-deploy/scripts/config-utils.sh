#!/bin/bash
# config-utils.sh - Common utilities for finding and loading configuration files

find_config_file() {
    local config_file="${1:-${CONFIG_FILE_PATH:-lambda-deploy-config.yml}}"
    
    # If config file exists at the provided path, use it
    if [[ -f "$config_file" ]]; then
        echo "$config_file"
        return 0
    fi
    
    # Try common locations
    local common_locations=(
        ".github/config/lambda-deploy-config.yml"
        "config/lambda-deploy-config.yml" 
        ".config/lambda-deploy-config.yml"
        "lambda-deploy-config.yml"
    )
    
    for location in "${common_locations[@]}"; do
        if [[ -f "$location" ]]; then
            echo "$location"
            return 0
        fi
    done
    
    # Try action directory as fallback
    local action_dir="$(dirname "${BASH_SOURCE[0]}")/.."
    local fallback_config="$action_dir/lambda-deploy-config.yml"
    
    if [[ -f "$fallback_config" ]]; then
        echo "$fallback_config"
        return 0
    fi
    
    # Return the original path if nothing found
    echo "$config_file"
    return 1
}

# Get a config value with fallback
get_config_value() {
    local config_file="$1"
    local config_path="$2" 
    local default_value="${3:-}"
    
    if [[ -f "$config_file" ]] && command -v yq >/dev/null 2>&1; then
        yq eval "$config_path // \"$default_value\"" "$config_file" 2>/dev/null || echo "$default_value"
    else
        echo "$default_value"
    fi
}

# Check if config file is accessible
validate_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "::error::Configuration file $config_file not found"
        return 1
    fi
    
    if ! yq eval '.' "$config_file" > /dev/null 2>&1; then
        echo "::error::Invalid YAML syntax in $config_file" 
        return 1
    fi
    
    return 0
}