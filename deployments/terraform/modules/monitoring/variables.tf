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

variable "db_instance_id" {
  description = "The ID of the RDS instance"
  type        = string
}

variable "redis_replication_group_id" {
  description = "The ID of the ElastiCache Replication Group"
  type        = string
}

variable "alb_arn_suffix" {
  description = "The ARN suffix of the ALB"
  type        = string
}

variable "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  type        = string
  default     = null
}

variable "logs_bucket_name" {
  description = "The name of the S3 bucket for logs"
  type        = string
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key for encryption"
  type        = string
}

variable "sns_topic_arn" {
  description = "The ARN of the SNS topic for alarms"
  type        = string
  default     = null
}

variable "create_sns_topic" {
  description = "Whether to create an SNS topic for alarms"
  type        = bool
  default     = true
}

variable "sns_topic_name" {
  description = "The name of the SNS topic for alarms"
  type        = string
  default     = null
}

variable "sns_subscription_email_addresses" {
  description = "Email addresses to subscribe to the SNS topic"
  type        = list(string)
  default     = []
}

variable "create_dashboard" {
  description = "Whether to create a CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "The name of the CloudWatch dashboard"
  type        = string
  default     = null
}

variable "create_alarms" {
  description = "Whether to create CloudWatch alarms"
  type        = bool
  default     = true
}

variable "alarm_prefix" {
  description = "The prefix for CloudWatch alarms"
  type        = string
  default     = null
}

# RDS Alarms
variable "rds_cpu_threshold" {
  description = "The CPU threshold for RDS alarms"
  type        = number
  default     = 80
}

variable "rds_memory_threshold" {
  description = "The memory threshold for RDS alarms (in bytes)"
  type        = number
  default     = 1000000000 # 1 GB
}

variable "rds_storage_threshold" {
  description = "The storage threshold for RDS alarms (in bytes)"
  type        = number
  default     = 5000000000 # 5 GB
}

variable "rds_connections_threshold" {
  description = "The connections threshold for RDS alarms"
  type        = number
  default     = 100
}

# ElastiCache Alarms
variable "redis_cpu_threshold" {
  description = "The CPU threshold for ElastiCache alarms"
  type        = number
  default     = 80
}

variable "redis_memory_threshold" {
  description = "The memory threshold for ElastiCache alarms (percentage)"
  type        = number
  default     = 80
}

variable "redis_connections_threshold" {
  description = "The connections threshold for ElastiCache alarms"
  type        = number
  default     = 1000
}

# ALB Alarms
variable "alb_5xx_threshold" {
  description = "The 5XX threshold for ALB alarms"
  type        = number
  default     = 10
}

variable "alb_4xx_threshold" {
  description = "The 4XX threshold for ALB alarms"
  type        = number
  default     = 100
}

variable "alb_target_5xx_threshold" {
  description = "The target 5XX threshold for ALB alarms"
  type        = number
  default     = 10
}

variable "alb_target_response_time_threshold" {
  description = "The target response time threshold for ALB alarms (in seconds)"
  type        = number
  default     = 2
}

# ECS Alarms
variable "ecs_cpu_threshold" {
  description = "The CPU threshold for ECS alarms (percentage)"
  type        = number
  default     = 80
}

variable "ecs_memory_threshold" {
  description = "The memory threshold for ECS alarms (percentage)"
  type        = number
  default     = 80
}

# CloudFront Alarms
variable "enable_cloudfront_alarms" {
  description = "Whether to enable CloudFront alarms (set to true when CloudFront distribution is available)"
  type        = bool
  default     = false
}

variable "cloudfront_5xx_threshold" {
  description = "The 5XX threshold for CloudFront alarms"
  type        = number
  default     = 10
}

variable "cloudfront_4xx_threshold" {
  description = "The 4XX threshold for CloudFront alarms"
  type        = number
  default     = 100
}

# Log Metrics
variable "create_log_metrics" {
  description = "Whether to create CloudWatch log metrics"
  type        = bool
  default     = true
}

variable "log_group_names" {
  description = "The names of the CloudWatch log groups to create metrics for"
  type        = list(string)
  default     = []
}

variable "error_pattern" {
  description = "The pattern to match for error log metrics"
  type        = string
  default     = "ERROR"
}

variable "warning_pattern" {
  description = "The pattern to match for warning log metrics"
  type        = string
  default     = "WARN"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
