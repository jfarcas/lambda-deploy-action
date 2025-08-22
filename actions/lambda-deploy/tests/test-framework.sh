#!/bin/bash
# test-framework.sh - Simple bash testing framework

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test results
CURRENT_TEST=""
TEST_RESULTS=()

# Start a test
start_test() {
    CURRENT_TEST="$1"
    echo -e "${BLUE}🧪 Running: $CURRENT_TEST${NC}"
    ((TESTS_RUN++))
}

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $message"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $message"
        echo -e "    Expected: '$expected'"
        echo -e "    Actual:   '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$not_expected" != "$actual" ]]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $message"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $message"
        echo -e "    Not expected: '$not_expected'"
        echo -e "    Actual:       '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $message"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $message"
        echo -e "    String: '$haystack'"
        echo -e "    Should contain: '$needle'"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $message"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $message"
        echo -e "    File does not exist: '$file'"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ PASS${NC}: $message"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $message"
        echo -e "    Command failed: '$command'"
        return 1
    fi
}

assert_command_failure() {
    local command="$1"
    local message="${2:-Command should fail}"
    
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ PASS${NC}: $message"
        return 0
    else
        echo -e "  ${RED}❌ FAIL${NC}: $message"
        echo -e "    Command should have failed: '$command'"
        return 1
    fi
}

# End a test
end_test() {
    local test_status="${1:-success}"
    
    if [[ "$test_status" == "success" ]]; then
        echo -e "${GREEN}✅ PASSED${NC}: $CURRENT_TEST"
        ((TESTS_PASSED++))
        TEST_RESULTS+=("PASS: $CURRENT_TEST")
    else
        echo -e "${RED}❌ FAILED${NC}: $CURRENT_TEST"
        ((TESTS_FAILED++))
        TEST_RESULTS+=("FAIL: $CURRENT_TEST")
    fi
    echo ""
}

# Setup and teardown
setup() {
    echo -e "${BLUE}🔧 Setting up test environment...${NC}"
    # Create temporary test directory
    export TEST_TEMP_DIR=$(mktemp -d)
    export ORIGINAL_PWD="$PWD"
    cd "$TEST_TEMP_DIR"
}

teardown() {
    echo -e "${BLUE}🧹 Cleaning up test environment...${NC}"
    cd "$ORIGINAL_PWD"
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Print test summary
print_summary() {
    echo -e "${BLUE}📊 Test Summary${NC}"
    echo "=================="
    echo "Tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        for result in "${TEST_RESULTS[@]}"; do
            if [[ "$result" == FAIL:* ]]; then
                echo "  - ${result#FAIL: }"
            fi
        done
        return 1
    else
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        return 0
    fi
}

# Mock GitHub Actions environment
mock_github_actions() {
    export GITHUB_OUTPUT="${TEST_TEMP_DIR}/github_output"
    export GITHUB_ENV="${TEST_TEMP_DIR}/github_env"
    export GITHUB_REF_NAME="main"
    export GITHUB_EVENT_NAME="push"
    export GITHUB_ACTOR="test-user"
    export GITHUB_REPOSITORY="test/repo"
    export GITHUB_SHA="abc123"
    
    touch "$GITHUB_OUTPUT"
    touch "$GITHUB_ENV"
}

# Utility function to run a test suite
run_test_suite() {
    local test_file="$1"
    
    echo -e "${YELLOW}🚀 Running test suite: $(basename "$test_file")${NC}"
    echo "================================================"
    
    setup
    mock_github_actions
    
    # Source the test file
    if source "$test_file"; then
        teardown
        print_summary
    else
        echo -e "${RED}❌ Test suite failed to load${NC}"
        teardown
        return 1
    fi
}