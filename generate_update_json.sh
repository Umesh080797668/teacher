#!/bin/bash

# Script to generate update.json with environment variables

# Load environment variables
if [ -f ".env" ]; then
    # Read .env file line by line and export variables
    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        # Remove leading/trailing whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        export "$key=$value"
    done < .env
fi

# Set default values if not set
UPDATE_VERSION=${UPDATE_VERSION:-"1.0.1"}
UPDATE_DOWNLOAD_URL=${UPDATE_DOWNLOAD_URL:-"YOUR_MEGA_DOWNLOAD_LINK_HERE"}
UPDATE_RELEASE_NOTES=${UPDATE_RELEASE_NOTES:-"• Bug fixes and performance improvements\\n• New features added\\n• UI enhancements"}
UPDATE_FORCED=${UPDATE_FORCED:-false}

# Generate update.json
cat > update.json << EOF
{
  "version": "$UPDATE_VERSION",
  "downloadUrl": "$UPDATE_DOWNLOAD_URL",
  "releaseNotes": "$UPDATE_RELEASE_NOTES",
  "isForced": $UPDATE_FORCED
}
EOF

echo "Generated update.json with environment variables"