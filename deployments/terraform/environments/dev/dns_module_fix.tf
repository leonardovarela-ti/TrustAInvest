# This file modifies the DNS module configuration to fix issues with Route53 record creation

# We can now enable the creation of Route53 records for the CloudFront distribution
# We have fixed the DNS module to conditionally create CloudFront records
# However, the apex domain record already exists, so we need to exclude it

# Override the DNS module variables using locals
locals {
  # Enable CloudFront DNS records creation for www subdomain only
  dns_create_cloudfront_records = true
  dns_cloudfront_domains = ["www.trustainvest.com"]
  dns_exclude_apex_domain = true
}

# The locals are referenced in the main.tf file
