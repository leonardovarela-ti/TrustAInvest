#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if verification request ID is provided
if [ -z "$1" ]; then
    print_error "Please provide a verification request ID"
    echo "Usage: $0 <verification_request_id> [compose_file]"
    exit 1
fi

VERIFICATION_REQUEST_ID=$1

# Check if a specific compose file was provided
if [ -n "$2" ]; then
    COMPOSE_FILE=$2
else
    COMPOSE_FILE="docker-compose.yml"
fi

# Step 1: Update verification request status
print_step "Updating verification request status to VERIFIED..."
if docker-compose -f "$COMPOSE_FILE" exec postgres psql -U trustainvest -d trustainvest -c "BEGIN; UPDATE kyc.verification_requests SET status = 'VERIFIED', updated_at = NOW() WHERE id = '$VERIFICATION_REQUEST_ID'; COMMIT;" | grep -q "UPDATE 1"; then
    print_success "Verification request status updated successfully"
else
    print_error "Failed to update verification request status"
    exit 1
fi

# Step 2: Update user's KYC status
print_step "Updating user's KYC status to VERIFIED..."
if docker-compose -f "$COMPOSE_FILE" exec postgres psql -U trustainvest -d trustainvest -c "BEGIN; UPDATE users.users SET kyc_status = 'VERIFIED', updated_at = NOW() WHERE id = (SELECT user_id FROM kyc.verification_requests WHERE id = '$VERIFICATION_REQUEST_ID'); COMMIT;" | grep -q "UPDATE 1"; then
    print_success "User's KYC status updated successfully"
else
    print_error "Failed to update user's KYC status"
    exit 1
fi

# Step 3: Fix and re-enable the trigger
print_step "Fixing and re-enabling the KYC status update trigger..."
if docker-compose -f "$COMPOSE_FILE" exec postgres psql -U trustainvest -d trustainvest -c "
CREATE OR REPLACE FUNCTION kyc.update_user_kyc_status() 
RETURNS TRIGGER AS \$\$ 
BEGIN 
    IF NEW.status = 'VERIFIED' THEN 
        UPDATE users.users SET kyc_status = 'VERIFIED', updated_at = NOW() WHERE id = NEW.user_id;
    ELSIF NEW.status = 'REJECTED' THEN 
        UPDATE users.users SET kyc_status = 'REJECTED', updated_at = NOW() WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_kyc_status_trigger ON kyc.verification_requests;
CREATE TRIGGER update_user_kyc_status_trigger 
AFTER UPDATE ON kyc.verification_requests 
FOR EACH ROW 
EXECUTE FUNCTION kyc.update_user_kyc_status();" | grep -q "CREATE TRIGGER"; then
    print_success "Trigger fixed and re-enabled successfully"
else
    print_error "Failed to fix and re-enable trigger"
    exit 1
fi

print_success "KYC verification process completed successfully!"
echo -e "${GREEN}Verification request ID:${NC} $VERIFICATION_REQUEST_ID"
