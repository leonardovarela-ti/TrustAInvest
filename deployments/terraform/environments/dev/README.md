# TrustAInvest AWS Infrastructure - Development Environment

This directory contains Terraform configurations for deploying the TrustAInvest infrastructure to the development environment in AWS.

## Overview

The development environment infrastructure is deployed using Terraform modules that define various AWS resources such as VPC, subnets, security groups, RDS, ElastiCache, ECS, CloudFront, and more.

## Recent Improvements

All fix files have been consolidated into the main.tf file for better maintainability. This consolidation makes the infrastructure code easier to understand for new developers, as all configurations are now in their proper places rather than spread across multiple fix files.

The following fix files have been consolidated:
- ✅ `iam_roles_fix.tf` → `main.tf` (IAM roles for ECS tasks)
- ✅ `global_waf.tf` → `main.tf` (CloudFront WAF configuration)
- ✅ `dns_module_fix.tf` → `main.tf` (DNS records configuration)
- ✅ `frontend_module_fix.tf` → `main.tf` (CloudFront logs configuration)
- ✅ `frontend_waf_fix.tf` → `main.tf` (CloudFront WAF integration)
- ✅ `monitoring_module_fix.tf` → `main.tf` (CloudWatch log metrics configuration)
- ✅ `container_module_fix.tf` → `main.tf` (ALB access logs configuration)
- ✅ `storage_module_fix.tf` → `main.tf` (S3 bucket ACLs for logs)
- ✅ `variables_fix.tf` → `variables.tf` (in the DNS module)

The module source has been updated from "container_with_existing_roles" to "container" to avoid issues with data sources that were trying to reference resources that don't exist yet.

## Current Issues

### ALB Access Logs

Despite the consolidation of fix files, there are still issues with ALB access logs that need to be addressed:

1. **Issue**: The Application Load Balancer (ALB) access logs may not be delivered to the S3 bucket due to permission issues and configuration problems.

2. **Alternative Solutions**:
   - **Dedicated S3 Bucket for ALB Logs**: Create a separate S3 bucket specifically for ALB logs with proper permissions and configuration.
   - **Simplified S3 Bucket Policy**: Use the existing shared logs bucket but with a simplified bucket policy that follows AWS documentation exactly.
   - **CloudWatch Logs Instead of S3**: Use CloudWatch Logs instead of S3 for ALB access logs, avoiding S3 permission issues entirely.

3. **Recommended Approach**: Use a dedicated S3 bucket for ALB logs with proper permissions and configuration. This approach is already implemented in the main.tf file but may require additional configuration or troubleshooting.

4. **Verification Steps**:
   - Apply the Terraform changes
   - Generate some traffic to the ALB
   - Wait a few minutes for logs to be delivered
   - Check the S3 bucket for logs

5. **Troubleshooting**:
   - Check the AWS CloudTrail logs for access denied errors
   - Verify that the ALB service account has the correct permissions
   - Ensure that S3 bucket policies are correctly formatted
   - Check that the bucket ACLs are properly configured
   - Verify that the ALB is correctly configured to send logs

For detailed information on ALB access logs issues and solutions, refer to:
- [ALB Access Logs: Alternative Approaches](../../docs/alb-access-logs-alternatives.md)
- [Applying and Testing ALB Access Logs Changes](../../docs/applying-alb-logs-changes.md)
- [Terraform Deployment Fixes](../../docs/terraform-deployment-fixes-updated.md)

## Deployment Instructions

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Create a Terraform plan:
   ```bash
   terraform plan -out=tfplan
   ```

3. Apply the Terraform plan:
   ```bash
   terraform apply tfplan
   ```

## Terraform State

The Terraform state is stored locally by default. For production use, it is recommended to configure a remote backend such as S3 with DynamoDB for state locking.

## Variables

The variables for the development environment are defined in:
- `variables.tf`: Variable definitions
- `terraform.tfvars`: Variable values (not committed to version control)
- `terraform.tfvars.example`: Example variable values

## Outputs

The outputs from the Terraform deployment are defined in `outputs.tf`. These include:
- VPC and subnet IDs
- Database endpoint and credentials
- Redis endpoint
- Cognito user pool ID
- S3 bucket names
- ECR repository URLs
- ECS cluster name
- ALB DNS name
- CloudFront distribution domain name
- DNS records

## Scripts

Several scripts are available to help with deployment and troubleshooting:
- `scripts/apply-terraform-fixes-all.sh`: Apply all fixes
- `scripts/check-alb-logs-bucket-policy.sh`: Check and fix ALB logs configuration
- `scripts/enable-alb-logs-manually.sh`: Manually enable ALB access logs
- `scripts/test-deployment-local.sh`: Test the deployment locally

## References

- [AWS Documentation: Access Logs for Your Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html)
- [AWS Documentation: Bucket Policy Examples for S3 Buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)
- [AWS Documentation: Enabling Access Logging for ALB](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html)
