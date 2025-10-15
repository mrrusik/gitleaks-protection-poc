#!/bin/bash
# Gitleaks Execution Tracker
# This script runs as a prepare-commit-msg hook to mark successful Gitleaks execution

set -e

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"
SHA1="$3"

# Configuration
TRACKER_FILE=".gitleaks-tracker"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null || echo "new-commit")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
USER_EMAIL=$(git config user.email 2>/dev/null || echo "unknown")

# Create tracking metadata
create_tracking_metadata() {
    cat > "$TRACKER_FILE" << EOF
{
  "gitleaks_execution": {
    "timestamp": "$TIMESTAMP",
    "commit_hash": "$COMMIT_HASH",
    "branch": "$BRANCH", 
    "user_email": "$USER_EMAIL",
    "pre_commit_version": "$(pre-commit --version 2>/dev/null || echo 'unknown')",
    "gitleaks_version": "$(gitleaks version 2>/dev/null | head -1 || echo 'unknown')",
    "scan_status": "completed",
    "tracking_version": "1.0"
  }
}
EOF
}

# Add tracking signature to commit message
add_tracking_signature() {
    if [ -f "$COMMIT_MSG_FILE" ]; then
        # Don't add signature if it's already there or if it's a merge/rebase commit
        if ! grep -q "gitleaks-scan-executed" "$COMMIT_MSG_FILE" && [ "$COMMIT_SOURCE" != "merge" ] && [ "$COMMIT_SOURCE" != "squash" ]; then
            echo "" >> "$COMMIT_MSG_FILE"
            echo "<!-- gitleaks-scan-executed: $TIMESTAMP -->" >> "$COMMIT_MSG_FILE"
            echo "Signed-off-by: Gitleaks-Scanner <gitleaks@security.local>" >> "$COMMIT_MSG_FILE"
        fi
    fi
}

# Main execution
main() {
    echo "🔍 Tracking Gitleaks execution..."
    
    # Check if Gitleaks actually ran (look for report file)
    if [ -f ".gitleaks-report.json" ]; then
        echo "✅ Gitleaks report found - scan completed successfully"
        
        # Create tracking metadata
        create_tracking_metadata
        
        # Add tracking signature to commit message
        add_tracking_signature
        
        # Stage the tracker file
        git add "$TRACKER_FILE" 2>/dev/null || true
        
        echo "📝 Gitleaks execution tracked successfully"
    else
        echo "⚠️  No Gitleaks report found - scan may have been skipped"
        
        # Still create tracker but mark as potentially skipped
        cat > "$TRACKER_FILE" << EOF
{
  "gitleaks_execution": {
    "timestamp": "$TIMESTAMP",
    "commit_hash": "$COMMIT_HASH",
    "branch": "$BRANCH",
    "user_email": "$USER_EMAIL", 
    "scan_status": "possibly_skipped",
    "tracking_version": "1.0",
    "warning": "No gitleaks report found"
  }
}
EOF
        git add "$TRACKER_FILE" 2>/dev/null || true
    fi
    
    # Clean up report file (don't commit it)
    rm -f ".gitleaks-report.json"
}

# Run main function
main "$@"
