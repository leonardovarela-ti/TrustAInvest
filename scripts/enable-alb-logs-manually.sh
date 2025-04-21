#!/bin/bash

# Script to manually enable ALB access logs using the AWS CLI
# This script should be used if the Terraform approach doesn't enable the logs correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="trustainvest"
ENVIRONMENT="dev"
ALB_LOGS_BUCKET_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb-logs"
REGION="us-east-1"  # Change this if your ALB is in a different region

echo -e "${YELLOW}Step 1: Finding the ALB ARN...${NC}"
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `'$PROJECT_NAME-$ENVIRONMENT'`)].LoadBalancerArn' \
  --output text)

if [ -z "$ALB_ARN" ]; then
  echo -e "${RED}Could not find ALB with name containing $PROJECT_NAME-$ENVIRONMENT!${NC}"
  echo -e "${RED}Please check your AWS configuration and try again.${NC}"
  exit 1
fi

echo -e "${GREEN}Found ALB ARN: $ALB_ARN${NC}"

echo -e "${YELLOW}Step 2: Checking if the S3 bucket exists...${NC}"
if aws s3 ls "s3://$ALB_LOGS_BUCKET_NAME" >/dev/null 2>&1; then
  echo -e "${GREEN}S3 bucket $ALB_LOGS_BUCKET_NAME exists!${NC}"
else
  echo -e "${RED}S3 bucket $ALB_LOGS_BUCKET_NAME does not exist!${NC}"
  echo -e "${RED}Please create the bucket first using the apply-alb-logs-fix.sh script.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 3: Enabling ALB access logs...${NC}"
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn "$ALB_ARN" \
  --attributes \
  "Key=access_logs.s3.enabled,Value=true" \
  "Key=access_logs.s3.bucket,Value=$ALB_LOGS_BUCKET_NAME" \
  "Key=access_logs.s3.prefix,Value="

echo -e "${YELLOW}Step 4: Verifying ALB access logs configuration...${NC}"
LOGS_ENABLED=$(aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Attributes[?Key==`access_logs.s3.enabled`].Value' \
  --output text)

LOGS_BUCKET=$(aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Attributes[?Key==`access_logs.s3.bucket`].Value' \
  --output text)

if [ "$LOGS_ENABLED" == "true" ] && [ "$LOGS_BUCKET" == "$ALB_LOGS_BUCKET_NAME" ]; then
  echo -e "${GREEN}ALB access logs were enabled successfully!${NC}"
  echo -e "${GREEN}Logs will be delivered to $ALB_LOGS_BUCKET_NAME${NC}"
else
  echo -e "${RED}ALB access logs were not enabled correctly!${NC}"
  echo -e "${RED}access_logs.s3.enabled = $LOGS_ENABLED${NC}"
  echo -e "${RED}access_logs.s3.bucket = $LOGS_BUCKET${NC}"
  echo -e "${RED}Please check your AWS permissions and try again.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 5: Generating test traffic to the ALB...${NC}"
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arn "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo -e "${YELLOW}Sending 10 requests to http://$ALB_DNS...${NC}"
echo -e "${YELLOW}Note: You may see connection errors (000) if the ALB doesn't have any healthy targets.${NC}"
echo -e "${YELLOW}This is normal and won't affect log generation - ALB will still log the requests.${NC}"

# Add a small delay between requests and handle errors better
for i in {1..10}; do 
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "http://$ALB_DNS" || echo "ERROR")
  echo "Request $i: $STATUS"
  sleep 1
done

echo -e "${YELLOW}Step 6: Next steps${NC}"
echo -e "${YELLOW}1. Wait 5-10 minutes for logs to be delivered${NC}"
echo -e "${YELLOW}2. Check the S3 bucket for logs:${NC}"
echo -e "${YELLOW}   aws s3 ls s3://$ALB_LOGS_BUCKET_NAME/ --recursive${NC}"
echo -e "${YELLOW}3. If you don't see logs after 10 minutes, check:${NC}"
echo -e "${YELLOW}   - S3 bucket policy (should allow ELB account to write logs)${NC}"
echo -e "${YELLOW}   - CloudTrail for access denied errors${NC}"
echo -e "${YELLOW}   - ALB configuration in the AWS console${NC}"

echo -e "${GREEN}Script completed!${NC}"
