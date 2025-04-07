# API Gateway module implementation

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "REST API for ${var.project_name} ${var.environment} environment"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.kyc_service_integration,
    aws_api_gateway_integration.user_service_integration,
    aws_api_gateway_integration.account_service_integration,
    aws_api_gateway_integration.trust_service_integration,
    aws_api_gateway_integration.investment_service_integration,
    aws_api_gateway_integration.document_service_integration,
    aws_api_gateway_integration.notification_service_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.environment

  lifecycle {
    create_before_destroy = true
  }

  variables = {
    deployed_at = timestamp()
  }
}

# API Gateway stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment

  cache_cluster_enabled = var.cache_enabled
  cache_cluster_size    = var.cache_enabled ? var.cache_size : null

  xray_tracing_enabled = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway Authorizer using Cognito User Pool
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                   = "cognito-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [var.cognito_user_pool_id]
  identity_source        = "method.request.header.Authorization"
  authorizer_credentials = aws_iam_role.api_gateway_authorizer_role.arn
}

# IAM role for API Gateway Authorizer
resource "aws_iam_role" "api_gateway_authorizer_role" {
  name = "${var.project_name}-${var.environment}-api-gateway-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM policy for API Gateway Authorizer role
resource "aws_iam_role_policy" "api_gateway_authorizer_policy" {
  name = "${var.project_name}-${var.environment}-api-gateway-auth-policy"
  role = aws_iam_role.api_gateway_authorizer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cognito-idp:AdminGetUser",
          "cognito-idp:GetUser"
        ]
        Effect   = "Allow"
        Resource = var.cognito_user_pool_id
      }
    ]
  })
}

# ----------------------------------------------------
# API Resources and methods for each microservice
# ----------------------------------------------------

# 1. KYC Service
resource "aws_api_gateway_resource" "kyc_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "kyc"
}

resource "aws_api_gateway_method" "kyc_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.kyc_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "kyc_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.kyc_service.id
  http_method = aws_api_gateway_method.kyc_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.kyc_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# 2. User Service
resource "aws_api_gateway_resource" "user_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "users"
}

resource "aws_api_gateway_method" "user_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.user_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "user_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.user_service.id
  http_method = aws_api_gateway_method.user_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.user_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# 2. Account Service
resource "aws_api_gateway_resource" "account_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "accounts"
}

resource "aws_api_gateway_method" "account_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.account_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "account_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.account_service.id
  http_method = aws_api_gateway_method.account_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.account_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# 3. Trust Service
resource "aws_api_gateway_resource" "trust_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "trusts"
}

resource "aws_api_gateway_method" "trust_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.trust_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "trust_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.trust_service.id
  http_method = aws_api_gateway_method.trust_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.trust_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# 4. Investment Service
resource "aws_api_gateway_resource" "investment_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "investments"
}

resource "aws_api_gateway_method" "investment_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.investment_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "investment_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.investment_service.id
  http_method = aws_api_gateway_method.investment_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.investment_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# 5. Document Service
resource "aws_api_gateway_resource" "document_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "documents"
}

resource "aws_api_gateway_method" "document_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.document_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "document_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.document_service.id
  http_method = aws_api_gateway_method.document_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.document_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# 6. Notification Service
resource "aws_api_gateway_resource" "notification_service" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "notifications"
}

resource "aws_api_gateway_method" "notification_service_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notification_service.id
  http_method   = "ANY"
  authorization_type = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "notification_service_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notification_service.id
  http_method = aws_api_gateway_method.notification_service_any.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${var.notification_service_endpoint}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.api_vpc_link.id
}

# Create a VPC Link to connect API Gateway to the microservices in the VPC
resource "aws_api_gateway_vpc_link" "api_vpc_link" {
  name        = "${var.project_name}-${var.environment}-vpc-link"
  description = "VPC Link for ${var.project_name} ${var.environment} environment"
  target_arns = [var.nlb_arn]
}

# Configure CORS for the API
resource "aws_api_gateway_method" "cors_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.cors_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      "statusCode" : 200
    })
  }
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.cors_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.cors_method.http_method
  status_code = aws_api_gateway_method_response.cors_method_response.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Enable WAF for API Gateway
resource "aws_wafv2_web_acl_association" "api_waf_association" {
  count        = var.waf_acl_arn != "" ? 1 : 0
  resource_arn = aws_api_gateway_stage.stage.arn
  web_acl_arn  = var.waf_acl_arn
}

# Set up CloudWatch logging
resource "aws_api_gateway_method_settings" "api_logging_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = var.environment != "prod"
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.api.id}/${var.environment}"
  retention_in_days = 7
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# API Gateway Usage Plan
resource "aws_api_gateway_usage_plan" "api_usage_plan" {
  name        = "${var.project_name}-${var.environment}-usage-plan"
  description = "Usage plan for ${var.project_name} ${var.environment} API"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }
  
  quota_settings {
    limit  = var.quota_limit
    period = "DAY"
  }
  
  throttle_settings {
    burst_limit = var.throttling_burst_limit
    rate_limit  = var.throttling_rate_limit
  }
}

# API Key for internal services
resource "aws_api_gateway_api_key" "internal_api_key" {
  name = "${var.project_name}-${var.environment}-internal-key"
  description = "API Key for internal services"
  enabled = true
}

# Associate API Key with usage plan
resource "aws_api_gateway_usage_plan_key" "internal_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.internal_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.api_usage_plan.id
}

# API Gateway Custom Domain Name
resource "aws_api_gateway_domain_name" "api_domain" {
  count           = var.custom_domain_name != "" ? 1 : 0
  domain_name     = var.custom_domain_name
  certificate_arn = var.acm_certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "api_mapping" {
  count       = var.custom_domain_name != "" ? 1 : 0
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  domain_name = aws_api_gateway_domain_name.api_domain[0].domain_name
  base_path   = "v1"
}