# Lambda Deploy Action - Implementation Guide

This guide provides detailed instructions for implementing the enhanced Generic Lambda Deploy Action across your organization.

## 🚀 Quick Start

### 1. Setup in Central DevOps Repository

1. **The repository structure is already organized:**
   ```
   YourOrg/devops-actions/
   ├── .github/
   │   ├── actions/
   │   │   └── lambda-deploy/
   │   │       ├── action.yml                 # Main action
   │   │       └── README.md                  # Action docs
   │   └── workflows/
   │       └── lambda-deploy-reusable.yml     # Reusable workflow
   ├── docs/                                  # Documentation
   ├── examples/                              # Templates and examples
   └── README.md
   ```

2. **Clone and customize this repository:**
   ```bash
   # Clone this repository as your organization's DevOps actions repo
   git clone <this-repo> YourOrg/devops-actions
   cd YourOrg/devops-actions
   
   # Customize organization references
   find . -type f -name "*.yml" -o -name "*.yaml" -o -name "*.md" -o -name "*.html" | \
     xargs sed -i 's/YourOrg/ActualOrgName/g'
   ```

3. **Tag and release:**
   ```bash
   cd YourOrg/devops-actions
   git add .
   git commit -m "feat: add enhanced lambda deploy action v1.0.0"
   git tag lambda-deploy/v1.0.0
   git push origin main --tags
   ```

### 2. Setup in Lambda Repositories

1. **Create configuration file:**
   ```bash
   cp lambda-deploy-config-example.yml your-lambda-repo/lambda-deploy-config.yml
   ```

2. **Update configuration for your project:**
   - Set project name and runtime
   - Configure build commands if needed
   - Set environment-specific variables

3. **Add workflow:**
   ```bash
   cp ejemplo-workflow-repositorio.yml your-lambda-repo/.github/workflows/lambda-deploy.yml
   ```

4. **Update action reference:**
   ```yaml
   # In .github/workflows/lambda-deploy.yml
   action-ref: "YourOrg/devops-actions/.github/actions/lambda-deploy@lambda-deploy/v1.0.0"
   ```

## 🔧 Configuration Reference

### Project Configuration

```yaml
project:
  name: "your-lambda-function"
  description: "Description of your Lambda function"
  runtime: "bun"  # bun, node, python
  
  # Optional: Specify runtime versions
  versions:
    bun: "latest"
    node: "18"
    python: "3.9"
```

### Build Configuration

```yaml
build:
  # Commands (use "auto" for automatic detection)
  commands:
    install: "auto"  # or "npm ci", "bun install", etc.
    lint: "auto"     # or "eslint src/", "flake8", etc.
    test: "auto"     # or "npm test", "pytest", etc.
    build: "auto"    # or "npm run build", "bun run zip", etc.
  
  # Quality gates
  lint_required: false  # Fail if linting fails
  tests_required: true  # Fail if tests fail
  
  # Artifact configuration
  artifact:
    path: "build/lambda.zip"
    exclude_patterns:
      - "*.md"
      - "tests/"
      - ".env*"
```

### Deployment Configuration

```yaml
deployment:
  # Optional health check
  health_check:
    test_payload: '{"test": true}'

environments:
  dev:
    trigger_branches: 
      - "feature/MMDSQ**"
      - "main"
    aws:
      region: "eu-west-1"
      auth_type: "access_key"
    deployment:
      versioning: false
      run_tests: true
      notifications: false
  
  prod:
    aws:
      region: "eu-west-1" 
      auth_type: "oidc"
    deployment:
      versioning: true
      run_tests: true
      notifications: true
      require_manual_approval: true
    notifications:
      teams:
        webhook_secret: "TEAMS_WEBHOOK_URL"
```

## 🔐 Security Setup

### Required Secrets per Environment

#### Development Environment
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

#### Pre-production/Production
- `AWS_ROLE_ARN` (for OIDC authentication)
- `TEAMS_WEBHOOK_URL` (optional, for notifications)

### Required Variables
- `S3_BUCKET_NAME`
- `LAMBDA_FUNCTION_NAME`

### IAM Permissions

The AWS credentials need the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-deployment-bucket",
        "arn:aws:s3:::your-deployment-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:PublishVersion",
        "lambda:TagResource",
        "lambda:ListVersionsByFunction"
      ],
      "Resource": "arn:aws:lambda:*:*:function:your-function-name"
    }
  ]
}
```

## 🚦 Features Overview

### ✅ Implemented Improvements

1. **Proper YAML Configuration Parsing**
   - Uses `yq` for reliable YAML parsing
   - Validates configuration syntax and required fields
   - Supports complex configuration structures

2. **Comprehensive Error Handling**
   - Validates AWS credentials and resources
   - Checks S3 bucket accessibility
   - Verifies Lambda function exists
   - Retry logic for AWS operations

3. **Security Enhancements**
   - Input validation to prevent injection attacks
   - Package size validation
   - Secure file copying with exclusion patterns
   - Comprehensive tagging for audit trails

4. **Configurable Runtime Support**
   - Supports Bun, Node.js, and Python
   - Configurable runtime versions
   - Custom build commands
   - Quality gates for linting and testing

5. **Deployment Validation**
   - Post-deployment health checks
   - Function state validation
   - Optional test invocation
   - Deployment rollback support

6. **Version Conflict Resolution**
   - Automatic version conflict detection
   - Force deployment option
   - Semantic versioning support
   - Environment-specific versioning strategies

7. **Enhanced Monitoring**
   - Detailed deployment logging
   - Package size reporting
   - Deployment timing metrics
   - Comprehensive tagging

8. **Organization Agnostic**
   - Configurable action references
   - No hardcoded organization names
   - Flexible deployment patterns

## 🔄 Future Migration Notes

When upgrading to future versions:

1. **Review changelog** for breaking changes and new features
2. **Update configuration files** as needed for new options
3. **Update workflow references** to the new version tag
4. **Test thoroughly** in development environment before production

## 🚨 Troubleshooting

### Common Issues

1. **YAML Parsing Errors**
   - Validate YAML syntax using online validators
   - Check for proper indentation
   - Ensure required fields are present

2. **AWS Permission Issues**
   - Verify IAM policies match requirements
   - Check resource ARNs are correct
   - Ensure cross-account roles are properly configured

3. **Build Failures**
   - Check custom build commands are correct
   - Verify dependencies are properly installed
   - Review artifact path configuration

4. **Deployment Failures**
   - Check Lambda function exists and is accessible
   - Verify S3 bucket permissions
   - Review CloudWatch logs for detailed errors

### Debug Mode

Enable debug logging by setting:
```yaml
# In your workflow
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## 📊 Monitoring and Metrics

The action provides comprehensive logging and metrics:

- **Build metrics:** Package size, build time
- **Deployment metrics:** Upload time, deployment time
- **Quality metrics:** Test results, linting results
- **Audit trail:** Complete deployment history with tags

## 🔮 Future Enhancements

Planned improvements for future versions:

- **Multi-region deployment support**
- **Automated rollback capabilities**
- **Integration with monitoring systems**
- **Performance optimization**
- **Advanced security scanning**

---

## Support

For issues and questions:
- Review this documentation
- Check the troubleshooting section
- Open an issue in the central DevOps repository
- Contact the DevOps team

---

*Generated with the Enhanced Lambda Deploy Action v1.0.0*