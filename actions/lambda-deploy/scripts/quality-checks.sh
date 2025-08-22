#!/bin/bash
set -euo pipefail

# quality-checks.sh - Run linting and testing for code quality

run_linting() {
    echo "🔍 Running code linting..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Get lint command from config
    local lint_cmd
    lint_cmd=$(yq eval '.build.commands.lint // ""' "$config_file")
    
    if [[ -n "$lint_cmd" && "$lint_cmd" != "null" ]]; then
        echo "Running lint command: $lint_cmd"
        run_quality_command "lint" "$lint_cmd" "non-blocking"
    else
        echo "No lint command specified, trying auto-detection..."
        run_auto_linting
    fi
    
    echo "✅ Linting completed"
}

run_tests() {
    echo "🧪 Running tests..."
    
    # Get config file path from environment or use default
    local config_file="${CONFIG_FILE_PATH:-lambda-deploy-config.yml}"
    
    # Get test command from config
    local test_cmd
    test_cmd=$(yq eval '.build.commands.test // ""' "$config_file")
    
    if [[ -n "$test_cmd" && "$test_cmd" != "null" ]]; then
        echo "Running test command: $test_cmd"
        run_quality_command "test" "$test_cmd" "blocking"
    else
        echo "No test command specified, trying auto-detection..."
        run_auto_testing
    fi
    
    echo "✅ Tests completed"
}

# Run a quality command with proper error handling
run_quality_command() {
    local command_type="$1"
    local command="$2"
    local error_handling="${3:-blocking}"  # blocking or non-blocking
    
    echo "🔧 Executing $command_type command..."
    echo "Command: $command"
    echo "Error handling: $error_handling"
    
    # Create output files for command results
    local output_file="/tmp/${command_type}_output.txt"
    local error_file="/tmp/${command_type}_error.txt"
    
    # Execute command with output capture
    local exit_code=0
    if ! eval "$command" > "$output_file" 2> "$error_file"; then
        exit_code=$?
    fi
    
    # Display output
    if [[ -s "$output_file" ]]; then
        echo "📋 $command_type output:"
        cat "$output_file"
    fi
    
    # Handle errors based on configuration
    if [[ $exit_code -ne 0 ]]; then
        if [[ -s "$error_file" ]]; then
            echo "📋 $command_type errors:"
            cat "$error_file"
        fi
        
        if [[ "$error_handling" == "blocking" ]]; then
            echo "::error::$command_type failed with exit code: $exit_code"
            echo "::error::Command: $command"
            rm -f "$output_file" "$error_file"
            return $exit_code
        else
            echo "::warning::$command_type failed but deployment will continue"
            echo "::warning::Exit code: $exit_code"
            echo "::warning::Command: $command"
        fi
    else
        echo "✅ $command_type passed"
    fi
    
    # Clean up temporary files
    rm -f "$output_file" "$error_file"
    return 0
}

# Auto-detect and run linting based on runtime
run_auto_linting() {
    local runtime="${RUNTIME:-}"
    
    case "$runtime" in
        "python")
            run_python_linting
            ;;
        "node"|"bun")
            run_javascript_linting
            ;;
        *)
            echo "::warning::No auto-linting available for runtime: $runtime"
            ;;
    esac
}

# Auto-detect and run tests based on runtime
run_auto_testing() {
    local runtime="${RUNTIME:-}"
    
    case "$runtime" in
        "python")
            run_python_testing
            ;;
        "node"|"bun")
            run_javascript_testing
            ;;
        *)
            echo "::warning::No auto-testing available for runtime: $runtime"
            ;;
    esac
}

# Python linting
run_python_linting() {
    echo "🐍 Running Python linting..."
    
    local lint_tools_found=false
    
    # Check for common Python linting tools
    if command -v flake8 >/dev/null 2>&1; then
        echo "Running flake8..."
        if flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics; then
            echo "✅ flake8 passed"
        else
            echo "::warning::flake8 found issues"
        fi
        lint_tools_found=true
    fi
    
    if command -v pylint >/dev/null 2>&1; then
        echo "Running pylint..."
        if find . -name "*.py" -exec pylint {} + --errors-only; then
            echo "✅ pylint passed"
        else
            echo "::warning::pylint found issues"
        fi
        lint_tools_found=true
    fi
    
    if command -v black >/dev/null 2>&1; then
        echo "Running black (format check)..."
        if black --check .; then
            echo "✅ black formatting passed"
        else
            echo "::warning::black formatting issues found"
        fi
        lint_tools_found=true
    fi
    
    if command -v isort >/dev/null 2>&1; then
        echo "Running isort (import sorting check)..."
        if isort --check-only .; then
            echo "✅ isort passed"
        else
            echo "::warning::isort found import sorting issues"
        fi
        lint_tools_found=true
    fi
    
    if ! $lint_tools_found; then
        echo "::warning::No Python linting tools found (flake8, pylint, black, isort)"
        echo "Consider adding linting tools to your requirements.txt or setup.py"
    fi
}

# JavaScript/TypeScript linting
run_javascript_linting() {
    echo "🟡 Running JavaScript/TypeScript linting..."
    
    local lint_tools_found=false
    
    # Check package.json for lint script
    if [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
        echo "Found lint script in package.json..."
        case "$RUNTIME" in
            "bun")
                if bun run lint; then
                    echo "✅ bun run lint passed"
                else
                    echo "::warning::bun run lint found issues"
                fi
                ;;
            *)
                if npm run lint; then
                    echo "✅ npm run lint passed"
                else
                    echo "::warning::npm run lint found issues"
                fi
                ;;
        esac
        lint_tools_found=true
    fi
    
    # Check for ESLint
    if command -v eslint >/dev/null 2>&1; then
        echo "Running ESLint..."
        if eslint . --ext .js,.ts,.jsx,.tsx; then
            echo "✅ ESLint passed"
        else
            echo "::warning::ESLint found issues"
        fi
        lint_tools_found=true
    fi
    
    # Check for Prettier
    if command -v prettier >/dev/null 2>&1; then
        echo "Running Prettier (format check)..."
        if prettier --check .; then
            echo "✅ Prettier formatting passed"
        else
            echo "::warning::Prettier formatting issues found"
        fi
        lint_tools_found=true
    fi
    
    if ! $lint_tools_found; then
        echo "::warning::No JavaScript linting tools found"
        echo "Consider adding ESLint or a lint script to package.json"
    fi
}

# Python testing
run_python_testing() {
    echo "🐍 Running Python tests..."
    
    local test_runner_found=false
    
    # Check for pytest
    if command -v pytest >/dev/null 2>&1 && find . -name "*test*.py" -o -name "test_*.py" | grep -q .; then
        echo "Running pytest..."
        if pytest --tb=short -v; then
            echo "✅ pytest passed"
        else
            echo "::error::pytest failed"
            return 1
        fi
        test_runner_found=true
    fi
    
    # Check for unittest
    if ! $test_runner_found && find . -name "*test*.py" | grep -q .; then
        echo "Running unittest discover..."
        if python -m unittest discover -s . -p "*test*.py" -v; then
            echo "✅ unittest passed"
        else
            echo "::error::unittest failed"
            return 1
        fi
        test_runner_found=true
    fi
    
    # Check for tox
    if ! $test_runner_found && [[ -f "tox.ini" ]] && command -v tox >/dev/null 2>&1; then
        echo "Running tox..."
        if tox; then
            echo "✅ tox passed"
        else
            echo "::error::tox failed"
            return 1
        fi
        test_runner_found=true
    fi
    
    if ! $test_runner_found; then
        echo "::warning::No Python tests found or test runners available"
        echo "Looked for: pytest, unittest, or tox.ini"
    fi
}

# JavaScript/TypeScript testing
run_javascript_testing() {
    echo "🟡 Running JavaScript/TypeScript tests..."
    
    local test_runner_found=false
    
    # Check package.json for test script
    if [[ -f "package.json" ]] && grep -q '"test"' package.json; then
        echo "Found test script in package.json..."
        case "$RUNTIME" in
            "bun")
                if bun run test; then
                    echo "✅ bun run test passed"
                else
                    echo "::error::bun run test failed"
                    return 1
                fi
                ;;
            *)
                if npm run test; then
                    echo "✅ npm run test passed"
                else
                    echo "::error::npm run test failed"
                    return 1
                fi
                ;;
        esac
        test_runner_found=true
    fi
    
    # Check for specific test frameworks
    if ! $test_runner_found; then
        # Check for Jest
        if command -v jest >/dev/null 2>&1; then
            echo "Running Jest..."
            if jest; then
                echo "✅ Jest passed"
            else
                echo "::error::Jest failed"
                return 1
            fi
            test_runner_found=true
        fi
        
        # Check for Mocha
        if ! $test_runner_found && command -v mocha >/dev/null 2>&1; then
            echo "Running Mocha..."
            if mocha; then
                echo "✅ Mocha passed"
            else
                echo "::error::Mocha failed"
                return 1
            fi
            test_runner_found=true
        fi
        
        # Check for Vitest
        if ! $test_runner_found && command -v vitest >/dev/null 2>&1; then
            echo "Running Vitest..."
            if vitest run; then
                echo "✅ Vitest passed"
            else
                echo "::error::Vitest failed"
                return 1
            fi
            test_runner_found=true
        fi
    fi
    
    if ! $test_runner_found; then
        echo "::warning::No JavaScript tests found or test runners available"
        echo "Looked for: test script in package.json, Jest, Mocha, or Vitest"
    fi
}

# Check code coverage (if tools are available)
check_coverage() {
    echo "📊 Checking code coverage..."
    
    local runtime="${RUNTIME:-}"
    local coverage_found=false
    
    case "$runtime" in
        "python")
            if command -v coverage >/dev/null 2>&1; then
                echo "Running Python coverage..."
                coverage report --show-missing || echo "::warning::Coverage report failed"
                coverage_found=true
            fi
            ;;
        "node"|"bun")
            # Check if coverage is configured in package.json
            if [[ -f "package.json" ]] && grep -q "coverage" package.json; then
                echo "Running JavaScript coverage..."
                case "$RUNTIME" in
                    "bun")
                        bun run coverage 2>/dev/null || echo "::warning::Coverage run failed"
                        ;;
                    *)
                        npm run coverage 2>/dev/null || echo "::warning::Coverage run failed"
                        ;;
                esac
                coverage_found=true
            fi
            ;;
    esac
    
    if ! $coverage_found; then
        echo "::notice::No code coverage tools configured"
    fi
}

# Security vulnerability scanning
run_security_scan() {
    echo "🔒 Running security vulnerability scan..."
    
    local runtime="${RUNTIME:-}"
    local security_found=false
    
    case "$runtime" in
        "python")
            # Check for safety (Python security scanner)
            if command -v safety >/dev/null 2>&1; then
                echo "Running safety (Python security scanner)..."
                safety check || echo "::warning::Safety scan found vulnerabilities"
                security_found=true
            fi
            
            # Check for bandit (Python security linter)
            if command -v bandit >/dev/null 2>&1; then
                echo "Running bandit (Python security linter)..."
                bandit -r . -f json -o /tmp/bandit-report.json || true
                if [[ -f "/tmp/bandit-report.json" ]]; then
                    local issue_count
                    issue_count=$(jq '.results | length' /tmp/bandit-report.json 2>/dev/null || echo "0")
                    echo "Bandit found $issue_count security issues"
                    rm -f /tmp/bandit-report.json
                fi
                security_found=true
            fi
            ;;
        "node"|"bun")
            # Check for npm audit
            if command -v npm >/dev/null 2>&1; then
                echo "Running npm audit..."
                npm audit --audit-level=moderate || echo "::warning::npm audit found vulnerabilities"
                security_found=true
            fi
            ;;
    esac
    
    if ! $security_found; then
        echo "::notice::No security scanning tools configured"
    fi
}

# Generate quality report
generate_quality_report() {
    echo "📋 Generating quality report..."
    
    local report_file="/tmp/quality-report.md"
    
    cat > "$report_file" << EOF
# Code Quality Report

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Runtime: ${RUNTIME:-unknown}

## Summary
- ✅ Linting: Completed
- ✅ Testing: Completed  
- 📊 Coverage: $(command -v coverage >/dev/null 2>&1 && echo "Available" || echo "Not configured")
- 🔒 Security: $(command -v safety >/dev/null 2>&1 || command -v npm >/dev/null 2>&1 && echo "Scanned" || echo "Not configured")

## Next Steps
Consider adding the following quality tools:

### Python
- \`flake8\` - Code linting
- \`black\` - Code formatting  
- \`pytest\` - Testing framework
- \`coverage\` - Code coverage
- \`safety\` - Security vulnerability scanner

### JavaScript/TypeScript
- \`eslint\` - Code linting
- \`prettier\` - Code formatting
- \`jest\` - Testing framework
- \`npm audit\` - Security vulnerability scanner

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
    case "${1:-all}" in
        "lint")
            run_linting
            ;;
        "test")
            run_tests
            ;;
        "coverage")
            check_coverage
            ;;
        "security")
            run_security_scan
            ;;
        "report")
            generate_quality_report
            ;;
        "all")
            run_linting
            run_tests
            check_coverage
            run_security_scan
            generate_quality_report
            ;;
        *)
            echo "Usage: $0 [lint|test|coverage|security|report|all]"
            echo "  lint     - Run code linting"
            echo "  test     - Run tests"
            echo "  coverage - Check code coverage"
            echo "  security - Run security scans"
            echo "  report   - Generate quality report"
            echo "  all      - Run all quality checks"
            exit 1
            ;;
    esac
fi