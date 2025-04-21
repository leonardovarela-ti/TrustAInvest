output "sns_topic_arn" {
  description = "The ARN of the SNS topic for alarms"
  value       = var.create_sns_topic && var.sns_topic_arn == null ? aws_sns_topic.alarms[0].arn : var.sns_topic_arn
}

output "sns_topic_name" {
  description = "The name of the SNS topic for alarms"
  value       = var.create_sns_topic && var.sns_topic_arn == null ? aws_sns_topic.alarms[0].name : null
}

output "dashboard_name" {
  description = "The name of the CloudWatch dashboard"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.main[0].dashboard_name : null
}

output "dashboard_arn" {
  description = "The ARN of the CloudWatch dashboard"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.main[0].dashboard_arn : null
}

output "rds_cpu_alarm_arn" {
  description = "The ARN of the RDS CPU alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.rds_cpu[0].arn : null
}

output "rds_memory_alarm_arn" {
  description = "The ARN of the RDS memory alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.rds_memory[0].arn : null
}

output "rds_storage_alarm_arn" {
  description = "The ARN of the RDS storage alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.rds_storage[0].arn : null
}

output "rds_connections_alarm_arn" {
  description = "The ARN of the RDS connections alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.rds_connections[0].arn : null
}

output "redis_cpu_alarm_arn" {
  description = "The ARN of the ElastiCache CPU alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.redis_cpu[0].arn : null
}

output "redis_memory_alarm_arn" {
  description = "The ARN of the ElastiCache memory alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.redis_memory[0].arn : null
}

output "redis_connections_alarm_arn" {
  description = "The ARN of the ElastiCache connections alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.redis_connections[0].arn : null
}

output "alb_5xx_alarm_arn" {
  description = "The ARN of the ALB 5XX alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.alb_5xx[0].arn : null
}

output "alb_4xx_alarm_arn" {
  description = "The ARN of the ALB 4XX alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.alb_4xx[0].arn : null
}

output "alb_target_5xx_alarm_arn" {
  description = "The ARN of the ALB target 5XX alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.alb_target_5xx[0].arn : null
}

output "alb_target_response_time_alarm_arn" {
  description = "The ARN of the ALB target response time alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.alb_target_response_time[0].arn : null
}

output "ecs_cpu_alarm_arn" {
  description = "The ARN of the ECS CPU alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.ecs_cpu[0].arn : null
}

output "ecs_memory_alarm_arn" {
  description = "The ARN of the ECS memory alarm"
  value       = var.create_alarms ? aws_cloudwatch_metric_alarm.ecs_memory[0].arn : null
}

output "cloudfront_5xx_alarm_arn" {
  description = "The ARN of the CloudFront 5XX alarm"
  value       = var.create_alarms && var.cloudfront_distribution_id != null ? aws_cloudwatch_metric_alarm.cloudfront_5xx[0].arn : null
}

output "cloudfront_4xx_alarm_arn" {
  description = "The ARN of the CloudFront 4XX alarm"
  value       = var.create_alarms && var.cloudfront_distribution_id != null ? aws_cloudwatch_metric_alarm.cloudfront_4xx[0].arn : null
}

output "log_metric_filters_error" {
  description = "The ARNs of the CloudWatch log metric filters for errors"
  value       = var.create_log_metrics ? aws_cloudwatch_log_metric_filter.error[*].id : null
}

output "log_metric_filters_warning" {
  description = "The ARNs of the CloudWatch log metric filters for warnings"
  value       = var.create_log_metrics ? aws_cloudwatch_log_metric_filter.warning[*].id : null
}

output "sns_subscriptions" {
  description = "The ARNs of the SNS topic subscriptions"
  value       = var.create_sns_topic && var.sns_topic_arn == null ? aws_sns_topic_subscription.email[*].arn : null
}
