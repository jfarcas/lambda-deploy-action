# Modular Lambda Deploy Action Structure

This document describes the new modular structure of the Lambda Deploy Action, which breaks down the monolithic `action.yml` into logical, maintainable components.

## 📁 Directory Structure

```
actions/lambda-deploy/
├── action.yml                    # Current modular action structure
├── action-original-backup.yml   # Original monolithic action (backup)
├── scripts/                     # Modular script components
│   ├── validate-env.sh          # Environment variable validation
│   ├── deployment-mode.sh       # Deployment mode determination (deploy/rollback)
│   ├── setup-tools.sh           # Tool installation (yq, etc.)
│   ├── config-loader.sh         # Configuration file loading and validation
│   ├── environment-detector.sh  # Environment detection (dev/pre/prod)
│   ├── version-detector.sh      # Version detection from multiple sources
│   └── retry-utils.sh           # Sophisticated retry mechanisms
├── tests/                       # Unit tests for script components
│   ├── test-framework.sh        # Simple bash testing framework
│   ├── test-validate-env.sh     # Tests for environment validation
│   ├── test-version-detector.sh # Tests for version detection
│   ├── test-retry-utils.sh      # Tests for retry mechanisms
│   └── run-all-tests.sh         # Test runner
└── docs/                        # Existing documentation
```

## 🔧 Script Components

### Core Validation & Setup
- **`validate-env.sh`** - Validates required environment variables with debug support
- **`setup-tools.sh`** - Installs required tools like yq for YAML parsing
- **`deployment-mode.sh`** - Determines if this is a deploy or rollback operation

### Configuration Management
- **`config-loader.sh`** - Loads and validates the lambda-deploy-config.yml file
- **`environment-detector.sh`** - Determines target environment (dev/pre/prod)

### Version Management
- **`version-detector.sh`** - Detects version from multiple sources (pyproject.toml, package.json, git tags, etc.)

### Utility Functions
- **`retry-utils.sh`** - Provides sophisticated retry mechanisms with exponential backoff

## 🧪 Testing Framework

### Test Structure
- **`test-framework.sh`** - Simple bash testing framework with assertions
- Individual test files for each component
- **`run-all-tests.sh`** - Runs complete test suite

### Available Assertions
- `assert_equals` - Check equality
- `assert_not_equals` - Check inequality
- `assert_contains` - Check substring presence
- `assert_file_exists` - Check file existence
- `assert_command_success` - Check command success
- `assert_command_failure` - Check command failure

### Running Tests
```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suite
./tests/test-validate-env.sh

# Run with the test framework
source tests/test-framework.sh
run_test_suite tests/test-validate-env.sh
```

## 🔄 Migration Path

### Phase 1: Modular Implementation (COMPLETED)
- ✅ Break down monolithic action.yml into logical components
- ✅ Create script modules for core functionality
- ✅ Implement sophisticated retry mechanisms
- ✅ Add unit testing framework

### Phase 2: Remaining Scripts (TODO)
- [ ] Complete all remaining script modules
- [ ] Update action-modular.yml to use all components
- [ ] Add integration tests
- [ ] Performance testing

### Phase 3: Migration (COMPLETED)
- ✅ Replace original action.yml with modular version
- ✅ Update documentation
- [ ] Add CI/CD for testing

## 💡 Benefits of Modular Structure

### ✅ Improved Maintainability
- Each script has a single responsibility
- Easier to debug and troubleshoot
- Better code organization

### ✅ Enhanced Testing
- Unit tests for individual components
- Better test coverage
- Easier to mock dependencies

### ✅ Better Reusability
- Scripts can be used independently
- Common utilities can be shared
- Easier to add new features

### ✅ Sophisticated Error Handling
- Exponential backoff retry mechanisms
- Better error reporting
- Graceful failure handling

## 🚀 Usage

### Using the Action
```yaml
- name: Deploy Lambda
  uses: ./actions/lambda-deploy
  with:
    config-file: "lambda-deploy-config.yml"
    environment: "prod"
```

### Testing Scripts Individually
```bash
# Test environment validation
source scripts/validate-env.sh
export S3_BUCKET_NAME="test-bucket"
export LAMBDA_FUNCTION_NAME="test-function"
export AWS_REGION="us-east-1"
validate_environment_variables

# Test version detection
source scripts/version-detector.sh
detect_version "1.0.0"
```

## 📋 TODO: Complete Implementation

The following scripts still need to be created to complete the modular implementation:

1. **`version-history.sh`** - Get last successful version for rollback
2. **`runtime-setup.sh`** - Setup Python/Node.js/Bun environments
3. **`dependency-installer.sh`** - Install project dependencies
4. **`quality-checks.sh`** - Run linting and tests
5. **`package-builder.sh`** - Build Lambda deployment packages
6. **`aws-auth.sh`** - Configure AWS authentication
7. **`aws-validator.sh`** - Validate AWS configuration
8. **`version-conflicts.sh`** - Check for version conflicts
9. **`rollback-retriever.sh`** - Retrieve rollback artifacts
10. **`deployer.sh`** - Main deployment logic
11. **`deployment-validator.sh`** - Post-deployment validation
12. **`notifications.sh`** - Send notifications (Teams, etc.)
13. **`auto-rollback.sh`** - Automatic rollback on failure
14. **`rollback-validator.sh`** - Validate rollback health

## 🎯 Next Steps

1. Complete the remaining script modules
2. Test the modular action end-to-end
3. Add integration tests
4. Update documentation
5. Replace the original action.yml