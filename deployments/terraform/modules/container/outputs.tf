output "ecr_repository_urls" {
  description = "The URLs of the ECR repositories"
  value       = { for name, repo in aws_ecr_repository.repositories : name => repo.repository_url }
}

output "ecr_repository_arns" {
  description = "The ARNs of the ECR repositories"
  value       = { for name, repo in aws_ecr_repository.repositories : name => repo.arn }
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "The name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "The name of the ECS task role"
  value       = aws_iam_role.ecs_task.name
}

output "cloudwatch_log_groups" {
  description = "The CloudWatch log groups for ECS services"
  value       = { for name, log_group in aws_cloudwatch_log_group.ecs_services : name => log_group.name }
}

output "service_discovery_namespace_id" {
  description = "The ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_arn" {
  description = "The ARN of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_discovery_namespace_name" {
  description = "The name of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "alb_id" {
  description = "The ID of the ALB"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "alb_http_listener_arn" {
  description = "The ARN of the ALB HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "alb_https_listener_arn" {
  description = "The ARN of the ALB HTTPS listener"
  value       = var.alb_certificate_arn != null ? aws_lb_listener.https[0].arn : null
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = var.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "The ID of the ECS security group"
  value       = var.security_group_id
}
