# Lambda Deploy Action - Test Suite

## 🧪 Test Files

- `run-all-tests.sh` - Main test runner (runs all test suites)
- `test-framework.sh` - Test framework with assertions and utilities
- `test-validate-env.sh` - Environment variable validation tests (4 tests)
- `test-version-detector.sh` - Version detection tests (6 tests)
- `test-retry-utils.sh` - Retry utility tests (5 tests)

## 🚀 Running Tests

### Run All Tests
```bash
./run-all-tests.sh
```

### Run Individual Test Suites
```bash
./test-validate-env.sh      # Environment validation
./test-version-detector.sh  # Version detection
./test-retry-utils.sh       # Retry utilities
```
