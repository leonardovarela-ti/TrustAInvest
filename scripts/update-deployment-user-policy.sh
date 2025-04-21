#!/bin/bash

# Script to update the IAM policy for the TrustAInvest deployment user
# This script updates the IAM policy with the necessary permissions for Terraform deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
POLICY_NAME="TrustAInvestDeploymentPolicy"
USER_NAME="trust-ai-deployment"
POLICY_FILE="updated-deployment-policy.json"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if the policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}Error: Policy file $POLICY_FILE not found.${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking if policy $POLICY_NAME exists...${NC}"

# Check if the policy exists
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" == "None" ]; then
    echo -e "${YELLOW}Policy $POLICY_NAME does not exist. Creating new policy...${NC}"
    
    # Create the policy
    POLICY_ARN=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://$POLICY_FILE --query 'Policy.Arn' --output text)
    
    echo -e "${GREEN}Policy $POLICY_NAME created with ARN: $POLICY_ARN${NC}"
else
    echo -e "${YELLOW}Policy $POLICY_NAME exists. Updating policy...${NC}"
    
    # Check if we have reached the limit of 5 versions
    POLICY_VERSIONS=$(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query "Versions[?!IsDefaultVersion].VersionId" --output text)
    VERSION_COUNT=$(echo "$POLICY_VERSIONS" | wc -w)
    
    if [ "$VERSION_COUNT" -ge 4 ]; then
        echo -e "${YELLOW}Policy has reached the maximum number of versions. Deleting oldest non-default version...${NC}"
        OLDEST_VERSION=$(echo "$POLICY_VERSIONS" | tr '\t' '\n' | head -1)
        aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$OLDEST_VERSION"
        echo -e "${GREEN}Deleted policy version $OLDEST_VERSION.${NC}"
    fi
    
    # Create a new version of the policy
    aws iam create-policy-version --policy-arn "$POLICY_ARN" --policy-document file://$POLICY_FILE --set-as-default
    
    echo -e "${GREEN}Policy $POLICY_NAME updated.${NC}"
fi

echo -e "${YELLOW}Checking if user $USER_NAME exists...${NC}"

# Check if the user exists
USER_EXISTS=$(aws iam get-user --user-name "$USER_NAME" 2>/dev/null || echo "false")

if [ "$USER_EXISTS" == "false" ]; then
    echo -e "${RED}Error: User $USER_NAME does not exist. Please create the user first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Attaching policy to user $USER_NAME...${NC}"

# Detach any existing policy with the same name
ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$USER_NAME" --query "AttachedPolicies[?PolicyName=='$POLICY_NAME'].PolicyArn" --output text)

if [ -n "$ATTACHED_POLICIES" ] && [ "$ATTACHED_POLICIES" != "None" ]; then
    echo -e "${YELLOW}Detaching existing policy from user $USER_NAME...${NC}"
    aws iam detach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN"
fi

# Attach the policy to the user
aws iam attach-user-policy --user-name "$USER_NAME" --policy-arn "$POLICY_ARN"

echo -e "${GREEN}Policy $POLICY_NAME attached to user $USER_NAME.${NC}"
echo -e "${GREEN}Deployment user policy update completed successfully.${NC}"
echo -e "${YELLOW}Note: You may need to wait a few minutes for the policy changes to propagate.${NC}"
