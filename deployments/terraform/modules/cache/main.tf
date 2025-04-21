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

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name        = "${local.name_prefix}-cache-subnet-group"
  description = "Cache subnet group for ${local.name_prefix}"
  subnet_ids  = var.subnet_ids
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-cache-subnet-group"
    }
  )
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  name        = "${local.name_prefix}-cache-parameter-group"
  family      = "redis7"
  description = "Cache parameter group for ${local.name_prefix}"
  
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-cache-parameter-group"
    }
  )
}

# KMS Key for ElastiCache encryption
resource "aws_kms_key" "cache" {
  description             = "KMS key for ElastiCache encryption for ${local.name_prefix}"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-cache-kms-key"
    }
  )
}

resource "aws_kms_alias" "cache" {
  name          = "alias/${local.name_prefix}-cache-key"
  target_key_id = aws_kms_key.cache.key_id
}

# ElastiCache Replication Group
resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis cluster for ${local.name_prefix}"
  
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = var.port
  parameter_group_name = aws_elasticache_parameter_group.main.name
  
  subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.security_group_id]
  
  # Single node configuration
  num_cache_clusters = var.num_cache_nodes
  
  # Multi-AZ configuration
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled
  
  # Encryption
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token
  kms_key_id                 = aws_kms_key.cache.arn
  
  # Maintenance
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  maintenance_window         = var.maintenance_window
  
  # Snapshots
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window          = var.snapshot_window
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-redis"
    }
  )
  
  lifecycle {
    prevent_destroy = false
  }
}

# CloudWatch Alarms for ElastiCache
resource "aws_cloudwatch_metric_alarm" "cache_cpu" {
  alarm_name          = "${local.name_prefix}-cache-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-cache-cpu-utilization"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "cache_memory" {
  alarm_name          = "${local.name_prefix}-cache-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors ElastiCache memory utilization"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-cache-memory-utilization"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "cache_connections" {
  alarm_name          = "${local.name_prefix}-cache-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 1000
  alarm_description   = "This metric monitors ElastiCache connections"
  alarm_actions       = []
  ok_actions          = []
  
  dimensions = {
    CacheClusterId = aws_elasticache_replication_group.main.id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-cache-connections"
    }
  )
}
