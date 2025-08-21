# Lambda Deploy Action

A production-ready, enterprise-grade GitHub Action for deploying AWS Lambda functions with comprehensive validation, security, and monitoring capabilities.

## Features

- **Multi-runtime support:** Bun, Node.js, Python with configurable versions
- **Enhanced security:** Input validation, resource verification, audit trails
- **Deployment validation:** Health checks and post-deployment verification
- **Version conflict resolution:** Automatic detection with force deployment options
- **Organization agnostic:** Fully configurable for any organization
- **Quality gates:** Configurable linting and testing requirements

## Usage

```yaml
- name: Deploy Lambda Function
  uses: YourOrg/devops-actions/.github/actions/lambda-deploy@lambda-deploy/v1.0.0
  with:
    config-file: 'lambda-deploy-config.yml'
    environment: 'auto'
    version: ''
    force-deploy: false
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `config-file` | Path to lambda deploy configuration file | No | `lambda-deploy-config.yml` |
| `environment` | Environment to deploy to (dev, pre, prod, or auto) | No | `auto` |
| `version` | Version to deploy (overrides package.json version) | No | |
| `force-deploy` | Force deployment even if version already exists | No | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `deployed-version` | Version that was deployed |
| `deployment-environment` | Environment where deployment occurred |

## Configuration

Create a `lambda-deploy-config.yml` file in your repository root:

```yaml
project:
  name: "your-lambda-function"
  runtime: "bun"  # bun, node, python
  versions:
    bun: "latest"
    node: "18"
    python: "3.9"

build:
  commands:
    install: "auto"
    lint: "auto"  
    test: "auto"
    build: "auto"
  lint_required: false
  tests_required: true

environments:
  dev:
    trigger_branches: ["main", "feature/**"]
    aws:
      auth_type: "access_key"
  prod:
    aws:
      auth_type: "oidc"
    deployment:
      versioning: true
      notifications: true
```

## Required Secrets

### Development
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Production  
- `AWS_ROLE_ARN`
- `TEAMS_WEBHOOK_URL` (optional)

## Required Variables
- `S3_BUCKET_NAME`
- `LAMBDA_FUNCTION_NAME`

## Examples

See the [examples directory](../../../examples/) for complete configuration examples and workflow templates.

## Documentation

- [Implementation Guide](../../../docs/IMPLEMENTATION-GUIDE.md)
- [Interactive Setup Guide](../../../docs/lambda-deploy-guide-v2.html)
- [Versioning Strategy](../../../docs/github-actions-versioning-guide-v2.html)

## License

This action is provided under your organization's internal license terms.