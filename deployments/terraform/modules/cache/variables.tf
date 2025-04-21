variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "trustainvest"
}

variable "environment" {
  description = "The deployment environment (dev, stage, prod)"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "The IDs of the private subnets"
  type        = list(string)
}

variable "security_group_id" {
  description = "The ID of the Redis security group"
  type        = string
}

variable "node_type" {
  description = "The node type for the Redis cluster"
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "The Redis engine version"
  type        = string
  default     = "7.0"
}

variable "port" {
  description = "The port for Redis"
  type        = number
  default     = 6379
}

variable "parameter_group_name" {
  description = "The name of the parameter group to associate with this cache cluster"
  type        = string
  default     = "default.redis7"
}

variable "num_cache_nodes" {
  description = "The number of cache nodes"
  type        = number
  default     = 1
}

variable "automatic_failover_enabled" {
  description = "Whether automatic failover is enabled"
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Whether Multi-AZ is enabled"
  type        = bool
  default     = false
}

variable "at_rest_encryption_enabled" {
  description = "Whether encryption at rest is enabled"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Whether encryption in transit is enabled"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "The password used to access a password protected server"
  type        = string
  default     = null
  sensitive   = true
}

variable "apply_immediately" {
  description = "Whether to apply changes immediately or during the next maintenance window"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Whether to automatically upgrade to new minor versions"
  type        = bool
  default     = true
}

variable "snapshot_retention_limit" {
  description = "The number of days for which ElastiCache will retain automatic snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "The daily time range during which automated backups are created"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The weekly time range during which system maintenance can occur"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
