#!/bin/bash
set -euo pipefail

# aws-auth.sh - Configure AWS authentication (OIDC or Access Keys)

configure_aws_authentication() {
    local environment="${1:-}"
    
    if [[ -z "$environment" ]]; then
        echo "::error::Environment is required for AWS authentication"
        return 1
    fi
    
    echo "🔐 Configuring AWS authentication for environment: $environment"
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Determine authentication type from configuration
    local auth_type
    auth_type=$(yq eval ".environments.$environment.aws.auth_type // \"access_key\"" "$config_file")
    
    echo "AWS_AUTH_TYPE=$auth_type" >> "$GITHUB_ENV"
    export AWS_AUTH_TYPE="$auth_type"
    
    echo "🔍 AWS Authentication Type: $auth_type"
    
    # Set AWS region - prioritize environment variable over config
    if [[ -z "${AWS_REGION:-}" ]]; then
        local config_region
        config_region=$(yq eval ".environments.$environment.aws.region // \"us-east-1\"" "$config_file")
        echo "AWS_REGION=$config_region" >> "$GITHUB_ENV"
        export AWS_REGION="$config_region"
        echo "🌍 AWS Region (from config): $config_region"
    else
        echo "🌍 AWS Region (from environment): $AWS_REGION"
    fi
    
    # Validate required credentials are present based on auth type
    validate_aws_credentials "$auth_type"
    
    echo "✅ AWS authentication configured successfully"
}

validate_aws_credentials() {
    local auth_type="$1"
    
    echo "🔒 Validating AWS credentials for auth type: $auth_type"
    
    case "$auth_type" in
        "oidc")
            validate_oidc_credentials
            ;;
        "access_key")
            validate_access_key_credentials
            ;;
        *)
            echo "::warning::Unknown auth type: $auth_type, defaulting to access_key"
            echo "AWS_AUTH_TYPE=access_key" >> "$GITHUB_ENV"
            export AWS_AUTH_TYPE="access_key"
            validate_access_key_credentials
            ;;
    esac
}

validate_oidc_credentials() {
    echo "🔑 Validating OIDC credentials..."
    
    if [[ -z "${AWS_ROLE_ARN:-}" ]]; then
        echo "::error::AWS_ROLE_ARN environment variable is required for OIDC authentication"
        echo "::error::Please ensure AWS_ROLE_ARN is set in your GitHub repository secrets/variables"
        return 1
    fi
    
    # Validate role ARN format
    if [[ ! "$AWS_ROLE_ARN" =~ ^arn:aws:iam::[0-9]+:role/.+ ]]; then
        echo "::error::Invalid AWS_ROLE_ARN format: $AWS_ROLE_ARN"
        echo "::error::Expected format: arn:aws:iam::123456789012:role/RoleName"
        return 1
    fi
    
    echo "✅ OIDC credentials validated"
    echo "  Role ARN: $AWS_ROLE_ARN"
}

validate_access_key_credentials() {
    echo "🔑 Validating access key credentials..."
    
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
        echo "::error::AWS_ACCESS_KEY_ID environment variable is required for access key authentication"
        echo "::error::Please ensure AWS_ACCESS_KEY_ID is set in your GitHub repository secrets"
        return 1
    fi
    
    if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "::error::AWS_SECRET_ACCESS_KEY environment variable is required for access key authentication"
        echo "::error::Please ensure AWS_SECRET_ACCESS_KEY is set in your GitHub repository secrets"
        return 1
    fi
    
    # Validate access key format (basic validation)
    if [[ ${#AWS_ACCESS_KEY_ID} -lt 16 || ${#AWS_ACCESS_KEY_ID} -gt 32 ]]; then
        echo "::warning::AWS_ACCESS_KEY_ID length seems unusual (${#AWS_ACCESS_KEY_ID} characters)"
    fi
    
    if [[ ${#AWS_SECRET_ACCESS_KEY} -lt 28 || ${#AWS_SECRET_ACCESS_KEY} -gt 64 ]]; then
        echo "::warning::AWS_SECRET_ACCESS_KEY length seems unusual (${#AWS_SECRET_ACCESS_KEY} characters)"
    fi
    
    echo "✅ Access key credentials validated"
    echo "  Access Key ID: ${AWS_ACCESS_KEY_ID:0:8}********"
}

# Setup AWS CLI configuration
setup_aws_cli_config() {
    echo "🔧 Setting up AWS CLI configuration..."
    
    # Create AWS config directory
    local aws_config_dir="${HOME}/.aws"
    mkdir -p "$aws_config_dir"
    
    # Set basic AWS CLI configuration
    cat > "$aws_config_dir/config" << EOF
[default]
region = ${AWS_REGION:-us-east-1}
output = json
EOF
    
    # Set credentials based on auth type
    if [[ "${AWS_AUTH_TYPE:-}" == "access_key" ]]; then
        cat > "$aws_config_dir/credentials" << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
        
        # Secure the credentials file
        chmod 600 "$aws_config_dir/credentials"
    fi
    
    echo "✅ AWS CLI configuration completed"
}

# Test AWS authentication
test_aws_authentication() {
    echo "🧪 Testing AWS authentication..."
    
    # Test with AWS STS get-caller-identity
    local caller_identity
    if caller_identity=$(aws sts get-caller-identity 2>/dev/null); then
        local account_id
        local user_arn
        local user_id
        
        if command -v jq >/dev/null 2>&1; then
            account_id=$(echo "$caller_identity" | jq -r '.Account')
            user_arn=$(echo "$caller_identity" | jq -r '.Arn')
            user_id=$(echo "$caller_identity" | jq -r '.UserId')
        else
            # Fallback parsing without jq
            account_id=$(echo "$caller_identity" | grep -o '"Account":"[^"]*"' | cut -d'"' -f4)
            user_arn=$(echo "$caller_identity" | grep -o '"Arn":"[^"]*"' | cut -d'"' -f4)
            user_id=$(echo "$caller_identity" | grep -o '"UserId":"[^"]*"' | cut -d'"' -f4)
        fi
        
        echo "✅ AWS authentication successful"
        echo "  Account ID: $account_id"
        echo "  User ARN: $user_arn"
        echo "  User ID: ${user_id:0:20}..."
        
        # Export account ID for use by other scripts
        echo "AWS_ACCOUNT_ID=$account_id" >> "$GITHUB_ENV"
        export AWS_ACCOUNT_ID="$account_id"
        
        return 0
    else
        echo "::error::AWS authentication test failed"
        echo "::error::Unable to get caller identity with current credentials"
        return 1
    fi
}

# Get AWS session information
get_aws_session_info() {
    echo "ℹ️  AWS Session Information:"
    
    # Get region
    local current_region
    current_region=$(aws configure get region 2>/dev/null || echo "${AWS_REGION:-not-set}")
    echo "  Region: $current_region"
    
    # Get account information if possible
    if command -v aws >/dev/null 2>&1; then
        local session_info
        if session_info=$(aws sts get-caller-identity 2>/dev/null); then
            if command -v jq >/dev/null 2>&1; then
                local account_id
                local arn_type
                
                account_id=$(echo "$session_info" | jq -r '.Account')
                arn_type=$(echo "$session_info" | jq -r '.Arn' | cut -d'/' -f1 | cut -d':' -f6)
                
                echo "  Account: $account_id"
                echo "  Authentication: $arn_type"
            fi
        fi
    fi
    
    # Show environment variables (masked)
    echo "  Environment Variables:"
    echo "    AWS_REGION: ${AWS_REGION:-not-set}"
    echo "    AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:+SET}" 
    echo "    AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:+SET}"
    echo "    AWS_ROLE_ARN: ${AWS_ROLE_ARN:-not-set}"
    echo "    AWS_AUTH_TYPE: ${AWS_AUTH_TYPE:-not-set}"
}

# Clean up AWS credentials (for security)
cleanup_aws_credentials() {
    echo "🧹 Cleaning up AWS credentials..."
    
    # Remove credentials file if using access keys
    if [[ -f "${HOME}/.aws/credentials" ]]; then
        rm -f "${HOME}/.aws/credentials"
        echo "  Removed credentials file"
    fi
    
    # Unset environment variables
    if [[ "${AWS_AUTH_TYPE:-}" == "access_key" ]]; then
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
        echo "  Cleared environment variables"
    fi
    
    echo "✅ AWS credentials cleanup completed"
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-configure}" in
        "configure")
            configure_aws_authentication "${2:-prod}"
            ;;
        "test")
            test_aws_authentication
            ;;
        "info")
            get_aws_session_info
            ;;
        "setup")
            setup_aws_cli_config
            ;;
        "cleanup")
            cleanup_aws_credentials
            ;;
        *)
            echo "Usage: $0 [configure|test|info|setup|cleanup] [environment]"
            echo "  configure - Configure AWS authentication for environment"
            echo "  test      - Test AWS authentication"
            echo "  info      - Show AWS session information"
            echo "  setup     - Setup AWS CLI configuration"
            echo "  cleanup   - Clean up AWS credentials"
            exit 1
            ;;
    esac
fi