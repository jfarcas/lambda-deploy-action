# Lambda Deploy Action - Quick Reference

## 🚀 Common Configurations

### Hello World (Minimal)
```yaml
project:
  name: "my-lambda"
  runtime: "python"
  versions:
    python: "3.9"

build:
  commands:
    install: "pip install -r requirements.txt"
    build: "auto"

environments:
  dev:
    trigger_branches: ["main"]
    aws:
      auth_type: "access_key"

deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "Test"
    expected_status_code: 200
  auto_rollback:
    enabled: false
```

### With Quality Gates
```yaml
project:
  name: "my-lambda"
  runtime: "python"
  versions:
    python: "3.9"

build:
  commands:
    install: "pip install -r requirements.txt -r dev-requirements.txt"
    lint: "flake8 . --max-line-length=88"
    test: "python -m pytest tests/ -v"
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
    enabled: false
```

### Production Ready
```yaml
project:
  name: "my-lambda"
  runtime: "python"
  versions:
    python: "3.9"

build:
  commands:
    install: "pip install -r requirements.txt -r dev-requirements.txt"
    lint: "flake8 . --max-line-length=88"
    test: "python -m pytest tests/ -v --cov=."
    build: "auto"

environments:
  dev:
    trigger_branches: ["main", "feature/**"]
    aws:
      auth_type: "access_key"
  
  prod:
    aws:
      auth_type: "oidc"
    deployment:
      versioning: true
      notifications: true

deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "HealthCheck"
      source: "deployment-validation"
    expected_status_code: 200
    expected_response_contains: "success"
  
  auto_rollback:
    enabled: true
    strategy: "last_successful"
    triggers:
      on_deployment_failure: true
    behavior:
      validate_rollback: true
```

## 🔧 Version Management Options

### pyproject.toml (Recommended)
```toml
[project]
name = "my-lambda"
version = "1.0.0"
```

### version.txt (Simple)
```
1.0.0
```

### __version__.py (Traditional)
```python
__version__ = "1.0.0"
```

## 🛡️ Quality Gates Options

### No Quality Gates
```yaml
build:
  commands:
    install: "pip install -r requirements.txt"
    build: "auto"
    # No lint or test = skip both
```

### Lint Only
```yaml
build:
  commands:
    install: "pip install -r requirements.txt flake8"
    lint: "flake8 ."
    build: "auto"
```

### Test Only
```yaml
build:
  commands:
    install: "pip install -r requirements.txt pytest"
    test: "python -m pytest tests/"
    build: "auto"
```

### Both Lint and Test
```yaml
build:
  commands:
    install: "pip install -r requirements.txt flake8 pytest"
    lint: "flake8 . --max-line-length=88"
    test: "python -m pytest tests/ -v"
    build: "auto"
```

## 🔄 Auto-Rollback Options

### Disabled (Safe Default)
```yaml
deployment:
  auto_rollback:
    enabled: false
```

### Basic Auto-Rollback
```yaml
deployment:
  auto_rollback:
    enabled: true
    strategy: "last_successful"
```

### Advanced Auto-Rollback
```yaml
deployment:
  auto_rollback:
    enabled: true
    strategy: "last_successful"
    triggers:
      on_deployment_failure: true
      on_health_check_failure: false
    behavior:
      max_attempts: 1
      validate_rollback: true
      fail_on_rollback_failure: true
```

## 🏥 Health Check Options

### Basic Health Check
```yaml
deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "Test"
    expected_status_code: 200
```

### Advanced Health Check
```yaml
deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "HealthCheck"
      source: "deployment-validation"
      timestamp: "auto"
    expected_status_code: 200
    expected_response_contains: "Hello, HealthCheck!"
```

### Disabled Health Check
```yaml
deployment:
  health_check:
    enabled: false
```

## 🔐 AWS Authentication

### Access Keys (Simple)
```yaml
environments:
  dev:
    aws:
      auth_type: "access_key"
```

### OIDC (Recommended)
```yaml
environments:
  prod:
    aws:
      auth_type: "oidc"
```

## 📋 Required Secrets/Variables

### Secrets
- `AWS_ACCESS_KEY_ID` (for access_key auth)
- `AWS_SECRET_ACCESS_KEY` (for access_key auth)
- `AWS_ROLE_ARN` (for oidc auth)

### Variables
- `S3_BUCKET_NAME`
- `LAMBDA_FUNCTION_NAME`
- `AWS_REGION`

## 🚨 Common Issues & Solutions

### Issue: Command not found
```
Error: flake8: command not found
Solution: Install in build command
Fix: install: "pip install -r requirements.txt flake8"
```

### Issue: No module named pytest
```
Error: No module named pytest
Solution: Install pytest or remove test command
Fix: install: "pip install -r requirements.txt pytest"
```

### Issue: Version not found
```
Warning: Using commit hash as version
Solution: Add version file
Fix: Create version.txt with "1.0.0"
```

### Issue: Auto-rollback not working
```
Error: No previous version found
Solution: Ensure previous successful deployment
Fix: Check Lambda function tags for Version
```

## 📊 Best Practices

1. **Start Simple:** Begin with minimal config, add features as needed
2. **Use Semantic Versioning:** Create version files with proper versioning
3. **Separate Dev Dependencies:** Use dev-requirements.txt or pyproject.toml
4. **Test in Dev First:** Always test configuration changes in dev environment
5. **Use OIDC for Production:** More secure than access keys
6. **Enable Auto-Rollback for Dev:** Disable for production for manual control
7. **Configure Health Checks:** Verify deployments work correctly
8. **Monitor Logs:** Check GitHub Actions logs for issues

## 🔗 Quick Links

- [Full Implementation Guide](IMPLEMENTATION-GUIDE.md)
- [Configuration Examples](../examples/)
- [Troubleshooting](IMPLEMENTATION-GUIDE.md#troubleshooting)
- [Migration Guide](IMPLEMENTATION-GUIDE.md#migration-guide)
