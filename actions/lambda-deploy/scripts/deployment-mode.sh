#!/bin/bash
set -euo pipefail

# deployment-mode.sh - Determine deployment mode (deploy vs rollback)

determine_deployment_mode() {
    local rollback_version="${1:-}"
    
    if [[ -n "$rollback_version" ]]; then
        echo "🔄 Rollback mode detected"
        echo "deployment-mode=rollback" >> "$GITHUB_OUTPUT"
        echo "target-version=$rollback_version" >> "$GITHUB_OUTPUT"
        echo "DEPLOYMENT_MODE=rollback" >> "$GITHUB_ENV"
        echo "TARGET_VERSION=$rollback_version" >> "$GITHUB_ENV"
        
        # Validate rollback version format
        if [[ ! "$rollback_version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
            echo "::error::Invalid rollback version format: $rollback_version"
            echo "::error::Expected format: v1.2.3 or 1.2.3"
            exit 1
        fi
        
        echo "🎯 Target rollback version: $rollback_version"
    else
        echo "🚀 Normal deployment mode"
        echo "deployment-mode=deploy" >> "$GITHUB_OUTPUT"
        echo "DEPLOYMENT_MODE=deploy" >> "$GITHUB_ENV"
    fi
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    determine_deployment_mode "${1:-}"
fi