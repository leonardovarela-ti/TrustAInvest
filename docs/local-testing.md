# Local Testing with LocalStack

This document explains how to test the TrustAInvest infrastructure locally using LocalStack before deploying to AWS.

## What is LocalStack?

[LocalStack](https://localstack.cloud/) is a cloud service emulator that runs in a single container on your laptop or in your CI environment. It provides an easy-to-use test/mocking framework for developing cloud applications.

## Prerequisites

- Docker and Docker Compose installed on your local machine
- AWS CLI installed on your local machine
- Terraform installed on your local machine

## Setting Up LocalStack

1. Start LocalStack using Docker Compose:

```bash
docker-compose up -d localstack
```

2. Wait for LocalStack to be ready:

```bash
docker logs -f localstack
```

Wait until you see a message indicating that LocalStack is ready.

3. Initialize LocalStack with the required AWS resources:

```bash
./scripts/init-localstack.sh
```

This script creates the necessary AWS resources in LocalStack, such as S3 buckets, SQS queues, and SNS topics.

## Testing with LocalStack

### Option 1: Using the Test Deployment Script

The easiest way to test the deployment is to use the provided script:

```bash
./scripts/test-deployment-local.sh
```

This script:
- Builds Docker images for all services
- Deploys the services to the local environment
- Sets up the necessary environment variables
- Connects the services to LocalStack

You can also specify which services to deploy:

```bash
./scripts/test-deployment-local.sh user-service account-service
```

Or build the Docker images without deploying:

```bash
./scripts/test-deployment-local.sh --build-only
```

### Option 2: Manual Testing

If you prefer to test manually, you can:

1. Configure the AWS CLI to use LocalStack:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
```

2. Create the necessary AWS resources:

```bash
# Create an S3 bucket
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-dev-documents

# Create an SQS queue
aws --endpoint-url=http://localhost:4566 sqs create-queue --queue-name trustainvest-dev-kyc-queue

# Create an SNS topic
aws --endpoint-url=http://localhost:4566 sns create-topic --name trustainvest-dev-kyc-topic
```

3. Build and run the services:

```bash
# Build a service
docker build -t trustainvest-local-user-service -f cmd/user-service/Dockerfile .

# Run the service
docker run -d --name trustainvest-local-user-service \
  --network trustainvest \
  -e AWS_ENDPOINT=http://localstack:4566 \
  -e AWS_REGION=us-east-1 \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e DB_HOST=postgres \
  -e DB_PORT=5432 \
  -e DB_NAME=trustainvest \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e REDIS_HOST=redis \
  -e REDIS_PORT=6379 \
  trustainvest-local-user-service:latest
```

## Testing with Terraform

You can also test the Terraform configuration with LocalStack:

1. Configure Terraform to use LocalStack:

```bash
export TF_VAR_aws_endpoint=http://localhost:4566
```

2. Initialize Terraform:

```bash
cd deployments/terraform/environments/dev
terraform init
```

3. Plan the deployment:

```bash
terraform plan -var="aws_account_id=000000000000" -var="route53_hosted_zone_id=Z0514020MO3GNVU62G13" -var="route53_hosted_zone_name=trustainvest.com"
```

4. Apply the deployment:

```bash
terraform apply -var="aws_account_id=000000000000" -var="route53_hosted_zone_id=Z0514020MO3GNVU62G13" -var="route53_hosted_zone_name=trustainvest.com"
```

Note: Some Terraform resources may not be fully supported by LocalStack, so you may encounter errors. In such cases, you can use the `terraform state rm` command to remove the problematic resources from the state file.

## Verifying the Deployment

Once the services are deployed, you can verify that they are working correctly:

1. Check that the services are running:

```bash
docker ps
```

2. Check the logs of a service:

```bash
docker logs trustainvest-local-user-service
```

3. Access the API:

```bash
curl http://localhost:8000/health
```

4. Access the frontend:

```bash
open http://localhost:8080
```

## Cleaning Up

To clean up the local environment:

1. Stop and remove the containers:

```bash
docker-compose down
```

2. Remove the Docker images:

```bash
docker rmi $(docker images -q trustainvest-local-*)
```

3. Remove the LocalStack data:

```bash
rm -rf localstack_data
```

## Troubleshooting

If you encounter issues with LocalStack:

- Check the LocalStack logs:

```bash
docker logs localstack
```

- Restart LocalStack:

```bash
docker-compose restart localstack
```

- Ensure that the AWS endpoint URL is correctly set:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566
```

- Verify that the services are using the correct environment variables:

```bash
docker inspect trustainvest-local-user-service | grep -A 20 "Env"
```

- Check the network connectivity:

```bash
docker network inspect trustainvest
