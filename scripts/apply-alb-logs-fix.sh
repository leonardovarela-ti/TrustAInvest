#!/bin/bash

# Script to apply the ALB logs fix using the dedicated S3 bucket with existing resources approach
# This script automates the process described in docs/applying-alb-logs-changes.md

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="deployments/terraform/environments/dev"
ALB_LOGS_FILE="$TERRAFORM_DIR/alb_logs_with_existing_resources.tf"
MAIN_TF_FILE="$TERRAFORM_DIR/main.tf"
PROJECT_NAME="trustainvest"
ENVIRONMENT="dev"
ALB_LOGS_BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb-logs"

echo -e "${YELLOW}Step 1: Preparing the Terraform files...${NC}"

# Function to uncomment a line in a file
uncomment_line() {
  local file=$1
  local pattern=$2
  sed -i '' "s/# \($pattern\)/\1/" "$file"
}

# Function to remove a line in a file
remove_line() {
  local file=$1
  local pattern=$2
  sed -i '' "/$pattern/d" "$file"
}

# Check for conflicts with other ALB logs approaches and handle them
for CONFLICT_FILE in "$TERRAFORM_DIR/alb_logs_fix.tf" "$TERRAFORM_DIR/alb_logs_fix_alternative.tf" "$TERRAFORM_DIR/alb_logs_cloudwatch_alternative.tf"; do
  if [ -f "$CONFLICT_FILE" ] && [ "$CONFLICT_FILE" != "$ALB_LOGS_FILE" ]; then
    echo -e "${YELLOW}Detected potential resource name conflict with $CONFLICT_FILE${NC}"
    echo -e "${YELLOW}Renaming $CONFLICT_FILE to ${CONFLICT_FILE}.bak to avoid conflicts${NC}"
    mv "$CONFLICT_FILE" "${CONFLICT_FILE}.bak"
  fi
done

# Uncomment the S3 bucket resources and remove placeholder values
echo -e "${YELLOW}Updating $ALB_LOGS_FILE...${NC}"

# Create a temporary file for the updated content
TMP_ALB_LOGS_FILE=$(mktemp)

# Process the file to update all bucket references and remove count = 0
awk -v bucket_name="aws_s3_bucket.alb_logs.id" '
/^  # This is a placeholder resource and should not be applied as-is$/ {
  skip_next = 1
  next
}
/^  count = 0$/ {
  if (skip_next) {
    skip_next = 0
    next
  }
}
/^  # bucket = aws_s3_bucket.alb_logs.id$/ {
  print "  bucket = " bucket_name
  next
}
/^  bucket = "placeholder-alb-logs-bucket"$/ {
  print "  bucket = " bucket_name
  next
}
/^# / {
  if ($0 ~ /^# depends_on/) {
    gsub(/^# /, "")
  }
  print
  next
}
{
  print
}
' "$ALB_LOGS_FILE" > "$TMP_ALB_LOGS_FILE"

# Replace the original file with the updated content
mv "$TMP_ALB_LOGS_FILE" "$ALB_LOGS_FILE"

# Also update the S3 bucket resource to use the correct name
TMP_ALB_LOGS_FILE=$(mktemp)
awk -v bucket_var="\${var.project_name}-\${var.environment}-alb-logs" '
/^  # bucket = "\${var.project_name}-\${var.environment}-alb-logs"$/ {
  print "  bucket = \"" bucket_var "\""
  next
}
/^  bucket = "placeholder-alb-logs-bucket"$/ {
  print "  bucket = \"" bucket_var "\""
  next
}
{
  print
}
' "$ALB_LOGS_FILE" > "$TMP_ALB_LOGS_FILE"

# Replace the original file with the updated content
mv "$TMP_ALB_LOGS_FILE" "$ALB_LOGS_FILE"

echo -e "${GREEN}Successfully updated $ALB_LOGS_FILE${NC}"

# Create a backup of the main.tf file
cp "$MAIN_TF_FILE" "${MAIN_TF_FILE}.bak"
echo -e "${YELLOW}Created backup of $MAIN_TF_FILE at ${MAIN_TF_FILE}.bak${NC}"

# Update the container_with_existing_roles module in main.tf
echo -e "${YELLOW}Updating $MAIN_TF_FILE to enable ALB access logs...${NC}"

# Instead of trying to find the exact position, let's use a simpler approach
# Create a temporary file with the updated content
TMP_FILE=$(mktemp)

# Add the ALB logs configuration to the container_with_existing_roles module
awk -v bucket="$ALB_LOGS_BUCKET_NAME" '
/module "container_with_existing_roles"/ {
  in_module = 1
}
/^}/ {
  if (in_module) {
    print "  # Enable ALB access logs with the dedicated bucket"
    print "  alb_access_logs_enabled = true"
    print "  logs_bucket_name = \"" bucket "\""
    print "  alb_access_logs_prefix = \"\""
    in_module = 0
  }
  print
  next
}
{ print }
' "$MAIN_TF_FILE" > "$TMP_FILE"

# Replace the original file with the updated content
mv "$TMP_FILE" "$MAIN_TF_FILE"

echo -e "${GREEN}Successfully updated $MAIN_TF_FILE${NC}"

echo -e "${YELLOW}Step 2: Initializing Terraform...${NC}"
cd "$TERRAFORM_DIR"
terraform init

echo -e "${YELLOW}Step 3: Creating Terraform plan...${NC}"
terraform plan -out=alb-logs-plan

echo -e "${YELLOW}Step 4: Review the plan above carefully.${NC}"
echo -e "${RED}IMPORTANT: Verify that the plan will:${NC}"
echo -e "${RED}  - Create the new S3 bucket for ALB logs${NC}"
echo -e "${RED}  - Update the ALB configuration to enable access logs${NC}"
echo -e "${RED}  - Not attempt to recreate existing resources${NC}"

echo -e "${YELLOW}Do you want to apply the Terraform plan? (y/n)${NC}"
read -p "" APPLY

if [ "$APPLY" == "y" ] || [ "$APPLY" == "Y" ]; then
  echo -e "${YELLOW}Applying Terraform plan...${NC}"
  terraform apply alb-logs-plan
  echo -e "${GREEN}Terraform apply completed!${NC}"
  
  echo -e "${YELLOW}Step 5: Verifying the changes...${NC}"
  
  # Verify the S3 bucket was created
  echo -e "${YELLOW}Checking if the S3 bucket was created...${NC}"
  if aws s3 ls | grep -q "$ALB_LOGS_BUCKET_NAME"; then
    echo -e "${GREEN}S3 bucket $ALB_LOGS_BUCKET_NAME was created successfully!${NC}"
  else
    echo -e "${RED}S3 bucket $ALB_LOGS_BUCKET_NAME was not found!${NC}"
  fi
  
  # Verify the ALB configuration was updated
  echo -e "${YELLOW}Checking if ALB access logs were enabled...${NC}"
  ALB_ARN=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `'$PROJECT_NAME-$ENVIRONMENT'`)].LoadBalancerArn' --output text)
  
  if [ -n "$ALB_ARN" ]; then
    LOGS_ENABLED=$(aws elbv2 describe-load-balancer-attributes --load-balancer-arn "$ALB_ARN" --query 'Attributes[?Key==`access_logs.s3.enabled`].Value' --output text)
    LOGS_BUCKET=$(aws elbv2 describe-load-balancer-attributes --load-balancer-arn "$ALB_ARN" --query 'Attributes[?Key==`access_logs.s3.bucket`].Value' --output text)
    
    if [ "$LOGS_ENABLED" == "true" ] && [ "$LOGS_BUCKET" == "$ALB_LOGS_BUCKET_NAME" ]; then
      echo -e "${GREEN}ALB access logs were enabled successfully!${NC}"
      echo -e "${GREEN}Logs will be delivered to $ALB_LOGS_BUCKET_NAME${NC}"
    else
      echo -e "${RED}ALB access logs were not enabled correctly!${NC}"
      echo -e "${RED}access_logs.s3.enabled = $LOGS_ENABLED${NC}"
      echo -e "${RED}access_logs.s3.bucket = $LOGS_BUCKET${NC}"
    fi
  else
    echo -e "${RED}Could not find ALB with name containing $PROJECT_NAME-$ENVIRONMENT!${NC}"
  fi
  
  echo -e "${YELLOW}Step 6: Next steps${NC}"
  echo -e "${YELLOW}1. Generate some traffic to the ALB to test log delivery${NC}"
  echo -e "${YELLOW}2. Wait a few minutes for logs to be delivered${NC}"
  echo -e "${YELLOW}3. Check the S3 bucket for logs: aws s3 ls s3://$ALB_LOGS_BUCKET_NAME/ --recursive${NC}"
  echo -e "${YELLOW}4. For more detailed instructions, see docs/applying-alb-logs-changes.md${NC}"
else
  echo -e "${YELLOW}Terraform apply skipped. You can apply the plan manually with:${NC}"
  echo -e "cd $TERRAFORM_DIR && terraform apply alb-logs-plan"
fi

echo -e "${GREEN}Script completed!${NC}"
