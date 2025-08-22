# Contributing to GitHub Actions Collection

Thank you for your interest in contributing to our GitHub Actions Collection! This repository contains multiple actions, each with their own specific contribution guidelines.

## 🎯 How to Contribute

### Action-Specific Contributions
Each action has its own detailed contributing guide:

- **[Lambda Deploy Action](actions/lambda-deploy/CONTRIBUTING.md)** - AWS Lambda deployment contributions
- **[SSH Deploy Action](actions/ssh-deploy/CONTRIBUTING.md)** - SSH deployment contributions *(Coming Soon)*

### Repository-Level Contributions
For repository-wide improvements:
- Documentation structure and organization
- CI/CD workflows for the repository
- Cross-action utilities and shared components
- Repository configuration and settings

## 📋 General Guidelines

### Before Contributing
1. **Choose the right action** - Identify which action your contribution affects
2. **Read action-specific guidelines** - Each action has unique requirements
3. **Check existing issues** - Look for related issues or discussions
4. **Discuss major changes** - Open an issue for significant modifications

### Contribution Types

#### New Actions
If you want to add a new action to the collection:
1. Open an issue to discuss the proposed action
2. Follow the established directory structure
3. Include comprehensive documentation and examples
4. Ensure enterprise-grade quality and security

#### Action Improvements
For improvements to existing actions:
1. Follow the action-specific contributing guide
2. Test thoroughly with real deployments
3. Update action-specific documentation
4. Maintain backward compatibility when possible

#### Documentation
For documentation improvements:
- Repository-level docs: Follow this guide
- Action-specific docs: Follow action contributing guides
- Keep documentation current with code changes
- Include practical examples and use cases

## 🛠️ Repository Structure

```
github-actions-collection/
├── actions/
│   ├── lambda-deploy/
│   │   ├── action.yml
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── CONTRIBUTING.md
│   │   ├── docs/
│   │   └── examples/
│   └── ssh-deploy/
│       └── (similar structure)
├── .github/
│   └── workflows/
├── README.md
├── CONTRIBUTING.md (this file)
└── LICENSE
```

### Directory Standards
Each action must include:
- `action.yml` - Action definition
- `README.md` - Action-specific documentation
- `CHANGELOG.md` - Action version history
- `CONTRIBUTING.md` - Action contribution guidelines
- `docs/` - Comprehensive documentation
- `examples/` - Configuration examples

## 🔄 Versioning Strategy

### Action Versioning
Each action follows independent semantic versioning:
- `lambda-deploy@v1.0.0`, `lambda-deploy@v1.1.0`
- `ssh-deploy@v1.0.0`, `ssh-deploy@v1.1.0`

### Repository Tags
Tags include action prefix:
- `lambda-deploy-v1.0.0`
- `ssh-deploy-v1.0.0`

### Breaking Changes
- Major version bumps for breaking changes
- Clear migration documentation
- Backward compatibility when possible
- Deprecation notices for removed features

## 🧪 Testing Standards

### Action Testing
Each action must have:
- Comprehensive test coverage
- Real-world deployment testing
- Multi-environment validation
- Error handling verification

### Repository Testing
- Cross-action compatibility
- Documentation accuracy
- Example configuration validation
- CI/CD pipeline testing

## 📚 Documentation Standards

### Repository Documentation
- Clear overview of all actions
- Comparison tables and feature matrices
- Usage patterns and examples
- Contribution guidelines

### Action Documentation
- Comprehensive README with quick start
- Detailed configuration reference
- Troubleshooting guides
- Real-world examples

## 🔒 Security Standards

### All Actions Must Include
- Input validation and sanitization
- Secure credential handling
- Audit trail capabilities
- Enterprise security features

### Security Review Process
- Security review for all contributions
- Vulnerability scanning and testing
- Regular security updates
- Responsible disclosure process

## 🏷️ Issue Management

### Labels
- `action:lambda-deploy` - Lambda Deploy specific issues
- `action:ssh-deploy` - SSH Deploy specific issues
- `enhancement` - New features or improvements
- `bug` - Something isn't working
- `documentation` - Documentation improvements
- `security` - Security-related issues

### Issue Templates
Use appropriate templates for:
- Bug reports (action-specific)
- Feature requests (action-specific)
- Documentation improvements
- Security issues

## 📋 Pull Request Process

### PR Requirements
1. **Clear description** - Explain what and why
2. **Action identification** - Specify which action(s) affected
3. **Testing evidence** - Show testing results
4. **Documentation updates** - Keep docs current
5. **Backward compatibility** - Maintain when possible

### Review Process
1. **Automated checks** - All CI/CD must pass
2. **Action maintainer review** - Action-specific review
3. **Security review** - For security-related changes
4. **Documentation review** - Ensure docs are accurate
5. **Final approval** - Repository maintainer approval

## 🤝 Community Guidelines

### Communication
- Be respectful and constructive
- Help others learn and contribute
- Share knowledge and experiences
- Provide helpful feedback

### Collaboration
- Work together on complex features
- Share testing resources
- Review each other's contributions
- Mentor new contributors

## 📞 Getting Help

### Action-Specific Help
- Check action-specific documentation
- Review action contributing guides
- Use action-specific issue labels
- Tag action maintainers when needed

### Repository Help
- GitHub Discussions for general questions
- Repository issues for bugs and features
- Documentation for guidance
- Community support and collaboration

## 🎉 Recognition

Contributors are recognized through:
- GitHub contributor graphs
- Action-specific release notes
- Repository acknowledgments
- Community appreciation

## 📄 License

All contributions are subject to the MIT License - see the [LICENSE](LICENSE) file for details.

---

Thank you for contributing to our GitHub Actions Collection! Your contributions help make deployment automation better for everyone. 🚀
