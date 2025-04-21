output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "cloudfront_distribution_status" {
  description = "The status of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.status
}

output "cloudfront_distribution_last_modified_time" {
  description = "The date and time the CloudFront distribution was last modified"
  value       = aws_cloudfront_distribution.main.last_modified_time
}

output "cloudfront_origin_access_identity_id" {
  description = "The ID of the CloudFront origin access identity"
  value       = aws_cloudfront_origin_access_identity.main.id
}

output "cloudfront_origin_access_identity_iam_arn" {
  description = "The IAM ARN of the CloudFront origin access identity"
  value       = aws_cloudfront_origin_access_identity.main.iam_arn
}

output "cloudfront_origin_access_identity_path" {
  description = "The path of the CloudFront origin access identity"
  value       = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
}

output "cloudfront_origin_access_control_id" {
  description = "The ID of the CloudFront origin access control"
  value       = aws_cloudfront_origin_access_control.main.id
}

output "cloudfront_cache_policy_id" {
  description = "The ID of the CloudFront cache policy"
  value       = var.cloudfront_cache_policy_id != null ? var.cloudfront_cache_policy_id : aws_cloudfront_cache_policy.main[0].id
}

output "cloudfront_origin_request_policy_id" {
  description = "The ID of the CloudFront origin request policy"
  value       = var.cloudfront_origin_request_policy_id != null ? var.cloudfront_origin_request_policy_id : aws_cloudfront_origin_request_policy.main[0].id
}

output "cloudfront_response_headers_policy_id" {
  description = "The ID of the CloudFront response headers policy"
  value       = var.cloudfront_response_headers_policy_id != null ? var.cloudfront_response_headers_policy_id : aws_cloudfront_response_headers_policy.main[0].id
}

output "frontend_bucket_name" {
  description = "The name of the S3 bucket for frontend assets"
  value       = var.frontend_bucket_name
}

output "frontend_bucket_arn" {
  description = "The ARN of the S3 bucket for frontend assets"
  value       = var.frontend_bucket_arn
}

output "frontend_bucket_domain_name" {
  description = "The domain name of the S3 bucket for frontend assets"
  value       = var.frontend_bucket_domain_name
}

output "frontend_bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket for frontend assets"
  value       = var.frontend_bucket_regional_domain_name
}

output "domain_name" {
  description = "The domain name for the CloudFront distribution"
  value       = local.domain_name
}

output "alternative_domain_names" {
  description = "Alternative domain names for the CloudFront distribution"
  value       = var.alternative_domain_names
}
