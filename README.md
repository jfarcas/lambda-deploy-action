# GitHub Actions Collection

A collection of production-ready GitHub Actions for deployment automation and infrastructure management.

## 🚀 Available Actions

### [Lambda Deploy Action](actions/lambda-deploy/)
Enterprise-grade AWS Lambda deployment with multi-environment support, version management, and rollback capabilities.

**Features:**
- Multi-environment deployment (dev/pre/prod)
- Smart version management with conflict prevention
- Environment isolation and rollback capabilities
- Health checks and validation
- Enterprise security and audit trails

**Quick Start:**
```yaml
- name: Deploy Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    config-file: "lambda-deploy-config.yml"
    environment: "prod"
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
    LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
    AWS_REGION: ${{ vars.AWS_REGION }}
```

### [SSH Deploy Action](actions/ssh-deploy/) *(Coming Soon)*
Secure SSH-based deployment for traditional servers and containerized applications.

**Planned Features:**
- SSH key and password authentication
- Multi-server deployment
- Rollback capabilities
- Health checks and validation
- Docker and traditional deployment support

## 📋 Action Comparison

| Feature | Lambda Deploy | SSH Deploy |
|---------|---------------|------------|
| **Target** | AWS Lambda | SSH Servers |
| **Environments** | dev/pre/prod | Configurable |
| **Rollback** | ✅ | ✅ (Planned) |
| **Health Checks** | ✅ | ✅ (Planned) |
| **Version Management** | ✅ | ✅ (Planned) |
| **Status** | ✅ Available | 🚧 In Development |

## 🛠️ Repository Structure

```
github-actions-collection/
├── actions/
│   ├── lambda-deploy/
│   │   ├── action.yml                    # Action definition
│   │   ├── README.md                     # Action documentation
│   │   ├── CHANGELOG.md                  # Version history
│   │   ├── CONTRIBUTING.md               # Contribution guide
│   │   ├── docs/                         # Comprehensive docs
│   │   └── examples/                     # Configuration examples
│   └── ssh-deploy/                       # Future SSH action
├── README.md                             # This file
├── CONTRIBUTING.md                       # Repository guidelines
└── LICENSE                               # MIT license
```

## 🎯 Usage Pattern

### Direct Action Usage (Recommended)
```yaml
# Use the action directly in your workflow
- name: Deploy Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    config-file: "lambda-deploy-config.yml"
    environment: "prod"
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
    LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
    AWS_REGION: ${{ vars.AWS_REGION }}
```

### Multi-Action Workflow (Future)
```yaml
# Deploy Lambda function
- name: Deploy Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    environment: "prod"

# Deploy to SSH servers
- name: Deploy to Servers
  uses: YourOrg/github-actions-collection/actions/ssh-deploy@v1.0.0
  with:
    servers: "prod-servers"
```

## 🎯 Why Direct Action Usage?

### **Simplicity:**
- ✅ Single action call - no complex workflow nesting
- ✅ Direct control over all parameters
- ✅ Easy to understand and debug

### **Flexibility:**
- ✅ Custom steps before/after deployment
- ✅ Custom error handling and retry logic
- ✅ Full control over workflow structure

### **Reliability:**
- ✅ No cross-repository dependencies
- ✅ No permission inheritance issues
- ✅ Straightforward troubleshooting

### **Maintainability:**
- ✅ Self-contained workflow
- ✅ Easy to customize and extend
- ✅ Clear action parameters and environment variables

## 📚 Documentation

Each action has its own comprehensive documentation:

- **[Lambda Deploy Documentation](actions/lambda-deploy/docs/)**
- **[SSH Deploy Documentation](actions/ssh-deploy/docs/)** *(Coming Soon)*

## 🔄 Versioning Strategy

### Action-Specific Versioning
Each action follows semantic versioning independently:
- `lambda-deploy@v1.0.0`, `lambda-deploy@v1.1.0`, etc.
- `ssh-deploy@v1.0.0`, `ssh-deploy@v1.1.0`, etc.

### Repository Tags
Repository tags include action prefix:
- `lambda-deploy-v1.0.0`
- `ssh-deploy-v1.0.0`

### Usage Examples
```yaml
# Use specific version
- uses: YourOrg/github-actions-collection/actions/lambda-deploy@lambda-deploy-v1.0.0

# Use latest major version (recommended)
- uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1

# Use latest version (not recommended for production)
- uses: YourOrg/github-actions-collection/actions/lambda-deploy@main
```

## 🤝 Contributing

We welcome contributions to any of our actions! Please see:

- [Repository Contributing Guide](CONTRIBUTING.md) - General guidelines
- [Lambda Deploy Contributing](actions/lambda-deploy/CONTRIBUTING.md) - Action-specific guidelines
- [SSH Deploy Contributing](actions/ssh-deploy/CONTRIBUTING.md) - Action-specific guidelines *(Coming Soon)*

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues:** Open action-specific issues with appropriate labels
- **Discussions:** Use GitHub Discussions for questions and ideas
- **Documentation:** Check action-specific documentation first

---

**Enterprise Ready:** All actions are designed for production use with comprehensive error handling, security validation, and enterprise-grade features.
