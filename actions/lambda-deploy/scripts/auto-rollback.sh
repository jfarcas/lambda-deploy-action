#!/bin/bash
set -euo pipefail

# auto-rollback.sh - Automatic rollback on deployment failure

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/deployer.sh"

perform_auto_rollback() {
    local last_version="${1:-}"
    local environment="${2:-}"
    
    if [[ -z "$last_version" || -z "$environment" ]]; then
        echo "::error::Last version and environment are required for auto-rollback"
        return 1
    fi
    
    echo "🚨 Deployment failure detected, initiating auto-rollback..."
    echo "  Target Version: $last_version"
    echo "  Environment: $environment"
    
    # Check if auto-rollback is enabled and configured properly
    validate_auto_rollback_configuration "$environment"
    
    # Get rollback configuration
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    local max_attempts strategy
    
    max_attempts=$(yq eval '.deployment.auto_rollback.behavior.max_attempts // 1' "$config_file")
    strategy=$(yq eval '.deployment.auto_rollback.strategy // "last_successful"' "$config_file")
    
    echo "Auto-rollback configuration:"
    echo "  Strategy: $strategy"
    echo "  Max Attempts: $max_attempts"
    
    # Determine rollback target version
    local rollback_version
    rollback_version=$(determine_rollback_target "$strategy" "$last_version" "$config_file")
    
    if [[ -z "$rollback_version" ]]; then
        echo "::error::No rollback target version available"
        echo "::error::Cannot perform automatic rollback"
        return 1
    fi
    
    echo "🎯 Rolling back to version: $rollback_version"
    
    # Perform the auto-rollback deployment
    execute_auto_rollback "$rollback_version" "$environment"
    
    # Set outputs
    echo "rollback-completed=true" >> "$GITHUB_OUTPUT"
    echo "rollback-version=$rollback_version" >> "$GITHUB_OUTPUT"
    
    echo "✅ Auto-rollback completed successfully!"
}

validate_auto_rollback_configuration() {
    local environment="$1"
    
    echo "🔍 Validating auto-rollback configuration..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Check if auto-rollback is enabled
    local auto_rollback_enabled on_deployment_failure
    auto_rollback_enabled=$(yq eval '.deployment.auto_rollback.enabled // false' "$config_file")
    on_deployment_failure=$(yq eval '.deployment.auto_rollback.triggers.on_deployment_failure // true' "$config_file")
    
    if [[ "$auto_rollback_enabled" != "true" ]]; then
        echo "Auto-rollback is disabled, skipping automatic rollback"
        exit 0
    fi
    
    if [[ "$on_deployment_failure" != "true" ]]; then
        echo "Auto-rollback on deployment failure is disabled"
        exit 0
    fi
    
    # Check if rollback is supported for this environment
    case "$environment" in
        "dev"|"development")
            echo "::error::Auto-rollback not supported for dev environment"
            echo "::error::Dev deployments use timestamp-based paths, not versions"
            exit 1
            ;;
        "pre"|"staging"|"test"|"prod"|"production")
            echo "✅ Auto-rollback supported for $environment environment"
            ;;
        *)
            echo "::warning::Unknown environment: $environment"
            echo "Proceeding with auto-rollback attempt..."
            ;;
    esac
    
    echo "✅ Auto-rollback validation passed"
}

determine_rollback_target() {
    local strategy="$1"
    local last_version="$2"
    local config_file="$3"
    
    echo "🎯 Determining rollback target using strategy: $strategy"
    
    local rollback_version=""
    
    case "$strategy" in
        "last_successful")
            rollback_version="$last_version"
            echo "Using last successful version: $rollback_version"
            ;;
        "specific_version")
            rollback_version=$(yq eval '.deployment.auto_rollback.target_version // ""' "$config_file")
            echo "Using specific version from configuration: $rollback_version"
            ;;
        "previous_stable")
            # Try to get the version before the current failed deployment
            rollback_version=$(get_previous_stable_version "$last_version")
            echo "Using previous stable version: $rollback_version"
            ;;
        *)
            echo "::error::Unknown rollback strategy: $strategy"
            return 1
            ;;
    esac
    
    # Validate the rollback version
    if [[ -z "$rollback_version" ]]; then
        echo "::error::Could not determine rollback target version"
        return 1
    fi
    
    # Normalize version (remove 'v' prefix if present)
    rollback_version=$(echo "$rollback_version" | sed 's/^v//')
    
    echo "$rollback_version"
}

get_previous_stable_version() {
    local current_version="$1"
    local environment="${DEPLOYMENT_ENVIRONMENT:-prod}"
    
    echo "🔍 Looking for previous stable version before: $current_version"
    
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    if [[ -z "$s3_bucket" || -z "$lambda_function" ]]; then
        echo "::warning::Cannot determine previous version without S3 bucket and function name"
        echo "$current_version"  # Fallback to current version
        return 0
    fi
    
    # Get environment-specific versions path
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
    
    # List versions and find the one before current
    local versions_file="/tmp/stable-versions.txt"
    
    if aws s3 ls "s3://$s3_bucket/$versions_prefix" --recursive > "$versions_file" 2>/dev/null; then
        # Extract versions and sort them
        local previous_version
        previous_version=$(grep "\.zip$" "$versions_file" | \
            sed -E "s|.*versions/([^/]+)/.*|\1|" | \
            sort -V -r | \
            grep -A1 "^$current_version$" | \
            tail -1)
        
        if [[ -n "$previous_version" && "$previous_version" != "$current_version" ]]; then
            echo "Found previous stable version: $previous_version"
            echo "$previous_version"
        else
            echo "No previous stable version found, using current: $current_version"
            echo "$current_version"
        fi
    else
        echo "::warning::Cannot access S3 versions, using current: $current_version"
        echo "$current_version"
    fi
    
    rm -f "$versions_file"
}

execute_auto_rollback() {
    local rollback_version="$1"
    local environment="$2"
    
    echo "🔄 Executing auto-rollback deployment..."
    
    # Set variables for rollback deployment
    local s3_bucket="${S3_BUCKET_NAME:-}"
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    local aws_region="${AWS_REGION:-}"
    
    # Normalize version (remove 'v' prefix if present)
    local normalized_version
    normalized_version=$(echo "$rollback_version" | sed 's/^v//')
    
    # Determine S3 key for rollback artifact using actual structure
    local s3_key
    case "$environment" in
        "pre"|"staging"|"test")
            s3_key="$lambda_function/pre/$normalized_version.zip"
            ;;
        "prod"|"production")
            s3_key="$lambda_function/prod/$normalized_version.zip"
            ;;
        *)
            s3_key="$lambda_function/$environment/$normalized_version.zip"
            ;;
    esac
    
    echo "🔍 Checking if rollback version exists..."
    echo "S3 location: s3://$s3_bucket/$s3_key"
    
    # Verify rollback artifact exists
    if ! aws_retry 3 aws s3api head-object --bucket "$s3_bucket" --key "$s3_key" > /dev/null 2>&1; then
        echo "::error::Rollback version $rollback_version not found in $environment environment"
        echo "::error::S3 location: s3://$s3_bucket/$s3_key"
        
        # List available versions for debugging using actual structure
        echo "Available versions in $environment:"
        aws s3 ls "s3://$s3_bucket/$lambda_function/$environment/" | \
            grep "\.zip$" | grep -v "latest.zip" | head -10 || echo "No versions found"
        
        return 1
    fi
    
    echo "✅ Rollback version found, proceeding with rollback..."
    
    # Update Lambda function with rollback version
    echo "🔄 Updating Lambda function to rollback version..."
    
    # Create rollback-specific version description
    local rollback_timestamp deployer rollback_description
    rollback_timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    deployer="${GITHUB_ACTOR:-system}"
    
    case "$environment" in
        "pre"|"staging"|"test")
            rollback_description="PRE-AUTO-ROLLBACK: v$normalized_version | by $deployer | $rollback_timestamp"
            ;;
        "prod"|"production")
            rollback_description="PROD-AUTO-ROLLBACK: v$normalized_version | by $deployer | $rollback_timestamp"
            ;;
        *)
            rollback_description="$environment-AUTO-ROLLBACK: v$normalized_version | by $deployer | $rollback_timestamp"
            ;;
    esac
    
    echo "📝 Rollback description: $rollback_description"
    
    # Update function code and wait for it to be ready
    if aws_retry 3 aws lambda update-function-code \
        --function-name "$lambda_function" \
        --s3-bucket "$s3_bucket" \
        --s3-key "$s3_key" > /tmp/auto-rollback-update.json; then
        
        # Wait for function to be ready for version publishing
        if wait_for_lambda_ready "$lambda_function" 120 2; then
            
            # Publish rollback version
            if aws_retry 3 aws lambda publish-version \
                --function-name "$lambda_function" \
                --description "$rollback_description" > /tmp/auto-rollback-publish.json; then
                
                echo "✅ Auto-rollback version published successfully"
                
                # Get rollback deployment info
                local lambda_version lambda_size
                lambda_version=$(jq -r '.Version' /tmp/auto-rollback-publish.json)
                lambda_size=$(jq -r '.CodeSize' /tmp/auto-rollback-publish.json)
                
                # Tag the auto-rollback
                tag_auto_rollback "$lambda_function" "$normalized_version" "$environment" "$aws_region"
                
                # Update environment alias
                update_environment_alias_for_rollback "$lambda_function" "$environment" "$lambda_version" "$normalized_version"
                
                echo "✅ Auto-rollback deployment completed successfully!"
                echo "  Rolled back to Version: $normalized_version"
                echo "  Lambda Version: $lambda_version"
                echo "  Package Size: $(numfmt --to=iec "$lambda_size" 2>/dev/null || echo "$lambda_size bytes")"
                
                # Set environment variables for other scripts
                echo "ROLLBACK_LAMBDA_VERSION=$lambda_version" >> "$GITHUB_ENV"
                echo "ROLLBACK_COMPLETED=true" >> "$GITHUB_ENV"
                
                return 0
            else
                echo "::error::Failed to publish auto-rollback version"
                return 1
            fi
        else
            echo "::error::Lambda function did not become ready for rollback version publishing"
            return 1
        fi
    else
        echo "::error::Failed to update Lambda function code for auto-rollback"
        return 1
    fi
}

tag_auto_rollback() {
    local lambda_function="$1"
    local version="$2"
    local environment="$3"
    local aws_region="$4"
    
    echo "🏷️ Tagging auto-rollback deployment..."
    
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
    
    local tags="Version=$version,Environment=$environment,DeploymentType=auto-rollback,RollbackBy=system,RollbackTimestamp=$timestamp,RollbackReason=deployment-failure"
    
    if aws_retry 2 aws lambda tag-resource --resource "$function_arn" --tags "$tags"; then
        echo "✅ Auto-rollback tagged successfully"
    else
        echo "::warning::Failed to tag auto-rollback (non-critical)"
    fi
}

update_environment_alias_for_rollback() {
    local lambda_function="$1"
    local environment="$2"
    local lambda_version="$3"
    local rollback_version="$4"
    
    echo "🏷️ Updating environment alias after auto-rollback..."
    
    local alias_name="${environment}-current"
    
    # Delete existing alias if it exists
    aws lambda delete-alias \
        --function-name "$lambda_function" \
        --name "$alias_name" 2>/dev/null || true
    
    # Create new alias pointing to rollback version
    if aws_retry 2 aws lambda create-alias \
        --function-name "$lambda_function" \
        --name "$alias_name" \
        --function-version "$lambda_version" \
        --description "Auto-rolled back $environment environment to: v$rollback_version" > /dev/null 2>&1; then
        
        echo "✅ Updated alias: $alias_name → Version $lambda_version (auto-rollback)"
    else
        echo "::warning::Failed to update alias after auto-rollback (non-critical)"
    fi
}

# Check if auto-rollback should be triggered
should_trigger_auto_rollback() {
    echo "🔍 Checking if auto-rollback should be triggered..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Check if we're in a deployment mode (not rollback)
    local deployment_mode="${DEPLOYMENT_MODE:-deploy}"
    if [[ "$deployment_mode" == "rollback" ]]; then
        echo "Already in rollback mode, skipping auto-rollback trigger"
        return 1
    fi
    
    # Check if auto-rollback is enabled
    local auto_rollback_enabled
    auto_rollback_enabled=$(yq eval '.deployment.auto_rollback.enabled // false' "$config_file")
    
    if [[ "$auto_rollback_enabled" != "true" ]]; then
        echo "Auto-rollback is disabled"
        return 1
    fi
    
    # Check if we have a last successful version
    local last_version="${LAST_SUCCESSFUL_VERSION:-}"
    if [[ -z "$last_version" ]]; then
        echo "No last successful version available for rollback"
        return 1
    fi
    
    echo "✅ Auto-rollback should be triggered"
    echo "  Last successful version: $last_version"
    return 0
}

# Generate auto-rollback report
generate_auto_rollback_report() {
    local rollback_version="${1:-unknown}"
    local environment="${2:-unknown}"
    
    echo "📋 Generating auto-rollback report..."
    
    local report_file="/tmp/auto-rollback-report.md"
    
    cat > "$report_file" << EOF
# Auto-Rollback Report

## Incident Summary
- **Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Environment**: $environment
- **Rollback Version**: $rollback_version
- **Function**: ${LAMBDA_FUNCTION_NAME:-unknown}
- **Triggered By**: Deployment failure

## Rollback Details
- **Original Deployment**: Failed
- **Rollback Target**: Version $rollback_version
- **Rollback Method**: Automatic
- **Rollback Status**: Completed

## Actions Taken
1. ✅ Detected deployment failure
2. ✅ Validated auto-rollback configuration
3. ✅ Retrieved rollback artifact from S3
4. ✅ Updated Lambda function code
5. ✅ Published new Lambda version
6. ✅ Updated environment alias
7. ✅ Tagged rollback deployment

## Post-Rollback Checklist
- [ ] Verify application functionality
- [ ] Check application logs
- [ ] Monitor error rates
- [ ] Investigate original deployment failure
- [ ] Plan remediation for failed deployment

## Recommendations
1. **Immediate**: Monitor application health
2. **Short-term**: Investigate failure cause
3. **Long-term**: Improve deployment tests

## Contact
- Rolled back by: ${GITHUB_ACTOR:-system}
- Workflow: ${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-unknown}

EOF
    
    if [[ -f "$report_file" ]]; then
        cat "$report_file"
        
        # Save report as GitHub step summary if available
        if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
            cat "$report_file" >> "$GITHUB_STEP_SUMMARY"
        fi
    fi
    
    rm -f "$report_file"
}

# Send auto-rollback notification
send_auto_rollback_notification() {
    local rollback_version="${1:-unknown}"
    local environment="${2:-unknown}"
    
    echo "📢 Sending auto-rollback notification..."
    
    # Override deployment info for notification
    export DEPLOYMENT_MODE="auto-rollback"
    export DETECTED_VERSION="$rollback_version"
    export DEPLOYMENT_ENVIRONMENT="$environment"
    
    # Try to send notification using the notifications script
    local notifications_script
    notifications_script="$(dirname "${BASH_SOURCE[0]}")/notifications.sh"
    
    if [[ -f "$notifications_script" ]]; then
        if source "$notifications_script" && send_all_notifications; then
            echo "✅ Auto-rollback notification sent"
        else
            echo "::warning::Failed to send auto-rollback notification"
        fi
    else
        echo "::warning::Notifications script not found, skipping notification"
    fi
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-perform}" in
        "perform")
            perform_auto_rollback "${2:-}" "${3:-}"
            ;;
        "check")
            should_trigger_auto_rollback
            ;;
        "report")
            generate_auto_rollback_report "${2:-}" "${3:-}"
            ;;
        "notify")
            send_auto_rollback_notification "${2:-}" "${3:-}"
            ;;
        *)
            echo "Usage: $0 [perform|check|report|notify] [args...]"
            echo "  perform <version> <env>  - Perform auto-rollback"
            echo "  check                    - Check if auto-rollback should trigger"
            echo "  report <version> <env>   - Generate auto-rollback report"
            echo "  notify <version> <env>   - Send auto-rollback notification"
            exit 1
            ;;
    esac
fi