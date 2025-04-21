variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "trustainvest"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "The AWS account ID"
  type        = string
}

# VPC
variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "The availability zones to deploy to"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Database
variable "db_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "The allocated storage for the RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "The maximum allocated storage for the RDS instance in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "trustainvest"
}

variable "db_username" {
  description = "The username for the database"
  type        = string
  default     = "trustainvest"
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ deployment for the RDS instance"
  type        = bool
  default     = false
}

# Cache
variable "redis_node_type" {
  description = "The node type for the ElastiCache Redis cluster"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "The Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_multi_az_enabled" {
  description = "Whether to enable Multi-AZ for the ElastiCache Redis cluster"
  type        = bool
  default     = false
}

# ECS
variable "ecs_capacity_providers" {
  description = "List of capacity providers to use for the ECS cluster"
  type        = list(string)
  default     = ["FARGATE", "FARGATE_SPOT"]
}

variable "ecs_default_capacity_provider_strategy" {
  description = "The default capacity provider strategy for the ECS cluster"
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
  default = [
    {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
      base              = 1
    },
    {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  ]
}

# CloudFront and DNS
variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_100"
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

variable "route53_hosted_zone_id" {
  description = "The ID of the Route 53 hosted zone"
  type        = string
}

variable "route53_hosted_zone_name" {
  description = "The name of the Route 53 hosted zone"
  type        = string
}

# Logs
variable "cloudfront_logs_prefix" {
  description = "The S3 bucket prefix for CloudFront access logs"
  type        = string
  default     = "cloudfront-logs"
}

variable "alb_access_logs_prefix" {
  description = "The S3 bucket prefix for ALB access logs"
  type        = string
  default     = "alb-logs"
}

# Monitoring
variable "sns_subscription_email_addresses" {
  description = "Email addresses to subscribe to the SNS topic"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
