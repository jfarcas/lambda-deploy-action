#!/bin/bash
set -euo pipefail

# deployer.sh - Main deployment logic for Lambda functions

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

deploy_to_lambda() {
    local deployment_mode="${1:-deploy}"
    local environment="${2:-}"
    
    if [[ -z "$environment" ]]; then
        echo "::error::Environment is required for deployment"
        return 1
    fi
    
    echo "🚀 Starting Lambda deployment..."
    echo "  Mode: $deployment_mode"
    echo "  Environment: $environment"
    
    case "$deployment_mode" in
        "deploy")
            perform_normal_deployment "$environment"
            ;;
        "rollback")
            perform_rollback_deployment "$environment"
            ;;
        *)
            echo "::error::Unknown deployment mode: $deployment_mode"
            return 1
            ;;
    esac
    
    echo "✅ Lambda deployment completed successfully"
}

perform_normal_deployment() {
    local environment="$1"
    
    echo "🔄 Performing normal deployment to $environment environment..."
    
    # Get deployment variables
    local version="${DETECTED_VERSION:-}"
    local artifact_path="${ARTIFACT_PATH:-}"
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    local aws_region="${AWS_REGION:-}"
    
    # Validate required variables
    validate_deployment_variables "$version" "$artifact_path" "$s3_bucket" "$lambda_function" "$aws_region"
    
    # Upload to S3 with environment-specific paths
    local s3_key
    echo "🔍 DEBUG: About to call upload_to_s3..." >&2
    echo "🔍 DEBUG: Parameters: artifact_path=$artifact_path, environment=$environment, version=$version, s3_bucket=$s3_bucket, lambda_function=$lambda_function" >&2
    
    s3_key=$(upload_to_s3 "$artifact_path" "$environment" "$version" "$s3_bucket" "$lambda_function")
    
    echo "🔍 DEBUG: upload_to_s3 returned s3_key='$s3_key'" >&2
    echo "🔍 DEBUG: s3_key length: ${#s3_key}" >&2
    echo "🔍 DEBUG: s3_key first 100 chars: '${s3_key:0:100}'" >&2
    
    # Validate s3_key format
    if [[ "$s3_key" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        echo "🔍 DEBUG: s3_key format looks valid" >&2
    else
        echo "🔍 DEBUG: s3_key format is INVALID - contains unexpected characters" >&2
        echo "🔍 DEBUG: Full s3_key content:" >&2
        echo "$s3_key" | head -10 >&2
        echo "🔍 DEBUG: End of s3_key content" >&2
        echo "::error::S3 key contains invalid characters, aborting deployment" >&2
        return 1
    fi
    
    # Additional validation: check if s3_key is a single line
    local s3_key_lines
    s3_key_lines=$(echo "$s3_key" | wc -l)
    if [[ $s3_key_lines -ne 1 ]]; then
        echo "🔍 DEBUG: s3_key contains multiple lines ($s3_key_lines lines) - this is wrong!" >&2
        echo "🔍 DEBUG: s3_key content:" >&2
        echo "$s3_key" >&2
        echo "::error::S3 key contains multiple lines, aborting deployment" >&2
        return 1
    fi
    
    # Update Lambda function
    local lambda_version
    if ! lambda_version=$(update_lambda_function "$s3_bucket" "$s3_key" "$lambda_function" "$version" "$environment"); then
        echo "::error::Lambda function update failed, aborting deployment"
        return 1
    fi
    
    # Tag the deployment
    tag_lambda_deployment "$lambda_function" "$version" "$environment" "deploy" "$aws_region"
    
    # Create environment alias
    create_environment_alias "$lambda_function" "$environment" "$lambda_version" "$version"
    
    # Set outputs
    set_deployment_outputs "$lambda_version" "$s3_bucket" "$s3_key" "deploy" "$version"
    
    echo "🎉 Normal deployment completed successfully"
}

perform_rollback_deployment() {
    local environment="$1"
    
    echo "🔄 Performing rollback deployment to $environment environment..."
    
    # Get rollback variables (should be set by rollback-retriever.sh)
    local rollback_version="${TARGET_VERSION:-}"
    local rollback_artifact="${ROLLBACK_ARTIFACT_PATH:-}"
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    local aws_region="${AWS_REGION:-}"
    
    if [[ -z "$rollback_version" ]]; then
        echo "::error::Rollback version not specified"
        return 1
    fi
    
    # Use existing S3 artifact for rollback
    local s3_key
    s3_key=$(get_rollback_s3_key "$environment" "$rollback_version" "$lambda_function")
    
    # Update Lambda function with rollback artifact
    local lambda_version
    if ! lambda_version=$(update_lambda_function "$s3_bucket" "$s3_key" "$lambda_function" "$rollback_version" "$environment"); then
        echo "::error::Lambda function rollback failed, aborting rollback"
        return 1
    fi
    
    # Tag the rollback
    tag_lambda_deployment "$lambda_function" "$rollback_version" "$environment" "rollback" "$aws_region"
    
    # Update environment alias
    create_environment_alias "$lambda_function" "$environment" "$lambda_version" "$rollback_version"
    
    # Set outputs
    set_deployment_outputs "$lambda_version" "$s3_bucket" "$s3_key" "rollback" "$rollback_version"
    
    echo "🎉 Rollback deployment completed successfully"
}

validate_deployment_variables() {
    local version="$1"
    local artifact_path="$2"
    local s3_bucket="$3"
    local lambda_function="$4"
    local aws_region="$5"
    
    echo "🔍 Validating deployment variables..."
    
    local validation_failed=false
    
    if [[ -z "$version" ]]; then
        echo "::error::Version not specified"
        validation_failed=true
    fi
    
    if [[ -z "$artifact_path" || ! -f "$artifact_path" ]]; then
        echo "::error::Artifact not found: $artifact_path"
        validation_failed=true
    fi
    
    if [[ -z "$s3_bucket" ]]; then
        echo "::error::S3 bucket not specified"
        validation_failed=true
    fi
    
    if [[ -z "$lambda_function" ]]; then
        echo "::error::Lambda function not specified"
        validation_failed=true
    fi
    
    if [[ -z "$aws_region" ]]; then
        echo "::error::AWS region not specified"
        validation_failed=true
    fi
    
    if $validation_failed; then
        return 1
    fi
    
    echo "✅ Deployment variables validated"
}

upload_to_s3() {
    local artifact_path="$1"
    local environment="$2"
    local version="$3"
    local s3_bucket="$4"
    local lambda_function="$5"
    
    echo "📦 Uploading package to S3..." >&2
    
    # Generate environment-specific S3 key
    local timestamp
    timestamp=$(date +%s)
    local s3_key_base="$lambda_function"
    local s3_key
    
    # Environment-specific S3 paths with proper isolation
    case "$environment" in
        "dev"|"development")
            # Dev: Use shorter timestamp-based paths for rapid iteration
            s3_key="$s3_key_base/dev/$timestamp.zip"
            ;;
        "pre"|"staging"|"test")
            # Pre: Shorter environment-specific versioned paths
            s3_key="$s3_key_base/pre/$version.zip"
            ;;
        "prod"|"production")
            # Prod: Shorter environment-specific versioned paths
            s3_key="$s3_key_base/prod/$version.zip"
            ;;
        *)
            # Unknown environment: Use shorter environment-specific path
            s3_key="$s3_key_base/$environment/$version.zip"
            ;;
    esac
    
    echo "S3 destination: s3://$s3_bucket/$s3_key" >&2
    
    # Prepare metadata
    local metadata
    metadata=$(prepare_s3_metadata "$environment" "$version")
    
    # Upload with retry logic
    echo "🔍 DEBUG: About to upload to S3 with aws_retry..." >&2
    echo "🔍 DEBUG: Command will be: aws s3 cp $artifact_path s3://$s3_bucket/$s3_key --metadata $metadata --no-progress --quiet" >&2
    
    if aws_retry 3 aws s3 cp "$artifact_path" "s3://$s3_bucket/$s3_key" --metadata "$metadata" --no-progress --quiet >&2; then
        echo "✅ Package uploaded successfully" >&2
        
        # Also update the "latest" pointer for this environment
        update_latest_pointer "$artifact_path" "$s3_bucket" "$s3_key_base" "$environment" "$version"
        
        echo "🔍 DEBUG: About to return s3_key='$s3_key'" >&2
        echo "$s3_key"
    else
        echo "::error::Failed to upload package to S3" >&2
        return 1
    fi
}

prepare_s3_metadata() {
    local environment="$1"
    local version="$2"
    
    local commit_hash
    local branch_name
    local deploy_timestamp
    
    commit_hash=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    deploy_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local metadata="environment=$environment,version=$version,deployed_at=$deploy_timestamp,commit=$commit_hash"
    
    # Add branch info for non-production environments
    if [[ "$environment" != "prod" && "$environment" != "production" ]]; then
        metadata="$metadata,branch=$branch_name"
    fi
    
    # Add deployer info if available
    if [[ -n "${GITHUB_ACTOR:-}" ]]; then
        metadata="$metadata,deployed_by=${GITHUB_ACTOR}"
    fi
    
    echo "$metadata"
}

update_latest_pointer() {
    local artifact_path="$1"
    local s3_bucket="$2"
    local s3_key_base="$3"
    local environment="$4"
    local version="$5"
    
    echo "🔗 Updating latest pointer for $environment environment..." >&2
    
    local latest_key="$s3_key_base/$environment/latest.zip"
    local latest_metadata="environment=$environment,version=$version,updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    if aws_retry 2 aws s3 cp "$artifact_path" "s3://$s3_bucket/$latest_key" --metadata "$latest_metadata" --no-progress --quiet >&2; then
        echo "✅ Latest pointer updated" >&2
    else
        echo "::warning::Failed to update latest pointer (non-critical)" >&2
    fi
}

update_lambda_function() {
    local s3_bucket="$1"
    local s3_key="$2"
    local lambda_function="$3"
    local version="$4"
    local environment="$5"
    
    echo "🔄 Updating Lambda function code..." >&2
    echo "🔍 DEBUG: update_lambda_function received parameters:" >&2
    echo "🔍 DEBUG: s3_bucket='$s3_bucket'" >&2
    echo "🔍 DEBUG: s3_key='$s3_key'" >&2
    echo "🔍 DEBUG: s3_key length: ${#s3_key}" >&2
    echo "🔍 DEBUG: lambda_function='$lambda_function'" >&2
    
    local retry_count=0
    local max_retries=3
    
    while [[ $retry_count -lt $max_retries ]]; do
        echo "Attempt $((retry_count + 1))/$max_retries: Updating function code..." >&2
        
        # First update the function code without publishing
        if aws_retry 3 aws lambda update-function-code \
            --function-name "$lambda_function" \
            --s3-bucket "$s3_bucket" \
            --s3-key "$s3_key" > /tmp/lambda-update.json; then
            
            # Wait for function to be ready
            if wait_for_lambda_ready "$lambda_function" 120 2; then
                
                # Publish a version with description
                local version_description
                version_description=$(create_version_description "$environment" "$version")
                
                echo "📝 Publishing Lambda version with description..." >&2
                if publish_lambda_version "$lambda_function" "$version_description"; then
                    # Get the published version number
                    local lambda_version
                    lambda_version=$(/usr/bin/jq -r '.Version' /tmp/lambda-publish.json 2>/dev/null || /usr/bin/jq -r '.Version' /tmp/lambda-update.json)
                    
                    echo "✅ Lambda function updated successfully" >&2
                    echo "  Function: $lambda_function" >&2
                    echo "  Version: $lambda_version" >&2
                    echo "  S3 Location: s3://$s3_bucket/$s3_key" >&2
                    
                    echo "$lambda_version"
                    return 0
                else
                    echo "::warning::Failed to publish version, but function code was updated" >&2
                    local lambda_version
                    lambda_version=$(/usr/bin/jq -r '.Version' /tmp/lambda-update.json 2>/dev/null || echo "\$LATEST")
                    echo "$lambda_version"
                    return 0
                fi
            else
                echo "::warning::Function did not become ready, but continuing..." >&2
                local lambda_version
                lambda_version=$(/usr/bin/jq -r '.Version' /tmp/lambda-update.json 2>/dev/null || echo "\$LATEST")
                echo "$lambda_version"
                return 0
            fi
        else
            ((retry_count++))
            if [[ $retry_count -eq $max_retries ]]; then
                echo "::error::Failed to update Lambda function after $max_retries attempts" >&2
                return 1
            fi
            echo "Retrying in 10 seconds..." >&2
            sleep 10
        fi
    done
}

create_version_description() {
    local environment="$1"
    local version="$2"
    
    local commit_short
    local branch_name
    local deploy_timestamp
    local deployer
    
    commit_short=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    deploy_timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    deployer="${GITHUB_ACTOR:-system}"
    
    case "$environment" in
        "dev"|"development")
            echo "DEV: v$version | $commit_short | $deploy_timestamp | by $deployer"
            ;;
        "pre"|"staging"|"test")
            echo "PRE: v$version | $branch_name | $commit_short | $deploy_timestamp | by $deployer"
            ;;
        "prod"|"production")
            echo "PROD: v$version | $branch_name | $commit_short | $deploy_timestamp | by $deployer"
            ;;
        *)
            echo "$environment: v$version | $commit_short | $deploy_timestamp | by $deployer"
            ;;
    esac
}

publish_lambda_version() {
    local lambda_function="$1"
    local version_description="$2"
    
    local publish_attempts=0
    local max_publish_attempts=3
    
    while [[ $publish_attempts -lt $max_publish_attempts ]]; do
        ((publish_attempts++))
        echo "Publishing version attempt $publish_attempts/$max_publish_attempts..." >&2
        
        if aws_retry 2 aws lambda publish-version \
            --function-name "$lambda_function" \
            --description "$version_description" > /tmp/lambda-publish.json 2>/tmp/lambda-publish-error.log; then
            
            echo "✅ Version published successfully" >&2
            return 0
        else
            local publish_error
            publish_error=$(cat /tmp/lambda-publish-error.log 2>/dev/null || echo "Unknown error")
            echo "::warning::Failed to publish version (attempt $publish_attempts/$max_publish_attempts): $publish_error" >&2
            
            if [[ $publish_attempts -eq $max_publish_attempts ]]; then
                echo "::error::Failed to publish version after $max_publish_attempts attempts" >&2
                return 1
            fi
            
            echo "Waiting 5 seconds before retry..." >&2
            sleep 5
        fi
    done
}

tag_lambda_deployment() {
    local lambda_function="$1"
    local version="$2"
    local environment="$3"
    local deployment_type="$4"
    local aws_region="$5"
    
    echo "🏷️ Tagging Lambda function deployment..."
    
    # Get account ID
    local account_id
    account_id="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'unknown')}"
    
    if [[ "$account_id" == "unknown" ]]; then
        echo "::warning::Could not determine account ID for tagging"
        return 0
    fi
    
    local function_arn="arn:aws:lambda:$aws_region:$account_id:function:$lambda_function"
    local timestamp
    timestamp=$(date +%s)
    
    # Prepare tags based on deployment type
    local tags
    if [[ "$deployment_type" == "rollback" ]]; then
        tags="Version=$version,Environment=$environment,DeploymentType=rollback,RollbackBy=${GITHUB_ACTOR:-system},RollbackTimestamp=$timestamp"
    else
        local commit_sha
        local branch_name
        commit_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        
        tags="Version=$version,Environment=$environment,DeploymentType=deploy,CommitSHA=$commit_sha,Branch=$branch_name,DeployedBy=${GITHUB_ACTOR:-system},Timestamp=$timestamp"
    fi
    
    if aws_retry 2 aws lambda tag-resource --resource "$function_arn" --tags "$tags"; then
        echo "✅ Lambda function tagged successfully"
    else
        echo "::warning::Failed to tag Lambda function (non-critical)"
    fi
}

create_environment_alias() {
    local lambda_function="$1"
    local environment="$2"
    local lambda_version="$3"
    local deployment_version="$4"
    
    echo "🏷️ Creating environment-specific alias..."
    
    local alias_name="${environment}-current"
    
    # Delete existing alias if it exists (ignore errors)
    aws lambda delete-alias \
        --function-name "$lambda_function" \
        --name "$alias_name" 2>/dev/null || true
    
    # Create new alias pointing to this version
    local alias_description="Current $environment environment version: v$deployment_version"
    
    if aws_retry 2 aws lambda create-alias \
        --function-name "$lambda_function" \
        --name "$alias_name" \
        --function-version "$lambda_version" \
        --description "$alias_description" > /dev/null 2>&1; then
        
        echo "✅ Created alias: $alias_name → Version $lambda_version"
        echo "   Invoke with: $lambda_function:$alias_name"
    else
        echo "::warning::Failed to create alias $alias_name (non-critical)"
    fi
}

get_rollback_s3_key() {
    local environment="$1"
    local version="$2"
    local lambda_function="$3"
    
    # Normalize version (remove 'v' prefix if present)
    local normalized_version
    normalized_version=$(echo "$version" | sed 's/^v//')
    
    # Generate environment-specific S3 key for rollback
    case "$environment" in
        "pre"|"staging"|"test")
            echo "$lambda_function/pre/$normalized_version.zip"
            ;;
        "prod"|"production")
            echo "$lambda_function/prod/$normalized_version.zip"
            ;;
        *)
            echo "$lambda_function/$environment/$normalized_version.zip"
            ;;
    esac
}

set_deployment_outputs() {
    local lambda_version="$1"
    local s3_bucket="$2"
    local s3_key="$3"
    local deployment_type="$4"
    local version="$5"
    
    echo "📋 Setting deployment outputs..."
    
    # Get package size if possible
    local package_size
    if [[ -n "${ARTIFACT_PATH:-}" && -f "${ARTIFACT_PATH}" ]]; then
        package_size=$(stat -c%s "${ARTIFACT_PATH}" 2>/dev/null || stat -f%z "${ARTIFACT_PATH}" 2>/dev/null || echo "unknown")
    else
        package_size="unknown"
    fi
    
    # Set GitHub Action outputs
    echo "lambda-version=$lambda_version" >> "$GITHUB_OUTPUT"
    echo "s3-location=s3://$s3_bucket/$s3_key" >> "$GITHUB_OUTPUT"
    echo "package-size=$package_size" >> "$GITHUB_OUTPUT"
    echo "deployment-type=$deployment_type" >> "$GITHUB_OUTPUT"
    echo "deployed-version=$version" >> "$GITHUB_OUTPUT"
    
    echo "✅ Deployment outputs set"
    echo "  Lambda Version: $lambda_version"
    echo "  S3 Location: s3://$s3_bucket/$s3_key"
    echo "  Package Size: $(numfmt --to=iec "$package_size" 2>/dev/null || echo "$package_size bytes")"
}

# Get deployment status and information
get_deployment_info() {
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    if [[ -z "$lambda_function" ]]; then
        echo "::error::Lambda function name not specified"
        return 1
    fi
    
    echo "ℹ️  Deployment Information:"
    
    # Get function configuration
    local function_info
    if function_info=$(aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
        if command -v /usr/bin/jq >/dev/null 2>&1; then
            local state last_modified code_size runtime
            state=$(echo "$function_info" | /usr/bin/jq -r '.Configuration.State')
            last_modified=$(echo "$function_info" | /usr/bin/jq -r '.Configuration.LastModified')
            code_size=$(echo "$function_info" | /usr/bin/jq -r '.Configuration.CodeSize')
            runtime=$(echo "$function_info" | /usr/bin/jq -r '.Configuration.Runtime')
            
            echo "  Function: $lambda_function"
            echo "  State: $state"
            echo "  Runtime: $runtime"
            echo "  Code Size: $(numfmt --to=iec "$code_size" 2>/dev/null || echo "$code_size bytes")"
            echo "  Last Modified: $last_modified"
        fi
        
        # Get function tags if possible
        local account_id aws_region
        account_id="${AWS_ACCOUNT_ID:-}"
        aws_region="${AWS_REGION:-}"
        
        if [[ -n "$account_id" && -n "$aws_region" ]]; then
            local function_arn="arn:aws:lambda:$aws_region:$account_id:function:$lambda_function"
            local tags
            if tags=$(aws lambda list-tags --resource "$function_arn" 2>/dev/null); then
                if command -v /usr/bin/jq >/dev/null 2>&1; then
                    local version environment
                    version=$(echo "$tags" | /usr/bin/jq -r '.Tags.Version // "unknown"')
                    environment=$(echo "$tags" | /usr/bin/jq -r '.Tags.Environment // "unknown"')
                    
                    echo "  Tagged Version: $version"
                    echo "  Tagged Environment: $environment"
                fi
            fi
        fi
    else
        echo "  Cannot retrieve function information"
    fi
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-deploy}" in
        "deploy")
            deploy_to_lambda "${2:-deploy}" "${3:-prod}"
            ;;
        "info")
            get_deployment_info
            ;;
        *)
            echo "Usage: $0 [deploy|info] [deployment_mode] [environment]"
            echo "  deploy - Perform Lambda deployment"
            echo "  info   - Get deployment information"
            exit 1
            ;;
    esac
fi