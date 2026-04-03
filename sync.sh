#!/usr/bin/env bash
# sync.sh — commit and push all changes in ~/Xcode/SASS

set -euo pipefail

REPO="$HOME/Xcode/SASS"
cd "$REPO"

# Check for any changes at all
if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
    echo "Nothing to sync — working tree is clean."
    exit 0
fi

# Show what's changing
git status --short

# Prompt for commit message
echo ""
read -rp "Commit message: " msg
if [ -z "$msg" ]; then
    echo "Aborted — commit message cannot be empty."
    exit 1
fi

git add .
git commit -m "$msg"
git push

echo ""
echo "Synced to GitHub."
