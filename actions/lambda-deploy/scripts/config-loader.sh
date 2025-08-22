#!/bin/bash
set -euo pipefail

# config-loader.sh - Load and validate configuration files

load_configuration() {
    local config_file="${1:-lambda-deploy-config.yml}"
    
    echo "📋 Loading configuration from: $config_file"
    echo "🔍 Current working directory: $(pwd)"
    echo "🔍 Checking if config file exists: $config_file"
    
    # Check if config file exists, try fallback locations
    if [[ ! -f "$config_file" ]]; then
        echo "⚠️  Config file not found at: $config_file"
        
        # Try some common locations
        local common_locations=(
            ".github/config/lambda-deploy-config.yml"
            "config/lambda-deploy-config.yml"
            ".config/lambda-deploy-config.yml"
        )
        
        local found=false
        for location in "${common_locations[@]}"; do
            if [[ -f "$location" ]]; then
                echo "✅ Found config at common location: $location"
                config_file="$location"
                found=true
                break
            fi
        done
        
        if [[ "$found" == false ]]; then
            # Try action directory as fallback
            local action_dir="$(dirname "${BASH_SOURCE[0]}")/.."
            local fallback_config="$action_dir/lambda-deploy-config.yml"
            
            if [[ -f "$fallback_config" ]]; then
                echo "::warning::Config file not found, using default from action: $fallback_config"
                config_file="$fallback_config"
            else
                echo "::error::Configuration file $config_file not found"
                echo "Searched locations:"
                echo "  - $config_file (provided path)"
                for location in "${common_locations[@]}"; do
                    echo "  - $location"
                done
                echo "  - $fallback_config (action default)"
                echo ""
                echo "Please ensure the configuration file exists or use the config-file input to specify the correct path"
                exit 1
            fi
        fi
    else
        echo "✅ Config file found at: $config_file"
    fi
    
    # Validate YAML syntax
    if ! yq eval '.' "$config_file" > /dev/null 2>&1; then
        echo "::error::Invalid YAML syntax in $config_file"
        exit 1
    fi
    
    # Parse and validate required fields
    local project_name
    local project_runtime
    
    project_name=$(yq eval '.project.name' "$config_file")
    project_runtime=$(yq eval '.project.runtime' "$config_file")
    
    if [[ "$project_name" == "null" || -z "$project_name" ]]; then
        echo "::error::Missing required field: project.name in $config_file"
        exit 1
    fi
    
    if [[ "$project_runtime" == "null" || -z "$project_runtime" ]]; then
        echo "::error::Missing required field: project.runtime in $config_file"
        exit 1
    fi
    
    # Validate runtime is supported
    if [[ ! "$project_runtime" =~ ^(bun|node|python)$ ]]; then
        echo "::error::Unsupported runtime: $project_runtime. Supported: bun, node, python"
        exit 1
    fi
    
    # Set outputs
    echo "config-loaded=true" >> "$GITHUB_OUTPUT"
    echo "project-name=$project_name" >> "$GITHUB_OUTPUT"
    echo "project-runtime=$project_runtime" >> "$GITHUB_OUTPUT"
    echo "config-file-path=$config_file" >> "$GITHUB_OUTPUT"
    
    echo "✅ Configuration loaded successfully:"
    echo "  - Project: $project_name"
    echo "  - Runtime: $project_runtime"
    
    # Export for use by other scripts
    export PROJECT_NAME="$project_name"
    export PROJECT_RUNTIME="$project_runtime"
    export CONFIG_FILE_PATH="$config_file"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_configuration "${1:-lambda-deploy-config.yml}"
fi