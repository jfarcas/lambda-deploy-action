#!/bin/bash
set -euo pipefail

# notifications.sh - Send deployment notifications (Teams, Slack, etc.)

source "$(dirname "${BASH_SOURCE[0]}")/retry-utils.sh"

send_teams_notification() {
    echo "📢 Sending Microsoft Teams notification..."
    
    local webhook_url="${TEAMS_WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        echo "::notice::TEAMS_WEBHOOK_URL not configured, skipping Teams notification"
        return 0
    fi
    
    # Gather deployment information
    local deployment_info
    deployment_info=$(gather_deployment_info)
    
    # Create Teams message payload
    local teams_payload
    teams_payload=$(create_teams_payload "$deployment_info")
    
    # Send notification with retry logic
    if send_teams_message "$webhook_url" "$teams_payload"; then
        echo "✅ Teams notification sent successfully"
    else
        echo "::warning::Failed to send Teams notification"
        return 1
    fi
}

gather_deployment_info() {
    # Collect all relevant deployment information
    local function_name="${LAMBDA_FUNCTION_NAME:-unknown}"
    local version="${DETECTED_VERSION:-${ROLLBACK_VERSION:-unknown}}"
    local environment="${DEPLOYMENT_ENVIRONMENT:-unknown}"
    local deployment_type="${DEPLOYMENT_MODE:-deploy}"
    local lambda_version="${LAMBDA_VERSION:-unknown}"
    local package_size="${PACKAGE_SIZE:-unknown}"
    local s3_location="${S3_LOCATION:-unknown}"
    
    # Get additional context
    local deployer="${GITHUB_ACTOR:-system}"
    local repository="${GITHUB_REPOSITORY:-unknown}"
    local commit_sha="${GITHUB_SHA:-unknown}"
    local workflow_run_id="${GITHUB_RUN_ID:-unknown}"
    local branch="${GITHUB_REF_NAME:-unknown}"
    
    # Format package size
    local formatted_size
    if [[ "$package_size" != "unknown" && "$package_size" =~ ^[0-9]+$ ]]; then
        formatted_size=$(numfmt --to=iec "$package_size" 2>/dev/null || echo "$package_size bytes")
    else
        formatted_size="$package_size"
    fi
    
    # Create JSON object with all information
    cat << EOF
{
  "function_name": "$function_name",
  "version": "$version",
  "environment": "$environment",
  "deployment_type": "$deployment_type",
  "lambda_version": "$lambda_version",
  "package_size": "$formatted_size",
  "s3_location": "$s3_location",
  "deployer": "$deployer",
  "repository": "$repository",
  "commit_sha": "$commit_sha",
  "workflow_run_id": "$workflow_run_id",
  "branch": "$branch",
  "timestamp": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
}
EOF
}

create_teams_payload() {
    local deployment_info="$1"
    
    # Extract values from deployment info JSON
    local function_name version environment deployment_type lambda_version
    local package_size deployer repository commit_sha workflow_run_id branch timestamp
    
    if command -v jq >/dev/null 2>&1; then
        function_name=$(echo "$deployment_info" | jq -r '.function_name')
        version=$(echo "$deployment_info" | jq -r '.version')
        environment=$(echo "$deployment_info" | jq -r '.environment')
        deployment_type=$(echo "$deployment_info" | jq -r '.deployment_type')
        lambda_version=$(echo "$deployment_info" | jq -r '.lambda_version')
        package_size=$(echo "$deployment_info" | jq -r '.package_size')
        deployer=$(echo "$deployment_info" | jq -r '.deployer')
        repository=$(echo "$deployment_info" | jq -r '.repository')
        commit_sha=$(echo "$deployment_info" | jq -r '.commit_sha')
        workflow_run_id=$(echo "$deployment_info" | jq -r '.workflow_run_id')
        branch=$(echo "$deployment_info" | jq -r '.branch')
        timestamp=$(echo "$deployment_info" | jq -r '.timestamp')
    else
        # Fallback parsing without jq
        function_name="unknown"
        version="unknown"
        environment="unknown"
        deployment_type="deploy"
        deployer="unknown"
        repository="unknown"
    fi
    
    # Determine notification color and title based on deployment type
    local theme_color title_emoji title_text
    case "$deployment_type" in
        "rollback")
            theme_color="FF6B35"  # Orange
            title_emoji="🔄"
            title_text="Rollback Completed"
            ;;
        "deploy")
            case "$environment" in
                "prod"|"production")
                    theme_color="28A745"  # Green
                    title_emoji="🚀"
                    title_text="Production Deployment Successful"
                    ;;
                "pre"|"staging"|"test")
                    theme_color="007BFF"  # Blue
                    title_emoji="🧪"
                    title_text="Staging Deployment Successful"
                    ;;
                *)
                    theme_color="6F42C1"  # Purple
                    title_emoji="🔧"
                    title_text="Development Deployment Successful"
                    ;;
            esac
            ;;
        *)
            theme_color="6C757D"  # Gray
            title_emoji="📦"
            title_text="Deployment Completed"
            ;;
    esac
    
    # Create the Teams adaptive card payload
    cat << EOF
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "themeColor": "$theme_color",
  "summary": "$title_text",
  "sections": [{
    "activityTitle": "$title_emoji $title_text",
    "activitySubtitle": "Lambda Function: **$function_name**",
    "activityImage": "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
    "facts": [
      {
        "name": "Environment:",
        "value": "$(echo "$environment" | tr '[:lower:]' '[:upper:]')"
      },
      {
        "name": "Version:",
        "value": "$version"
      },
      {
        "name": "Lambda Version:",
        "value": "$lambda_version"
      },
      {
        "name": "Package Size:",
        "value": "$package_size"
      },
      {
        "name": "Deployed By:",
        "value": "$deployer"
      },
      {
        "name": "Repository:",
        "value": "$repository"
      },
      {
        "name": "Branch:",
        "value": "$branch"
      },
      {
        "name": "Timestamp:",
        "value": "$timestamp"
      }
    ],
    "markdown": true
  }],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "View Workflow",
      "targets": [{
        "os": "default",
        "uri": "https://github.com/$repository/actions/runs/$workflow_run_id"
      }]
    },
    {
      "@type": "OpenUri",
      "name": "View Repository",
      "targets": [{
        "os": "default",
        "uri": "https://github.com/$repository"
      }]
    }
  ]
}
EOF
}

send_teams_message() {
    local webhook_url="$1"
    local payload="$2"
    
    echo "Sending Teams message to webhook..."
    
    # Send notification with retry and improved error handling
    if http_retry "$webhook_url" 3 \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -w "HTTP Status: %{http_code}" \
        -o /tmp/teams-response.json; then
        
        echo "✅ Teams message sent successfully"
        
        # Check response for any warnings
        if [[ -f "/tmp/teams-response.json" ]]; then
            local response_content
            response_content=$(cat /tmp/teams-response.json)
            
            # Teams webhook typically returns "1" for success
            if [[ "$response_content" == "1" ]]; then
                echo "✅ Teams webhook confirmed message delivery"
            else
                echo "::warning::Unexpected Teams response: $response_content"
            fi
        fi
        
        rm -f /tmp/teams-response.json
        return 0
    else
        echo "::error::Failed to send Teams notification"
        
        if [[ -f "/tmp/teams-response.json" ]]; then
            echo "Response content:"
            cat /tmp/teams-response.json
        fi
        
        rm -f /tmp/teams-response.json
        return 1
    fi
}

# Send Slack notification (if configured)
send_slack_notification() {
    echo "📢 Sending Slack notification..."
    
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        echo "::notice::SLACK_WEBHOOK_URL not configured, skipping Slack notification"
        return 0
    fi
    
    # Gather deployment information
    local deployment_info
    deployment_info=$(gather_deployment_info)
    
    # Create Slack message payload
    local slack_payload
    slack_payload=$(create_slack_payload "$deployment_info")
    
    # Send notification
    if send_slack_message "$webhook_url" "$slack_payload"; then
        echo "✅ Slack notification sent successfully"
    else
        echo "::warning::Failed to send Slack notification"
        return 1
    fi
}

create_slack_payload() {
    local deployment_info="$1"
    
    # Extract values from deployment info JSON
    local function_name version environment deployment_type
    local deployer repository commit_sha branch timestamp
    
    if command -v jq >/dev/null 2>&1; then
        function_name=$(echo "$deployment_info" | jq -r '.function_name')
        version=$(echo "$deployment_info" | jq -r '.version')
        environment=$(echo "$deployment_info" | jq -r '.environment')
        deployment_type=$(echo "$deployment_info" | jq -r '.deployment_type')
        deployer=$(echo "$deployment_info" | jq -r '.deployer')
        repository=$(echo "$deployment_info" | jq -r '.repository')
        commit_sha=$(echo "$deployment_info" | jq -r '.commit_sha')
        branch=$(echo "$deployment_info" | jq -r '.branch')
        timestamp=$(echo "$deployment_info" | jq -r '.timestamp')
    else
        function_name="unknown"
        version="unknown"
        environment="unknown"
        deployment_type="deploy"
        deployer="unknown"
        repository="unknown"
        commit_sha="unknown"
        branch="unknown"
        timestamp="unknown"
    fi
    
    # Determine emoji and message based on deployment type
    local emoji message_text
    case "$deployment_type" in
        "rollback")
            emoji=":arrows_counterclockwise:"
            message_text="Rollback completed"
            ;;
        *)
            emoji=":rocket:"
            message_text="Deployment successful"
            ;;
    esac
    
    # Create Slack message payload
    cat << EOF
{
  "text": "$emoji Lambda $message_text",
  "attachments": [
    {
      "color": "good",
      "fields": [
        {
          "title": "Function",
          "value": "$function_name",
          "short": true
        },
        {
          "title": "Environment",
          "value": "$(echo "$environment" | tr '[:lower:]' '[:upper:]')",
          "short": true
        },
        {
          "title": "Version",
          "value": "$version",
          "short": true
        },
        {
          "title": "Deployed By",
          "value": "$deployer",
          "short": true
        },
        {
          "title": "Repository",
          "value": "$repository",
          "short": false
        },
        {
          "title": "Branch",
          "value": "$branch",
          "short": true
        },
        {
          "title": "Commit",
          "value": "${commit_sha:0:8}",
          "short": true
        }
      ],
      "footer": "Lambda Deploy Action",
      "ts": $(date +%s)
    }
  ]
}
EOF
}

send_slack_message() {
    local webhook_url="$1"
    local payload="$2"
    
    echo "Sending Slack message to webhook..."
    
    if http_retry "$webhook_url" 3 \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -w "HTTP Status: %{http_code}" \
        -o /tmp/slack-response.json; then
        
        echo "✅ Slack message sent successfully"
        rm -f /tmp/slack-response.json
        return 0
    else
        echo "::error::Failed to send Slack notification"
        
        if [[ -f "/tmp/slack-response.json" ]]; then
            echo "Response content:"
            cat /tmp/slack-response.json
        fi
        
        rm -f /tmp/slack-response.json
        return 1
    fi
}

# Send email notification (if configured)
send_email_notification() {
    echo "📧 Sending email notification..."
    
    local smtp_server="${SMTP_SERVER:-}"
    local smtp_port="${SMTP_PORT:-587}"
    local smtp_user="${SMTP_USER:-}"
    local smtp_password="${SMTP_PASSWORD:-}"
    local email_to="${EMAIL_TO:-}"
    local email_from="${EMAIL_FROM:-noreply@github.com}"
    
    if [[ -z "$smtp_server" || -z "$smtp_user" || -z "$smtp_password" || -z "$email_to" ]]; then
        echo "::notice::Email configuration incomplete, skipping email notification"
        return 0
    fi
    
    echo "::notice::Email notifications not yet implemented"
    echo "Consider using Teams or Slack notifications instead"
}

# Send generic webhook notification
send_webhook_notification() {
    local webhook_url="${WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        echo "::notice::WEBHOOK_URL not configured, skipping webhook notification"
        return 0
    fi
    
    echo "📡 Sending generic webhook notification..."
    
    # Gather deployment information
    local deployment_info
    deployment_info=$(gather_deployment_info)
    
    # Send raw deployment info as JSON
    if http_retry "$webhook_url" 3 \
        -H "Content-Type: application/json" \
        -d "$deployment_info" \
        -w "HTTP Status: %{http_code}" \
        -o /tmp/webhook-response.json; then
        
        echo "✅ Webhook notification sent successfully"
        rm -f /tmp/webhook-response.json
        return 0
    else
        echo "::warning::Failed to send webhook notification"
        
        if [[ -f "/tmp/webhook-response.json" ]]; then
            echo "Response content:"
            cat /tmp/webhook-response.json
        fi
        
        rm -f /tmp/webhook-response.json
        return 1
    fi
}

# Send all configured notifications
send_all_notifications() {
    echo "📢 Sending deployment notifications..."
    
    local notifications_sent=false
    local failed_notifications=()
    
    # Teams notification
    if [[ -n "${TEAMS_WEBHOOK_URL:-}" ]]; then
        if send_teams_notification; then
            notifications_sent=true
        else
            failed_notifications+=("Teams")
        fi
    fi
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        if send_slack_notification; then
            notifications_sent=true
        else
            failed_notifications+=("Slack")
        fi
    fi
    
    # Generic webhook
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        if send_webhook_notification; then
            notifications_sent=true
        else
            failed_notifications+=("Webhook")
        fi
    fi
    
    # Email (placeholder)
    if [[ -n "${EMAIL_TO:-}" ]]; then
        if send_email_notification; then
            notifications_sent=true
        else
            failed_notifications+=("Email")
        fi
    fi
    
    # Summary
    if $notifications_sent; then
        echo "✅ At least one notification was sent successfully"
        
        if [[ ${#failed_notifications[@]} -gt 0 ]]; then
            echo "::warning::Some notifications failed: ${failed_notifications[*]}"
        fi
    else
        if [[ ${#failed_notifications[@]} -gt 0 ]]; then
            echo "::error::All notifications failed: ${failed_notifications[*]}"
            return 1
        else
            echo "::notice::No notification services configured"
        fi
    fi
}

# Test notification configuration
test_notifications() {
    echo "🧪 Testing notification configuration..."
    
    # Override deployment info for testing
    export LAMBDA_FUNCTION_NAME="test-function"
    export DETECTED_VERSION="1.0.0-test"
    export DEPLOYMENT_ENVIRONMENT="test"
    export DEPLOYMENT_MODE="deploy"
    export GITHUB_ACTOR="test-user"
    export GITHUB_REPOSITORY="test/repo"
    
    echo "This is a test notification from Lambda Deploy Action"
    
    send_all_notifications
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-all}" in
        "teams")
            send_teams_notification
            ;;
        "slack")
            send_slack_notification
            ;;
        "email")
            send_email_notification
            ;;
        "webhook")
            send_webhook_notification
            ;;
        "all")
            send_all_notifications
            ;;
        "test")
            test_notifications
            ;;
        *)
            echo "Usage: $0 [teams|slack|email|webhook|all|test]"
            echo "  teams   - Send Microsoft Teams notification"
            echo "  slack   - Send Slack notification"
            echo "  email   - Send email notification"
            echo "  webhook - Send generic webhook notification"
            echo "  all     - Send all configured notifications"
            echo "  test    - Test notification configuration"
            exit 1
            ;;
    esac
fi