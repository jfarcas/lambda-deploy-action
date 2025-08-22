# Lambda Deploy Action Examples

Real-world configuration examples for different use cases and scenarios.

## 📋 Configuration Examples

### Basic Configurations
- **[minimal.yml](minimal.yml)** - Minimal configuration for simple deployments
- **[python-basic.yml](python-basic.yml)** - Basic Python Lambda setup
- **[nodejs-basic.yml](nodejs-basic.yml)** - Basic Node.js Lambda setup

### Advanced Configurations
- **[python-advanced.yml](python-advanced.yml)** - Full-featured Python configuration
- **[python-enterprise.yml](python-enterprise.yml)** - Enterprise Python setup with all features
- **[complete-example.yml](complete-example.yml)** - Comprehensive example with all options

## 🔧 Workflow Examples

### GitHub Actions Workflows
- **[workflow-basic.yml](workflow-basic.yml)** - Simple workflow with manual and auto deployment
- **[workflow-advanced.yml](workflow-advanced.yml)** - Advanced workflow with rollback and multiple environments

## 🎯 Use Case Examples

### Development Workflow
```yaml
# Quick development setup
project:
  name: "dev-lambda"
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
```

### Production Workflow
```yaml
# Production-ready setup with strict version control
project:
  name: "prod-lambda"
  runtime: "python"
  versions:
    python: "3.11"

build:
  commands:
    install: "pip install -r requirements.txt"
    lint: "flake8 ."
    test: "pytest tests/"
    build: "auto"

environments:
  prod:
    aws:
      auth_type: "oidc"
    deployment:
      versioning: true
      notifications: true

deployment:
  health_check:
    enabled: true
    expected_status_code: 200
    expected_response_contains: "success"
```

### Multi-Environment Setup
```yaml
# Complete multi-environment configuration
environments:
  dev:
    trigger_branches: ["main", "feature/**"]
    aws:
      auth_type: "access_key"
    deployment:
      versioning: false  # Timestamp-based for dev
  
  staging:
    trigger_branches: ["main"]
    aws:
      auth_type: "access_key"
    deployment:
      versioning: true   # Version-based for staging
  
  prod:
    aws:
      auth_type: "oidc"  # OIDC for production security
    deployment:
      versioning: true
      notifications: true
      auto_rollback:
        enabled: true
```

## 🚀 Runtime-Specific Examples

### Python Examples
- **Python 3.9** with pip and pytest
- **Python 3.11** with advanced linting and testing
- **Enterprise Python** with comprehensive validation

### Node.js Examples
- **Node.js 18** with npm and basic testing
- **Node.js 20** with advanced build pipeline
- **TypeScript** configuration with compilation

### Bun Examples
- **Bun latest** with fast package management
- **Bun 1.0** with specific version pinning

## 🔍 Feature Examples

### Health Checks
```yaml
deployment:
  health_check:
    enabled: true
    timeout: 30
    test_payload_object:
      action: "health_check"
      source: "deployment"
    expected_status_code: 200
    expected_response_contains: "healthy"
    retry_attempts: 3
    retry_delay: 5
```

### Auto-Rollback
```yaml
deployment:
  auto_rollback:
    enabled: true
    strategy: "last_successful"
    triggers:
      on_deployment_failure: true
      on_health_check_failure: false
```

### Notifications
```yaml
deployment:
  notifications:
    teams:
      enabled: true
      on_success: true
      on_failure: true
      on_rollback: true
```

## 📚 How to Use Examples

### 1. Choose Base Configuration
Start with a basic example that matches your runtime and use case.

### 2. Customize for Your Needs
Modify the configuration based on your specific requirements:
- Update project name and runtime version
- Configure environments and trigger branches
- Set up health checks and notifications
- Add custom build commands

### 3. Test Configuration
1. Copy configuration to your repository as `lambda-deploy-config.yml`
2. Set up required environment variables
3. Test with dev environment first
4. Gradually roll out to staging and production

### 4. Iterate and Improve
- Monitor deployment logs and metrics
- Adjust health check parameters
- Optimize build commands
- Add additional environments as needed

## 🛡️ Security Examples

### OIDC Authentication
```yaml
environments:
  prod:
    aws:
      auth_type: "oidc"
    deployment:
      versioning: true
      notifications: true
```

### Minimal IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "lambda:UpdateFunctionCode",
        "lambda:PublishVersion"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket/*",
        "arn:aws:lambda:*:*:function:your-function"
      ]
    }
  ]
}
```

## 🚨 Common Patterns

### Version Management
- **Dev:** No versioning (timestamp-based)
- **Staging:** Versioning with overwrite warnings
- **Production:** Strict versioning with conflict prevention

### Branch Triggers
- **Feature branches:** Deploy to dev automatically
- **Main branch:** Deploy to dev and staging
- **Manual deployment:** Production deployments

### Build Commands
- **Install:** Always required for dependency management
- **Lint:** Recommended for code quality
- **Test:** Essential for production deployments
- **Build:** Required for package creation

## 📞 Need Help?

- **Documentation:** Check [docs/](../docs/) for detailed guides
- **Issues:** Open GitHub issue with `lambda-deploy` label
- **Discussions:** Use GitHub Discussions for questions
- **Examples:** Request new examples via GitHub issues

---

**Pro Tip:** Start with a basic example and gradually add features as you become more familiar with the action's capabilities.
