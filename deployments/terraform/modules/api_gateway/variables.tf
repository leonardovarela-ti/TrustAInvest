variable "environment" {
  description = "The deployment environment (dev, stage, prod)"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ARN of the Cognito User Pool used for authorization"
  type        = string
}

variable "kyc_service_endpoint" {
  description = "Endpoint for the KYC Service"
  type        = string
  default     = "kyc-service:8080"
}

variable "user_service_endpoint" {
  description = "Endpoint for the User Service"
  type        = string
  default     = "user-service:8080"
}

variable "account_service_endpoint" {
  description = "Endpoint for the Account Service"
  type        = string
  default     = "account-service:8080"
}

variable "trust_service_endpoint" {
  description = "Endpoint for the Trust Service"
  type        = string
  default     = "trust-service:8080"
}

variable "investment_service_endpoint" {
  description = "Endpoint for the Investment Service"
  type        = string
  default     = "investment-service:8080"
}

variable "document_service_endpoint" {
  description = "Endpoint for the Document Service"
  type        = string
  default     = "document-service:8080"
}

variable "notification_service_endpoint" {
  description = "Endpoint for the Notification Service"
  type        = string
  default     = "notification-service:8080"
}

variable "nlb_arn" {
  description = "ARN of the Network Load Balancer for the VPC Link"
  type        = string
  default     = ""
}

variable "create_nlb" {
  description = "Whether to create a Network Load Balancer for the VPC Link"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "ID of the VPC where the services are deployed"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the NLB"
  type        = list(string)
  default     = []
}

variable "service_ports" {
  description = "Map of service names to their port numbers"
  type        = map(number)
  default = {
    kyc_service          = 8086
    user_service         = 8080
    account_service      = 8081
    trust_service        = 8082
    investment_service   = 8083
    document_service     = 8084
    notification_service = 8085
  }
}

variable "waf_acl_arn" {
  description = "ARN of the WAF ACL to associate with the API Gateway"
  type        = string
  default     = ""
}

variable "cache_enabled" {
  description = "Whether to enable API Gateway cache"
  type        = bool
  default     = false
}

variable "cache_size" {
  description = "Size of the API Gateway cache cluster"
  type        = string
  default     = "0.5"
}

variable "throttling_burst_limit" {
  description = "The API Gateway throttling burst limit"
  type        = number
  default     = 5000
}

variable "throttling_rate_limit" {
  description = "The API Gateway throttling rate limit"
  type        = number
  default     = 10000
}

variable "quota_limit" {
  description = "The API Gateway quota limit per day"
  type        = number
  default     = 1000000
}

variable "custom_domain_name" {
  description = "The custom domain name for the API Gateway"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "create_waf" {
  description = "Whether to create a WAF Web ACL for the API Gateway"
  type        = bool
  default     = false
}

variable "allowed_vpc_ids" {
  description = "List of VPC IDs allowed to access the API Gateway"
  type        = list(string)
  default     = []
}

variable "alarm_actions" {
  description = "List of ARNs to notify when API Gateway alarms trigger"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when API Gateway alarms return to OK state"
  type        = list(string)
  default     = []
}

variable "error_threshold" {
  description = "Threshold for API Gateway error alarms"
  type        = number
  default     = 10
}

variable "latency_threshold" {
  description = "Threshold for API Gateway latency alarm (in ms)"
  type        = number
  default     = 1000
}

variable "generate_docs" {
  description = "Whether to generate API documentation"
  type        = bool
  default     = false
}

variable "create_service_discovery" {
  description = "Whether to create service discovery resources"
  type        = bool
  default     = false
}

variable "existing_service_namespace_id" {
  description = "ID of an existing service discovery namespace"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain API Gateway logs"
  type        = number
  default     = 7
}

variable "enable_access_logs" {
  description = "Whether to enable API Gateway access logs"
  type        = bool
  default     = true
}

variable "logging_level" {
  description = "Logging level for API Gateway (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"
}

variable "data_trace_enabled" {
  description = "Whether to enable API Gateway data trace (not recommended for production)"
  type        = bool
  default     = false
}

variable "create_dashboard" {
  description = "Whether to create a CloudWatch dashboard for API Gateway metrics"
  type        = bool
  default     = false
}