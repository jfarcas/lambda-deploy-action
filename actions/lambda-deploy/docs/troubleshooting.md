# Troubleshooting Guide

Common issues and solutions for Lambda Deploy Action.

## 🚨 Common Issues

### Environment Variables

#### Missing Required Environment Variables
```
Error: Missing required environment variables: S3_BUCKET_NAME LAMBDA_FUNCTION_NAME AWS_REGION
```

**Cause:** Required environment variables are not set in GitHub repository.

**Solution:**
1. Go to Repository Settings → Secrets and variables → Actions
2. Add these variables in the **Variables** tab:
   - `S3_BUCKET_NAME` - Your S3 bucket name
   - `LAMBDA_FUNCTION_NAME` - Your Lambda function name
   - `AWS_REGION` - Your AWS region
3. Add these secrets in the **Secrets** tab:
   - `AWS_ACCESS_KEY_ID` - Your AWS access key
   - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key

#### Environment Variable Not Found
```
Error: Environment variable 'TEAMS_WEBHOOK_URL' is required but not set
```

**Cause:** Optional environment variable is referenced but not configured.

**Solution:**
- Add the missing secret/variable to your repository
- Or remove the reference from your configuration

### Version Management

#### Version Conflicts in Production
```
Error: Version 1.0.0 already exists in production
Error: Production requires unique versions for audit and rollback
```

**Cause:** Attempting to deploy a version that already exists in production.

**Solutions:**
1. **Increment version (Recommended):**
   ```bash
   # Update version in pyproject.toml, package.json, or version.txt
   echo "1.0.1" > version.txt
   ```

2. **Use force deployment (Emergency only):**
   ```yaml
   - name: Force Deploy
     uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
     with:
       force-deploy: true
   ```

#### Version Detection Failed
```
Warning: No version detected from any source, using commit hash
```

**Cause:** No version file found in repository.

**Solution:** Add a version file:
```bash
# Option 1: pyproject.toml
[project]
version = "1.0.0"

# Option 2: package.json
{
  "version": "1.0.0"
}

# Option 3: version.txt
1.0.0

# Option 4: Git tag
git tag v1.0.0
```

### AWS Integration

#### AWS Authentication Failed
```
Error: Unable to locate credentials
```

**Cause:** AWS credentials not properly configured.

**Solution:**
1. Verify secrets are set:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
2. Check IAM permissions
3. Verify AWS region is correct

#### S3 Access Denied
```
Error: Access Denied when uploading to S3
```

**Cause:** Insufficient S3 permissions.

**Solution:** Ensure IAM policy includes:
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::your-bucket",
    "arn:aws:s3:::your-bucket/*"
  ]
}
```

#### Lambda Function Not Found
```
Error: Function not found: arn:aws:lambda:region:account:function:name
```

**Cause:** Lambda function doesn't exist or incorrect name.

**Solution:**
1. Verify Lambda function exists in AWS console
2. Check `LAMBDA_FUNCTION_NAME` environment variable
3. Verify AWS region is correct

### Health Checks

#### Health Check Failed
```
Error: Health check failed - unexpected response
Response: {"error": "Internal server error"}
```

**Cause:** Lambda function returned unexpected response.

**Solutions:**
1. **Check Lambda function logs:**
   ```bash
   aws logs tail /aws/lambda/your-function --follow
   ```

2. **Verify test payload:**
   ```yaml
   deployment:
     health_check:
       test_payload_object:
         # Ensure this matches what your function expects
         name: "Test"
         source: "deployment-validation"
   ```

3. **Check expected response:**
   ```yaml
   deployment:
     health_check:
       expected_status_code: 200
       expected_response_contains: "success"  # Verify this text is in response
   ```

#### Health Check Timeout
```
Error: Health check timed out after 30 seconds
```

**Cause:** Lambda function taking too long to respond.

**Solutions:**
1. **Increase timeout:**
   ```yaml
   deployment:
     health_check:
       timeout: 60  # Increase from default 30
   ```

2. **Optimize Lambda function performance**
3. **Check Lambda function timeout settings**

### Deployment Issues

#### Lambda Function Update Failed
```
Error: ResourceConflictException: The operation cannot be performed at this time
```

**Cause:** Lambda function is in updating state.

**Solution:** The action automatically handles this with retry logic. If it persists:
1. Check Lambda function state in AWS console
2. Wait for any ongoing updates to complete
3. Retry deployment

#### Package Too Large
```
Error: Request entity too large
```

**Cause:** Lambda deployment package exceeds size limits.

**Solutions:**
1. **Optimize package size:**
   - Remove unnecessary files
   - Use `.gitignore` patterns
   - Optimize dependencies

2. **Check Lambda limits:**
   - Zipped: 50 MB
   - Unzipped: 250 MB

### Rollback Issues

#### Rollback Version Not Found
```
Error: Rollback version 1.0.0 not found in prod environment
```

**Cause:** Specified version was never deployed to target environment.

**Solutions:**
1. **Check available versions:**
   ```bash
   aws s3 ls s3://your-bucket/your-function/environments/prod/versions/
   ```

2. **Use correct version number**
3. **Deploy version first, then rollback**

#### Rollback Not Supported for Dev
```
Error: Rollback not supported for dev environment
```

**Cause:** Dev environment uses timestamp-based deployments.

**Solution:** Use regular deployment instead of rollback for dev environment.

### Configuration Issues

#### Invalid Configuration File
```
Error: Configuration file 'lambda-deploy-config.yml' not found
```

**Cause:** Configuration file missing or incorrect path.

**Solutions:**
1. **Create configuration file in repository root**
2. **Verify file name and path**
3. **Use custom path:**
   ```yaml
   - name: Deploy Lambda
     uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
     with:
       config-file: "path/to/your/config.yml"
   ```

#### Invalid YAML Syntax
```
Error: Invalid YAML syntax in configuration file
```

**Cause:** YAML formatting errors.

**Solution:**
1. **Validate YAML syntax** using online validators
2. **Check indentation** (use spaces, not tabs)
3. **Verify quotes and special characters**

## 🔍 Debug Mode

Enable debug mode for detailed logging:

```yaml
- name: Deploy with Debug
  uses: YourOrg/github-actions-collection/actions/lambda-deploy@v1.0.0
  with:
    debug: true
```

Debug mode provides:
- Detailed step-by-step logging
- Environment variable validation
- AWS API call details
- Configuration parsing information

## 📊 Monitoring and Logs

### GitHub Actions Logs
1. Go to Actions tab in your repository
2. Click on the failed workflow run
3. Expand the "Deploy Lambda" step
4. Review detailed logs and error messages

### AWS CloudWatch Logs
```bash
# View Lambda function logs
aws logs tail /aws/lambda/your-function --follow

# View specific log group
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/"
```

### S3 Deployment Artifacts
```bash
# List deployment artifacts
aws s3 ls s3://your-bucket/your-function/ --recursive

# Check specific environment
aws s3 ls s3://your-bucket/your-function/environments/prod/versions/
```

## 🛠️ Testing and Validation

### Local Testing
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://your-bucket/

# Test Lambda function
aws lambda get-function --function-name your-function
```

### Configuration Validation
```bash
# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('lambda-deploy-config.yml'))"

# Check file exists
ls -la lambda-deploy-config.yml
```

## 📞 Getting Help

### Documentation
- [Configuration Reference](configuration-reference.md)
- [Quick Start Guide](quick-start.md)
- [Examples](../examples/)

### GitHub Support
- Open an issue with the `lambda-deploy` label
- Include error messages and configuration
- Provide workflow run logs
- Describe expected vs actual behavior

### AWS Support
- Check AWS service health status
- Review AWS documentation for Lambda and S3
- Verify IAM permissions and policies
- Test with AWS CLI for debugging

## 🎯 Prevention Tips

### Best Practices
1. **Use version files** for consistent version detection
2. **Test in dev environment** before production
3. **Monitor deployment logs** regularly
4. **Keep IAM permissions minimal** but sufficient
5. **Use health checks** for critical functions

### Configuration Management
1. **Validate YAML syntax** before committing
2. **Use consistent naming** for environments
3. **Document custom configurations**
4. **Test configuration changes** in dev first

### Security
1. **Never commit AWS credentials**
2. **Use repository secrets** for sensitive data
3. **Regularly rotate credentials**
4. **Monitor access logs**

---

**Still having issues?** Open a GitHub issue with detailed error messages and configuration for personalized help.
