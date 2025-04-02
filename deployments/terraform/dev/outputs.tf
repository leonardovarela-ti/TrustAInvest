output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.database.db_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache endpoint"
  value       = module.cache.redis_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_gateway_url
}

output "documents_bucket_name" {
  description = "S3 bucket for documents"
  value       = module.storage.documents_bucket_name
}
