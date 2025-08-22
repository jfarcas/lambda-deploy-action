#!/bin/bash
set -euo pipefail

# setup-tools.sh - Install required tools like yq

setup_tools() {
    echo "🔧 Setting up required tools..."
    
    # Install yq for proper YAML parsing
    if ! command -v yq &> /dev/null; then
        echo "Installing yq for YAML parsing..."
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
    fi
    
    yq --version
    echo "✅ Tools setup completed"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_tools
fi