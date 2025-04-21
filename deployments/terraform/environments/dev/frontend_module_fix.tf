# This file modifies the frontend module configuration to fix issues with CloudFront logs

# We still have issues with the S3 bucket for CloudFront logs
# The S3 bucket does not enable ACL access

# Override the frontend module variables using locals
locals {
  # Disable CloudFront logs
  frontend_cloudfront_logs_enabled = false
}

# The locals are referenced in the main.tf file
