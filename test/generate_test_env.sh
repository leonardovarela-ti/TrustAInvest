#!/bin/bash

# Usage: ./generate_test_env.sh <test_name>
TEST_NAME=$1

if [ -z "$TEST_NAME" ]; then
  echo "Error: Test name is required"
  echo "Usage: ./generate_test_env.sh <test_name>"
  exit 1
fi

# Generate a unique hash based on the test name
HASH=$(echo $TEST_NAME | md5sum | cut -c1-8)
# Convert hash to a number between 0-99 for port offset
PORT_OFFSET=$((16#${HASH:0:2} % 100))

# Base ports for test environments - using ranges that don't overlap with main app
BASE_PG_PORT=15432       # Well above 5432
BASE_REDIS_PORT=16379    # Well above 6379
BASE_LOCALSTACK_PORT=14566  # Well above 4566
BASE_USER_REG_PORT=18086    # Well above 8086
BASE_KYC_PORT=18090         # Well above 8090

# Calculate unique ports with test-specific offset
PG_PORT=$((BASE_PG_PORT + PORT_OFFSET))
REDIS_PORT=$((BASE_REDIS_PORT + PORT_OFFSET))
LOCALSTACK_PORT=$((BASE_LOCALSTACK_PORT + PORT_OFFSET))
USER_REG_PORT=$((BASE_USER_REG_PORT + PORT_OFFSET))
KYC_PORT=$((BASE_KYC_PORT + PORT_OFFSET))

# Generate unique identifiers for containers, networks, and volumes
TEST_ID="${TEST_NAME}"
PROJECT_NAME="test_${TEST_ID}"
TEST_NETWORK="test-network-${TEST_ID}"
PG_VOLUME="postgres_data_${TEST_ID}"
REDIS_VOLUME="redis_data_${TEST_ID}"
CONTAINER_PREFIX="${PROJECT_NAME}"

# Function to check if a port is already in use
is_port_in_use() {
    netstat -tuln 2>/dev/null | grep -q ":$1 " || lsof -i:$1 2>/dev/null > /dev/null
    return $?
}

# Validate that none of our ports conflict with existing services
validate_ports() {
    local ports=($PG_PORT $REDIS_PORT $LOCALSTACK_PORT $USER_REG_PORT $KYC_PORT)
    local port_names=("PostgreSQL" "Redis" "LocalStack" "User Registration" "KYC Verifier")
    
    for i in "${!ports[@]}"; do
        if is_port_in_use ${ports[$i]}; then
            echo "Warning: Port ${ports[$i]} for ${port_names[$i]} is already in use."
            return 1
        fi
    done
    
    return 0
}

# Try up to 5 different port offsets if needed
MAX_ATTEMPTS=5
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
    if validate_ports; then
        break
    fi
    
    echo "Attempt $attempt: Trying different port offset..."
    PORT_OFFSET=$((PORT_OFFSET + 10))
    PG_PORT=$((BASE_PG_PORT + PORT_OFFSET))
    REDIS_PORT=$((BASE_REDIS_PORT + PORT_OFFSET))
    LOCALSTACK_PORT=$((BASE_LOCALSTACK_PORT + PORT_OFFSET))
    USER_REG_PORT=$((BASE_USER_REG_PORT + PORT_OFFSET))
    KYC_PORT=$((BASE_KYC_PORT + PORT_OFFSET))
    
    attempt=$((attempt + 1))
done

if [ $attempt -gt $MAX_ATTEMPTS ]; then
    echo "Error: Could not find available ports after $MAX_ATTEMPTS attempts."
    exit 1
fi

# Print port information to stderr so it doesn't get captured by eval
>&2 echo "Using ports: PG=$PG_PORT, Redis=$REDIS_PORT, LocalStack=$LOCALSTACK_PORT, UserReg=$USER_REG_PORT, KYC=$KYC_PORT"

# Create docker-compose file from template
COMPOSE_FILE="docker-compose.${TEST_NAME}.yml"
cat $(dirname "$0")/docker-compose.test.template.yml | \
  sed "s/\${PG_PORT}/$PG_PORT/g" | \
  sed "s/\${REDIS_PORT}/$REDIS_PORT/g" | \
  sed "s/\${LOCALSTACK_PORT}/$LOCALSTACK_PORT/g" | \
  sed "s/\${USER_REG_PORT}/$USER_REG_PORT/g" | \
  sed "s/\${KYC_PORT}/$KYC_PORT/g" | \
  sed "s/\${TEST_NETWORK}/$TEST_NETWORK/g" | \
  sed "s/\${PG_VOLUME}/$PG_VOLUME/g" | \
  sed "s/\${REDIS_VOLUME}/$REDIS_VOLUME/g" | \
  sed "s/\${CONTAINER_PREFIX}/$CONTAINER_PREFIX/g" > $(dirname "$0")/$COMPOSE_FILE

# Output the environment variables
echo "export COMPOSE_FILE=$COMPOSE_FILE"
echo "export COMPOSE_PROJECT_NAME=$PROJECT_NAME"
echo "export PG_PORT=$PG_PORT"
echo "export REDIS_PORT=$REDIS_PORT"
echo "export LOCALSTACK_PORT=$LOCALSTACK_PORT"
echo "export USER_REG_PORT=$USER_REG_PORT"
echo "export KYC_PORT=$KYC_PORT"
echo "export TEST_NETWORK=$TEST_NETWORK"
echo "export CONTAINER_PREFIX=$CONTAINER_PREFIX"
echo "export PROJECT_NAME=$PROJECT_NAME"
