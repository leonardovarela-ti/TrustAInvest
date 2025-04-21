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

variable "route53_hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
}

variable "route53_hosted_zone_name" {
  description = "The name of the Route 53 hosted zone"
  type        = string
}

variable "domain_name" {
  description = "The domain name for the CloudFront distribution"
  type        = string
}

variable "alternative_domain_names" {
  description = "Alternative domain names for the CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  type        = string
}

variable "cloudfront_distribution_hosted_zone_id" {
  description = "The CloudFront Route 53 zone ID"
  type        = string
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

variable "create_api_record" {
  description = "Whether to create an API record"
  type        = bool
  default     = true
}

variable "enable_api_dns" {
  description = "Whether the ALB DNS name and zone ID are available for API DNS records"
  type        = bool
  default     = false
}

variable "api_subdomain" {
  description = "The subdomain for the API"
  type        = string
  default     = "api"
}

variable "create_cloudfront_records" {
  description = "Whether to create CloudFront DNS records"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
