#!/bin/bash
set -e

echo "Rebuilding and restarting user-registration service for integration tests..."

# Navigate to the project root directory
cd "$(dirname "$0")/.."

# Build the user-registration service using the test Dockerfile
echo "Building user-registration service for tests..."
docker build -t trustainvest/user-registration-service:test -f ./Dockerfile.registration .

# Stop and remove the existing test container if it's running
echo "Stopping existing user-registration service test container..."
docker-compose -f test/docker-compose.test.yml stop user-registration-service || true
docker-compose -f test/docker-compose.test.yml rm -f user-registration-service || true

# Start the service with the new image
echo "Starting user-registration service with updated code for tests..."
docker-compose -f test/docker-compose.test.yml up -d user-registration-service

echo "User registration service has been rebuilt and restarted for integration tests."
