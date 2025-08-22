# Configuration Reference

Complete reference for `lambda-deploy-config.yml` configuration file.

## 📋 Configuration Schema

### Project Configuration

```yaml
project:
  name: "string"              # Required: Lambda function identifier
  runtime: "string"           # Required: Runtime environment
  versions:                   # Required: Runtime versions
    python: "string"          # Python version (3.9, 3.10, 3.11)
    nodejs: "string"          # Node.js version (18, 20)
    bun: "string"             # Bun version (latest, 1.0)
```

#### Project Options

| Field | Type | Required | Description | Examples |
|-------|------|----------|-------------|----------|
| `name` | string | ✅ | Lambda function identifier | `"my-lambda-function"` |
| `runtime` | string | ✅ | Runtime environment | `"python"`, `"nodejs"`, `"bun"` |
| `versions.python` | string | ⚠️ | Python version (if runtime=python) | `"3.9"`, `"3.10"`, `"3.11"` |
| `versions.nodejs` | string | ⚠️ | Node.js version (if runtime=nodejs) | `"18"`, `"20"` |
| `versions.bun` | string | ⚠️ | Bun version (if runtime=bun) | `"latest"`, `"1.0"` |

### Build Configuration

```yaml
build:
  commands:
    install: "string"         # Required: Install dependencies command
    lint: "string"            # Optional: Lint command
    test: "string"            # Optional: Test command
    build: "string"           # Required: Build command
```

#### Build Commands

| Field | Type | Required | Description | Examples |
|-------|------|----------|-------------|----------|
| `install` | string | ✅ | Install dependencies | `"pip install -r requirements.txt"`, `"npm ci"` |
| `lint` | string | ❌ | Code linting | `"flake8 ."`, `"npm run lint"` |
| `test` | string | ❌ | Run tests | `"pytest tests/"`, `"npm test"` |
| `build` | string | ✅ | Build package | `"auto"`, `"npm run build"` |

#### Special Build Values

- `"auto"` - Automatic build based on runtime
- Custom commands - Execute specific build steps

### Environment Configuration

```yaml
environments:
  environment_name:
    trigger_branches: ["string"]    # Optional: Auto-deploy branches
    aws:
      auth_type: "string"           # Required: AWS authentication
    deployment:                     # Optional: Deployment settings
      versioning: boolean           # Optional: Enable versioning
      notifications: boolean        # Optional: Enable notifications
      auto_rollback:               # Optional: Auto-rollback settings
        enabled: boolean
        strategy: "string"
        triggers:
          on_deployment_failure: boolean
          on_health_check_failure: boolean
```

#### Environment Options

| Field | Type | Required | Description | Examples |
|-------|------|----------|-------------|----------|
| `trigger_branches` | array | ❌ | Auto-deploy branches | `["main", "feature/**"]` |
| `aws.auth_type` | string | ✅ | AWS authentication method | `"access_key"`, `"oidc"` |
| `deployment.versioning` | boolean | ❌ | Enable version tracking | `true`, `false` |
| `deployment.notifications` | boolean | ❌ | Enable notifications | `true`, `false` |

#### Auto-Rollback Configuration

| Field | Type | Required | Description | Examples |
|-------|------|----------|-------------|----------|
| `auto_rollback.enabled` | boolean | ❌ | Enable auto-rollback | `true`, `false` |
| `auto_rollback.strategy` | string | ❌ | Rollback strategy | `"last_successful"` |
| `auto_rollback.triggers.on_deployment_failure` | boolean | ❌ | Rollback on deploy failure | `true`, `false` |
| `auto_rollback.triggers.on_health_check_failure` | boolean | ❌ | Rollback on health failure | `true`, `false` |

### Deployment Configuration

```yaml
deployment:
  health_check:
    enabled: boolean                    # Optional: Enable health checks
    timeout: number                     # Optional: Health check timeout
    test_payload_object: object         # Optional: Test payload
    expected_status_code: number        # Optional: Expected status code
    expected_response_contains: string  # Optional: Expected response content
    retry_attempts: number              # Optional: Retry attempts
    retry_delay: number                 # Optional: Retry delay
  
  notifications:                        # Optional: Notification settings
    teams:
      enabled: boolean                  # Optional: Enable Teams notifications
      on_success: boolean               # Optional: Notify on success
      on_failure: boolean               # Optional: Notify on failure
      on_rollback: boolean              # Optional: Notify on rollback
```

#### Health Check Options

| Field | Type | Required | Description | Default | Examples |
|-------|------|----------|-------------|---------|----------|
| `enabled` | boolean | ❌ | Enable health checks | `false` | `true`, `false` |
| `timeout` | number | ❌ | Timeout in seconds | `30` | `30`, `60` |
| `test_payload_object` | object | ❌ | Test payload | `{}` | `{"name": "test"}` |
| `expected_status_code` | number | ❌ | Expected HTTP status | `200` | `200`, `201` |
| `expected_response_contains` | string | ❌ | Expected response text | `""` | `"success"`, `"ok"` |
| `retry_attempts` | number | ❌ | Number of retries | `3` | `1`, `5` |
| `retry_delay` | number | ❌ | Delay between retries | `5` | `2`, `10` |

#### Notification Options

| Field | Type | Required | Description | Default | Examples |
|-------|------|----------|-------------|---------|----------|
| `teams.enabled` | boolean | ❌ | Enable Teams notifications | `false` | `true`, `false` |
| `teams.on_success` | boolean | ❌ | Notify on success | `true` | `true`, `false` |
| `teams.on_failure` | boolean | ❌ | Notify on failure | `true` | `true`, `false` |
| `teams.on_rollback` | boolean | ❌ | Notify on rollback | `true` | `true`, `false` |

## 📋 Complete Example

```yaml
project:
  name: "my-lambda-function"
  runtime: "python"
  versions:
    python: "3.11"

build:
  commands:
    install: "pip install -r requirements.txt"
    lint: "flake8 . --max-line-length=88"
    test: "python -m pytest tests/ -v"
    build: "auto"

environments:
  dev:
    trigger_branches: ["main", "feature/**", "develop"]
    aws:
      auth_type: "access_key"
    deployment:
      versioning: false
  
  staging:
    trigger_branches: ["main", "release/**"]
    aws:
      auth_type: "access_key"
    deployment:
      versioning: true
      notifications: false
  
  prod:
    aws:
      auth_type: "oidc"
    deployment:
      versioning: true
      notifications: true
      auto_rollback:
        enabled: true
        strategy: "last_successful"
        triggers:
          on_deployment_failure: true
          on_health_check_failure: false

deployment:
  health_check:
    enabled: true
    timeout: 30
    test_payload_object:
      event_type: "health_check"
      source: "deployment_validation"
      timestamp: "auto"
      environment: "auto"
    expected_status_code: 200
    expected_response_contains: "healthy"
    retry_attempts: 3
    retry_delay: 5
  
  notifications:
    teams:
      enabled: true
      on_success: true
      on_failure: true
      on_rollback: true
```

## 🎯 Environment-Specific Behavior

### Development Environment
- **Versioning:** Timestamp-based for rapid iteration
- **Conflict Handling:** Always allow deployment
- **S3 Structure:** `environments/dev/deployments/timestamp/`

### Staging Environment (pre)
- **Versioning:** Version-based with overwrite warnings
- **Conflict Handling:** Allow with warnings for testing flexibility
- **S3 Structure:** `environments/pre/versions/VERSION/`

### Production Environment
- **Versioning:** Strict version checking
- **Conflict Handling:** Block deployment on conflicts
- **S3 Structure:** `environments/prod/versions/VERSION/`

## 🔍 Version Detection Priority

The action detects versions from these sources in order:

1. **pyproject.toml** - `version = "1.0.0"`
2. **package.json** - `"version": "1.0.0"`
3. **version.txt** - `1.0.0`
4. **VERSION** - `1.0.0`
5. **__version__.py** - `__version__ = "1.0.0"`
6. **setup.py** - `version="1.0.0"`
7. **Git tags** - `v1.0.0` or `1.0.0`
8. **Commit hash** - Short commit hash (fallback)

## 🛡️ Security Considerations

### Sensitive Information
- Never include AWS credentials in configuration
- Use GitHub secrets for sensitive values
- Validate all input parameters

### Best Practices
- Use OIDC authentication for production
- Enable notifications for production deployments
- Configure health checks for critical functions
- Use environment-specific configurations

## 🚨 Common Configuration Errors

### Missing Required Fields
```yaml
# ❌ Missing required fields
project:
  name: "my-function"
  # Missing runtime and versions

# ✅ Correct configuration
project:
  name: "my-function"
  runtime: "python"
  versions:
    python: "3.9"
```

### Invalid Runtime Versions
```yaml
# ❌ Invalid Python version
versions:
  python: "3.8"  # Not supported

# ✅ Supported versions
versions:
  python: "3.9"  # or "3.10", "3.11"
```

### Incorrect Environment Names
```yaml
# ❌ Reserved environment names
environments:
  test:  # Conflicts with internal testing
  
# ✅ Recommended names
environments:
  dev:     # Development
  pre:     # Pre-production/Staging
  prod:    # Production
```

## 📚 Related Documentation

- [Quick Start Guide](quick-start.md) - Get started quickly
- [Environment Management](environment-management.md) - Environment strategies
- [Examples](../examples/) - Real-world configurations
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
