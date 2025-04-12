#!/bin/bash
set -e

echo "Building Flutter web app for TrustAInvest customer-app..."

# Ensure Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Ensure we're in the customer-app directory
cd "$(dirname "$0")"

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build for web
echo "Building for web..."
flutter build web --release

echo "Web build completed successfully!"
echo "The build is available in: $(pwd)/build/web"

# Create a config.json file for local development
echo "Creating config.json for local development..."
mkdir -p build/web/assets/config
echo "{
  \"apiBaseUrl\": \"http://localhost:8086\"
}" > build/web/assets/config/config.json

echo "Local config.json created with API_BASE_URL=http://localhost:8086"
echo "When running in Docker, the API_BASE_URL will be set to http://user-registration-service:8080"

echo "Build process completed successfully!"
