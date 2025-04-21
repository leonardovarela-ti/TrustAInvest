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

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name != null ? var.user_pool_name : "${local.name_prefix}-user-pool"
  
  # Auto-verification
  auto_verified_attributes = ["email"]
  
  # MFA Configuration
  mfa_configuration = var.mfa_configuration
  
  # SMS Configuration
  sms_configuration {
    external_id    = "${local.name_prefix}-external"
    sns_caller_arn = aws_iam_role.cognito_sns.arn
  }
  
  # Email Configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
  
  # Verification Messages
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_CODE"
    email_message         = var.email_verification_message
    email_subject         = var.email_verification_subject
    sms_message           = var.sms_verification_message
  }
  
  # Password Policy
  password_policy {
    minimum_length                   = var.password_minimum_length
    require_lowercase                = var.password_require_lowercase
    require_uppercase                = var.password_require_uppercase
    require_numbers                  = var.password_require_numbers
    require_symbols                  = var.password_require_symbols
    temporary_password_validity_days = var.password_temporary_validity_days
  }
  
  # Admin Create User Config
  admin_create_user_config {
    allow_admin_create_user_only = var.allow_admin_create_user_only
  }
  
  # User Existence Errors
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }
  
  # Schema Attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "name"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = true
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  schema {
    name                     = "phone_number"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = false
    string_attribute_constraints {
      min_length = 0
      max_length = 2048
    }
  }
  
  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }
  
  # Device Configuration
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }
  
  tags = local.tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "main" {
  name                                 = "${local.name_prefix}-client"
  user_pool_id                         = aws_cognito_user_pool.main.id
  
  generate_secret                      = true
  refresh_token_validity               = 30
  prevent_user_existence_errors        = var.enable_user_existence_errors
  explicit_auth_flows                  = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_CUSTOM_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH"]
  
  # OAuth Settings
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = ["https://${local.name_prefix}.com/callback"]
  logout_urls                          = ["https://${local.name_prefix}.com/logout"]
  supported_identity_providers         = ["COGNITO"]
  
  # Token Validity
  id_token_validity                    = 60
  access_token_validity                = 60
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
  
  read_attributes  = ["email", "email_verified", "name", "phone_number", "phone_number_verified", "updated_at"]
  write_attributes = ["email", "name", "phone_number", "updated_at"]
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${local.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# IAM Role for Cognito to send SMS
resource "aws_iam_role" "cognito_sns" {
  name = "${local.name_prefix}-cognito-sns-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.tags
}

resource "aws_iam_role_policy" "cognito_sns" {
  name = "${local.name_prefix}-cognito-sns-policy"
  role = aws_iam_role.cognito_sns.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# KMS Key for general encryption
resource "aws_kms_key" "general" {
  description             = "KMS key for general encryption for ${local.name_prefix}"
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = var.kms_key_enable_key_rotation
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ],
        Resource = "*",
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-general-kms-key"
    }
  )
}

resource "aws_kms_alias" "general" {
  name          = "alias/${local.name_prefix}-general-key"
  target_key_id = aws_kms_key.general.key_id
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0
  
  name        = "${local.name_prefix}-web-acl"
  description = "WAF Web ACL for ${local.name_prefix}"
  scope       = var.waf_scope
  
  default_action {
    dynamic "allow" {
      for_each = var.waf_default_action == "allow" ? [1] : []
      content {}
    }
    
    dynamic "block" {
      for_each = var.waf_default_action == "block" ? [1] : []
      content {}
    }
  }
  
  # AWS Managed Rules
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-aws-common-rule-set"
      sampled_requests_enabled   = true
    }
  }
  
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-aws-sqli-rule-set"
      sampled_requests_enabled   = true
    }
  }
  
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
    
    override_action {
      none {}
    }
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-aws-known-bad-inputs-rule-set"
      sampled_requests_enabled   = true
    }
  }
  
  # Rate Limiting Rule
  rule {
    name     = "RateLimitRule"
    priority = 4
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit-rule"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-web-acl"
    sampled_requests_enabled   = true
  }
  
  tags = local.tags
}

# SNS Topics
resource "aws_sns_topic" "kyc" {
  count = var.enable_sns_topics ? 1 : 0
  
  name              = "${local.name_prefix}-kyc-topic"
  kms_master_key_id = aws_kms_key.general.id
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-kyc-topic"
    }
  )
}

resource "aws_sns_topic" "notification" {
  count = var.enable_sns_topics ? 1 : 0
  
  name              = "${local.name_prefix}-notification-topic"
  kms_master_key_id = aws_kms_key.general.id
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-notification-topic"
    }
  )
}

# SQS Queues
resource "aws_sqs_queue" "kyc_dlq" {
  count = var.enable_sqs_queues ? 1 : 0
  
  name                      = "${local.name_prefix}-kyc-dlq"
  message_retention_seconds = var.sqs_message_retention_seconds
  kms_master_key_id         = aws_kms_key.general.id
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-kyc-dlq"
    }
  )
}

resource "aws_sqs_queue" "kyc" {
  count = var.enable_sqs_queues ? 1 : 0
  
  name                       = "${local.name_prefix}-kyc-queue"
  message_retention_seconds  = var.sqs_message_retention_seconds
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  max_message_size           = var.sqs_max_message_size
  delay_seconds              = var.sqs_delay_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  kms_master_key_id          = aws_kms_key.general.id
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.kyc_dlq[0].arn
    maxReceiveCount     = 5
  })
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-kyc-queue"
    }
  )
}

resource "aws_sqs_queue" "notification_dlq" {
  count = var.enable_sqs_queues ? 1 : 0
  
  name                      = "${local.name_prefix}-notification-dlq"
  message_retention_seconds = var.sqs_message_retention_seconds
  kms_master_key_id         = aws_kms_key.general.id
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-notification-dlq"
    }
  )
}

resource "aws_sqs_queue" "notification" {
  count = var.enable_sqs_queues ? 1 : 0
  
  name                       = "${local.name_prefix}-notification-queue"
  message_retention_seconds  = var.sqs_message_retention_seconds
  visibility_timeout_seconds = var.sqs_visibility_timeout_seconds
  max_message_size           = var.sqs_max_message_size
  delay_seconds              = var.sqs_delay_seconds
  receive_wait_time_seconds  = var.sqs_receive_wait_time_seconds
  kms_master_key_id          = aws_kms_key.general.id
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_dlq[0].arn
    maxReceiveCount     = 5
  })
  
  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-notification-queue"
    }
  )
}

# SNS to SQS Subscriptions
resource "aws_sns_topic_subscription" "kyc" {
  count = var.enable_sns_topics && var.enable_sqs_queues ? 1 : 0
  
  topic_arn = aws_sns_topic.kyc[0].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.kyc[0].arn
}

resource "aws_sns_topic_subscription" "notification" {
  count = var.enable_sns_topics && var.enable_sqs_queues ? 1 : 0
  
  topic_arn = aws_sns_topic.notification[0].arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notification[0].arn
}

# SQS Queue Policies
resource "aws_sqs_queue_policy" "kyc" {
  count = var.enable_sns_topics && var.enable_sqs_queues ? 1 : 0
  
  queue_url = aws_sqs_queue.kyc[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.kyc[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.kyc[0].arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "notification" {
  count = var.enable_sns_topics && var.enable_sqs_queues ? 1 : 0
  
  queue_url = aws_sqs_queue.notification[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.notification[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.notification[0].arn
          }
        }
      }
    ]
  })
}

# Data Sources
data "aws_caller_identity" "current" {}
