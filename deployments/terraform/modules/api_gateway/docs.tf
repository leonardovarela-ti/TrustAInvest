# This file is used to auto-generate documentation

# Generate module documentation
variable "module_enabled" {
  type        = bool
  default     = true
  description = "Controls whether resources in the module should be created."
}

locals {
  module_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      Module      = "api_gateway"
    }
  )
  
  api_endpoints = {
    kyc_service = {
      path = "/kyc"
      description = "Know Your Customer (KYC) verification API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    },
    user_service = {
      path = "/users"
      description = "User management API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    }
    account_service = {
      path = "/accounts"
      description = "Account management API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    }
    trust_service = {
      path = "/trusts"
      description = "Trust management API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    }
    investment_service = {
      path = "/investments"
      description = "Investment management API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    }
    document_service = {
      path = "/documents"
      description = "Document management API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    }
    notification_service = {
      path = "/notifications"
      description = "Notification management API"
      methods = ["GET", "POST", "PUT", "DELETE"]
    }
  }
  
  api_docs = <<-EOT
# ${var.project_name} API Documentation - ${upper(var.environment)} Environment

## Base URL
${var.custom_domain_name != "" ? "https://${var.custom_domain_name}/v1" : "https://{api-id}.execute-api.{region}.amazonaws.com/${var.environment}"}

## Authentication
All API endpoints require authentication using an JWT token from Cognito User Pool.
Add the following header to your requests:

```
Authorization: Bearer {jwt-token}
```

## Available Endpoints

${join("\n\n", [for service_name, service_info in local.api_endpoints : "### ${title(replace(service_name, "_", " "))} API\nBase path: `${service_info.path}`\n\nDescription: ${service_info.description}\n\nAvailable methods: ${join(", ", service_info.methods)}\n\n- **GET** `${service_info.path}` - List all ${replace(service_name, "_service", "s")}\n- **GET** `${service_info.path}/{id}` - Get a specific ${replace(service_name, "_service", "")}\n- **POST** `${service_info.path}` - Create a new ${replace(service_name, "_service", "")}\n- **PUT** `${service_info.path}/{id}` - Update a ${replace(service_name, "_service", "")}\n- **DELETE** `${service_info.path}/{id}` - Delete a ${replace(service_name, "_service", "")}\n"])}

## Rate Limits
- Burst limit: ${var.throttling_burst_limit} requests per second
- Rate limit: ${var.throttling_rate_limit} requests per second
- Daily quota: ${var.quota_limit} requests per day

## Error Codes
- **400** - Bad Request: The request was malformed
- **401** - Unauthorized: Missing or invalid authentication
- **403** - Forbidden: Not authorized to access the resource
- **404** - Not Found: The requested resource doesn't exist
- **429** - Too Many Requests: Rate limit exceeded
- **500** - Internal Server Error: Something went wrong on the server

## API Version
API version: v1
EOT
}

resource "local_file" "api_documentation" {
  count    = var.generate_docs ? 1 : 0
  content  = local.api_docs
  filename = "${path.module}/docs/api_documentation_${var.environment}.md"
}