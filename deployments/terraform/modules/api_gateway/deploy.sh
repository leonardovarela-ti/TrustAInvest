#!/bin/bash
# API Gateway deployment script for TrustAInvest.com

set -e

# Set environment variables
ENV=${1:-dev}
REGION=${2:-us-east-1}
PROFILE=${3:-default}

echo "Deploying API Gateway for TrustAInvest.com to $ENV environment in $REGION region..."

# Navigate to the terraform directory
cd ../../../deployments/terraform/$ENV

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan the deployment
echo "Planning deployment..."
terraform plan -target=module.api_gateway -out=api-gateway.tfplan

# Confirm before applying
read -p "Do you want to apply these changes? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Apply the changes
    echo "Applying changes..."
    terraform apply api-gateway.tfplan

    # Verify deployment
    echo "Verifying deployment..."
    API_URL=$(terraform output -raw api_gateway_url)
    echo "API Gateway URL: $API_URL"
    
    # Test API endpoint
    echo "Testing API health endpoint..."
    curl -s -o /dev/null -w "%{http_code}" "$API_URL/health" || echo "API health check failed"
    
    echo "Deployment complete!"
else
    echo "Deployment cancelled."
fi

# Clean up plan file
rm -f api-gateway.tfplan