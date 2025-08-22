# Lambda Deploy Action

A production-ready GitHub Action for deploying AWS Lambda functions with comprehensive environment management, version control, and enterprise-grade features.

## 🚀 Features

- **Multi-Environment Support** - Deploy to dev, staging, and production with environment-specific configurations
- **Smart Version Management** - Automatic version detection from multiple sources with conflict prevention
- **Environment Isolation** - Complete S3 and deployment isolation between environments
- **Intelligent Rollback** - Automatic and manual rollback capabilities with environment-specific artifact management
- **Multi-Runtime Support** - Python, Node.js, and Bun with configurable versions
- **Comprehensive Health Checks** - Post-deployment validation with customizable test payloads and proper Lambda invocation
- **Rich Deployment Context** - Environment-specific Lambda version descriptions and aliases
- **Enterprise Security** - Comprehensive input validation and audit trails
- **Robust Error Handling** - Advanced retry logic and proper stdout/stderr separation
- **Optimized S3 Integration** - Efficient storage paths and metadata handling

## 🔧 Recent Improvements (v1.1.0)

- ✅ **Fixed S3 key corruption** - Resolved stdout/stderr separation issues
- ✅ **Enhanced Lambda health checks** - Fixed base64 payload encoding for reliable invocations
- ✅ **Improved AWS CLI integration** - Better output handling and progress reporting
- ✅ **Optimized S3 storage** - Shorter, more efficient S3 key structure
- ✅ **Enhanced error handling** - Comprehensive retry logic and validation
- ✅ **Better debugging support** - Improved logging and error reporting

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
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - pre
          - prod
      deployment_mode:
        description: 'Deployment mode'
        required: true
        default: 'deploy'
        type: choice
        options:
          - deploy
          - rollback

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        
      - name: Deploy Lambda
        uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
        with:
          config-file: "lambda-deploy-config.yml"
          environment: ${{ inputs.environment || 'dev' }}
          deployment-mode: ${{ inputs.deployment_mode || 'deploy' }}
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          S3_BUCKET_NAME: ${{ vars.S3_BUCKET_NAME }}
          LAMBDA_FUNCTION_NAME: ${{ vars.LAMBDA_FUNCTION_NAME }}
          AWS_REGION: ${{ vars.AWS_REGION }}
```

## ⚙️ Configuration

Create `lambda-deploy-config.yml` in your repository root:

```yaml
# Lambda Deploy Configuration
deployment:
  # Package configuration
  package:
    artifact_path: "lambda-function.zip"
    
  # Version detection (in order of precedence)
  version_detection:
    sources:
      - type: "pyproject_toml"
        path: "pyproject.toml"
      - type: "package_json"
        path: "package.json"
      - type: "version_file"
        path: "version.txt"
      - type: "git_tag"
        pattern: "v*"
      - type: "git_commit"
        short: true
    fallback: "1.0.0"
    
  # Environment-specific settings
  environments:
    dev:
      version_policy: "allow_all"
      health_checks:
        enabled: true
        timeout: 30
        payload:
          name: "DevTest"
          source: "GitHub Actions"
          environment: "dev"
    
    pre:
      version_policy: "warn_conflicts"
      health_checks:
        enabled: true
        timeout: 60
        payload:
          name: "PreProdTest"
          source: "GitHub Actions"
          environment: "pre"
    
    prod:
      version_policy: "strict"
      health_checks:
        enabled: true
        timeout: 120
        payload:
          name: "ProdTest"
          source: "GitHub Actions"
          environment: "prod"
          
  # Rollback configuration
  rollback_validation:
    enabled: true
    performance_test:
      enabled: true
      iterations: 5
      max_duration: 5000
    integration_test:
      enabled: false
```

## 🔧 Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `config-file` | Path to configuration file | Yes | - |
| `environment` | Target environment (dev/pre/prod) | Yes | - |
| `deployment-mode` | Deployment mode (deploy/rollback) | No | `deploy` |

## 🌍 Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `AWS_ACCESS_KEY_ID` | AWS access key ID | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | Yes |
| `S3_BUCKET_NAME` | S3 bucket for artifacts | Yes |
| `LAMBDA_FUNCTION_NAME` | Lambda function name | Yes |
| `AWS_REGION` | AWS region | Yes |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `lambda-version` | Published Lambda version number |
| `s3-location` | S3 location of deployed artifact |
| `package-size` | Size of deployment package |
| `deployment-type` | Type of deployment performed |
| `deployed-version` | Version that was deployed |

## 🏗️ Environment-Specific Behavior

### Development Environment (`dev`)
- **Version Policy**: Allow all deployments (rapid iteration)
- **S3 Path**: `function-name/dev/timestamp.zip`
- **Health Checks**: Basic validation (30s timeout)
- **Rollback**: Available with performance testing

### Pre-production Environment (`pre`)
- **Version Policy**: Warn on conflicts but allow deployment
- **S3 Path**: `function-name/pre/version.zip`
- **Health Checks**: Enhanced validation (60s timeout)
- **Rollback**: Full validation with integration tests

### Production Environment (`prod`)
- **Version Policy**: Strict version checking, prevent conflicts
- **S3 Path**: `function-name/prod/version.zip`
- **Health Checks**: Comprehensive validation (120s timeout)
- **Rollback**: Complete validation suite with performance testing

## 🔄 Rollback Process

The action supports intelligent rollback with environment-specific validation:

```yaml
- name: Rollback Lambda
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.1.0
  with:
    config-file: "lambda-deploy-config.yml"
    environment: "prod"
    deployment-mode: "rollback"
  env:
    TARGET_VERSION: "1.2.3"  # Version to rollback to
    # ... other environment variables
```

## 🏥 Health Checks

The action performs comprehensive health checks after deployment:

1. **Function Validation** - Verifies Lambda function is active and ready
2. **Invocation Test** - Tests function with configured payload
3. **Response Validation** - Validates function response format
4. **Performance Check** - Measures response time and validates against thresholds

## 🔍 Version Detection

The action automatically detects versions from multiple sources:

1. **pyproject.toml** - Python projects with Poetry/setuptools
2. **package.json** - Node.js projects with npm/yarn
3. **version.txt** - Simple text file with version
4. **Git Tags** - Git tags matching specified pattern
5. **Git Commit** - Git commit hash (short or full)

## 🛡️ Security Features

- **Input Validation** - Comprehensive validation of all inputs
- **Environment Isolation** - Complete separation between environments
- **Audit Trails** - Detailed logging of all deployment activities
- **IAM Integration** - Proper AWS permissions validation
- **Secure Credential Handling** - No credentials logged or exposed

## 📊 Monitoring & Observability

- **Deployment Metrics** - Track deployment success rates and performance
- **Health Monitoring** - Continuous validation of deployed functions
- **Error Reporting** - Comprehensive error tracking and reporting
- **Performance Analytics** - Deployment time and resource usage tracking

## 🚨 Error Handling

The action includes robust error handling:

- **Retry Logic** - Automatic retry for transient failures
- **Graceful Degradation** - Continue deployment when non-critical steps fail
- **Detailed Error Messages** - Clear error reporting for troubleshooting
- **Rollback on Failure** - Automatic rollback for critical failures

## 📚 Examples

See the [examples](examples/) directory for:
- Multi-environment workflows
- Custom health check configurations
- Rollback procedures
- Integration with monitoring systems

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [docs](docs/) directory for detailed guides
- **Issues**: Report issues with detailed reproduction steps
- **Discussions**: Use GitHub Discussions for questions and feature requests

---

**Production Ready**: This action is battle-tested and ready for enterprise deployment pipelines.
