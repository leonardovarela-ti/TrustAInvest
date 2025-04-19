#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}TrustAInvest.com - Complete System Rebuild Script${NC}"
echo -e "${YELLOW}============================================${NC}"

# Navigate to the project root directory
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# Function to check if Docker is running
check_docker() {
  echo -e "${YELLOW}Checking if Docker is running...${NC}"
  if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker and try again.${NC}"
    exit 1
  fi
  echo -e "${GREEN}Docker is running.${NC}"
}

# Function to stop and remove all containers, volumes, and networks
clean_environment() {
  echo -e "${YELLOW}Stopping and removing all containers, volumes, and networks...${NC}"
  
  # Stop all running containers
  echo -e "${YELLOW}Stopping all running containers...${NC}"
  docker-compose down -v --remove-orphans
  
  # Also check for any test containers that might be running
  if [ -f "$PROJECT_ROOT/test/docker-compose.test.yml" ]; then
    echo -e "${YELLOW}Stopping any test containers...${NC}"
    docker-compose -f "$PROJECT_ROOT/test/docker-compose.test.yml" down -v --remove-orphans
  fi
  
  # Remove any dangling volumes
  echo -e "${YELLOW}Removing dangling volumes...${NC}"
  docker volume prune -f
  
  echo -e "${GREEN}Environment cleaned successfully.${NC}"
}

# Function to rebuild all Docker images
rebuild_images() {
  echo -e "${YELLOW}Rebuilding all Docker images from scratch...${NC}"
  
  # Build all services defined in docker-compose.yml with --no-cache to ensure fresh builds
  echo -e "${YELLOW}Building main services...${NC}"
  docker-compose build --no-cache
  
  # Build test images if test docker-compose file exists
  if [ -f "$PROJECT_ROOT/test/docker-compose.test.yml" ]; then
    echo -e "${YELLOW}Building test services...${NC}"
    docker-compose -f "$PROJECT_ROOT/test/docker-compose.test.yml" build --no-cache
  fi
  
  echo -e "${GREEN}All Docker images rebuilt successfully.${NC}"
}

# Function to start all services
start_services() {
  echo -e "${YELLOW}Starting all services...${NC}"
  docker-compose up -d
  echo -e "${GREEN}All services started successfully.${NC}"
}

# Function to perform health checks
health_check() {
  echo -e "${YELLOW}Performing health checks...${NC}"
  
  # Wait for services to be ready
  echo -e "${YELLOW}Waiting for services to initialize (30 seconds)...${NC}"
  sleep 30
  
  # Check database
  echo -e "${YELLOW}Checking database connection...${NC}"
  if docker-compose exec -T postgres pg_isready -U trustainvest > /dev/null 2>&1; then
    echo -e "${GREEN}Database is ready.${NC}"
  else
    echo -e "${RED}Database is not ready. Check logs with 'docker-compose logs postgres'${NC}"
  fi
  
  # Check Redis
  echo -e "${YELLOW}Checking Redis connection...${NC}"
  if docker-compose exec -T redis redis-cli ping | grep -q "PONG"; then
    echo -e "${GREEN}Redis is ready.${NC}"
  else
    echo -e "${RED}Redis is not ready. Check logs with 'docker-compose logs redis'${NC}"
  fi
  
  # Check localstack
  echo -e "${YELLOW}Checking Localstack health...${NC}"
  if curl -s http://localhost:4566/_localstack/health | grep -q "running"; then
    echo -e "${GREEN}Localstack is ready.${NC}"
  else
    echo -e "${RED}Localstack is not ready. Check logs with 'docker-compose logs localstack'${NC}"
  fi
  
  # Check user-registration-service
  echo -e "${YELLOW}Checking user-registration-service...${NC}"
  if curl -s http://localhost:8086/health 2>/dev/null | grep -q ""; then
    echo -e "${GREEN}User registration service is ready.${NC}"
  else
    echo -e "${RED}User registration service is not ready. Check logs with 'docker-compose logs user-registration-service'${NC}"
  fi
  
  # Check kyc-verifier-service
  echo -e "${YELLOW}Checking kyc-verifier-service...${NC}"
  if curl -s http://localhost:8090/health 2>/dev/null | grep -q ""; then
    echo -e "${GREEN}KYC verifier service is ready.${NC}"
  else
    echo -e "${RED}KYC verifier service is not ready. Check logs with 'docker-compose logs kyc-verifier-service'${NC}"
  fi
  
  echo -e "${YELLOW}Health checks completed.${NC}"
}

# Function to run integration tests
run_integration_tests() {
  echo -e "${YELLOW}Do you want to run integration tests? (y/n)${NC}"
  read -r run_tests
  
  if [[ $run_tests =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Running integration tests...${NC}"
    
    if [ -f "$PROJECT_ROOT/test/integration_test.sh" ]; then
      bash "$PROJECT_ROOT/test/integration_test.sh"
      
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Integration tests passed successfully!${NC}"
      else
        echo -e "${RED}Integration tests failed. Please check the logs for more details.${NC}"
      fi
    else
      echo -e "${RED}Integration test script not found at $PROJECT_ROOT/test/integration_test.sh${NC}"
    fi
  else
    echo -e "${YELLOW}Skipping integration tests.${NC}"
  fi
}

# Main execution flow
main() {
  check_docker
  clean_environment
  rebuild_images
  start_services
  health_check
  
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}System rebuild completed successfully!${NC}"
  echo -e "${GREEN}All containers have been rebuilt from scratch.${NC}"
  echo -e "${GREEN}============================================${NC}"
  
  run_integration_tests
}

# Execute main function
main
