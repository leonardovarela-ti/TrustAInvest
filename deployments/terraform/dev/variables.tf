variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  default     = "TrustAInvest.com"
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  default     = 20
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
}
