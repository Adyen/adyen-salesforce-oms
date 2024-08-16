#!/bin/bash

# Extract version from branch name
DESTINATION_BRANCH=$(jq -r .pull_request.base.ref < "${GITHUB_EVENT_PATH}")
echo "Destination branch: $DESTINATION_BRANCH"

# Convert the branch name to lowercase to handle case-insensitive 'release'/'Release'
DESTINATION_BRANCH_LOWER=$(echo "$DESTINATION_BRANCH" | tr '[:upper:]' '[:lower:]')

VERSION=${DESTINATION_BRANCH_LOWER#release/}

# Remove the last number from the version (e.g., 3.0.0.1 -> 3.0.0)
BRANCH_VERSION=${VERSION%.*}

# Path to the AdyenOMSConstants.cls file
APEX_FILE="force-app/main/default/classes/AdyenOMSConstants.cls"

# Read version from sfdx-project.json
PROJECT_OMS_VERSION=$(jq -r '.packageDirectories[] | select(.default == true) | .versionNumber' sfdx-project.json | sed 's/.NEXT//')
PROJECT_LIBRARY_VERSION=$(jq -r '.packageDirectories[].dependencies[]? | select(.package | startswith("API Library Apex Adyen@")) | .package' sfdx-project.json | sed -E 's/.*@([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

# Read version from AdyenOMSConstants.cls using awk for single quotes
APEX_OMS_VERSION=$(awk -F"[']" '/MERCHANT_APP_VERSION_FOR_APP_INFO/ {print $2}' "$APEX_FILE")
APEX_LIBRARY_VERSION=$(awk -F"[']" '/ADYEN_LIBRARY_VERSION_FOR_APP_INFO/ {print $2}' "$APEX_FILE")

echo "Branch Version: $BRANCH_VERSION"
echo "SFDX Project OMS Version: $PROJECT_OMS_VERSION"
echo "SFDX Project Library Version: $PROJECT_LIBRARY_VERSION"
echo "Apex Constant OMS Version: $APEX_OMS_VERSION"
echo "Apex Constant Library Version: $APEX_LIBRARY_VERSION"

# Check if BASE_VERSION matches PROJECT_OMS_VERSION
if [ "$BRANCH_VERSION" != "$PROJECT_OMS_VERSION" ]; then
  echo "Version mismatch detected between branch version and SFDX project version."
  echo "Stopping execution."
  exit 1
fi

# Flags to check if updates are needed
UPDATE_OMS=false
UPDATE_LIBRARY=false

# Update AdyenOMSConstants.cls only if needed
if [ "$BRANCH_VERSION" != "$APEX_OMS_VERSION" ]; then
  echo "Updating AdyenOMSConstants.MERCHANT_APP_VERSION_FOR_APP_INFO to version $PROJECT_OMS_VERSION"
  sed -i '' "s/\(MERCHANT_APP_VERSION_FOR_APP_INFO = '\)[^']*'/\1$PROJECT_OMS_VERSION'/" "$APEX_FILE"
  UPDATE_OMS=true
else
  echo "AdyenOMSConstants.MERCHANT_APP_VERSION_FOR_APP_INFO is already up to date."
fi
if [ "$PROJECT_LIBRARY_VERSION" != "$APEX_LIBRARY_VERSION" ]; then
  echo "Updating AdyenOMSConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO to version $PROJECT_LIBRARY_VERSION"
  sed -i '' "s/\(ADYEN_LIBRARY_VERSION_FOR_APP_INFO = '\)[^']*'/\1$PROJECT_LIBRARY_VERSION'/" "$APEX_FILE"
  UPDATE_LIBRARY=true
else
  echo "AdyenOMSConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO is already up to date."
fi

# Commit changes if any updates were made
if [ "$UPDATE_OMS" = true ] || [ "$UPDATE_LIBRARY" = true ]; then
  git config --global user.name 'GitHub Actions'
  git config --global user.email 'actions@github.com'
  git add "$APEX_FILE"
  git commit -m "chore: Update AdyenOMSConstants.cls version to $PROJECT_OMS_VERSION and library version to $PROJECT_LIBRARY_VERSION"
else
  echo "AdyenOMSConstants.cls is already up to date."
fi