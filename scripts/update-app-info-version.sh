#!/bin/bash
# Simulate the GitHub environment variable
#export GITHUB_HEAD_REF="refs/heads/release/3.0.1"

# Source branch name (release/#.#.#)
BRANCH_NAME=${GITHUB_HEAD_REF##*/}
# Extract version from the branch name (e.g., release/3.0.0 -> 3.0.0)
BRANCH_VERSION=${BRANCH_NAME#release/}

# Path to the AdyenOMSConstants.cls file
APEX_FILE="force-app/main/default/classes/AdyenOMSConstants.cls"

# Read version from sfdx-project.json
PROJECT_OMS_VERSION=$(yq -r '.packageDirectories[] | select(.default == true) | .versionNumber' sfdx-project.json | sed 's/.NEXT//')
PROJECT_LIBRARY_VERSION=$(yq -r '.packageDirectories[].dependencies[]? | select(.package | test("API Library Apex Adyen@")) | .package' sfdx-project.json | sed -E 's/.*@([0-9]+\.[0-9]+\.[0-9]+).*/\1/')

# Read version from AdyenOMSConstants.cls using awk for single quotes
APEX_OMS_VERSION=$(awk -F"[']" '/MERCHANT_APP_VERSION_FOR_APP_INFO/ {print $2}' "$APEX_FILE")
APEX_LIBRARY_VERSION=$(awk -F"[']" '/ADYEN_LIBRARY_VERSION_FOR_APP_INFO/ {print $2}' "$APEX_FILE")

# Print the branch name
echo "Branch: $BRANCH_NAME"

# Print the headers for better comparison
printf "%-25s %-25s\n" "sfdx-project.json VERSION" "AdyenOMSConstants VERSION"
printf "%-25s %-25s\n" "-------------------------" "-------------------------"

# Print the OMS and Library versions in a pretty format
printf "%-25s %-25s\n" "$PROJECT_OMS_VERSION (OMS)" "$APEX_OMS_VERSION (OMS)"
printf "%-25s %-25s\n" "$PROJECT_LIBRARY_VERSION (Library)" "$APEX_LIBRARY_VERSION (Library)"

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
  sed -i "s/\(MERCHANT_APP_VERSION_FOR_APP_INFO = '\)[^']*'/\1$PROJECT_OMS_VERSION'/" "$APEX_FILE"
  UPDATE_OMS=true
else
  echo "AdyenOMSConstants.MERCHANT_APP_VERSION_FOR_APP_INFO is already up to date."
fi
if [ "$PROJECT_LIBRARY_VERSION" != "$APEX_LIBRARY_VERSION" ]; then
  echo "Updating AdyenOMSConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO to version $PROJECT_LIBRARY_VERSION"
  sed -i "s/\(ADYEN_LIBRARY_VERSION_FOR_APP_INFO = '\)[^']*'/\1$PROJECT_LIBRARY_VERSION'/" "$APEX_FILE"
  UPDATE_LIBRARY=true
else
  echo "AdyenOMSConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO is already up to date."
fi