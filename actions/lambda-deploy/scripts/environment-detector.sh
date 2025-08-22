#!/bin/bash
set -euo pipefail

# environment-detector.sh - Determine deployment environment

determine_environment() {
    local input_environment="${1:-auto}"
    local env_name
    
    if [[ "$input_environment" != "auto" ]]; then
        env_name="$input_environment"
    else
        # Auto-detect based on branch
        local branch="${GITHUB_REF_NAME:-main}"
        if [[ "$branch" == "main" || "$branch" == "master" ]]; then
            env_name="dev"
        elif [[ "$branch" =~ ^feature/MMDSQ ]]; then
            env_name="dev"
        elif [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" ]]; then
            env_name="pre"  # Default for manual triggers
        else
            echo "::error::Cannot determine environment for branch: $branch"
            exit 1
        fi
    fi
    
    echo "environment=$env_name" >> "$GITHUB_OUTPUT"
    echo "Deploying to environment: $env_name"
    
    # Export for use by other scripts
    export DEPLOYMENT_ENVIRONMENT="$env_name"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    determine_environment "${1:-auto}"
fi