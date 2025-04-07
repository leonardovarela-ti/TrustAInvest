# Service discovery for microservices

# Create a service discovery namespace if needed
resource "aws_service_discovery_private_dns_namespace" "service_namespace" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "${var.project_name}.local"
  description = "Service discovery namespace for ${var.project_name} ${var.environment}"
  vpc         = var.vpc_id
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Create service discovery services for each microservice
resource "aws_service_discovery_service" "kyc_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "kyc-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "kyc-service"
  }
}

resource "aws_service_discovery_service" "user_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "user-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "user-service"
  }
}

resource "aws_service_discovery_service" "account_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "account-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "account-service"
  }
}

resource "aws_service_discovery_service" "trust_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "trust-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "trust-service"
  }
}

resource "aws_service_discovery_service" "investment_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "investment-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "investment-service"
  }
}

resource "aws_service_discovery_service" "document_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "document-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "document-service"
  }
}

resource "aws_service_discovery_service" "notification_service" {
  count       = var.create_service_discovery ? 1 : 0
  name        = "notification-service"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_namespace[0].id
    
    dns_records {
      ttl  = 10
      type = "A"
    }
    
    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Service     = "notification-service"
  }
}

# Update the private DNS entries if services are registered manually
locals {
  service_discovery_enabled = var.create_service_discovery ? true : false
  service_namespace_id = var.create_service_discovery ? aws_service_discovery_private_dns_namespace.service_namespace[0].id : var.existing_service_namespace_id
  
  service_discovery_names = {
    kyc_service = local.service_discovery_enabled ? "${aws_service_discovery_service.kyc_service[0].name}.${var.project_name}.local" : var.kyc_service_endpoint
    user_service = local.service_discovery_enabled ? "${aws_service_discovery_service.user_service[0].name}.${var.project_name}.local" : var.user_service_endpoint
    account_service = local.service_discovery_enabled ? "${aws_service_discovery_service.account_service[0].name}.${var.project_name}.local" : var.account_service_endpoint
    trust_service = local.service_discovery_enabled ? "${aws_service_discovery_service.trust_service[0].name}.${var.project_name}.local" : var.trust_service_endpoint
    investment_service = local.service_discovery_enabled ? "${aws_service_discovery_service.investment_service[0].name}.${var.project_name}.local" : var.investment_service_endpoint
    document_service = local.service_discovery_enabled ? "${aws_service_discovery_service.document_service[0].name}.${var.project_name}.local" : var.document_service_endpoint
    notification_service = local.service_discovery_enabled ? "${aws_service_discovery_service.notification_service[0].name}.${var.project_name}.local" : var.notification_service_endpoint
  }
}