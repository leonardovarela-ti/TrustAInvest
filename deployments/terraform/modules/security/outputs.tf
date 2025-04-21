output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "The ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_endpoint" {
  description = "The endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "cognito_user_pool_client_id" {
  description = "The ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_client_secret" {
  description = "The client secret of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "cognito_user_pool_domain" {
  description = "The domain of the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_user_pool_domain_cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution for the Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.main.cloudfront_distribution_arn
}

output "cognito_user_pool_domain_s3_bucket" {
  description = "The S3 bucket for the Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.main.s3_bucket
}

output "kms_key_id" {
  description = "The ID of the KMS key for general encryption"
  value       = aws_kms_key.general.id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key for general encryption"
  value       = aws_kms_key.general.arn
}

output "waf_web_acl_id" {
  description = "The ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "kyc_topic_arn" {
  description = "The ARN of the KYC SNS topic"
  value       = var.enable_sns_topics ? aws_sns_topic.kyc[0].arn : null
}

output "notification_topic_arn" {
  description = "The ARN of the notification SNS topic"
  value       = var.enable_sns_topics ? aws_sns_topic.notification[0].arn : null
}

output "kyc_queue_url" {
  description = "The URL of the KYC SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.kyc[0].id : null
}

output "kyc_queue_arn" {
  description = "The ARN of the KYC SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.kyc[0].arn : null
}

output "kyc_dlq_url" {
  description = "The URL of the KYC dead-letter SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.kyc_dlq[0].id : null
}

output "kyc_dlq_arn" {
  description = "The ARN of the KYC dead-letter SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.kyc_dlq[0].arn : null
}

output "notification_queue_url" {
  description = "The URL of the notification SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.notification[0].id : null
}

output "notification_queue_arn" {
  description = "The ARN of the notification SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.notification[0].arn : null
}

output "notification_dlq_url" {
  description = "The URL of the notification dead-letter SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.notification_dlq[0].id : null
}

output "notification_dlq_arn" {
  description = "The ARN of the notification dead-letter SQS queue"
  value       = var.enable_sqs_queues ? aws_sqs_queue.notification_dlq[0].arn : null
}

output "cognito_sns_role_arn" {
  description = "The ARN of the IAM role for Cognito to send SMS"
  value       = aws_iam_role.cognito_sns.arn
}
