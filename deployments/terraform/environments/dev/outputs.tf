# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  description = "The IDs of the database subnets"
  value       = module.networking.database_subnet_ids
}

# Database
output "db_instance_endpoint" {
  description = "The connection endpoint of the RDS instance"
  value       = module.database.db_instance_endpoint
}

output "db_instance_id" {
  description = "The ID of the RDS instance"
  value       = module.database.db_instance_id
}

output "db_name" {
  description = "The name of the database"
  value       = module.database.db_name
}

output "db_username" {
  description = "The username for the database"
  value       = module.database.db_username
}

# Cache
output "redis_primary_endpoint_address" {
  description = "The address of the endpoint for the primary node in the replication group"
  value       = module.cache.redis_primary_endpoint_address
}

output "redis_replication_group_id" {
  description = "The ID of the ElastiCache Replication Group"
  value       = module.cache.redis_replication_group_id
}

# Security
output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = module.security.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client"
  value       = module.security.cognito_user_pool_client_id
}

output "kms_key_id" {
  description = "The ID of the KMS key for general encryption"
  value       = module.security.kms_key_id
}

output "kyc_topic_arn" {
  description = "The ARN of the KYC SNS topic"
  value       = module.security.kyc_topic_arn
}

output "notification_topic_arn" {
  description = "The ARN of the notification SNS topic"
  value       = module.security.notification_topic_arn
}

output "kyc_queue_url" {
  description = "The URL of the KYC SQS queue"
  value       = module.security.kyc_queue_url
}

output "notification_queue_url" {
  description = "The URL of the notification SQS queue"
  value       = module.security.notification_queue_url
}

# Storage
output "documents_bucket_name" {
  description = "The name of the documents bucket"
  value       = module.storage.documents_bucket_name
}

output "artifacts_bucket_name" {
  description = "The name of the artifacts bucket"
  value       = module.storage.artifacts_bucket_name
}

output "frontend_bucket_name" {
  description = "The name of the frontend bucket"
  value       = module.storage.frontend_bucket_name
}

output "logs_bucket_name" {
  description = "The name of the logs bucket"
  value       = module.storage.logs_bucket_name
}

# Container
output "ecr_repository_urls" {
  description = "The URLs of the ECR repositories"
  value       = module.container_with_existing_roles.ecr_repository_urls
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = module.container_with_existing_roles.ecs_cluster_name
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = module.container_with_existing_roles.alb_dns_name
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = module.container_with_existing_roles.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = module.container_with_existing_roles.ecs_task_role_arn
}

output "service_discovery_namespace_name" {
  description = "The name of the service discovery namespace"
  value       = module.container_with_existing_roles.service_discovery_namespace_name
}

# Frontend
output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = module.frontend.cloudfront_distribution_id
}

# Monitoring
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for alarms"
  value       = module.monitoring.sns_topic_arn
}

output "dashboard_name" {
  description = "The name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}

# DNS
output "cloudfront_dns_records" {
  description = "The Route 53 records for the CloudFront distribution"
  value       = module.dns.cloudfront_dns_records
}

output "api_dns_record" {
  description = "The Route 53 record for the API"
  value       = module.dns.api_dns_record
}

output "api_fqdn" {
  description = "The fully qualified domain name for the API"
  value       = module.dns.api_fqdn
}
