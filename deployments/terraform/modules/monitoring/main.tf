locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  sns_topic_name = var.sns_topic_name != null ? var.sns_topic_name : "${local.name_prefix}-alarms"
  dashboard_name = var.dashboard_name != null ? var.dashboard_name : "${local.name_prefix}-dashboard"
  alarm_prefix   = var.alarm_prefix != null ? var.alarm_prefix : "${local.name_prefix}"
  
  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# SNS Topic for Alarms
resource "aws_sns_topic" "alarms" {
  count = var.create_sns_topic && var.sns_topic_arn == null ? 1 : 0
  
  name              = local.sns_topic_name
  kms_master_key_id = var.kms_key_arn
  
  tags = merge(
    local.tags,
    {
      Name = local.sns_topic_name
    }
  )
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "email" {
  count = var.create_sns_topic && var.sns_topic_arn == null ? length(var.sns_subscription_email_addresses) : 0
  
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.sns_subscription_email_addresses[count.index]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  count = var.create_dashboard ? 1 : 0
  
  dashboard_name = local.dashboard_name
  
  dashboard_body = jsonencode({
    widgets = [
      # RDS Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id],
            [".", "FreeableMemory", ".", "."],
            [".", "FreeStorageSpace", ".", "."],
            [".", "DatabaseConnections", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS Metrics"
          period  = 300
        }
      },
      # ElastiCache Metrics
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "ReplicationGroupId", var.redis_replication_group_id],
            [".", "DatabaseMemoryUsagePercentage", ".", "."],
            [".", "CurrConnections", ".", "."],
            [".", "NetworkBytesIn", ".", "."],
            [".", "NetworkBytesOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ElastiCache Metrics"
          period  = 300
        }
      },
      # ALB Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "TargetResponseTime", ".", ".", { "stat": "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB Metrics"
          period  = 300
        }
      },
      # ECS Metrics
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name],
            [".", "MemoryUtilization", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ECS Metrics"
          period  = 300
        }
      },
      # CloudFront Metrics (if provided)
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = var.cloudfront_distribution_id != null ? [
            ["AWS/CloudFront", "Requests", "DistributionId", var.cloudfront_distribution_id, "Region", "Global"],
            [".", "4xxErrorRate", ".", ".", ".", "."],
            [".", "5xxErrorRate", ".", ".", ".", "."],
            [".", "TotalErrorRate", ".", ".", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1" # CloudFront metrics are in us-east-1
          title   = "CloudFront Metrics"
          period  = 300
        }
      },
      # Log Metrics
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = var.create_log_metrics ? concat(
            [for log_group in var.log_group_names : ["TrustAInvest", "ErrorCount", "LogGroupName", log_group]],
            [for log_group in var.log_group_names : [".", "WarningCount", ".", log_group]]
          ) : []
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Log Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Log Metric Filters
resource "aws_cloudwatch_log_metric_filter" "error" {
  count = var.create_log_metrics ? length(var.log_group_names) : 0
  
  name           = "${local.name_prefix}-${element(var.log_group_names, count.index)}-error"
  pattern        = var.error_pattern
  log_group_name = element(var.log_group_names, count.index)
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "TrustAInvest"
    value     = "1"
    dimensions = {
      LogGroupName = element(var.log_group_names, count.index)
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "warning" {
  count = var.create_log_metrics ? length(var.log_group_names) : 0
  
  name           = "${local.name_prefix}-${element(var.log_group_names, count.index)}-warning"
  pattern        = var.warning_pattern
  log_group_name = element(var.log_group_names, count.index)
  
  metric_transformation {
    name      = "WarningCount"
    namespace = "TrustAInvest"
    value     = "1"
    dimensions = {
      LogGroupName = element(var.log_group_names, count.index)
    }
  }
}

# CloudWatch Alarms
# RDS Alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-rds-cpu-utilization"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-rds-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_memory_threshold
  alarm_description   = "This metric monitors RDS freeable memory"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-rds-freeable-memory"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-rds-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_storage_threshold
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-rds-free-storage-space"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-rds-database-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-rds-database-connections"
    }
  )
}

# ElastiCache Alarms
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_cpu_threshold
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    ReplicationGroupId = var.redis_replication_group_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-redis-cpu-utilization"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_memory_threshold
  alarm_description   = "This metric monitors ElastiCache memory utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    ReplicationGroupId = var.redis_replication_group_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-redis-memory-utilization"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "redis_connections" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-redis-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = var.redis_connections_threshold
  alarm_description   = "This metric monitors ElastiCache connections"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    ReplicationGroupId = var.redis_replication_group_id
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-redis-connections"
    }
  )
}

# ALB Alarms
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-alb-5xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_4xx" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-alb-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_4xx_threshold
  alarm_description   = "This metric monitors ALB 4XX errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-alb-4xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_target_5xx" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-alb-target-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_target_5xx_threshold
  alarm_description   = "This metric monitors ALB target 5XX errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-alb-target-5xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-alb-target-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_target_response_time_threshold
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-alb-target-response-time"
    }
  )
}

# ECS Alarms
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-ecs-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_cpu_threshold
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    ClusterName = var.ecs_cluster_name
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-ecs-cpu-utilization"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  count = var.create_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-ecs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.ecs_memory_threshold
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    ClusterName = var.ecs_cluster_name
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-ecs-memory-utilization"
    }
  )
}

# CloudFront Alarms
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  count = var.create_alarms && var.enable_cloudfront_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-cloudfront-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = var.cloudfront_5xx_threshold
  alarm_description   = "This metric monitors CloudFront 5XX errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-cloudfront-5xx-errors"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  count = var.create_alarms && var.enable_cloudfront_alarms ? 1 : 0
  
  alarm_name          = "${local.alarm_prefix}-cloudfront-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = var.cloudfront_4xx_threshold
  alarm_description   = "This metric monitors CloudFront 4XX errors"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  ok_actions          = var.sns_topic_arn != null ? [var.sns_topic_arn] : (var.create_sns_topic ? [aws_sns_topic.alarms[0].arn] : [])
  
  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
  
  tags = merge(
    local.tags,
    {
      Name = "${local.alarm_prefix}-cloudfront-4xx-errors"
    }
  )
}
