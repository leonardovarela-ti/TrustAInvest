#!/bin/bash
set -e

echo "Rebuilding and restarting KYC verifier service..."

# Navigate to the project root directory
cd "$(dirname "$0")/.."

# Build the KYC verifier service
echo "Building KYC verifier service..."
docker build -t trustainvest/kyc-verifier-service:latest -f cmd/kyc-verifier-service/Dockerfile .

# Stop and remove the existing container if it's running
echo "Stopping existing KYC verifier service container..."
docker-compose stop kyc-verifier-service || true
docker-compose rm -f kyc-verifier-service || true

# Start the service with the new image
echo "Starting KYC verifier service with updated code..."
docker-compose up -d kyc-verifier-service

echo "KYC verifier service has been rebuilt and restarted."
