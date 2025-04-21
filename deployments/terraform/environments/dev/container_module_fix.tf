# This file modifies the container module configuration to fix issues with ALB access logs

# We still have issues with the S3 bucket policy for ALB access logs
# We need to disable ALB access logs until we fix the S3 bucket policy

# Override the container module variables using locals
locals {
  # Disable ALB access logs
  container_alb_access_logs_enabled = false
}

# The locals are referenced in the main.tf file

# Create a new module call to override the container module with explicit alb_access_logs_enabled = false
module "container_override" {
  source = "../../modules/container"
  
  # Copy all the parameters from the original module call
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
  
  tags = local.tags
}
