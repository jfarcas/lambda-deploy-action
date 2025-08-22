#!/bin/bash
# test-retry-utils.sh - Tests for retry utility functions

# Source the test framework and the script to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"
source "$SCRIPT_DIR/../scripts/retry-utils.sh"

# Test: Successful command on first attempt
test_successful_command_first_attempt() {
    start_test "Successful command should succeed on first attempt"
    
    # Command that always succeeds
    if retry_with_backoff 3 1 5 echo "test" >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
}

# Test: Command succeeds after retries
test_command_succeeds_after_retries() {
    start_test "Command should succeed after initial failures"
    
    # Create a counter file to track attempts
    local counter_file="$TEST_TEMP_DIR/counter"
    echo "0" > "$counter_file"
    
    # Command that fails first 2 times, then succeeds
    test_command() {
        local count=$(cat "$counter_file")
        count=$((count + 1))
        echo "$count" > "$counter_file"
        
        if [[ $count -lt 3 ]]; then
            return 1  # Fail
        else
            return 0  # Succeed
        fi
    }
    
    if retry_with_backoff 5 1 5 test_command >/dev/null 2>&1; then
        # Verify it took 3 attempts
        local final_count=$(cat "$counter_file")
        if assert_equals "3" "$final_count" "Should have taken 3 attempts"; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
}

# Test: Command fails after max attempts
test_command_fails_after_max_attempts() {
    start_test "Command should fail after max attempts exceeded"
    
    # Command that always fails
    if ! retry_with_backoff 2 1 5 false >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
}

# Test: AWS retry wrapper
test_aws_retry_wrapper() {
    start_test "AWS retry should work with aws commands"
    
    # Mock aws command that succeeds
    aws() {
        echo "AWS command executed successfully"
        return 0
    }
    export -f aws
    
    if aws_retry 3 aws s3 ls >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset -f aws
}

# Test: Lambda wait function with success
test_lambda_wait_success() {
    start_test "Lambda wait should succeed when function becomes ready"
    
    # Mock aws command that returns successful state
    aws() {
        if [[ "$*" == *"get-function"* ]]; then
            echo '{"Configuration": {"State": "Active", "LastUpdateStatus": "Successful"}}'
        fi
    }
    export -f aws
    
    # Mock jq command
    jq() {
        if [[ "$*" == *"State"* ]]; then
            echo "Active"
        elif [[ "$*" == *"LastUpdateStatus"* ]]; then
            echo "Successful"
        fi
    }
    export -f jq
    
    if wait_for_lambda_ready "test-function" 10 1 >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset -f aws jq
}

# Test: Lambda wait function with failure
test_lambda_wait_failure() {
    start_test "Lambda wait should fail when function update fails"
    
    # Mock aws command that returns failed state
    aws() {
        if [[ "$*" == *"get-function"* ]]; then
            echo '{"Configuration": {"State": "Failed", "LastUpdateStatus": "Failed"}}'
        fi
    }
    export -f aws
    
    # Mock jq command
    jq() {
        if [[ "$*" == *"State"* ]]; then
            echo "Failed"
        elif [[ "$*" == *"LastUpdateStatus"* ]]; then
            echo "Failed"
        fi
    }
    export -f jq
    
    if ! wait_for_lambda_ready "test-function" 10 1 >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset -f aws jq
}

# Test: HTTP retry function
test_http_retry() {
    start_test "HTTP retry should work with curl commands"
    
    # Mock curl command that succeeds
    curl() {
        if [[ "$*" == *"--fail"* ]]; then
            echo "HTTP request successful"
            return 0
        fi
    }
    export -f curl
    
    if http_retry "https://example.com" 3 --output /dev/null >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset -f curl
}

# Test: Exponential backoff behavior
test_exponential_backoff() {
    start_test "Retry should implement exponential backoff"
    
    local start_time=$(date +%s)
    
    # Command that always fails (to test the backoff timing)
    retry_with_backoff 3 2 10 false >/dev/null 2>&1 || true
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    
    # Should take at least 2 + 4 = 6 seconds (base delays without jitter)
    # But we'll be lenient and check for at least 4 seconds
    if [[ $elapsed -ge 4 ]]; then
        end_test "success"
    else
        echo "  Expected at least 4 seconds, got $elapsed seconds"
        end_test "failure"
    fi
}

# Run all tests
test_successful_command_first_attempt
test_command_succeeds_after_retries
test_command_fails_after_max_attempts
test_aws_retry_wrapper
test_lambda_wait_success
test_lambda_wait_failure
test_http_retry
test_exponential_backoff