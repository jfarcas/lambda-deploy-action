#!/bin/bash
# test-version-detector.sh - Tests for version detection logic

# Source the test framework and the script to test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"
source "$SCRIPT_DIR/../scripts/version-detector.sh"

# Test: Input version takes precedence
test_input_version_precedence() {
    start_test "Input version should take precedence over detected version"
    
    # Create a fake package.json that would normally be detected
    echo '{"version": "2.0.0"}' > package.json
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call with input version
    detect_version "1.0.0" >/dev/null
    
    # Check that input version was used
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "1.0.0" "$version_output" "Input version should be used"; then
        end_test "success"
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
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version
    detect_version "" >/dev/null
    
    # Check that pyproject.toml version was detected
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "1.2.3" "$version_output" "pyproject.toml version should be detected"; then
        end_test "success"
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
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Mock node command to return the version
    node() {
        if [[ "$*" == *"require('./package.json').version"* ]]; then
            echo "2.1.0"
        fi
    }
    export -f node
    
    # Call without input version
    detect_version "" >/dev/null
    
    # Check that package.json version was detected
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "2.1.0" "$version_output" "package.json version should be detected"; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f package.json
    unset -f node
}

# Test: version.txt detection
test_version_txt_detection() {
    start_test "Should detect version from version.txt"
    
    # Create a version.txt file
    echo "3.0.0" > version.txt
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version
    detect_version "" >/dev/null
    
    # Check that version.txt version was detected
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "3.0.0" "$version_output" "version.txt version should be detected"; then
        end_test "success"
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
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version
    detect_version "" >/dev/null
    
    # Check that VERSION file version was detected
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "4.0.0" "$version_output" "VERSION file version should be detected"; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    rm -f VERSION
}

# Test: Git tag fallback
test_git_tag_fallback() {
    start_test "Should fall back to git tag when no version files exist"
    
    # Mock git command to return a tag
    git() {
        if [[ "$*" == *"describe --tags"* ]]; then
            echo "v5.0.0"
        elif [[ "$*" == *"rev-parse --short HEAD"* ]]; then
            echo "abc1234"
        fi
    }
    export -f git
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version and no version files
    detect_version "" >/dev/null
    
    # Check that git tag version was detected (without 'v' prefix)
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "5.0.0" "$version_output" "Git tag version should be detected"; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset -f git
}

# Test: Commit hash fallback
test_commit_hash_fallback() {
    start_test "Should fall back to commit hash when no version found"
    
    # Mock git command to return empty for tags but hash for commit
    git() {
        if [[ "$*" == *"describe --tags"* ]]; then
            return 1  # No tags
        elif [[ "$*" == *"rev-parse --short HEAD"* ]]; then
            echo "abc1234"
        fi
    }
    export -f git
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call without input version and no version files
    detect_version "" >/dev/null
    
    # Check that commit hash was used
    local version_output
    version_output=$(grep "version=" "$output_file" | cut -d'=' -f2)
    
    if assert_equals "abc1234" "$version_output" "Commit hash should be used as fallback"; then
        end_test "success"
    else
        end_test "failure"
    fi
    
    # Clean up
    unset -f git
}

# Test: Version format validation warning
test_version_format_validation() {
    start_test "Should warn about non-semantic versioning"
    
    # Mock GitHub output
    local output_file="$TEST_TEMP_DIR/github_output"
    export GITHUB_OUTPUT="$output_file"
    
    # Call with non-semantic version
    local output
    output=$(detect_version "invalid-version" 2>&1)
    
    # Check that warning is issued
    if assert_contains "$output" "doesn't follow semantic versioning" "Should warn about invalid version format"; then
        end_test "success"
    else
        end_test "failure"
    fi
}

# Run all tests
test_input_version_precedence
test_pyproject_toml_detection
test_package_json_detection
test_version_txt_detection
test_version_file_detection
test_git_tag_fallback
test_commit_hash_fallback
test_version_format_validation