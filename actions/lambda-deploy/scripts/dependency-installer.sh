#!/bin/bash
set -euo pipefail

# dependency-installer.sh - Install project dependencies for different runtimes

source "$(dirname "${BASH_SOURCE[0]}")/runtime-setup.sh"

install_dependencies() {
    echo "📦 Installing project dependencies..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Get runtime from environment (should be set by runtime-setup.sh)
    local runtime="${RUNTIME:-}"
    
    if [[ -z "$runtime" ]]; then
        echo "::error::Runtime not specified. Ensure runtime-setup.sh has been run."
        return 1
    fi
    
    # Get custom install command from config, fallback to defaults
    local install_cmd
    install_cmd=$(yq eval '.build.commands.install // "auto"' "$config_file")
    
    if [[ "$install_cmd" != "auto" && "$install_cmd" != "null" ]]; then
        echo "Using custom install command: $install_cmd"
        install_custom_command "$install_cmd"
    else
        echo "Using automatic dependency installation for $runtime"
        case "$runtime" in
            "bun")
                install_bun_dependencies
                ;;
            "node")
                install_node_dependencies
                ;;
            "python")
                install_python_dependencies
                ;;
            *)
                echo "::error::Unsupported runtime: $runtime"
                return 1
                ;;
        esac
    fi
    
    echo "✅ Dependencies installed successfully"
}

# Install custom command with error handling
install_custom_command() {
    local install_cmd="$1"
    
    echo "🔧 Executing custom install command..."
    echo "Command: $install_cmd"
    
    # Execute with proper error handling
    if eval "$install_cmd"; then
        echo "✅ Custom install command completed successfully"
    else
        local exit_code=$?
        echo "::error::Custom install command failed with exit code: $exit_code"
        echo "::error::Command: $install_cmd"
        return $exit_code
    fi
}

# Install Bun dependencies
install_bun_dependencies() {
    echo "🟡 Installing Bun dependencies..."
    
    # Verify Bun is available
    if ! command -v bun >/dev/null 2>&1; then
        echo "::error::Bun is not available. Ensure runtime setup has been completed."
        return 1
    fi
    
    echo "Bun version: $(bun --version)"
    
    # Check for lockfile and install accordingly
    if [[ -f "bun.lockb" ]]; then
        echo "Found bun.lockb, installing from lockfile..."
        bun install --frozen-lockfile
    elif [[ -f "package.json" ]]; then
        echo "Found package.json, installing dependencies..."
        bun install
    else
        echo "::warning::No package.json found, skipping Bun dependency installation"
        return 0
    fi
    
    # Verify installation
    echo "Verifying Bun installation..."
    if [[ -d "node_modules" ]]; then
        local package_count
        package_count=$(find node_modules -maxdepth 1 -type d | wc -l)
        echo "✅ Installed packages: $((package_count - 1))"
    fi
}

# Install Node.js dependencies
install_node_dependencies() {
    echo "🟢 Installing Node.js dependencies..."
    
    # Verify Node.js and npm are available
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        echo "::error::Node.js or npm is not available. Ensure runtime setup has been completed."
        return 1
    fi
    
    echo "Node.js version: $(node --version)"
    echo "npm version: $(npm --version)"
    
    # Detect package manager and install accordingly
    local package_manager
    package_manager=$(detect_node_package_manager)
    
    echo "Detected package manager: $package_manager"
    
    case "$package_manager" in
        "yarn")
            install_with_yarn
            ;;
        "npm")
            install_with_npm
            ;;
        "none")
            echo "::warning::No package.json found, skipping Node.js dependency installation"
            return 0
            ;;
        *)
            echo "::warning::Unknown package manager: $package_manager, falling back to npm"
            install_with_npm
            ;;
    esac
    
    # Verify installation
    echo "Verifying Node.js installation..."
    if [[ -d "node_modules" ]]; then
        local package_count
        package_count=$(find node_modules -maxdepth 1 -type d | wc -l)
        echo "✅ Installed packages: $((package_count - 1))"
    fi
}

# Install with npm
install_with_npm() {
    echo "📦 Installing with npm..."
    
    if [[ -f "package-lock.json" ]]; then
        echo "Found package-lock.json, using npm ci..."
        npm ci
    elif [[ -f "package.json" ]]; then
        echo "Found package.json, using npm install..."
        npm install
    else
        echo "::warning::No package.json found"
        return 0
    fi
}

# Install with Yarn
install_with_yarn() {
    echo "📦 Installing with Yarn..."
    
    # Verify Yarn is available
    if ! command -v yarn >/dev/null 2>&1; then
        echo "::warning::Yarn not found, falling back to npm"
        install_with_npm
        return
    fi
    
    echo "Yarn version: $(yarn --version)"
    
    if [[ -f "yarn.lock" ]]; then
        echo "Found yarn.lock, using yarn install --frozen-lockfile..."
        yarn install --frozen-lockfile
    elif [[ -f "package.json" ]]; then
        echo "Found package.json, using yarn install..."
        yarn install
    else
        echo "::warning::No package.json found"
        return 0
    fi
}

# Install Python dependencies
install_python_dependencies() {
    echo "🐍 Installing Python dependencies..."
    
    # Verify Python and pip are available
    if ! command -v python3 >/dev/null 2>&1 || ! command -v pip >/dev/null 2>&1; then
        echo "::error::Python3 or pip is not available. Ensure runtime setup has been completed."
        return 1
    fi
    
    echo "Python version: $(python3 --version)"
    echo "pip version: $(pip --version)"
    
    # Detect package manager and install accordingly
    local package_manager
    package_manager=$(detect_python_package_manager)
    
    echo "Detected package manager: $package_manager"
    
    case "$package_manager" in
        "poetry")
            install_with_poetry
            ;;
        "pipenv")
            install_with_pipenv
            ;;
        "conda")
            install_with_conda
            ;;
        "pip")
            install_with_pip
            ;;
        *)
            echo "::warning::Unknown package manager: $package_manager, falling back to pip"
            install_with_pip
            ;;
    esac
    
    # Show installed packages for verification
    echo "Verifying Python installation..."
    local installed_count
    installed_count=$(pip list | wc -l)
    echo "✅ Total packages installed: $((installed_count - 2))"  # Subtract header lines
}

# Install with pip
install_with_pip() {
    echo "📦 Installing with pip..."
    
    # Install from requirements.txt if it exists
    if [[ -f "requirements.txt" ]]; then
        echo "Found requirements.txt, installing dependencies..."
        pip install -r requirements.txt
    elif [[ -f "setup.py" ]]; then
        echo "Found setup.py, installing in editable mode..."
        pip install -e .
    elif [[ -f "pyproject.toml" ]]; then
        echo "Found pyproject.toml, installing with pip..."
        pip install .
    else
        echo "::warning::No Python dependency files found (requirements.txt, setup.py, pyproject.toml)"
        return 0
    fi
}

# Install with Poetry
install_with_poetry() {
    echo "📦 Installing with Poetry..."
    
    # Verify Poetry is available
    if ! command -v poetry >/dev/null 2>&1; then
        echo "::warning::Poetry not found, falling back to pip"
        install_with_pip
        return
    fi
    
    echo "Poetry version: $(poetry --version)"
    
    if [[ -f "pyproject.toml" ]]; then
        echo "Installing dependencies with Poetry..."
        
        # Configure poetry for CI
        poetry config virtualenvs.create false
        
        # Install dependencies
        if [[ -f "poetry.lock" ]]; then
            echo "Found poetry.lock, installing from lockfile..."
            poetry install --no-dev
        else
            echo "Installing from pyproject.toml..."
            poetry install --no-dev
        fi
    else
        echo "::warning::No pyproject.toml found for Poetry"
        install_with_pip
    fi
}

# Install with Pipenv
install_with_pipenv() {
    echo "📦 Installing with Pipenv..."
    
    # Verify Pipenv is available
    if ! command -v pipenv >/dev/null 2>&1; then
        echo "::warning::Pipenv not found, installing it first..."
        pip install pipenv
    fi
    
    echo "Pipenv version: $(pipenv --version)"
    
    if [[ -f "Pipfile" ]]; then
        echo "Installing dependencies with Pipenv..."
        
        # Install dependencies (skip dev dependencies in production)
        pipenv install --deploy --system
    else
        echo "::warning::No Pipfile found for Pipenv"
        install_with_pip
    fi
}

# Install with Conda
install_with_conda() {
    echo "📦 Installing with Conda..."
    
    # Verify Conda is available
    if ! command -v conda >/dev/null 2>&1; then
        echo "::warning::Conda not found, falling back to pip"
        install_with_pip
        return
    fi
    
    echo "Conda version: $(conda --version)"
    
    if [[ -f "environment.yml" ]]; then
        echo "Installing from environment.yml..."
        conda env update --file environment.yml --name base
    elif [[ -f "environment.yaml" ]]; then
        echo "Installing from environment.yaml..."
        conda env update --file environment.yaml --name base
    else
        echo "::warning::No environment.yml found for Conda"
        install_with_pip
    fi
}

# Clean up dependency caches and temporary files
cleanup_dependency_artifacts() {
    echo "🧹 Cleaning up dependency artifacts..."
    
    local runtime="${RUNTIME:-}"
    
    case "$runtime" in
        "bun")
            # Clean Bun cache if needed
            if [[ -d "${HOME}/.bun" ]]; then
                echo "Bun cache size: $(du -sh "${HOME}/.bun" 2>/dev/null | cut -f1 || echo "unknown")"
            fi
            ;;
        "node")
            # Clean npm/yarn cache if needed
            if [[ -d "${HOME}/.npm" ]]; then
                echo "npm cache size: $(du -sh "${HOME}/.npm" 2>/dev/null | cut -f1 || echo "unknown")"
            fi
            if [[ -d "${HOME}/.yarn" ]]; then
                echo "Yarn cache size: $(du -sh "${HOME}/.yarn" 2>/dev/null | cut -f1 || echo "unknown")"
            fi
            ;;
        "python")
            # Clean pip cache if needed
            if [[ -d "${HOME}/.pip" ]]; then
                echo "pip cache size: $(du -sh "${HOME}/.pip" 2>/dev/null | cut -f1 || echo "unknown")"
            fi
            
            # Remove __pycache__ directories
            find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
            find . -name "*.pyc" -delete 2>/dev/null || true
            ;;
    esac
    
    echo "✅ Cleanup completed"
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-install}" in
        "install")
            install_dependencies
            ;;
        "cleanup")
            cleanup_dependency_artifacts
            ;;
        *)
            echo "Usage: $0 [install|cleanup]"
            echo "  install - Install project dependencies"
            echo "  cleanup - Clean up dependency artifacts"
            exit 1
            ;;
    esac
fi