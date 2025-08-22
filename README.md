# DevOps Actions - Enterprise GitHub Actions Repository

This repository contains production-ready, reusable GitHub Actions for enterprise deployment workflows. Designed for organizations managing multiple repositories with standardized CI/CD processes.

## 📁 Repository Structure

```
devops-actions/
├── README.md                                    # This file
├── CHANGELOG.md                                 # Version history and changes
├── .github/
│   ├── actions/
│   │   └── lambda-deploy/
│   │       ├── action.yml                       # Lambda Deploy Action
│   │       └── README.md                        # Action documentation
│   └── workflows/
│       └── lambda-deploy-reusable.yml           # Reusable workflow
├── docs/
│   ├── IMPLEMENTATION-GUIDE.md                  # Detailed setup guide
│   ├── lambda-deploy-guide-v2.html              # Interactive setup guide
│   └── github-actions-versioning-guide-v2.html # Versioning strategy
└── examples/
    ├── lambda-deploy-config-simple.yml         # Simple configuration template
    ├── lambda-deploy-config-advanced.yml       # Advanced configuration template
    ├── repository-workflow.yml                 # Repository workflow template
    ├── action-workflow.yml                     # Direct action usage example
    └── simple-action-workflow.yml              # Minimal action example
```

## 🎯 Purpose

This repository serves as the central hub for reusable GitHub Actions and workflows across your organization. It provides:

- **Standardized deployment processes** across all repositories
- **Enterprise-grade security** and validation
- **Centralized version management** for all actions
- **Comprehensive documentation** and examples
- **Organization-specific customization** capabilities

## 🚀 Available Actions

### Lambda Deploy Action v2.0.0

Production-ready Lambda function deployment with comprehensive validation, security, and enterprise features.

**Location:** `.github/actions/lambda-deploy/`

**Key Features:**
- **Multi-runtime support** (Bun, Node.js, Python) with configurable versions
- **Smart version detection** from multiple sources (pyproject.toml, package.json, version files)
- **Consumer-driven lint/test** - Simple, predictable behavior
- **Configurable auto-rollback** - Optional automatic recovery from deployment failures
- **Enterprise-grade security** with comprehensive input validation
- **Health checks** with customizable validation
- **Version conflict resolution** with force deployment options
- **Quality gates** with consumer-controlled testing requirements
- **Comprehensive monitoring** with detailed logging and metrics

## 🚀 Quick Start

### For Repository Administrators

1. **Clone this repository** as your organization's central DevOps actions repository
2. **Customize organization references** in all files (replace `YourOrg` with your organization name)
3. **Tag and release** your first version:
   ```bash
   git tag lambda-deploy/v2.0.0
   git push origin main --tags
   ```

### For Development Teams

1. **Copy configuration template:**
   ```bash
   cp examples/lambda-deploy-config-simple.yml your-repo/lambda-deploy-config.yml
   ```

2. **Add workflow to your repository:**
   ```bash
   cp examples/repository-workflow.yml your-repo/.github/workflows/lambda-deploy.yml
   ```

3. **Update action reference** in your workflow:
   ```yaml
   action-ref: "YourOrg/devops-actions/.github/actions/lambda-deploy@lambda-deploy/v2.0.0"
   ```

4. **Configure secrets and variables** in your repository settings

### For Detailed Setup

- See [`docs/IMPLEMENTATION-GUIDE.md`](docs/IMPLEMENTATION-GUIDE.md) for complete instructions
- Check [`docs/lambda-deploy-guide-v2.html`](docs/lambda-deploy-guide-v2.html) for interactive guide
- Review [`CHANGELOG.md`](CHANGELOG.md) for version history and migration notes

## 📋 Configuration Examples

### Simple Configuration (Recommended for Hello World)
```yaml
project:
  name: "my-lambda-function"
  runtime: "python"
  versions:
    python: "3.9"

build:
  commands:
    install: "pip install -r requirements.txt"
    # lint: "flake8 ."                    # Optional: Uncomment if needed
    # test: "python -m pytest tests/"    # Optional: Uncomment if needed
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
      source: "deployment-validation"
    expected_status_code: 200
    expected_response_contains: "success"
  
  auto_rollback:
    enabled: false  # Manual rollback only (safe default)
```

### Advanced Configuration (Enterprise Features)
```yaml
project:
  name: "my-lambda-function"
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
    enabled: true                        # Automatic rollback enabled
    strategy: "last_successful"
    triggers:
      on_deployment_failure: true
      on_health_check_failure: false
    behavior:
      max_attempts: 1
      validate_rollback: true
      fail_on_rollback_failure: true
```

## ✨ Key Features

### 🔧 Smart Version Management
- **Multiple sources supported:** pyproject.toml, package.json, version.txt, VERSION, __version__.py, setup.py
- **Semantic versioning validation** with warnings for non-standard formats
- **Automatic fallbacks** from preferred to git tags to commit hash
- **Priority-based detection** for consistent behavior

### 🛡️ Consumer-Driven Quality Gates
- **Simple approach:** Specify exact commands or omit to skip
- **No auto-detection:** Predictable, explicit behavior
- **Lint command:** Optional, warns on failure but continues deployment
- **Test command:** Optional, fails deployment on failure
- **Full consumer control** over what runs and when

### 🔄 Configurable Auto-Rollback
- **Consumer choice:** Enable/disable automatic rollback
- **Multiple strategies:** last_successful, specific_version
- **Granular triggers:** deployment_failure, health_check_failure, validation_failure
- **Safe default:** Manual rollback only
- **Enterprise option:** Automatic recovery for faster incident response

### 🏥 Advanced Health Checks
- **Customizable payloads:** YAML objects or JSON strings
- **Response validation:** Status codes, content matching, error messages
- **Post-deployment verification** with comprehensive logging
- **Optional execution** based on configuration

### 🔐 Enterprise Security
- **Input validation** with comprehensive checks
- **AWS authentication:** OIDC and Access Keys support
- **Secure artifact handling** with path validation
- **Audit trails** with comprehensive tagging and logging

### 📊 Multi-Runtime Support
- **Bun:** Latest or specific versions with bun install/test/build
- **Node.js:** Configurable versions with npm/yarn support
- **Python:** Version management with pip/poetry support
- **Extensible architecture** for additional runtimes

## 📚 Documentation

| Document | Description | When to Use |
|----------|-------------|-------------|
| `docs/IMPLEMENTATION-GUIDE.md` | Complete setup and configuration guide | First-time implementation |
| `CHANGELOG.md` | Version history and release notes | Understanding releases and updates |
| `docs/lambda-deploy-guide-v2.html` | Interactive enterprise setup guide | Visual setup and troubleshooting |
| `docs/github-actions-versioning-guide-v2.html` | Enterprise versioning strategy | Managing versions across organization |
| `examples/lambda-deploy-config-simple.yml` | Simple configuration reference | Quick start for basic projects |
| `examples/lambda-deploy-config-advanced.yml` | Advanced configuration reference | Enterprise features and complex setups |
| `examples/action-workflow.yml` | Direct action usage with full options | Using action directly instead of reusable workflow |

## 🔧 Requirements

### AWS Resources
- **Lambda function** (pre-created)
- **S3 bucket** for artifact storage
- **IAM roles/users** with required permissions

### GitHub Configuration
- **Secrets:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ROLE_ARN`, `TEAMS_WEBHOOK_URL`
- **Variables:** `S3_BUCKET_NAME`, `LAMBDA_FUNCTION_NAME`
- **Permissions:** `id-token: write`, `contents: read`

### Required IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject", "s3:PutObject", "s3:ListBucket",
        "lambda:UpdateFunctionCode", "lambda:GetFunction", 
        "lambda:PublishVersion", "lambda:TagResource", "lambda:ListTags"
      ],
      "Resource": [
        "arn:aws:s3:::bucket/*", 
        "arn:aws:lambda:*:*:function:name"
      ]
    }
  ]
}
```

## 🚨 Migration Guide

### From v1.x to v2.0

**Breaking Changes:**
1. **Lint/Test Logic:** No more auto-detection, specify exact commands or omit
2. **Configuration:** Removed `tests_required` and `lint_required` flags
3. **Version Detection:** New priority order with pyproject.toml support

**Migration Steps:**
```yaml
# Before (v1.x)
build:
  commands:
    test: "auto"
  tests_required: true
  lint_required: false

# After (v2.0)
build:
  commands:
    test: "python -m pytest tests/"  # Specify exact command
    # lint: "flake8 ."               # Omit or specify exact command
```

## 🚨 Troubleshooting

### Common Issues

**Version Detection:**
- Ensure version files exist and contain valid semantic versions
- Check priority order: pyproject.toml → __version__.py → setup.py → version.txt → VERSION → package.json → git tags → commit hash

**Lint/Test Commands:**
- Install required tools: `pip install flake8 pytest` in install command
- Use dev-requirements.txt for development dependencies
- Omit commands entirely to skip lint/test steps

**Auto-Rollback:**
- Requires previous successful deployment with version tags
- Check Lambda function tags for Version information
- Verify S3 bucket contains previous version artifacts

**AWS Permissions:**
- Verify IAM policies include all required Lambda and S3 permissions
- Check resource ARNs match your actual resources
- Ensure OIDC trust relationships are configured correctly

### Debug Mode
Enable detailed logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## 📊 Versioning & Releases

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality in backward compatible manner
- **PATCH** version for backward compatible bug fixes

### Current Status
- **Latest Stable:** v2.0.0 (Consumer-driven quality gates, auto-rollback, smart version detection)
- **Previous:** v1.0.0 (Initial production release)
- **Next Planned:** v2.1.0 (Multi-region deployment support)

### Tag Format
```bash
lambda-deploy/v2.0.0    # Specific version
lambda-deploy/v2        # Major version alias
lambda-deploy/latest    # Latest stable
```

See `CHANGELOG.md` for complete version history and planned features.

---

## 📞 Support & Contributing

- **Implementation questions:** See `IMPLEMENTATION-GUIDE.md`
- **Issues & bugs:** Open issue in central DevOps repository  
- **Feature requests:** Contact DevOps team with business justification
- **Security issues:** Report through private channels

**Enterprise Ready:** This action is designed for production use across multiple Lambda repositories with comprehensive error handling, security validation, audit capabilities, and enterprise-grade features.

---

*For complete setup instructions and advanced configuration, see [IMPLEMENTATION-GUIDE.md](./docs/IMPLEMENTATION-GUIDE.md)*
