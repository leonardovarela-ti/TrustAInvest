#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting failed registration test...${NC}"

# Step 1: Start the system using docker-compose
echo -e "${YELLOW}Step 1: Starting the system...${NC}"
docker-compose -f docker-compose.test.yml down -v # Ensure clean state
echo -e "${YELLOW}Starting services (this may take a minute)...${NC}"
docker-compose -f docker-compose.test.yml up -d --build

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Check if user-registration-service is up
echo -e "${YELLOW}Checking if user-registration-service is up...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s http://localhost:18086/health | grep -q "ok"; then
    echo -e "${GREEN}User registration service is up!${NC}"
    break
  fi
  
  echo -e "${YELLOW}Waiting for user-registration-service to be ready... (${RETRY_COUNT}/${MAX_RETRIES})${NC}"
  sleep 2
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo -e "${RED}Failed to connect to user-registration-service after ${MAX_RETRIES} attempts.${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test Case 1: Missing required fields
echo -e "${YELLOW}Test Case 1: Attempting registration with missing required fields...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
    "password": "securePassword123!"
  }')

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration failed as expected
if echo "$REGISTER_RESPONSE" | grep -q "error"; then
  echo -e "${GREEN}Test passed: Registration failed as expected due to missing required fields${NC}"
else
  echo -e "${RED}Test failed: Registration should have failed but succeeded${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test Case 2: Invalid email format
echo -e "${YELLOW}Test Case 2: Attempting registration with invalid email format...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "invalid-email",
    "password": "securePassword123!",
    "phone_number": "+15551234567",
    "first_name": "John",
    "last_name": "Doe",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration failed as expected
if echo "$REGISTER_RESPONSE" | grep -q "error"; then
  echo -e "${GREEN}Test passed: Registration failed as expected due to invalid email format${NC}"
else
  echo -e "${RED}Test failed: Registration should have failed but succeeded${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test Case 3: Weak password
echo -e "${YELLOW}Test Case 3: Attempting registration with weak password...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
    "password": "password",
    "phone_number": "+15551234567",
    "first_name": "John",
    "last_name": "Doe",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration failed as expected
if echo "$REGISTER_RESPONSE" | grep -q "error"; then
  echo -e "${GREEN}Test passed: Registration failed as expected due to weak password${NC}"
else
  echo -e "${RED}Test failed: Registration should have failed but succeeded${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test Case 4: Invalid verification token
echo -e "${YELLOW}Test Case 4: Attempting email verification with invalid token...${NC}"
VERIFY_RESPONSE=$(curl -s -X POST \
  http://localhost:18086/api/v1/verify-email \
  -H 'Content-Type: application/json' \
  -d '{
    "token": "invalid-token-that-does-not-exist"
  }')

echo "Verification response: $VERIFY_RESPONSE"

# Check if verification failed as expected
if echo "$VERIFY_RESPONSE" | grep -q "Invalid or expired verification token"; then
  echo -e "${GREEN}Test passed: Verification failed as expected due to invalid token${NC}"
else
  echo -e "${RED}Test failed: Verification should have failed but succeeded${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test Case 5: Empty first_name or last_name
echo -e "${YELLOW}Test Case 5: Attempting registration with empty first_name...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
    "password": "securePassword123!",
    "phone_number": "+15551234567",
    "first_name": "",
    "last_name": "Doe",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration failed as expected
if echo "$REGISTER_RESPONSE" | grep -q "First name cannot be empty"; then
  echo -e "${GREEN}Test passed: Registration failed as expected due to empty first_name${NC}"
else
  echo -e "${RED}Test failed: Registration should have failed but succeeded or failed with wrong error message${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test with whitespace-only first_name
echo -e "${YELLOW}Test Case 5b: Attempting registration with whitespace-only first_name...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
    "password": "securePassword123!",
    "phone_number": "+15551234567",
    "first_name": "   ",
    "last_name": "Doe",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration failed as expected
if echo "$REGISTER_RESPONSE" | grep -q "First name cannot be empty"; then
  echo -e "${GREEN}Test passed: Registration failed as expected due to whitespace-only first_name${NC}"
else
  echo -e "${RED}Test failed: Registration should have failed but succeeded or failed with wrong error message${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test Case 6: Successful registration but check for duplicate username
echo -e "${YELLOW}Test Case 6: Register a user, then try to register with the same username...${NC}"

# First registration
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "uniqueuser",
    "email": "unique.user@example.com",
    "password": "securePassword123!",
    "phone_number": "+15551234567",
    "first_name": "Unique",
    "last_name": "User",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "First registration response: $REGISTER_RESPONSE"

# Check if first registration was successful
if ! echo "$REGISTER_RESPONSE" | grep -q "User registered successfully"; then
  echo -e "${RED}Test setup failed: First registration was not successful${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Second registration with same username
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "uniqueuser",
    "email": "different.email@example.com",
    "password": "securePassword123!",
    "phone_number": "+15551234567",
    "first_name": "Different",
    "last_name": "User",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "Second registration response: $REGISTER_RESPONSE"

# Check if second registration failed as expected
if echo "$REGISTER_RESPONSE" | grep -q "Username already taken"; then
  echo -e "${GREEN}Test passed: Second registration failed as expected due to duplicate username${NC}"
else
  echo -e "${RED}Test failed: Second registration should have failed but succeeded${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

# Test completed successfully
echo -e "${GREEN}All failed registration tests passed successfully!${NC}"

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
docker-compose -f docker-compose.test.yml down

exit 0
