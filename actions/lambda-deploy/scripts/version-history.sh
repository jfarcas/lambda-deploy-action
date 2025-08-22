#!/bin/bash
set -euo pipefail

# version-history.sh - Get last successful version for rollback capability

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

get_last_successful_version() {
    echo "🔍 Getting last successful version for potential rollback..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    echo "Using config file: $config_file"
    
    # Check if auto-rollback is enabled
    local auto_rollback_enabled
    auto_rollback_enabled=$(yq eval '.deployment.auto_rollback.enabled // false' "$config_file")
    
    if [[ "$auto_rollback_enabled" == "false" ]]; then
        echo "Auto-rollback is disabled, skipping last version lookup"
        echo "last-version=" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    echo "Auto-rollback is enabled, looking up last successful version..."
    
    # Get current Lambda function configuration to find last successful version
    local lambda_function="$LAMBDA_FUNCTION_NAME"
    local aws_region="$AWS_REGION"
    
    # Try to get the current version from Lambda function tags
    local account_id
    if ! account_id=$(aws_retry 3 aws sts get-caller-identity --query Account --output text); then
        echo "::warning::Failed to get AWS account ID, skipping version history"
        echo "last-version=" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    local function_arn="arn:aws:lambda:$aws_region:$account_id:function:$lambda_function"
    
    # Get current tags to find last successful deployment
    local last_version=""
    local tags_file="/tmp/lambda-tags.json"
    
    if aws_retry 3 aws lambda list-tags --resource "$function_arn" > "$tags_file" 2>/dev/null; then
        # Try to extract version from tags
        if command -v jq >/dev/null 2>&1; then
            last_version=$(jq -r '.Tags.Version // empty' "$tags_file" 2>/dev/null || echo "")
        else
            # Fallback parsing if jq is not available
            last_version=$(grep -o '"Version":"[^"]*"' "$tags_file" 2>/dev/null | cut -d'"' -f4 || echo "")
        fi
    else
        echo "::warning::Failed to retrieve Lambda function tags"
    fi
    
    # If no version in tags, try to get from function configuration
    if [[ -z "$last_version" || "$last_version" == "null" ]]; then
        echo "No version found in tags, checking function configuration..."
        
        local function_config="/tmp/function-config.json"
        if aws_retry 3 aws lambda get-function --function-name "$lambda_function" > "$function_config" 2>/dev/null; then
            # Try to extract version from description or environment variables
            if command -v jq >/dev/null 2>&1; then
                # Check function description for version pattern
                local description
                description=$(jq -r '.Configuration.Description // empty' "$function_config" 2>/dev/null)
                if [[ -n "$description" ]]; then
                    # Look for version pattern like "v1.2.3" or "1.2.3" in description
                    last_version=$(echo "$description" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+[^[:space:]]*' | head -1 | sed 's/^v//' || echo "")
                fi
                
                # If still no version, check environment variables
                if [[ -z "$last_version" ]]; then
                    last_version=$(jq -r '.Configuration.Environment.Variables.VERSION // empty' "$function_config" 2>/dev/null || echo "")
                fi
            fi
        fi
    fi
    
    # Clean up temporary files
    rm -f "$tags_file" "$function_config"
    
    if [[ -n "$last_version" ]] && [[ "$last_version" != "null" ]]; then
        echo "Found last successful version: $last_version"
        echo "last-version=$last_version" >> "$GITHUB_OUTPUT"
        
        # Export for use by other scripts
        export LAST_SUCCESSFUL_VERSION="$last_version"
    else
        echo "No previous successful version found"
        echo "last-version=" >> "$GITHUB_OUTPUT"
    fi
}

# Get version history for environment-specific rollback options
get_version_history() {
    local environment="${1:-}"
    local limit="${2:-10}"
    
    if [[ -z "$environment" ]]; then
        echo "::error::Environment is required for version history"
        return 1
    fi
    
    echo "📋 Getting version history for environment: $environment (limit: $limit)"
    
    local s3_bucket="$S3_BUCKET_NAME"
    local lambda_function="$LAMBDA_FUNCTION_NAME"
    
    # Construct environment-specific S3 path
    local s3_path="s3://$s3_bucket/$lambda_function/environments/$environment/versions/"
    
    echo "Checking S3 path: $s3_path"
    
    # List versions in S3, sorted by modification time (newest first)
    local versions_output="/tmp/version-history.txt"
    
    if aws_retry 3 aws s3 ls "$s3_path" --recursive > "$versions_output" 2>/dev/null; then
        echo "Available versions in $environment environment:"
        
        # Parse versions from S3 listing and sort by date
        local versions_file="/tmp/versions.txt"
        grep "\.zip$" "$versions_output" | \
            grep -oE '/versions/[^/]+/' | \
            sed 's|/versions/||g; s|/||g' | \
            sort -V -r | \
            head -"$limit" > "$versions_file"
        
        if [[ -s "$versions_file" ]]; then
            local count=1
            while IFS= read -r version; do
                echo "  $count. $version"
                ((count++))
            done < "$versions_file"
            
            # Set the most recent version as last-version if not already set
            if [[ -z "${LAST_SUCCESSFUL_VERSION:-}" ]]; then
                local most_recent
                most_recent=$(head -1 "$versions_file")
                echo "last-version=$most_recent" >> "$GITHUB_OUTPUT"
                export LAST_SUCCESSFUL_VERSION="$most_recent"
                echo "Set most recent version as last successful: $most_recent"
            fi
        else
            echo "  No versions found in $environment environment"
        fi
        
        rm -f "$versions_file"
    else
        echo "::warning::Failed to list versions from S3 or no versions exist"
    fi
    
    rm -f "$versions_output"
}

# Validate that a specific version exists in the environment
validate_version_exists() {
    local version="${1:-}"
    local environment="${2:-}"
    
    if [[ -z "$version" || -z "$environment" ]]; then
        echo "::error::Version and environment are required for validation"
        return 1
    fi
    
    echo "🔍 Validating that version $version exists in $environment environment..."
    
    local s3_bucket="$S3_BUCKET_NAME"
    local lambda_function="$LAMBDA_FUNCTION_NAME"
    
    # Normalize version (remove 'v' prefix if present)
    local normalized_version
    normalized_version=$(echo "$version" | sed 's/^v//')
    
    # Construct expected S3 key
    local s3_key="$lambda_function/environments/$environment/versions/$normalized_version/$lambda_function-$normalized_version.zip"
    
    echo "Checking S3 object: s3://$s3_bucket/$s3_key"
    
    if aws_retry 3 aws s3api head-object --bucket "$s3_bucket" --key "$s3_key" > /dev/null 2>&1; then
        echo "✅ Version $version exists in $environment environment"
        return 0
    else
        echo "❌ Version $version does not exist in $environment environment"
        return 1
    fi
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-get_last}" in
        "get_last")
            get_last_successful_version
            ;;
        "get_history")
            get_version_history "${2:-}" "${3:-10}"
            ;;
        "validate")
            validate_version_exists "${2:-}" "${3:-}"
            ;;
        *)
            echo "Usage: $0 [get_last|get_history|validate] [args...]"
            echo "  get_last                    - Get last successful version"
            echo "  get_history <env> [limit]   - Get version history for environment"
            echo "  validate <version> <env>    - Validate version exists in environment"
            exit 1
            ;;
    esac
fi