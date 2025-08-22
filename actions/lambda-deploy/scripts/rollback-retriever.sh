#!/bin/bash
set -euo pipefail

# rollback-retriever.sh - Retrieve rollback artifacts from S3

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

retrieve_rollback_artifact() {
    local rollback_version="${1:-}"
    local environment="${2:-}"
    
    if [[ -z "$rollback_version" || -z "$environment" ]]; then
        echo "::error::Rollback version and environment are required"
        return 1
    fi
    
    echo "🔄 Retrieving rollback artifact from S3..."
    echo "  Version: $rollback_version"
    echo "  Environment: $environment"
    
    # Set variables
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    if [[ -z "$s3_bucket" || -z "$lambda_function" ]]; then
        echo "::error::S3_BUCKET_NAME and LAMBDA_FUNCTION_NAME must be set"
        return 1
    fi
    
    # Normalize version (remove 'v' prefix if present)
    local normalized_version
    normalized_version=$(echo "$rollback_version" | sed 's/^v//')
    
    # Check if rollback is supported for this environment
    validate_rollback_environment "$environment"
    
    # Get environment-specific S3 key
    local s3_key
    s3_key=$(get_rollback_s3_key "$environment" "$normalized_version" "$lambda_function")
    
    echo "🔍 Looking for rollback artifact:"
    echo "  S3 Bucket: $s3_bucket"
    echo "  S3 Key: $s3_key"
    
    # Verify the rollback artifact exists
    if ! verify_rollback_artifact_exists "$s3_bucket" "$s3_key"; then
        list_available_versions "$environment" "$s3_bucket" "$lambda_function"
        return 1
    fi
    
    # Create deployment directory if it doesn't exist
    mkdir -p deployment
    
    # Download the rollback artifact
    local local_artifact_path="deployment/${lambda_function}-${normalized_version}.zip"
    download_rollback_artifact "$s3_bucket" "$s3_key" "$local_artifact_path"
    
    # Validate the downloaded artifact
    validate_downloaded_artifact "$local_artifact_path" "$normalized_version"
    
    # Set outputs for deployment step
    set_rollback_outputs "$s3_key" "$local_artifact_path" "$normalized_version"
    
    echo "✅ Rollback artifact ready for deployment"
}

validate_rollback_environment() {
    local environment="$1"
    
    case "$environment" in
        "dev"|"development")
            echo "::error::Rollback not supported for dev environment"
            echo "::error::Dev deployments use timestamp-based paths, not versions"
            echo "::error::Use latest deployment or redeploy instead"
            exit 1
            ;;
        "pre"|"staging"|"test"|"prod"|"production")
            echo "✅ Rollback supported for $environment environment"
            ;;
        *)
            echo "::warning::Unknown environment: $environment"
            echo "Proceeding with rollback attempt..."
            ;;
    esac
}

get_rollback_s3_key() {
    local environment="$1"
    local normalized_version="$2"
    local lambda_function="$3"
    
    # Generate environment-specific S3 path for rollback
    case "$environment" in
        "pre"|"staging"|"test")
            echo "$lambda_function/environments/pre/versions/$normalized_version/$lambda_function-$normalized_version.zip"
            ;;
        "prod"|"production")
            echo "$lambda_function/environments/prod/versions/$normalized_version/$lambda_function-$normalized_version.zip"
            ;;
        *)
            echo "$lambda_function/environments/$environment/versions/$normalized_version/$lambda_function-$normalized_version.zip"
            ;;
    esac
}

verify_rollback_artifact_exists() {
    local s3_bucket="$1"
    local s3_key="$2"
    
    echo "🔍 Verifying rollback artifact exists in S3..."
    
    if aws_retry 3 aws s3api head-object --bucket "$s3_bucket" --key "$s3_key" > /dev/null 2>&1; then
        echo "✅ Rollback artifact found in S3"
        
        # Get artifact metadata if available
        local object_info
        if object_info=$(aws s3api head-object --bucket "$s3_bucket" --key "$s3_key" 2>/dev/null); then
            if command -v jq >/dev/null 2>&1; then
                local content_length last_modified
                content_length=$(echo "$object_info" | jq -r '.ContentLength // "unknown"')
                last_modified=$(echo "$object_info" | jq -r '.LastModified // "unknown"')
                
                echo "  Size: $(numfmt --to=iec "$content_length" 2>/dev/null || echo "$content_length bytes")"
                echo "  Last Modified: $last_modified"
                
                # Check metadata for deployment info
                local metadata
                if metadata=$(echo "$object_info" | jq -r '.Metadata // {}' 2>/dev/null); then
                    local environment version deployed_by
                    environment=$(echo "$metadata" | jq -r '.environment // "unknown"' 2>/dev/null || echo "unknown")
                    version=$(echo "$metadata" | jq -r '.version // "unknown"' 2>/dev/null || echo "unknown")
                    deployed_by=$(echo "$metadata" | jq -r '.deployed_by // "unknown"' 2>/dev/null || echo "unknown")
                    
                    if [[ "$environment" != "unknown" ]]; then
                        echo "  Original Environment: $environment"
                    fi
                    if [[ "$version" != "unknown" ]]; then
                        echo "  Original Version: $version"
                    fi
                    if [[ "$deployed_by" != "unknown" ]]; then
                        echo "  Originally Deployed By: $deployed_by"
                    fi
                fi
            fi
        fi
        
        return 0
    else
        echo "❌ Rollback artifact not found in S3"
        return 1
    fi
}

list_available_versions() {
    local environment="$1"
    local s3_bucket="$2"
    local lambda_function="$3"
    
    echo "📋 Available versions for rollback in $environment environment:"
    
    local versions_prefix="$lambda_function/environments/"
    case "$environment" in
        "pre"|"staging"|"test")
            versions_prefix="${versions_prefix}pre/versions/"
            ;;
        "prod"|"production")
            versions_prefix="${versions_prefix}prod/versions/"
            ;;
        *)
            versions_prefix="${versions_prefix}$environment/versions/"
            ;;
    esac
    
    local versions_output="/tmp/available-versions.txt"
    
    if aws_retry 3 aws s3 ls "s3://$s3_bucket/$versions_prefix" --recursive > "$versions_output" 2>/dev/null; then
        if [[ -s "$versions_output" ]]; then
            echo "Available versions:"
            
            # Extract and display versions
            grep "\.zip$" "$versions_output" | \
                sed -E "s|.*versions/([^/]+)/.*|\1|" | \
                sort -V -r | \
                head -10 | \
                nl -w3 -s'. '
            
            local total_versions
            total_versions=$(grep "\.zip$" "$versions_output" | wc -l)
            
            if [[ $total_versions -gt 10 ]]; then
                echo "  ... and $((total_versions - 10)) more versions"
            fi
        else
            echo "No versions found in $environment environment"
        fi
    else
        echo "Failed to list available versions"
    fi
    
    rm -f "$versions_output"
}

download_rollback_artifact() {
    local s3_bucket="$1"
    local s3_key="$2"
    local local_path="$3"
    
    echo "📥 Downloading rollback artifact..."
    echo "  From: s3://$s3_bucket/$s3_key"
    echo "  To: $local_path"
    
    # Download with retry logic
    if aws_retry 3 aws s3 cp "s3://$s3_bucket/$s3_key" "$local_path"; then
        echo "✅ Rollback artifact downloaded successfully"
    else
        echo "::error::Failed to download rollback artifact"
        return 1
    fi
}

validate_downloaded_artifact() {
    local local_path="$1"
    local expected_version="$2"
    
    echo "🔍 Validating downloaded rollback artifact..."
    
    # Check if file exists and has content
    if [[ ! -f "$local_path" ]]; then
        echo "::error::Downloaded artifact not found: $local_path"
        return 1
    fi
    
    # Check file size
    local file_size
    file_size=$(stat -c%s "$local_path" 2>/dev/null || stat -f%z "$local_path" 2>/dev/null || echo "0")
    
    if [[ $file_size -lt 1000 ]]; then
        echo "::error::Downloaded artifact seems too small ($file_size bytes)"
        echo "This may indicate a download error or corrupt artifact"
        return 1
    fi
    
    local file_size_mb=$((file_size / 1024 / 1024))
    echo "📊 Artifact information:"
    echo "  Size: $file_size bytes (${file_size_mb}MB)"
    echo "  Path: $local_path"
    
    # Validate ZIP integrity if unzip is available
    if command -v unzip >/dev/null 2>&1; then
        if unzip -t "$local_path" >/dev/null 2>&1; then
            echo "✅ ZIP integrity verified"
        else
            echo "::error::Downloaded artifact is corrupted or not a valid ZIP file"
            return 1
        fi
        
        # Show contents preview
        echo "📋 Artifact contents (preview):"
        unzip -l "$local_path" | head -10
    fi
    
    echo "✅ Rollback artifact validation completed"
}

set_rollback_outputs() {
    local s3_key="$1"
    local local_path="$2"
    local version="$3"
    
    echo "📋 Setting rollback outputs..."
    
    # Set GitHub Action outputs
    echo "s3-key=$s3_key" >> "$GITHUB_OUTPUT"
    echo "local-file=$local_path" >> "$GITHUB_OUTPUT"  
    echo "version=$version" >> "$GITHUB_OUTPUT"
    
    # Set environment variables for use by other scripts
    echo "ROLLBACK_S3_KEY=$s3_key" >> "$GITHUB_ENV"
    echo "ROLLBACK_ARTIFACT_PATH=$local_path" >> "$GITHUB_ENV"
    echo "ROLLBACK_VERSION=$version" >> "$GITHUB_ENV"
    
    # Export for immediate use
    export ROLLBACK_S3_KEY="$s3_key"
    export ROLLBACK_ARTIFACT_PATH="$local_path"
    export ROLLBACK_VERSION="$version"
    
    echo "✅ Rollback outputs configured"
    echo "  S3 Key: $s3_key"
    echo "  Local File: $local_path"
    echo "  Version: $version"
}

# Get rollback candidates for an environment
get_rollback_candidates() {
    local environment="${1:-}"
    local limit="${2:-5}"
    
    if [[ -z "$environment" ]]; then
        echo "::error::Environment is required for rollback candidates"
        return 1
    fi
    
    echo "🎯 Getting rollback candidates for $environment environment..."
    
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    # Check current function version/tags
    get_current_deployment_info "$lambda_function"
    
    # List recent versions as rollback candidates
    echo ""
    echo "📋 Recent rollback candidates:"
    
    local versions_prefix="$lambda_function/environments/"
    case "$environment" in
        "pre"|"staging"|"test")
            versions_prefix="${versions_prefix}pre/versions/"
            ;;
        "prod"|"production") 
            versions_prefix="${versions_prefix}prod/versions/"
            ;;
        *)
            versions_prefix="${versions_prefix}$environment/versions/"
            ;;
    esac
    
    local candidates_file="/tmp/rollback-candidates.txt"
    
    if aws s3 ls "s3://$s3_bucket/$versions_prefix" --recursive > "$candidates_file" 2>/dev/null; then
        if [[ -s "$candidates_file" ]]; then
            # Extract versions with timestamps and sort by date (newest first)
            grep "\.zip$" "$candidates_file" | \
                sed -E 's|^([0-9-]+ [0-9:]+)\s+[0-9]+\s+.*versions/([^/]+)/.*|\1 \2|' | \
                sort -r | \
                head -"$limit" | \
                nl -w2 -s'. ' -v0 | \
                sed 's/^0\./Current: /'
            
            echo ""
            echo "💡 To rollback, use: rollback-to-version: 'VERSION_NUMBER'"
        else
            echo "No rollback candidates found"
        fi
    else
        echo "::warning::Failed to retrieve rollback candidates"
    fi
    
    rm -f "$candidates_file"
}

get_current_deployment_info() {
    local lambda_function="$1"
    
    echo "🔍 Current deployment information:"
    
    if command -v aws >/dev/null 2>&1; then
        # Get function configuration
        local function_info
        if function_info=$(aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
            if command -v jq >/dev/null 2>&1; then
                local last_modified version
                last_modified=$(echo "$function_info" | jq -r '.Configuration.LastModified')
                version=$(echo "$function_info" | jq -r '.Configuration.Version')
                
                echo "  Function Version: $version"
                echo "  Last Modified: $last_modified"
                
                # Try to get version from tags
                local account_id aws_region
                account_id="${AWS_ACCOUNT_ID:-}"
                aws_region="${AWS_REGION:-}"
                
                if [[ -n "$account_id" && -n "$aws_region" ]]; then
                    local function_arn="arn:aws:lambda:$aws_region:$account_id:function:$lambda_function"
                    local tags
                    if tags=$(aws lambda list-tags --resource "$function_arn" 2>/dev/null); then
                        local tagged_version environment
                        tagged_version=$(echo "$tags" | jq -r '.Tags.Version // "unknown"')
                        environment=$(echo "$tags" | jq -r '.Tags.Environment // "unknown"')
                        
                        if [[ "$tagged_version" != "unknown" ]]; then
                            echo "  Tagged Version: $tagged_version"
                        fi
                        if [[ "$environment" != "unknown" ]]; then
                            echo "  Tagged Environment: $environment"
                        fi
                    fi
                fi
            fi
        else
            echo "  Cannot retrieve current deployment info"
        fi
    fi
}

# Create rollback plan/summary
create_rollback_plan() {
    local rollback_version="${1:-}"
    local environment="${2:-}"
    
    if [[ -z "$rollback_version" || -z "$environment" ]]; then
        echo "::error::Rollback version and environment required for rollback plan"
        return 1
    fi
    
    echo "📋 Rollback Plan Summary"
    echo "========================"
    echo "Target Version: $rollback_version"
    echo "Environment: $environment"
    echo "Function: ${LAMBDA_FUNCTION_NAME:-unknown}"
    echo "S3 Bucket: ${S3_BUCKET_NAME:-unknown}"
    echo ""
    
    # Show current vs target
    echo "Rollback Details:"
    echo "  FROM: Current deployment"
    echo "  TO:   Version $rollback_version"
    echo ""
    
    # Show rollback steps
    echo "Rollback Steps:"
    echo "  1. Verify rollback artifact exists in S3"
    echo "  2. Download rollback artifact"
    echo "  3. Update Lambda function code"
    echo "  4. Publish new Lambda version"
    echo "  5. Update environment alias"
    echo "  6. Tag rollback deployment"
    echo ""
    
    echo "⚠️  Rollback Considerations:"
    echo "  - Database migrations may need manual handling"
    echo "  - Environment variables will remain unchanged"
    echo "  - External dependencies should be compatible"
    echo "  - Monitor application health after rollback"
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-retrieve}" in
        "retrieve")
            retrieve_rollback_artifact "${2:-}" "${3:-}"
            ;;
        "candidates")
            get_rollback_candidates "${2:-}" "${3:-5}"
            ;;
        "current")
            get_current_deployment_info "${2:-${LAMBDA_FUNCTION_NAME}}"
            ;;
        "plan")
            create_rollback_plan "${2:-}" "${3:-}"
            ;;
        *)
            echo "Usage: $0 [retrieve|candidates|current|plan] [args...]"
            echo "  retrieve <version> <env>  - Retrieve rollback artifact"
            echo "  candidates <env> [limit]  - List rollback candidates"
            echo "  current [function]        - Show current deployment info"
            echo "  plan <version> <env>      - Create rollback plan"
            exit 1
            ;;
    esac
fi