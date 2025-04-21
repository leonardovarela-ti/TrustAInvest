output "documents_bucket_id" {
  description = "The ID of the documents bucket"
  value       = aws_s3_bucket.documents.id
}

output "documents_bucket_arn" {
  description = "The ARN of the documents bucket"
  value       = aws_s3_bucket.documents.arn
}

output "documents_bucket_domain_name" {
  description = "The domain name of the documents bucket"
  value       = aws_s3_bucket.documents.bucket_domain_name
}

output "documents_bucket_regional_domain_name" {
  description = "The regional domain name of the documents bucket"
  value       = aws_s3_bucket.documents.bucket_regional_domain_name
}

output "artifacts_bucket_id" {
  description = "The ID of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "The ARN of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "artifacts_bucket_domain_name" {
  description = "The domain name of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket_domain_name
}

output "artifacts_bucket_regional_domain_name" {
  description = "The regional domain name of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket_regional_domain_name
}

output "frontend_bucket_id" {
  description = "The ID of the frontend bucket"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "The ARN of the frontend bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_domain_name" {
  description = "The domain name of the frontend bucket"
  value       = aws_s3_bucket.frontend.bucket_domain_name
}

output "frontend_bucket_regional_domain_name" {
  description = "The regional domain name of the frontend bucket"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "frontend_bucket_website_endpoint" {
  description = "The website endpoint of the frontend bucket"
  value       = var.enable_frontend_website ? aws_s3_bucket_website_configuration.frontend[0].website_endpoint : null
}

output "frontend_bucket_website_domain" {
  description = "The website domain of the frontend bucket"
  value       = var.enable_frontend_website ? aws_s3_bucket_website_configuration.frontend[0].website_domain : null
}

output "logs_bucket_id" {
  description = "The ID of the logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "The ARN of the logs bucket"
  value       = aws_s3_bucket.logs.arn
}

output "logs_bucket_domain_name" {
  description = "The domain name of the logs bucket"
  value       = aws_s3_bucket.logs.bucket_domain_name
}

output "logs_bucket_regional_domain_name" {
  description = "The regional domain name of the logs bucket"
  value       = aws_s3_bucket.logs.bucket_regional_domain_name
}

output "documents_bucket_name" {
  description = "The name of the documents bucket"
  value       = aws_s3_bucket.documents.bucket
}

output "artifacts_bucket_name" {
  description = "The name of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.bucket
}

output "frontend_bucket_name" {
  description = "The name of the frontend bucket"
  value       = aws_s3_bucket.frontend.bucket
}

output "logs_bucket_name" {
  description = "The name of the logs bucket"
  value       = aws_s3_bucket.logs.bucket
}
