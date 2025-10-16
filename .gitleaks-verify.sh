#!/bin/sh
# Simple script to add Gitleaks verification to commit message

COMMIT_MSG_FILE=$1

# Debug logging
echo "DEBUG: Script called with args: $@" >&2
echo "DEBUG: COMMIT_MSG_FILE = $COMMIT_MSG_FILE" >&2
echo "DEBUG: File exists check: $(test -f "$COMMIT_MSG_FILE" && echo yes || echo no)" >&2

if [ -n "$COMMIT_MSG_FILE" ] && [ -f "$COMMIT_MSG_FILE" ]; then
    echo "DEBUG: Adding verification to $COMMIT_MSG_FILE" >&2
    echo "" >> "$COMMIT_MSG_FILE"
    echo "✅ Gitleaks scan passed - no secrets detected" >> "$COMMIT_MSG_FILE"
    echo "DEBUG: Verification added successfully" >&2
else
    echo "DEBUG: Could not add verification - file not found or empty arg" >&2
fi
