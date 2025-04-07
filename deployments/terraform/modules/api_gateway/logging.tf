# API Gateway logging configuration

# CloudWatch Log Group for API Gateway execution logs
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.api.id}/${var.environment}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "API-Gateway-Access-Logs_${aws_api_gateway_rest_api.api.id}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Enable access logging for the API Gateway stage
resource "aws_api_gateway_stage" "logging_settings" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment
  deployment_id = aws_api_gateway_deployment.deployment.id
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
    format          = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      caller                  = "$context.identity.caller"
      user                    = "$context.identity.user"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      errorMessage            = "$context.error.message"
      errorResponseType       = "$context.error.responseType"
      userAgent               = "$context.identity.userAgent"
      integrationStatus       = "$context.integration.status"
      integrationLatency      = "$context.integration.latency"
      responseLatency         = "$context.responseLatency"
    })
  }
  
  # Override the previously created stage
  lifecycle {
    replace_triggered_by = [
      aws_api_gateway_deployment.deployment.id
    ]
  }
  
  count = var.enable_access_logs ? 1 : 0
}

# Configure API Gateway method settings for logging
resource "aws_api_gateway_method_settings" "api_gateway_logging" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.environment
  method_path = "*/*"
  
  settings {
    metrics_enabled      = true
    logging_level        = var.logging_level
    data_trace_enabled   = var.data_trace_enabled
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }
  
  depends_on = [
    aws_api_gateway_stage.stage,
    aws_cloudwatch_log_group.api_gateway_logs
  ]
}

# Create a CloudWatch dashboard for API Gateway metrics
resource "aws_cloudwatch_dashboard" "api_gateway_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-api-gateway"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Sum", "period": 60 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Requests"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Sum", "period": 60 }],
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Sum", "period": 60 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Errors"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Average", "period": 60 }],
            ["AWS/ApiGateway", "IntegrationLatency", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Average", "period": 60 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Latency"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "CacheHitCount", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Sum", "period": 300 }],
            ["AWS/ApiGateway", "CacheMissCount", "ApiName", aws_api_gateway_rest_api.api.name, "Stage", var.environment, { "stat": "Sum", "period": 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Cache Performance"
          hidden  = var.cache_enabled ? false : true
        }
      }
    ]
  })
  
  count = var.create_dashboard ? 1 : 0
}

# Create a log metric filter for 5XX errors
resource "aws_cloudwatch_log_metric_filter" "api_5xx_errors" {
  name           = "${var.project_name}-${var.environment}-api-5xx-errors"
  pattern        = "{ $.status >= 500 && $.status < 600 }"
  log_group_name = aws_cloudwatch_log_group.api_gateway_access_logs.name
  
  metric_transformation {
    name      = "${var.project_name}-${var.environment}-5xx-errors"
    namespace = "ApiGateway/Custom"
    value     = "1"
  }
  
  count = var.enable_access_logs ? 1 : 0
}

# Create a log metric filter for 4XX errors
resource "aws_cloudwatch_log_metric_filter" "api_4xx_errors" {
  name           = "${var.project_name}-${var.environment}-api-4xx-errors"
  pattern        = "{ $.status >= 400 && $.status < 500 }"
  log_group_name = aws_cloudwatch_log_group.api_gateway_access_logs.name
  
  metric_transformation {
    name      = "${var.project_name}-${var.environment}-4xx-errors"
    namespace = "ApiGateway/Custom"
    value     = "1"
  }
  
  count = var.enable_access_logs ? 1 : 0
}

# Data source for current AWS region
data "aws_region" "current" {}