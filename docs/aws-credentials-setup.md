# AWS Credentials Setup

This document explains how to set up AWS credentials for deploying the TrustAInvest infrastructure.

## Prerequisites

- An AWS account with appropriate permissions
- AWS CLI installed on your local machine

## Local Deployment

For local deployment, you need to configure AWS credentials on your machine. There are several ways to do this:

### Option 1: AWS CLI Configuration

1. Run the AWS CLI configuration command:

```bash
aws configure
```

2. Enter your AWS Access Key ID, Secret Access Key, default region, and output format when prompted:

```
AWS Access Key ID [None]: YOUR_ACCESS_KEY_ID
AWS Secret Access Key [None]: YOUR_SECRET_ACCESS_KEY
Default region name [None]: us-east-1
Default output format [None]: json
```

This creates a credentials file at `~/.aws/credentials` and a configuration file at `~/.aws/config`.

### Option 2: Environment Variables

Set the following environment variables:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-east-1
```

### Option 3: AWS Profiles

If you have multiple AWS accounts, you can use named profiles:

1. Configure a named profile:

```bash
aws configure --profile trustainvest
```

2. Use the profile when running commands:

```bash
aws s3 ls --profile trustainvest
```

Or set the profile as the default for your current session:

```bash
export AWS_PROFILE=trustainvest
```

## CI/CD Deployment

For GitHub Actions, you need to set up secrets in your GitHub repository:

1. Go to your GitHub repository
2. Click on "Settings" > "Secrets and variables" > "Actions"
3. Click on "New repository secret"
4. Add the following secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS Access Key ID
   - `AWS_SECRET_ACCESS_KEY`: Your AWS Secret Access Key
   - `TF_VAR_DB_PASSWORD`: The password for the database

These secrets are referenced in the GitHub Actions workflow file (`.github/workflows/terraform.yml`).

## Creating AWS Credentials

If you need to create new AWS credentials:

1. Log in to the AWS Management Console
2. Go to "IAM" > "Users"
3. Select your user or create a new one
4. Click on the "Security credentials" tab
5. Under "Access keys", click "Create access key"
6. Download the CSV file or copy the Access Key ID and Secret Access Key
7. Store these credentials securely

## Required Permissions

The AWS credentials used for deployment should have the following permissions:

- IAM permissions for creating roles and policies
- EC2 permissions for creating VPCs, subnets, and security groups
- RDS permissions for creating databases
- ElastiCache permissions for creating Redis clusters
- S3 permissions for creating buckets
- CloudFront permissions for creating distributions
- Route 53 permissions for creating DNS records
- CloudWatch permissions for creating dashboards and alarms
- ECS permissions for creating clusters and services
- ECR permissions for creating repositories
- KMS permissions for creating encryption keys
- Cognito permissions for creating user pools
- SNS permissions for creating topics
- SQS permissions for creating queues

You can use the AWS managed policy `AdministratorAccess` for testing, but for production, it's recommended to create a custom policy with only the necessary permissions.

## Temporary Credentials

For enhanced security, you can use temporary credentials with AWS STS (Security Token Service):

```bash
aws sts get-session-token --duration-seconds 3600
```

This will return temporary credentials that you can use for a limited time.

## Credential Rotation

It's a good practice to rotate your AWS credentials regularly:

1. Create new access keys
2. Update your configuration to use the new keys
3. Verify that everything works with the new keys
4. Delete the old access keys

## Troubleshooting

If you encounter credential-related issues:

- Verify that your credentials are correct
- Check that your credentials have the necessary permissions
- Ensure that your credentials are not expired
- Confirm that you're using the correct AWS region
- Check the AWS CLI configuration files for any issues
