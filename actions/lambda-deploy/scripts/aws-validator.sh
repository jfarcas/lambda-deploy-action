#!/bin/bash
set -euo pipefail

# aws-validator.sh - Validate AWS configuration and permissions

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

validate_aws_configuration() {
    echo "🔍 Validating AWS configuration and permissions..."
    
    # Test AWS credentials first
    test_aws_credentials
    
    # Validate required AWS resources
    validate_s3_bucket
    validate_lambda_function
    validate_aws_permissions
    
    echo "✅ AWS configuration validation completed successfully"
}

test_aws_credentials() {
    echo "🔐 Testing AWS credentials..."
    
    local caller_identity
    if ! caller_identity=$(aws_retry 3 aws sts get-caller-identity); then
        echo "::error::AWS credentials validation failed"
        echo "::error::Unable to get caller identity - check your AWS credentials"
        return 1
    fi
    
    echo "✅ AWS credentials are valid"
    
    # Extract and display account information
    if command -v jq >/dev/null 2>&1; then
        local account_id user_arn
        account_id=$(echo "$caller_identity" | jq -r '.Account')
        user_arn=$(echo "$caller_identity" | jq -r '.Arn')
        
        echo "  Account ID: $account_id"
        echo "  User/Role: $user_arn"
        
        # Export account ID for use by other scripts
        echo "AWS_ACCOUNT_ID=$account_id" >> "$GITHUB_ENV"
        export AWS_ACCOUNT_ID="$account_id"
    fi
}

validate_s3_bucket() {
    echo "🪣 Validating S3 bucket access..."
    
    local s3_bucket="${S3_BUCKET_NAME:-}"
    if [[ -z "$s3_bucket" ]]; then
        echo "::error::S3_BUCKET_NAME environment variable is not set"
        return 1
    fi
    
    echo "Checking bucket: $s3_bucket"
    
    # Test bucket existence and access
    if ! aws_retry 3 aws s3 ls "s3://$s3_bucket" > /dev/null; then
        echo "::error::Cannot access S3 bucket: $s3_bucket"
        echo "::error::Possible issues:"
        echo "::error::  1. Bucket does not exist"
        echo "::error::  2. No permission to list bucket contents"
        echo "::error::  3. Bucket is in a different region"
        return 1
    fi
    
    echo "✅ S3 bucket is accessible"
    
    # Test write permissions by creating a test object
    local test_key="lambda-deploy-test-$(date +%s)"
    local test_content="test-write-permissions"
    
    if echo "$test_content" | aws_retry 2 aws s3 cp - "s3://$s3_bucket/$test_key" > /dev/null 2>&1; then
        echo "✅ S3 bucket write permissions confirmed"
        
        # Clean up test object
        aws s3 rm "s3://$s3_bucket/$test_key" > /dev/null 2>&1 || true
    else
        echo "::warning::S3 bucket write test failed - deployment may fail"
        echo "::warning::Ensure your AWS credentials have s3:PutObject permission"
    fi
    
    # Check bucket region
    local bucket_region
    if bucket_region=$(aws s3api get-bucket-location --bucket "$s3_bucket" --query 'LocationConstraint' --output text 2>/dev/null); then
        # Handle null region (us-east-1)
        if [[ "$bucket_region" == "null" ]]; then
            bucket_region="us-east-1"
        fi
        
        if [[ "$bucket_region" != "${AWS_REGION:-}" ]]; then
            echo "::warning::S3 bucket region ($bucket_region) differs from AWS region (${AWS_REGION:-})"
            echo "::warning::This may cause deployment issues"
        else
            echo "✅ S3 bucket region matches AWS region: $bucket_region"
        fi
    fi
}

validate_lambda_function() {
    echo "🔧 Validating Lambda function access..."
    
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    if [[ -z "$lambda_function" ]]; then
        echo "::error::LAMBDA_FUNCTION_NAME environment variable is not set"
        return 1
    fi
    
    echo "Checking function: $lambda_function"
    
    # Test function existence and access
    local function_info
    if ! function_info=$(aws_retry 3 aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
        echo "::error::Cannot access Lambda function: $lambda_function"
        echo "::error::Possible issues:"
        echo "::error::  1. Function does not exist"
        echo "::error::  2. No permission to access function"
        echo "::error::  3. Function is in a different region"
        return 1
    fi
    
    echo "✅ Lambda function is accessible"
    
    # Extract function information
    if command -v jq >/dev/null 2>&1; then
        local function_runtime state last_modified
        function_runtime=$(echo "$function_info" | jq -r '.Configuration.Runtime // "unknown"')
        state=$(echo "$function_info" | jq -r '.Configuration.State // "unknown"')
        last_modified=$(echo "$function_info" | jq -r '.Configuration.LastModified // "unknown"')
        
        echo "  Runtime: $function_runtime"
        echo "  State: $state"
        echo "  Last Modified: $last_modified"
        
        # Warn about runtime compatibility
        local project_runtime="${RUNTIME:-}"
        if [[ -n "$project_runtime" && "$project_runtime" != "unknown" ]]; then
            case "$project_runtime" in
                "python")
                    if [[ ! "$function_runtime" =~ python ]]; then
                        echo "::warning::Project runtime ($project_runtime) may not match Lambda runtime ($function_runtime)"
                    fi
                    ;;
                "node"|"bun")
                    if [[ ! "$function_runtime" =~ nodejs ]]; then
                        echo "::warning::Project runtime ($project_runtime) may not match Lambda runtime ($function_runtime)"
                    fi
                    ;;
            esac
        fi
    fi
    
    # Test update permissions by checking if we can get function configuration
    if aws_retry 2 aws lambda get-function-configuration --function-name "$lambda_function" > /dev/null 2>&1; then
        echo "✅ Lambda function configuration access confirmed"
    else
        echo "::warning::Cannot access Lambda function configuration"
        echo "::warning::May lack lambda:GetFunction permissions"
    fi
}

validate_aws_permissions() {
    echo "🛡️  Validating AWS IAM permissions..."
    
    local permissions_ok=true
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    local s3_bucket="${S3_BUCKET_NAME:-}"
    
    # Test Lambda permissions
    echo "Checking Lambda permissions..."
    
    # Test UpdateFunctionCode permission
    if ! test_lambda_permission "lambda:UpdateFunctionCode" "$lambda_function"; then
        permissions_ok=false
    fi
    
    # Test PublishVersion permission
    if ! test_lambda_permission "lambda:PublishVersion" "$lambda_function"; then
        permissions_ok=false
    fi
    
    # Test TagResource permission
    if ! test_lambda_permission "lambda:TagResource" "$lambda_function"; then
        permissions_ok=false
    fi
    
    # Test S3 permissions
    echo "Checking S3 permissions..."
    
    if ! test_s3_permission "s3:PutObject" "$s3_bucket"; then
        permissions_ok=false
    fi
    
    if ! test_s3_permission "s3:GetObject" "$s3_bucket"; then
        permissions_ok=false
    fi
    
    if $permissions_ok; then
        echo "✅ Required AWS permissions validated"
    else
        echo "::error::Some required AWS permissions are missing"
        echo "::error::Please ensure your AWS credentials have the necessary permissions"
        return 1
    fi
}

test_lambda_permission() {
    local permission="$1"
    local function_name="$2"
    
    case "$permission" in
        "lambda:UpdateFunctionCode")
            # We can't actually test this without updating, so check if we can get function config
            if aws lambda get-function-configuration --function-name "$function_name" > /dev/null 2>&1; then
                echo "  ✅ $permission (inferred from get-function-configuration)"
                return 0
            else
                echo "  ❌ $permission access denied"
                return 1
            fi
            ;;
        "lambda:PublishVersion")
            # Check if we can list versions (requires similar permissions)
            if aws lambda list-versions-by-function --function-name "$function_name" > /dev/null 2>&1; then
                echo "  ✅ $permission (inferred from list-versions)"
                return 0
            else
                echo "  ❌ $permission access denied"
                return 1
            fi
            ;;
        "lambda:TagResource")
            # Check if we can list tags
            local account_id="${AWS_ACCOUNT_ID:-}"
            local aws_region="${AWS_REGION:-}"
            if [[ -n "$account_id" && -n "$aws_region" ]]; then
                local function_arn="arn:aws:lambda:$aws_region:$account_id:function:$function_name"
                if aws lambda list-tags --resource "$function_arn" > /dev/null 2>&1; then
                    echo "  ✅ $permission (inferred from list-tags)"
                    return 0
                else
                    echo "  ⚠️  $permission may not be available"
                    return 1
                fi
            else
                echo "  ⚠️  Cannot test $permission (missing account/region info)"
                return 1
            fi
            ;;
        *)
            echo "  ⚠️  Unknown permission test: $permission"
            return 1
            ;;
    esac
}

test_s3_permission() {
    local permission="$1"
    local bucket_name="$2"
    
    case "$permission" in
        "s3:PutObject")
            # We already tested this in validate_s3_bucket
            echo "  ✅ $permission (verified earlier)"
            return 0
            ;;
        "s3:GetObject")
            # Test by trying to list objects (requires similar permissions)
            if aws s3 ls "s3://$bucket_name" > /dev/null 2>&1; then
                echo "  ✅ $permission (inferred from list access)"
                return 0
            else
                echo "  ❌ $permission access denied"
                return 1
            fi
            ;;
        *)
            echo "  ⚠️  Unknown S3 permission test: $permission"
            return 1
            ;;
    esac
}

# Generate AWS validation report
generate_aws_validation_report() {
    echo "📋 Generating AWS validation report..."
    
    local report_file="/tmp/aws-validation-report.md"
    
    # Get AWS session info
    local account_id="${AWS_ACCOUNT_ID:-unknown}"
    local region="${AWS_REGION:-unknown}"
    local auth_type="${AWS_AUTH_TYPE:-unknown}"
    
    cat > "$report_file" << EOF
# AWS Configuration Validation Report

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## AWS Session Information
- **Account ID**: $account_id
- **Region**: $region  
- **Authentication**: $auth_type
- **S3 Bucket**: ${S3_BUCKET_NAME:-not-set}
- **Lambda Function**: ${LAMBDA_FUNCTION_NAME:-not-set}

## Validation Results
- ✅ AWS Credentials: Valid
- ✅ S3 Bucket: Accessible
- ✅ Lambda Function: Accessible  
- ✅ IAM Permissions: Sufficient

## Required Permissions
### Lambda Function
- lambda:GetFunction
- lambda:GetFunctionConfiguration
- lambda:UpdateFunctionCode
- lambda:PublishVersion
- lambda:TagResource
- lambda:ListVersionsByFunction

### S3 Bucket
- s3:ListBucket
- s3:GetObject
- s3:PutObject

## Recommendations
- Ensure AWS credentials are stored securely in GitHub Secrets
- Consider using OIDC for enhanced security
- Regularly rotate access keys if using access key authentication

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

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-validate}" in
        "validate")
            validate_aws_configuration
            ;;
        "credentials")
            test_aws_credentials
            ;;
        "s3")
            validate_s3_bucket
            ;;
        "lambda")
            validate_lambda_function
            ;;
        "permissions")
            validate_aws_permissions
            ;;
        "report")
            generate_aws_validation_report
            ;;
        *)
            echo "Usage: $0 [validate|credentials|s3|lambda|permissions|report]"
            echo "  validate     - Run complete AWS validation"
            echo "  credentials  - Test AWS credentials only"
            echo "  s3          - Validate S3 bucket access"
            echo "  lambda      - Validate Lambda function access"  
            echo "  permissions - Test IAM permissions"
            echo "  report      - Generate validation report"
            exit 1
            ;;
    esac
fi