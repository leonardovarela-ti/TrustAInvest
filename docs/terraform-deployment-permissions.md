# Terraform Deployment Permissions Guide

This document explains how to resolve common permission issues when deploying the TrustAInvest infrastructure using Terraform. For a complete list of fixes applied to the deployment, see [Terraform Deployment Fixes](terraform-deployment-fixes.md).

## Common Permission Issues

When deploying the TrustAInvest infrastructure using Terraform, you might encounter the following permission-related errors:

1. **Service-Linked Role Issues**:
   - ElastiCache operations failing due to missing service-linked roles
   - ELB operations failing due to missing service-linked roles

2. **IAM Permission Issues**:
   - Missing iam:TagRole permission needed when creating IAM roles
   - Missing iam:ListPolicies permission needed for policy management
   - Missing iam:GetRolePolicy permission needed for role policy management
   - Missing servicediscovery:CreatePrivateDnsNamespace permission

3. **CloudWatch Logs Issues**:
   - KMS key access issues for CloudWatch log groups (see error below)
   ```
   Error: creating CloudWatch Logs Log Group: AccessDeniedException: The specified KMS key does not exist or is not allowed to be used
   ```
   - Metric filter errors due to non-existent log groups
   ```
   Error: putting CloudWatch Logs Metric Filter: ResourceNotFoundException: The specified log group does not exist
   ```

4. **S3 Bucket Access Issues**:
   - ALB access logs failing due to S3 bucket permission issues
   ```
   Error: modifying ELBv2 Load Balancer attributes: InvalidConfigurationRequest: Access Denied for bucket: trustainvest-dev-logs. Please check S3bucket permission
   ```

5. **Route53 Record Creation Conflicts**:
   - Conflicts when trying to create DNS records that already exist
   ```
   Error: creating Route53 Record: InvalidChangeBatch: Tried to create resource record set [name='trustainvest.com.', type='A'] but it already exists
   ```

6. **CloudFront WAF Association Issues**:
   - CloudFront requires a global WAF web ACL, but the infrastructure is using a regional one

## Root Cause

The root cause of these issues is that the IAM policy attached to the deployment user (`trust-ai-deployment`) does not have all the necessary permissions to create and manage the required AWS resources.

The original policy is missing the following critical permissions:

- `iam:CreateServiceLinkedRole` - Required for services like ElastiCache and ELB to create their service-linked roles
- `iam:TagRole` - Required when creating IAM roles with tags
- `iam:ListPolicies` - Required for listing and managing IAM policies
- `iam:GetRolePolicy` - Required for managing role policies
- `servicediscovery:*` - Required for AWS Cloud Map service discovery operations

## Solution

We've created an updated IAM policy that includes all the necessary permissions for deploying the TrustAInvest infrastructure. The updated policy is available in the `updated-deployment-policy.json` file.

Additionally, we've made the following infrastructure changes to address specific permission issues:

### 1. Disabling KMS Encryption for CloudWatch Logs

As a temporary workaround to get the deployment working, we've disabled KMS encryption for CloudWatch Logs in the container module. This is done by:

1. Commenting out the `kms_key_id` parameter in the CloudWatch Log Group resources:

```terraform
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${local.name_prefix}/exec"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  # Temporarily disable KMS encryption to get the deployment working
  # kms_key_id        = var.cloudwatch_log_group_kms_key_id != null ? var.cloudwatch_log_group_kms_key_id : var.kms_key_arn
  
  # ...
}
```

2. Setting `cloud_watch_encryption_enabled` to `false` in the ECS cluster configuration:

```terraform
configuration {
  execute_command_configuration {
    kms_key_id = var.kms_key_arn
    logging    = "OVERRIDE"
    
    log_configuration {
      cloud_watch_encryption_enabled = false
      cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
    }
  }
}
```

This workaround allows the deployment to proceed without requiring KMS key permissions for CloudWatch Logs. Once the deployment is successful, you can re-enable KMS encryption by reverting these changes and ensuring the KMS key policy is properly configured.

### 2. Disabling CloudFront WAF Association

CloudFront distributions require a global WAF web ACL, but our infrastructure is using a regional one. We've created a fix to disable the CloudFront WAF association until a global WAF web ACL is available:

```terraform
# frontend_waf_fix.tf
locals {
  frontend_cloudfront_waf_enabled = false
}
```

And updated the main.tf file to use this variable:

```terraform
# Disable CloudFront WAF association until we have a global WAF web ACL
waf_web_acl_arn = try(local.frontend_cloudfront_waf_enabled, false) ? module.security.waf_web_acl_arn : null
```

### 3. Disabling CloudFront DNS Records Creation

To resolve conflicts with existing Route53 records, we've created a fix to disable the creation of CloudFront DNS records:

```terraform
# dns_module_fix.tf
locals {
  dns_create_cloudfront_records = false
}
```

We've also added a new variable to the DNS module to control CloudFront record creation:

```terraform
variable "create_cloudfront_records" {
  description = "Whether to create CloudFront DNS records"
  type        = bool
  default     = true
}
```

And modified the DNS module to use this variable:

```terraform
resource "aws_route53_record" "cloudfront" {
  for_each = var.create_cloudfront_records ? toset(local.all_domain_names) : toset([])
  
  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "A"
  
  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
```

### 4. Disabling CloudWatch Log Metrics

To address the issue with CloudWatch Log Metric Filters failing because the log groups don't exist, we've created a fix to disable log metrics until log groups are created:

```terraform
# monitoring_module_fix.tf
locals {
  monitoring_create_log_metrics = false
}
```

And updated the main.tf file to use this variable:

```terraform
# Disable log metrics until log groups are created
create_log_metrics = try(local.monitoring_create_log_metrics, true)
```

### KMS Key Policy for CloudWatch Logs

The KMS key used for encryption needs to explicitly allow CloudWatch Logs to use it. We've updated the KMS key policy in the security module to include the following statement:

```json
{
  "Sid": "Allow CloudWatch Logs to use the key",
  "Effect": "Allow",
  "Principal": {
    "Service": "logs.REGION.amazonaws.com"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:Describe*"
  ],
  "Resource": "*",
  "Condition": {
    "ArnLike": {
      "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:REGION:ACCOUNT_ID:*"
    }
  }
}
```

### S3 Bucket Policy for ALB Logs

The S3 bucket used for ALB logs needs a policy that allows the ALB service to write logs to it. We've added the following bucket policy to the logs bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::127311923021:root" // AWS ELB service account for us-east-1
      },
      "Action": "s3:PutObject",
      "Resource": "BUCKET_ARN/alb-logs/*"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "BUCKET_ARN/alb-logs/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "BUCKET_ARN"
    }
  ]
}
```

Note: The AWS account ID `127311923021` is the ELB service account for the us-east-1 region. If you're deploying to a different region, you'll need to use the appropriate service account ID for that region.

### Key Additions to the Policy

The updated policy includes the following additional permissions:

```json
"iam:TagRole",
"iam:CreateServiceLinkedRole",
"iam:ListPolicies",
"iam:CreatePolicy",
"iam:CreatePolicyVersion",
"iam:GetPolicy",
"iam:GetPolicyVersion",
"iam:GetRolePolicy",
"servicediscovery:*"
```

### Updating the Policy

To update the IAM policy for your deployment user, follow these steps:

1. Ensure you have AWS CLI installed and configured with administrative access.

2. Run the update script:

```bash
./scripts/update-deployment-user-policy.sh
```

This script will:
- Check if the policy exists and create or update it as needed
- Handle the case where the policy has reached the maximum number of versions (5) by deleting the oldest non-default version
- Attach the policy to the deployment user
- Handle any errors that might occur during the process

3. Wait a few minutes for the policy changes to propagate.

4. Try running the Terraform deployment again:

```bash
cd deployments/terraform/environments/dev
terraform plan -out=tfplan
terraform apply tfplan
```

## Understanding Service-Linked Roles

Service-linked roles are a special type of IAM role that is linked to a specific AWS service. These roles are predefined by the service and include all the permissions that the service requires to call other AWS services on your behalf.

Services that use service-linked roles include:

- Amazon ElastiCache
- Elastic Load Balancing
- Amazon RDS
- AWS CloudFormation
- Amazon ECS

When you use these services for the first time, the service needs to create its service-linked role in your AWS account. This requires the `iam:CreateServiceLinkedRole` permission.

## Troubleshooting

If you still encounter permission issues after updating the policy, check the error message to identify the missing permission. The error message will typically include the action that was denied and the resource it was trying to access.

For example:

```
Error: User: arn:aws:iam::123456789012:user/trust-ai-deployment is not authorized to perform: iam:CreateServiceLinkedRole on resource: arn:aws:iam::123456789012:role/aws-service-role/elasticache.amazonaws.com/AWSServiceRoleForElastiCache
```

This error indicates that the user does not have permission to create the service-linked role for ElastiCache.

To resolve this, ensure that the `iam:CreateServiceLinkedRole` permission is included in the policy and that there are no restrictive conditions that might prevent it from being applied.

## Best Practices

1. **Follow the Principle of Least Privilege**: While the updated policy includes broad permissions for ease of deployment, consider restricting the permissions further for production environments.

2. **Use Temporary Credentials**: For CI/CD pipelines, consider using temporary credentials with the AWS Security Token Service (STS) instead of long-term access keys.

3. **Monitor IAM Activity**: Enable AWS CloudTrail and set up alerts for suspicious IAM activities.

4. **Regularly Review and Update Policies**: As your infrastructure evolves, regularly review and update your IAM policies to ensure they include only the necessary permissions.

5. **Use Policy Conditions**: Consider using policy conditions to restrict permissions based on IP address, time of day, or other factors.

6. **Implement Proper Resource Naming**: Use consistent naming conventions for resources to avoid conflicts.

7. **Test Deployments in Isolated Environments**: Before deploying to production, test in a development or staging environment to identify and resolve permission issues.

## References

- [AWS IAM User Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [AWS Service-Linked Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/using-service-linked-roles.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CloudFront WAF Integration](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-awswaf.html)
- [Route53 DNS Management](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/Welcome.html)
- [CloudWatch Logs KMS Encryption](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html)
