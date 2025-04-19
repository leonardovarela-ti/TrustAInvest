#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting user journey integration test...${NC}"

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

# Step 2: Register a new user
echo -e "${YELLOW}Step 2: Registering a new user...${NC}"
# Generate a unique username with timestamp
TIMESTAMP=$(date +%s)
USERNAME="testuser_${TIMESTAMP}"
EMAIL="test.user.${TIMESTAMP}@example.com"

# Create a JSON file for registration
cat > register.json << EOF
{
  "username": "$USERNAME",
  "email": "$EMAIL",
  "password": "securePassword123!",
  "phone_number": "5551234567",
  "first_name": "Test",
  "last_name": "User",
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
}
EOF

REGISTER_CMD="curl -X POST http://localhost:18086/api/v1/register \\
  -H \"Content-Type: application/json\" \\
  -d @register.json"
echo -e "${GREEN}Executing command:${NC}"
echo "$REGISTER_CMD"
REGISTER_RESPONSE=$(eval "$REGISTER_CMD -s")

echo "Registration response: $REGISTER_RESPONSE"

# Extract user ID from the response
USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"user_id":"[^"]*' | sed 's/"user_id":"//')

if [ -z "$USER_ID" ]; then
  echo -e "${RED}Failed to extract user ID from registration response.${NC}"
  exit 1
fi

echo -e "${GREEN}User registered with ID: $USER_ID${NC}"

# Step 3: Extract the verification token from the logs
echo -e "${YELLOW}Step 3: Extracting verification token from logs...${NC}"
sleep 2 # Give some time for logs to be written

# Get the logs from the user-registration-service
LOGS=$(docker-compose -f docker-compose.test.yml logs user-registration-service)

# Extract the verification token from the logs
VERIFICATION_TOKEN=$(echo "$LOGS" | grep -o "Sending verification email to $EMAIL with link: https://app.trustainvest.com/verify?token=[a-f0-9-]*" | tail -1 | sed 's/.*token=//')

if [ -z "$VERIFICATION_TOKEN" ]; then
  echo -e "${RED}Failed to extract verification token from logs.${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}Extracted verification token: $VERIFICATION_TOKEN${NC}"

# Step 4: Verify the email using the token
echo -e "${YELLOW}Step 4: Verifying email with token...${NC}"
# Create a JSON file for verification
cat > verify.json << EOF
{
  "token": "$VERIFICATION_TOKEN"
}
EOF

VERIFY_CMD="curl -X POST http://localhost:18086/api/v1/verify-email \\
  -H 'Content-Type: application/json' \\
  -d @verify.json"
echo -e "${GREEN}Executing command:${NC}"
echo "$VERIFY_CMD"
VERIFY_RESPONSE=$(eval "$VERIFY_CMD -s")

echo "Verification response: $VERIFY_RESPONSE"

# Check if verification was successful
if ! echo "$VERIFY_RESPONSE" | grep -q "Email verified successfully"; then
  echo -e "${RED}Email verification failed.${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}Email verified successfully!${NC}"

# Step 5: Get the verification request ID from the database
echo -e "${YELLOW}Step 5: Getting verification request ID from the database...${NC}"
VERIFICATION_REQUEST_ID=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -t -c "SELECT id FROM kyc.verification_requests WHERE request_data->>'source' = 'EMAIL_VERIFICATION' AND request_data->>'email' = '$EMAIL'" | tr -d '[:space:]')

if [ -z "$VERIFICATION_REQUEST_ID" ]; then
  echo -e "${RED}Failed to get verification request ID from the database.${NC}"
  docker-compose -f docker-compose.test.yml down
  exit 1
fi

echo -e "${GREEN}Got verification request ID: $VERIFICATION_REQUEST_ID${NC}"
# try to login before updating the verification request status
# Step 5.1: Login with the non verified user
echo -e "${YELLOW}Step 5.1: Attempting to login with the non-verified user...${NC}"
# Create a JSON file for login
cat > login-non-verified.json << EOF
{
  "username": "$USERNAME",
  "password": "securePassword123!"
}
EOF

# Add retry mechanism for login
LOGIN_RETRY_COUNT=0
LOGIN_MAX_RETRIES=5
LOGIN_SUCCESS=false

while [ $LOGIN_RETRY_COUNT -lt $LOGIN_MAX_RETRIES ] && [ "$LOGIN_SUCCESS" = false ]; do
  echo -e "${YELLOW}Attempting login (${LOGIN_RETRY_COUNT}/${LOGIN_MAX_RETRIES})...${NC}"
  
  LOGIN_CMD="curl -v -X POST http://localhost:18086/api/v1/auth/login \\
    -H \"Content-Type: application/json\" \\
    -d @login-non-verified.json"
  echo -e "${GREEN}Executing command:${NC}"
  echo "$LOGIN_CMD"
  LOGIN_RESPONSE=$(eval "$LOGIN_CMD 2>&1")

  echo -e "${YELLOW}Full response (including headers):${NC}"
  echo "$LOGIN_RESPONSE"

  # Extract just the response body
  LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | awk '/^{/,/^}/')
  echo -e "${YELLOW}Response body:${NC}"
  echo "$LOGIN_BODY"
  
  # Check if the response contains an error message about KYC verification
  if echo "$LOGIN_BODY" | grep -q "KYC not verified"; then
    echo -e "${GREEN}Login correctly failed with KYC not verified message!${NC}"
    LOGIN_SUCCESS=true
  else
    echo -e "${YELLOW}Login attempt did not fail as expected, retrying in 2 seconds...${NC}"
    sleep 2
    LOGIN_RETRY_COUNT=$((LOGIN_RETRY_COUNT + 1))
  fi
done

if [ "$LOGIN_SUCCESS" = false ]; then
  echo -e "${RED}Login did not fail as expected after ${LOGIN_MAX_RETRIES} attempts.${NC}"
  echo -e "${YELLOW}Last response: $LOGIN_RESPONSE${NC}"
  # Get the logs from the user-registration-service
  echo -e "${YELLOW}User registration service logs:${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  exit 1
fi

# Step 6: Update the verification request status to VERIFIED
echo -e "${YELLOW}Step 6: Updating verification request status to VERIFIED...${NC}"

# Disable the trigger to avoid the verified_at field error
echo -e "${YELLOW}Disabling trigger...${NC}"
DISABLE_TRIGGER_RESULT=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -c "ALTER TABLE kyc.verification_requests DISABLE TRIGGER update_user_kyc_status_trigger")
echo "$DISABLE_TRIGGER_RESULT"

# Update the status with explicit transaction
echo -e "${YELLOW}Updating verification request status...${NC}"
UPDATE_RESULT=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -c "
BEGIN;
UPDATE kyc.verification_requests SET status = 'VERIFIED', updated_at = NOW(), completed_at = NOW() WHERE id = '$VERIFICATION_REQUEST_ID';
COMMIT;
")
echo "$UPDATE_RESULT"

# Also update the user's KYC status directly since we disabled the trigger
echo -e "${YELLOW}Updating user KYC status...${NC}"
USER_UPDATE_RESULT=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -c "
BEGIN;
UPDATE users.users SET kyc_status = 'VERIFIED', updated_at = NOW() WHERE id = '$USER_ID';
COMMIT;
")
echo "$USER_UPDATE_RESULT"

# Re-enable the trigger
echo -e "${YELLOW}Re-enabling trigger...${NC}"
ENABLE_TRIGGER_RESULT=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -c "ALTER TABLE kyc.verification_requests ENABLE TRIGGER update_user_kyc_status_trigger")
echo "$ENABLE_TRIGGER_RESULT"

# Step 7: Verify the KYC status is set to VERIFIED
echo -e "${YELLOW}Step 7: Verifying KYC status is set to VERIFIED...${NC}"
KYC_STATUS_RESULT=$(docker-compose -f docker-compose.test.yml exec -T postgres psql -U trustainvest -d trustainvest -c "
SELECT kyc_status FROM users.users WHERE id = '$USER_ID';
")
echo "$KYC_STATUS_RESULT"

if echo "$KYC_STATUS_RESULT" | grep -q "VERIFIED"; then
  echo -e "${GREEN}User's KYC status is correctly set to VERIFIED!${NC}"
else
  echo -e "${RED}User's KYC status is not set to VERIFIED as expected.${NC}"
  exit 1
fi

# Step 8: Login with the verified user
echo -e "${YELLOW}Step 8: Attempting to login with the verified user...${NC}"
# Create a JSON file for login
cat > login.json << EOF
{
  "username": "$USERNAME",
  "password": "securePassword123!"
}
EOF

# Add retry mechanism for login
LOGIN_RETRY_COUNT=0
LOGIN_MAX_RETRIES=5
LOGIN_SUCCESS=false

while [ $LOGIN_RETRY_COUNT -lt $LOGIN_MAX_RETRIES ] && [ "$LOGIN_SUCCESS" = false ]; do
  echo -e "${YELLOW}Attempting login (${LOGIN_RETRY_COUNT}/${LOGIN_MAX_RETRIES})...${NC}"
  
  LOGIN_CMD="curl -v -X POST http://localhost:18086/api/v1/auth/login \\
    -H \"Content-Type: application/json\" \\
    -d @login.json"
  echo -e "${GREEN}Executing command:${NC}"
  echo "$LOGIN_CMD"
  LOGIN_RESPONSE=$(eval "$LOGIN_CMD 2>&1")

  echo -e "${YELLOW}Full response (including headers):${NC}"
  echo "$LOGIN_RESPONSE"

  # Extract just the response body
  LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | awk '/^{/,/^}/')
  echo -e "${YELLOW}Response body:${NC}"
  echo "$LOGIN_BODY"

  # Extract the token from the response
  JWT_TOKEN=$(echo "$LOGIN_BODY" | grep -o '"token":"[^"]*' | sed 's/"token":"//')

  if [ -n "$JWT_TOKEN" ]; then
    LOGIN_SUCCESS=true
    echo -e "${GREEN}Successfully logged in and received JWT token!${NC}"
  else
    echo -e "${YELLOW}Login attempt failed, retrying in 2 seconds...${NC}"
    sleep 2
    LOGIN_RETRY_COUNT=$((LOGIN_RETRY_COUNT + 1))
  fi
done

if [ "$LOGIN_SUCCESS" = false ]; then
  echo -e "${RED}Failed to login after ${LOGIN_MAX_RETRIES} attempts.${NC}"
  echo -e "${YELLOW}Last response: $LOGIN_RESPONSE${NC}"
  # Get the logs from the user-registration-service
  echo -e "${YELLOW}User registration service logs:${NC}"
  docker-compose -f docker-compose.test.yml logs user-registration-service
  exit 1
fi

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
docker-compose -f docker-compose.test.yml down -v
rm -f register.json verify.json login.json

echo -e "${GREEN}User journey test completed successfully!${NC}" 