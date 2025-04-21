# This file modifies the monitoring module configuration to fix issues with CloudWatch Logs metric filters

# We still have issues with the CloudWatch Logs metric filters
# The filter pattern does not support dimensions

# Override the monitoring module variables using locals
locals {
  # Disable log metrics
  monitoring_create_log_metrics = false
}

# The locals are referenced in the main.tf file
