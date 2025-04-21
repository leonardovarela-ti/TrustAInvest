#!/bin/bash

# Script to apply all Terraform fixes, including ALB access logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="deployments/terraform/environments/dev"
PROJECT_NAME="trustainvest"
ENVIRONMENT="dev"

echo -e "${YELLOW}Step 1: Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &>/dev/null; then
  echo -e "${RED}AWS credentials not configured or invalid.${NC}"
  echo -e "${RED}Please configure your AWS credentials and try again.${NC}"
  exit 1
fi

echo -e "${GREEN}AWS credentials are valid.${NC}"

echo -e "${YELLOW}Step 2: Backing up current Terraform state...${NC}"
if [ -d "$TERRAFORM_DIR/.terraform" ]; then
  BACKUP_DIR="$TERRAFORM_DIR/.terraform.backup.$(date +%Y%m%d%H%M%S)"
  cp -r "$TERRAFORM_DIR/.terraform" "$BACKUP_DIR"
  echo -e "${GREEN}Terraform state backed up to $BACKUP_DIR${NC}"
fi

echo -e "${YELLOW}Step 3: Initializing Terraform...${NC}"
cd "$TERRAFORM_DIR"
terraform init

echo -e "${YELLOW}Step 4: Creating Terraform plan...${NC}"
terraform plan -out=all-fixes-plan

echo -e "${YELLOW}Step 5: Review the plan above carefully.${NC}"
echo -e "${RED}IMPORTANT: Verify that the plan will:${NC}"
echo -e "${RED}  - Create the new S3 bucket for ALB logs${NC}"
echo -e "${RED}  - Update the ALB configuration to enable access logs${NC}"
echo -e "${RED}  - Not attempt to recreate existing resources${NC}"

echo -e "${YELLOW}Do you want to apply the Terraform plan? (y/n)${NC}"
read -p "" APPLY

if [ "$APPLY" == "y" ] || [ "$APPLY" == "Y" ]; then
  echo -e "${YELLOW}Applying Terraform plan...${NC}"
  terraform apply all-fixes-plan
  echo -e "${GREEN}Terraform apply completed!${NC}"
  
  echo -e "${YELLOW}Step 6: Verifying the changes...${NC}"
  
  # Verify the S3 bucket was created
  echo -e "${YELLOW}Checking if the S3 bucket was created...${NC}"
  if aws s3 ls "s3://${PROJECT_NAME}-${ENVIRONMENT}-alb-logs" >/dev/null 2>&1; then
    echo -e "${GREEN}S3 bucket ${PROJECT_NAME}-${ENVIRONMENT}-alb-logs exists!${NC}"
  else
    echo -e "${RED}S3 bucket ${PROJECT_NAME}-${ENVIRONMENT}-alb-logs was not found!${NC}"
  fi
  
  # Verify the ALB configuration was updated
  echo -e "${YELLOW}Checking if ALB access logs were enabled...${NC}"
  ALB_ARN=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName, `'$PROJECT_NAME-$ENVIRONMENT'`)].LoadBalancerArn' \
    --output text)
  
  if [ -n "$ALB_ARN" ]; then
    LOGS_ENABLED=$(aws elbv2 describe-load-balancer-attributes \
      --load-balancer-arn "$ALB_ARN" \
      --query 'Attributes[?Key==`access_logs.s3.enabled`].Value' \
      --output text)
    LOGS_BUCKET=$(aws elbv2 describe-load-balancer-attributes \
      --load-balancer-arn "$ALB_ARN" \
      --query 'Attributes[?Key==`access_logs.s3.bucket`].Value' \
      --output text)
    
    if [ "$LOGS_ENABLED" == "true" ] && [ "$LOGS_BUCKET" == "${PROJECT_NAME}-${ENVIRONMENT}-alb-logs" ]; then
      echo -e "${GREEN}ALB access logs were enabled successfully!${NC}"
      echo -e "${GREEN}Logs will be delivered to ${PROJECT_NAME}-${ENVIRONMENT}-alb-logs${NC}"
    else
      echo -e "${RED}ALB access logs were not enabled correctly!${NC}"
      echo -e "${RED}access_logs.s3.enabled = $LOGS_ENABLED${NC}"
      echo -e "${RED}access_logs.s3.bucket = $LOGS_BUCKET${NC}"
      echo -e "${RED}You may need to run scripts/check-alb-logs-bucket-policy.sh to fix the configuration.${NC}"
    fi
  else
    echo -e "${RED}Could not find ALB with name containing $PROJECT_NAME-$ENVIRONMENT!${NC}"
  fi
  
  echo -e "${YELLOW}Step 7: Next steps${NC}"
  echo -e "${YELLOW}1. Generate some traffic to the ALB to test log delivery:${NC}"
  echo -e "${YELLOW}   ALB_DNS=\$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, \`$PROJECT_NAME-$ENVIRONMENT\`)].DNSName' --output text)${NC}"
  echo -e "${YELLOW}   for i in {1..10}; do curl -s -o /dev/null -w \"%{http_code}\\n\" http://\$ALB_DNS; done${NC}"
  echo -e "${YELLOW}2. Wait 5-10 minutes for logs to be delivered${NC}"
  echo -e "${YELLOW}3. Check the S3 bucket for logs:${NC}"
  echo -e "${YELLOW}   aws s3 ls s3://${PROJECT_NAME}-${ENVIRONMENT}-alb-logs/ --recursive${NC}"
  echo -e "${YELLOW}4. If you don't see logs after 10 minutes, run:${NC}"
  echo -e "${YELLOW}   ./scripts/check-alb-logs-bucket-policy.sh${NC}"
else
  echo -e "${YELLOW}Terraform apply skipped. You can apply the plan manually with:${NC}"
  echo -e "cd $TERRAFORM_DIR && terraform apply all-fixes-plan"
fi

echo -e "${GREEN}Script completed!${NC}"
