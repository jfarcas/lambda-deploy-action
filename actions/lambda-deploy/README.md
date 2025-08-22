# Lambda Deploy Action

A production-ready GitHub Action for deploying AWS Lambda functions with comprehensive environment management, version control, and enterprise-grade features.

## 🚀 Features

- **Multi-Environment Support** - Deploy to dev, staging, and production with environment-specific configurations
- **Smart Version Management** - Automatic version detection from multiple sources with conflict prevention
- **Environment Isolation** - Complete S3 and deployment isolation between environments
- **Intelligent Rollback** - Automatic and manual rollback capabilities with environment-specific artifact management
- **Multi-Runtime Support** - Python, Node.js, and Bun with configurable versions
- **Health Checks** - Post-deployment validation with customizable test payloads
- **Rich Deployment Context** - Environment-specific Lambda version descriptions and aliases
- **Enterprise Security** - Comprehensive input validation and audit trails

## 📋 Usage

Create `.github/workflows/lambda-deploy.yml` in your repository:

```yaml
name: Deploy Lambda Function

run-name: >-
  ${{
    github.event_name == 'workflow_dispatch' && 
    format('🚀 Manual Deploy | {0} → {1}', github.actor, inputs.environment) ||
    format('📦 Auto Deploy | {0}', github.ref_name)
  }}

on:
  push:
    branches: [main, feature/**]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options: [dev, pre, prod]
        default: 'dev'
      force-deploy:
        description: 'Force deployment (bypass version conflicts)'
        required: false
        type: boolean
        default: false
      rollback-to-version:
        description: 'Version to rollback to (leave empty for normal deployment)'
        required: false
        type: string
      debug:
        description: 'Enable debug output'
        required: false
        type: boolean
        default: false

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy Lambda
        uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
        with:
          config-file: "lambda-deploy-config.yml"
          environment: ${{ inputs.environment || 'auto' }}
          force-deploy: ${{ inputs.force-deploy || false }}
          rollback-to-version: ${{ inputs.rollback-to-version }}
          debug: ${{ inputs.debug || false }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
          LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
          AWS_REGION: ${{ vars.AWS_REGION }}
          TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
```

## 🔧 Repository Setup

### 1. Configuration File

Create `lambda-deploy-config.yml` in your repository root:

```yaml
project:
  name: "my-lambda-function"
  runtime: "python"
  versions:
    python: "3.9"

build:
  commands:
    install: "pip install -r requirements.txt"
    build: "auto"

environments:
  dev:
    trigger_branches: ["main", "feature/**"]
    aws:
      auth_type: "access_key"
  
  pre:
    trigger_branches: ["main"]
    aws:
      auth_type: "access_key"
  
  prod:
    aws:
      auth_type: "access_key"

deployment:
  health_check:
    enabled: true
    test_payload_object:
      name: "Test"
      source: "deployment-validation"
    expected_status_code: 200
    expected_response_contains: "success"
```

### 2. Repository Configuration

Set up these repository secrets and variables:

**Secrets:**
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `TEAMS_WEBHOOK_URL` - Teams webhook URL (optional)

**Variables:**
- `S3_BUCKET_NAME` - S3 bucket for deployment artifacts
- `LAMBDA_FUNCTION_NAME` - Lambda function name
- `AWS_REGION` - AWS region (e.g., us-east-1)

## 🏗️ Architecture

### Environment Isolation

Each environment maintains complete isolation:

```
S3 Structure:
s3://your-bucket/your-function/
├── environments/
│   ├── dev/
│   │   ├── deployments/timestamp/lambda.zip
│   │   └── latest/lambda.zip
│   ├── pre/
│   │   ├── versions/1.0.0/function-1.0.0.zip
│   │   └── latest/lambda.zip
│   └── prod/
│       ├── versions/1.0.0/function-1.0.0.zip
│       └── latest/lambda.zip
```

### Version Management

- **Dev:** Timestamp-based deployments for rapid iteration
- **Pre:** Version-based with overwrite warnings for staging flexibility
- **Prod:** Strict version checking with conflict prevention

### Lambda Versions

Each deployment creates descriptive Lambda versions:

```
Lambda Versions:
├── Version 5: "DEV: v1.0.1 | abc123 | 2025-08-22 12:46:06 UTC"
├── Version 4: "PRE: v1.0.0 | main | def456 | 2025-08-22 11:00:00 UTC"
└── Version 3: "PROD: v1.0.0 | main | def456 | 2025-08-22 10:00:00 UTC"

Aliases:
├── dev-current → Version 5
├── pre-current → Version 4
└── prod-current → Version 3
```

## 📖 Documentation

- **[Complete Documentation](docs/)** - Comprehensive guides and references
- **[Quick Start Guide](docs/quick-start.md)** - Get started in 5 minutes
- **[Configuration Reference](docs/configuration-reference.md)** - Complete configuration options
- **[Examples](examples/)** - Real-world configuration examples

## 🔧 Advanced Features

### Manual Rollback

```yaml
# In your workflow
- name: Rollback Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    config-file: "lambda-deploy-config.yml"
    environment: "prod"
    rollback-to-version: "1.0.0"
```

### Force Deployment

```yaml
# Bypass version conflicts
- name: Force Deploy
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    force-deploy: true
```

### Custom Version

```yaml
# Override version detection
- name: Deploy Custom Version
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    version: "1.2.0-rc.1"
```

### Debug Mode

```yaml
# Enable detailed logging
- name: Deploy with Debug
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    debug: true
```

## 🔍 Version Detection

The action automatically detects versions from multiple sources in priority order:

1. **pyproject.toml** - `version = "1.0.0"`
2. **package.json** - `"version": "1.0.0"`
3. **version.txt** - `1.0.0`
4. **VERSION** - `1.0.0`
5. **__version__.py** - `__version__ = "1.0.0"`
6. **setup.py** - `version="1.0.0"`
7. **Git tags** - `v1.0.0` or `1.0.0`
8. **Commit hash** - Fallback to short commit hash

## 📋 Requirements

### AWS Resources
- **Lambda function** (pre-created)
- **S3 bucket** for artifact storage
- **IAM permissions** for Lambda and S3 operations

### Required IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject", 
        "s3:ListBucket",
        "lambda:UpdateFunctionCode",
        "lambda:GetFunction",
        "lambda:PublishVersion",
        "lambda:CreateAlias",
        "lambda:DeleteAlias",
        "lambda:TagResource",
        "lambda:ListTags"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket/*",
        "arn:aws:lambda:*:*:function:your-function"
      ]
    }
  ]
}
```

## 🚨 Troubleshooting

### Common Issues

**Version Conflicts:**
```
Error: Version 1.0.0 already exists in production
Solution: Increment version or use force-deploy for emergencies
```

**Missing Environment Variables:**
```
Error: Missing required environment variables
Solution: Set S3_BUCKET_NAME, LAMBDA_FUNCTION_NAME, AWS_REGION as repository variables
```

**Health Check Failures:**
```
Error: Health check failed - unexpected response
Solution: Verify test payload and expected response configuration
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

## 🤝 Contributing

See the [Contributing Guide](CONTRIBUTING.md) for information on how to contribute to this action.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.

## 🆘 Support

- **Documentation:** Check the [docs](docs/) directory
- **Issues:** Open an issue with the `lambda-deploy` label
- **Discussions:** Use GitHub Discussions for questions

---

**Enterprise Ready:** This action is designed for production use with comprehensive error handling, security validation, audit capabilities, and enterprise-grade features.
