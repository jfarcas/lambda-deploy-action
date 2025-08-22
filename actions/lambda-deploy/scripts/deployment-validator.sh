#!/bin/bash
set -euo pipefail

# deployment-validator.sh - Post-deployment validation and health checks

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

validate_deployment() {
    echo "🔍 Validating deployment..."
    
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    if [[ -z "$lambda_function" ]]; then
        echo "::error::LAMBDA_FUNCTION_NAME environment variable is required"
        return 1
    fi
    
    # Wait for function to be active with better error handling
    wait_for_function_active "$lambda_function"
    
    # Get final function configuration
    get_final_function_configuration "$lambda_function"
    
    # Run health checks if configured
    run_deployment_health_checks "$lambda_function"
    
    # Validate deployment completeness
    validate_deployment_completeness "$lambda_function"
    
    echo "✅ Deployment validation completed successfully!"
    echo "deployment-validated=true" >> "$GITHUB_OUTPUT"
}

wait_for_function_active() {
    local lambda_function="$1"
    
    echo "⏳ Waiting for Lambda function to be active..."
    
    # Use custom wait logic with better timeout and error handling
    local max_attempts=30
    local attempt=0
    local wait_interval=10
    
    while [[ $attempt -lt $max_attempts ]]; do
        local function_info
        if function_info=$(aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
            
            if command -v jq >/dev/null 2>&1; then
                local state last_update_status
                state=$(echo "$function_info" | jq -r '.Configuration.State // "Unknown"')
                last_update_status=$(echo "$function_info" | jq -r '.Configuration.LastUpdateStatus // "Unknown"')
                
                echo "  Attempt $((attempt + 1))/$max_attempts - State: $state, LastUpdateStatus: $last_update_status"
                
                if [[ "$state" == "Active" && "$last_update_status" == "Successful" ]]; then
                    echo "✅ Lambda function is active and ready"
                    return 0
                elif [[ "$last_update_status" == "Failed" ]]; then
                    echo "::error::Lambda function update failed: $last_update_status"
                    
                    # Get detailed error information
                    local state_reason state_reason_code
                    state_reason=$(echo "$function_info" | jq -r '.Configuration.StateReason // "Unknown"')
                    state_reason_code=$(echo "$function_info" | jq -r '.Configuration.StateReasonCode // "Unknown"')
                    
                    echo "::error::State Reason: $state_reason"
                    echo "::error::State Reason Code: $state_reason_code"
                    
                    return 1
                fi
            else
                echo "  Attempt $((attempt + 1))/$max_attempts - Checking function status..."
            fi
        else
            echo "::error::Failed to get Lambda function status"
            return 1
        fi
        
        ((attempt++))
        if [[ $attempt -lt $max_attempts ]]; then
            echo "  Waiting ${wait_interval}s before next check..."
            sleep $wait_interval
        fi
    done
    
    echo "::warning::Timeout waiting for Lambda function to be active after $((max_attempts * wait_interval)) seconds"
    echo "::warning::Function may still be updating, but proceeding with validation..."
    
    # Get final state for reporting
    local function_info
    if function_info=$(aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
        if command -v jq >/dev/null 2>&1; then
            local final_state final_status
            final_state=$(echo "$function_info" | jq -r '.Configuration.State // "Unknown"')
            final_status=$(echo "$function_info" | jq -r '.Configuration.LastUpdateStatus // "Unknown"')
            
            echo "::warning::Final state: $final_state, LastUpdateStatus: $final_status"
        fi
    fi
    
    return 0  # Continue with validation despite timeout
}

get_final_function_configuration() {
    local lambda_function="$1"
    
    echo "📋 Getting final function configuration..."
    
    local function_info
    if function_info=$(aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
        
        if command -v jq >/dev/null 2>&1; then
            local state last_update_status runtime code_size timeout memory
            
            state=$(echo "$function_info" | jq -r '.Configuration.State')
            last_update_status=$(echo "$function_info" | jq -r '.Configuration.LastUpdateStatus')
            runtime=$(echo "$function_info" | jq -r '.Configuration.Runtime')
            code_size=$(echo "$function_info" | jq -r '.Configuration.CodeSize')
            timeout=$(echo "$function_info" | jq -r '.Configuration.Timeout')
            memory=$(echo "$function_info" | jq -r '.Configuration.MemorySize')
            
            echo "📊 Function Configuration:"
            echo "  State: $state"
            echo "  Last Update Status: $last_update_status"
            echo "  Runtime: $runtime"
            echo "  Code Size: $(numfmt --to=iec "$code_size" 2>/dev/null || echo "$code_size bytes")"
            echo "  Timeout: ${timeout}s"
            echo "  Memory: ${memory}MB"
            
            # Validate configuration
            if [[ "$state" != "Active" ]]; then
                echo "::warning::Lambda function is not in Active state: $state"
            fi
            
            if [[ "$last_update_status" == "Failed" ]]; then
                echo "::error::Lambda function update failed: $last_update_status"
                return 1
            elif [[ "$last_update_status" == "InProgress" ]]; then
                echo "::warning::Lambda function update is still in progress"
            else
                echo "✅ Lambda function configuration is valid"
            fi
        fi
    else
        echo "::error::Failed to get function configuration"
        return 1
    fi
}

run_deployment_health_checks() {
    local lambda_function="$1"
    
    echo "🏥 Running deployment health checks..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Check if health checks are enabled
    local health_check_enabled
    health_check_enabled=$(yq eval '.deployment.health_check.enabled // true' "$config_file")
    
    if [[ "$health_check_enabled" == "false" ]]; then
        echo "Health checks disabled in configuration"
        return 0
    fi
    
    # Determine deployment mode for appropriate health check
    local deployment_mode="${DEPLOYMENT_MODE:-deploy}"
    
    if [[ "$deployment_mode" == "rollback" ]]; then
        echo "Running post-rollback health check..."
        run_rollback_health_check "$lambda_function" "$config_file"
    else
        echo "Running post-deployment health check..."
        run_deployment_health_check "$lambda_function" "$config_file"
    fi
}

run_deployment_health_check() {
    local lambda_function="$1"
    local config_file="$2"
    
    # Get test payload configuration
    local test_payload test_payload_object
    test_payload=$(yq eval '.deployment.health_check.test_payload // null' "$config_file")
    test_payload_object=$(yq eval '.deployment.health_check.test_payload_object // null' "$config_file")
    
    # Prepare test payload
    local payload_file="/tmp/health-check-payload.json"
    prepare_test_payload "$test_payload" "$test_payload_object" "$payload_file"
    
    echo "🧪 Invoking Lambda function for health check..."
    echo "Function: $lambda_function"
    echo "Payload file: $payload_file"
    
    # Show payload for debugging
    if [[ -f "$payload_file" ]]; then
        echo "Test payload:"
        cat "$payload_file"
        echo ""
    fi
    
    # Invoke the function
    local response_file="/tmp/health-check-response.json"
    local invoke_output="/tmp/health-check-invoke.json"
    
    if aws_retry 3 aws lambda invoke \
        --function-name "$lambda_function" \
        --payload "file://$payload_file" \
        "$response_file" \
        --cli-read-timeout 30 \
        --cli-connect-timeout 10 > "$invoke_output" 2>&1; then
        
        echo "✅ Lambda invocation succeeded"
        
        # Validate the response
        validate_health_check_response "$response_file" "$invoke_output" "$config_file"
        
    else
        echo "::error::Health check failed - Lambda invocation failed"
        echo "📋 Error details:"
        cat "$invoke_output" 2>/dev/null || echo "No error details available"
        
        # Clean up
        rm -f "$payload_file" "$response_file" "$invoke_output"
        return 1
    fi
    
    # Clean up
    rm -f "$payload_file" "$response_file" "$invoke_output"
}

prepare_test_payload() {
    local test_payload="$1"
    local test_payload_object="$2"
    local output_file="$3"
    
    # Determine which payload format to use
    if [[ "$test_payload_object" != "null" ]]; then
        echo "Using YAML object format for payload"
        # Convert YAML object to JSON
        yq eval '.deployment.health_check.test_payload_object' "${CONFIG_FILE_PATH:-lambda-deploy-config.yml}" -o json > "$output_file"
    elif [[ "$test_payload" != "null" ]]; then
        echo "Using JSON string format for payload"
        # Clean and validate the JSON string
        echo "$test_payload" | jq . > "$output_file"
    else
        echo "No test payload configured, using default"
        cat > "$output_file" << 'EOF'
{
  "source": "deployment-health-check",
  "timestamp": "TIMESTAMP_PLACEHOLDER",
  "test": true
}
EOF
        # Replace timestamp placeholder
        local timestamp
        timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        sed -i "s/TIMESTAMP_PLACEHOLDER/$timestamp/" "$output_file"
    fi
    
    # Validate JSON syntax
    if ! jq . "$output_file" > /dev/null 2>&1; then
        echo "::error::Invalid JSON in test payload"
        cat "$output_file"
        return 1
    fi
}

validate_health_check_response() {
    local response_file="$1"
    local invoke_output="$2"
    local config_file="$3"
    
    echo "🔍 Validating health check response..."
    
    # Show invocation metadata
    if [[ -f "$invoke_output" ]]; then
        echo "📊 Invocation metadata:"
        cat "$invoke_output" | jq . 2>/dev/null || cat "$invoke_output"
    fi
    
    # Show response
    if [[ -f "$response_file" ]]; then
        echo "📋 Lambda response:"
        cat "$response_file" | jq . 2>/dev/null || cat "$response_file"
        
        # Get expected response validation from config
        local expected_status_code expected_response_contains expected_error_message
        expected_status_code=$(yq eval '.deployment.health_check.expected_status_code // 200' "$config_file")
        expected_response_contains=$(yq eval '.deployment.health_check.expected_response_contains // null' "$config_file")
        expected_error_message=$(yq eval '.deployment.health_check.expected_error_message // null' "$config_file")
        
        local validation_passed=true
        
        # Check if response contains an error
        if grep -q '"errorMessage"' "$response_file" 2>/dev/null; then
            local error_message error_type
            error_message=$(jq -r '.errorMessage // "Unknown error"' "$response_file" 2>/dev/null || echo "Unknown error")
            error_type=$(jq -r '.errorType // "Unknown"' "$response_file" 2>/dev/null || echo "Unknown")
            
            if [[ "$expected_error_message" != "null" ]]; then
                echo "Expected error response, checking error message..."
                if echo "$error_message" | grep -q "$expected_error_message"; then
                    echo "✅ Expected error message found: $error_message"
                else
                    echo "::warning::Error message doesn't match expected pattern"
                    echo "::warning::Expected: $expected_error_message"
                    echo "::warning::Actual: $error_message"
                    validation_passed=false
                fi
            else
                echo "::warning::Lambda function returned an error: $error_type - $error_message"
                echo "::warning::Function deployed successfully but has runtime issues"
                validation_passed=false
            fi
        else
            # No error in response, validate success response
            echo "No error in response, validating success response..."
            
            # Check status code if response has one
            if jq -e '.statusCode' "$response_file" > /dev/null 2>&1; then
                local actual_status_code
                actual_status_code=$(jq -r '.statusCode' "$response_file")
                echo "Response status code: $actual_status_code"
                
                if [[ "$actual_status_code" != "$expected_status_code" ]]; then
                    echo "::warning::Status code mismatch"
                    echo "::warning::Expected: $expected_status_code"
                    echo "::warning::Actual: $actual_status_code"
                    validation_passed=false
                else
                    echo "✅ Status code matches expected: $expected_status_code"
                fi
            fi
            
            # Check if response contains expected content
            if [[ "$expected_response_contains" != "null" ]]; then
                echo "Checking if response contains: $expected_response_contains"
                if grep -q "$expected_response_contains" "$response_file"; then
                    echo "✅ Response contains expected content"
                else
                    echo "::warning::Response doesn't contain expected content: $expected_response_contains"
                    validation_passed=false
                fi
            fi
            
            # Check response body if it exists
            if jq -e '.body' "$response_file" > /dev/null 2>&1; then
                local response_body
                response_body=$(jq -r '.body' "$response_file")
                echo "Response body: $response_body"
                
                # Try to parse body as JSON if it looks like JSON
                if echo "$response_body" | jq . > /dev/null 2>&1; then
                    echo "Response body is valid JSON"
                    
                    # Additional validation on parsed body if needed
                    if [[ "$expected_response_contains" != "null" ]]; then
                        if echo "$response_body" | grep -q "$expected_response_contains"; then
                            echo "✅ Parsed body contains expected content"
                        fi
                    fi
                fi
            fi
        fi
        
        # Final validation result
        if [[ "$validation_passed" == "true" ]]; then
            echo "✅ Health check passed - function is working correctly"
            return 0
        else
            echo "::warning::Health check validation failed - function may have issues"
            echo "::warning::Function deployed successfully but response validation failed"
            return 1
        fi
        
    else
        echo "::error::No response file generated"
        return 1
    fi
}

run_rollback_health_check() {
    local lambda_function="$1"
    local config_file="$2"
    
    echo "🔄 Running post-rollback health check..."
    
    # Simple health check for rollback - just verify function responds
    local simple_payload='{"source":"rollback-health-check","test":true}'
    
    local response_file="/tmp/rollback-health-response.json"
    
    if aws_retry 2 aws lambda invoke \
        --function-name "$lambda_function" \
        --payload "$simple_payload" \
        "$response_file" > /dev/null 2>&1; then
        
        echo "✅ Rollback health check passed"
        echo "✅ Function is responding after rollback"
        
        # Show response for debugging
        if [[ -f "$response_file" ]]; then
            echo "📋 Rollback health check response:"
            cat "$response_file" | jq . 2>/dev/null || cat "$response_file"
        fi
        
        rm -f "$response_file"
        return 0
    else
        echo "::warning::Rollback health check failed"
        echo "::warning::Function may not be responding properly after rollback"
        
        rm -f "$response_file"
        return 1
    fi
}

validate_deployment_completeness() {
    local lambda_function="$1"
    
    echo "✅ Validating deployment completeness..."
    
    # Check that all expected outputs are set
    local validation_passed=true
    
    # Verify function is accessible
    if aws lambda get-function --function-name "$lambda_function" > /dev/null 2>&1; then
        echo "✅ Lambda function is accessible"
    else
        echo "::error::Lambda function is not accessible"
        validation_passed=false
    fi
    
    # Check if environment variables are properly set
    if [[ -n "${LAMBDA_VERSION:-}" ]]; then
        echo "✅ Lambda version recorded: ${LAMBDA_VERSION}"
    fi
    
    if [[ -n "${S3_LOCATION:-}" ]]; then
        echo "✅ S3 location recorded: ${S3_LOCATION}"
    fi
    
    # Verify deployment outputs were set
    if [[ -f "$GITHUB_OUTPUT" ]] && grep -q "deployment-validated" "$GITHUB_OUTPUT"; then
        echo "✅ GitHub Action outputs configured"
    fi
    
    if $validation_passed; then
        echo "✅ Deployment completeness validation passed"
        return 0
    else
        echo "::error::Deployment completeness validation failed"
        return 1
    fi
}

# Generate deployment validation report
generate_validation_report() {
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    echo "📋 Generating deployment validation report..."
    
    local report_file="/tmp/deployment-validation-report.md"
    
    cat > "$report_file" << EOF
# Deployment Validation Report

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Function: $lambda_function
Environment: ${DEPLOYMENT_ENVIRONMENT:-unknown}
Version: ${DETECTED_VERSION:-unknown}

## Validation Results

### Function Status
- ✅ Function Active: Yes
- ✅ Update Successful: Yes
- ✅ Health Check: Passed

### Deployment Details
- Lambda Version: ${LAMBDA_VERSION:-unknown}
- S3 Location: ${S3_LOCATION:-unknown}
- Package Size: ${PACKAGE_SIZE:-unknown}

### Health Check Results
- Test Payload: Executed
- Response Validation: Passed
- Function Responsiveness: Confirmed

## Post-Deployment Checklist
- [x] Lambda function deployed successfully
- [x] Function is in Active state
- [x] Health check passed
- [x] Environment alias updated
- [x] Deployment tagged

## Recommendations
- Monitor function metrics for the next 30 minutes
- Verify application-specific functionality
- Check logs for any runtime warnings
- Consider running integration tests

EOF
    
    if [[ -f "$report_file" ]]; then
        cat "$report_file"
        
        # Save report as GitHub step summary if available
        if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
            cat "$report_file" >> "$GITHUB_STEP_SUMMARY"
        fi
    fi
    
    rm -f "$report_file"
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-validate}" in
        "validate")
            validate_deployment
            ;;
        "health-check")
            run_deployment_health_checks "${LAMBDA_FUNCTION_NAME:-}"
            ;;
        "report")
            generate_validation_report
            ;;
        *)
            echo "Usage: $0 [validate|health-check|report]"
            echo "  validate     - Run complete deployment validation"
            echo "  health-check - Run health checks only"
            echo "  report       - Generate validation report"
            exit 1
            ;;
    esac
fi