# Contributing to Lambda Deploy Action

Thank you for your interest in contributing to the Lambda Deploy Action! This guide covers contribution guidelines specific to this action.

## 🎯 Lambda Deploy Specific Guidelines

### Testing Requirements
- Test all environment types (dev, pre, prod)
- Verify version management functionality across different version sources
- Test rollback capabilities with environment isolation
- Validate health checks with various payload configurations
- Test multi-runtime support (Python, Node.js, Bun)

### Configuration Testing
- Test with different `lambda-deploy-config.yml` configurations
- Verify environment-specific settings work correctly
- Test version detection from all supported sources
- Validate S3 structure and environment isolation

### AWS Integration Testing
- Test with different AWS regions
- Verify IAM permissions work correctly
- Test S3 bucket operations and structure
- Validate Lambda function operations (update, publish, alias)

## 🧪 Test Scenarios

### Environment Management
```yaml
# Test dev environment (timestamp-based)
environment: dev
expected: Always allow deployment with timestamp paths

# Test pre environment (version-based with warnings)
environment: pre
version: "1.0.0" (existing)
expected: Allow deployment with warnings

# Test prod environment (strict version checking)
environment: prod
version: "1.0.0" (existing)
expected: Block deployment with error
```

### Version Detection
```bash
# Test version detection priority
1. pyproject.toml
2. package.json
3. version.txt
4. Git tags
5. Commit hash fallback
```

### Rollback Testing
```yaml
# Test environment-specific rollback
environment: prod
rollback-to-version: "1.0.0"
expected: Use prod environment artifact
```

## 🔧 Development Setup

### Local Testing
1. Create test AWS resources (Lambda function, S3 bucket)
2. Set up test repository with lambda-deploy-config.yml
3. Configure AWS credentials for testing
4. Test with real deployments in isolated environment

### Test Configuration
```yaml
# Use test-specific configuration
project:
  name: "test-lambda-function"
  runtime: "python"

environments:
  test:
    aws:
      auth_type: "access_key"

deployment:
  health_check:
    enabled: true
    test_payload_object:
      test: true
```

## 📋 Code Style

### YAML Configuration
```yaml
# Lambda Deploy specific patterns
project:
  name: "kebab-case-names"
  runtime: "lowercase"

environments:
  dev:
    trigger_branches: ["main", "feature/**"]
  
deployment:
  health_check:
    enabled: true
```

### Shell Script Patterns
```bash
# Environment-specific logic
case "$ENV" in
  "dev"|"development")
    echo "Development deployment"
    ;;
  "pre"|"staging"|"test")
    echo "Staging deployment"
    ;;
  "prod"|"production")
    echo "Production deployment"
    ;;
esac
```

## 🛡️ Security Considerations

### Lambda Deploy Specific Security
- Validate S3 bucket names and paths
- Sanitize Lambda function names
- Prevent path traversal in artifact paths
- Validate version strings and environment names

### AWS Security
- Use least privilege IAM policies
- Validate AWS resource ARNs
- Secure credential handling
- Audit trail maintenance

## 📚 Documentation Requirements

### Lambda Deploy Documentation
- Update configuration schema for new options
- Add examples for new features
- Document environment-specific behavior
- Include troubleshooting for Lambda-specific issues

### Code Documentation
```bash
# Document environment-specific behavior
# Dev environment: Uses timestamp-based deployments for rapid iteration
# Pre environment: Allows version overwrites with warnings for staging flexibility
# Prod environment: Strict version checking prevents accidental overwrites
```

## 🔍 Testing Checklist

### Before Submitting PR
- [ ] Test all three environments (dev, pre, prod)
- [ ] Verify version detection works with multiple sources
- [ ] Test rollback functionality
- [ ] Validate health checks with custom payloads
- [ ] Test with different Lambda runtimes
- [ ] Verify S3 structure and environment isolation
- [ ] Test error handling and edge cases
- [ ] Update documentation and examples

### Integration Testing
- [ ] Test with real AWS resources
- [ ] Verify IAM permissions work correctly
- [ ] Test with different AWS regions
- [ ] Validate with various repository structures
- [ ] Test both manual and automatic deployments

## 🎯 Feature Development

### Lambda Deploy Feature Process
1. **Issue Creation** - Describe Lambda-specific use case
2. **AWS Impact Analysis** - Consider AWS resource implications
3. **Environment Testing** - Test across all environments
4. **Configuration Updates** - Update lambda-deploy-config.yml schema
5. **Documentation** - Update Lambda Deploy specific docs

### Common Feature Areas
- **Environment Management** - New environment types or policies
- **Version Management** - New version detection sources
- **Rollback Features** - Enhanced rollback capabilities
- **Health Checks** - New validation options
- **AWS Integration** - New AWS service integrations

## 🚨 Lambda Deploy Specific Issues

### Environment Issues
```bash
# Environment detection problems
Issue: Wrong environment detected
Debug: Check environment mapping logic

# S3 structure issues
Issue: Cross-environment artifact conflicts
Debug: Verify S3 path isolation
```

### Version Management Issues
```bash
# Version detection problems
Issue: Version not detected from source
Debug: Check version detection priority order

# Version conflict issues
Issue: Unexpected version conflict behavior
Debug: Verify environment-specific version policies
```

### AWS Integration Issues
```bash
# Lambda function issues
Issue: Function update failures
Debug: Check IAM permissions and function state

# S3 issues
Issue: Artifact upload failures
Debug: Verify S3 bucket permissions and paths
```

## 📞 Getting Help

### Lambda Deploy Support
- Check [Lambda Deploy Documentation](docs/)
- Review [Configuration Examples](examples/)
- Search existing issues with `lambda-deploy` label
- Use GitHub Discussions for Lambda-specific questions

### AWS-Specific Help
- Review AWS documentation for Lambda and S3
- Check IAM permissions and policies
- Validate AWS resource configurations
- Test with AWS CLI for debugging

## 🎉 Recognition

Contributors to Lambda Deploy Action will be recognized in:
- Lambda Deploy release notes
- Action-specific documentation
- GitHub contributor graphs
- Community appreciation

Thank you for contributing to Lambda Deploy Action! Your contributions help make AWS Lambda deployments better for everyone. 🚀
