# Lambda Deploy Action Documentation

Welcome to the comprehensive documentation for Lambda Deploy Action - a production-ready GitHub Action for deploying AWS Lambda functions with enterprise-grade features.

## 📚 Documentation Structure

### Getting Started
- [Quick Start Guide](quick-start.md) - Get up and running in 5 minutes
- [Installation](installation.md) - Detailed setup instructions
- [Configuration](configuration.md) - Complete configuration reference

### Core Features
- [Environment Management](environment-management.md) - Multi-environment deployment strategies
- [Version Management](version-management.md) - Automatic version detection and conflict prevention
- [Rollback System](rollback-system.md) - Manual and automatic rollback capabilities
- [Health Checks](health-checks.md) - Post-deployment validation

### Advanced Topics
- [Security](security.md) - Security features and best practices
- [Monitoring](monitoring.md) - Deployment metrics and observability
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Architecture](architecture.md) - System design and S3 structure

### Integration Guides
- [GitHub Actions Integration](github-actions.md) - Workflow setup and dynamic naming
- [AWS Setup](aws-setup.md) - IAM permissions and resource configuration
- [CI/CD Patterns](cicd-patterns.md) - Common deployment patterns and workflows

### Reference
- [Configuration Schema](configuration-schema.md) - Complete YAML configuration reference
- [API Reference](api-reference.md) - Action inputs, outputs, and environment variables
- [Examples](examples/) - Real-world configuration examples

## 🚀 Quick Navigation

### New Users
1. Start with [Quick Start Guide](quick-start.md)
2. Review [Configuration](configuration.md)
3. Set up [AWS Resources](aws-setup.md)
4. Configure [GitHub Actions](github-actions.md)

### Existing Users
- [Configuration Reference](configuration-schema.md) for detailed options
- [Troubleshooting](troubleshooting.md) for common issues
- [Advanced Features](advanced-features.md) for power user capabilities

### Enterprise Users
- [Security Guide](security.md) for compliance requirements
- [Monitoring](monitoring.md) for observability setup
- [Architecture](architecture.md) for system understanding

## 🎯 Key Features Overview

### Multi-Environment Support
Deploy to development, staging, and production environments with complete isolation and environment-specific configurations.

### Smart Version Management
Automatic version detection from multiple sources with intelligent conflict prevention and environment-specific policies.

### Enterprise Security
Comprehensive input validation, audit trails, and secure credential handling for enterprise compliance.

### Rollback Capabilities
Manual and automatic rollback with environment-specific artifact management and validation.

### Health Checks
Post-deployment validation with customizable test payloads and response verification.

### GitHub Integration
Dynamic workflow names, comprehensive logging, and seamless GitHub Actions integration.

## 📋 Supported Runtimes

- **Python** (3.9, 3.10, 3.11)
- **Node.js** (18, 20)
- **Bun** (latest, 1.0)

## 🛡️ Enterprise Ready

This action is designed for production use with:
- Comprehensive error handling
- Security validation
- Audit capabilities
- Enterprise-grade features
- Scalable architecture

## 🤝 Contributing

See our [Contributing Guide](../CONTRIBUTING.md) for information on how to contribute to this project.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**Need Help?** Check our [Troubleshooting Guide](troubleshooting.md) or open an issue on GitHub.
