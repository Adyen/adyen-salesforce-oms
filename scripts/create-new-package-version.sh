# Create the package version and capture both the result and any error
PACKAGE_CREATION_RESULT=$(sf package version create -p "Adyen Salesforce Order Management" -c -k Payments@Adyen --json)

# Extract the package version ID (if available) or handle errors
PACKAGE_VERSION_ID=$(echo "$PACKAGE_CREATION_RESULT" | yq -r '.result.Id')

# Check if the PACKAGE_VERSION_ID is null or empty
if [[ "$PACKAGE_VERSION_ID" == "null" || -z "$PACKAGE_VERSION_ID" ]]; then
  # Extract the error message from the returned JSON
  ERROR_MESSAGE=$(echo "$PACKAGE_CREATION_RESULT" | yq -r '.message')
  echo "Error: Package version creation failed. Error message: $ERROR_MESSAGE"
  # Stop the workflow with an error
  exit 1
fi

echo "Package version creation id: $PACKAGE_VERSION_ID";
MAX_ATTEMPTS=${MAX_ATTEMPTS:-30}
echo "Using MAX_ATTEMPTS: $MAX_ATTEMPTS"  # Max number of attempts (minutes) before giving up
echo

ATTEMPT=0
while true; do
  # Fetch the package version creation status and the full JSON response
  PACKAGE_CREATION_RESULT=$(sf package version create report -i "$PACKAGE_VERSION_ID" --json)
  # Print the full JSON response for debugging (optional)
  echo "Package creation result - attempt $((ATTEMPT + 1)):"
  echo "$PACKAGE_CREATION_RESULT"

  # Extract the status from the result
  STATUS=$(echo "$PACKAGE_CREATION_RESULT" | yq -r '.result[0].Status')

  if [ "$STATUS" == "Success" ]; then
    echo "Package creation completed successfully."
    break
  elif [ "$STATUS" == "Error" ]; then
    echo "Package creation failed, check the result json"
    exit 1
  else
    echo "Package creation is in progress. Current status: $STATUS"
  fi
  echo

  # Increment the attempt counter
  ATTEMPT=$((ATTEMPT + 1))

  # Check if we've reached the max attempts
  if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    echo "Package creation is taking too long. Stopping after $MAX_ATTEMPTS minutes."
    exit 1
  fi

  # Wait for a minute before checking again
  sleep 60
done
