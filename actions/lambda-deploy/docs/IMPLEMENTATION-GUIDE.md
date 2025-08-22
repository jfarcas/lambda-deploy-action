# Lambda Deploy Action - Implementation Guide v2.0

This comprehensive guide covers the implementation of the Lambda Deploy Action v2.0 with all enterprise features including auto-rollback, smart version detection, and consumer-driven quality gates.

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Configuration Reference](#configuration-reference)
3. [Version Management](#version-management)
4. [Quality Gates (Lint & Test)](#quality-gates-lint--test)
5. [Auto-Rollback Configuration](#auto-rollback-configuration)
6. [Health Checks](#health-checks)
7. [AWS Setup](#aws-setup)
8. [GitHub Setup](#github-setup)
9. [Troubleshooting](#troubleshooting)
10. [Migration Guide](#migration-guide)

## 🚀 Quick Start

### Step 1: Create Configuration File

Create `lambda-deploy-config.yml` in your repository root:

```yaml
# Minimal configuration for hello world Lambda
project:
  name: "my-lambda-function"
  runtime: "python"
  versions:
    python: "3.9"

build:
  commands:
    install: "pip install -r requirements.txt"
    build: "auto"

environments:
  dev:
    trigger_branches: ["main", "feature/**"]
    aws:
      auth_type: "access_key"

deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "Test"
    expected_status_code: 200
    expected_response_contains: "success"
  
  auto_rollback:
    enabled: false  # Safe default
```

### Step 2: Create Workflow File

Create `.github/workflows/lambda-deploy.yml`:

```yaml
name: Deploy Lambda Function

on:
  push:
    branches: [main, feature/**]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy Lambda
        uses: YourOrg/devops-actions/.github/actions/lambda-deploy@lambda-deploy/v2.0.0
        with:
          config-file: "lambda-deploy-config.yml"
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
          LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
          AWS_REGION: ${{ vars.AWS_REGION }}
```

### Step 3: Configure Secrets and Variables

In your repository settings:

**Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Variables:**
- `S3_BUCKET_NAME`
- `LAMBDA_FUNCTION_NAME`
- `AWS_REGION`

## 📋 Configuration Reference

### Project Configuration

```yaml
project:
  name: "my-lambda-function"           # Required: Lambda function name
  description: "My Lambda function"    # Optional: Description
  runtime: "python"                   # Required: python, node, bun
  versions:
    python: "3.9"                     # Runtime version
    # node: "18"                      # For Node.js projects
    # bun: "latest"                   # For Bun projects
```

### Build Configuration

```yaml
build:
  commands:
    install: "pip install -r requirements.txt"  # Required: Install dependencies
    lint: "flake8 . --max-line-length=88"      # Optional: Lint command
    test: "python -m pytest tests/ -v"        # Optional: Test command
    build: "auto"                              # Required: Build command
  
  # Optional: Artifact configuration
  artifact:
    path: "lambda-deployment.zip"
    exclude_patterns:
      - "*.md"
      - "test_*.py"
      - "__pycache__/"
      - "*.pyc"
```

### Environment Configuration

```yaml
environments:
  dev:
    trigger_branches: ["main", "feature/**"]
    aws:
      region: "us-east-1"              # Optional: Override default region
      auth_type: "access_key"          # access_key or oidc
    deployment:
      versioning: false                # Optional: Enable versioning
      notifications: false             # Optional: Enable notifications
  
  prod:
    aws:
      auth_type: "oidc"               # Recommended for production
    deployment:
      versioning: true
      notifications: true
```

## 🔧 Version Management

### Supported Version Sources (Priority Order)

1. **pyproject.toml** (Recommended - Modern Python)
```toml
[project]
name = "my-lambda"
version = "1.0.0"
```

2. **__version__.py** (Traditional Python)
```python
__version__ = "1.0.0"
```

3. **setup.py** (Traditional Python)
```python
setup(name="my-lambda", version="1.0.0")
```

4. **version.txt** (Simple)
```
1.0.0
```

5. **VERSION** (Alternative simple)
```
1.0.0
```

6. **package.json** (Node.js compatibility)
```json
{"version": "1.0.0"}
```

7. **Git tags** (Fallback)
```bash
git tag v1.0.0
```

8. **Commit hash** (Last resort)

### Version Management Best Practices

**For Python Projects:**
```yaml
# Option 1: Modern approach (Recommended)
# Create pyproject.toml with version

# Option 2: Traditional approach
# Create __version__.py with version

# Option 3: Simple approach
# Create version.txt with version
```

**Version Bumping:**
```bash
# Manual
echo "1.0.1" > version.txt

# Automated (with bump2version)
pip install bump2version
bump2version patch  # 1.0.0 -> 1.0.1
```

## 🛡️ Quality Gates (Lint & Test)

### Consumer-Driven Approach

**Simple (No Quality Gates):**
```yaml
build:
  commands:
    install: "pip install -r requirements.txt"
    build: "auto"
    # No lint or test commands = skip both
```

**With Linting Only:**
```yaml
build:
  commands:
    install: "pip install -r requirements.txt flake8"
    lint: "flake8 . --max-line-length=88"
    build: "auto"
    # No test command = skip tests
```

**With Testing Only:**
```yaml
build:
  commands:
    install: "pip install -r requirements.txt pytest"
    test: "python -m pytest tests/"
    build: "auto"
    # No lint command = skip linting
```

**Full Quality Gates:**
```yaml
build:
  commands:
    install: "pip install -r requirements.txt -r dev-requirements.txt"
    lint: "flake8 . --max-line-length=88"
    test: "python -m pytest tests/ -v --cov=."
    build: "auto"
```

### Development Dependencies

**Option 1: Install in build command**
```yaml
install: "pip install -r requirements.txt && pip install flake8 pytest"
```

**Option 2: Use dev-requirements.txt**
```yaml
install: "pip install -r requirements.txt -r dev-requirements.txt"
```

**Option 3: Use pyproject.toml**
```toml
[project.optional-dependencies]
dev = ["flake8>=5.0.0", "pytest>=7.0.0"]
```
```yaml
install: "pip install -e .[dev]"
```

### Quality Gate Behavior

- **Lint failure:** Warning (deployment continues)
- **Test failure:** Error (deployment stops)
- **Missing command:** Step skipped

## 🔄 Auto-Rollback Configuration

### Basic Auto-Rollback

```yaml
deployment:
  auto_rollback:
    enabled: true
    strategy: "last_successful"
    triggers:
      on_deployment_failure: true
```

### Advanced Auto-Rollback

```yaml
deployment:
  auto_rollback:
    enabled: true
    strategy: "last_successful"          # or "specific_version"
    # target_version: "v1.2.3"          # For specific_version strategy
    
    triggers:
      on_deployment_failure: true       # Rollback on Lambda update failure
      on_health_check_failure: false    # Rollback on health check failure
      on_validation_failure: false      # Rollback on validation failure
    
    behavior:
      max_attempts: 1                   # Maximum rollback attempts
      validate_rollback: true           # Run health check after rollback
      fail_on_rollback_failure: true    # Fail if rollback also fails
```

### Auto-Rollback Strategies

**last_successful:** Rollback to the last successfully deployed version
```yaml
strategy: "last_successful"
```

**specific_version:** Rollback to a predefined version
```yaml
strategy: "specific_version"
target_version: "v1.2.3"
```

### Auto-Rollback Use Cases

**Development Environment:**
```yaml
auto_rollback:
  enabled: true    # Fast feedback
  strategy: "last_successful"
```

**Production Environment:**
```yaml
auto_rollback:
  enabled: false   # Manual control
```

**High-Availability Production:**
```yaml
auto_rollback:
  enabled: true    # Automatic recovery
  strategy: "last_successful"
  triggers:
    on_deployment_failure: true
    on_health_check_failure: true
```

## 🏥 Health Checks

### Basic Health Check

```yaml
deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "Test"
    expected_status_code: 200
    expected_response_contains: "success"
```

### Advanced Health Check

```yaml
deployment:
  health_check:
    enabled: true
    
    # Test payload (YAML object format - recommended)
    test_payload_object:
      name: "HealthCheck"
      source: "deployment-validation"
      timestamp: "auto"
      environment: "dev"
    
    # Alternative: JSON string format
    # test_payload: '{"name":"Test","source":"deployment"}'
    
    # Response validation
    expected_status_code: 200
    expected_response_contains: "Hello, HealthCheck!"
    
    # Optional: Expected error message (for testing error scenarios)
    # expected_error_message: "ValidationError"
```

### Health Check Scenarios

**Successful Response:**
```yaml
expected_status_code: 200
expected_response_contains: "success"
```

**Error Testing:**
```yaml
expected_status_code: 400
expected_error_message: "Invalid input"
```

**API Gateway Response:**
```yaml
expected_status_code: 200
expected_response_contains: '"statusCode":200'
```

## ☁️ AWS Setup

### Required AWS Resources

1. **Lambda Function** (pre-created)
2. **S3 Bucket** for artifact storage
3. **IAM Role/User** with required permissions

### IAM Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:PublishVersion",
        "lambda:TagResource",
        "lambda:ListTags",
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:your-function-name"
    }
  ]
}
```

### OIDC Setup (Recommended for Production)

1. **Create OIDC Provider** in AWS IAM
2. **Create Role** with trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YourOrg/your-repo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

## 🔧 GitHub Setup

### Repository Secrets

**For Access Key Authentication:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**For OIDC Authentication:**
- `AWS_ROLE_ARN`

**Optional:**
- `TEAMS_WEBHOOK_URL` (for notifications)

### Repository Variables

- `S3_BUCKET_NAME`
- `LAMBDA_FUNCTION_NAME`
- `AWS_REGION`

### Workflow Permissions

```yaml
permissions:
  id-token: write    # Required for OIDC
  contents: read     # Required for checkout
```

## 🚨 Troubleshooting

### Common Issues

**1. Version Detection Issues**
```
Problem: Version not found or incorrect version detected
Solution: Check version file exists and follows semantic versioning
Priority: pyproject.toml → __version__.py → setup.py → version.txt → VERSION → package.json → git tags → commit hash
```

**2. Lint/Test Command Not Found**
```
Problem: flake8: command not found / No module named pytest
Solution: Install tools in install command or omit lint/test commands
Fix: pip install -r requirements.txt && pip install flake8 pytest
```

**3. Auto-Rollback Not Working**
```
Problem: No previous version found for rollback
Solution: Ensure previous successful deployment exists with version tags
Check: Lambda function tags contain Version information
```

**4. Health Check Failures**
```
Problem: Health check fails after deployment
Solution: Check Lambda function logs and response format
Debug: Verify expected_response_contains matches actual response
```

**5. AWS Permission Errors**
```
Problem: Access denied errors
Solution: Verify IAM policies include all required permissions
Check: Resource ARNs match your actual AWS resources
```

### Debug Mode

Enable detailed logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

### Validation Commands

**Test configuration locally:**
```bash
# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('lambda-deploy-config.yml'))"

# Test version detection
python -c "exec(open('__version__.py').read()); print(__version__)"

# Test lint command
flake8 . --max-line-length=88

# Test test command
python -m pytest tests/ -v
```

## 🔄 Migration Guide

### From v1.x to v2.0

**Breaking Changes:**

1. **Lint/Test Logic Changed**
```yaml
# Before (v1.x) - Auto-detection
build:
  commands:
    test: "auto"
  tests_required: true
  lint_required: false

# After (v2.0) - Consumer-driven
build:
  commands:
    test: "python -m pytest tests/"  # Specify exact command
    # lint: "flake8 ."               # Omit to skip
```

2. **Configuration Structure**
```yaml
# Remove these flags (no longer supported):
# tests_required: true
# lint_required: false
```

3. **Version Detection Priority**
```
# New priority order:
# pyproject.toml → __version__.py → setup.py → version.txt → VERSION → package.json → git tags → commit hash
```

**Migration Steps:**

1. **Update configuration:**
   - Remove `tests_required` and `lint_required` flags
   - Specify exact lint/test commands or omit them
   - Add version file (pyproject.toml recommended)

2. **Update dependencies:**
   - Install lint/test tools if using them
   - Create dev-requirements.txt for development dependencies

3. **Test migration:**
   - Run deployment in dev environment
   - Verify lint/test behavior matches expectations
   - Check version detection works correctly

### Example Migration

**Before:**
```yaml
build:
  commands:
    install: "pip install -r requirements.txt"
    test: "auto"
    build: "auto"
  tests_required: false
  lint_required: false
```

**After:**
```yaml
build:
  commands:
    install: "pip install -r requirements.txt"
    # test: "python -m pytest tests/"  # Uncomment if needed
    # lint: "flake8 ."                 # Uncomment if needed
    build: "auto"
```

## 📊 Best Practices

### Configuration Management

1. **Use semantic versioning** in version files
2. **Specify exact commands** for predictable behavior
3. **Use OIDC authentication** for production environments
4. **Enable auto-rollback** for development, disable for production
5. **Configure health checks** for all environments

### Development Workflow

1. **Start simple** - No lint/test for hello world
2. **Add quality gates** as project matures
3. **Use dev-requirements.txt** for development dependencies
4. **Test in dev environment** before production deployment
5. **Monitor deployment logs** for issues

### Security

1. **Use OIDC** instead of access keys when possible
2. **Limit IAM permissions** to minimum required
3. **Use separate roles** for different environments
4. **Enable versioning** for production deployments
5. **Monitor deployment activities** through CloudTrail

---

For additional support, see the main [README.md](../README.md) or contact your DevOps team.
