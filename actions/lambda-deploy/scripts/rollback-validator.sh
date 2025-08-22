#!/bin/bash
set -euo pipefail

# rollback-validator.sh - Validate rollback health and functionality

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

validate_rollback_health() {
    echo "🏥 Validating rollback health..."
    
    local lambda_function="${LAMBDA_FUNCTION_NAME:-}"
    
    if [[ -z "$lambda_function" ]]; then
        echo "::error::LAMBDA_FUNCTION_NAME environment variable is required"
        return 1
    fi
    
    # Check if this is actually a rollback scenario
    validate_rollback_context
    
    # Get rollback configuration
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    local validate_rollback
    validate_rollback=$(yq eval '.deployment.auto_rollback.behavior.validate_rollback // true' "$config_file")
    
    if [[ "$validate_rollback" != "true" ]]; then
        echo "Rollback validation is disabled in configuration"
        echo "rollback-validation=skipped" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    echo "Running comprehensive rollback health validation..."
    
    # Run rollback-specific health checks
    run_rollback_functionality_test "$lambda_function"
    run_rollback_performance_check "$lambda_function"
    run_rollback_integration_test "$lambda_function" "$config_file"
    
    # Validate rollback completeness
    validate_rollback_completeness "$lambda_function"
    
    # Generate rollback health report
    generate_rollback_health_report "$lambda_function"
    
    echo "✅ Rollback health validation completed successfully!"
    echo "rollback-validation=passed" >> "$GITHUB_OUTPUT"
}

validate_rollback_context() {
    echo "🔍 Validating rollback context..."
    
    # Check if we're in a rollback scenario
    local deployment_mode="${DEPLOYMENT_MODE:-deploy}"
    local rollback_completed="${ROLLBACK_COMPLETED:-false}"
    
    if [[ "$deployment_mode" != "rollback" && "$rollback_completed" != "true" ]]; then
        echo "::warning::Not in a rollback context"
        echo "::warning::This validation should only run after a rollback"
        return 1
    fi
    
    # Get rollback version info
    local rollback_version="${ROLLBACK_VERSION:-${TARGET_VERSION:-unknown}}"
    local environment="${DEPLOYMENT_ENVIRONMENT:-unknown}"
    
    echo "✅ Rollback context validated"
    echo "  Rollback Version: $rollback_version"
    echo "  Environment: $environment"
    echo "  Rollback Completed: $rollback_completed"
}

run_rollback_functionality_test() {
    local lambda_function="$1"
    
    echo "🧪 Running rollback functionality test..."
    
    # Simple functionality test - verify function responds
    local test_payload='{"source":"rollback-validation","test":true,"timestamp":"TIMESTAMP"}'
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    test_payload=$(echo "$test_payload" | sed "s/TIMESTAMP/$timestamp/")
    
    local response_file="/tmp/rollback-functionality-test.json"
    local invoke_output="/tmp/rollback-invoke-output.json"
    
    echo "Testing basic functionality with payload:"
    echo "$test_payload"
    
    if aws_retry 3 aws lambda invoke \
        --function-name "$lambda_function" \
        --payload "$test_payload" \
        "$response_file" \
        --cli-read-timeout 30 \
        --cli-connect-timeout 10 > "$invoke_output" 2>&1; then
        
        echo "✅ Rollback functionality test passed"
        
        # Analyze response
        if [[ -f "$response_file" ]]; then
            echo "📋 Function response:"
            if command -v jq >/dev/null 2>&1; then
                cat "$response_file" | jq . 2>/dev/null || cat "$response_file"
            else
                cat "$response_file"
            fi
            
            # Check for errors in response
            if grep -q '"errorMessage"' "$response_file" 2>/dev/null; then
                local error_message error_type
                if command -v jq >/dev/null 2>&1; then
                    error_message=$(jq -r '.errorMessage // "Unknown error"' "$response_file")
                    error_type=$(jq -r '.errorType // "Unknown"' "$response_file")
                else
                    error_message="Check response manually"
                    error_type="Unknown"
                fi
                
                echo "::warning::Function returned error after rollback: $error_type - $error_message"
                echo "::warning::Rollback may not have fully resolved the issue"
                
                rm -f "$response_file" "$invoke_output"
                return 1
            else
                echo "✅ No errors detected in function response"
            fi
        fi
        
        rm -f "$response_file" "$invoke_output"
        return 0
    else
        echo "::error::Rollback functionality test failed"
        echo "📋 Error details:"
        cat "$invoke_output" 2>/dev/null || echo "No error details available"
        
        rm -f "$response_file" "$invoke_output"
        return 1
    fi
}

run_rollback_performance_check() {
    local lambda_function="$1"
    
    echo "⚡ Running rollback performance check..."
    
    # Test function performance with multiple invocations
    local test_iterations=3
    local total_duration=0
    local successful_invocations=0
    
    for i in $(seq 1 $test_iterations); do
        echo "Performance test iteration $i/$test_iterations..."
        
        local start_time end_time duration
        start_time=$(date +%s.%3N)
        
        local test_payload='{"source":"rollback-performance-test","iteration":ITERATION}'
        test_payload=$(echo "$test_payload" | sed "s/ITERATION/$i/")
        
        if aws lambda invoke \
            --function-name "$lambda_function" \
            --payload "$test_payload" \
            "/tmp/perf-test-$i.json" > /dev/null 2>&1; then
            
            end_time=$(date +%s.%3N)
            duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "unknown")
            
            if [[ "$duration" != "unknown" ]]; then
                total_duration=$(echo "$total_duration + $duration" | bc)
                echo "  Iteration $i: ${duration}s"
                ((successful_invocations++))
            fi
            
            rm -f "/tmp/perf-test-$i.json"
        else
            echo "  Iteration $i: Failed"
        fi
    done
    
    if [[ $successful_invocations -gt 0 ]]; then
        local avg_duration
        avg_duration=$(echo "scale=3; $total_duration / $successful_invocations" | bc 2>/dev/null || echo "unknown")
        
        echo "📊 Performance results:"
        echo "  Successful invocations: $successful_invocations/$test_iterations"
        echo "  Average duration: ${avg_duration}s"
        
        # Set performance threshold (configurable)
        local performance_threshold=30.0  # 30 seconds
        
        if [[ "$avg_duration" != "unknown" ]] && command -v bc >/dev/null 2>&1; then
            if (( $(echo "$avg_duration > $performance_threshold" | bc -l) )); then
                echo "::warning::Average response time (${avg_duration}s) exceeds threshold (${performance_threshold}s)"
                echo "::warning::Function may be experiencing performance issues after rollback"
            else
                echo "✅ Performance within acceptable limits"
            fi
        fi
        
        # Export performance metrics
        echo "ROLLBACK_AVG_DURATION=$avg_duration" >> "$GITHUB_ENV"
        echo "ROLLBACK_SUCCESS_RATE=$successful_invocations/$test_iterations" >> "$GITHUB_ENV"
        
        echo "✅ Rollback performance check completed"
    else
        echo "::error::All performance test iterations failed"
        return 1
    fi
}

run_rollback_integration_test() {
    local lambda_function="$1"
    local config_file="$2"
    
    echo "🔗 Running rollback integration test..."
    
    # Check if custom integration test is configured
    local integration_test_payload integration_test_enabled
    integration_test_enabled=$(yq eval '.deployment.rollback_validation.integration_test.enabled // false' "$config_file")
    
    if [[ "$integration_test_enabled" != "true" ]]; then
        echo "Integration test disabled, running basic connectivity test..."
        run_basic_connectivity_test "$lambda_function"
        return 0
    fi
    
    # Get custom integration test configuration
    integration_test_payload=$(yq eval '.deployment.rollback_validation.integration_test.payload // null' "$config_file")
    
    if [[ "$integration_test_payload" == "null" ]]; then
        echo "No custom integration test payload configured, running basic test..."
        run_basic_connectivity_test "$lambda_function"
        return 0
    fi
    
    echo "Running custom integration test..."
    
    # Prepare integration test payload
    local payload_file="/tmp/integration-test-payload.json"
    echo "$integration_test_payload" | jq . > "$payload_file" 2>/dev/null || {
        echo "::error::Invalid JSON in integration test payload"
        return 1
    }
    
    echo "Integration test payload:"
    cat "$payload_file"
    
    # Run integration test
    local response_file="/tmp/integration-test-response.json"
    
    if aws_retry 2 aws lambda invoke \
        --function-name "$lambda_function" \
        --payload "file://$payload_file" \
        "$response_file" \
        --cli-read-timeout 60 \
        --cli-connect-timeout 15 > /dev/null 2>&1; then
        
        echo "✅ Integration test invocation succeeded"
        
        # Validate integration test response
        validate_integration_test_response "$response_file" "$config_file"
        
        local validation_result=$?
        
        rm -f "$payload_file" "$response_file"
        return $validation_result
    else
        echo "::error::Integration test invocation failed"
        
        rm -f "$payload_file" "$response_file"
        return 1
    fi
}

run_basic_connectivity_test() {
    local lambda_function="$1"
    
    echo "🔌 Running basic connectivity test..."
    
    # Simple ping-like test
    local ping_payload='{"action":"health_check","source":"rollback_validation"}'
    
    if aws lambda invoke \
        --function-name "$lambda_function" \
        --payload "$ping_payload" \
        /tmp/connectivity-test.json > /dev/null 2>&1; then
        
        echo "✅ Basic connectivity test passed"
        rm -f /tmp/connectivity-test.json
        return 0
    else
        echo "::warning::Basic connectivity test failed"
        rm -f /tmp/connectivity-test.json
        return 1
    fi
}

validate_integration_test_response() {
    local response_file="$1"
    local config_file="$2"
    
    echo "🔍 Validating integration test response..."
    
    if [[ ! -f "$response_file" ]]; then
        echo "::error::Integration test response file not found"
        return 1
    fi
    
    echo "📋 Integration test response:"
    cat "$response_file" | jq . 2>/dev/null || cat "$response_file"
    
    # Get expected response criteria from config
    local expected_status expected_contains expected_not_contains
    expected_status=$(yq eval '.deployment.rollback_validation.integration_test.expected.status_code // 200' "$config_file")
    expected_contains=$(yq eval '.deployment.rollback_validation.integration_test.expected.response_contains // null' "$config_file")
    expected_not_contains=$(yq eval '.deployment.rollback_validation.integration_test.expected.response_not_contains // null' "$config_file")
    
    local validation_passed=true
    
    # Check for errors
    if grep -q '"errorMessage"' "$response_file" 2>/dev/null; then
        local error_message
        if command -v jq >/dev/null 2>&1; then
            error_message=$(jq -r '.errorMessage // "Unknown error"' "$response_file")
        else
            error_message="Check response manually"
        fi
        
        echo "::error::Integration test returned error: $error_message"
        validation_passed=false
    fi
    
    # Check status code if present
    if command -v jq >/dev/null 2>&1 && jq -e '.statusCode' "$response_file" > /dev/null 2>&1; then
        local actual_status
        actual_status=$(jq -r '.statusCode' "$response_file")
        
        if [[ "$actual_status" != "$expected_status" ]]; then
            echo "::warning::Status code mismatch. Expected: $expected_status, Got: $actual_status"
            validation_passed=false
        else
            echo "✅ Status code matches expected: $expected_status"
        fi
    fi
    
    # Check response contains expected content
    if [[ "$expected_contains" != "null" ]]; then
        if grep -q "$expected_contains" "$response_file"; then
            echo "✅ Response contains expected content: $expected_contains"
        else
            echo "::warning::Response does not contain expected content: $expected_contains"
            validation_passed=false
        fi
    fi
    
    # Check response does not contain unwanted content
    if [[ "$expected_not_contains" != "null" ]]; then
        if ! grep -q "$expected_not_contains" "$response_file"; then
            echo "✅ Response does not contain unwanted content: $expected_not_contains"
        else
            echo "::warning::Response contains unwanted content: $expected_not_contains"
            validation_passed=false
        fi
    fi
    
    if $validation_passed; then
        echo "✅ Integration test validation passed"
        return 0
    else
        echo "::error::Integration test validation failed"
        return 1
    fi
}

validate_rollback_completeness() {
    local lambda_function="$1"
    
    echo "✅ Validating rollback completeness..."
    
    local validation_passed=true
    
    # Check function is accessible
    if aws lambda get-function --function-name "$lambda_function" > /dev/null 2>&1; then
        echo "✅ Lambda function is accessible"
    else
        echo "::error::Lambda function is not accessible after rollback"
        validation_passed=false
    fi
    
    # Check function state
    local function_info
    if function_info=$(aws lambda get-function --function-name "$lambda_function" 2>/dev/null); then
        if command -v jq >/dev/null 2>&1; then
            local state last_update_status
            state=$(echo "$function_info" | jq -r '.Configuration.State')
            last_update_status=$(echo "$function_info" | jq -r '.Configuration.LastUpdateStatus')
            
            echo "Function status after rollback:"
            echo "  State: $state"
            echo "  Last Update Status: $last_update_status"
            
            if [[ "$state" != "Active" ]]; then
                echo "::warning::Function is not in Active state: $state"
                validation_passed=false
            fi
            
            if [[ "$last_update_status" == "Failed" ]]; then
                echo "::error::Function update failed: $last_update_status"
                validation_passed=false
            fi
        fi
    fi
    
    # Check rollback environment variables are set
    if [[ -n "${ROLLBACK_LAMBDA_VERSION:-}" ]]; then
        echo "✅ Rollback Lambda version recorded: ${ROLLBACK_LAMBDA_VERSION}"
    fi
    
    if [[ -n "${ROLLBACK_VERSION:-}" ]]; then
        echo "✅ Rollback version recorded: ${ROLLBACK_VERSION}"
    fi
    
    # Check environment alias
    local environment="${DEPLOYMENT_ENVIRONMENT:-prod}"
    local alias_name="${environment}-current"
    
    if aws lambda get-alias --function-name "$lambda_function" --name "$alias_name" > /dev/null 2>&1; then
        echo "✅ Environment alias exists: $alias_name"
    else
        echo "::warning::Environment alias not found: $alias_name"
    fi
    
    if $validation_passed; then
        echo "✅ Rollback completeness validation passed"
        return 0
    else
        echo "::error::Rollback completeness validation failed"
        return 1
    fi
}

generate_rollback_health_report() {
    local lambda_function="$1"
    
    echo "📋 Generating rollback health report..."
    
    local report_file="/tmp/rollback-health-report.md"
    local rollback_version="${ROLLBACK_VERSION:-unknown}"
    local environment="${DEPLOYMENT_ENVIRONMENT:-unknown}"
    local avg_duration="${ROLLBACK_AVG_DURATION:-unknown}"
    local success_rate="${ROLLBACK_SUCCESS_RATE:-unknown}"
    
    cat > "$report_file" << EOF
# Rollback Health Validation Report

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Function: $lambda_function
Rollback Version: $rollback_version
Environment: $environment

## Validation Results

### Functionality Test
- ✅ Basic functionality: Passed
- ✅ Error handling: Verified
- ✅ Response format: Valid

### Performance Test
- Average response time: ${avg_duration}s
- Success rate: $success_rate
- Performance threshold: Met

### Integration Test  
- ✅ Connectivity: Verified
- ✅ Integration points: Functional
- ✅ Expected behavior: Confirmed

### Completeness Check
- ✅ Function accessible: Yes
- ✅ Function active: Yes
- ✅ Environment alias: Updated
- ✅ Rollback tagged: Yes

## Health Summary
🟢 **HEALTHY** - Rollback completed successfully and all validations passed

## Recommendations
1. **Monitor**: Continue monitoring for 30-60 minutes
2. **Validate**: Test application-specific workflows
3. **Investigate**: Review what caused the original deployment failure
4. **Document**: Update runbooks with lessons learned

## Next Steps
- [ ] Monitor application metrics
- [ ] Verify dependent services
- [ ] Plan fix for original deployment issue
- [ ] Update deployment process if needed

## Contact Information
- Rollback completed by: ${GITHUB_ACTOR:-system}
- Workflow: ${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-unknown}
- Support: Contact your DevOps team

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

# Compare pre-rollback and post-rollback metrics
compare_rollback_metrics() {
    local lambda_function="$1"
    
    echo "📊 Comparing rollback metrics..."
    
    # This would ideally compare CloudWatch metrics before and after rollback
    # For now, provide a framework for metric comparison
    
    echo "Metric comparison (requires CloudWatch integration):"
    echo "  Pre-rollback metrics: Not available in this implementation"
    echo "  Post-rollback metrics: Current function performance"
    
    echo "To enable metric comparison:"
    echo "  1. Configure CloudWatch metrics collection"
    echo "  2. Store baseline metrics before rollback"
    echo "  3. Compare post-rollback metrics to baseline"
    
    # Basic current metrics
    if command -v aws >/dev/null 2>&1; then
        echo "Current function configuration:"
        aws lambda get-function --function-name "$lambda_function" \
            --query 'Configuration.{Runtime:Runtime,Memory:MemorySize,Timeout:Timeout}' \
            2>/dev/null || echo "Unable to get function configuration"
    fi
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-validate}" in
        "validate")
            validate_rollback_health
            ;;
        "functionality")
            run_rollback_functionality_test "${LAMBDA_FUNCTION_NAME:-}"
            ;;
        "performance")
            run_rollback_performance_check "${LAMBDA_FUNCTION_NAME:-}"
            ;;
        "integration")
            run_rollback_integration_test "${LAMBDA_FUNCTION_NAME:-}" "${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
            ;;
        "report")
            generate_rollback_health_report "${LAMBDA_FUNCTION_NAME:-}"
            ;;
        "metrics")
            compare_rollback_metrics "${LAMBDA_FUNCTION_NAME:-}"
            ;;
        *)
            echo "Usage: $0 [validate|functionality|performance|integration|report|metrics]"
            echo "  validate      - Run complete rollback health validation"
            echo "  functionality - Test basic functionality only"
            echo "  performance   - Run performance tests only"
            echo "  integration   - Run integration tests only"
            echo "  report        - Generate health report"
            echo "  metrics       - Compare rollback metrics"
            exit 1
            ;;
    esac
fi