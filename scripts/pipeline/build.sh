#!/bin/bash
# Generic Build Script Template
# Called by async-state-machine.yml
# Arguments: $1=event_name, $2=git_ref

set -euo pipefail

EVENT_NAME="${1:-push}"
GIT_REF="${2:-refs/heads/main}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔨 Starting build process..."
echo "  Event: $EVENT_NAME"
echo "  Ref: $GIT_REF"
echo "  Working Dir: $(pwd)"

# =================================
# ESCAPE MECHANISM
# =================================
setup_escape_handler() {
    local escape_file="/tmp/build-escape-$$"
    
    # Set up signal handlers for graceful escape
    trap 'echo "⚠️  Build escape triggered"; touch "$escape_file"; exit 42' TERM
    trap 'echo "🛑 Build interrupted"; touch "$escape_file"; exit 130' INT
    
    # Background process to check for escape conditions
    (
        while [[ ! -f "$escape_file" ]]; do
            # Check system resources, external dependencies, etc.
            if ! check_build_prerequisites; then
                echo "❌ Build prerequisites failed - triggering escape"
                touch "$escape_file"
                kill -TERM $$
            fi
            sleep 5
        done
    ) &
    
    ESCAPE_PID=$!
}

check_build_prerequisites() {
    # Check disk space
    if [[ $(df . | tail -1 | awk '{print $5}' | sed 's/%//') -gt 90 ]]; then
        echo "❌ Insufficient disk space"
        return 1
    fi
    
    # Check memory
    if [[ $(free | grep '^Mem:' | awk '{print ($3/$2)*100}' | cut -d. -f1) -gt 90 ]]; then
        echo "❌ Insufficient memory"
        return 1
    fi
    
    return 0
}

# =================================
# BUSINESS LOGIC (CUSTOMIZABLE)
# =================================
execute_build() {
    echo "📦 Detecting project type..."
    
    # Maven project
    if [[ -f "pom.xml" ]]; then
        echo "☕ Maven project detected"
        if ! timeout 240s mvn clean install -DskipTests=false; then
            echo "❌ Maven build failed or timed out"
            return 1
        fi
        
    # Gradle project  
    elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
        echo "🐘 Gradle project detected"
        if ! timeout 240s ./gradlew build; then
            echo "❌ Gradle build failed or timed out"
            return 1
        fi
        
    # Node.js project
    elif [[ -f "package.json" ]]; then
        echo "📦 Node.js project detected"
        if ! timeout 180s npm ci && timeout 300s npm run build; then
            echo "❌ Node.js build failed or timed out"
            return 1
        fi
        
    # Go project
    elif [[ -f "go.mod" ]]; then
        echo "🐹 Go project detected"
        if ! timeout 180s go build ./...; then
            echo "❌ Go build failed or timed out"
            return 1
        fi
        
    # Generic fallback
    else
        echo "❓ Unknown project type - executing custom build logic"
        # Source custom build logic if exists
        if [[ -f "${SCRIPT_DIR}/custom-build.sh" ]]; then
            source "${SCRIPT_DIR}/custom-build.sh"
        else
            echo "⚠️  No custom build script found - build passed by default"
        fi
    fi
    
    echo "✅ Build completed successfully"
    return 0
}

# =================================
# CALLBACK MECHANISM
# =================================
register_build_callback() {
    local callback_type="$1"
    local callback_data="$2"
    
    local callback_file="/tmp/build-callbacks-$$"
    echo "$(date -Iseconds)|$callback_type|$callback_data" >> "$callback_file"
}

execute_build_callbacks() {
    local callback_file="/tmp/build-callbacks-$$"
    
    if [[ -f "$callback_file" ]]; then
        echo "🔄 Executing build callbacks..."
        while IFS='|' read -r timestamp callback_type callback_data; do
            case "$callback_type" in
                "artifact")
                    echo "📁 Archiving artifact: $callback_data"
                    # Archive build artifacts
                    ;;
                "notification")
                    echo "📢 Sending notification: $callback_data"
                    # Send notifications
                    ;;
                "cleanup")
                    echo "🧹 Cleaning up: $callback_data"
                    # Cleanup temporary resources
                    ;;
                *)
                    echo "❓ Unknown callback type: $callback_type"
                    ;;
            esac
        done < "$callback_file"
    fi
}

# =================================
# MAIN EXECUTION
# =================================
main() {
    setup_escape_handler
    
    # Execute the actual build
    if execute_build; then
        register_build_callback "artifact" "target/"
        register_build_callback "notification" "build-success"
        echo "🎉 Build stage completed successfully"
        execute_build_callbacks
        
        # Cleanup escape handler
        [[ -n "${ESCAPE_PID:-}" ]] && kill $ESCAPE_PID 2>/dev/null || true
        
        return 0
    else
        register_build_callback "notification" "build-failed"
        echo "💥 Build stage failed"
        execute_build_callbacks
        
        # Cleanup escape handler
        [[ -n "${ESCAPE_PID:-}" ]] && kill $ESCAPE_PID 2>/dev/null || true
        
        return 1
    fi
}

# Execute main function
main "$@"