#!/bin/bash
set -euo pipefail

# version-conflicts.sh - Check for version conflicts before deployment

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

check_version_conflicts() {
    local environment="${1:-}"
    local version="${2:-}"
    local force_deploy="${3:-false}"
    
    if [[ -z "$environment" || -z "$version" ]]; then
        echo "::error::Environment and version are required for conflict checking"
        return 1
    fi
    
    echo "🔍 Checking version conflicts for $version in $environment environment..."
    
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    # Skip version check for dev environment or if force deploy is enabled
    if [[ "$environment" == "dev" || "$force_deploy" == "true" ]]; then
        echo "Skipping version conflict check (environment: $environment, force: $force_deploy)"
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    # Environment-specific version conflict checking
    case "$environment" in
        "dev"|"development")
            handle_dev_environment "$version"
            ;;
        "pre"|"staging"|"test")
            handle_staging_environment "$version" "$s3_bucket" "$lambda_function" "$force_deploy"
            ;;
        "prod"|"production")
            handle_production_environment "$version" "$s3_bucket" "$lambda_function" "$force_deploy"
            ;;
        *)
            handle_unknown_environment "$environment" "$version" "$s3_bucket" "$lambda_function" "$force_deploy"
            ;;
    esac
    
    echo "✅ Version conflict check completed"
}

handle_dev_environment() {
    local version="$1"
    
    echo "🔧 Development environment: Always allow deployment"
    echo "can-deploy=true" >> "$GITHUB_OUTPUT"
    echo "deployment-strategy=timestamp-based" >> "$GITHUB_OUTPUT"
}

handle_staging_environment() {
    local version="$1"
    local s3_bucket="$2"
    local lambda_function="$3"
    local force_deploy="$4"
    
    echo "🧪 Staging environment: Flexible version policy"
    
    # Check if version exists in staging environment specifically
    # Use the actual S3 structure: lambda_function/pre/version.zip
    local staging_s3_key="$lambda_function/pre/$version.zip"
    local staging_s3_path="s3://$s3_bucket/$staging_s3_key"
    
    if [[ "$force_deploy" == "true" ]]; then
        echo "🚨 Force deployment enabled - bypassing version checks"
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=force-overwrite" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    echo "Checking for existing version at: $staging_s3_path"
    if check_version_exists_in_s3_object "$s3_bucket" "$staging_s3_key"; then
        echo "⚠️  Version $version already exists in staging environment"
        echo "::warning::Version $version exists in staging environment"
        echo "::notice::Allowing overwrite for staging testing flexibility"
        echo "::notice::Consider using pre-release versions: $version-rc.1"
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=staging-overwrite" >> "$GITHUB_OUTPUT"
    else
        echo "✅ Version $version is new in staging environment"
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=new-version" >> "$GITHUB_OUTPUT"
    fi
}

handle_production_environment() {
    local version="$1"
    local s3_bucket="$2"
    local lambda_function="$3"
    local force_deploy="$4"
    
    echo "🏭 Production environment: Strict version conflict checking"
    
    # Check if version exists in production environment specifically
    # Use the actual S3 structure: lambda_function/prod/version.zip
    local prod_s3_key="$lambda_function/prod/$version.zip"
    local prod_s3_path="s3://$s3_bucket/$prod_s3_key"
    
    if [[ "$force_deploy" == "true" ]]; then
        echo "🚨 Force deployment enabled in PRODUCTION"
        echo "::warning::Force deployment bypasses all safety checks"
        echo "::warning::This should only be used for emergency hotfixes"
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=emergency-override" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    echo "Checking for existing version at: $prod_s3_path"
    if check_version_exists_in_s3_object "$s3_bucket" "$prod_s3_key"; then
        echo "❌ Version conflict in PRODUCTION environment"
        echo "::error::Version $version already exists in production"
        echo "::error::Production requires unique versions for audit and rollback"
        
        # Provide helpful error messages and suggestions
        provide_version_conflict_resolution "$version"
        
        echo "can-deploy=false" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=blocked" >> "$GITHUB_OUTPUT"
        return 1
    else
        echo "✅ Version $version is new in PRODUCTION environment"
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=new-version" >> "$GITHUB_OUTPUT"
    fi
}

handle_unknown_environment() {
    local environment="$1"
    local version="$2"
    local s3_bucket="$3"
    local lambda_function="$4"
    local force_deploy="$5"
    
    echo "🤔 Unknown environment: $environment (applying production policies)"
    echo "::warning::Unknown environment, using strict version checking"
    
    # Use the actual S3 structure: lambda_function/environment/version.zip
    local unknown_s3_key="$lambda_function/$environment/$version.zip"
    local unknown_s3_path="s3://$s3_bucket/$unknown_s3_key"
    
    if [[ "$force_deploy" == "true" ]]; then
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=force-unknown" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    echo "Checking for existing version at: $unknown_s3_path"
    if check_version_exists_in_s3_object "$s3_bucket" "$unknown_s3_key"; then
        echo "::error::Version conflict in $environment environment"
        echo "can-deploy=false" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=blocked" >> "$GITHUB_OUTPUT"
        return 1
    else
        echo "can-deploy=true" >> "$GITHUB_OUTPUT"
        echo "deployment-strategy=new-version" >> "$GITHUB_OUTPUT"
    fi
}

check_version_exists_in_s3() {
    local s3_path="$1"
    
    echo "Checking S3 path: $s3_path"
    
    if aws_retry 3 aws s3 ls "$s3_path" > /dev/null 2>&1; then
        return 0  # Version exists
    else
        return 1  # Version does not exist
    fi
}

check_version_exists_in_s3_object() {
    local s3_bucket="$1"
    local s3_key="$2"
    
    echo "Checking S3 object: s3://$s3_bucket/$s3_key"
    
    # Use direct AWS CLI call instead of aws_retry for object existence check
    # 404 errors are not retryable - they definitively mean the object doesn't exist
    if aws s3api head-object --bucket "$s3_bucket" --key "$s3_key" > /dev/null 2>&1; then
        echo "✅ Object exists"
        return 0  # Object exists
    else
        local exit_code=$?
        echo "❌ Object does not exist (exit code: $exit_code)"
        return 1  # Object does not exist
    fi
}

provide_version_conflict_resolution() {
    local current_version="$1"
    
    echo "::error::Resolution options:"
    echo "::error::  1. Increment version (recommended)"
    
    # Provide version increment suggestions if it's semantic versioning
    if [[ "$current_version" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"  
        local patch="${BASH_REMATCH[3]}"
        
        local suggested_patch="$major.$minor.$((patch + 1))"
        local suggested_minor="$major.$((minor + 1)).0"
        local suggested_major="$((major + 1)).0.0"
        
        echo "::error::     Next patch: $suggested_patch"
        echo "::error::     Next minor: $suggested_minor"
        echo "::error::     Next major: $suggested_major"
        
        # Provide specific commands based on detected version files
        suggest_version_update_commands "$suggested_patch"
    fi
    
    echo "::error::  2. Use force-deploy: true (emergency only)"
    echo "::error::  3. Deploy to staging first, then promote to production"
}

suggest_version_update_commands() {
    local suggested_version="$1"
    
    # Check for different version files and provide appropriate commands
    if [[ -f "pyproject.toml" ]]; then
        echo "::error::     Update command: sed -i 's/version = \".*\"/version = \"$suggested_version\"/' pyproject.toml"
    fi
    
    if [[ -f "package.json" ]]; then
        echo "::error::     Update command: npm version $suggested_version --no-git-tag-version"
    fi
    
    if [[ -f "version.txt" ]]; then
        echo "::error::     Update command: echo '$suggested_version' > version.txt"
    fi
    
    if [[ -f "VERSION" ]]; then
        echo "::error::     Update command: echo '$suggested_version' > VERSION"
    fi
}

# Get version history for an environment
get_environment_version_history() {
    local environment="${1:-}"
    local limit="${2:-10}"
    
    if [[ -z "$environment" ]]; then
        echo "::error::Environment is required for version history"
        return 1
    fi
    
    echo "📋 Getting version history for $environment environment (limit: $limit)"
    
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    # Use the actual S3 structure: lambda_function/environment/
    local env_s3_path="s3://$s3_bucket/$lambda_function/$environment/"
    
    echo "Listing versions from: $env_s3_path"
    
    local versions_file="/tmp/versions-$environment.txt"
    
    if aws_retry 3 aws s3 ls "$env_s3_path" > "$versions_file" 2>/dev/null; then
        if [[ -s "$versions_file" ]]; then
            echo "Available versions in $environment:"
            
            # Extract version numbers from .zip files and sort them
            grep "\.zip$" "$versions_file" | \
                grep -v "latest.zip" | \
                awk '{print $4}' | \
                sed 's/\.zip$//' | \
                sort -V -r | \
                head -"$limit" | \
                nl -w2 -s'. '
        else
            echo "No versions found in $environment environment"
        fi
    else
        echo "::warning::Failed to retrieve version history for $environment"
        echo "This may be normal if no versions have been deployed yet"
    fi
    
    rm -f "$versions_file"
}

# Check deployment readiness
check_deployment_readiness() {
    local environment="${1:-}"
    local version="${2:-}"
    
    echo "🎯 Checking deployment readiness..."
    
    # Validate prerequisites
    local prerequisites_met=true
    
    # Check if version is set
    if [[ -z "$version" ]]; then
        echo "::error::Version not specified"
        prerequisites_met=false
    fi
    
    # Check if environment is valid
    case "$environment" in
        "dev"|"pre"|"prod"|"development"|"staging"|"test"|"production")
            echo "✅ Valid environment: $environment"
            ;;
        *)
            echo "::warning::Unknown environment: $environment"
            ;;
    esac
    
    # Check if AWS resources are accessible
    if [[ -z "${S3_BUCKET_NAME:-}" ]]; then
        echo "::error::S3_BUCKET_NAME not set"
        prerequisites_met=false
    fi
    
    if [[ -z "${LAMBDA_FUNCTION_NAME:-}" ]]; then
        echo "::error::LAMBDA_FUNCTION_NAME not set"
        prerequisites_met=false
    fi
    
    if $prerequisites_met; then
        echo "✅ Deployment prerequisites satisfied"
        echo "deployment-ready=true" >> "$GITHUB_OUTPUT"
    else
        echo "❌ Deployment prerequisites not satisfied"
        echo "deployment-ready=false" >> "$GITHUB_OUTPUT"
        return 1
    fi
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-check}" in
        "check")
            check_version_conflicts "${2:-}" "${3:-}" "${4:-false}"
            ;;
        "history")
            get_environment_version_history "${2:-}" "${3:-10}"
            ;;
        "readiness")
            check_deployment_readiness "${2:-}" "${3:-}"
            ;;
        *)
            echo "Usage: $0 [check|history|readiness] [args...]"
            echo "  check <env> <version> [force]  - Check version conflicts"
            echo "  history <env> [limit]          - Get version history"
            echo "  readiness <env> <version>      - Check deployment readiness"
            exit 1
            ;;
    esac
fi