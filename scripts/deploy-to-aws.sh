#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
REGION="us-east-1"
SERVICES=()
BUILD_ONLY=false
DEPLOY_ONLY=false
SKIP_CONFIRMATION=false
AWS_PROFILE="trustainvest"

# Usage information
function show_usage {
  echo -e "${BLUE}Usage:${NC} $0 [options] [services...]"
  echo ""
  echo "Options:"
  echo "  -e, --environment ENV    Environment to deploy to (dev, stage, prod) [default: dev]"
  echo "  -r, --region REGION      AWS region to deploy to [default: us-east-1]"
  echo "  -b, --build-only         Build Docker images only, don't deploy"
  echo "  -d, --deploy-only        Deploy only, don't build Docker images"
  echo "  -y, --yes                Skip confirmation prompts"
  echo "  -p, --profile PROFILE    AWS profile to use [default: trustainvest]"
  echo "  -h, --help               Show this help message"
  echo ""
  echo "Services:"
  echo "  If no services are specified, all services will be deployed."
  echo "  Available services: user-service, account-service, trust-service, investment-service,"
  echo "  document-service, notification-service, user-registration-service, kyc-verifier-service,"
  echo "  etrade-service, capitalone-service, etrade-callback, kyc-worker, customer-app, kyc-verifier-ui"
  echo ""
  echo "Examples:"
  echo "  $0 --environment dev user-service account-service"
  echo "  $0 --environment prod --region us-west-2 --yes"
  echo "  $0 --build-only customer-app"
  echo "  $0 --profile my-aws-profile"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -b|--build-only)
      BUILD_ONLY=true
      shift
      ;;
    -d|--deploy-only)
      DEPLOY_ONLY=true
      shift
      ;;
    -y|--yes)
      SKIP_CONFIRMATION=true
      shift
      ;;
    -p|--profile)
      AWS_PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      ;;
    *)
      SERVICES+=("$1")
      shift
      ;;
  esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
  echo -e "${RED}Error:${NC} Invalid environment. Must be one of: dev, stage, prod"
  exit 1
fi

# Check if both build-only and deploy-only are specified
if [[ "$BUILD_ONLY" == true && "$DEPLOY_ONLY" == true ]]; then
  echo -e "${RED}Error:${NC} Cannot specify both --build-only and --deploy-only"
  exit 1
fi

# Set AWS account ID
AWS_ACCOUNT_ID="982081083216"

# Set ECR repository URL
ECR_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Set default services if none specified
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=(
    "user-service"
    "account-service"
    "trust-service"
    "investment-service"
    "document-service"
    "notification-service"
    "user-registration-service"
    "kyc-verifier-service"
    "etrade-service"
    "capitalone-service"
    "etrade-callback"
    "kyc-worker"
    "customer-app"
    "kyc-verifier-ui"
  )
fi

# Print deployment information
echo -e "${BLUE}Deployment Information:${NC}"
echo -e "  Environment: ${GREEN}${ENVIRONMENT}${NC}"
echo -e "  Region: ${GREEN}${REGION}${NC}"
echo -e "  AWS Account ID: ${GREEN}${AWS_ACCOUNT_ID}${NC}"
echo -e "  ECR Repository URL: ${GREEN}${ECR_REPO_URL}${NC}"
echo -e "  AWS Profile: ${GREEN}${AWS_PROFILE}${NC}"
echo -e "  Services: ${GREEN}${SERVICES[*]}${NC}"
echo -e "  Build Only: ${GREEN}${BUILD_ONLY}${NC}"
echo -e "  Deploy Only: ${GREEN}${DEPLOY_ONLY}${NC}"
echo ""

# Confirm deployment
if [[ "$SKIP_CONFIRMATION" != true ]]; then
  read -p "Do you want to continue? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
  fi
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed. Please install it first.${NC}"
  exit 1
fi

# Check if the profile exists
if ! aws configure list --profile $AWS_PROFILE &> /dev/null; then
  echo -e "${RED}Error: Profile '$AWS_PROFILE' does not exist. Please configure it first.${NC}"
  echo -e "${YELLOW}Run: aws configure --profile $AWS_PROFILE${NC}"
  exit 1
fi

# Check if credentials are valid
echo -e "${BLUE}Verifying AWS credentials...${NC}"
if ! aws sts get-caller-identity --profile $AWS_PROFILE &> /dev/null; then
  echo -e "${RED}Error: Invalid AWS credentials for profile '$AWS_PROFILE'.${NC}"
  exit 1
fi

# Get account info
account_info=$(aws sts get-caller-identity --profile $AWS_PROFILE)
actual_account_id=$(echo $account_info | grep -o '"Account": "[^"]*' | cut -d'"' -f4)

echo -e "${GREEN}Credentials are valid!${NC}"
echo -e "${BLUE}Account ID:${NC} $actual_account_id"
echo ""

# Check if the account ID matches the expected one
if [ "$actual_account_id" != "$AWS_ACCOUNT_ID" ]; then
  echo -e "${YELLOW}Warning: The AWS account ID ($actual_account_id) does not match the expected ID ($AWS_ACCOUNT_ID).${NC}"
  echo -e "${YELLOW}Make sure you are using the correct AWS account.${NC}"
  echo ""
  
  # Ask for confirmation to continue
  if [[ "$SKIP_CONFIRMATION" != true ]]; then
    read -p "Do you want to continue with account ID $actual_account_id? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${RED}Deployment cancelled.${NC}"
      exit 1
    fi
    
    # Update the account ID and ECR repository URL
    AWS_ACCOUNT_ID=$actual_account_id
    ECR_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
    echo -e "${BLUE}Updated ECR Repository URL: ${GREEN}${ECR_REPO_URL}${NC}"
    echo ""
  fi
fi

# Login to ECR
if [[ "$DEPLOY_ONLY" != true ]]; then
  echo -e "${BLUE}Logging in to ECR...${NC}"
  aws ecr get-login-password --region $REGION --profile $AWS_PROFILE | docker login --username AWS --password-stdin $ECR_REPO_URL
fi

# Process each service
for SERVICE in "${SERVICES[@]}"; do
  echo -e "${BLUE}Processing service: ${GREEN}${SERVICE}${NC}"
  
  # Set service-specific variables
  case $SERVICE in
    "user-service")
      DOCKERFILE="cmd/user-service/Dockerfile"
      ;;
    "account-service")
      DOCKERFILE="cmd/account-service/Dockerfile"
      ;;
    "trust-service")
      DOCKERFILE="cmd/trust-service/Dockerfile"
      ;;
    "investment-service")
      DOCKERFILE="cmd/investment-service/Dockerfile"
      ;;
    "document-service")
      DOCKERFILE="cmd/document-service/Dockerfile"
      ;;
    "notification-service")
      DOCKERFILE="cmd/notification-service/Dockerfile"
      ;;
    "user-registration-service")
      DOCKERFILE="cmd/user-registration-service/Dockerfile"
      ;;
    "kyc-verifier-service")
      DOCKERFILE="cmd/kyc-verifier-service/Dockerfile"
      ;;
    "etrade-service")
      DOCKERFILE="cmd/etrade-service/Dockerfile"
      ;;
    "capitalone-service")
      DOCKERFILE="cmd/capitalone-service/Dockerfile"
      ;;
    "etrade-callback")
      DOCKERFILE="cmd/etrade-callback/Dockerfile"
      ;;
    "kyc-worker")
      DOCKERFILE="cmd/kyc-worker/Dockerfile"
      ;;
    "customer-app")
      DOCKERFILE="customer-app/Dockerfile"
      ;;
    "kyc-verifier-ui")
      DOCKERFILE="kyc-verifier-ui/Dockerfile"
      ;;
    *)
      echo -e "${RED}Error:${NC} Unknown service: ${SERVICE}"
      continue
      ;;
  esac
  
  # Build and push Docker image
  if [[ "$DEPLOY_ONLY" != true ]]; then
    echo -e "${BLUE}Building Docker image for ${SERVICE}...${NC}"
    
    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names "trustainvest-${ENVIRONMENT}-${SERVICE}" --region $REGION --profile $AWS_PROFILE > /dev/null 2>&1 || \
      aws ecr create-repository --repository-name "trustainvest-${ENVIRONMENT}-${SERVICE}" --region $REGION --profile $AWS_PROFILE
    
    # Build Docker image
    docker build -t "trustainvest-${ENVIRONMENT}-${SERVICE}:latest" -f $DOCKERFILE .
    
    # Tag Docker image
    docker tag "trustainvest-${ENVIRONMENT}-${SERVICE}:latest" "${ECR_REPO_URL}/trustainvest-${ENVIRONMENT}-${SERVICE}:latest"
    
    # Push Docker image
    echo -e "${BLUE}Pushing Docker image for ${SERVICE}...${NC}"
    docker push "${ECR_REPO_URL}/trustainvest-${ENVIRONMENT}-${SERVICE}:latest"
  fi
  
  # Deploy to ECS
  if [[ "$BUILD_ONLY" != true ]]; then
    echo -e "${BLUE}Deploying ${SERVICE} to ECS...${NC}"
    
    # Get ECS cluster name
    ECS_CLUSTER_NAME=$(aws ecs list-clusters --region $REGION --profile $AWS_PROFILE --query "clusterArns[?contains(@, 'trustainvest-${ENVIRONMENT}')]" --output text | awk -F'/' '{print $2}')
    
    if [[ -z "$ECS_CLUSTER_NAME" ]]; then
      echo -e "${RED}Error:${NC} ECS cluster not found for environment: ${ENVIRONMENT}"
      continue
    fi
    
    # Get ECS service name
    ECS_SERVICE_NAME=$(aws ecs list-services --cluster $ECS_CLUSTER_NAME --region $REGION --profile $AWS_PROFILE --query "serviceArns[?contains(@, '${SERVICE}')]" --output text | awk -F'/' '{print $3}')
    
    if [[ -z "$ECS_SERVICE_NAME" ]]; then
      echo -e "${YELLOW}Warning:${NC} ECS service not found for ${SERVICE}. Skipping deployment."
      continue
    fi
    
    # Update ECS service
    aws ecs update-service --cluster $ECS_CLUSTER_NAME --service $ECS_SERVICE_NAME --force-new-deployment --region $REGION --profile $AWS_PROFILE
    
    echo -e "${GREEN}Deployment initiated for ${SERVICE}.${NC}"
  fi
  
  echo -e "${GREEN}Processing completed for ${SERVICE}.${NC}"
  echo ""
done

echo -e "${GREEN}All services processed successfully.${NC}"
