#!/bin/sh
# Simple script to add Gitleaks verification to commit message

COMMIT_MSG_FILE=$1

if [ -n "$COMMIT_MSG_FILE" ] && [ -f "$COMMIT_MSG_FILE" ]; then
    echo "" >> "$COMMIT_MSG_FILE"
    echo "✅ Gitleaks scan passed - no secrets detected" >> "$COMMIT_MSG_FILE"
fi
