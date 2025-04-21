# This file modifies the frontend module configuration to fix issues with CloudFront logs

# We have fixed the S3 bucket ACL issues for CloudFront logs
# The S3 bucket now has ownership controls and ACLs enabled

# Override the frontend module variables using locals
locals {
  # Enable CloudFront logs now that the S3 bucket ACL issues are fixed
  frontend_cloudfront_logs_enabled = true
}

# The locals are referenced in the main.tf file
