# Create a global WAF web ACL for CloudFront

resource "aws_wafv2_web_acl" "cloudfront" {
  name        = "${local.name_prefix}-cloudfront-web-acl"
  description = "WAF Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"
  
  default_action {
    allow {}
  }
  
  # AWS Managed Rules - Common Rule Set
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
      metric_name                = "${local.name_prefix}-cloudfront-common-rule-set"
      sampled_requests_enabled   = true
    }
  }
  
  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    
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
      metric_name                = "${local.name_prefix}-cloudfront-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }
  
  # Rate-based rule to prevent DDoS attacks
  rule {
    name     = "RateBasedRule"
    priority = 3
    
    action {
      block {}
    }
    
    statement {
      rate_based_statement {
        limit              = 10000
        aggregate_key_type = "IP"
      }
    }
    
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-cloudfront-rate-based-rule"
      sampled_requests_enabled   = true
    }
  }
  
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-cloudfront-web-acl"
    sampled_requests_enabled   = true
  }
  
  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-cloudfront-web-acl"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# The WAF web ACL ARN is referenced in frontend_waf_fix.tf
