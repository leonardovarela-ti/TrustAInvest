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

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "The IDs of the private subnets"
  type        = list(string)
}

variable "security_group_id" {
  description = "The ID of the ECS security group"
  type        = string
}

variable "alb_security_group_id" {
  description = "The ID of the ALB security group"
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

# ECR Repositories
variable "ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = [
    "user-service",
    "account-service",
    "trust-service",
    "investment-service",
    "document-service",
    "notification-service",
    "user-registration-service",
    "kyc-verifier-service",
    "etrade-service",
    "capitalone-service",
    "etrade-callback",
    "kyc-worker",
    "customer-app",
    "kyc-verifier-ui"
  ]
}

variable "ecr_image_tag_mutability" {
  description = "The tag mutability setting for the ECR repositories"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Whether to scan images on push for the ECR repositories"
  type        = bool
  default     = true
}

variable "ecr_lifecycle_policy_max_image_count" {
  description = "The maximum number of images to keep in each ECR repository"
  type        = number
  default     = 10
}

# ECS Cluster
variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
  default     = null
}

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

# ALB
variable "alb_name" {
  description = "The name of the ALB"
  type        = string
  default     = null
}

variable "alb_internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "alb_http_port" {
  description = "The HTTP port for the ALB"
  type        = number
  default     = 80
}

variable "alb_https_port" {
  description = "The HTTPS port for the ALB"
  type        = number
  default     = 443
}

variable "alb_ssl_policy" {
  description = "The SSL policy for the ALB"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "alb_certificate_arn" {
  description = "The ARN of the ACM certificate for the ALB"
  type        = string
  default     = null
}

variable "alb_enable_deletion_protection" {
  description = "Whether to enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "alb_enable_http_to_https_redirect" {
  description = "Whether to enable HTTP to HTTPS redirect for the ALB"
  type        = bool
  default     = true
}

variable "alb_enable_waf" {
  description = "Whether to enable WAF for the ALB"
  type        = bool
  default     = true
}

variable "enable_waf_association" {
  description = "Whether to enable WAF association (set to true when WAF Web ACL ARN is available)"
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "The idle timeout for the ALB"
  type        = number
  default     = 60
}

variable "alb_access_logs_enabled" {
  description = "Whether to enable access logs for the ALB"
  type        = bool
  default     = true
}

variable "alb_access_logs_prefix" {
  description = "The S3 bucket prefix for ALB access logs"
  type        = string
  default     = "alb-logs"
}

# CloudWatch Log Groups
variable "cloudwatch_log_group_retention_in_days" {
  description = "The number of days to retain logs in CloudWatch Log Groups"
  type        = number
  default     = 30
}

variable "cloudwatch_log_group_kms_key_id" {
  description = "The ARN of the KMS key to use for encrypting CloudWatch Log Groups"
  type        = string
  default     = null
}

# Service Discovery
variable "service_discovery_namespace_name" {
  description = "The name of the service discovery namespace"
  type        = string
  default     = null
}

variable "service_discovery_namespace_description" {
  description = "The description of the service discovery namespace"
  type        = string
  default     = "Service discovery namespace for TrustAInvest services"
}

# Tags
variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
