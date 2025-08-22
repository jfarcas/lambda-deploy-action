#!/bin/bash
set -euo pipefail

# validate-env.sh - Environment variable validation
# This script validates required environment variables for Lambda deployment

validate_environment_variables() {
    echo "🔍 Validating required environment variables..."
    
    # Optional debug output
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "🐛 DEBUG: Environment variables received by composite action:"
        echo "S3_BUCKET_NAME: '${S3_BUCKET_NAME:-NOT_SET}'"
        echo "LAMBDA_FUNCTION_NAME: '${LAMBDA_FUNCTION_NAME:-NOT_SET}'"
        echo "AWS_REGION: '${AWS_REGION:-NOT_SET}'"
        echo "AWS_ACCESS_KEY_ID: '${AWS_ACCESS_KEY_ID:+SET}'"
        echo "AWS_SECRET_ACCESS_KEY: '${AWS_SECRET_ACCESS_KEY:+SET}'"
        echo "AWS_ROLE_ARN: '${AWS_ROLE_ARN:+SET}'"
        echo "TEAMS_WEBHOOK_URL: '${TEAMS_WEBHOOK_URL:+SET}'"
    fi
    
    # Check required environment variables
    local missing_vars=()
    
    if [[ -z "${S3_BUCKET_NAME:-}" ]]; then
        missing_vars+=("S3_BUCKET_NAME")
    fi
    if [[ -z "${LAMBDA_FUNCTION_NAME:-}" ]]; then
        missing_vars+=("LAMBDA_FUNCTION_NAME")
    fi
    if [[ -z "${AWS_REGION:-}" ]]; then
        missing_vars+=("AWS_REGION")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "::error::Missing required environment variables: ${missing_vars[*]}"
        echo "::error::Please ensure these are set as repository variables or environment variables"
        echo "::error::And that they are passed to the action via the 'env:' block in your workflow"
        exit 1
    fi
    
    echo "✅ All required environment variables are present"
    echo "S3_BUCKET_NAME: $S3_BUCKET_NAME"
    echo "LAMBDA_FUNCTION_NAME: $LAMBDA_FUNCTION_NAME"
    echo "AWS_REGION: $AWS_REGION"
}

# Run validation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_environment_variables
fi