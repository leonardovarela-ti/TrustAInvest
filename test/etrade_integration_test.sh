#!/bin/bash

# E-Trade Integration Test Script
# This script tests the E-Trade integration by making API calls to the etrade-service

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

# Set variables
API_BASE_URL="http://localhost:8087/api/v1"

# Get the demo user ID from the database
echo "Fetching demo user ID from database..."
if command -v docker &> /dev/null; then
  # Try to find a PostgreSQL container
  POSTGRES_CONTAINER=$(docker ps --filter "name=postgres" --format "{{.Names}}" | grep -E 'postgres|db|database' | head -n 1)
  
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
  CONSUMER_KEY="${ETRADE_CONSUMER_KEY}"
  CONSUMER_SECRET="${ETRADE_CONSUMER_SECRET}"
  echo "Using E-Trade credentials from .env file."
elif [ -f ".env" ]; then
  source ".env"
  CONSUMER_KEY="${ETRADE_CONSUMER_KEY}"
  CONSUMER_SECRET="${ETRADE_CONSUMER_SECRET}"
  echo "Using E-Trade credentials from .env file."
elif [ -z "${ETRADE_CONSUMER_KEY}" ] || [ -z "${ETRADE_CONSUMER_SECRET}" ]; then
  print_status "warning" "ETRADE_CONSUMER_KEY or ETRADE_CONSUMER_SECRET environment variables are not set."
  echo "Using default values for testing. This will likely fail with real E-Trade API."
  CONSUMER_KEY="demo_key"
  CONSUMER_SECRET="demo_secret"
else
  CONSUMER_KEY="${ETRADE_CONSUMER_KEY}"
  CONSUMER_SECRET="${ETRADE_CONSUMER_SECRET}"
  echo "Using E-Trade credentials from environment variables."
fi

CALLBACK_URL="oob"

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
  if curl -s --connect-timeout 5 http://localhost:8087 > /dev/null; then
    print_status "success" "Connected to etrade-service"
  else
    print_status "error" "Failed to connect to etrade-service. Make sure it's running."
    exit 1
  fi
else
  # Check if the etrade-service is running
  echo "Testing connection to etrade-service..."
  # Try to connect to the service, but don't check for a specific endpoint
  # Just verify that the service is accepting connections
  if nc -z localhost 8087 2>/dev/null; then
    print_status "success" "Connected to etrade-service"
  else
    print_status "error" "Failed to connect to etrade-service. Make sure it's running."
    exit 1
  fi
fi

# Wait a moment to ensure the service is fully initialized
sleep 2

# Step 1: Initiate OAuth flow
echo -e "\n1. Initiating OAuth flow..."
initiate_data="{\"user_id\":\"$USER_ID\", \"consumer_key\":\"$CONSUMER_KEY\", \"callback_url\":\"$CALLBACK_URL\"}"
echo "Request data: $(echo $initiate_data | jq -c '.')"
initiate_response=$(make_api_call "POST" "/etrade/auth/initiate" "$initiate_data")

# Check if the initiate request was successful
if echo "$initiate_response" | jq -e '.auth_url' > /dev/null 2>&1; then
  auth_url=$(echo "$initiate_response" | jq -r '.auth_url')
  request_token=$(echo "$initiate_response" | jq -r '.request_token')
  print_status "success" "OAuth flow initiated"
  echo "Auth URL: $auth_url"
  echo "Request Token: $request_token"
else
  print_status "error" "Failed to initiate OAuth flow"
  echo "Response: $(echo $initiate_response | jq -c '.')"
  exit 1
fi

# Step 2: Automated authorization using Python script
echo -e "\n2. Automated authorization"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
  print_status "error" "Python 3 is not installed. Please install it to use the automated authorization."
  echo -e "\nFalling back to manual authorization..."
  echo "Please follow these steps:"
  echo "1. Open the Auth URL in your browser: $auth_url"
  echo "2. Log in with your E-Trade credentials"
  echo "3. Authorize the application when prompted"
  echo "4. You will be redirected to a callback URL with a verification code"
  echo "5. Look for 'oauth_verifier' parameter in the URL (e.g., http://localhost:3002/etrade/callback?oauth_token=xxx&oauth_verifier=ABCDEF)"
  echo "6. Copy the value of the 'oauth_verifier' parameter (e.g., ABCDEF)"
  echo ""
  read -p "Verification Code: " verifier
else
  # Check if required Python packages are installed
  echo "Checking Python dependencies..."
  
  # Check if selenium and webdriver-manager are installed
  MISSING_PACKAGES=()
  if ! python3 -c "import selenium" &> /dev/null; then
    MISSING_PACKAGES+=("selenium")
  fi
  if ! python3 -c "import webdriver_manager" &> /dev/null; then
    MISSING_PACKAGES+=("webdriver-manager")
  fi
  
  if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    print_status "warning" "Missing Python packages: ${MISSING_PACKAGES[*]}. Installing..."
    pip3 install ${MISSING_PACKAGES[@]}
    if [ $? -ne 0 ]; then
      print_status "error" "Failed to install required packages. Falling back to manual authorization."
      echo "Please follow these steps:"
      echo "1. Open the Auth URL in your browser: $auth_url"
      echo "2. Log in with your E-Trade credentials"
      echo "3. Authorize the application when prompted"
      echo "4. You will be redirected to a callback URL with a verification code"
      echo "5. Look for 'oauth_verifier' parameter in the URL (e.g., http://localhost:3002/etrade/callback?oauth_token=xxx&oauth_verifier=ABCDEF)"
      echo "6. Copy the value of the 'oauth_verifier' parameter (e.g., ABCDEF)"
      echo ""
      read -p "Verification Code: " verifier
    fi
  fi
  
  # If selenium is installed, use the Python script to get the verification code
  if python3 -c "import selenium" &> /dev/null; then
    print_status "success" "Using automated authorization with Python script."
    
    # Prompt for E-Trade credentials
    echo "Please enter your E-Trade credentials:"
    read -p "Username: " etrade_username
    read -s -p "Password: " etrade_password
    echo ""
    
    # Run the Python script to get the verification code
    echo "Running automated authorization script..."
    
    # Find the Python script
    SCRIPT_PATH=""
    if [ -f "../scripts/get_etrade_verifier.py" ]; then
      SCRIPT_PATH="../scripts/get_etrade_verifier.py"
    elif [ -f "scripts/get_etrade_verifier.py" ]; then
      SCRIPT_PATH="scripts/get_etrade_verifier.py"
    else
      print_status "error" "Could not find get_etrade_verifier.py script."
      echo "Please follow these steps:"
      echo "1. Open the Auth URL in your browser: $auth_url"
      echo "2. Log in with your E-Trade credentials"
      echo "3. Authorize the application when prompted"
      echo "4. You will be redirected to a callback URL with a verification code"
      echo "5. Look for 'oauth_verifier' parameter in the URL (e.g., http://localhost:3002/etrade/callback?oauth_token=xxx&oauth_verifier=ABCDEF)"
      echo "6. Copy the value of the 'oauth_verifier' parameter (e.g., ABCDEF)"
      echo ""
      read -p "Verification Code: " verifier
    fi
    
    # Run the script if found
    if [ -n "$SCRIPT_PATH" ]; then
      # Create a temporary file for stderr output
      STDERR_FILE=$(mktemp)
      
      # Run the script, capturing stdout for the verifier and stderr to a file
      verifier=$(python3 "$SCRIPT_PATH" "$auth_url" "$etrade_username" "$etrade_password" 2>"$STDERR_FILE")
      
      # Check if the script was successful
      if [ -z "$verifier" ]; then
      print_status "error" "Failed to get verification code automatically."
      echo "Debug information:"
      cat "$STDERR_FILE"
      echo ""
      print_status "warning" "Falling back to manual authorization."
      echo "Please follow these steps:"
      echo "1. Open the Auth URL in your browser: $auth_url"
      echo "2. Log in with your E-Trade credentials"
      echo "3. Authorize the application when prompted"
      echo "4. You will be redirected to a callback URL with a verification code"
      echo "5. Look for 'oauth_verifier' parameter in the URL (e.g., http://localhost:3002/etrade/callback?oauth_token=xxx&oauth_verifier=ABCDEF)"
      echo "6. Copy the value of the 'oauth_verifier' parameter (e.g., ABCDEF)"
      echo ""
      read -p "Verification Code: " verifier
      else
        print_status "success" "Got verification code automatically: $verifier"
        
        # Simulate the callback from E-Trade by making a request to the callback service
        echo -e "\n2.1. Simulating callback from E-Trade..."
        CALLBACK_FULL_URL="${CALLBACK_URL}?oauth_token=${request_token}&oauth_verifier=${verifier}"
        echo "Sending request to: $CALLBACK_FULL_URL"
        
        # Make the request to the callback URL
        callback_result=$(curl -s -o /dev/null -w "%{http_code}" "$CALLBACK_FULL_URL")
        
        if [ "$callback_result" == "200" ]; then
          print_status "success" "Callback simulation successful"
        else
          print_status "warning" "Callback simulation returned status code: $callback_result"
          print_status "warning" "This is not critical, continuing with direct API call..."
        fi
      fi
      
      # Clean up the temporary file
      rm -f "$STDERR_FILE"
    fi
  fi
fi

if [ -z "$verifier" ]; then
  print_status "error" "Verification code is required"
  exit 1
fi

# Step 3: Complete OAuth flow
echo -e "\n3. Completing OAuth flow..."
# If the callback simulation was successful, the etrade-service should already have the verification code
# But we'll make the API call directly as well to ensure it works
callback_data="{\"request_token\":\"$request_token\", \"verifier\":\"$verifier\", \"user_id\":\"$USER_ID\"}"
callback_response=$(make_api_call "POST" "/etrade/auth/callback" "$callback_data")

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

# Step 4: Get E-Trade accounts
echo -e "\n4. Getting E-Trade accounts..."
accounts_response=$(make_api_call "GET" "/etrade/accounts?user_id=$USER_ID")

# Check if the accounts request was successful
if echo "$accounts_response" | jq -e '.accounts' > /dev/null 2>&1; then
  accounts_count=$(echo "$accounts_response" | jq '.accounts | length')
  print_status "success" "Retrieved $accounts_count E-Trade accounts"
  
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
  print_status "error" "Failed to get E-Trade accounts"
  echo "Response: $(echo $accounts_response | jq -c '.')"
  exit 1
fi

# Step 5: Link an E-Trade account
echo -e "\n5. Linking E-Trade account..."
link_data="{\"user_id\":\"$USER_ID\", \"account_id\":\"$first_account_id\", \"account_name\":\"$first_account_name\"}"
link_response=$(make_api_call "POST" "/etrade/accounts/link" "$link_data")

# Check if the link request was successful
if echo "$link_response" | jq -e '.success' > /dev/null 2>&1; then
  internal_id=$(echo "$link_response" | jq -r '.internal_id')
  print_status "success" "E-Trade account linked successfully"
  echo "Internal Account ID: $internal_id"
else
  print_status "error" "Failed to link E-Trade account"
  echo "Response: $(echo $link_response | jq -c '.')"
  exit 1
fi

echo -e "\nE-Trade integration test completed successfully!"
