locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  ecs_cluster_name = var.ecs_cluster_name != null ? var.ecs_cluster_name : "${local.name_prefix}-cluster"
  alb_name         = var.alb_name != null ? var.alb_name : "${local.name_prefix}-alb"
  
  service_discovery_namespace_name = var.service_discovery_namespace_name != null ? var.service_discovery_namespace_name : "${local.name_prefix}.local"
  
  # Use the provided ARNs
  ecs_task_execution_role_arn = var.ecs_task_execution_role_arn
  ecs_task_role_arn = var.ecs_task_role_arn
  
  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Use existing ECR Repositories
data "aws_ecr_repository" "repositories" {
  for_each = toset(var.ecr_repositories)
  
  name = "${local.name_prefix}-${each.key}"
}

# Use existing ECS Cluster
data "aws_ecs_cluster" "main" {
  cluster_name = local.ecs_cluster_name
}

# Use existing CloudWatch Log Groups
data "aws_cloudwatch_log_group" "ecs_exec" {
  name = "/aws/ecs/${local.name_prefix}/exec"
}

data "aws_cloudwatch_log_group" "ecs_services" {
  for_each = toset(var.ecr_repositories)
  
  name = "/aws/ecs/${local.name_prefix}/${each.key}"
}

# Use existing Application Load Balancer
data "aws_lb" "main" {
  name = local.alb_name
}

# Use existing ALB HTTP Listener
data "aws_lb_listener" "http" {
  load_balancer_arn = data.aws_lb.main.arn
  port              = var.alb_http_port
}

# Use existing ALB HTTPS Listener if certificate is provided
data "aws_lb_listener" "https" {
  count = var.alb_certificate_arn != null ? 1 : 0
  
  load_balancer_arn = data.aws_lb.main.arn
  port              = var.alb_https_port
}

# We don't create IAM roles in this module, we use the ones provided
