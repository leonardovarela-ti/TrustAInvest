provider "aws" {
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
}

# Terraform backend configuration (uncomment and configure as needed)
# terraform {
#   backend "s3" {
#     bucket         = "trustainvest-terraform-state"
#     key            = "dev/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "trustainvest-terraform-locks"
#     encrypt        = true
#   }
# }

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
  
  # ALB logs bucket name
  alb_logs_bucket_name = "${var.project_name}-${var.environment}-alb-logs"
  
  # Enable CloudFront WAF association with the global WAF web ACL
  frontend_cloudfront_waf_enabled = true
  frontend_cloudfront_waf_web_acl_arn = aws_wafv2_web_acl.cloudfront.arn
  
  # Enable CloudFront logs now that the S3 bucket ACL issues are fixed
  frontend_cloudfront_logs_enabled = true
  
  # Enable CloudFront DNS records creation for www subdomain only
  dns_create_cloudfront_records = true
  dns_cloudfront_domains = ["www.trustainvest.com"]
  dns_exclude_apex_domain = true
  
  # Disable log metrics until we can fix the dimensions issue
  monitoring_create_log_metrics = false
  
  # Disable ALB access logs (this is now overridden in the container module)
  container_alb_access_logs_enabled = false
}

# Create a dedicated S3 bucket for ALB logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = local.alb_logs_bucket_name
  
  tags = merge(
    local.tags,
    {
      Name = local.alb_logs_bucket_name
    }
  )
}

# Configure bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Configure bucket ACL
resource "aws_s3_bucket_acl" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.alb_logs]
}

# Configure server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Configure lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"
    
    # Add prefix to fix the warning
    prefix = ""
    
    expiration {
      days = 90
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure bucket policy for ALB logs
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  
  depends_on = [aws_s3_bucket_acl.alb_logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root" # ELB Account ID for us-east-1
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# Networking
module "networking" {
  source = "../../modules/networking"
  
  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  
  tags = local.tags
}

# Security
module "security" {
  source = "../../modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  vpc_id       = module.networking.vpc_id
  
  tags = local.tags
}

# Storage
module "storage" {
  source = "../../modules/storage"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  # Create a temporary KMS key for storage encryption
  # This avoids the circular dependency with the security module
  kms_key_arn = aws_kms_key.storage_encryption.arn
  
  tags = local.tags
}

# Configure S3 bucket ACLs for CloudFront and ALB logs
# CloudFront and ALB require ACLs to be enabled on the S3 bucket to write logs
# We need to add ownership controls and enable ACLs for the logs bucket

# Create a new S3 bucket ownership controls resource for the logs bucket
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = module.storage.logs_bucket_name

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Create a new S3 bucket ACL resource for the logs bucket
resource "aws_s3_bucket_acl" "logs" {
  bucket = module.storage.logs_bucket_name
  acl    = "log-delivery-write"

  # The ACL can only be set after the ownership controls
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

# Update the existing S3 bucket policy to allow ALB and CloudFront to write logs
resource "aws_s3_bucket_policy" "logs_updated" {
  bucket = module.storage.logs_bucket_name

  # The policy can only be set after the ACL
  depends_on = [aws_s3_bucket_acl.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ALB Access Logs - ELB Account
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::127311923021:root" # AWS ELB service account for us-east-1
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/alb-logs/*"
      },
      # ALB Access Logs - Delivery Service
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/alb-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # ALB Access Logs - Get Bucket ACL
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}"
      },
      # ALB Access Logs - ELB Log Delivery
      {
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = ["s3:PutObject", "s3:GetBucketAcl"]
        Resource = [
          "arn:aws:s3:::${module.storage.logs_bucket_name}",
          "arn:aws:s3:::${module.storage.logs_bucket_name}/alb-logs/*"
        ]
      },
      # CloudFront Access Logs - Put Object
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}/cloudfront-logs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      # CloudFront Access Logs - Get Bucket ACL
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${module.storage.logs_bucket_name}"
      }
    ]
  })
}

# Temporary KMS key for storage encryption
resource "aws_kms_key" "storage_encryption" {
  description             = "Temporary KMS key for storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-storage-encryption-key"
    }
  )
}

resource "aws_kms_alias" "storage_encryption" {
  name          = "alias/${local.name_prefix}-storage-encryption-key"
  target_key_id = aws_kms_key.storage_encryption.key_id
}

# Create a global WAF web ACL for CloudFront
resource "aws_wafv2_web_acl" "cloudfront" {
  name        = "${local.name_prefix}-cloudfront-web-acl"
  description = "WAF Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"
  
  default_action {
    allow {}
  }
  
  # AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-cloudfront-common-rule-set"
      sampled_requests_enabled   = true
    }
  }
  
  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-cloudfront-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }
  
  # Rate-based rule to prevent DDoS attacks
  rule {
    name     = "RateBasedRule"
    priority = 3
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 10000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-cloudfront-rate-based-rule"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-cloudfront-web-acl"
    sampled_requests_enabled   = true
  }
  
  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-cloudfront-web-acl"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Database
module "database" {
  source = "../../modules/database"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.database_subnet_ids
  security_group_id = module.networking.database_security_group_id
  
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  multi_az               = var.db_multi_az
  
  tags = local.tags
}

# Cache
module "cache" {
  source = "../../modules/cache"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.redis_security_group_id
  
  node_type           = var.redis_node_type
  engine_version      = var.redis_engine_version
  multi_az_enabled    = var.redis_multi_az_enabled
  
  tags = local.tags
}

# Container
# Create new IAM roles with different names to avoid conflicts
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

# Use the container module instead of container_with_existing_roles
module "container" {
  source = "../../modules/container"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  vpc_id               = module.networking.vpc_id
  subnet_ids           = module.networking.private_subnet_ids
  security_group_id    = module.networking.ecs_security_group_id
  alb_security_group_id = module.networking.alb_security_group_id
  
  # Use the general logs bucket for other logs
  logs_bucket_name = module.storage.logs_bucket_name
  kms_key_arn      = module.security.kms_key_arn
  waf_web_acl_arn  = module.security.waf_web_acl_arn
  
  # Enable WAF association
  enable_waf_association = true
  
  # Explicitly disable ALB access logs
  alb_access_logs_enabled = false
  
  ecs_capacity_providers               = var.ecs_capacity_providers
  ecs_default_capacity_provider_strategy = var.ecs_default_capacity_provider_strategy
  
  tags = local.tags
}

# Frontend
module "frontend" {
  source = "../../modules/frontend"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  frontend_bucket_name              = module.storage.frontend_bucket_name
  frontend_bucket_arn               = module.storage.frontend_bucket_arn
  frontend_bucket_domain_name       = module.storage.frontend_bucket_domain_name
  frontend_bucket_regional_domain_name = module.storage.frontend_bucket_regional_domain_name
  
  logs_bucket_name = module.storage.logs_bucket_name
  kms_key_arn      = module.security.kms_key_arn
  # Use the global WAF web ACL for CloudFront
  waf_web_acl_arn  = try(local.frontend_cloudfront_waf_enabled, false) ? try(local.frontend_cloudfront_waf_web_acl_arn, module.security.waf_web_acl_arn) : null
  
  alb_dns_name = module.container.alb_dns_name
  alb_zone_id  = module.container.alb_zone_id
  
  domain_name            = var.domain_name
  alternative_domain_names = var.alternative_domain_names
  acm_certificate_arn    = var.acm_certificate_arn
  cloudfront_price_class = var.cloudfront_price_class
  
  # Disable CloudFront logs until S3 bucket ACL access is fixed
  cloudfront_access_logs_enabled = try(local.frontend_cloudfront_logs_enabled, true)
  
  tags = local.tags
}

# Monitoring
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  vpc_id                   = module.networking.vpc_id
  db_instance_id           = module.database.db_instance_id
  redis_replication_group_id = module.cache.redis_replication_group_id
  alb_arn_suffix           = module.container.alb_arn_suffix
  ecs_cluster_name         = module.container.ecs_cluster_name
  cloudfront_distribution_id = module.frontend.cloudfront_distribution_id
  
  logs_bucket_name = module.storage.logs_bucket_name
  kms_key_arn      = module.security.kms_key_arn
  
  sns_subscription_email_addresses = var.sns_subscription_email_addresses
  
  # Enable CloudFront alarms
  enable_cloudfront_alarms = true
  
  # Disable log metrics until we can fix the dimensions issue
  create_log_metrics = try(local.monitoring_create_log_metrics, true)
  
  log_group_names = [
    "/aws/ecs/${local.name_prefix}/user-service",
    "/aws/ecs/${local.name_prefix}/account-service",
    "/aws/ecs/${local.name_prefix}/trust-service",
    "/aws/ecs/${local.name_prefix}/investment-service",
    "/aws/ecs/${local.name_prefix}/document-service",
    "/aws/ecs/${local.name_prefix}/notification-service",
    "/aws/ecs/${local.name_prefix}/user-registration-service",
    "/aws/ecs/${local.name_prefix}/kyc-verifier-service",
    "/aws/ecs/${local.name_prefix}/etrade-service",
    "/aws/ecs/${local.name_prefix}/capitalone-service",
    "/aws/ecs/${local.name_prefix}/etrade-callback",
    "/aws/ecs/${local.name_prefix}/kyc-worker"
  ]
  
  tags = local.tags
}

# DNS
module "dns" {
  source = "../../modules/dns"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  
  route53_hosted_zone_id   = var.route53_hosted_zone_id
  route53_hosted_zone_name = var.route53_hosted_zone_name
  
  domain_name                          = var.domain_name
  alternative_domain_names             = var.alternative_domain_names
  cloudfront_distribution_domain_name  = module.frontend.cloudfront_distribution_domain_name
  cloudfront_distribution_hosted_zone_id = module.frontend.cloudfront_distribution_hosted_zone_id
  
  alb_dns_name = module.container.alb_dns_name
  alb_zone_id  = module.container.alb_zone_id
  
  create_api_record = true
  enable_api_dns    = true
  api_subdomain     = "api"
  
  # Disable CloudFront DNS records creation because they already exist
  create_cloudfront_records = true
  cloudfront_domains = ["www.trustainvest.com"]
  
  tags = local.tags
}

# Commented out modules that are causing errors

# Cognito (commented out because the module is not fully implemented yet)
# module "cognito" {
#   source = "../../modules/cognito"
#   
#   # These parameters are not supported by the cognito module yet
#   # environment = "dev"
#   # project_name = "TrustAInvest.com"
# }

# ECS (commented out because it's using parameters that don't match the module's interface)
# module "ecs" {
#   source = "../../modules/ecs"
#   
#   # These parameters are causing errors
#   # environment = "dev"
#   # project_name = "TrustAInvest.com"
#   # vpc_id = module.vpc.vpc_id
#   # subnet_ids = module.vpc.private_subnet_ids
#   # security_group_id = module.security.ecs_security_group_id
#   # db_host = module.database.db_host
#   # db_name = module.database.db_name
#   # db_user = module.database.db_user
#   # db_password = var.db_password
#   # redis_host = module.cache.redis_host
#   # cognito_user_pool_id = module.cognito.user_pool_id
#   # documents_bucket_name = module.storage.documents_bucket_name
# }

# VPC (commented out because it's referenced by the ecs module but not properly defined)
# module "vpc" {
#   source = "../../modules/vpc"
#   
#   # These parameters might be causing errors
#   # environment = "dev"
#   # project_name = "TrustAInvest.com"
#   # vpc_cidr = "10.0.0.0/16"
#   # availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
# }
