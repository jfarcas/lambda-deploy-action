#!/bin/bash
set -euo pipefail

# package-builder.sh - Build Lambda deployment packages for different runtimes

build_lambda_package() {
    echo "📦 Building Lambda deployment package..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Get runtime from environment (should be set by runtime-setup.sh)
    local runtime="${RUNTIME:-}"
    
    if [[ -z "$runtime" ]]; then
        echo "::error::Runtime not specified. Ensure runtime-setup.sh has been run."
        return 1
    fi
    
    # Get custom build command from config
    local build_cmd
    build_cmd=$(yq eval '.build.commands.build // "auto"' "$config_file")
    
    local artifact_path
    artifact_path=$(yq eval '.build.artifact.path // "build/lambda.zip"' "$config_file")
    
    # Security: Validate artifact path to prevent directory traversal
    if [[ "$artifact_path" =~ \.\. ]]; then
        echo "::error::Invalid artifact path contains '..': $artifact_path"
        return 1
    fi
    
    # Ensure build directory exists
    local build_dir
    build_dir=$(dirname "$artifact_path")
    mkdir -p "$build_dir"
    
    echo "Build configuration:"
    echo "  Runtime: $runtime"
    echo "  Build command: $build_cmd"
    echo "  Artifact path: $artifact_path"
    
    if [[ "$build_cmd" != "auto" && "$build_cmd" != "null" ]]; then
        echo "Using custom build command..."
        build_with_custom_command "$build_cmd" "$artifact_path"
    else
        echo "Using automatic build for $runtime..."
        case "$runtime" in
            "bun")
                build_bun_package "$artifact_path"
                ;;
            "node")
                build_node_package "$artifact_path"
                ;;
            "python")
                build_python_package "$artifact_path" "$config_file"
                ;;
            *)
                echo "::error::Unsupported runtime for automatic build: $runtime"
                return 1
                ;;
        esac
    fi
    
    # Verify package was created and validate it
    validate_lambda_package "$artifact_path"
    
    # Set environment variable for other scripts
    echo "ARTIFACT_PATH=$artifact_path" >> "$GITHUB_ENV"
    export ARTIFACT_PATH="$artifact_path"
    
    echo "✅ Lambda package built successfully: $artifact_path"
}

# Build with custom command
build_with_custom_command() {
    local build_cmd="$1"
    local artifact_path="$2"
    
    echo "🔧 Executing custom build command: $build_cmd"
    
    if ! eval "$build_cmd"; then
        echo "::error::Custom build command failed"
        return 1
    fi
    
    # Verify the custom command produced the expected artifact
    if [[ ! -f "$artifact_path" ]]; then
        echo "::error::Custom build command did not produce expected artifact: $artifact_path"
        return 1
    fi
}

# Build Bun package
build_bun_package() {
    local artifact_path="$1"
    local build_dir
    build_dir=$(dirname "$artifact_path")
    
    echo "🟡 Building Bun Lambda package..."
    
    # Check for build scripts in package.json
    if [[ -f "package.json" ]]; then
        if bun run --silent zip 2>/dev/null; then
            echo "Using 'bun run zip' script..."
            bun run zip
        elif bun run --silent build 2>/dev/null; then
            echo "Using 'bun run build' script..."
            bun run build
            
            # Create zip if build doesn't create it
            if [[ ! -f "$artifact_path" ]] && [[ -d "$build_dir" ]]; then
                echo "Creating zip from build directory..."
                create_zip_from_directory "$build_dir" "$artifact_path"
            fi
        else
            echo "No build script found, creating package manually..."
            build_bun_package_manual "$artifact_path"
        fi
    else
        echo "::error::No package.json found for Bun project"
        return 1
    fi
}

# Manual Bun package building
build_bun_package_manual() {
    local artifact_path="$1"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    echo "Creating Bun package manually..."
    
    # Copy source files
    cp -r . "$temp_dir/" 2>/dev/null || true
    
    # Remove development files
    cd "$temp_dir"
    rm -rf node_modules/.cache
    rm -rf .git
    rm -rf tests
    rm -rf test
    rm -rf "*.test.*"
    rm -rf coverage
    
    # Create the zip
    zip -r "$(basename "$artifact_path")" . -x "*.git*" "node_modules/.cache/*" "test/*" "tests/*"
    
    # Move back to original directory and copy artifact
    cd - >/dev/null
    mv "$temp_dir/$(basename "$artifact_path")" "$artifact_path"
    rm -rf "$temp_dir"
}

# Build Node.js package
build_node_package() {
    local artifact_path="$1"
    local build_dir
    build_dir=$(dirname "$artifact_path")
    
    echo "🟢 Building Node.js Lambda package..."
    
    # Check for build scripts in package.json
    if [[ -f "package.json" ]]; then
        if npm run --silent zip 2>/dev/null; then
            echo "Using 'npm run zip' script..."
            npm run zip
        elif npm run --silent build 2>/dev/null; then
            echo "Using 'npm run build' script..."
            npm run build
            
            # Create zip if build doesn't create it
            if [[ ! -f "$artifact_path" ]] && [[ -d "$build_dir" ]]; then
                echo "Creating zip from build directory..."
                create_zip_from_directory "$build_dir" "$artifact_path"
            fi
        else
            echo "No build script found, creating package manually..."
            build_node_package_manual "$artifact_path"
        fi
    else
        echo "::error::No package.json found for Node.js project"
        return 1
    fi
}

# Manual Node.js package building
build_node_package_manual() {
    local artifact_path="$1"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    echo "Creating Node.js package manually..."
    
    # Copy source files and production dependencies
    cp -r . "$temp_dir/" 2>/dev/null || true
    
    # Install only production dependencies in temp directory
    cd "$temp_dir"
    
    if [[ -f "package-lock.json" ]]; then
        npm ci --only=production
    elif [[ -f "yarn.lock" ]]; then
        yarn install --production --frozen-lockfile
    else
        npm install --only=production
    fi
    
    # Remove development files
    rm -rf .git
    rm -rf tests
    rm -rf test
    rm -rf coverage
    rm -rf "*.test.*"
    rm -rf node_modules/.cache
    
    # Create the zip
    zip -r "$(basename "$artifact_path")" . -x "*.git*" "node_modules/.cache/*" "test/*" "tests/*"
    
    # Move back and copy artifact
    cd - >/dev/null
    mv "$temp_dir/$(basename "$artifact_path")" "$artifact_path"
    rm -rf "$temp_dir"
}

# Build Python package
build_python_package() {
    local artifact_path="$1"
    local config_file="$2"
    
    echo "🐍 Building Python Lambda package..."
    
    # Create temporary build directory
    local temp_build_dir
    temp_build_dir=$(mktemp -d)
    
    echo "Using temporary build directory: $temp_build_dir"
    
    # Install dependencies if requirements exist
    install_python_dependencies_for_package "$temp_build_dir"
    
    # Copy Python source files
    copy_python_source_files "$temp_build_dir" "$config_file"
    
    # Create the final zip package
    create_python_zip_package "$temp_build_dir" "$artifact_path"
    
    # Clean up
    rm -rf "$temp_build_dir"
}

# Install Python dependencies for packaging
install_python_dependencies_for_package() {
    local build_dir="$1"
    
    echo "📦 Installing Python dependencies for packaging..."
    
    # Install from requirements.txt if it exists
    if [[ -f "requirements.txt" ]]; then
        echo "Installing from requirements.txt..."
        pip install -r requirements.txt -t "$build_dir/"
    elif [[ -f "pyproject.toml" ]]; then
        echo "Installing from pyproject.toml..."
        # Extract dependencies and install them
        if command -v poetry >/dev/null 2>&1; then
            # Use poetry to install dependencies
            poetry export -f requirements.txt --output /tmp/lambda-requirements.txt
            pip install -r /tmp/lambda-requirements.txt -t "$build_dir/"
            rm -f /tmp/lambda-requirements.txt
        else
            # Fallback to pip install
            pip install . -t "$build_dir/"
        fi
    elif [[ -f "setup.py" ]]; then
        echo "Installing from setup.py..."
        pip install . -t "$build_dir/"
    fi
}

# Copy Python source files
copy_python_source_files() {
    local build_dir="$1"
    local config_file="$2"
    
    echo "📁 Copying Python source files..."
    
    # Get exclude patterns from config
    local exclude_patterns=""
    if yq eval '.build.artifact.exclude_patterns' "$config_file" | grep -q "^-"; then
        exclude_patterns=$(yq eval '.build.artifact.exclude_patterns[]' "$config_file" 2>/dev/null | tr '\n' ' ' || echo "")
    fi
    
    # Copy Python files, excluding test files and sensitive files
    echo "Copying .py files..."
    find . -name "*.py" \
        -not -path "./tests/*" \
        -not -path "./.git/*" \
        -not -path "./venv/*" \
        -not -path "./.venv/*" \
        -not -name "*test*.py" \
        -exec cp {} "$build_dir/" \; 2>/dev/null || true
    
    # Copy src directory if it exists
    if [[ -d "src" ]]; then
        echo "Copying src/ directory..."
        cp -r src/* "$build_dir/" 2>/dev/null || true
    fi
    
    # Copy any configuration files that might be needed
    for config_pattern in "*.json" "*.yml" "*.yaml" "*.toml" "*.ini"; do
        find . -maxdepth 1 -name "$config_pattern" -exec cp {} "$build_dir/" \; 2>/dev/null || true
    done
    
    # Apply exclude patterns
    if [[ -n "$exclude_patterns" ]]; then
        echo "Applying exclude patterns: $exclude_patterns"
        cd "$build_dir"
        for pattern in $exclude_patterns; do
            find . -name "$pattern" -delete 2>/dev/null || true
        done
        cd - >/dev/null
    fi
}

# Create Python zip package
create_python_zip_package() {
    local build_dir="$1"
    local artifact_path="$2"
    
    echo "🗜️  Creating Python zip package..."
    
    cd "$build_dir"
    
    # Remove unnecessary files to reduce package size
    echo "Cleaning up unnecessary files..."
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    find . -name ".DS_Store" -delete 2>/dev/null || true
    
    # Remove test files from dependencies
    find . -path "*/tests/*" -delete 2>/dev/null || true
    find . -name "*test*" -type f -delete 2>/dev/null || true
    
    # Create zip with maximum compression
    zip -r9 "$(basename "$artifact_path")" . -x "*.git*" "*__pycache__*" "*.pyc" "*.pyo"
    
    cd - >/dev/null
    
    # Move the zip to the final location
    mv "$build_dir/$(basename "$artifact_path")" "$artifact_path"
}

# Create zip from directory (generic)
create_zip_from_directory() {
    local source_dir="$1"
    local artifact_path="$2"
    
    echo "🗜️  Creating zip from directory: $source_dir"
    
    if [[ -d "$source_dir" ]]; then
        cd "$source_dir"
        zip -r "$(basename "$artifact_path")" . -x "*.git*" "node_modules/.cache/*" "__pycache__/*" "*.pyc"
        cd - >/dev/null
        
        mv "$source_dir/$(basename "$artifact_path")" "$artifact_path"
    else
        echo "::error::Source directory does not exist: $source_dir"
        return 1
    fi
}

# Validate the created Lambda package
validate_lambda_package() {
    local artifact_path="$1"
    
    echo "🔍 Validating Lambda package..."
    
    # Check if package exists
    if [[ ! -f "$artifact_path" ]]; then
        echo "::error::Lambda package not found at $artifact_path"
        return 1
    fi
    
    # Check package size
    local package_size
    if command -v stat >/dev/null 2>&1; then
        if stat -f%z "$artifact_path" >/dev/null 2>&1; then
            # macOS
            package_size=$(stat -f%z "$artifact_path")
        else
            # Linux
            package_size=$(stat -c%s "$artifact_path")
        fi
    else
        package_size=$(ls -la "$artifact_path" | awk '{print $5}')
    fi
    
    local package_size_mb=$((package_size / 1024 / 1024))
    
    echo "📊 Package information:"
    echo "  Size: ${package_size} bytes (${package_size_mb}MB)"
    echo "  Location: $artifact_path"
    
    # Export package size for notifications and other scripts
    echo "PACKAGE_SIZE=$package_size" >> "$GITHUB_ENV"
    export PACKAGE_SIZE="$package_size"
    
    # Check AWS Lambda limits
    if [[ $package_size_mb -gt 250 ]]; then
        echo "::error::Lambda package exceeds AWS limit (250MB unzipped)"
        echo "Consider optimizing your dependencies or excluding unnecessary files"
        return 1
    elif [[ $package_size_mb -gt 200 ]]; then
        echo "::warning::Lambda package is large (${package_size_mb}MB). Consider optimization."
    fi
    
    # Check if zip is valid
    if command -v unzip >/dev/null 2>&1; then
        if unzip -t "$artifact_path" >/dev/null 2>&1; then
            echo "✅ Package zip integrity verified"
        else
            echo "::error::Package zip is corrupted or invalid"
            return 1
        fi
    fi
    
    # List contents for verification (first 10 files)
    echo "📋 Package contents (sample):"
    if command -v unzip >/dev/null 2>&1; then
        unzip -l "$artifact_path" | head -20
    fi
    
    echo "✅ Package validation completed"
}

# Optimize package size
optimize_package() {
    local artifact_path="$1"
    
    echo "⚡ Optimizing package size..."
    
    if [[ ! -f "$artifact_path" ]]; then
        echo "::error::Package not found for optimization: $artifact_path"
        return 1
    fi
    
    local original_size
    original_size=$(stat -c%s "$artifact_path" 2>/dev/null || stat -f%z "$artifact_path")
    
    # Create temporary directory for optimization
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Extract, optimize, and repackage
    cd "$temp_dir"
    unzip -q "$artifact_path"
    
    # Remove additional unnecessary files
    find . -name "*.md" -delete 2>/dev/null || true
    find . -name "LICENSE*" -delete 2>/dev/null || true
    find . -name "README*" -delete 2>/dev/null || true
    find . -name "*.txt" -not -name "requirements.txt" -delete 2>/dev/null || true
    
    # Repackage with maximum compression
    zip -r9 "optimized.zip" . -x "*.git*"
    
    cd - >/dev/null
    
    # Replace original with optimized version
    mv "$temp_dir/optimized.zip" "$artifact_path"
    rm -rf "$temp_dir"
    
    local new_size
    new_size=$(stat -c%s "$artifact_path" 2>/dev/null || stat -f%z "$artifact_path")
    
    local saved_bytes=$((original_size - new_size))
    local saved_mb=$((saved_bytes / 1024 / 1024))
    
    if [[ $saved_bytes -gt 0 ]]; then
        echo "✅ Package optimized: saved ${saved_mb}MB"
    else
        echo "ℹ️  No significant size reduction achieved"
    fi
}

# Run the appropriate function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-build}" in
        "build")
            build_lambda_package
            ;;
        "optimize")
            optimize_package "${2:-build/lambda.zip}"
            ;;
        "validate")
            validate_lambda_package "${2:-build/lambda.zip}"
            ;;
        *)
            echo "Usage: $0 [build|optimize|validate] [artifact_path]"
            echo "  build        - Build Lambda deployment package"
            echo "  optimize     - Optimize existing package size"
            echo "  validate     - Validate package"
            exit 1
            ;;
    esac
fi