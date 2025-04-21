#!/bin/bash

# Script to check and fix the S3 bucket policy for ALB access logs
# This script should be used if logs are not being delivered to the S3 bucket

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
ELB_ACCOUNT_ID="127311923021"  # ELB Account ID for us-east-1

# Function to get ELB Account ID for a region
get_elb_account_id() {
  local region=$1
  
  case "$region" in
    "us-east-1")
      echo "127311923021"
      ;;
    "us-east-2")
      echo "033677994240"
      ;;
    "us-west-1")
      echo "027434742980"
      ;;
    "us-west-2")
      echo "797873946194"
      ;;
    "af-south-1")
      echo "098369216593"
      ;;
    "ca-central-1")
      echo "985666609251"
      ;;
    "eu-central-1")
      echo "054676820928"
      ;;
    "eu-west-1")
      echo "156460612806"
      ;;
    "eu-west-2")
      echo "652711504416"
      ;;
    "eu-west-3")
      echo "009996457667"
      ;;
    "eu-north-1")
      echo "897822967062"
      ;;
    "eu-south-1")
      echo "635631232127"
      ;;
    "ap-east-1")
      echo "754344448648"
      ;;
    "ap-northeast-1")
      echo "582318560864"
      ;;
    "ap-northeast-2")
      echo "600734575887"
      ;;
    "ap-northeast-3")
      echo "383597477331"
      ;;
    "ap-southeast-1")
      echo "114774131450"
      ;;
    "ap-southeast-2")
      echo "783225319266"
      ;;
    "ap-south-1")
      echo "718504428378"
      ;;
    "me-south-1")
      echo "076674570225"
      ;;
    "sa-east-1")
      echo "507241528517"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Get the current AWS region if not specified
if [ -z "$REGION" ]; then
  REGION=$(aws configure get region)
  if [ -z "$REGION" ]; then
    REGION="us-east-1"
  fi
fi

# Get the ELB Account ID for the current region
ELB_ACCOUNT_ID=$(get_elb_account_id "$REGION")
if [ -z "$ELB_ACCOUNT_ID" ]; then
  echo -e "${RED}Unknown region: $REGION${NC}"
  echo -e "${RED}Please specify a valid region or update the script with the ELB Account ID for your region.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 1: Checking if the S3 bucket exists...${NC}"
if aws s3 ls "s3://$ALB_LOGS_BUCKET_NAME" >/dev/null 2>&1; then
  echo -e "${GREEN}S3 bucket $ALB_LOGS_BUCKET_NAME exists!${NC}"
else
  echo -e "${RED}S3 bucket $ALB_LOGS_BUCKET_NAME does not exist!${NC}"
  echo -e "${RED}Please create the bucket first using the apply-alb-logs-fix.sh script.${NC}"
  exit 1
fi

echo -e "${YELLOW}Step 2: Checking the current bucket policy...${NC}"
POLICY=$(aws s3api get-bucket-policy --bucket "$ALB_LOGS_BUCKET_NAME" --query Policy --output text 2>/dev/null || echo "")

if [ -z "$POLICY" ]; then
  echo -e "${YELLOW}No bucket policy found. Creating a new policy...${NC}"
  CREATE_NEW_POLICY=true
else
  echo -e "${GREEN}Found existing bucket policy:${NC}"
  echo "$POLICY" | jq '.'
  
  # Check if the policy contains the ELB Account ID
  if echo "$POLICY" | grep -q "$ELB_ACCOUNT_ID"; then
    echo -e "${GREEN}Policy contains the correct ELB Account ID for region $REGION.${NC}"
    HAS_ELB_ACCOUNT=true
  else
    echo -e "${YELLOW}Policy does not contain the ELB Account ID for region $REGION.${NC}"
    HAS_ELB_ACCOUNT=false
  fi
  
  # Check if the policy allows s3:PutObject
  if echo "$POLICY" | grep -q "s3:PutObject"; then
    echo -e "${GREEN}Policy allows s3:PutObject action.${NC}"
    HAS_PUT_OBJECT=true
  else
    echo -e "${YELLOW}Policy does not allow s3:PutObject action.${NC}"
    HAS_PUT_OBJECT=false
  fi
  
  # Check if the policy has the correct resource path
  if echo "$POLICY" | grep -q "arn:aws:s3:::$ALB_LOGS_BUCKET_NAME/\*"; then
    echo -e "${GREEN}Policy has the correct resource path.${NC}"
    HAS_CORRECT_RESOURCE=true
  else
    echo -e "${YELLOW}Policy does not have the correct resource path.${NC}"
    HAS_CORRECT_RESOURCE=false
  fi
  
  # Decide if we need to update the policy
  if [ "$HAS_ELB_ACCOUNT" = true ] && [ "$HAS_PUT_OBJECT" = true ] && [ "$HAS_CORRECT_RESOURCE" = true ]; then
    echo -e "${GREEN}Bucket policy appears to be correctly configured for ALB logs.${NC}"
    UPDATE_POLICY=false
  else
    echo -e "${YELLOW}Bucket policy needs to be updated for ALB logs.${NC}"
    UPDATE_POLICY=true
  fi
fi

if [ "$CREATE_NEW_POLICY" = true ] || [ "$UPDATE_POLICY" = true ]; then
  echo -e "${YELLOW}Step 3: Creating/updating the bucket policy...${NC}"
  
  # Create a temporary file for the policy
  POLICY_FILE=$(mktemp)
  
  # Write the policy to the file
  cat > "$POLICY_FILE" << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::$ELB_ACCOUNT_ID:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$ALB_LOGS_BUCKET_NAME/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$ALB_LOGS_BUCKET_NAME/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::$ALB_LOGS_BUCKET_NAME"
    }
  ]
}
EOF
  
  # Apply the policy to the bucket
  aws s3api put-bucket-policy --bucket "$ALB_LOGS_BUCKET_NAME" --policy file://"$POLICY_FILE"
  
  # Clean up the temporary file
  rm "$POLICY_FILE"
  
  echo -e "${GREEN}Bucket policy updated successfully!${NC}"
fi

echo -e "${YELLOW}Step 4: Checking bucket ACL...${NC}"
ACL=$(aws s3api get-bucket-acl --bucket "$ALB_LOGS_BUCKET_NAME" --output json)

# Check if the bucket has the log-delivery-write ACL
if echo "$ACL" | jq -e '.Grants[] | select(.Grantee.URI == "http://acs.amazonaws.com/groups/s3/LogDelivery" and .Permission == "WRITE")' > /dev/null; then
  echo -e "${GREEN}Bucket has the log-delivery-write ACL.${NC}"
else
  echo -e "${YELLOW}Bucket does not have the log-delivery-write ACL. Updating...${NC}"
  
  # Update the bucket ACL
  aws s3api put-bucket-acl --bucket "$ALB_LOGS_BUCKET_NAME" --acl log-delivery-write
  
  echo -e "${GREEN}Bucket ACL updated successfully!${NC}"
fi

echo -e "${YELLOW}Step 5: Finding the ALB ARN...${NC}"
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `'$PROJECT_NAME-$ENVIRONMENT'`)].LoadBalancerArn' \
  --output text)

if [ -z "$ALB_ARN" ]; then
  echo -e "${RED}Could not find ALB with name containing $PROJECT_NAME-$ENVIRONMENT!${NC}"
  echo -e "${RED}Please check your AWS configuration and try again.${NC}"
  exit 1
fi

echo -e "${GREEN}Found ALB ARN: $ALB_ARN${NC}"

echo -e "${YELLOW}Step 6: Verifying ALB access logs configuration...${NC}"
LOGS_ENABLED=$(aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Attributes[?Key==`access_logs.s3.enabled`].Value' \
  --output text)

LOGS_BUCKET=$(aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Attributes[?Key==`access_logs.s3.bucket`].Value' \
  --output text)

if [ "$LOGS_ENABLED" == "true" ] && [ "$LOGS_BUCKET" == "$ALB_LOGS_BUCKET_NAME" ]; then
  echo -e "${GREEN}ALB access logs are correctly configured!${NC}"
  echo -e "${GREEN}Logs will be delivered to $ALB_LOGS_BUCKET_NAME${NC}"
else
  echo -e "${YELLOW}ALB access logs are not correctly configured. Updating...${NC}"
  
  # Update the ALB attributes
  aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn "$ALB_ARN" \
    --attributes \
    "Key=access_logs.s3.enabled,Value=true" \
    "Key=access_logs.s3.bucket,Value=$ALB_LOGS_BUCKET_NAME" \
    "Key=access_logs.s3.prefix,Value="
  
  echo -e "${GREEN}ALB access logs configuration updated successfully!${NC}"
fi

echo -e "${YELLOW}Step 7: Generating test traffic to the ALB...${NC}"
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

echo -e "${YELLOW}Step 8: Next steps${NC}"
echo -e "${YELLOW}1. Wait 5-10 minutes for logs to be delivered${NC}"
echo -e "${YELLOW}2. Check the S3 bucket for logs:${NC}"
echo -e "${YELLOW}   aws s3 ls s3://$ALB_LOGS_BUCKET_NAME/ --recursive${NC}"
echo -e "${YELLOW}3. If you don't see logs after 10 minutes, check:${NC}"
echo -e "${YELLOW}   - CloudTrail for access denied errors${NC}"
echo -e "${YELLOW}   - ALB configuration in the AWS console${NC}"
echo -e "${YELLOW}   - AWS documentation for any region-specific requirements${NC}"

echo -e "${GREEN}Script completed!${NC}"
