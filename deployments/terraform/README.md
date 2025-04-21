# TrustAInvest AWS Infrastructure

This directory contains Terraform configurations for deploying the TrustAInvest infrastructure to AWS.

## Architecture

The infrastructure is organized into the following modules:

- **networking**: VPC, subnets, security groups, and related networking resources
- **security**: IAM roles, KMS keys, Cognito user pools, WAF, SNS topics, and SQS queues
- **storage**: S3 buckets for documents, artifacts, frontend assets, and logs
- **database**: RDS PostgreSQL instance
- **cache**: ElastiCache Redis cluster
- **container**: ECS cluster, ECR repositories, and ALB
- **frontend**: CloudFront distribution for the frontend application
- **monitoring**: CloudWatch dashboards, alarms, and log metrics
- **dns**: Route53 records for the domain

## Recent Infrastructure Improvements

Several improvements have been made to the infrastructure. All fixes have been consolidated into the main.tf file for better maintainability:

### ALB Access Logs

Application Load Balancer access logs are now enabled and stored in a dedicated S3 bucket:

- **S3 Bucket**: `trustainvest-dev-alb-logs`
- **Implementation**: The configuration is now consolidated in `main.tf`
- **Scripts**:
  - `scripts/check-alb-logs-bucket-policy.sh`: Check and fix ALB logs configuration

### IAM Roles

Custom IAM roles are used to avoid conflicts with existing roles:

- **Implementation**: The configuration is now consolidated in `main.tf`
- **Roles**:
  - `trustainvest-dev-ecs-task-execution-role-new`
  - `trustainvest-dev-ecs-task-role-new`

### WAF Integration

Web Application Firewall is integrated with CloudFront and ALB:

- **Implementation**: The configuration is now consolidated in `main.tf`

### S3 Bucket ACLs for Logs

S3 bucket ACLs are configured to allow CloudFront and ALB to write logs:

- **Implementation**: The configuration is now consolidated in `main.tf`

### DNS Configuration

DNS records are configured for CloudFront and ALB:

- **Implementation**: The configuration is now consolidated in `main.tf` and the DNS module

### Documentation

Detailed documentation is available:

- `docs/terraform-deployment-fixes-updated.md`: Overview of all fixes
- `docs/alb-access-logs-alternatives.md`: ALB access logs implementation alternatives

### Code Consolidation

All fix files have been consolidated into the main.tf file for better maintainability:

- ✅ `iam_roles_fix.tf` → `main.tf`
- ✅ `global_waf.tf` → `main.tf`
- ✅ `dns_module_fix.tf` → `main.tf`
- ✅ `frontend_module_fix.tf` → `main.tf`
- ✅ `frontend_waf_fix.tf` → `main.tf`
- ✅ `monitoring_module_fix.tf` → `main.tf`
- ✅ `container_module_fix.tf` → `main.tf`
- ✅ `storage_module_fix.tf` → `main.tf`
- ✅ `variables_fix.tf` → `variables.tf` (in the DNS module)

The module source has been updated from "container_with_existing_roles" to "container" to avoid issues with data sources that were trying to reference resources that don't exist yet.

## Environments

The infrastructure is deployed to the following environments:

- **dev**: Development environment
- **stage**: Staging environment
- **prod**: Production environment

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or later)
- [AWS CLI](https://aws.amazon.com/cli/) (v2.0.0 or later)
- AWS account with appropriate permissions

## Getting Started

1. Clone the repository:

```bash
git clone https://github.com/your-org/TrustAInvest.com.git
cd TrustAInvest.com
```

2. Configure AWS credentials:

```bash
aws configure
```

3. Initialize Terraform:

```bash
cd deployments/terraform/environments/dev
terraform init
```

4. Create a `terraform.tfvars` file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

5. Edit the `terraform.tfvars` file to set the appropriate values for your environment.

6. Plan the deployment:

```bash
terraform plan -out=tfplan
```

7. Apply the deployment:

```bash
terraform apply tfplan
```

## Terraform Backend

The Terraform state is stored locally by default. For production use, it is recommended to configure a remote backend such as S3 with DynamoDB for state locking. Uncomment and configure the backend section in `main.tf` to use a remote backend.

```hcl
terraform {
  backend "s3" {
    bucket         = "trustainvest-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "trustainvest-terraform-locks"
    encrypt        = true
  }
}
```

## Module Structure

Each module has the following structure:

- `variables.tf`: Input variables for the module
- `main.tf`: Main configuration for the module
- `outputs.tf`: Output values from the module

## Environment Structure

Each environment has the following structure:

- `variables.tf`: Input variables for the environment
- `main.tf`: Main configuration for the environment
- `outputs.tf`: Output values from the environment
- `terraform.tfvars.example`: Example variable values for the environment

## Security Considerations

- All sensitive data is encrypted at rest and in transit
- KMS keys are used for encryption
- IAM roles follow the principle of least privilege
- Security groups restrict access to resources
- WAF protects against common web exploits
- CloudWatch alarms monitor for suspicious activity

## Cost Optimization

- Development and staging environments use smaller instance sizes
- Auto-scaling is configured to scale down during off-hours
- S3 lifecycle policies archive and expire old objects
- CloudWatch log retention periods are configured to minimize storage costs

## Deployment Pipeline

The infrastructure can be deployed using a CI/CD pipeline. A sample GitHub Actions workflow is provided in `.github/workflows/terraform.yml`.

## Troubleshooting

If you encounter issues with the deployment, check the following:

- AWS credentials are configured correctly
- Terraform state is not corrupted
- Required AWS services are available in the selected region
- Resource limits are not exceeded

## Contributing

1. Create a feature branch
2. Make your changes
3. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
