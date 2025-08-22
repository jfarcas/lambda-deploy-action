#!/bin/bash
set -euo pipefail

# config-loader.sh - Load and validate configuration files

load_configuration() {
    local config_file="${1:-lambda-deploy-config.yml}"
    
    echo "📋 Loading configuration from: $config_file"
    
    # Validate config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "::error::Configuration file $config_file not found"
        echo "Please ensure the configuration file exists in your repository root"
        exit 1
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