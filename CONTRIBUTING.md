# Contributing to Lambda Deploy Action

Thank you for your interest in contributing to Lambda Deploy Action! This guide will help you get started with contributing to this project.

## 🎯 How to Contribute

### Reporting Issues
- Use GitHub Issues to report bugs or request features
- Provide detailed information about your environment and use case
- Include relevant logs and configuration examples
- Search existing issues before creating new ones

### Suggesting Features
- Open a GitHub Issue with the "enhancement" label
- Describe the use case and expected behavior
- Explain how it would benefit other users
- Consider backward compatibility implications

### Code Contributions
- Fork the repository and create a feature branch
- Make your changes with appropriate tests
- Follow the existing code style and conventions
- Submit a pull request with a clear description

## 🛠️ Development Setup

### Prerequisites
- GitHub account with access to GitHub Actions
- AWS account for testing
- Basic knowledge of GitHub Actions and AWS Lambda

### Local Development
1. Fork and clone the repository
2. Create a test repository for validation
3. Set up AWS resources for testing
4. Test changes with real deployments

### Testing
- Test all environment types (dev, pre, prod)
- Verify version management functionality
- Test rollback capabilities
- Validate health checks and error handling

## 📋 Pull Request Process

### Before Submitting
1. **Test thoroughly** - Ensure your changes work across different scenarios
2. **Update documentation** - Update README, docs, and inline comments
3. **Follow conventions** - Match existing code style and patterns
4. **Add examples** - Include configuration examples if applicable

### PR Requirements
- Clear title and description
- Reference related issues
- Include test results or validation steps
- Update CHANGELOG.md if applicable

### Review Process
1. Automated checks must pass
2. Code review by maintainers
3. Testing in real environments
4. Documentation review
5. Merge after approval

## 🎨 Code Style Guidelines

### YAML Configuration
```yaml
# Use consistent indentation (2 spaces)
project:
  name: "example"
  runtime: "python"
  
# Use descriptive names
environments:
  development:  # Not: dev
    trigger_branches: ["main"]
```

### Shell Scripts
```bash
# Use set -e for error handling
set -e

# Use descriptive variable names
LAMBDA_FUNCTION_NAME="my-function"

# Add comments for complex logic
# Check if version exists in S3
if aws s3 ls "s3://$BUCKET/$KEY" > /dev/null 2>&1; then
  echo "Version exists"
fi
```

### Documentation
- Use clear, concise language
- Include practical examples
- Explain the "why" not just the "what"
- Keep documentation up to date with code changes

## 🧪 Testing Guidelines

### Test Scenarios
- **Environment Isolation** - Verify dev/pre/prod separation
- **Version Management** - Test conflict detection and resolution
- **Rollback Functionality** - Validate rollback to previous versions
- **Health Checks** - Test various payload and response scenarios
- **Error Handling** - Verify graceful failure and recovery

### Test Environments
- Use separate AWS accounts or regions for testing
- Test with different Lambda runtimes (Python, Node.js, Bun)
- Validate with various repository structures
- Test both manual and automatic deployments

## 📚 Documentation Standards

### README Updates
- Keep quick start guide current
- Update feature lists when adding functionality
- Maintain accurate configuration examples
- Include troubleshooting for new features

### Code Documentation
- Comment complex logic and algorithms
- Explain environment-specific behavior
- Document security considerations
- Include examples in comments

### Changelog Maintenance
- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Categorize changes (Added, Changed, Fixed, Removed)
- Include migration notes for breaking changes
- Reference related issues and PRs

## 🔒 Security Considerations

### Sensitive Information
- Never commit AWS credentials or secrets
- Use placeholder values in examples
- Sanitize logs and error messages
- Follow least privilege principles

### Input Validation
- Validate all user inputs
- Prevent path traversal attacks
- Sanitize shell command inputs
- Use parameterized queries where applicable

### Error Handling
- Don't expose sensitive information in errors
- Provide helpful but secure error messages
- Log security events appropriately
- Fail securely by default

## 🏷️ Issue Labels

### Type Labels
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements or additions to docs
- `question` - Further information is requested

### Priority Labels
- `critical` - Blocking production use
- `high` - Important but not blocking
- `medium` - Nice to have
- `low` - Minor improvements

### Status Labels
- `needs-triage` - Needs initial review
- `in-progress` - Being worked on
- `needs-testing` - Ready for validation
- `ready-to-merge` - Approved and ready

## 🎯 Feature Development Process

### Planning Phase
1. **Issue Creation** - Describe the feature and use case
2. **Discussion** - Gather feedback from maintainers and users
3. **Design** - Plan implementation approach and architecture
4. **Approval** - Get maintainer approval before starting

### Implementation Phase
1. **Branch Creation** - Create feature branch from main
2. **Development** - Implement feature with tests
3. **Documentation** - Update docs and examples
4. **Testing** - Validate in multiple scenarios

### Review Phase
1. **PR Creation** - Submit pull request with description
2. **Code Review** - Address feedback from maintainers
3. **Testing** - Validate in test environments
4. **Merge** - Merge after approval and testing

## 🤝 Community Guidelines

### Communication
- Be respectful and constructive
- Help others learn and grow
- Share knowledge and experiences
- Provide helpful feedback

### Collaboration
- Work together on complex features
- Share testing resources and environments
- Review each other's contributions
- Mentor new contributors

## 📞 Getting Help

### Documentation
- Check [docs/](docs/) for detailed guides
- Review existing issues and discussions
- Read configuration examples

### Community Support
- GitHub Discussions for questions
- GitHub Issues for bugs and features
- Code review feedback for improvements

### Maintainer Contact
- Tag maintainers in issues for urgent matters
- Use GitHub Discussions for general questions
- Provide detailed context for faster resolution

## 🎉 Recognition

Contributors will be recognized through:
- GitHub contributor graphs
- Mention in release notes
- Credit in documentation
- Community appreciation

Thank you for contributing to Lambda Deploy Action! Your contributions help make AWS Lambda deployments better for everyone. 🚀
