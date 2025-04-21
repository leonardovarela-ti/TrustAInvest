# This file creates a new container module with new IAM roles to avoid conflicts

# Create new IAM roles with different names
resource "aws_iam_role" "ecs_task_execution_new" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role-new"
  
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
  
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_new" {
  role       = aws_iam_role.ecs_task_execution_new.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_kms_new" {
  name = "${local.name_prefix}-ecs-task-execution-kms-policy-new"
  role = aws_iam_role.ecs_task_execution_new.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = module.security.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_new" {
  name = "${var.project_name}-${var.environment}-ecs-task-role-new"
  
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
  
  tags = local.tags
}

resource "aws_iam_role_policy" "ecs_task_ssm_new" {
  name = "${local.name_prefix}-ecs-task-ssm-policy-new"
  role = aws_iam_role.ecs_task_new.id
  
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

resource "aws_iam_role_policy" "ecs_task_cloudwatch_new" {
  name = "${local.name_prefix}-ecs-task-cloudwatch-policy-new"
  role = aws_iam_role.ecs_task_new.id
  
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

resource "aws_iam_role_policy" "ecs_task_kms_new" {
  name = "${local.name_prefix}-ecs-task-kms-policy-new"
  role = aws_iam_role.ecs_task_new.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = module.security.kms_key_arn
      }
    ]
  })
}

# Use our custom module with the new roles
module "container_with_existing_roles" {
  source = "../../modules/container_with_existing_roles"
  
  # Copy all the parameters from the container_override module
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  vpc_id               = module.networking.vpc_id
  subnet_ids           = module.networking.private_subnet_ids
  security_group_id    = module.networking.ecs_security_group_id
  alb_security_group_id = module.networking.alb_security_group_id
  
  logs_bucket_name = module.storage.logs_bucket_name
  kms_key_arn      = module.security.kms_key_arn
  waf_web_acl_arn  = module.security.waf_web_acl_arn
  
  # Enable WAF association
  enable_waf_association = true
  
  # Explicitly disable ALB access logs
  alb_access_logs_enabled = false
  
  ecs_capacity_providers               = var.ecs_capacity_providers
  ecs_default_capacity_provider_strategy = var.ecs_default_capacity_provider_strategy
  
  # Use the new IAM roles
  ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_new.arn
  ecs_task_role_arn = aws_iam_role.ecs_task_new.arn
  
  tags = local.tags
}

# Use the name_prefix local from main.tf
