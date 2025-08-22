#!/bin/bash
set -euo pipefail

# runtime-setup.sh - Setup Python/Node.js/Bun runtime environments

setup_runtime_environment() {
    echo "🔧 Setting up runtime environment..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Get runtime from configuration (should be set by config-loader.sh)
    local runtime="${PROJECT_RUNTIME:-}"
    
    if [[ -z "$runtime" ]]; then
        echo "::error::Runtime not specified. Ensure config-loader.sh has been run."
        return 1
    fi
    
    echo "RUNTIME=$runtime" >> "$GITHUB_ENV"
    
    # Get runtime versions from configuration (with defaults)
    case "$runtime" in
        "bun")
            local bun_version
            bun_version=$(yq eval '.project.versions.bun // "latest"' "$config_file")
            echo "BUN_VERSION=$bun_version" >> "$GITHUB_ENV"
            echo "Configuring Bun runtime (version: $bun_version)"
            export BUN_VERSION="$bun_version"
            ;;
        "node")
            local node_version
            node_version=$(yq eval '.project.versions.node // "18"' "$config_file")
            echo "NODE_VERSION=$node_version" >> "$GITHUB_ENV"
            echo "Configuring Node.js runtime (version: $node_version)"
            export NODE_VERSION="$node_version"
            ;;
        "python")
            local python_version
            python_version=$(yq eval '.project.versions.python // "3.9"' "$config_file")
            echo "PYTHON_VERSION=$python_version" >> "$GITHUB_ENV"
            echo "Configuring Python runtime (version: $python_version)"
            export PYTHON_VERSION="$python_version"
            ;;
        *)
            echo "::error::Unsupported runtime: $runtime"
            return 1
            ;;
    esac
    
    echo "✅ Runtime environment configured for $runtime"
}

# Setup Bun environment (called by GitHub Actions setup-bun action)
setup_bun_environment() {
    local bun_version="${BUN_VERSION:-latest}"
    
    echo "🟡 Setting up Bun environment (version: $bun_version)"
    
    # This function provides post-setup configuration if needed
    # The actual Bun installation is handled by oven-sh/setup-bun@v1 action
    
    # Verify Bun installation
    if command -v bun >/dev/null 2>&1; then
        echo "✅ Bun is available: $(bun --version)"
        
        # Set up Bun-specific configuration
        export BUN_INSTALL_CACHE_DIR="${HOME}/.bun/install/cache"
        
        # Configure Bun for CI environment
        if [[ "${CI:-false}" == "true" ]]; then
            echo "Configuring Bun for CI environment..."
            export BUN_CONFIG_PROGRESS="false"
        fi
        
    else
        echo "::error::Bun is not available after setup"
        return 1
    fi
}

# Setup Node.js environment (called by GitHub Actions setup-node action)  
setup_node_environment() {
    local node_version="${NODE_VERSION:-18}"
    
    echo "🟢 Setting up Node.js environment (version: $node_version)"
    
    # This function provides post-setup configuration if needed
    # The actual Node.js installation is handled by actions/setup-node@v4 action
    
    # Verify Node.js installation
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        echo "✅ Node.js is available: $(node --version)"
        echo "✅ npm is available: $(npm --version)"
        
        # Configure npm for faster installs
        npm config set progress=false
        npm config set fund=false
        npm config set audit-level=moderate
        
        # Set up npm cache directory
        local npm_cache_dir="${HOME}/.npm"
        mkdir -p "$npm_cache_dir"
        npm config set cache "$npm_cache_dir"
        
        # Check for yarn availability
        if command -v yarn >/dev/null 2>&1; then
            echo "✅ Yarn is also available: $(yarn --version)"
            
            # Configure yarn for CI
            export YARN_CACHE_FOLDER="${HOME}/.yarn/cache"
            mkdir -p "$YARN_CACHE_FOLDER"
        fi
        
    else
        echo "::error::Node.js or npm is not available after setup"
        return 1
    fi
}

# Setup Python environment (called by GitHub Actions setup-python action)
setup_python_environment() {
    local python_version="${PYTHON_VERSION:-3.9}"
    
    echo "🐍 Setting up Python environment (version: $python_version)"
    
    # This function provides post-setup configuration if needed
    # The actual Python installation is handled by actions/setup-python@v5 action
    
    # Verify Python installation
    if command -v python3 >/dev/null 2>&1 && command -v pip >/dev/null 2>&1; then
        echo "✅ Python is available: $(python3 --version)"
        echo "✅ pip is available: $(pip --version)"
        
        # Upgrade pip to latest version
        python3 -m pip install --upgrade pip
        
        # Configure pip for faster installs
        pip config set global.progress-bar off
        pip config set global.disable-pip-version-check true
        
        # Set up pip cache directory
        local pip_cache_dir="${HOME}/.pip/cache"
        mkdir -p "$pip_cache_dir"
        export PIP_CACHE_DIR="$pip_cache_dir"
        
        # Install common build dependencies for Python packages
        echo "Installing common Python build dependencies..."
        pip install --upgrade setuptools wheel
        
        # Check for poetry availability
        if command -v poetry >/dev/null 2>&1; then
            echo "✅ Poetry is available: $(poetry --version)"
            
            # Configure poetry
            poetry config virtualenvs.create false
            poetry config cache-dir "${HOME}/.poetry/cache"
        fi
        
    else
        echo "::error::Python3 or pip is not available after setup"
        return 1
    fi
}

# Detect package manager for Node.js projects
detect_node_package_manager() {
    if [[ -f "bun.lockb" ]]; then
        echo "bun"
    elif [[ -f "yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "package-lock.json" ]]; then
        echo "npm"
    elif [[ -f "package.json" ]]; then
        echo "npm"  # Default to npm if only package.json exists
    else
        echo "none"
    fi
}

# Detect Python dependency manager
detect_python_package_manager() {
    if [[ -f "pyproject.toml" ]]; then
        # Check if poetry is being used
        if grep -q "\[tool\.poetry\]" pyproject.toml 2>/dev/null; then
            echo "poetry"
        else
            echo "pip"  # Could be setuptools, flit, etc.
        fi
    elif [[ -f "requirements.txt" ]]; then
        echo "pip"
    elif [[ -f "Pipfile" ]]; then
        echo "pipenv"
    elif [[ -f "environment.yml" ]] || [[ -f "environment.yaml" ]]; then
        echo "conda"
    else
        echo "pip"  # Default to pip
    fi
}

# Get runtime-specific build information
get_runtime_info() {
    local runtime="${PROJECT_RUNTIME:-}"
    
    if [[ -z "$runtime" ]]; then
        echo "::error::Runtime not specified"
        return 1
    fi
    
    case "$runtime" in
        "bun")
            echo "runtime=$runtime" >> "$GITHUB_OUTPUT"
            echo "package-manager=bun" >> "$GITHUB_OUTPUT"
            echo "lockfile=bun.lockb" >> "$GITHUB_OUTPUT"
            ;;
        "node")
            local package_manager
            package_manager=$(detect_node_package_manager)
            echo "runtime=$runtime" >> "$GITHUB_OUTPUT"
            echo "package-manager=$package_manager" >> "$GITHUB_OUTPUT"
            
            case "$package_manager" in
                "yarn")
                    echo "lockfile=yarn.lock" >> "$GITHUB_OUTPUT"
                    ;;
                "npm")
                    echo "lockfile=package-lock.json" >> "$GITHUB_OUTPUT"
                    ;;
                *)
                    echo "lockfile=none" >> "$GITHUB_OUTPUT"
                    ;;
            esac
            ;;
        "python")
            local package_manager
            package_manager=$(detect_python_package_manager)
            echo "runtime=$runtime" >> "$GITHUB_OUTPUT"
            echo "package-manager=$package_manager" >> "$GITHUB_OUTPUT"
            
            case "$package_manager" in
                "poetry")
                    echo "lockfile=poetry.lock" >> "$GITHUB_OUTPUT"
                    ;;
                "pipenv")
                    echo "lockfile=Pipfile.lock" >> "$GITHUB_OUTPUT"
                    ;;
                *)
                    echo "lockfile=requirements.txt" >> "$GITHUB_OUTPUT"
                    ;;
            esac
            ;;
    esac
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-setup}" in
        "setup")
            setup_runtime_environment
            ;;
        "bun")
            setup_bun_environment
            ;;
        "node")
            setup_node_environment
            ;;
        "python")
            setup_python_environment
            ;;
        "info")
            get_runtime_info
            ;;
        *)
            echo "Usage: $0 [setup|bun|node|python|info]"
            echo "  setup   - Configure runtime environment from config"
            echo "  bun     - Post-setup configuration for Bun"
            echo "  node    - Post-setup configuration for Node.js"
            echo "  python  - Post-setup configuration for Python"
            echo "  info    - Output runtime information"
            exit 1
            ;;
    esac
fi