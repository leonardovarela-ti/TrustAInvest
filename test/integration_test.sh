#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting integration tests...${NC}"

# Step 1: Start the system using docker-compose
echo -e "${YELLOW}Step 1: Starting the system...${NC}"
docker-compose -f docker-compose.test.yml down -v # Ensure clean state
echo -e "${YELLOW}Starting services (this may take a minute)...${NC}"
docker-compose -f docker-compose.test.yml up -d

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

# Step 2: Register a user
echo -e "${YELLOW}Step 2: Registering a user...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:18086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
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
    "ssn": "123-45-6789",
    "risk_profile": "MODERATE",
    "accept_terms": true
  }')

echo "Registration response: $REGISTER_RESPONSE"

# Check if registration was successful
if ! echo "$REGISTER_RESPONSE" | grep -q "User registered successfully"; then
  echo -e "${RED}User registration failed.${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}User registered successfully!${NC}"

# Step 3: Extract the verification token from the logs
echo -e "${YELLOW}Step 3: Extracting verification token from logs...${NC}"
sleep 2 # Give some time for logs to be written

# Get the logs from the user-registration-service
LOGS=$(docker-compose -f docker-compose.test.yml logs user-registration-service)

# Extract the verification token from the logs
VERIFICATION_TOKEN=$(echo "$LOGS" | grep -o 'with link: https://app.trustainvest.com/verify?token=[a-f0-9-]*' | tail -1 | sed 's/.*token=//')

if [ -z "$VERIFICATION_TOKEN" ]; then
  echo -e "${RED}Failed to extract verification token from logs.${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}Extracted verification token: $VERIFICATION_TOKEN${NC}"

# Step 4: Verify the email using the token
echo -e "${YELLOW}Step 4: Verifying email with token...${NC}"
VERIFY_RESPONSE=$(curl -s -X POST \
  http://localhost:18086/api/v1/verify-email \
  -H 'Content-Type: application/json' \
  -d "{
    \"token\": \"$VERIFICATION_TOKEN\"
  }")

echo "Verification response: $VERIFY_RESPONSE"

# Check if verification was successful
if ! echo "$VERIFY_RESPONSE" | grep -q "Email verified successfully"; then
  echo -e "${RED}Email verification failed.${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}Email verified successfully!${NC}"

# Step 5: Check that the entry is in the kyc.verification_requests table
echo -e "${YELLOW}Step 5: Checking KYC verification request in database...${NC}"
sleep 2 # Give some time for the database to be updated

# Run a query to check if the entry exists
KYC_CHECK=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -c "SELECT COUNT(*) FROM kyc.verification_requests WHERE status = 'PENDING' AND request_data->>'source' = 'EMAIL_VERIFICATION'")

# Extract the count from the result
COUNT=$(echo "$KYC_CHECK" | grep -o '[0-9]' | head -1)

if [ "$COUNT" -eq "0" ]; then
  echo -e "${RED}No KYC verification request found in the database.${NC}"
  docker-compose -f docker-compose.test.yml exec postgres psql -U trustainvest -d trustainvest -c "SELECT * FROM kyc.verification_requests"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}KYC verification request found in the database!${NC}"

# Print detailed information about the KYC request
echo -e "${YELLOW}KYC verification request details:${NC}"
docker-compose -f docker-compose.test.yml exec postgres psql -U trustainvest -d trustainvest -c "SELECT id, user_id, status, created_at, request_data FROM kyc.verification_requests WHERE request_data->>'source' = 'EMAIL_VERIFICATION'"

# Test completed successfully
echo -e "${GREEN}All tests passed successfully!${NC}"

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
docker-compose -f docker-compose.test.yml down

exit 0
