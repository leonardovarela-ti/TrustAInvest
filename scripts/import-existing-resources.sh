#!/bin/bash

# Script to import existing resources into Terraform state
# This script will import existing ECR repositories, CloudWatch log groups, and other resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="deployments/terraform/environments/dev"
AWS_ACCOUNT_ID="982081083216"
REGION="us-east-1"
PROJECT_NAME="trustainvest"
ENVIRONMENT="dev"
NAME_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"

echo -e "${YELLOW}Changing to the Terraform directory...${NC}"
cd "$TERRAFORM_DIR"

echo -e "${YELLOW}Importing existing IAM roles...${NC}"
terraform import aws_iam_role.ecs_task_execution_new "${NAME_PREFIX}-ecs-task-execution-role-new"
terraform import aws_iam_role.ecs_task_new "${NAME_PREFIX}-ecs-task-role-new"

echo -e "${YELLOW}Importing existing IAM role policies...${NC}"
terraform import aws_iam_role_policy.ecs_task_execution_kms_new "${NAME_PREFIX}-ecs-task-execution-role-new:${NAME_PREFIX}-ecs-task-execution-kms-policy-new"
terraform import aws_iam_role_policy.ecs_task_kms_new "${NAME_PREFIX}-ecs-task-role-new:${NAME_PREFIX}-ecs-task-kms-policy-new"
terraform import aws_iam_role_policy.ecs_task_ssm_new "${NAME_PREFIX}-ecs-task-role-new:${NAME_PREFIX}-ecs-task-ssm-policy-new"
terraform import aws_iam_role_policy.ecs_task_cloudwatch_new "${NAME_PREFIX}-ecs-task-role-new:${NAME_PREFIX}-ecs-task-cloudwatch-policy-new"

echo -e "${YELLOW}Importing existing IAM role policy attachments...${NC}"
terraform import aws_iam_role_policy_attachment.ecs_task_execution_new "${NAME_PREFIX}-ecs-task-execution-role-new/arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"

echo -e "${YELLOW}Creating a Terraform plan...${NC}"
terraform plan -out=tfplan

echo -e "${YELLOW}Applying the Terraform plan...${NC}"
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
