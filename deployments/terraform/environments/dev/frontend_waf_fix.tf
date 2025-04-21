# This file modifies the frontend module configuration to fix issues with CloudFront WAF association

# We need to use a global WAF web ACL for CloudFront
# The security module creates a regional WAF web ACL, but CloudFront requires a global WAF web ACL
# We've created a global WAF web ACL in global_waf.tf, but we're still having issues

# Override the frontend module variables using locals
locals {
  # Disable CloudFront WAF association until we fix the global WAF web ACL
  frontend_cloudfront_waf_enabled = false
}

# The locals are referenced in the main.tf file
