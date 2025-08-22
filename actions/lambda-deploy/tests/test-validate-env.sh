#!/bin/bash
# test-validate-env.sh - Tests for environment variable validation

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

# Test: All required environment variables present
test_all_env_vars_present() {
    start_test "All required environment variables present"
    
    # Set up required environment variables
    export S3_BUCKET_NAME="test-bucket"
    export LAMBDA_FUNCTION_NAME="test-function"
    export AWS_REGION="us-east-1"
    
    # Test the validation function in a subshell to avoid exit issues
    if (
        source "$SCRIPT_DIR/../scripts/validate-env.sh"
        validate_environment_variables
    ) >/dev/null 2>&1; then
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
    unset S3_BUCKET_NAME 2>/dev/null || true
    
    # Should exit with error - test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/validate-env.sh"
        validate_environment_variables
    ) >/dev/null 2>&1; then
        end_test "failure"
    else
        end_test "success"
    fi
    
    # Clean up
    unset LAMBDA_FUNCTION_NAME AWS_REGION 2>/dev/null || true
}

# Test: Missing LAMBDA_FUNCTION_NAME
test_missing_lambda_function_name() {
    start_test "Missing LAMBDA_FUNCTION_NAME should fail"
    
    # Set up some required variables but not all
    export S3_BUCKET_NAME="test-bucket"
    export AWS_REGION="us-east-1"
    unset LAMBDA_FUNCTION_NAME 2>/dev/null || true
    
    # Should exit with error - test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/validate-env.sh"
        validate_environment_variables
    ) >/dev/null 2>&1; then
        end_test "failure"
    else
        end_test "success"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME AWS_REGION 2>/dev/null || true
}

# Test: Missing AWS_REGION
test_missing_aws_region() {
    start_test "Missing AWS_REGION should fail"
    
    # Set up some required variables but not all
    export S3_BUCKET_NAME="test-bucket"
    export LAMBDA_FUNCTION_NAME="test-function"
    unset AWS_REGION 2>/dev/null || true
    
    # Should exit with error - test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/validate-env.sh"
        validate_environment_variables
    ) >/dev/null 2>&1; then
        end_test "failure"
    else
        end_test "success"
    fi
    
    # Clean up
    unset S3_BUCKET_NAME LAMBDA_FUNCTION_NAME 2>/dev/null || true
}

# Run all tests
main() {
    setup
    mock_github_actions
    
    test_all_env_vars_present
    test_missing_s3_bucket
    test_missing_lambda_function_name
    test_missing_aws_region
    
    teardown
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
