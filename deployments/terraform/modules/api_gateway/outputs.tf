output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.api.execution_arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway deployment"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "api_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.stage.stage_name
}

output "api_key_id" {
  description = "ID of the API Key"
  value       = aws_api_gateway_api_key.internal_api_key.id
}

output "api_key_value" {
  description = "Value of the API Key"
  value       = aws_api_gateway_api_key.internal_api_key.value
  sensitive   = true
}

output "custom_domain_url" {
  description = "Custom domain URL, if configured"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}/v1" : ""
}

# Get the current AWS region
data "aws_region" "current" {}