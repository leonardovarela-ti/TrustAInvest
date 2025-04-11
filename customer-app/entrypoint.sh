#!/bin/sh
echo "{
  \"apiBaseUrl\": \"$API_BASE_URL\"
}" > /usr/share/nginx/html/assets/config/config.json
nginx -g "daemon off;"
