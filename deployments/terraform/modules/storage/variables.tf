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

variable "documents_bucket_name" {
  description = "The name of the S3 bucket for documents"
  type        = string
  default     = null
}

variable "artifacts_bucket_name" {
  description = "The name of the S3 bucket for artifacts"
  type        = string
  default     = null
}

variable "frontend_bucket_name" {
  description = "The name of the S3 bucket for frontend assets"
  type        = string
  default     = null
}

variable "logs_bucket_name" {
  description = "The name of the S3 bucket for logs"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key for S3 encryption"
  type        = string
}

variable "documents_bucket_versioning" {
  description = "Whether to enable versioning for the documents bucket"
  type        = bool
  default     = true
}

variable "artifacts_bucket_versioning" {
  description = "Whether to enable versioning for the artifacts bucket"
  type        = bool
  default     = true
}

variable "frontend_bucket_versioning" {
  description = "Whether to enable versioning for the frontend bucket"
  type        = bool
  default     = false
}

variable "logs_bucket_versioning" {
  description = "Whether to enable versioning for the logs bucket"
  type        = bool
  default     = false
}

variable "documents_bucket_lifecycle_rules" {
  description = "Lifecycle rules for the documents bucket"
  type = list(object({
    id                                     = string
    enabled                                = bool
    prefix                                 = string
    expiration_days                        = number
    noncurrent_version_expiration_days     = number
    abort_incomplete_multipart_upload_days = number
  }))
  default = [
    {
      id                                     = "expire-old-versions"
      enabled                                = true
      prefix                                 = ""
      expiration_days                        = 0
      noncurrent_version_expiration_days     = 90
      abort_incomplete_multipart_upload_days = 7
    }
  ]
}

variable "artifacts_bucket_lifecycle_rules" {
  description = "Lifecycle rules for the artifacts bucket"
  type = list(object({
    id                                     = string
    enabled                                = bool
    prefix                                 = string
    expiration_days                        = number
    noncurrent_version_expiration_days     = number
    abort_incomplete_multipart_upload_days = number
  }))
  default = [
    {
      id                                     = "expire-old-versions"
      enabled                                = true
      prefix                                 = ""
      expiration_days                        = 30
      noncurrent_version_expiration_days     = 7
      abort_incomplete_multipart_upload_days = 1
    }
  ]
}

variable "logs_bucket_lifecycle_rules" {
  description = "Lifecycle rules for the logs bucket"
  type = list(object({
    id                                     = string
    enabled                                = bool
    prefix                                 = string
    expiration_days                        = number
    noncurrent_version_expiration_days     = number
    abort_incomplete_multipart_upload_days = number
  }))
  default = [
    {
      id                                     = "expire-old-logs"
      enabled                                = true
      prefix                                 = ""
      expiration_days                        = 90
      noncurrent_version_expiration_days     = 30
      abort_incomplete_multipart_upload_days = 1
    }
  ]
}

variable "block_public_acls" {
  description = "Whether to block public ACLs for the S3 buckets"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Whether to block public policies for the S3 buckets"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Whether to ignore public ACLs for the S3 buckets"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Whether to restrict public bucket policies for the S3 buckets"
  type        = bool
  default     = true
}

variable "enable_frontend_website" {
  description = "Whether to enable website hosting for the frontend bucket"
  type        = bool
  default     = true
}

variable "frontend_index_document" {
  description = "The index document for the frontend website"
  type        = string
  default     = "index.html"
}

variable "frontend_error_document" {
  description = "The error document for the frontend website"
  type        = string
  default     = "index.html"
}

variable "alb_access_logs_prefix" {
  description = "The S3 bucket prefix for ALB access logs"
  type        = string
  default     = "alb-logs"
}

variable "cloudfront_logs_prefix" {
  description = "The S3 bucket prefix for CloudFront access logs"
  type        = string
  default     = "cloudfront-logs"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
