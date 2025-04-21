#!/bin/bash

# Script to import existing IAM roles into Terraform state
# This script helps resolve the issue where Terraform tries to create roles that already exist

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="dev"
PROJECT_NAME="trustainvest"
TERRAFORM_DIR="deployments/terraform/environments/${ENVIRONMENT}"

# Role names
TASK_EXECUTION_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-task-execution-role"
TASK_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-task-role"

echo -e "${YELLOW}Checking if roles exist in AWS...${NC}"

# Check if the roles exist in AWS
TASK_EXECUTION_ROLE_EXISTS=$(aws iam get-role --role-name "$TASK_EXECUTION_ROLE" 2>/dev/null && echo "true" || echo "false")
TASK_ROLE_EXISTS=$(aws iam get-role --role-name "$TASK_ROLE" 2>/dev/null && echo "true" || echo "false")

if [ "$TASK_EXECUTION_ROLE_EXISTS" == "false" ] && [ "$TASK_ROLE_EXISTS" == "false" ]; then
    echo -e "${RED}Error: Neither role exists in AWS. This script is only needed when roles already exist.${NC}"
    exit 1
fi

# Change to the Terraform directory
cd "$TERRAFORM_DIR"

echo -e "${YELLOW}Importing existing IAM roles into Terraform state...${NC}"

# Import the task execution role if it exists
if [ "$TASK_EXECUTION_ROLE_EXISTS" == "true" ]; then
    echo -e "${YELLOW}Importing task execution role: $TASK_EXECUTION_ROLE${NC}"
    terraform import module.container_override.aws_iam_role.ecs_task_execution "$TASK_EXECUTION_ROLE" || {
        echo -e "${RED}Failed to import task execution role. Make sure Terraform is initialized and the module path is correct.${NC}"
        exit 1
    }
    echo -e "${GREEN}Successfully imported task execution role.${NC}"
fi

# Import the task role if it exists
if [ "$TASK_ROLE_EXISTS" == "true" ]; then
    echo -e "${YELLOW}Importing task role: $TASK_ROLE${NC}"
    terraform import module.container_override.aws_iam_role.ecs_task "$TASK_ROLE" || {
        echo -e "${RED}Failed to import task role. Make sure Terraform is initialized and the module path is correct.${NC}"
        exit 1
    }
    echo -e "${GREEN}Successfully imported task role.${NC}"
fi

echo -e "${GREEN}Import completed successfully.${NC}"
echo -e "${YELLOW}You can now run terraform plan and terraform apply to continue with your deployment.${NC}"
