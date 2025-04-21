output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = local.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = data.aws_ecs_cluster.main.arn
}

output "ecs_cluster_id" {
  description = "The ID of the ECS cluster"
  value       = data.aws_ecs_cluster.main.id
}

output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = data.aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the ALB"
  value       = data.aws_lb.main.zone_id
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = data.aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "The ARN suffix of the ALB"
  value       = data.aws_lb.main.arn_suffix
}

output "alb_http_listener_arn" {
  description = "The ARN of the ALB HTTP listener"
  value       = data.aws_lb_listener.http.arn
}

output "alb_https_listener_arn" {
  description = "The ARN of the ALB HTTPS listener"
  value       = var.alb_certificate_arn != null ? data.aws_lb_listener.https[0].arn : null
}

output "service_discovery_namespace_id" {
  description = "The ID of the service discovery namespace"
  value       = null
}

output "service_discovery_namespace_arn" {
  description = "The ARN of the service discovery namespace"
  value       = null
}

output "service_discovery_namespace_name" {
  description = "The name of the service discovery namespace"
  value       = local.service_discovery_namespace_name
}

output "ecr_repository_urls" {
  description = "The URLs of the ECR repositories"
  value       = { for k, v in data.aws_ecr_repository.repositories : k => v.repository_url }
}

output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = local.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "The ARN of the ECS task role"
  value       = local.ecs_task_role_arn
}
