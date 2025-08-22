# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-08-22

### 🎉 Initial Release

This is the first stable release of Lambda Deploy Action, providing enterprise-grade AWS Lambda deployment capabilities with comprehensive environment management.

### ✨ Features Added

#### Core Deployment
- **Multi-Environment Support** - Deploy to dev, staging (pre), and production environments
- **Environment Isolation** - Complete S3 and Lambda version isolation between environments
- **Smart Version Management** - Automatic version detection from multiple sources
- **Multi-Runtime Support** - Python, Node.js, and Bun runtime support

#### Version Management
- **Automatic Version Detection** - Supports pyproject.toml, package.json, version.txt, git tags, and more
- **Environment-Specific Policies** - Different version conflict handling per environment:
  - **Dev:** Always allow deployment (rapid iteration)
  - **Pre:** Allow with warnings (staging flexibility)
  - **Prod:** Strict version checking (production safety)
- **Version Conflict Prevention** - Prevents accidental overwrites in production

#### Environment Features
- **S3 Structure Isolation** - Environment-specific S3 paths prevent cross-environment conflicts
- **Lambda Version Descriptions** - Rich, environment-specific version descriptions:
  - `DEV: v1.0.1 | abc123 | 2025-08-22 12:46:06 UTC`
  - `PRE: v1.0.0 | main | def456 | 2025-08-22 11:00:00 UTC`
  - `PROD: v1.0.0 | main | def456 | 2025-08-22 10:00:00 UTC`
- **Environment Aliases** - Automatic alias creation (dev-current, pre-current, prod-current)

#### Rollback Capabilities
- **Manual Rollback** - Deploy specific versions to any environment
- **Environment-Specific Rollback** - Rollback uses correct environment artifacts
- **Auto-Rollback** - Optional automatic rollback on deployment failures
- **Rollback Validation** - Ensures rollback versions exist before attempting

#### Health Checks & Validation
- **Post-Deployment Health Checks** - Configurable validation with custom payloads
- **Lambda State Management** - Waits for Lambda function readiness before version publishing
- **Response Validation** - Verify expected status codes and response content
- **Deployment Validation** - Comprehensive pre and post-deployment checks

#### GitHub Actions Integration
- **Dynamic Workflow Names** - Context-rich workflow names in GitHub UI:
  - `🚀 Manual Deploy | user → prod`
  - `📦 Auto Deploy | main`
  - `🔍 PR Deploy | #123`
- **Comprehensive Logging** - Detailed deployment logs with progress indicators
- **Error Handling** - Graceful error handling with actionable error messages

#### Security & Enterprise Features
- **Input Validation** - Comprehensive validation of all inputs and parameters
- **AWS Authentication** - Support for IAM access keys and OIDC
- **Audit Trail** - Complete deployment history with environment context
- **Lambda Tagging** - Automatic tagging with deployment metadata
- **Least Privilege** - Minimal required IAM permissions

#### Configuration Management
- **YAML Configuration** - Flexible configuration file support
- **Environment-Specific Settings** - Different configurations per environment
- **Build Command Support** - Configurable install, lint, test, and build commands
- **Notification Integration** - Teams webhook support for deployment notifications

### 🏗️ Architecture

#### S3 Structure
```
s3://bucket/function/environments/
├── dev/deployments/timestamp/lambda.zip
├── pre/versions/1.0.0/function-1.0.0.zip
└── prod/versions/1.0.0/function-1.0.0.zip
```

#### Lambda Versions
- Environment-specific version descriptions
- Automatic alias management
- Version conflict prevention
- Rollback support

#### Environment Policies
- **Dev:** Maximum flexibility for rapid development
- **Pre:** Staging flexibility with awareness warnings
- **Prod:** Maximum safety with strict version checking

### 📋 Supported Runtimes

- **Python** - 3.9, 3.10, 3.11
- **Node.js** - 18, 20
- **Bun** - latest, 1.0

### 🔧 Configuration Options

#### Project Configuration
- Runtime selection and version specification
- Function naming and identification
- Build command customization

#### Environment Configuration
- Trigger branch specification
- AWS authentication method selection
- Environment-specific deployment settings

#### Deployment Configuration
- Health check configuration
- Auto-rollback settings
- Notification preferences

### 📊 Monitoring & Observability

- Deployment success/failure tracking
- Environment-specific metrics
- Health check validation
- Comprehensive audit logs

### 🛡️ Security Features

- Input sanitization and validation
- Path traversal prevention
- Command injection protection
- Secure credential handling
- Audit trail maintenance

### 📖 Documentation

- Comprehensive README with quick start guide
- Configuration reference documentation
- Troubleshooting guide
- Security best practices
- Contributing guidelines

### 🎯 Use Cases

This action is designed for:
- **Enterprise teams** requiring robust deployment pipelines
- **Multi-environment workflows** with dev/staging/production
- **Version-controlled deployments** with rollback capabilities
- **Compliance requirements** needing audit trails
- **Teams using GitHub Actions** for CI/CD

### 🚀 Getting Started

See the [README.md](README.md) for complete setup instructions and configuration examples.

---

**Note:** This is the initial stable release. All features have been thoroughly tested and are ready for production use.
