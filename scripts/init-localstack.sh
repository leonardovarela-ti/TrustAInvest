#!/bin/bash
set -e

echo "Initializing LocalStack resources for TrustAInvest.com..."

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:4566/health | grep -q "\"s3\": \"running\""; then
    echo "LocalStack is ready!"
    break
  fi
  echo "Waiting for LocalStack... ($i/30)"
  sleep 1
done

# Set up AWS CLI with localstack endpoint
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Create S3 buckets
echo "Creating S3 buckets..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-documents || true
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-artifacts || true
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-kyc-documents || true

# Create DynamoDB tables
echo "Creating DynamoDB tables..."
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name user-sessions \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    || true

aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name market-data \
    --attribute-definitions AttributeName=symbol,AttributeType=S AttributeName=timestamp,AttributeType=N \
    --key-schema AttributeName=symbol,KeyType=HASH AttributeName=timestamp,KeyType=RANGE \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    || true

# Create Cognito User Pool
echo "Creating Cognito User Pool..."
aws --endpoint-url=http://localhost:4566 cognito-idp create-user-pool \
    --pool-name trustainvest-user-pool \
    --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":true}}' \
    --auto-verified-attributes email \
    --schema '[{"Name":"email","Required":true},{"Name":"phone_number","Required":false}]' \
    --mfa-configuration OFF \
    || true

# Create KMS key for encryption
echo "Creating KMS key..."
KMS_KEY_ID=$(aws --endpoint-url=http://localhost:4566 kms create-key --description "TrustAInvest KMS Key" --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "dummy-key-id")
aws --endpoint-url=http://localhost:4566 kms create-alias --alias-name alias/trustainvest-key --target-key-id "$KMS_KEY_ID" 2>/dev/null || true
echo "Created KMS key with ID: $KMS_KEY_ID"

# Create API Gateway
echo "Creating API Gateway..."
aws --endpoint-url=http://localhost:4566 apigateway create-rest-api \
    --name trustainvest-api \
    || true

# Create SQS queues
echo "Creating SQS queues..."
aws --endpoint-url=http://localhost:4566 sqs create-queue \
    --queue-name notification-queue \
    || true

aws --endpoint-url=http://localhost:4566 sqs create-queue \
    --queue-name document-processing-queue \
    || true

aws --endpoint-url=http://localhost:4566 sqs create-queue \
    --queue-name kyc-queue \
    || true

# Create SNS topics
echo "Creating SNS topics..."
aws --endpoint-url=http://localhost:4566 sns create-topic \
    --name user-events \
    || true

aws --endpoint-url=http://localhost:4566 sns create-topic \
    --name transaction-events \
    || true

KYC_TOPIC_ARN=$(aws --endpoint-url=http://localhost:4566 sns create-topic --name kyc-topic --query 'TopicArn' --output text || echo "arn:aws:sns:us-east-1:000000000000:kyc-topic")
NOTIFICATION_TOPIC_ARN=$(aws --endpoint-url=http://localhost:4566 sns create-topic --name notification-topic --query 'TopicArn' --output text || echo "arn:aws:sns:us-east-1:000000000000:notification-topic")

# Subscribe queues to topics
echo "Subscribing queues to topics..."
aws --endpoint-url=http://localhost:4566 sns subscribe \
    --topic-arn "arn:aws:sns:us-east-1:000000000000:user-events" \
    --protocol sqs \
    --notification-endpoint http://localhost:4566/000000000000/notification-queue \
    || true

aws --endpoint-url=http://localhost:4566 sns subscribe \
    --topic-arn "arn:aws:sns:us-east-1:000000000000:transaction-events" \
    --protocol sqs \
    --notification-endpoint http://localhost:4566/000000000000/notification-queue \
    || true

aws --endpoint-url=http://localhost:4566 sns subscribe \
    --topic-arn "$KYC_TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint http://localhost:4566/000000000000/kyc-queue \
    || true

aws --endpoint-url=http://localhost:4566 sns subscribe \
    --topic-arn "$NOTIFICATION_TOPIC_ARN" \
    --protocol sqs \
    --notification-endpoint http://localhost:4566/000000000000/notification-queue \
    || true

echo "LocalStack resources initialized successfully!"