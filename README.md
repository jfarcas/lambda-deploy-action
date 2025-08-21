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
    ├── lambda-deploy-config-example.yml        # Configuration template
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

### Lambda Deploy Action v1.0.0

Production-ready Lambda function deployment with comprehensive validation and security.

**Location:** `.github/actions/lambda-deploy/`

**Features:**
- Multi-runtime support (Bun, Node.js, Python)
- Enterprise-grade security with input validation
- Deployment validation and health checks
- Version conflict resolution
- Quality gates and testing requirements

## 🚀 Quick Start

### For Repository Administrators

1. **Clone this repository** as your organization's central DevOps actions repository
2. **Customize organization references** in all files (replace `YourOrg` with your organization name)
3. **Tag and release** your first version:
   ```bash
   git tag lambda-deploy/v1.0.0
   git push origin main --tags
   ```

### For Development Teams

1. **Copy configuration template:**
   ```bash
   cp examples/lambda-deploy-config-example.yml your-repo/lambda-deploy-config.yml
   ```

2. **Add workflow to your repository:**
   ```bash
   cp examples/repository-workflow.yml your-repo/.github/workflows/lambda-deploy.yml
   ```

3. **Update action reference** in your workflow:
   ```yaml
   action-ref: "YourOrg/devops-actions/.github/actions/lambda-deploy@lambda-deploy/v1.0.0"
   ```

4. **Configure secrets and variables** in your repository settings

### For Detailed Setup

- See [`docs/IMPLEMENTATION-GUIDE.md`](docs/IMPLEMENTATION-GUIDE.md) for complete instructions
- Check [`docs/lambda-deploy-guide-v2.html`](docs/lambda-deploy-guide-v2.html) for interactive guide
- Review [`CHANGELOG.md`](CHANGELOG.md) for version history and migration notes

## 📋 Main Files

| File/Directory                                 | Description                  | Usage                                                                                         |
|------------------------------------------------|------------------------------|-----------------------------------------------------------------------------------------------|
| `.github/actions/lambda-deploy/`               | Lambda Deploy Action         | Reference in workflows: `uses: YourOrg/devops-actions/.github/actions/lambda-deploy@v1.0.0`   |
| `.github/workflows/lambda-deploy-reusable.yml` | Reusable workflow            | Reference: `uses: YourOrg/devops-actions/.github/workflows/lambda-deploy-reusable.yml@v1.0.0` |
| `examples/lambda-deploy-config-example.yml`    | Configuration template       | Copy and adapt as `lambda-deploy-config.yml` in target repos                                  |
| `examples/repository-workflow.yml`             | Repository workflow template | Copy as `.github/workflows/lambda-deploy.yml` in target repos                                 |
| `examples/action-workflow.yml`                 | Direct action usage example  | Use the action directly without reusable workflow                                            |
| `examples/simple-action-workflow.yml`          | Minimal action example       | Simplest way to use the action for basic deployments                                         |
| `docs/IMPLEMENTATION-GUIDE.md`                 | Complete setup guide         | Reference for detailed implementation                                                         |

## ✨ Key Features

### Production-Ready Enterprise Action
- **🔧 Advanced YAML parsing** with validation and error handling
- **🛡️ Enterprise security** with input validation and comprehensive checks
- **⚙️ Configurable runtimes** with custom versions and build commands
- **🔍 Deployment validation** with health checks and post-deployment verification
- **📊 Version conflict resolution** with force deployment options
- **🎯 Organization agnostic** design for easy adoption
- **📈 Comprehensive monitoring** with detailed logging and metrics

### Core Capabilities
- **Multi-runtime support:** Bun, Node.js, Python with configurable versions
- **Environment management:** dev, pre, prod with branch-based auto-detection
- **AWS authentication:** OIDC and Access Keys with comprehensive validation
- **Quality gates:** Configurable linting and testing requirements
- **Health checks:** Post-deployment validation with optional test payloads
- **Notifications:** Microsoft Teams integration for production deployments
- **Audit trails:** Comprehensive tagging and logging for compliance

## 🚀 Implementation

### Prerequisites
- AWS Lambda function already created
- S3 bucket for artifact storage  
- GitHub repository with required secrets and variables
- Central DevOps repository for action hosting

### Basic Setup
```bash
# 1. Clone this repository as your organization's DevOps actions repository
git clone <this-repo> YourOrg/devops-actions
cd YourOrg/devops-actions

# 2. Customize organization references
find . -name "*.yml" -o -name "*.md" | xargs sed -i 's/YourOrg/YourActualOrg/g'

# 3. Tag and release
git tag lambda-deploy/v1.0.0
git push origin main --tags

# 4. Configure in Lambda repositories
cp examples/lambda-deploy-config-example.yml your-lambda-repo/lambda-deploy-config.yml
cp examples/repository-workflow.yml your-lambda-repo/.github/workflows/lambda-deploy.yml
```

### Configuration Example
```yaml
project:
  name: "your-lambda-function"
  runtime: "bun"
  versions:
    bun: "latest"

build:
  commands:
    install: "auto"
    test: "auto"
    build: "auto"
  tests_required: true

environments:
  dev:
    trigger_branches: ["main", "feature/MMDSQ**"]
    aws:
      auth_type: "access_key"
  prod:
    aws:
      auth_type: "oidc"
    deployment:
      versioning: true
      notifications: true
```

## 📚 Documentation

| Document | Description | When to Use |
|----------|-------------|-------------|
| `docs/IMPLEMENTATION-GUIDE.md` | Complete setup and configuration guide | First-time implementation |
| `CHANGELOG.md` | Version history and release notes | Understanding releases and updates |
| `docs/lambda-deploy-guide-v2.html` | Interactive enterprise setup guide | Visual setup and troubleshooting |
| `docs/github-actions-versioning-guide-v2.html` | Enterprise versioning strategy | Managing versions across organization |
| `examples/lambda-deploy-config-example.yml` | Full configuration reference | Configuring new projects |
| `examples/action-workflow.yml` | Direct action usage with full options | Using action directly instead of reusable workflow |
| `examples/simple-action-workflow.yml` | Minimal action implementation | Quick start for basic deployments |

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
        "lambda:PublishVersion", "lambda:TagResource"
      ],
      "Resource": ["arn:aws:s3:::bucket/*", "arn:aws:lambda:*:*:function:name"]
    }
  ]
}
```

## 🚨 Troubleshooting

### Common Issues
- **YAML parsing errors:** Validate syntax and required fields using online YAML validators
- **AWS permission issues:** Verify IAM policies match required permissions and resource ARNs are correct
- **Build failures:** Check custom build commands and dependencies, use "auto" for automatic detection
- **Deployment failures:** Review CloudWatch logs and Lambda function state for detailed error messages

### Debug Mode
Enable detailed logging:
```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

See `docs/IMPLEMENTATION-GUIDE.md` for comprehensive troubleshooting guide.

## 📊 Versioning & Releases

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality in backward compatible manner
- **PATCH** version for backward compatible bug fixes

### Current Status
- **Latest Stable:** v1.0.0 (Initial Production Release)
- **Next Planned:** v1.1.0 (Multi-region deployment support)

### Tag Format
```bash
lambda-deploy/v1.0.0    # Specific version
lambda-deploy/v1        # Major version alias
lambda-deploy/latest    # Latest stable
```

See `CHANGELOG.md` for complete version history and planned features.

---

## 📞 Support & Contributing

- **Implementation questions:** See `IMPLEMENTATION-GUIDE.md`
- **Issues & bugs:** Open issue in central DevOps repository  
- **Feature requests:** Contact DevOps team with business justification
- **Security issues:** Report through private channels

**Enterprise Ready:** This action is designed for production use across multiple Lambda repositories with comprehensive error handling, security validation, and audit capabilities.

---

*For complete setup instructions and advanced configuration, see [IMPLEMENTATION-GUIDE.md](./IMPLEMENTATION-GUIDE.md)*
