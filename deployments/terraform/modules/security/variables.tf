variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "trustainvest"
}

variable "environment" {
  description = "The deployment environment (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

# Cognito User Pool
variable "user_pool_name" {
  description = "The name of the Cognito User Pool"
  type        = string
  default     = null
}

variable "email_verification_message" {
  description = "The email verification message"
  type        = string
  default     = "Your verification code is {####}"
}

variable "email_verification_subject" {
  description = "The email verification subject"
  type        = string
  default     = "Your verification code"
}

variable "sms_authentication_message" {
  description = "The SMS authentication message"
  type        = string
  default     = "Your authentication code is {####}"
}

variable "sms_verification_message" {
  description = "The SMS verification message"
  type        = string
  default     = "Your verification code is {####}"
}

variable "password_minimum_length" {
  description = "The minimum length of the password"
  type        = number
  default     = 8
}

variable "password_require_lowercase" {
  description = "Whether to require lowercase characters in the password"
  type        = bool
  default     = true
}

variable "password_require_uppercase" {
  description = "Whether to require uppercase characters in the password"
  type        = bool
  default     = true
}

variable "password_require_numbers" {
  description = "Whether to require numbers in the password"
  type        = bool
  default     = true
}

variable "password_require_symbols" {
  description = "Whether to require symbols in the password"
  type        = bool
  default     = true
}

variable "password_temporary_validity_days" {
  description = "The number of days a temporary password is valid"
  type        = number
  default     = 7
}

variable "mfa_configuration" {
  description = "The MFA configuration"
  type        = string
  default     = "OPTIONAL"
}

variable "allow_admin_create_user_only" {
  description = "Whether to allow only administrators to create users"
  type        = bool
  default     = false
}

variable "enable_user_existence_errors" {
  description = "Whether to enable user existence errors"
  type        = string
  default     = "ENABLED"
}

# KMS Keys
variable "kms_key_deletion_window_in_days" {
  description = "The number of days to retain a KMS key scheduled for deletion"
  type        = number
  default     = 30
}

variable "kms_key_enable_key_rotation" {
  description = "Whether to enable key rotation"
  type        = bool
  default     = true
}

# WAF
variable "enable_waf" {
  description = "Whether to enable WAF"
  type        = bool
  default     = true
}

variable "waf_default_action" {
  description = "The default action for the WAF web ACL"
  type        = string
  default     = "allow"
}

variable "waf_scope" {
  description = "The scope of the WAF web ACL"
  type        = string
  default     = "REGIONAL"
}

# SNS Topics
variable "enable_sns_topics" {
  description = "Whether to enable SNS topics"
  type        = bool
  default     = true
}

# SQS Queues
variable "enable_sqs_queues" {
  description = "Whether to enable SQS queues"
  type        = bool
  default     = true
}

variable "sqs_message_retention_seconds" {
  description = "The number of seconds to retain a message in an SQS queue"
  type        = number
  default     = 1209600 # 14 days
}

variable "sqs_visibility_timeout_seconds" {
  description = "The visibility timeout for an SQS queue"
  type        = number
  default     = 30
}

variable "sqs_max_message_size" {
  description = "The maximum message size for an SQS queue"
  type        = number
  default     = 262144 # 256 KiB
}

variable "sqs_delay_seconds" {
  description = "The delay in seconds for an SQS queue"
  type        = number
  default     = 0
}

variable "sqs_receive_wait_time_seconds" {
  description = "The receive wait time in seconds for an SQS queue"
  type        = number
  default     = 0
}
