#!/bin/sh
set -e

# Generate the config.json file with the API_BASE_URL
echo "Generating config.json with API_BASE_URL: $API_BASE_URL"
cat > /usr/share/nginx/html/assets/config/config.json << EOF
{
  "apiBaseUrl": "${API_BASE_URL:-http://user-registration-service:8080}",
  "environment": "production"
}
EOF

# Start nginx
exec nginx -g "daemon off;"
