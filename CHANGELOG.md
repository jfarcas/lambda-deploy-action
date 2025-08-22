# Changelog

All notable changes to the Lambda Deploy Action will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-08-22

### 🚀 Major Features Added

#### Consumer-Driven Quality Gates
- **BREAKING CHANGE:** Simplified lint and test logic
- Removed auto-detection and complex conditional logic
- Consumer specifies exact commands or omits them entirely
- No more `tests_required` and `lint_required` flags
- Predictable behavior: command provided = run it, command missing = skip it

#### Smart Version Management
- **NEW:** Multi-source version detection with priority order
- Support for `pyproject.toml` (modern Python standard)
- Support for `__version__.py`, `setup.py`, `version.txt`, `VERSION`
- Fallback to `package.json`, git tags, and commit hash
- Semantic versioning validation with warnings

#### Configurable Auto-Rollback
- **NEW:** Optional automatic rollback on deployment failure
- Multiple rollback strategies: `last_successful`, `specific_version`
- Granular trigger control: deployment failure, health check failure
- Consumer choice: enable for fast recovery or disable for manual control
- Safe default: manual rollback only

#### Enhanced Health Checks
- **NEW:** YAML object format for test payloads (cleaner than JSON)
- Comprehensive response validation
- Support for error scenario testing
- Optional execution based on configuration

### 🔧 Improvements

#### Build Process
- Simplified install command handling
- Better error messages and logging
- Improved artifact packaging
- Enhanced security validation

#### Deployment Process
- Fixed S3 upload logic for different environments
- Improved Lambda function tagging
- Better version conflict resolution
- Enhanced retry logic

#### Configuration
- Cleaner YAML structure
- Better validation and error messages
- More flexible environment configuration
- Comprehensive examples and documentation

### 🐛 Bug Fixes

- Fixed bash syntax error in deployment script
- Fixed step execution order (load config before using config)
- Fixed duplicate YAML keys in configuration examples
- Fixed version detection fallback logic
- Fixed S3 key generation for different environments

### 📚 Documentation

- **NEW:** Comprehensive implementation guide
- **NEW:** Version management guide with best practices
- Updated README with all new features
- Added configuration examples for different use cases
- Added troubleshooting guide
- Added migration guide from v1.x

### 🚨 Breaking Changes

1. **Lint/Test Configuration:**
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
       # lint: "flake8 ."               # Omit to skip
   ```

2. **Removed Configuration Options:**
   - `tests_required` flag (no longer supported)
   - `lint_required` flag (no longer supported)
   - Auto-detection logic for lint/test commands

3. **Version Detection Priority Changed:**
   - New priority: pyproject.toml → __version__.py → setup.py → version.txt → VERSION → package.json → git tags → commit hash

### 📋 Migration Guide

1. **Update configuration files:**
   - Remove `tests_required` and `lint_required` flags
   - Specify exact lint/test commands or omit them
   - Add version file (pyproject.toml recommended)

2. **Update dependencies:**
   - Install lint/test tools if using them: `pip install flake8 pytest`
   - Consider using dev-requirements.txt

3. **Test in development environment first**

## [1.0.0] - 2025-08-21

### 🚀 Initial Release

#### Core Features
- Multi-runtime support (Python, Node.js, Bun)
- AWS Lambda deployment with S3 artifact storage
- Environment-based deployment (dev, pre, prod)
- Basic health checks
- AWS authentication (Access Keys and OIDC)

#### Build Process
- Automatic dependency installation
- Basic lint and test support with auto-detection
- Artifact packaging and upload

#### Configuration
- YAML-based configuration
- Environment-specific settings
- Basic validation

#### Security
- Input validation
- Secure artifact handling
- AWS IAM integration

### 📚 Documentation
- Basic README
- Configuration examples
- Setup instructions

## [Unreleased] - Future Plans

### 🔮 Planned Features (v2.1.0)

#### Multi-Region Deployment
- Deploy to multiple AWS regions simultaneously
- Region-specific configuration
- Cross-region rollback support

#### Enhanced Monitoring
- CloudWatch integration
- Custom metrics
- Deployment dashboards

#### Advanced Security
- Vulnerability scanning
- Dependency audit
- Security policy enforcement

#### Workflow Enhancements
- Parallel deployments
- Blue/green deployment strategy
- Canary deployments

### 🔮 Planned Features (v2.2.0)

#### Container Support
- Docker-based Lambda deployments
- Container image building
- ECR integration

#### Advanced Testing
- Integration test support
- Load testing integration
- Performance benchmarking

#### Enterprise Features
- Approval workflows
- Deployment gates
- Compliance reporting

---

## Version Compatibility

| Version | Node.js | Python | Bun | GitHub Actions |
|---------|---------|--------|-----|----------------|
| 2.0.0   | 16+     | 3.8+   | 1.0+ | v4            |
| 1.0.0   | 16+     | 3.8+   | 1.0+ | v3            |

## Support

- **Current Version:** v2.0.0
- **Supported Versions:** v2.0.0, v1.0.0
- **End of Life:** v1.0.0 will be supported until v3.0.0 release

## Upgrade Path

- **v1.x → v2.0:** See migration guide above
- **v2.0 → v2.1:** Will be backward compatible
- **v2.x → v3.0:** Breaking changes expected (TBD)

---

*For detailed implementation instructions, see [IMPLEMENTATION-GUIDE.md](docs/IMPLEMENTATION-GUIDE.md)*
