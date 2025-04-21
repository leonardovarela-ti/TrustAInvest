#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SERVICES=()
BUILD_ONLY=false
SKIP_CONFIRMATION=false

# Usage information
function show_usage {
  echo -e "${BLUE}Usage:${NC} $0 [options] [services...]"
  echo ""
  echo "Options:"
  echo "  -b, --build-only         Build Docker images only, don't deploy"
  echo "  -y, --yes                Skip confirmation prompts"
  echo "  -h, --help               Show this help message"
  echo ""
  echo "Services:"
  echo "  If no services are specified, all services will be deployed."
  echo "  Available services: user-service, account-service, trust-service, investment-service,"
  echo "  document-service, notification-service, user-registration-service, kyc-verifier-service,"
  echo "  etrade-service, capitalone-service, etrade-callback, kyc-worker, customer-app, kyc-verifier-ui"
  echo ""
  echo "Examples:"
  echo "  $0 user-service account-service"
  echo "  $0 --build-only customer-app"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--build-only)
      BUILD_ONLY=true
      shift
      ;;
    -y|--yes)
      SKIP_CONFIRMATION=true
      shift
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
echo -e "${BLUE}Local Deployment Information:${NC}"
echo -e "  Services: ${GREEN}${SERVICES[*]}${NC}"
echo -e "  Build Only: ${GREEN}${BUILD_ONLY}${NC}"
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

# Check if LocalStack is running
if ! docker ps | grep -q localstack; then
  echo -e "${YELLOW}LocalStack is not running. Starting LocalStack...${NC}"
  docker-compose up -d localstack
  
  # Wait for LocalStack to be ready
  echo -e "${BLUE}Waiting for LocalStack to be ready...${NC}"
  sleep 10
fi

# Initialize LocalStack
echo -e "${BLUE}Initializing LocalStack...${NC}"
./scripts/init-localstack.sh

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
  
  # Build Docker image
  echo -e "${BLUE}Building Docker image for ${SERVICE}...${NC}"
  docker build -t "trustainvest-local-${SERVICE}:latest" -f $DOCKERFILE .
  
  # Deploy to local environment
  if [[ "$BUILD_ONLY" != true ]]; then
    echo -e "${BLUE}Deploying ${SERVICE} to local environment...${NC}"
    
    # Check if service is already running
    if docker ps | grep -q "trustainvest-local-${SERVICE}"; then
      echo -e "${YELLOW}Service ${SERVICE} is already running. Stopping...${NC}"
      docker stop "trustainvest-local-${SERVICE}" || true
      docker rm "trustainvest-local-${SERVICE}" || true
    fi
    
    # Set environment variables
    ENV_VARS="-e AWS_ENDPOINT=http://localstack:4566"
    ENV_VARS+=" -e AWS_REGION=us-east-1"
    ENV_VARS+=" -e AWS_ACCESS_KEY_ID=test"
    ENV_VARS+=" -e AWS_SECRET_ACCESS_KEY=test"
    
    # Add service-specific environment variables
    case $SERVICE in
      "user-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "account-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "trust-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "investment-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "document-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "notification-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "user-registration-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "kyc-verifier-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "etrade-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "capitalone-service")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "etrade-callback")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "kyc-worker")
        ENV_VARS+=" -e DB_HOST=postgres"
        ENV_VARS+=" -e DB_PORT=5432"
        ENV_VARS+=" -e DB_NAME=trustainvest"
        ENV_VARS+=" -e DB_USER=postgres"
        ENV_VARS+=" -e DB_PASSWORD=postgres"
        ENV_VARS+=" -e REDIS_HOST=redis"
        ENV_VARS+=" -e REDIS_PORT=6379"
        ;;
      "customer-app")
        # Frontend app doesn't need database access
        ;;
      "kyc-verifier-ui")
        # Frontend app doesn't need database access
        ;;
    esac
    
    # Run Docker container
    if [[ "$SERVICE" == "customer-app" || "$SERVICE" == "kyc-verifier-ui" ]]; then
      # Frontend apps
      docker run -d --name "trustainvest-local-${SERVICE}" \
        --network trustainvest \
        -p 8080:80 \
        "trustainvest-local-${SERVICE}:latest"
    else
      # Backend services
      docker run -d --name "trustainvest-local-${SERVICE}" \
        --network trustainvest \
        $ENV_VARS \
        "trustainvest-local-${SERVICE}:latest"
    fi
    
    echo -e "${GREEN}Deployment completed for ${SERVICE}.${NC}"
  fi
  
  echo -e "${GREEN}Processing completed for ${SERVICE}.${NC}"
  echo ""
done

echo -e "${GREEN}All services processed successfully.${NC}"
echo -e "${BLUE}You can access the services at:${NC}"
echo -e "  Customer App: ${GREEN}http://localhost:8080${NC}"
echo -e "  KYC Verifier UI: ${GREEN}http://localhost:8081${NC}"
echo -e "  API Gateway: ${GREEN}http://localhost:8000${NC}"
