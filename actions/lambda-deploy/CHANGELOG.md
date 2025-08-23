# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [lambda-deploy-v1.1.1] - 2025-08-23

### 🔧 Bug Fixes
- **Fixed version detection failure in production environment**: Corrected S3 path structure mismatch between version conflict checking and actual deployment paths
- **Fixed artifact path configuration**: Moved artifact configuration from `quality_checks.artifact.path` to `build.artifact.path` to match action expectations
- **Fixed Teams notification environment**: Reverted Teams notification trigger from `prod` to `dev` environment for backward compatibility with v1.0.0

### 🏗️ Technical Improvements
- **S3 Structure Consistency**: Aligned all scripts to use the simplified S3 structure (`lambda_function/environment/version.zip`) instead of the complex nested structure
- **Version Conflict Detection**: Enhanced version conflict checking to properly handle new production environments with no previous deployments
- **Rollback Path Consistency**: Fixed rollback artifact retrieval to use correct S3 paths across all scripts

### 📝 Files Updated
- `scripts/version-conflicts.sh`: Fixed S3 path structure and added object-specific checking
- `scripts/version-history.sh`: Updated to use correct S3 structure for version listing
- `scripts/rollback-retriever.sh`: Aligned S3 key generation with deployer structure
- `scripts/auto-rollback.sh`: Fixed rollback artifact path resolution
- `action.yml`: Reverted Teams notification environment trigger
- Consumer config example: Fixed artifact path configuration location

### 🎯 Impact
- **Production deployments**: Now work correctly even when no previous deployments exist
- **Version conflicts**: Properly detected using actual S3 object existence rather than directory structure
- **Rollbacks**: Function correctly with consistent S3 path resolution
- **Teams notifications**: Restored to original v1.0.0 behavior for dev environment

## [lambda-deploy-v1.1.0] - 2025-08-22

### 🔧 Critical Bug Fixes

#### S3 Integration Fixes
- **Fixed S3 key corruption** - Resolved stdout/stderr separation issues in deployment functions
- **Enhanced AWS CLI integration** - Added proper output redirection with `--no-progress --quiet >&2`
- **Optimized S3 storage paths** - Implemented shorter, more efficient S3 key structure
- **Improved metadata handling** - Better S3 object metadata for deployment tracking

#### Lambda Invocation Fixes
- **Fixed Lambda health check failures** - Resolved "Invalid base64" errors in health checks
- **Corrected payload encoding** - Implemented proper base64 encoding for all Lambda invocations
- **Enhanced JSON handling** - Added JSON compacting and validation for payloads
- **Fixed rollback validation** - Corrected Lambda invoke commands in rollback scenarios

#### Output and Logging Improvements
- **Enhanced stdout/stderr separation** - All progress messages now go to stderr, clean output to stdout
- **Improved error handling** - Better error messages and validation throughout the pipeline
- **Added comprehensive retry logic** - Enhanced retry mechanisms for all AWS operations
- **Better debugging support** - Improved logging and error reporting

### 🚀 Performance Improvements
- **Faster deployments** - Optimized S3 upload process with better progress handling
- **Reduced API calls** - More efficient AWS CLI usage patterns
- **Better resource utilization** - Improved memory and CPU usage during deployments

### 🛡️ Security Enhancements
- **Enhanced validation** - Added S3 key format validation to prevent corruption
- **Improved error boundaries** - Better error isolation and handling
- **Secure payload handling** - Proper encoding and validation of Lambda payloads

### 📚 Documentation Updates
- **Updated README** - Comprehensive documentation updates reflecting all improvements
- **Enhanced examples** - Better configuration examples and usage patterns
- **Improved troubleshooting** - Added debugging guides and common issue resolution

## [ lambda-deploy-v1.0.0] - 2025-08-22

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
- **Development Environment** - Rapid iteration with timestamp-based versioning
- **Pre-production Environment** - Staging with comprehensive validation
- **Production Environment** - Enterprise-grade deployment with strict controls

#### Health Checks & Validation
- **Comprehensive Health Checks** - Post-deployment Lambda function validation
- **Performance Testing** - Response time and throughput validation
- **Integration Testing** - Custom payload testing capabilities
- **Rollback Validation** - Automated rollback testing and verification

#### S3 Integration
- **Optimized Storage** - Environment-specific S3 organization
- **Metadata Tracking** - Comprehensive deployment metadata
- **Version Archival** - Automatic version history maintenance
- **Latest Pointers** - Environment-specific latest version tracking

#### Security & Compliance
- **IAM Integration** - Proper AWS permissions validation
- **Audit Trails** - Comprehensive deployment logging
- **Environment Isolation** - Secure separation between environments
- **Access Control** - Role-based deployment permissions

#### Rollback Capabilities
- **Automated Rollback** - Quick rollback to previous versions
- **Rollback Validation** - Comprehensive post-rollback testing
- **Version History** - Complete deployment history tracking
- **Emergency Procedures** - Fast rollback for critical issues

#### Monitoring & Observability
- **Deployment Metrics** - Performance and success tracking
- **Health Monitoring** - Continuous function health validation
- **Error Reporting** - Comprehensive error tracking and reporting
- **Performance Analytics** - Deployment time and resource usage tracking

#### Configuration Management
- **YAML Configuration** - Flexible configuration file support
- **Environment Variables** - Secure credential management
- **Custom Payloads** - Configurable health check payloads
- **Validation Rules** - Customizable validation criteria

#### Enterprise Features
- **Multi-Account Support** - Cross-account deployment capabilities
- **Compliance Reporting** - Audit and compliance documentation
- **Disaster Recovery** - Automated backup and recovery procedures
- **High Availability** - Zero-downtime deployment strategies

### 🛠️ Technical Implementation
- **Modular Architecture** - Clean, maintainable script organization
- **Comprehensive Testing** - Extensive validation and testing framework
- **Error Handling** - Robust error handling and recovery mechanisms
- **Performance Optimization** - Efficient resource usage and fast deployments

### 📋 Supported Configurations
- **AWS Regions** - All AWS regions supported
- **Lambda Runtimes** - Python 3.8+, Node.js 14+, Bun 1.0+
- **Package Sizes** - Up to 250MB deployment packages
- **Environment Variables** - Full Lambda environment variable support

### 🔗 Integration Support
- **GitHub Actions** - Native GitHub Actions integration
- **AWS Services** - S3, Lambda, IAM, CloudWatch integration
- **CI/CD Pipelines** - Compatible with all major CI/CD platforms
- **Monitoring Tools** - Integration with monitoring and alerting systems

---

### Migration Guide

#### From Manual Deployments
1. Create configuration file using provided examples
2. Set up required AWS credentials and permissions
3. Configure environment-specific settings
4. Test deployment in development environment first

#### Best Practices
- Always test in development environment first
- Use environment-specific configuration
- Monitor deployment metrics and health checks
- Implement proper rollback procedures
- Follow security best practices for credential management

### Known Issues
- None reported in this release

### Upcoming Features
- Enhanced monitoring dashboard
- Advanced deployment strategies (blue-green, canary)
- Multi-region deployment support
- Enhanced integration testing capabilities
