#!/bin/bash

# Capital One Integration Test Script
# This script tests the Capital One integration by making API calls to the capitalone-service

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  if [ "$1" == "success" ]; then
    echo -e "${GREEN}✓ $2${NC}"
  elif [ "$1" == "error" ]; then
    echo -e "${RED}✗ $2${NC}"
  else
    echo -e "${YELLOW}! $2${NC}"
  fi
}

# Set variables - use environment variables if available
API_BASE_URL="${CAPITALONE_API_URL:-http://localhost:8088/api/v1}"
echo "Using API base URL: $API_BASE_URL"

# Get the demo user ID from the database
echo "Fetching demo user ID from database..."
if command -v docker &> /dev/null; then
  # Try to find a PostgreSQL container using the container prefix from the test environment
  POSTGRES_CONTAINER="${CONTAINER_PREFIX:-test}-postgres"
  
  if ! docker ps --filter "name=$POSTGRES_CONTAINER" --format "{{.Names}}" | grep -q "$POSTGRES_CONTAINER"; then
    print_status "warning" "No PostgreSQL container found with name $POSTGRES_CONTAINER. Looking for any PostgreSQL container..."
    POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | grep -E 'postgres|db|database' | head -n 1)
  fi
  
  if [ -z "$POSTGRES_CONTAINER" ]; then
    print_status "warning" "No PostgreSQL container found by name. Looking for any PostgreSQL container..."
    POSTGRES_CONTAINER=$(docker ps --filter "ancestor=postgres" --format "{{.Names}}" | head -n 1)
  fi
  
  if [ -z "$POSTGRES_CONTAINER" ]; then
    print_status "warning" "No PostgreSQL container found. Using demo user ID."
    # Use the demo user ID that was created during database initialization
    USER_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "550e8400-e29b-41d4-a716-446655440000")
  else
    echo "Found PostgreSQL container: $POSTGRES_CONTAINER"
    # Try to get the user ID using docker
    USER_ID=$(docker exec -i $POSTGRES_CONTAINER psql -U trustainvest -d trustainvest -t -c "SELECT id FROM users.users WHERE username = 'demo_user'" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$USER_ID" ]; then
      print_status "warning" "Demo user not found. Creating demo user..."
      
      # Create the SQL command to create the demo user
      SQL_COMMAND="INSERT INTO users.users (
        username, email, first_name, last_name, date_of_birth, 
        street, city, state, zip_code, country, risk_profile, password_hash
      ) 
      SELECT 
        'demo_user', 'demo@trustainvest.com', 'Demo', 'User', '1980-01-01',
        '123 Main St', 'New York', 'NY', '10001', 'USA', 'MODERATE', 'testhash'
      WHERE NOT EXISTS (
        SELECT 1 FROM users.users WHERE username = 'demo_user'
      );
      SELECT id FROM users.users WHERE username = 'demo_user';"
      
      # Run the SQL command
      USER_ID=$(docker exec -i $POSTGRES_CONTAINER psql -U trustainvest -d trustainvest -t -c "$SQL_COMMAND" 2>/dev/null | tail -n 1 | tr -d '[:space:]')
      
      if [ -z "$USER_ID" ]; then
        print_status "warning" "Failed to create demo user. Using generated UUID."
        USER_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "550e8400-e29b-41d4-a716-446655440000")
      else
        print_status "success" "Created demo user with ID: $USER_ID"
      fi
    else
      print_status "success" "Got demo user ID from database: $USER_ID"
    fi
  fi
else
  print_status "warning" "Docker not found. Using generated UUID."
  USER_ID=$(uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || echo "550e8400-e29b-41d4-a716-446655440000")
fi

echo "Using user ID: $USER_ID"

# Use the credentials directly from the .env file
if [ -f "../.env" ]; then
  source "../.env"
  CLIENT_ID="${CAPITALONE_CLIENT_ID}"
  CLIENT_SECRET="${CAPITALONE_CLIENT_SECRET}"
  REDIRECT_URI="${CAPITALONE_REDIRECT_URI}"
  echo "Using Capital One credentials from .env file."
elif [ -f ".env" ]; then
  source ".env"
  CLIENT_ID="${CAPITALONE_CLIENT_ID}"
  CLIENT_SECRET="${CAPITALONE_CLIENT_SECRET}"
  REDIRECT_URI="${CAPITALONE_REDIRECT_URI}"
  echo "Using Capital One credentials from .env file."
elif [ -z "${CAPITALONE_CLIENT_ID}" ] || [ -z "${CAPITALONE_CLIENT_SECRET}" ] || [ -z "${CAPITALONE_REDIRECT_URI}" ]; then
  print_status "warning" "CAPITALONE_CLIENT_ID, CAPITALONE_CLIENT_SECRET, or CAPITALONE_REDIRECT_URI environment variables are not set."
  echo "Using default values for testing. This will likely fail with real Capital One API."
  CLIENT_ID="demo_client_id"
  CLIENT_SECRET="demo_client_secret"
  REDIRECT_URI="http://localhost:3000/callback"
else
  CLIENT_ID="${CAPITALONE_CLIENT_ID}"
  CLIENT_SECRET="${CAPITALONE_CLIENT_SECRET}"
  REDIRECT_URI="${CAPITALONE_REDIRECT_URI}"
  echo "Using Capital One credentials from environment variables."
fi

# Function to make API calls
make_api_call() {
  local method="$1"
  local endpoint="$2"
  local data="$3"
  local url="${API_BASE_URL}${endpoint}"

  if [ "$method" == "GET" ]; then
    curl -s -X GET "$url"
  else
    curl -s -X "$method" "$url" \
      -H "Content-Type: application/json" \
      -d "$data"
  fi
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  print_status "error" "jq is not installed. Please install it to parse JSON responses."
  echo "On Ubuntu/Debian: sudo apt-get install jq"
  echo "On macOS: brew install jq"
  exit 1
fi

# Check if nc (netcat) is installed
if ! command -v nc &> /dev/null; then
  print_status "error" "nc (netcat) is not installed. Please install it to check connectivity."
  echo "On Ubuntu/Debian: sudo apt-get install netcat"
  echo "On macOS: It should be pre-installed, but you can install it with 'brew install netcat'"
  
  # Fallback to curl for connectivity check
  echo "Falling back to curl for connectivity check..."
  if curl -s --connect-timeout 5 "${API_BASE_URL}/health" > /dev/null; then
    print_status "success" "Connected to capitalone-service"
  else
    print_status "error" "Failed to connect to capitalone-service. Make sure it's running."
    exit 1
  fi
else
  # Check if the capitalone-service is running
  echo "Testing connection to capitalone-service..."
  # Extract host and port from API_BASE_URL
  API_HOST=$(echo $API_BASE_URL | sed -E 's|^https?://([^:/]+).*|\1|')
  API_PORT=$(echo $API_BASE_URL | sed -E 's|^https?://[^:]+:([0-9]+).*|\1|')
  if [ "$API_HOST" = "$API_BASE_URL" ]; then
    # Default to port 80 for HTTP if no port specified
    API_PORT=80
  fi
  
  echo "Checking connection to $API_HOST:$API_PORT..."
  if nc -z $API_HOST $API_PORT 2>/dev/null; then
    print_status "success" "Connected to capitalone-service at $API_HOST:$API_PORT"
  else
    print_status "error" "Failed to connect to capitalone-service at $API_HOST:$API_PORT. Make sure it's running."
    exit 1
  fi
fi

# Wait a moment to ensure the service is fully initialized
sleep 2

# Step 1: Initiate OAuth flow
echo -e "\n1. Initiating OAuth flow..."
initiate_data="{\"user_id\":\"$USER_ID\", \"client_id\":\"$CLIENT_ID\", \"redirect_uri\":\"$REDIRECT_URI\"}"
echo "Request data: $(echo $initiate_data | jq -c '.')"
initiate_response=$(make_api_call "POST" "/capitalone/auth/initiate" "$initiate_data")

# Check if the initiate request was successful
if echo "$initiate_response" | jq -e '.auth_url' > /dev/null 2>&1; then
  auth_url=$(echo "$initiate_response" | jq -r '.auth_url')
  state=$(echo "$initiate_response" | jq -r '.state')
  print_status "success" "OAuth flow initiated"
  echo "Auth URL: $auth_url"
  echo "State: $state"
else
  print_status "error" "Failed to initiate OAuth flow"
  echo "Response: $(echo $initiate_response | jq -c '.')"
  exit 1
fi

# Step 2: Manual authorization
echo -e "\n2. Manual authorization required"
echo "Please follow these steps:"
echo "1. Open the Auth URL in your browser: $auth_url"
echo "2. Log in with your Capital One credentials"
echo "3. Authorize the application when prompted"
echo "4. You will be redirected to the callback URL with a code parameter"
echo "5. Copy the entire URL you were redirected to"
echo ""
read -p "Redirect URL: " redirect_url

# Extract the code and state from the redirect URL
if [ -z "$redirect_url" ]; then
  print_status "error" "Redirect URL is required"
  exit 1
fi

# Extract the code parameter from the URL
code=$(echo "$redirect_url" | grep -oP 'code=\K[^&]+' || echo "")
if [ -z "$code" ]; then
  print_status "error" "Could not extract code from redirect URL"
  echo "The redirect URL should contain a 'code' parameter"
  exit 1
fi

# Extract the state parameter from the URL
url_state=$(echo "$redirect_url" | grep -oP 'state=\K[^&]+' || echo "")
if [ -z "$url_state" ]; then
  print_status "error" "Could not extract state from redirect URL"
  echo "The redirect URL should contain a 'state' parameter"
  exit 1
fi

# Verify that the state matches
if [ "$url_state" != "$state" ]; then
  print_status "error" "State mismatch. Expected: $state, Got: $url_state"
  echo "This could indicate a CSRF attack. Aborting."
  exit 1
fi

# Step 3: Complete OAuth flow
echo -e "\n3. Completing OAuth flow..."
callback_data="{\"code\":\"$code\", \"state\":\"$state\", \"user_id\":\"$USER_ID\", \"redirect_uri\":\"$REDIRECT_URI\"}"
echo "Request data: $(echo $callback_data | jq -c '.')"
callback_response=$(make_api_call "POST" "/capitalone/auth/callback" "$callback_data")

# Check if the callback request was successful
if echo "$callback_response" | jq -e '.success' > /dev/null 2>&1; then
  access_token=$(echo "$callback_response" | jq -r '.access_token')
  print_status "success" "OAuth flow completed"
  echo "Access Token: $access_token"
else
  print_status "error" "Failed to complete OAuth flow"
  echo "Response: $(echo $callback_response | jq -c '.')"
  exit 1
fi

# Step 4: Get Capital One accounts
echo -e "\n4. Getting Capital One accounts..."
accounts_response=$(make_api_call "GET" "/capitalone/accounts?user_id=$USER_ID")

# Check if the accounts request was successful
if echo "$accounts_response" | jq -e '.accounts' > /dev/null 2>&1; then
  accounts_count=$(echo "$accounts_response" | jq '.accounts | length')
  print_status "success" "Retrieved $accounts_count Capital One accounts"
  
  # Display account information
  echo -e "\nAccount Information:"
  echo "$accounts_response" | jq -r '.accounts[] | "ID: \(.account_id), Name: \(.account_name), Type: \(.account_type), Balance: \(.balance) \(.currency)"'
  
  # If there are accounts, get the first account ID for linking
  if [ "$accounts_count" -gt 0 ]; then
    first_account_id=$(echo "$accounts_response" | jq -r '.accounts[0].account_id')
    first_account_name=$(echo "$accounts_response" | jq -r '.accounts[0].account_name')
  else
    print_status "warning" "No accounts found to link"
    exit 0
  fi
else
  print_status "error" "Failed to get Capital One accounts"
  echo "Response: $(echo $accounts_response | jq -c '.')"
  exit 1
fi

# Step 5: Link a Capital One account
echo -e "\n5. Linking Capital One account..."
link_data="{\"user_id\":\"$USER_ID\", \"account_id\":\"$first_account_id\", \"account_name\":\"$first_account_name\"}"
link_response=$(make_api_call "POST" "/capitalone/accounts/link" "$link_data")

# Check if the link request was successful
if echo "$link_response" | jq -e '.success' > /dev/null 2>&1; then
  internal_id=$(echo "$link_response" | jq -r '.internal_id')
  print_status "success" "Capital One account linked successfully"
  echo "Internal Account ID: $internal_id"
else
  print_status "error" "Failed to link Capital One account"
  echo "Response: $(echo $link_response | jq -c '.')"
  exit 1
fi

# Step 6: Search for bank products (optional)
echo -e "\n6. Searching for bank products..."
product_id="savings"
search_data="{\"productType\":\"SAVINGS\", \"zipCode\":\"10001\", \"amount\":5000}"
search_response=$(make_api_call "POST" "/capitalone/products/$product_id/search" "$search_data")

# Check if the search request was successful
if echo "$search_response" | jq -e '.products' > /dev/null 2>&1; then
  products_count=$(echo "$search_response" | jq '.products | length')
  print_status "success" "Found $products_count bank products"
  
  # Display product information
  if [ "$products_count" -gt 0 ]; then
    echo -e "\nProduct Information:"
    echo "$search_response" | jq -r '.products[] | "Name: \(.productName), Type: \(.productType), APY: \(.apy)%, Min Deposit: $\(.minimumDeposit)"'
  fi
else
  print_status "warning" "No bank products found or search failed"
  echo "Response: $(echo $search_response | jq -c '.')"
  # Don't exit with error as this is an optional step
fi

echo -e "\nCapital One integration test completed successfully!"
