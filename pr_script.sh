#!/bin/bash

# Get arguments
PR_NUMBER="$1"
PR_TITLE="$2"
PR_URL="$3"

# Log the pull request information
echo "New pull request received!"
echo "PR Number: $PR_NUMBER"
echo "PR Title: $PR_TITLE"
echo "PR URL: $PR_URL"

# Add your custom logic here
# For example, you could:
# - Run tests
# - Build the project
# - Deploy to staging
# - Send notifications

# Log completion
echo "Pull request processing completed!"

# Exit successfully
exit 0 