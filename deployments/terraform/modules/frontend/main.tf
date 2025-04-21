locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  s3_origin_id = "${local.name_prefix}-s3-origin"
  alb_origin_id = "${local.name_prefix}-alb-origin"
  
  domain_name = var.domain_name != null ? var.domain_name : "${local.name_prefix}.com"
  
  tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "main" {
  comment = "OAI for ${local.name_prefix} CloudFront distribution"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.frontend_bucket_name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${var.frontend_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}

# CloudFront Cache Policy
resource "aws_cloudfront_cache_policy" "main" {
  count = var.cloudfront_cache_policy_id == null ? 1 : 0
  
  name        = "${local.name_prefix}-cache-policy"
  comment     = "Cache policy for ${local.name_prefix} CloudFront distribution"
  default_ttl = var.cloudfront_default_ttl
  max_ttl     = var.cloudfront_max_ttl
  min_ttl     = var.cloudfront_min_ttl
  
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    
    headers_config {
      header_behavior = "none"
    }
    
    query_strings_config {
      query_string_behavior = "none"
    }
    
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# CloudFront Origin Request Policy
resource "aws_cloudfront_origin_request_policy" "main" {
  count = var.cloudfront_origin_request_policy_id == null ? 1 : 0
  
  name    = "${local.name_prefix}-origin-request-policy"
  comment = "Origin request policy for ${local.name_prefix} CloudFront distribution"
  
  cookies_config {
    cookie_behavior = "none"
  }
  
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Origin", "Host"]
    }
  }
  
  query_strings_config {
    query_string_behavior = "all"
  }
}

# CloudFront Response Headers Policy
resource "aws_cloudfront_response_headers_policy" "main" {
  count = var.cloudfront_response_headers_policy_id == null ? 1 : 0
  
  name    = "${local.name_prefix}-response-headers-policy"
  comment = "Response headers policy for ${local.name_prefix} CloudFront distribution"
  
  security_headers_config {
    content_type_options {
      override = true
    }
    
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
    
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }
  
  cors_config {
    access_control_allow_credentials = false
    
    access_control_allow_headers {
      items = ["*"]
    }
    
    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }
    
    access_control_allow_origins {
      items = ["*"]
    }
    
    origin_override = true
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = var.cloudfront_enabled
  is_ipv6_enabled     = true
  comment             = "${local.name_prefix} CloudFront distribution"
  default_root_object = var.cloudfront_default_root_object
  price_class         = var.cloudfront_price_class
  http_version        = var.cloudfront_http_version
  
  # S3 Origin
  origin {
    domain_name              = var.frontend_bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    
    dynamic "origin_shield" {
      for_each = var.cloudfront_origin_shield_enabled ? [1] : []
      
      content {
        enabled              = true
        origin_shield_region = var.cloudfront_origin_shield_region != null ? var.cloudfront_origin_shield_region : var.region
      }
    }
  }
  
  # ALB Origin (if provided)
  dynamic "origin" {
    for_each = var.alb_dns_name != null ? [1] : []
    
    content {
      domain_name = var.alb_dns_name
      origin_id   = local.alb_origin_id
      
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
        
        origin_keepalive_timeout = var.cloudfront_origin_keepalive_timeout
        origin_read_timeout      = var.cloudfront_origin_read_timeout
      }
      
      dynamic "origin_shield" {
        for_each = var.cloudfront_origin_shield_enabled ? [1] : []
        
        content {
          enabled              = true
          origin_shield_region = var.cloudfront_origin_shield_region != null ? var.cloudfront_origin_shield_region : var.region
        }
      }
    }
  }
  
  # Default Cache Behavior (S3)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id
    
    cache_policy_id            = var.cloudfront_cache_policy_id != null ? var.cloudfront_cache_policy_id : aws_cloudfront_cache_policy.main[0].id
    origin_request_policy_id   = var.cloudfront_origin_request_policy_id != null ? var.cloudfront_origin_request_policy_id : aws_cloudfront_origin_request_policy.main[0].id
    response_headers_policy_id = var.cloudfront_response_headers_policy_id != null ? var.cloudfront_response_headers_policy_id : aws_cloudfront_response_headers_policy.main[0].id
    
    compress               = var.cloudfront_compress
    viewer_protocol_policy = var.cloudfront_viewer_protocol_policy
    
    dynamic "function_association" {
      for_each = var.cloudfront_realtime_log_config_arn != null ? [1] : []
      
      content {
        event_type   = "viewer-request"
        function_arn = var.cloudfront_realtime_log_config_arn
      }
    }
  }
  
  # API Cache Behavior (ALB)
  dynamic "ordered_cache_behavior" {
    for_each = var.alb_dns_name != null ? [1] : []
    
    content {
      path_pattern     = "/api/*"
      allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
      cached_methods   = ["GET", "HEAD", "OPTIONS"]
      target_origin_id = local.alb_origin_id
      
      cache_policy_id            = var.cloudfront_cache_policy_id != null ? var.cloudfront_cache_policy_id : aws_cloudfront_cache_policy.main[0].id
      origin_request_policy_id   = var.cloudfront_origin_request_policy_id != null ? var.cloudfront_origin_request_policy_id : aws_cloudfront_origin_request_policy.main[0].id
      response_headers_policy_id = var.cloudfront_response_headers_policy_id != null ? var.cloudfront_response_headers_policy_id : aws_cloudfront_response_headers_policy.main[0].id
      
      compress               = var.cloudfront_compress
      viewer_protocol_policy = var.cloudfront_viewer_protocol_policy
    }
  }
  
  # Custom Error Responses
  dynamic "custom_error_response" {
    for_each = var.cloudfront_custom_error_responses
    
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }
  
  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction_type
      locations        = var.cloudfront_geo_restriction_locations
    }
  }
  
  # Viewer Certificate
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    
    acm_certificate_arn      = var.acm_certificate_arn
    minimum_protocol_version = var.acm_certificate_arn != null ? var.cloudfront_minimum_protocol_version : "TLSv1"
    ssl_support_method       = var.acm_certificate_arn != null ? var.cloudfront_ssl_support_method : null
  }
  
  # Aliases
  aliases = var.acm_certificate_arn != null ? concat([var.domain_name], var.alternative_domain_names) : []
  
  # Logging
  dynamic "logging_config" {
    for_each = var.cloudfront_access_logs_enabled ? [1] : []
    
    content {
      include_cookies = false
      bucket          = "${var.logs_bucket_name}.s3.amazonaws.com"
      prefix          = var.cloudfront_access_logs_prefix
    }
  }
  
  # WAF
  web_acl_id = var.cloudfront_web_acl_id != null ? var.cloudfront_web_acl_id : (var.waf_web_acl_arn != null ? var.waf_web_acl_arn : null)
  
  tags = local.tags
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${local.name_prefix}-oac"
  description                       = "Origin Access Control for ${local.name_prefix} CloudFront distribution"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
