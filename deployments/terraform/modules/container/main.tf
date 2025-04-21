locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  ecs_cluster_name = var.ecs_cluster_name != null ? var.ecs_cluster_name : "${local.name_prefix}-cluster"
  alb_name         = var.alb_name != null ? var.alb_name : "${local.name_prefix}-alb"
  
  service_discovery_namespace_name = var.service_discovery_namespace_name != null ? var.service_discovery_namespace_name : "${local.name_prefix}.local"
  
  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# ECR Repositories
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.ecr_repositories)
  
  name                 = "${local.name_prefix}-${each.key}"
  image_tag_mutability = var.ecr_image_tag_mutability
  
  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }
  
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-${each.key}"
    }
  )
}

resource "aws_ecr_lifecycle_policy" "repositories" {
  for_each = toset(var.ecr_repositories)
  
  repository = aws_ecr_repository.repositories[each.key].name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_lifecycle_policy_max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_lifecycle_policy_max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = local.ecs_cluster_name
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = "OVERRIDE"
      
      log_configuration {
        cloud_watch_encryption_enabled = false
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }
  
  tags = merge(
    local.tags,
    {
      Name = local.ecs_cluster_name
    }
  )
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = var.ecs_capacity_providers
  
  dynamic "default_capacity_provider_strategy" {
    for_each = var.ecs_default_capacity_provider_strategy
    
    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      weight            = default_capacity_provider_strategy.value.weight
      base              = default_capacity_provider_strategy.value.base
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${local.name_prefix}/exec"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  # Temporarily disable KMS encryption to get the deployment working
  # kms_key_id        = var.cloudwatch_log_group_kms_key_id != null ? var.cloudwatch_log_group_kms_key_id : var.kms_key_arn
  
  tags = merge(
    local.tags,
    {
      Name = "/aws/ecs/${local.name_prefix}/exec"
    }
  )
}

resource "aws_cloudwatch_log_group" "ecs_services" {
  for_each = toset(var.ecr_repositories)
  
  name              = "/aws/ecs/${local.name_prefix}/${each.key}"
  retention_in_days = var.cloudwatch_log_group_retention_in_days
  # Temporarily disable KMS encryption to get the deployment working
  # kms_key_id        = var.cloudwatch_log_group_kms_key_id != null ? var.cloudwatch_log_group_kms_key_id : var.kms_key_arn
  
  tags = merge(
    local.tags,
    {
      Name = "/aws/ecs/${local.name_prefix}/${each.key}"
    }
  )
}

# Service Discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = local.service_discovery_namespace_name
  description = var.service_discovery_namespace_description
  vpc         = var.vpc_id
  
  tags = merge(
    local.tags,
    {
      Name = local.service_discovery_namespace_name
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = local.alb_name
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.subnet_ids
  
  enable_deletion_protection = var.alb_enable_deletion_protection
  idle_timeout               = var.alb_idle_timeout
  
  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []
    
    content {
      bucket  = var.logs_bucket_name
      prefix  = var.alb_access_logs_prefix
      enabled = true
    }
  }
  
  tags = merge(
    local.tags,
    {
      Name = local.alb_name
    }
  )
}

# ALB HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_http_port
  protocol          = "HTTP"
  
  default_action {
    type = var.alb_enable_http_to_https_redirect && var.alb_certificate_arn != null ? "redirect" : "fixed-response"
    
    dynamic "redirect" {
      for_each = var.alb_enable_http_to_https_redirect && var.alb_certificate_arn != null ? [1] : []
      
      content {
        port        = var.alb_https_port
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    dynamic "fixed_response" {
      for_each = !var.alb_enable_http_to_https_redirect || var.alb_certificate_arn == null ? [1] : []
      
      content {
        content_type = "text/plain"
        message_body = "Not Found"
        status_code  = "404"
      }
    }
  }
}

# ALB HTTPS Listener
resource "aws_lb_listener" "https" {
  count = var.alb_certificate_arn != null ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_https_port
  protocol          = "HTTPS"
  ssl_policy        = var.alb_ssl_policy
  certificate_arn   = var.alb_certificate_arn
  
  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# WAF Association
resource "aws_wafv2_web_acl_association" "main" {
  count = var.alb_enable_waf && var.enable_waf_association ? 1 : 0
  
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn
}

# CloudWatch Alarms for ALB
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-alb-5xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "This metric monitors ALB 4XX errors"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-alb-4xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx_errors" {
  alarm_name          = "${local.name_prefix}-alb-target-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors ALB target 5XX errors"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-alb-target-5xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${local.name_prefix}-alb-target-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-alb-target-response-time"
    }
  )
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_kms" {
  name = "${local.name_prefix}-ecs-task-execution-kms-policy"
  role = aws_iam_role.ecs_task_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = var.kms_key_arn
      }
    ]
  })
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-ecs-task-role"
    }
  )
}

resource "aws_iam_role_policy" "ecs_task_ssm" {
  name = "${local.name_prefix}-ecs-task-ssm-policy"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_cloudwatch" {
  name = "${local.name_prefix}-ecs-task-cloudwatch-policy"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/ecs/${local.name_prefix}/*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_kms" {
  name = "${local.name_prefix}-ecs-task-kms-policy"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = var.kms_key_arn
      }
    ]
  })
}
