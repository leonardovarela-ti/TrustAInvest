#!/bin/bash

# Script to apply the Terraform fixes for IAM role issues
# This script skips the policy update step and just initializes Terraform and applies the changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="deployments/terraform/environments/dev"

echo -e "${YELLOW}Step 1: Changing to the Terraform directory...${NC}"
cd "$TERRAFORM_DIR"

echo -e "${YELLOW}Step 2: Initializing Terraform to recognize the new module...${NC}"
terraform init

echo -e "${YELLOW}Step 3: Creating a Terraform plan...${NC}"
terraform plan -out=tfplan

echo -e "${YELLOW}Step 4: Applying the Terraform plan...${NC}"
echo -e "${RED}IMPORTANT: Review the plan carefully before applying!${NC}"
echo -e "${YELLOW}Do you want to apply the Terraform plan? (y/n)${NC}"
read -p "" APPLY

if [ "$APPLY" == "y" ] || [ "$APPLY" == "Y" ]; then
  echo -e "${YELLOW}Applying Terraform plan...${NC}"
  terraform apply tfplan
  echo -e "${GREEN}Terraform apply completed!${NC}"
else
  echo -e "${YELLOW}Terraform apply skipped. You can apply the plan manually with:${NC}"
  echo -e "cd $TERRAFORM_DIR && terraform apply tfplan"
fi

echo -e "${GREEN}All steps completed successfully!${NC}"
echo -e "${YELLOW}If you encounter any issues, please refer to the documentation in docs/terraform-deployment-fixes.md${NC}"
