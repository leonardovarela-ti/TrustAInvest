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
module "container" {
  source = "../../modules/container"
  
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
  
  # Disable ALB access logs until S3 bucket permissions are fixed
  alb_access_logs_enabled = try(local.container_alb_access_logs_enabled, true)
  
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
  # Disable CloudFront WAF association until we have a global WAF web ACL
  waf_web_acl_arn  = try(local.frontend_cloudfront_waf_enabled, false) ? module.security.waf_web_acl_arn : null
  
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
  
  # Disable log metrics until log groups are created
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
