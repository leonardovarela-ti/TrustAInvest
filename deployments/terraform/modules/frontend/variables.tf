variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "trustainvest"
}

variable "environment" {
  description = "The deployment environment (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "frontend_bucket_name" {
  description = "The name of the S3 bucket for frontend assets"
  type        = string
}

variable "frontend_bucket_arn" {
  description = "The ARN of the S3 bucket for frontend assets"
  type        = string
}

variable "frontend_bucket_domain_name" {
  description = "The domain name of the S3 bucket for frontend assets"
  type        = string
}

variable "frontend_bucket_regional_domain_name" {
  description = "The regional domain name of the S3 bucket for frontend assets"
  type        = string
}

variable "logs_bucket_name" {
  description = "The name of the S3 bucket for logs"
  type        = string
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key for encryption"
  type        = string
}

variable "waf_web_acl_arn" {
  description = "The ARN of the WAF Web ACL"
  type        = string
  default     = null
}

variable "alb_dns_name" {
  description = "The DNS name of the ALB"
  type        = string
  default     = null
}

variable "alb_zone_id" {
  description = "The zone ID of the ALB"
  type        = string
  default     = null
}

variable "domain_name" {
  description = "The domain name for the CloudFront distribution"
  type        = string
  default     = null
}

variable "alternative_domain_names" {
  description = "Alternative domain names for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_enabled" {
  description = "Whether the CloudFront distribution is enabled"
  type        = bool
  default     = true
}

variable "cloudfront_default_root_object" {
  description = "The default root object for the CloudFront distribution"
  type        = string
  default     = "index.html"
}

variable "cloudfront_http_version" {
  description = "The HTTP version for the CloudFront distribution"
  type        = string
  default     = "http2and3"
}

variable "cloudfront_minimum_protocol_version" {
  description = "The minimum protocol version for the CloudFront distribution"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "cloudfront_ssl_support_method" {
  description = "The SSL support method for the CloudFront distribution"
  type        = string
  default     = "sni-only"
}

variable "cloudfront_default_ttl" {
  description = "The default TTL for the CloudFront distribution"
  type        = number
  default     = 86400
}

variable "cloudfront_min_ttl" {
  description = "The minimum TTL for the CloudFront distribution"
  type        = number
  default     = 0
}

variable "cloudfront_max_ttl" {
  description = "The maximum TTL for the CloudFront distribution"
  type        = number
  default     = 31536000
}

variable "cloudfront_compress" {
  description = "Whether to enable compression for the CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_viewer_protocol_policy" {
  description = "The viewer protocol policy for the CloudFront distribution"
  type        = string
  default     = "redirect-to-https"
}

variable "cloudfront_geo_restriction_type" {
  description = "The geo restriction type for the CloudFront distribution"
  type        = string
  default     = "none"
}

variable "cloudfront_geo_restriction_locations" {
  description = "The geo restriction locations for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "cloudfront_origin_shield_enabled" {
  description = "Whether to enable origin shield for the CloudFront distribution"
  type        = bool
  default     = false
}

variable "cloudfront_origin_shield_region" {
  description = "The region for origin shield for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_origin_keepalive_timeout" {
  description = "The keep-alive timeout for the CloudFront distribution"
  type        = number
  default     = 5
}

variable "cloudfront_origin_read_timeout" {
  description = "The read timeout for the CloudFront distribution"
  type        = number
  default     = 30
}

variable "cloudfront_origin_connection_attempts" {
  description = "The connection attempts for the CloudFront distribution"
  type        = number
  default     = 3
}

variable "cloudfront_origin_connection_timeout" {
  description = "The connection timeout for the CloudFront distribution"
  type        = number
  default     = 10
}

variable "cloudfront_custom_error_responses" {
  description = "Custom error responses for the CloudFront distribution"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    }
  ]
}

variable "cloudfront_cache_policy_id" {
  description = "The ID of the cache policy for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_origin_request_policy_id" {
  description = "The ID of the origin request policy for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_response_headers_policy_id" {
  description = "The ID of the response headers policy for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_realtime_log_config_arn" {
  description = "The ARN of the real-time log configuration for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_web_acl_id" {
  description = "The ID of the WAF web ACL for the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_access_logs_enabled" {
  description = "Whether to enable access logs for the CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_access_logs_prefix" {
  description = "The S3 bucket prefix for CloudFront access logs"
  type        = string
  default     = "cloudfront-logs"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
