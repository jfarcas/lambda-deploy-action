#!/bin/bash
set -euo pipefail

# retry-utils.sh - Sophisticated retry mechanisms with exponential backoff

# Retry function with exponential backoff
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local base_delay="${2:-2}"
    local max_delay="${3:-60}"
    local attempt=1
    local delay="$base_delay"
    
    # Shift the retry parameters to get the actual command
    shift 3
    local command=("$@")
    
    while (( attempt <= max_attempts )); do
        echo "Attempt $attempt/$max_attempts: ${command[*]}" >&2
        
        echo "🔍 DEBUG: About to execute command: ${command[*]}" >&2
        
        if "${command[@]}"; then
            echo "✅ Command succeeded on attempt $attempt" >&2
            echo "🔍 DEBUG: Command completed successfully" >&2
            return 0
        fi
        
        local exit_code=$?
        
        if (( attempt == max_attempts )); then
            echo "::error::Command failed after $max_attempts attempts" >&2
            return $exit_code
        fi
        
        echo "⚠️ Command failed (exit code: $exit_code), retrying in ${delay}s..." >&2
        sleep "$delay"
        
        # Exponential backoff with jitter
        delay=$(( delay * 2 ))
        if (( delay > max_delay )); then
            delay=$max_delay
        fi
        
        # Add jitter (random 0-20% of delay)
        local jitter=$(( RANDOM % (delay / 5 + 1) ))
        delay=$(( delay + jitter ))
        
        ((attempt++))
    done
}

# AWS-specific retry with proper error handling
aws_retry() {
    local max_attempts="${1:-3}"
    shift
    local aws_command=("$@")
    
    retry_with_backoff "$max_attempts" 5 30 "${aws_command[@]}"
}

# Lambda function wait with improved logic
wait_for_lambda_ready() {
    local function_name="$1"
    local max_wait_time="${2:-120}"  # seconds
    local check_interval="${3:-2}"   # seconds
    
    echo "⏳ Waiting for Lambda function '$function_name' to be ready..."
    
    local elapsed=0
    local last_state=""
    local last_update_status=""
    
    while (( elapsed < max_wait_time )); do
        local function_info
        if function_info=$(aws lambda get-function --function-name "$function_name" 2>/dev/null); then
            local state
            local update_status
            
            state=$(echo "$function_info" | /usr/bin/jq -r '.Configuration.State // "Unknown"')
            update_status=$(echo "$function_info" | /usr/bin/jq -r '.Configuration.LastUpdateStatus // "Unknown"')
            
            # Only log if state changed
            if [[ "$state" != "$last_state" || "$update_status" != "$last_update_status" ]]; then
                echo "  State: $state, LastUpdateStatus: $update_status (${elapsed}s elapsed)"
                last_state="$state"
                last_update_status="$update_status"
            fi
            
            if [[ "$state" == "Active" && "$update_status" == "Successful" ]]; then
                echo "✅ Lambda function is ready"
                return 0
            elif [[ "$update_status" == "Failed" ]]; then
                echo "::error::Lambda function update failed"
                echo "Function details:"
                echo "$function_info" | /usr/bin/jq '.Configuration'
                return 1
            fi
        else
            echo "::warning::Failed to get function status, continuing..."
        fi
        
        sleep "$check_interval"
        elapsed=$((elapsed + check_interval))
        
        # Progress indicator every 20 seconds
        if (( elapsed % 20 == 0 )); then
            echo "  ⏱️  Still waiting... (${elapsed}s/${max_wait_time}s)"
        fi
    done
    
    echo "::warning::Timeout waiting for Lambda function to be ready after ${max_wait_time}s"
    echo "::warning::Current state: $last_state, LastUpdateStatus: $last_update_status"
    return 1
}

# HTTP retry with exponential backoff
http_retry() {
    local url="$1"
    local max_attempts="${2:-3}"
    shift 2
    local curl_args=("$@")
    
    local attempt=1
    local delay=2
    
    while (( attempt <= max_attempts )); do
        echo "HTTP request attempt $attempt/$max_attempts to: $url" >&2
        
        if curl --fail --silent --show-error --max-time 30 "${curl_args[@]}" "$url"; then
            echo "✅ HTTP request succeeded" >&2
            return 0
        fi
        
        local exit_code=$?
        
        if (( attempt == max_attempts )); then
            echo "::error::HTTP request failed after $max_attempts attempts" >&2
            return $exit_code
        fi
        
        echo "⚠️ HTTP request failed, retrying in ${delay}s..." >&2
        sleep "$delay"
        delay=$(( delay * 2 ))
        ((attempt++))
    done
}

# Check if functions are being called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script provides utility functions and should be sourced, not executed directly."
    echo "Available functions:"
    echo "  - retry_with_backoff <max_attempts> <base_delay> <max_delay> <command...>"
    echo "  - aws_retry <max_attempts> <aws_command...>"
    echo "  - wait_for_lambda_ready <function_name> [max_wait_time] [check_interval]"
    echo "  - http_retry <url> <max_attempts> [curl_args...]"
fi