#!/bin/bash
set -euo pipefail

# version-detector.sh - Automatic version detection from multiple sources

detect_version() {
    local input_version="${1:-}"
    
    # Check if version is provided as input
    if [[ -n "$input_version" ]]; then
        echo "Using input version: $input_version"
        echo "version=$input_version" >> "$GITHUB_OUTPUT"
        return 0
    fi
    
    echo "🔍 Detecting version from project files..."
    local version=""
    
    # Try different version detection methods in order of preference
    
    # 1. pyproject.toml (Modern Python standard)
    if [[ -f "pyproject.toml" ]] && command -v python3 >/dev/null 2>&1; then
        echo "Found pyproject.toml, extracting version..."
        version=$(grep -E "^version\s*=\s*[\"'].*[\"']" pyproject.toml | sed -E "s/^version\s*=\s*[\"']([^\"']+)[\"'].*/\1/" || echo "")
        if [[ -n "$version" ]]; then
            echo "Found version in pyproject.toml: $version"
        fi
    fi
    
    # 2. __version__.py (Traditional Python)
    if [[ -z "$version" ]] && [[ -f "__version__.py" ]]; then
        echo "Found __version__.py, extracting version..."
        version=$(python3 -c "exec(open('__version__.py').read()); print(__version__)" 2>/dev/null || echo "")
        if [[ -n "$version" ]]; then
            echo "Found version in __version__.py: $version"
        fi
    fi
    
    # 3. setup.py (Traditional Python)
    if [[ -z "$version" ]] && [[ -f "setup.py" ]]; then
        echo "Found setup.py, extracting version..."
        version=$(python3 setup.py --version 2>/dev/null || echo "")
        if [[ -n "$version" ]]; then
            echo "Found version in setup.py: $version"
        fi
    fi
    
    # 4. version.txt (Simple approach)
    if [[ -z "$version" ]] && [[ -f "version.txt" ]]; then
        echo "Found version.txt, reading version..."
        version=$(cat version.txt | tr -d '\n\r' | xargs)
        if [[ -n "$version" ]]; then
            echo "Found version in version.txt: $version"
        fi
    fi
    
    # 5. VERSION file (Alternative simple approach)
    if [[ -z "$version" ]] && [[ -f "VERSION" ]]; then
        echo "Found VERSION file, reading version..."
        version=$(cat VERSION | tr -d '\n\r' | xargs)
        if [[ -n "$version" ]]; then
            echo "Found version in VERSION file: $version"
        fi
    fi
    
    # 6. package.json (for Node.js compatibility)
    if [[ -z "$version" ]] && [[ -f "package.json" ]]; then
        echo "Found package.json, extracting version..."
        version=$(node -p "require('./package.json').version" 2>/dev/null || echo "")
        if [[ -n "$version" ]]; then
            echo "Found version in package.json: $version"
        fi
    fi
    
    # 7. Lambda function code (inline version)
    if [[ -z "$version" ]] && [[ -f "lambda_function.py" ]]; then
        echo "Checking lambda_function.py for inline version..."
        version=$(grep -E "^__version__\s*=\s*['\"]([^'\"]+)['\"]" lambda_function.py | sed -E "s/^__version__\s*=\s*['\"]([^'\"]+)['\"].*/\1/" || echo "")
        if [[ -n "$version" ]]; then
            echo "Found version in lambda_function.py: $version"
        fi
    fi
    
    # 8. Git tag fallback (if no other version found)
    if [[ -z "$version" ]]; then
        echo "No version file found, trying git tags..."
        version=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "")
        if [[ -n "$version" ]]; then
            echo "Found version from git tag: $version"
        fi
    fi
    
    # 9. Commit hash fallback (last resort)
    if [[ -z "$version" ]]; then
        echo "No version found, using commit hash..."
        version=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        echo "::warning::No version found in any standard location, using commit SHA: $version"
        echo "::warning::Consider adding a version file (pyproject.toml, version.txt, or VERSION)"
    fi
    
    # Validate version format
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+.*$ ]] && [[ "$version" != "unknown" ]] && [[ ! "$version" =~ ^[a-f0-9]{7,}$ ]]; then
        echo "::warning::Version '$version' doesn't follow semantic versioning (x.y.z)"
        echo "::warning::Consider using semantic versioning for better version management"
    fi
    
    echo "version=$version" >> "$GITHUB_OUTPUT"
    echo "Version to deploy: $version"
    
    # Export for use by other scripts
    export DETECTED_VERSION="$version"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_version "${1:-}"
fi