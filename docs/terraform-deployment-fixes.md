# Terraform Deployment Fixes

This document describes the fixes applied to the Terraform deployment for the TrustAInvest.com infrastructure.

## Overview

The Terraform deployment was failing due to several permission and configuration issues. We've applied targeted fixes to address these issues and enable successful deployment.

## Fixes Applied

### 1. CloudFront WAF Association

**Issue**: CloudFront distributions can only be associated with global WAF web ACLs, but our security module was creating a regional WAF web ACL.

**Fix**:
- Created a global WAF web ACL specifically for CloudFront in `environments/dev/global_waf.tf`
- Disabled CloudFront WAF association in `frontend_waf_fix.tf` until we can properly configure the global WAF web ACL

### 2. S3 Bucket Permissions for Logging

**Issue**: The S3 bucket for logs didn't have the correct permissions to allow CloudFront and ALB to write logs to it.

**Fix**:
- Updated the S3 bucket policy in `modules/storage/main.tf` to allow CloudFront and ALB to write logs
- Added the `cloudfront_logs_prefix` and `alb_access_logs_prefix` variables to control the prefix for logs
- Added S3 bucket ownership controls and ACL configuration in `storage_module_fix.tf` to enable CloudFront logs
- Created a comprehensive S3 bucket policy in `storage_module_fix.tf` that includes permissions for both CloudFront and ALB
- Enabled CloudFront logs in `frontend_module_fix.tf` now that the ACL issues are fixed
- Disabled ALB access logs in `container_module_fix.tf` due to ongoing permission issues

### 3. Route53 DNS Records for CloudFront

**Issue**: The DNS module was trying to create Route53 records for CloudFront, but the apex domain record already existed.

**Fix**:
- Modified the DNS module in `modules/dns/main.tf` to conditionally create CloudFront DNS records
- Added a `create_cloudfront_records` variable to control record creation
- Added a `cloudfront_domains` variable to specify which domains to create records for
- Configured DNS module to only create the www subdomain record in `dns_module_fix.tf`

### 4. CloudWatch Log Metrics

**Issue**: The monitoring module was trying to create CloudWatch Log Metric Filters, but there were issues with the filter pattern.

**Fix**:
- Disabled CloudWatch Log Metrics in `monitoring_module_fix.tf` until we can fix the filter pattern issues

## Implementation Details

### Global WAF Web ACL for CloudFront

We created a global WAF web ACL with the following rules:
- AWS Managed Rules Common Rule Set
- AWS Managed Rules Known Bad Inputs Rule Set
- Rate-based rule to prevent DDoS attacks

### S3 Bucket ACL and Ownership Controls for CloudFront Logs

We added the following resources to enable CloudFront logs:
- `aws_s3_bucket_ownership_controls` with `object_ownership = "BucketOwnerPreferred"` to allow the bucket owner to control ACLs
- `aws_s3_bucket_acl` with `acl = "log-delivery-write"` to allow CloudFront to write logs to the bucket

### S3 Bucket Policy for Logs

We created a comprehensive S3 bucket policy that includes permissions for:
- ALB service account (127311923021 for us-east-1) to write access logs to the alb-logs/ prefix
- CloudFront service to write access logs to the cloudfront-logs/ prefix
- Both services to get the bucket ACL for permission checks
- Added specific permission for `logdelivery.elasticloadbalancing.amazonaws.com` service

Despite these changes, we still encountered permission issues with ALB access logs. We've disabled ALB access logs for now and will need to investigate further.

### DNS Module Modifications

We modified the DNS module to:
- Use a conditional for_each expression to create CloudFront records only when enabled
- Added variables to control CloudFront record creation and specify which domains to create records for
- Successfully created the www subdomain record for CloudFront

## Next Steps

1. **Fix ALB Access Logs**: Further investigate and fix the S3 bucket policy for ALB access logs
2. **Fix CloudWatch Log Metrics**: Update the filter pattern to support dimensions
3. **Enable CloudFront WAF Association**: Configure the global WAF web ACL for CloudFront

## Conclusion

We've made significant progress in fixing the Terraform deployment issues. The infrastructure is now partially deployed, with some features still disabled until further fixes can be applied. The DNS records for the www subdomain are correctly pointing to CloudFront, and CloudFront logs are now enabled with the proper S3 bucket configuration.

## Remaining Issues

There are still some features disabled that will need additional fixes in the future:
- ALB Access Logs (permission issues)
- CloudWatch Log Metrics (filter pattern issues)
- CloudFront WAF Association (needs proper global WAF web ACL configuration)

These can be addressed in future updates as needed.
