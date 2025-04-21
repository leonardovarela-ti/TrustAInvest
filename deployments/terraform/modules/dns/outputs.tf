output "cloudfront_dns_records" {
  description = "The Route 53 records for the CloudFront distribution"
  value       = aws_route53_record.cloudfront
}

output "api_dns_record" {
  description = "The Route 53 record for the API"
  value       = var.create_api_record && var.alb_dns_name != null && var.alb_zone_id != null ? aws_route53_record.api[0] : null
}

output "api_health_check_id" {
  description = "The ID of the Route 53 health check for the API"
  value       = var.create_api_record && var.alb_dns_name != null ? aws_route53_health_check.api[0].id : null
}

output "api_fqdn" {
  description = "The fully qualified domain name for the API"
  value       = var.create_api_record ? "${var.api_subdomain}.${var.route53_hosted_zone_name}" : null
}
