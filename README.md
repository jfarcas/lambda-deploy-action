# GitHub Actions Collection

A collection of production-ready GitHub Actions for deployment automation and infrastructure management.

## 🚀 Available Actions

### [Lambda Deploy Action](actions/lambda-deploy/)
Enterprise-grade AWS Lambda deployment with multi-environment support, version management, and rollback capabilities.

**Features:**
- ✅ **Multi-environment deployment** (dev/pre/prod) with environment isolation
- ✅ **Smart version management** with conflict prevention and rollback support
- ✅ **Comprehensive health checks** with Lambda function validation
- ✅ **Performance monitoring** and deployment validation
- ✅ **Enterprise security** with proper IAM permissions and audit trails
- ✅ **Robust error handling** with retry logic and detailed logging
- ✅ **S3 integration** with optimized storage paths and metadata
- ✅ **Automated tagging** for deployment tracking and compliance

**Recent Improvements (v1.1.0):**
- 🔧 Fixed S3 key corruption issues with proper stdout/stderr separation
- 🔧 Resolved Lambda invocation failures with correct base64 payload encoding
- 🔧 Enhanced AWS CLI integration with proper output handling
- 🔧 Improved health check reliability and validation
- 🔧 Optimized S3 storage paths for better organization
- 🔧 Added comprehensive retry logic for all AWS operations

**Quick Start:**
```yaml
- name: Deploy Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
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
| **Status** | ✅ Production Ready | 🚧 In Development |

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
│   │   ├── examples/                     # Configuration examples
│   │   ├── scripts/                      # Deployment scripts
│   │   └── tests/                        # Test configurations
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
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
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

### Multi-Environment Workflow
```yaml
# Deploy to multiple environments
- name: Deploy to Dev
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
  with:
    environment: "dev"

- name: Deploy to Production
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
  with:
    environment: "prod"
  if: github.ref == 'refs/heads/main'
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
- `lambda-deploy@v1.1.0`, `lambda-deploy@v1.2.0`, etc.
- `ssh-deploy@v1.0.0`, `ssh-deploy@v1.1.0`, etc.

### Repository Tags
Repository tags include action prefix:
- `lambda-deploy-v1.1.0`
- `ssh-deploy-v1.0.0`

### Usage Examples
```yaml
# Use specific version (recommended for production)
- uses: YourOrg/github-actions-collection/actions/lambda-deploy@lambda-deploy-v1.1.0

# Use latest major version (recommended)
- uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1

# Use latest version (not recommended for production)
- uses: YourOrg/github-actions-collection/actions/lambda-deploy@main
```

## 🔄 Rollback Options

The Lambda Deploy Action provides comprehensive rollback capabilities for safe deployment recovery:

### **Manual Rollback**

#### **Option 1: GitHub Actions Workflow Dispatch**
1. Go to your repository's **Actions** tab
2. Select your deployment workflow
3. Click **Run workflow**
4. Fill in the parameters:
   - **Environment**: `prod`, `pre`, or `dev`
   - **Rollback Version**: `1.0.1` (version to rollback to)
   - **Force Deploy**: Check only for emergencies

#### **Option 2: Direct Action Configuration**
```yaml
- name: Rollback Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
  with:
    config-file: "lambda-deploy-config.yml"
    environment: "prod"
    rollback-to-version: "1.0.1"  # Specify version to rollback to
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
    LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
    AWS_REGION: ${{ vars.AWS_REGION }}
```

#### **Option 3: Emergency Force Deploy**
If rollback encounters issues, use force deploy to bypass safety checks:
```yaml
- name: Emergency Rollback
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
  with:
    rollback-to-version: "1.0.1"
    force-deploy: "true"  # Bypasses version conflicts
    environment: "prod"
```

### **Automatic Rollback**

Enable automatic rollback on deployment failure in `lambda-deploy-config.yml`:

```yaml
rollback:
  enabled: true
  auto_rollback: true      # Automatically rollback on deployment failure
  health_check_retries: 3
  health_check_delay: 10   # Seconds between health checks

deployment:
  auto_rollback:
    enabled: true
    strategy: "last_successful"  # Options: last_successful, specific_version, previous_stable
    triggers:
      on_deployment_failure: true
    behavior:
      max_attempts: 1
```

### **Rollback Requirements & Limitations**

#### **✅ Supported Environments**
- `pre`, `staging`, `test` - Full rollback support
- `prod`, `production` - Full rollback support with pre-deployment validation

#### **❌ Limitations**
- **Dev Environment**: Rollback NOT supported (uses timestamp-based paths)
- **Version Must Exist**: Target rollback version must exist in S3 for the environment
- **Production Safety**: Versions must be deployed to `pre` environment before production

#### **🔍 Finding Available Versions**
The action automatically lists available versions when rollback fails. You can also check S3 directly:
```bash
aws s3 ls s3://your-bucket/your-function/prod/ --recursive | grep "\.zip$"
```

### **Rollback Best Practices**

1. **Test in Pre-Production First**: Always deploy and test in `pre` before production
2. **Monitor After Rollback**: Verify application health post-rollback
3. **Database Compatibility**: Ensure rollback version is compatible with current database state
4. **Environment Variables**: They remain unchanged during rollback
5. **Use Force Deploy Sparingly**: Only for emergency situations

### **Troubleshooting Rollback Issues**

**Issue**: "Version conflict detected even in rollback mode"
- **Solution**: Update to latest action version with rollback conflict fix

**Issue**: "Version not found for rollback"  
- **Solution**: Check available versions and ensure target exists in the environment

**Issue**: "Production deployment blocked: missing pre-deployment"
- **Solution**: Deploy to `pre` environment first, or use `force-deploy: true` for emergencies

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

## 🏆 Production Ready

All actions are designed for production use with:
- ✅ Comprehensive error handling and retry logic
- ✅ Security validation and enterprise-grade features
- ✅ Detailed logging and audit trails
- ✅ Multi-environment support with proper isolation
- ✅ Performance monitoring and health checks
- ✅ Rollback capabilities and disaster recovery

---

**Enterprise Ready:** All actions are battle-tested and ready for production deployment pipelines.
