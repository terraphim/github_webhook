#!/bin/bash

# Get arguments
PR_NUMBER="$1"
PR_TITLE="$2"
PR_URL="$3"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
export PATH=$PATH:$HOME/.local/bin
# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it first:"
    echo "For Linux:"
    echo "  ./gh_install.sh"
    echo "For macOS:"
    echo "  brew install gh"
    exit 1
fi

# If GITHUB_TOKEN is not set, try to get it from gh
if [ -z "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN=$(gh auth token)
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "Error: Could not get GitHub token. Please either:"
        echo "1. Set GITHUB_TOKEN environment variable"
        echo "2. Run 'gh auth login' to authenticate GitHub CLI"
        exit 1
    fi
fi

# Export token for gh to use
export GITHUB_TOKEN

# Log the pull request information
echo "New pull request received!"
echo "PR Number: $PR_NUMBER"
echo "PR Title: $PR_TITLE"
echo "PR URL: $PR_URL"

# Write PR information to a file
LOG_FILE="pr_details.log"
echo "=== Pull Request Details ===" > "$LOG_FILE"
echo "Timestamp: $(date)" >> "$LOG_FILE"
echo "PR Number: $PR_NUMBER" >> "$LOG_FILE"
echo "PR Title: $PR_TITLE" >> "$LOG_FILE"
echo "PR URL: $PR_URL" >> "$LOG_FILE"

# Log that we wrote to the file
echo "PR details written to $LOG_FILE"

# Extract repository information from PR_URL
# Expected format: https://github.com/owner/repo/pull/number
REPO_OWNER_AND_NAME=$(echo "$PR_URL" | sed -E 's|https://github.com/||' | sed -E 's|/pull/.*||')
echo "Repository: $REPO_OWNER_AND_NAME"
# Get PR branch name using GitHub CLI
PR_BRANCH=$(gh pr view "$PR_NUMBER" --repo "$REPO_OWNER_AND_NAME" --json headRefName --jq .headRefName)
if [ -z "$PR_BRANCH" ]; then
    echo "Error: Could not determine PR branch name"
    exit 1
fi
echo "PR Branch: $PR_BRANCH"
echo "PR Branch: $PR_BRANCH" >> "$LOG_FILE"
echo "===========================" >> "$LOG_FILE"


# Create a temporary directory for checkout
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"

# Clone the repository first, then checkout PR
echo "Cloning repository and checking out PR #$PR_NUMBER..."
cd "$TEMP_DIR"
gh repo clone "$REPO_OWNER_AND_NAME" .
if [ $? -ne 0 ]; then
    echo "Failed to clone repository"
    cd -
    rm -rf "$TEMP_DIR"
    exit 1
fi

gh pr checkout "$PR_NUMBER"
if [ $? -ne 0 ]; then
    echo "Failed to checkout PR"
    cd -
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Run make command
echo "Running make command with branch: $PR_BRANCH..."
if ! make deploy-pr PR_BRANCH="$PR_BRANCH"; then
    echo "Make command failed!"
    cd -
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up
echo "Cleaning up temporary directory..."
cd -
rm -rf "$TEMP_DIR"

# Log completion
echo "Pull request processing completed!"

# Exit successfully
exit 0 
