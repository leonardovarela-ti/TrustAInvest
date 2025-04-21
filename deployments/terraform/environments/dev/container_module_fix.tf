# This file modifies the container module configuration to fix issues with ALB access logs

# We still have issues with the S3 bucket policy for ALB access logs
# We need to disable ALB access logs until we fix the S3 bucket policy

# Override the container module variables using locals
locals {
  # Disable ALB access logs
  container_alb_access_logs_enabled = false
}

# The locals are referenced in the main.tf file
