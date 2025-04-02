provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "../modules/vpc"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  cidr_block = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
}

module "security" {
  source = "../modules/security"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  vpc_id = module.vpc.vpc_id
}

module "database" {
  source = "../modules/database"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.db_security_group_id
  instance_class = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  password = var.db_password
}

module "cache" {
  source = "../modules/cache"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.cache_security_group_id
}

module "cognito" {
  source = "../modules/cognito"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
}

module "storage" {
  source = "../modules/storage"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  documents_bucket_name = "TrustAInvest.com-documents-${var.environment}"
  artifacts_bucket_name = "TrustAInvest.com-artifacts-dev"
}

module "api_gateway" {
  source = "../modules/api_gateway"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  cognito_user_pool_id = module.cognito.user_pool_id
}

module "ecs" {
  source = "../modules/ecs"
  
  environment = "dev"
  project_name = "TrustAInvest.com"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.ecs_security_group_id
  db_host = module.database.db_host
  db_name = module.database.db_name
  db_user = module.database.db_user
  db_password = var.db_password
  redis_host = module.cache.redis_host
  cognito_user_pool_id = module.cognito.user_pool_id
  documents_bucket_name = module.storage.documents_bucket_name
}
