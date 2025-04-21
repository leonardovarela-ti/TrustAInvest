# This file adds additional variables to the DNS module

variable "cloudfront_domains" {
  description = "List of domain names to create CloudFront DNS records for. If not provided, all domain names will be used."
  type        = list(string)
  default     = null
}
