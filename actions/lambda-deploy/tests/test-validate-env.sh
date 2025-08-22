#!/bin/bash
# test-validate-env.sh - Tests for environment variable validation

# Source the test framework and the script to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"
source "$SCRIPT_DIR/../scripts/validate-env.sh"

# Test: All required environment variables present
test_all_env_vars_present() {
    start_test "All required environment variables present"
    
    # Set up required environment variables
    export S3_BUCKET_NAME="test-bucket"
    export LAMBDA_FUNCTION_NAME="test-function"
    export AWS_REGION="us-east-1"
    
    # Should not exit with error
    if validate_environment_variables >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME LAMBDA_FUNCTION_NAME AWS_REGION
}

# Test: Missing S3_BUCKET_NAME
test_missing_s3_bucket() {
    start_test "Missing S3_BUCKET_NAME should fail"
    
    # Set up some required variables but not all
    export LAMBDA_FUNCTION_NAME="test-function"
    export AWS_REGION="us-east-1"
    unset S3_BUCKET_NAME
    
    # Should exit with error
    if ! validate_environment_variables >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset LAMBDA_FUNCTION_NAME AWS_REGION
}

# Test: Missing LAMBDA_FUNCTION_NAME
test_missing_lambda_function_name() {
    start_test "Missing LAMBDA_FUNCTION_NAME should fail"
    
    # Set up some required variables but not all
    export S3_BUCKET_NAME="test-bucket"
    export AWS_REGION="us-east-1"
    unset LAMBDA_FUNCTION_NAME
    
    # Should exit with error
    if ! validate_environment_variables >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME AWS_REGION
}

# Test: Missing AWS_REGION
test_missing_aws_region() {
    start_test "Missing AWS_REGION should fail"
    
    # Set up some required variables but not all
    export S3_BUCKET_NAME="test-bucket"
    export LAMBDA_FUNCTION_NAME="test-function"
    unset AWS_REGION
    
    # Should exit with error
    if ! validate_environment_variables >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME LAMBDA_FUNCTION_NAME
}

# Test: Debug mode output
test_debug_mode() {
    start_test "Debug mode should show environment variables"
    
    # Set up required environment variables
    export S3_BUCKET_NAME="test-bucket"
    export LAMBDA_FUNCTION_NAME="test-function"
    export AWS_REGION="us-east-1"
    export DEBUG="true"
    
    # Capture output
    local output
    output=$(validate_environment_variables 2>&1)
    
    # Check if debug output is present
    if assert_contains "$output" "DEBUG: Environment variables received"; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME LAMBDA_FUNCTION_NAME AWS_REGION DEBUG
}

# Test: Optional credentials in debug mode
test_debug_credentials_masking() {
    start_test "Debug mode should mask credentials appropriately"
    
    # Set up environment variables including credentials
    export S3_BUCKET_NAME="test-bucket"
    export LAMBDA_FUNCTION_NAME="test-function"
    export AWS_REGION="us-east-1"
    export AWS_ACCESS_KEY_ID="AKIATEST123"
    export AWS_SECRET_ACCESS_KEY="secret123"
    export DEBUG="true"
    
    # Capture output
    local output
    output=$(validate_environment_variables 2>&1)
    
    # Check if credentials are shown as SET (not the actual values)
    if assert_contains "$output" "AWS_ACCESS_KEY_ID: 'SET'" && \
       assert_contains "$output" "AWS_SECRET_ACCESS_KEY: 'SET'"; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME LAMBDA_FUNCTION_NAME AWS_REGION
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY DEBUG
}

# Run all tests
test_all_env_vars_present
test_missing_s3_bucket
test_missing_lambda_function_name
test_missing_aws_region
test_debug_mode
test_debug_credentials_masking