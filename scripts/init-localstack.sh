#!/bin/bash
set -e

echo "Initializing LocalStack resources..."

# Create S3 buckets
echo "Creating S3 buckets..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-documents || true
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-artifacts || true

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

# Create SNS topics
echo "Creating SNS topics..."
aws --endpoint-url=http://localhost:4566 sns create-topic \
    --name user-events \
    || true

aws --endpoint-url=http://localhost:4566 sns create-topic \
    --name transaction-events \
    || true

echo "LocalStack initialization complete!"
