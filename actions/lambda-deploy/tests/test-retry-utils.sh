#!/bin/bash
# test-retry-utils.sh - Tests for retry utility functions

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

# Test: Successful command on first attempt
test_successful_command_first_attempt() {
    start_test "Successful command should succeed on first attempt"
    
    # Command that always succeeds - test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/retry-utils.sh"
        retry_with_backoff 3 1 5 echo "test"
    ) >/dev/null 2>&1; then
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
    
    # Create a script that fails first 2 times, then succeeds
    local test_script="$TEST_TEMP_DIR/test_command.sh"
    cat > "$test_script" << EOF
#!/bin/bash
count=\$(cat "$counter_file")
count=\$((count + 1))
echo "\$count" > "$counter_file"

if [[ \$count -lt 3 ]]; then
    exit 1  # Fail
else
    exit 0  # Succeed
fi
EOF
    chmod +x "$test_script"
    
    # Test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/retry-utils.sh"
        retry_with_backoff 5 1 5 "$test_script"
    ) >/dev/null 2>&1; then
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

# Test: Retry function produces expected output for failing commands
test_retry_output_for_failing_commands() {
    start_test "Retry function should produce expected output for failing commands"
    
    # Create a script that always fails
    local fail_script="$TEST_TEMP_DIR/fail_command.sh"
    cat > "$fail_script" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$fail_script"
    
    # Test in subshell and capture output
    local result
    result=$(
        cd "$TEST_TEMP_DIR"
        source "$SCRIPT_DIR/../scripts/retry-utils.sh"
        retry_with_backoff 2 1 2 "./fail_command.sh" 2>&1
    )
    
    # Check if the output contains expected retry messages
    if echo "$result" | grep -q "Command failed after 2 attempts"; then
        end_test "success"
    else
        end_test "failure"
    fi
}

# Test: AWS retry function
test_aws_retry_function() {
    start_test "AWS retry function should work"
    
    # Test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/retry-utils.sh"
        aws_retry 2 echo "aws test"
    ) >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
}

# Test: Retry with different backoff settings
test_retry_with_custom_backoff() {
    start_test "Retry should work with custom backoff settings"
    
    # Test in subshell
    if (
        source "$SCRIPT_DIR/../scripts/retry-utils.sh"
        retry_with_backoff 1 1 1 echo "backoff test"
    ) >/dev/null 2>&1; then
        end_test "success"
    else
        end_test "failure"
    fi
}

# Run all tests
main() {
    setup
    mock_github_actions
    
    test_successful_command_first_attempt
    test_command_succeeds_after_retries
    test_retry_output_for_failing_commands
    test_aws_retry_function
    test_retry_with_custom_backoff
    
    teardown
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
