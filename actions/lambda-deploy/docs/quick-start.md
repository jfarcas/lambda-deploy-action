# Quick Start Guide

Get up and running with Lambda Deploy Action in 5 minutes.

## 🎯 Prerequisites

- AWS Lambda function (already created)
- S3 bucket for deployment artifacts
- GitHub repository with your Lambda code
- AWS credentials with appropriate permissions

## 📋 Step 1: Create Configuration File

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

## 🔧 Step 2: Create GitHub Workflow

Create `.github/workflows/lambda-deploy.yml`:

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

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy Lambda
        uses: YourOrg/lambda-deploy-action/.github/actions/lambda-deploy@v1.0.0
        with:
          config-file: "lambda-deploy-config.yml"
          environment: ${{ inputs.environment || 'auto' }}
          force-deploy: ${{ inputs.force-deploy || false }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
          LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
          AWS_REGION: ${{ vars.AWS_REGION }}
```

## 🔐 Step 3: Configure Repository Secrets

### Add Secrets
Go to Repository Settings → Secrets and variables → Actions → Secrets:

- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

### Add Variables
Go to Repository Settings → Secrets and variables → Actions → Variables:

- `S3_BUCKET_NAME` - Your S3 bucket name (e.g., `my-lambda-deployments`)
- `LAMBDA_FUNCTION_NAME` - Your Lambda function name (e.g., `my-function`)
- `AWS_REGION` - Your AWS region (e.g., `us-east-1`)

## 📦 Step 4: Add Version File

Create one of these files to enable version detection:

### Option A: pyproject.toml (Python)
```toml
[project]
name = "my-lambda-function"
version = "1.0.0"
```

### Option B: package.json (Node.js)
```json
{
  "name": "my-lambda-function",
  "version": "1.0.0"
}
```

### Option C: version.txt
```
1.0.0
```

## 🚀 Step 5: Deploy

### Automatic Deployment
Push to `main` or a `feature/**` branch to trigger automatic deployment to dev environment.

### Manual Deployment
1. Go to Actions tab in your repository
2. Select "Deploy Lambda Function" workflow
3. Click "Run workflow"
4. Choose environment (dev/pre/prod)
5. Click "Run workflow"

## ✅ Step 6: Verify Deployment

After deployment, check:

### GitHub Actions
- Workflow shows dynamic name: `🚀 Manual Deploy | user → prod`
- Deployment logs show environment-specific details
- Success confirmation with deployment summary

### AWS Lambda Console
- New version with descriptive name: `PROD: v1.0.0 | main | abc123 | 2025-08-22 12:00:00 UTC`
- Environment-specific alias: `prod-current`
- Function tags with deployment metadata

### S3 Bucket
- Environment-specific structure:
  ```
  s3://your-bucket/your-function/environments/
  ├── dev/deployments/timestamp/lambda.zip
  ├── pre/versions/1.0.0/function-1.0.0.zip
  └── prod/versions/1.0.0/function-1.0.0.zip
  ```

## 🎯 Next Steps

### Customize Configuration
- Review [Configuration Guide](configuration.md) for advanced options
- Set up [Health Checks](health-checks.md) for your specific needs
- Configure [Rollback System](rollback-system.md) for production safety

### Add More Environments
- Extend configuration for additional environments
- Set up environment-specific triggers and policies
- Configure notifications and monitoring

### Security Hardening
- Review [Security Guide](security.md) for best practices
- Set up OIDC authentication for keyless access
- Implement least privilege IAM policies

## 🚨 Common Issues

### Missing Environment Variables
```
Error: Missing required environment variables
```
**Solution:** Ensure all repository variables are set correctly.

### Version Conflicts
```
Error: Version 1.0.0 already exists in production
```
**Solution:** Increment version or use force-deploy for emergencies.

### Health Check Failures
```
Error: Health check failed - unexpected response
```
**Solution:** Verify test payload and expected response configuration.

## 📚 Learn More

- [Configuration Reference](configuration-schema.md) - Complete configuration options
- [Environment Management](environment-management.md) - Multi-environment strategies
- [Troubleshooting](troubleshooting.md) - Detailed problem solving
- [Examples](examples/) - Real-world configuration examples

---

**🎉 Congratulations!** You now have a production-ready Lambda deployment pipeline with environment isolation, version management, and rollback capabilities.
