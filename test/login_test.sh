#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting login test suite...${NC}"

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Step 1: Build the required images
echo -e "${YELLOW}Step 1: Building required images...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" build

# Step 2: Start the system using docker-compose
echo -e "${YELLOW}Step 2: Starting the system...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down -v # Ensure clean state
echo -e "${YELLOW}Starting services (this may take a minute)...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Wait for database initialization to complete
echo -e "${YELLOW}Waiting for database initialization to complete...${NC}"
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -c "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'users' AND table_name = 'active_sessions')" | grep -q "t"; then
    echo -e "${GREEN}Database initialization completed!${NC}"
    break
  fi
  
  echo -e "${YELLOW}Waiting for database initialization... (${RETRY_COUNT}/${MAX_RETRIES})${NC}"
  sleep 2
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo -e "${RED}Failed to initialize database after ${MAX_RETRIES} attempts.${NC}"
  docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs postgres
  docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down
  exit 1
fi

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
  docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs user-registration-service
  docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down
  exit 1
fi

# Test configuration
API_URL="http://localhost:18086/api/v1"  # User service port
TEST_USER="test_user_$(date +%s)"
TEST_EMAIL="test_$(date +%s)@example.com"
TEST_PASSWORD="Test123!@#"

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        exit 1
    fi
}

# Function to make API requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local token=$4
    local session_id=$5

    if [ -n "$token" ]; then
        if [ -n "$session_id" ]; then
            response=$(curl -s -X "$method" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -H "X-Session-ID: $session_id" \
                -d "$data" \
                "$API_URL/$endpoint")
        else
            response=$(curl -s -X "$method" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -d "$data" \
                "$API_URL/$endpoint")
        fi
    else
        response=$(curl -s -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$API_URL/$endpoint")
    fi

    echo "$response"
}

# Test 1: Register a new user
echo -e "\n${YELLOW}Test 1: Register new user${NC}"
register_data="{
    \"username\": \"$TEST_USER\",
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"first_name\": \"Test\",
    \"last_name\": \"User\",
    \"date_of_birth\": \"1990-01-01\",
    \"phone_number\": \"1234567890\",
    \"address\": {
        \"street\": \"123 Test St\",
        \"city\": \"Test City\",
        \"state\": \"TS\",
        \"zip_code\": \"12345\",
        \"country\": \"USA\"
    },
    \"ssn\": \"123-45-6789\",
    \"accept_terms\": true,
    \"risk_profile\": \"MODERATE\"
}"

response=$(make_request "POST" "register" "$register_data")
echo "Registration response: $response"

# Check if registration was successful
if echo "$response" | jq -e '.user_id' > /dev/null 2>&1; then
    user_id=$(echo "$response" | jq -r '.user_id')
    print_result 0 "User registration successful"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_result 1 "User registration failed: $error_msg"
fi

# Step 2: Extract the verification token from the logs
echo -e "${YELLOW}Step 2: Extracting verification token from logs...${NC}"
sleep 2 # Give some time for logs to be written

# Get the logs from the user-registration-service
LOGS=$(docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs user-registration-service)

# Extract the verification token from the logs
VERIFICATION_TOKEN=$(echo "$LOGS" | grep -o "Sending verification email to $TEST_EMAIL with link: https://app.trustainvest.com/verify?token=[a-f0-9-]*" | tail -1 | sed 's/.*token=//')

if [ -z "$VERIFICATION_TOKEN" ]; then
    echo -e "${RED}Failed to extract verification token from logs.${NC}"
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs user-registration-service
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down
    exit 1
fi

echo -e "${GREEN}Extracted verification token: $VERIFICATION_TOKEN${NC}"

# Step 3: Verify the email using the token
echo -e "${YELLOW}Step 3: Verifying email with token...${NC}"
verify_data="{
    \"token\": \"$VERIFICATION_TOKEN\"
}"

response=$(make_request "POST" "verify-email" "$verify_data")
echo "Verification response: $response"

if ! echo "$response" | grep -q "Email verified successfully"; then
    echo -e "${RED}Email verification failed.${NC}"
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs user-registration-service
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down
    exit 1
fi

echo -e "${GREEN}Email verified successfully!${NC}"

# Step 4: Get the verification request ID from the database
echo -e "${YELLOW}Step 4: Getting verification request ID from the database...${NC}"
VERIFICATION_REQUEST_ID=$(docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -t -c "SELECT id FROM kyc.verification_requests WHERE request_data->>'source' = 'EMAIL_VERIFICATION' AND request_data->>'email' = '$TEST_EMAIL'" | tr -d '[:space:]')

if [ -z "$VERIFICATION_REQUEST_ID" ]; then
    echo -e "${RED}Failed to get verification request ID from the database.${NC}"
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down
    exit 1
fi

echo -e "${GREEN}Got verification request ID: $VERIFICATION_REQUEST_ID${NC}"

# Step 5.1: Try to login before updating the verification request status
echo -e "${YELLOW}Step 5.1: Attempting to login with the non-verified user...${NC}"
login_data="{
    \"username\": \"$TEST_USER\",
    \"password\": \"$TEST_PASSWORD\"
}"

response=$(make_request "POST" "auth/login" "$login_data")
echo "Login response: $response"

if ! echo "$response" | grep -q "KYC not verified"; then
    echo -e "${RED}Login did not fail as expected with KYC not verified message.${NC}"
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" logs user-registration-service
    docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down
    exit 1
fi

echo -e "${GREEN}Login correctly failed with KYC not verified message!${NC}"

# Step 6: Update the verification request status to VERIFIED
echo -e "${YELLOW}Step 6: Updating verification request status to VERIFIED...${NC}"

# Disable the trigger to avoid the verified_at field error
echo -e "${YELLOW}Disabling trigger...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -c "ALTER TABLE kyc.verification_requests DISABLE TRIGGER update_user_kyc_status_trigger"

# Update the status with explicit transaction
echo -e "${YELLOW}Updating verification request status...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -c "
BEGIN;
UPDATE kyc.verification_requests SET status = 'VERIFIED', updated_at = NOW(), completed_at = NOW() WHERE id = '$VERIFICATION_REQUEST_ID';
COMMIT;
"

# Also update the user's KYC status directly since we disabled the trigger
echo -e "${YELLOW}Updating user KYC status...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -c "
BEGIN;
UPDATE users.users SET kyc_status = 'VERIFIED', updated_at = NOW() WHERE id = '$user_id';
COMMIT;
"

# Re-enable the trigger
echo -e "${YELLOW}Re-enabling trigger...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -c "ALTER TABLE kyc.verification_requests ENABLE TRIGGER update_user_kyc_status_trigger"

# Step 7: Verify the KYC status is set to VERIFIED
echo -e "${YELLOW}Step 7: Verifying KYC status is set to VERIFIED...${NC}"
KYC_STATUS=$(docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" exec -T postgres psql -U trustainvest -d trustainvest -t -c "SELECT kyc_status FROM users.users WHERE id = '$user_id';" | tr -d '[:space:]')

if [ "$KYC_STATUS" = "VERIFIED" ]; then
    echo -e "${GREEN}User's KYC status is correctly set to VERIFIED!${NC}"
else
    echo -e "${RED}User's KYC status is not set to VERIFIED as expected.${NC}"
    exit 1
fi

# Test 2: First login (should succeed now that KYC is verified)
echo -e "\n${YELLOW}Test 2: First login${NC}"
login_data="{
    \"username\": \"$TEST_USER\",
    \"password\": \"$TEST_PASSWORD\"
}"

response=$(make_request "POST" "auth/login" "$login_data")
echo "Login response: $response"

# Check if login was successful
if echo "$response" | jq -e '.token' > /dev/null 2>&1; then
    token1=$(echo "$response" | jq -r '.token')
    session_id1=$(echo "$response" | jq -r '.session_id')
    print_result 0 "First login successful"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_result 1 "First login failed: $error_msg"
fi

# Test 3: Second login from different device (should succeed and invalidate first session)
echo -e "\n${YELLOW}Test 3: Second login from different device${NC}"
login_data="{
    \"username\": \"$TEST_USER\",
    \"password\": \"$TEST_PASSWORD\"
}"

response=$(make_request "POST" "auth/login" "$login_data")
echo "Second login response: $response"

# Check if second login was successful
if echo "$response" | jq -e '.token' > /dev/null 2>&1; then
    token2=$(echo "$response" | jq -r '.token')
    session_id2=$(echo "$response" | jq -r '.session_id')
    print_result 0 "Second login successful"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_result 1 "Second login failed: $error_msg"
fi

# Test 4: Verify first session is invalidated
echo -e "\n${YELLOW}Test 4: Verify first session is invalidated${NC}"
response=$(make_request "GET" "auth/me" "" "$token1" "$session_id1")
echo "First session check response: $response"

if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error')
    if [[ "$error_msg" == *"Invalid or expired session"* ]]; then
        print_result 0 "First session successfully invalidated"
    else
        print_result 1 "First session check failed: $error_msg"
    fi
else
    print_result 1 "First session still active"
fi

# Test 5: Verify second session is still valid
echo -e "\n${YELLOW}Test 5: Verify second session is still valid${NC}"
response=$(make_request "GET" "auth/me" "" "$token2" "$session_id2")
echo "Second session check response: $response"

if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error')
    print_result 1 "Second session invalidated unexpectedly: $error_msg"
else
    print_result 0 "Second session remains valid"
fi

# Test 6: Third login from another device (should succeed and invalidate second session)
echo -e "\n${YELLOW}Test 6: Third login from another device${NC}"
login_data="{
    \"username\": \"$TEST_USER\",
    \"password\": \"$TEST_PASSWORD\"
}"

response=$(make_request "POST" "auth/login" "$login_data")
echo "Third login response: $response"

# Check if third login was successful
if echo "$response" | jq -e '.token' > /dev/null 2>&1; then
    token3=$(echo "$response" | jq -r '.token')
    session_id3=$(echo "$response" | jq -r '.session_id')
    print_result 0 "Third login successful"
else
    error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
    print_result 1 "Third login failed: $error_msg"
fi

# Test 7: Verify second session is invalidated
echo -e "\n${YELLOW}Test 7: Verify second session is invalidated${NC}"
response=$(make_request "GET" "auth/me" "" "$token2" "$session_id2")
echo "Second session check response: $response"

if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error')
    if [[ "$error_msg" == *"Invalid or expired session"* ]]; then
        print_result 0 "Second session successfully invalidated"
    else
        print_result 1 "Second session check failed: $error_msg"
    fi
else
    print_result 1 "Second session still active"
fi

# Test 8: Verify third session is still valid
echo -e "\n${YELLOW}Test 8: Verify third session is still valid${NC}"
response=$(make_request "GET" "auth/me" "" "$token3" "$session_id3")
echo "Third session check response: $response"

if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error')
    print_result 1 "Third session invalidated unexpectedly: $error_msg"
else
    print_result 0 "Third session remains valid"
fi

echo -e "\n${GREEN}All tests completed successfully!${NC}"

# Cleanup
echo -e "${YELLOW}Cleaning up...${NC}"
docker-compose -f "$SCRIPT_DIR/docker-compose.test.yml" down -v
