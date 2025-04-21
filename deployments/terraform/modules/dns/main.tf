locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Combine domain name and alternative domain names
  all_domain_names = concat([var.domain_name], var.alternative_domain_names)
  
  # Use cloudfront_domains if provided, otherwise use all_domain_names
  cloudfront_domains = var.cloudfront_domains != null ? var.cloudfront_domains : local.all_domain_names
}

# Create Route 53 record for the CloudFront distribution
resource "aws_route53_record" "cloudfront" {
  for_each = var.create_cloudfront_records ? toset(local.cloudfront_domains) : toset([])
  
  zone_id = var.route53_hosted_zone_id
  name    = each.value
  type    = "A"
  
  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

# Create Route 53 record for the API (ALB)
resource "aws_route53_record" "api" {
  count = var.create_api_record && var.enable_api_dns ? 1 : 0
  
  zone_id = var.route53_hosted_zone_id
  name    = "${var.api_subdomain}.${var.route53_hosted_zone_name}"
  type    = "A"
  
  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Create Route 53 health check for the API
resource "aws_route53_health_check" "api" {
  count = var.create_api_record && var.enable_api_dns ? 1 : 0
  
  fqdn              = var.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  
  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-api-health-check"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}
