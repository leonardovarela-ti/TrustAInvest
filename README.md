# TrustAInvest

TrustAInvest is a comprehensive financial platform that enables users to manage investments, trusts, and accounts securely.

## Architecture

The platform is built using a microservices architecture with the following components:

- **User Service**: Manages user authentication and profiles
- **Account Service**: Handles financial accounts and transactions
- **Trust Service**: Manages trust creation and administration
- **Investment Service**: Provides investment management capabilities
- **Document Service**: Handles document storage and retrieval
- **Notification Service**: Manages notifications and alerts
- **User Registration Service**: Handles user registration and onboarding
- **KYC Verifier Service**: Performs Know Your Customer verification
- **E-Trade Service**: Integrates with E-Trade for trading capabilities
- **Capital One Service**: Integrates with Capital One for banking services
- **E-Trade Callback**: Handles callbacks from E-Trade API
- **KYC Worker**: Background worker for KYC verification tasks
- **Customer App**: Frontend application for customers
- **KYC Verifier UI**: Frontend application for KYC verification staff

## Technology Stack

- **Backend**: Go
- **Frontend**: Flutter (Web)
- **Database**: PostgreSQL
- **Cache**: Redis
- **Message Queue**: AWS SQS
- **Pub/Sub**: AWS SNS
- **Storage**: AWS S3
- **Authentication**: AWS Cognito
- **Infrastructure**: AWS (ECS, ECR, RDS, ElastiCache, etc.)
- **Infrastructure as Code**: Terraform
- **CI/CD**: GitHub Actions

## Development

### Prerequisites

- Go 1.20+
- Flutter 3.0+
- Docker
- Docker Compose
- AWS CLI
- Terraform 1.0+

### Local Development

1. Clone the repository:

```bash
git clone https://github.com/your-org/TrustAInvest.com.git
cd TrustAInvest.com
```

2. Start the local development environment:

```bash
docker-compose up -d
```

3. Initialize the database:

```bash
./scripts/init-db.sh
```

4. Initialize LocalStack (for AWS services):

```bash
./scripts/init-localstack.sh
```

5. Run the services:

```bash
./scripts/rebuild-all.sh
```

### Testing

Run the integration tests:

```bash
cd test
make test
```

## Deployment

### Local Testing

Test the deployment locally using LocalStack:

```bash
./scripts/test-deployment-local.sh
```

### AWS Deployment

Deploy to AWS:

```bash
./scripts/deploy-to-aws.sh --environment dev
```

### Terraform Deployment

Deploy the infrastructure using Terraform:

```bash
cd deployments/terraform/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## Project Structure

- `cmd/`: Service entry points
- `internal/`: Internal packages
  - `api/`: API handlers
  - `auth/`: Authentication logic
  - `config/`: Configuration
  - `db/`: Database access
  - `models/`: Data models
  - `services/`: Business logic
  - `util/`: Utility functions
- `customer-app/`: Customer frontend application
- `kyc-verifier-ui/`: KYC verifier frontend application
- `deployments/`: Deployment configurations
  - `terraform/`: Terraform configurations
  - `k8s/`: Kubernetes configurations
  - `cloudformation/`: CloudFormation templates
- `scripts/`: Utility scripts
- `test/`: Integration tests
- `docs/`: Documentation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
