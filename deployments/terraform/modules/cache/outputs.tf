output "redis_replication_group_id" {
  description = "The ID of the ElastiCache Replication Group"
  value       = aws_elasticache_replication_group.main.id
}

output "redis_replication_group_arn" {
  description = "The ARN of the ElastiCache Replication Group"
  value       = aws_elasticache_replication_group.main.arn
}

output "redis_primary_endpoint_address" {
  description = "The address of the endpoint for the primary node in the replication group"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "redis_reader_endpoint_address" {
  description = "The address of the endpoint for the reader node in the replication group"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "redis_port" {
  description = "The port number on which each of the cache nodes accepts connections"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_configuration_endpoint_address" {
  description = "The configuration endpoint address to allow host discovery"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "redis_member_clusters" {
  description = "The identifiers of all the nodes that are part of this replication group"
  value       = aws_elasticache_replication_group.main.member_clusters
}

output "redis_subnet_group_name" {
  description = "The name of the ElastiCache Subnet Group"
  value       = aws_elasticache_subnet_group.main.name
}

output "redis_parameter_group_name" {
  description = "The name of the ElastiCache Parameter Group"
  value       = aws_elasticache_parameter_group.main.name
}

output "kms_key_id" {
  description = "The ID of the KMS key used for ElastiCache encryption"
  value       = aws_kms_key.cache.id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for ElastiCache encryption"
  value       = aws_kms_key.cache.arn
}

output "redis_engine_version" {
  description = "The Redis engine version"
  value       = aws_elasticache_replication_group.main.engine_version_actual
}

output "redis_at_rest_encryption_enabled" {
  description = "Whether at-rest encryption is enabled"
  value       = aws_elasticache_replication_group.main.at_rest_encryption_enabled
}

output "redis_transit_encryption_enabled" {
  description = "Whether transit encryption is enabled"
  value       = aws_elasticache_replication_group.main.transit_encryption_enabled
}

output "redis_auth_token_enabled" {
  description = "Whether an auth token (password) is enabled"
  value       = aws_elasticache_replication_group.main.auth_token != null
}

output "redis_multi_az_enabled" {
  description = "Whether Multi-AZ is enabled"
  value       = aws_elasticache_replication_group.main.multi_az_enabled
}

output "redis_automatic_failover_enabled" {
  description = "Whether automatic failover is enabled"
  value       = aws_elasticache_replication_group.main.automatic_failover_enabled
}

output "redis_snapshot_retention_limit" {
  description = "The number of days for which ElastiCache will retain automatic snapshots"
  value       = aws_elasticache_replication_group.main.snapshot_retention_limit
}

output "redis_snapshot_window" {
  description = "The daily time range during which automated backups are created"
  value       = aws_elasticache_replication_group.main.snapshot_window
}

output "redis_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur"
  value       = aws_elasticache_replication_group.main.maintenance_window
}
