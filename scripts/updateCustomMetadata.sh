#!/bin/bash

# Exit script on error
set -e

# Path to the XML file
XML_FILE="force-app/main/default/customMetadata/Adyen_Adapter.AdyenDefault.md-meta.xml"

# Update the XML file
xmlstarlet ed -L \
    -u '//_:values[_:field="Merchant_Account__c"]/_:value' -v "$MERCHANT_ACCOUNT" \
    -u '//_:values[_:field="HMAC_Key__c"]/_:value' -v "$HMAC_KEY" \
    "$XML_FILE"

echo "customMetadata update complete."
