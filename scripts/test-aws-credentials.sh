#!/bin/bash
# Script to test AWS credentials and permissions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default profile
PROFILE="trustainvest"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--profile)
      PROFILE="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [-p|--profile PROFILE_NAME]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}Testing AWS credentials for profile: ${GREEN}${PROFILE}${NC}"
echo ""

# Function to check a permission
check_permission() {
  local service=$1
  local action=$2
  local resource=$3
  local description=$4
  
  echo -ne "${BLUE}Testing ${service}:${action}... ${NC}"
  
  output=$(aws $service $action $resource --profile $PROFILE 2>&1)
  exit_code=$?
  
  if [ $exit_code -eq 0 ] || [[ "$output" == *"DryRunOperation"* ]]; then
    echo -e "${GREEN}✓ Success${NC}"
    return 0
  elif [[ "$output" == *"UnauthorizedOperation"* ]] || [[ "$output" == *"AccessDenied"* ]]; then
    echo -e "${RED}✗ Failed - Permission denied${NC}"
    echo -e "   ${YELLOW}Required for: ${description}${NC}"
    return 1
  else
    echo -e "${YELLOW}? Inconclusive - ${output}${NC}"
    return 2
  fi
}

# Function to check if a service is accessible
check_service() {
  local service=$1
  local description=$2
  
  echo -e "${BLUE}Checking ${service} access:${NC}"
  
  case $service in
    ec2)
      check_permission "ec2" "describe-instances" "" "Listing EC2 instances"
      check_permission "ec2" "describe-vpcs" "" "Listing VPCs"
      check_permission "ec2" "describe-subnets" "" "Listing subnets"
      check_permission "ec2" "describe-security-groups" "" "Listing security groups"
      ;;
    ecs)
      check_permission "ecs" "list-clusters" "" "Listing ECS clusters"
      # Skip list-services test if no clusters exist
      clusters=$(aws ecs list-clusters --profile $PROFILE --output text)
      if [ -n "$clusters" ]; then
        cluster=$(echo $clusters | awk '{print $1}')
        check_permission "ecs" "list-services" "--cluster $cluster" "Listing ECS services"
      else
        echo -e "${BLUE}Testing ecs:list-services... ${YELLOW}Skipped - No clusters found${NC}"
      fi
      ;;
    ecr)
      check_permission "ecr" "describe-repositories" "" "Listing ECR repositories"
      ;;
    s3)
      check_permission "s3api" "list-buckets" "" "Listing S3 buckets"
      ;;
    rds)
      check_permission "rds" "describe-db-instances" "" "Listing RDS instances"
      ;;
    elasticache)
      check_permission "elasticache" "describe-cache-clusters" "" "Listing ElastiCache clusters"
      ;;
    route53)
      check_permission "route53" "list-hosted-zones" "" "Listing Route53 hosted zones"
      ;;
    cloudfront)
      check_permission "cloudfront" "list-distributions" "" "Listing CloudFront distributions"
      ;;
    iam)
      check_permission "iam" "list-roles" "" "Listing IAM roles"
      ;;
    kms)
      check_permission "kms" "list-keys" "" "Listing KMS keys"
      ;;
    cognito-idp)
      check_permission "cognito-idp" "list-user-pools" "--max-results 10" "Listing Cognito user pools"
      ;;
    sns)
      check_permission "sns" "list-topics" "" "Listing SNS topics"
      ;;
    sqs)
      check_permission "sqs" "list-queues" "" "Listing SQS queues"
      ;;
    wafv2)
      check_permission "wafv2" "list-web-acls" "--scope REGIONAL --region us-east-1" "Listing WAF web ACLs"
      ;;
    *)
      echo -e "${RED}Unknown service: $service${NC}"
      return 1
      ;;
  esac
  
  echo ""
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed. Please install it first.${NC}"
  exit 1
fi

# Check if the profile exists
if ! aws configure list --profile $PROFILE &> /dev/null; then
  echo -e "${RED}Error: Profile '$PROFILE' does not exist. Please configure it first.${NC}"
  echo -e "${YELLOW}Run: aws configure --profile $PROFILE${NC}"
  exit 1
fi

# Check if credentials are valid
echo -e "${BLUE}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
  echo -e "${RED}Error: Invalid AWS credentials for profile '$PROFILE'.${NC}"
  exit 1
fi

# Get account info
account_info=$(aws sts get-caller-identity --profile $PROFILE)
account_id=$(echo $account_info | jq -r '.Account')
user_arn=$(echo $account_info | jq -r '.Arn')
user_id=$(echo $account_info | jq -r '.UserId')

echo -e "${GREEN}Credentials are valid!${NC}"
echo -e "${BLUE}Account ID:${NC} $account_id"
echo -e "${BLUE}User ARN:${NC} $user_arn"
echo -e "${BLUE}User ID:${NC} $user_id"
echo ""

# Check if the account ID matches the expected one
if [ "$account_id" != "982081083216" ]; then
  echo -e "${YELLOW}Warning: The AWS account ID ($account_id) does not match the expected ID (982081083216).${NC}"
  echo -e "${YELLOW}Make sure you are using the correct AWS account.${NC}"
  echo ""
fi

# Check permissions for each service
echo -e "${BLUE}Testing permissions for TrustAInvest deployment...${NC}"
echo ""

check_service "ec2" "EC2 instances, VPCs, subnets, security groups"
check_service "ecs" "ECS clusters and services"
check_service "ecr" "ECR repositories"
check_service "s3" "S3 buckets"
check_service "rds" "RDS instances"
check_service "elasticache" "ElastiCache clusters"
check_service "route53" "Route53 hosted zones"
check_service "cloudfront" "CloudFront distributions"
check_service "iam" "IAM roles"
check_service "kms" "KMS keys"
check_service "cognito-idp" "Cognito user pools"
check_service "sns" "SNS topics"
check_service "sqs" "SQS queues"
check_service "wafv2" "WAF web ACLs"

echo -e "${BLUE}Testing complete!${NC}"
echo -e "${YELLOW}Note: This script only tests read permissions. Some deployment operations require write permissions that cannot be safely tested.${NC}"
echo -e "${YELLOW}If you encounter permission errors during deployment, refer to the docs/create-aws-deployment-user.md file for the required permissions.${NC}"
