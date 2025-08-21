# Contributing to DevOps Actions

This repository contains enterprise-grade GitHub Actions used across multiple repositories. Please follow these guidelines when contributing.

## 🎯 Contribution Guidelines

### Before Making Changes

1. **Understand Impact**: Changes to this repository affect all consuming repositories
2. **Check Dependencies**: Ensure changes don't break existing implementations
3. **Review Documentation**: Update all relevant documentation
4. **Test Thoroughly**: Test changes in development environments first

### Development Process

1. **Create Feature Branch**: `git checkout -b feature/your-feature-name`
2. **Make Changes**: Follow the coding standards below
3. **Update Documentation**: Update README, action docs, and examples
4. **Test Changes**: Validate in test repositories
5. **Update Changelog**: Add entry to CHANGELOG.md
6. **Submit PR**: Create pull request with detailed description

## 📁 Repository Structure

When adding new actions, follow this structure:

```
.github/actions/your-action-name/
├── action.yml          # Action definition
├── README.md           # Action-specific documentation
└── scripts/            # Optional: Action scripts
```

## 🔄 Versioning Strategy

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (`X.0.0`): Breaking changes requiring migration
- **MINOR** (`X.Y.0`): New features, backward compatible
- **PATCH** (`X.Y.Z`): Bug fixes, security patches

### Tagging Format

```bash
# Full semantic version
action-name/v2.1.0

# Major version alias (for convenience)
action-name/v2

# Latest stable (automatically updated)
action-name/latest
```

## 🧪 Testing Requirements

### Before Submitting Changes

1. **Lint Validation**: Ensure YAML files pass linting
2. **Action Testing**: Test action in isolated repository
3. **Integration Testing**: Test with existing workflows
4. **Documentation Validation**: Ensure all links work
5. **Security Review**: Check for secrets or security issues

### Test Checklist

- [ ] Action runs successfully with default parameters
- [ ] Action handles error cases gracefully
- [ ] All input parameters work as expected
- [ ] Output parameters are correctly set
- [ ] Documentation is accurate and complete
- [ ] No hardcoded organization references
- [ ] Secrets and sensitive data are properly handled

## 📝 Coding Standards

### YAML Files

```yaml
# Use consistent indentation (2 spaces)
# Add meaningful descriptions
# Use kebab-case for input/output names
# Include default values where appropriate

inputs:
  config-file:
    description: 'Path to configuration file'
    required: false
    default: 'config.yml'
```

### Documentation

- **Clear descriptions** for all inputs/outputs
- **Usage examples** with real-world scenarios
- **Prerequisites** and requirements
- **Error handling** documentation
- **Migration notes** for breaking changes

### Security

- **Never hardcode secrets** or credentials
- **Validate all inputs** to prevent injection
- **Use least privilege** for permissions
- **Sanitize outputs** to prevent information disclosure
- **Review third-party actions** before using

## 🚀 Release Process

### For Maintainers

1. **Review Changes**: Ensure all changes are tested and documented
2. **Update Version**: Update version numbers in relevant files
3. **Update Changelog**: Add comprehensive changelog entry
4. **Create Tag**: Create semantic version tag
5. **Update Aliases**: Update major version and latest aliases
6. **Communicate**: Notify teams of breaking changes

### Release Commands

```bash
# Update changelog and documentation
git add CHANGELOG.md README.md docs/
git commit -m "docs: prepare v2.1.0 release"

# Create and push tag
git tag -a action-name/v2.1.0 -m "Release v2.1.0: New feature description"
git push origin main --tags

# Update major version alias
git tag -f action-name/v2
git push origin action-name/v2 --force

# Update latest alias
git tag -f action-name/latest  
git push origin action-name/latest --force
```

## 🐛 Bug Reports

When reporting bugs:

1. **Use Issue Templates**: Fill out all required fields
2. **Provide Context**: Include workflow files, configurations
3. **Steps to Reproduce**: Clear, step-by-step instructions
4. **Expected vs Actual**: What should happen vs what happened
5. **Environment Details**: Runner OS, action version, etc.

## 💡 Feature Requests

When requesting features:

1. **Business Justification**: Explain the business need
2. **Use Cases**: Provide specific scenarios
3. **Backward Compatibility**: Consider existing implementations
4. **Implementation Ideas**: Suggest approach if possible

## 🔒 Security Issues

For security-related issues:

1. **Do NOT open public issues**
2. **Contact maintainers privately**
3. **Provide detailed description**
4. **Allow time for investigation**
5. **Follow responsible disclosure**

## 📞 Getting Help

- **Documentation**: Check README and docs/ directory
- **Examples**: Review examples/ directory
- **Issues**: Search existing issues first
- **Discussions**: Use GitHub Discussions for questions
- **Urgent Issues**: Contact DevOps team directly

## 🏆 Recognition

Contributors will be recognized in:
- Release notes
- CHANGELOG.md
- Repository contributors list
- Internal team communications

Thank you for helping improve our DevOps Actions! 🚀

---

*This document is maintained by the DevOps team and updated as processes evolve.*