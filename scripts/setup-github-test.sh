#!/bin/bash
# Setup script for GitHub Async Feedback Loop Test
# Ensures all required files and dependencies are in place

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🛠️  GitHub Async Test Setup"
echo "==========================="
echo "Preparing for GitHub Actions async feedback loop test..."
echo ""

# Check project structure
check_project_structure() {
    echo "📁 Checking project structure..."
    
    local required_dirs=(
        ".github"
        ".github/workflows"
        "scripts"
        "scripts/pubsub"
    )
    
    local required_files=(
        ".github/workflows/async-producer.yml"
        ".github/workflows/async-consumer.yml"
        ".github/workflows/test-async-feedback-loop.yml"
        "scripts/pubsub/publisher.sh"
        "scripts/pubsub/math-subscriber.js"
        "scripts/pubsub/completion-monitor.sh"
        "scripts/pubsub/output-query-api.sh"
        "scripts/pubsub/output-streamer.sh"
    )
    
    cd "$PROJECT_ROOT"
    
    # Check directories
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "✅ Directory: $dir"
        else
            echo "❌ Missing directory: $dir"
            mkdir -p "$dir"
            echo "✅ Created: $dir"
        fi
    done
    
    echo ""
    
    # Check files
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "✅ File: $file"
        else
            echo "❌ Missing: $file"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️  Missing files detected. Please ensure all workflow and script files are created."
        echo "   Run the main setup commands to create missing files."
        return 1
    fi
    
    echo "✅ All required files present"
    return 0
}

# Check tool dependencies
check_dependencies() {
    echo "🔧 Checking tool dependencies..."
    
    local tools=(
        "git:Git version control"
        "gh:GitHub CLI"
        "node:Node.js runtime"
        "jq:JSON processor"
        "curl:HTTP client"
    )
    
    local missing_tools=()
    
    for tool_info in "${tools[@]}"; do
        local tool=$(echo "$tool_info" | cut -d: -f1)
        local desc=$(echo "$tool_info" | cut -d: -f2)
        
        if command -v "$tool" >/dev/null; then
            echo "✅ $desc: $(command -v "$tool")"
        else
            echo "❌ Missing: $desc ($tool)"
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo ""
        echo "⚠️  Missing tools detected. Install commands:"
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "git")
                    echo "   sudo apt-get install git"
                    ;;
                "gh")
                    echo "   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
                    echo "   echo 'deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list"
                    echo "   sudo apt update && sudo apt install gh"
                    ;;
                "node")
                    echo "   curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
                    echo "   sudo apt-get install -y nodejs"
                    ;;
                "jq")
                    echo "   sudo apt-get install jq"
                    ;;
                "curl")
                    echo "   sudo apt-get install curl"
                    ;;
            esac
        done
        return 1
    fi
    
    echo "✅ All required tools available"
    return 0
}

# Check GitHub authentication
check_github_auth() {
    echo "🔐 Checking GitHub authentication..."
    
    if ! command -v gh >/dev/null; then
        echo "❌ GitHub CLI not available"
        return 1
    fi
    
    if gh auth status >/dev/null 2>&1; then
        local user=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        echo "✅ GitHub CLI authenticated as: $user"
        
        # Check repository access
        if gh repo view >/dev/null 2>&1; then
            local repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
            echo "✅ Repository access confirmed: $repo"
        else
            echo "⚠️  Repository access check failed"
            echo "   Make sure you're in a GitHub repository directory"
        fi
    else
        echo "❌ GitHub CLI not authenticated"
        echo "   Run: gh auth login"
        return 1
    fi
    
    return 0
}

# Setup Node.js dependencies
setup_node_deps() {
    echo "📦 Setting up Node.js dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Create package.json if it doesn't exist
    if [[ ! -f "package.json" ]]; then
        echo "📝 Creating package.json..."
        cat > package.json << 'EOF'
{
  "name": "oracle-fusion-async-pipeline",
  "version": "1.0.0",
  "description": "Async pipeline system for Oracle Fusion authentication",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["async", "pipeline", "github-actions"],
  "author": "Oracle Fusion Team",
  "license": "MIT"
}
EOF
        echo "✅ package.json created"
    else
        echo "✅ package.json exists"
    fi
    
    return 0
}

# Make scripts executable
fix_permissions() {
    echo "🔑 Fixing script permissions..."
    
    cd "$PROJECT_ROOT"
    
    # Make all shell scripts executable
    find scripts -name "*.sh" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    # Specific important scripts
    local important_scripts=(
        "scripts/test-github-async-cycle.sh"
        "scripts/demo-async-feedback-loop.sh"
        "scripts/pubsub/publisher.sh"
        "scripts/pubsub/completion-monitor.sh"
        "scripts/pubsub/output-query-api.sh"
        "scripts/pubsub/output-streamer.sh"
        "scripts/pubsub/test-runner.sh"
    )
    
    for script in "${important_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            echo "✅ Made executable: $script"
        fi
    done
    
    return 0
}

# Create temp directories
setup_temp_dirs() {
    echo "📂 Setting up temporary directories..."
    
    local temp_dirs=(
        "/tmp/pipeline-messages"
        "/tmp/archived-results"
    )
    
    for dir in "${temp_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            echo "✅ Created: $dir"
        else
            echo "✅ Exists: $dir"
        fi
    done
    
    return 0
}

# Show setup summary
show_summary() {
    echo ""
    echo "📋 Setup Summary"
    echo "================"
    echo ""
    echo "🎯 Ready to test GitHub async feedback loop!"
    echo ""
    echo "📤 Next steps:"
    echo "  1. Run the GitHub test: ./scripts/test-github-async-cycle.sh"
    echo "  2. Or run local demo: ./scripts/demo-async-feedback-loop.sh"
    echo ""
    echo "🌐 GitHub Actions workflows will be created in:"
    echo "  - .github/workflows/async-producer.yml"
    echo "  - .github/workflows/async-consumer.yml"
    echo "  - .github/workflows/test-async-feedback-loop.yml"
    echo ""
    echo "🎪 The complete async feedback loop system is ready for testing!"
}

# Main setup function
main() {
    echo "🚀 Starting setup..."
    echo ""
    
    local setup_success=true
    
    # Run setup steps
    if ! check_project_structure; then
        echo "❌ Project structure check failed"
        setup_success=false
    fi
    
    echo ""
    
    if ! check_dependencies; then
        echo "❌ Dependencies check failed"
        setup_success=false
    fi
    
    echo ""
    
    if ! check_github_auth; then
        echo "❌ GitHub authentication check failed"
        setup_success=false
    fi
    
    echo ""
    
    if setup_node_deps; then
        echo "✅ Node.js dependencies setup complete"
    else
        echo "⚠️  Node.js dependencies setup had issues"
    fi
    
    echo ""
    
    if fix_permissions; then
        echo "✅ Script permissions fixed"
    else
        echo "⚠️  Script permissions fix had issues"
    fi
    
    echo ""
    
    if setup_temp_dirs; then
        echo "✅ Temporary directories ready"
    else
        echo "⚠️  Temporary directories setup had issues"
    fi
    
    echo ""
    
    # Show results
    if [[ "$setup_success" == "true" ]]; then
        echo "🎉 Setup completed successfully!"
        show_summary
        
        echo ""
        echo "🚀 Ready to run: ./scripts/test-github-async-cycle.sh"
        
        # Ask if user wants to run the test now
        read -p "Would you like to run the GitHub async cycle test now? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🎪 Starting GitHub async cycle test..."
            exec "$SCRIPT_DIR/test-github-async-cycle.sh"
        else
            echo "ℹ️  Run the test manually when ready: ./scripts/test-github-async-cycle.sh"
        fi
        
    else
        echo "⚠️  Setup completed with issues"
        echo "   Please resolve the issues above before running tests"
        exit 1
    fi
}

# Execute main
main "$@"