# AWS Deployment Guide

This document provides step-by-step instructions for deploying the TrustAInvest infrastructure to AWS.

## Prerequisites

- AWS account with appropriate permissions (see [Terraform Deployment Permissions Guide](terraform-deployment-permissions.md))
- AWS CLI installed and configured with credentials
- Terraform installed (v1.0.0 or later)
- Docker installed (for building service images)
- Git repository cloned locally

## Cost Estimate

For an estimate of the monthly AWS infrastructure costs, see the [AWS Infrastructure Cost Estimate](aws-cost-estimate.md) document. This provides a breakdown of costs for the development environment and recommendations for cost optimization.

## Deployment Overview

The deployment process consists of two main steps:

1. Deploying the infrastructure using Terraform
2. Deploying the services using the deployment script

## Step 1: Deploying the Infrastructure

### 1.1 Prepare Terraform Variables

1. Navigate to the Terraform environment directory:

```bash
cd deployments/terraform/environments/dev
```

2. Create a `terraform.tfvars` file from the example:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Edit the `terraform.tfvars` file to set the appropriate values for your environment:

```bash
# Project and Environment
project_name = "trustainvest"
environment  = "dev"
region       = "us-east-1"
aws_account_id = "982081083216"

# VPC
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Database
db_instance_class        = "db.t3.small"
db_allocated_storage     = 20
db_max_allocated_storage = 100
db_name                  = "trustainvest"
db_username              = "trustainvest"
db_password              = "YOUR_SECURE_PASSWORD" # Replace with a secure password
db_multi_az              = false

# CloudFront and DNS
domain_name               = "trustainvest.com"
alternative_domain_names  = ["www.trustainvest.com"]
route53_hosted_zone_id    = "Z0514020MO3GNVU62G13"
route53_hosted_zone_name  = "trustainvest.com"

# Monitoring
sns_subscription_email_addresses = ["leo@trustainvest.com"] # Replace with your email
```

### 1.2 Initialize Terraform

Initialize Terraform to download the required providers and modules:

```bash
terraform init
```

If you want to use a remote backend for storing the Terraform state, uncomment and configure the backend section in `main.tf` before running `terraform init`.

### 1.3 Plan the Deployment

Create a Terraform plan to see what resources will be created:

```bash
terraform plan -out=tfplan
```

Review the plan to ensure it will create the expected resources.

### 1.4 Apply the Deployment

Apply the Terraform plan to create the infrastructure:

```bash
terraform apply tfplan
```

This will create all the infrastructure resources in AWS, including:

- VPC, subnets, and security groups
- RDS PostgreSQL database
- ElastiCache Redis cluster
- S3 buckets for documents, artifacts, frontend assets, and logs
- CloudFront distribution for the frontend
- ECS cluster and ECR repositories
- Cognito user pool
- KMS keys for encryption
- SNS topics and SQS queues
- CloudWatch dashboards and alarms
- Route 53 DNS records

The deployment may take 20-30 minutes to complete.

### 1.5 Verify the Deployment

After the deployment is complete, verify that the resources were created successfully:

```bash
terraform output
```

This will display the outputs from the Terraform deployment, including:

- VPC ID and CIDR
- Subnet IDs
- Database endpoint
- Redis endpoint
- CloudFront distribution domain name
- ECR repository URLs
- ECS cluster name
- ALB DNS name

You can also verify the resources in the AWS Management Console.

## Step 2: Deploying the Services

### 2.1 Build and Push Docker Images

Use the deployment script to build and push the Docker images to ECR:

```bash
./scripts/deploy-to-aws.sh --environment dev --build-only
```

This will:

1. Build Docker images for all services
2. Create ECR repositories if they don't exist
3. Tag the Docker images
4. Push the Docker images to ECR

### 2.2 Deploy the Services to ECS

Use the deployment script to deploy the services to ECS:

```bash
./scripts/deploy-to-aws.sh --environment dev --deploy-only
```

This will:

1. Get the ECS cluster name
2. Get the ECS service names
3. Update the ECS services with the new Docker images

You can also deploy specific services:

```bash
./scripts/deploy-to-aws.sh --environment dev user-service account-service
```

### 2.3 Verify the Services

Verify that the services are running:

```bash
aws ecs list-services --cluster trustainvest-dev
```

Check the status of a service:

```bash
aws ecs describe-services --cluster trustainvest-dev --services trustainvest-dev-user-service
```

View the logs of a service:

```bash
aws logs get-log-events --log-group-name /aws/ecs/trustainvest-dev/user-service --log-stream-name <log-stream-name>
```

## Step 3: Accessing the Application

### 3.1 Frontend

The frontend is accessible at:

- https://trustainvest.com
- https://www.trustainvest.com

### 3.2 API

The API is accessible at:

- https://api.trustainvest.com

## Continuous Deployment

### GitHub Actions

The repository includes a GitHub Actions workflow for continuous deployment:

1. Go to the GitHub repository
2. Click on "Actions"
3. Select the "Terraform" workflow
4. Click "Run workflow"
5. Select the environment (dev, stage, prod)
6. Select the action (plan, apply, destroy)
7. Click "Run workflow"

### Required Secrets

The GitHub Actions workflow requires the following secrets:

- `AWS_ACCESS_KEY_ID`: Your AWS Access Key ID
- `AWS_SECRET_ACCESS_KEY`: Your AWS Secret Access Key
- `TF_VAR_DB_PASSWORD`: The password for the database

## Updating the Infrastructure

To update the infrastructure:

1. Make changes to the Terraform files
2. Run `terraform plan -out=tfplan` to see the changes
3. Run `terraform apply tfplan` to apply the changes

## Destroying the Infrastructure

To destroy the infrastructure:

```bash
terraform destroy
```

This will remove all the resources created by Terraform. Be careful with this command, as it will delete all the resources, including the database and its data.

## Troubleshooting

### Terraform Errors

If you encounter errors during the Terraform deployment:

- Check the error message for details
- Verify that your AWS credentials have the necessary permissions (see [Terraform Deployment Permissions Guide](terraform-deployment-permissions.md))
- Check that the resources you're trying to create don't already exist
- Try running `terraform plan` again to see if the error persists

### Deployment Script Errors

If you encounter errors during the service deployment:

- Check the error message for details
- Verify that the ECR repositories exist
- Check that the ECS cluster and services exist
- Verify that the Docker images were built and pushed successfully
- Check the ECS service logs for more information

### Service Errors

If the services are deployed but not working correctly:

- Check the ECS service logs
- Verify that the services can connect to the database and Redis
- Check that the environment variables are set correctly
- Verify that the security groups allow the necessary traffic
- Check the CloudWatch alarms for any triggered alarms
