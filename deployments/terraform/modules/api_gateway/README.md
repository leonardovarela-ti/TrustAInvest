# API Gateway Terraform Module

This module provisions an AWS API Gateway REST API that serves as the entry point for the TrustAInvest.com microservices architecture. It includes configuration for authentication, authorization, throttling, and integration with other AWS services.

## Features

- REST API with CORS support
- Cognito User Pool integration for authentication
- VPC Link integration to securely connect to microservices
- API Key and Usage Plan for API rate limiting
- CloudWatch logging
- WAF integration (optional)
- Custom domain support (optional)
- Cache configuration (optional)

## Usage

```hcl
module "api_gateway" {
  source = "../modules/api_gateway"
  
  environment     = "dev"
  project_name    = "TrustAInvest"
  
  # Authentication
  cognito_user_pool_id = module.cognito.user_pool_id
  
  # Networking
  nlb_arn = module.load_balancer.nlb_arn
  
  # Service endpoints (assuming ECS service discovery)
  user_service_endpoint        = "${module.ecs.user_service_name}.${module.ecs.service_discovery_namespace}"
  account_service_endpoint     = "${module.ecs.account_service_name}.${module.ecs.service_discovery_namespace}"
  trust_service_endpoint       = "${module.ecs.trust_service_name}.${module.ecs.service_discovery_namespace}"
  investment_service_endpoint  = "${module.ecs.investment_service_name}.${module.ecs.service_discovery_namespace}"
  document_service_endpoint    = "${module.ecs.document_service_name}.${module.ecs.service_discovery_namespace}"
  notification_service_endpoint = "${module.ecs.notification_service_name}.${module.ecs.service_discovery_namespace}"
  
  # Optional configurations
  cache_enabled           = true
  cache_size              = "0.5"
  throttling_burst_limit  = 5000
  throttling_rate_limit   = 10000
  quota_limit             = 1000000
  
  # WAF (optional)
  waf_acl_arn = module.security.waf_acl_arn
  
  # Custom domain (optional)
  custom_domain_name   = "api.trustainvest.com"
  acm_certificate_arn  = module.security.api_certificate_arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | The deployment environment (dev, stage, prod) | string | - | yes |
| project_name | The name of the project | string | - | yes |
| cognito_user_pool_id | ARN of the Cognito User Pool used for authorization | string | - | yes |
| nlb_arn | ARN of the Network Load Balancer for the VPC Link | string | - | yes |
| user_service_endpoint | Endpoint for the User Service | string | "user-service:8080" | no |
| account_service_endpoint | Endpoint for the Account Service | string | "account-service:8080" | no |
| trust_service_endpoint | Endpoint for the Trust Service | string | "trust-service:8080" | no |
| investment_service_endpoint | Endpoint for the Investment Service | string | "investment-service:8080" | no |
| document_service_endpoint | Endpoint for the Document Service | string | "document-service:8080" | no |
| notification_service_endpoint | Endpoint for the Notification Service | string | "notification-service:8080" | no |
| waf_acl_arn | ARN of the WAF ACL to associate with the API Gateway | string | "" | no |
| cache_enabled | Whether to enable API Gateway cache | bool | false | no |
| cache_size | Size of the API Gateway cache cluster | string | "0.5" | no |
| throttling_burst_limit | The API Gateway throttling burst limit | number | 5000 | no |
| throttling_rate_limit | The API Gateway throttling rate limit | number | 10000 | no |
| quota_limit | The API Gateway quota limit per day | number | 1000000 | no |
| custom_domain_name | The custom domain name for the API Gateway | string | "" | no |
| acm_certificate_arn | ARN of the ACM certificate for the custom domain | string | "" | no |

## Outputs

| Name | Description |
|------|-------------|
| api_gateway_id | ID of the API Gateway |
| api_gateway_execution_arn | Execution ARN of the API Gateway |
| api_gateway_url | URL of the API Gateway deployment |
| api_stage_name | Name of the API Gateway stage |
| api_key_id | ID of the API Key |
| api_key_value | Value of the API Key |
| custom_domain_url | Custom domain URL, if configured |

## Resources Created

- AWS API Gateway REST API
- API Gateway Stage
- API Gateway Deployment
- API Gateway Authorizer (Cognito)
- API Gateway Resources for each microservice
- API Gateway Methods
- API Gateway Integrations
- VPC Link for connecting to microservices
- API Gateway Usage Plan
- API Gateway API Key
- CloudWatch Log Group
- WAF Association (if WAF ACL ARN provided)
- Custom Domain and Base Path Mapping (if custom domain provided)

## Security Considerations

1. API Gateway is configured to use Cognito User Pools for authentication.
2. All API endpoints (except health checks) require authentication.
3. CloudWatch logs are enabled for API Gateway.
4. Optional WAF integration for additional protection.
5. VPC Link used for private connectivity to backend services.

## Network Architecture

The API Gateway is configured with a VPC Link that connects to a Network Load Balancer (NLB) in your VPC. The NLB routes traffic to your microservices running in private subnets.

This provides several advantages:
- Microservices are not exposed to the public internet
- Secure communication between API Gateway and microservices
- NLB can perform health checks on microservices

## IAM Permissions

The module creates an IAM role and policy that allows API Gateway to authenticate users through Cognito User Pools. Ensure that your API Gateway has the necessary permissions to invoke backend services if you're using Lambda integrations.

## Monitoring and Logging

The module configures CloudWatch logging for the API Gateway. Logs are stored in a CloudWatch Log Group with a retention period of 7 days by default.

## Best Practices

1. Use custom domains in production environments for better branding and flexibility.
2. Enable WAF for additional protection against common web exploits.
3. Configure appropriate throttling and quotas based on expected traffic patterns.
4. Regularly rotate API keys used for internal service communication.
5. Use different stages (dev, stage, prod) for different environments.
6. Enable caching in production for improved performance.
7. Set up CloudWatch alarms for monitoring API usage and errors.
8. Review API Gateway access logs regularly for security auditing.
9. Consider using request/response mapping templates for data transformation if needed.
10. Use API Gateway resource policies for additional access control.

## Troubleshooting

1. **403 Forbidden errors**: Check Cognito user pool configuration and ensure tokens are properly formatted.
2. **504 Gateway Timeout**: Verify that the VPC Link and NLB are properly configured and that target services are responsive.
3. **CORS errors**: Ensure that the CORS configuration matches the domains of your frontend applications.
4. **Throttling issues**: Review and adjust the throttling settings in the usage plan.

## Maintenance

1. Update the API Gateway deployment whenever changes are made to the API structure.
2. Monitor CloudWatch logs for errors and performance issues.
3. Regularly review and update security settings.
4. Consider enabling API Gateway cache in production for improved performance.