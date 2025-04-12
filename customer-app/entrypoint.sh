#!/bin/sh
set -e

# Create config directory if it doesn't exist
mkdir -p /usr/share/nginx/html/assets/config

# Generate the config.json file with the API_BASE_URL
echo "Generating config.json with API_BASE_URL: $API_BASE_URL"
echo "{
  \"apiBaseUrl\": \"$API_BASE_URL\"
}" > /usr/share/nginx/html/assets/config/config.json

# Verify the config file was created
ls -la /usr/share/nginx/html/assets/config/

# Start nginx in foreground
echo "Starting nginx..."
nginx -g "daemon off;"
