#!/bin/bash
# test-version-detector.sh - Tests for version detection logic

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

# Test: Input version takes precedence
test_input_version_precedence() {
    start_test "Input version should take precedence over detected version"
    
    # Create a fake package.json that would normally be detected
    echo '{"version": "2.0.0"}' > package.json
    
    # Mock GitHub output - create fresh file
    local output_file="$TEST_TEMP_DIR/github_output_1"
    export GITHUB_OUTPUT="$output_file"
    
    # Call with input version in subshell
    if (
        source "$SCRIPT_DIR/../scripts/version-detector.sh"
        detect_version "1.0.0"
    ) >/dev/null 2>&1; then
        # Check that input version was used
        local version_output
        version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
        
        if assert_equals "1.0.0" "$version_output" "Input version should be used"; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f package.json
}

# Test: pyproject.toml version detection
test_pyproject_toml_detection() {
    start_test "Should detect version from pyproject.toml"
    
    # Create a fake pyproject.toml
    cat > pyproject.toml << 'EOF'
[tool.poetry]
name = "test-project"
version = "1.2.3"
description = "Test project"
EOF
    
    # Mock GitHub output - create fresh file
    local output_file="$TEST_TEMP_DIR/github_output_2"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version in subshell
    if (
        source "$SCRIPT_DIR/../scripts/version-detector.sh"
        detect_version ""
    ) >/dev/null 2>&1; then
        # Check that pyproject.toml version was detected
        local version_output
        version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
        
        if assert_equals "1.2.3" "$version_output" "pyproject.toml version should be detected"; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f pyproject.toml
}

# Test: package.json version detection
test_package_json_detection() {
    start_test "Should detect version from package.json"
    
    # Create a fake package.json
    echo '{"name": "test-package", "version": "2.1.0"}' > package.json
    
    # Mock GitHub output - create fresh file
    local output_file="$TEST_TEMP_DIR/github_output_3"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version in subshell
    if (
        source "$SCRIPT_DIR/../scripts/version-detector.sh"
        detect_version ""
    ) >/dev/null 2>&1; then
        # Check that package.json version was detected
        local version_output
        version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
        
        if assert_equals "2.1.0" "$version_output" "package.json version should be detected"; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f package.json
}

# Test: version.txt detection
test_version_txt_detection() {
    start_test "Should detect version from version.txt"
    
    # Create a version.txt file
    echo "3.0.0" > version.txt
    
    # Mock GitHub output - create fresh file
    local output_file="$TEST_TEMP_DIR/github_output_4"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version in subshell
    if (
        source "$SCRIPT_DIR/../scripts/version-detector.sh"
        detect_version ""
    ) >/dev/null 2>&1; then
        # Check that version.txt version was detected
        local version_output
        version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
        
        if assert_equals "3.0.0" "$version_output" "version.txt version should be detected"; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f version.txt
}

# Test: VERSION file detection
test_version_file_detection() {
    start_test "Should detect version from VERSION file"
    
    # Create a VERSION file
    echo "4.0.0" > VERSION
    
    # Mock GitHub output - create fresh file
    local output_file="$TEST_TEMP_DIR/github_output_5"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version in subshell
    if (
        source "$SCRIPT_DIR/../scripts/version-detector.sh"
        detect_version ""
    ) >/dev/null 2>&1; then
        # Check that VERSION file version was detected
        local version_output
        version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
        
        if assert_equals "4.0.0" "$version_output" "VERSION file version should be detected"; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f VERSION
}

# Test: fallback version
test_fallback_version() {
    start_test "Should use fallback version when no version files exist"
    
    # Ensure no version files exist
    rm -f package.json pyproject.toml version.txt VERSION
    
    # Mock GitHub output - create fresh file
    local output_file="$TEST_TEMP_DIR/github_output_6"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version in subshell
    if (
        source "$SCRIPT_DIR/../scripts/version-detector.sh"
        detect_version ""
    ) >/dev/null 2>&1; then
        # Check that fallback version was used
        local version_output
        version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
        
        # Should use fallback version (likely 1.0.0 or similar)
        if [[ -n "$version_output" ]]; then
            end_test "success"
        else
            end_test "failure"
        fi
    else
        end_test "failure"
    fi
}

# Run all tests
main() {
    setup
    mock_github_actions
    
    test_input_version_precedence
    test_pyproject_toml_detection
    test_package_json_detection
    test_version_txt_detection
    test_version_file_detection
    test_fallback_version
    
    teardown
    print_summary
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
