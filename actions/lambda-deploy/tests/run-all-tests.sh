#!/bin/bash
# run-all-tests.sh - Run all test suites

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test suites to run
TEST_SUITES=(
    "$SCRIPT_DIR/test-validate-env.sh"
    "$SCRIPT_DIR/test-version-detector.sh"
    "$SCRIPT_DIR/test-retry-utils.sh"
)

# Track overall results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

echo -e "${BLUE}🧪 Running Lambda Deploy Action Test Suite${NC}"
echo "=================================================="
echo ""

# Run each test suite
for test_suite in "${TEST_SUITES[@]}"; do
    if [[ -f "$test_suite" ]]; then
        ((TOTAL_SUITES++))
        
        echo -e "${YELLOW}Running $(basename "$test_suite")...${NC}"
        
        # Execute the test suite directly (they have their own main functions)
        if "$test_suite"; then
            echo -e "${GREEN}✅ $(basename "$test_suite") PASSED${NC}"
            ((PASSED_SUITES++))
        else
            echo -e "${RED}❌ $(basename "$test_suite") FAILED${NC}"
            ((FAILED_SUITES++))
        fi
        
        echo ""
    else
        echo -e "${RED}❌ Test suite not found: $test_suite${NC}"
        ((TOTAL_SUITES++))
        ((FAILED_SUITES++))
    fi
done

# Print overall summary
echo "=================================================="
echo -e "${BLUE}📊 Overall Test Results${NC}"
echo "Total test suites: $TOTAL_SUITES"
echo -e "Passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Failed: ${RED}$FAILED_SUITES${NC}"

if [[ $FAILED_SUITES -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All test suites passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 Some test suites failed!${NC}"
    exit 1
fi
