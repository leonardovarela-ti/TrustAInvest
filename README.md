# TrustAInvest.com

## Overview

TrustAInvest.com is a secure financial technology platform that enables users to create and manage investment accounts, set up trusts, and automate investment strategies.

## Getting Started

### Prerequisites

- Go 1.18+
- Docker
- Docker Compose
- AWS CLI
- Terraform

### Setup Development Environment

1. Clone this repository
2. Run \"make setup\" to set up the local development environment
3. Run \"make run\" to start all services

### Project Structure

- \"cmd/\": Service entry points
- \"internal/\": Internal packages
- \"pkg/\": Public packages that can be imported by other projects
- \"deployments/\": Deployment configurations
- \"docs/\": Documentation
- \"test/\": Integration and e2e tests
- \"web/\": Web application

### Services

- User Service: User management and authentication
- Account Service: Financial account management
- Trust Service: Trust creation and management
- Investment Service: Investment management
- Document Service: Document generation and management
- Notification Service: Notifications and alerts

## Deployment

To deploy to AWS:

1. Configure AWS credentials
2. Run \"make deploy ENV=dev\"


# TrustAInvest.com User Registration with KYC

This project implements a user registration system with Know Your Customer (KYC) verification for TrustAInvest.com. It consists of a registration API and a KYC worker that processes verification requests asynchronously.

## Architecture

The system is designed with a microservices architecture:

1. **User Registration Service**: Handles user registration requests, performs initial validation, and enqueues KYC verification requests.
2. **KYC Worker Service**: Processes KYC verification requests from the queue, interacts with KYC providers, and updates user status.
3. **Notification Service**: Sends notifications to users about their registration and KYC status.

## Key Components

- **PostgreSQL**: Main database for user data and KYC verification records
- **Redis**: Caching and distributed locking
- **AWS SQS**: Queue for KYC verification requests
- **AWS SNS**: Topic for notifications
- **AWS KMS**: Encryption for sensitive user data
- **AWS S3**: Storage for KYC documents

## Prerequisites

- Docker and Docker Compose
- Go 1.18 or later (for local development)
- AWS CLI (for interacting with LocalStack)

## Getting Started

1. Clone the repository:
   ```
   git clone https://github.com/leonardovarelatrust/TrustAInvest.com.git
   cd TrustAInvest.com
   ```

2. Create a `.env` file from the sample:
   ```
   cp .env.sample .env
   ```

3. Start the services using Docker Compose:
   ```
   docker-compose up -d
   ```

4. Run the database migrations:
   ```
   docker-compose exec postgres psql -U trustainvest -d trustainvest -f /docker-entrypoint-initdb.d/000001_create_users_table.up.sql
   docker-compose exec postgres psql -U trustainvest -d trustainvest -f /docker-entrypoint-initdb.d/000002_create_notifications_schema.up.sql
   docker-compose exec postgres psql -U trustainvest -d trustainvest -f /docker-entrypoint-initdb.d/000003_create_kyc_tables.up.sql
   ```

5. Verify the services are running:
   ```
   docker-compose ps
   ```

## API Documentation

### User Registration

**Endpoint**: `POST /api/v1/register`

**Request Body**:
```json
{
  "username": "johndoe",
  "email": "john.doe@example.com",
  "password": "securePassword123",
  "phone_number": "+15551234567",
  "first_name": "John",
  "last_name": "Doe",
  "date_of_birth": "1990-01-15",
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "state": "NY",
    "zip_code": "10001",
    "country": "USA"
  },
  "ssn": "123-45-6789",
  "risk_profile": "MODERATE"
}
```

**Response**:
```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "username": "johndoe",
  "email": "john.doe@example.com",
  "status": "PENDING",
  "message": "Registration successful. Your account is pending KYC verification."
}
```

### Health Check

**Endpoint**: `GET /health`

**Response**:
```json
{
  "status": "ok",
  "service": "user-registration-service"
}
```

## KYC Process Flow

1. User submits registration information through the API
2. System validates input and creates a user account with "PENDING" KYC status
3. System encrypts sensitive data (SSN) and enqueues KYC verification request
4. KYC worker picks up the request from the queue
5. KYC worker processes the verification (integrates with third-party KYC provider)
6. KYC worker updates the user's KYC status (APPROVED, REJECTED, PENDING_ADDITIONAL_INFO)
7. System sends notification to the user about the verification result

## Testing the System

You can test the system using curl:

```bash
curl -X POST http://localhost:8080/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
    "password": "securePassword123",
    "phone_number": "+15551234567",
    "first_name": "John",
    "last_name": "Doe",
    "date_of_birth": "1990-01-15",
    "address": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "USA"
    },
    "ssn": "123-45-6789",
    "risk_profile": "MODERATE"
  }'
```

## Monitoring the KYC Process

### Check User Status

```bash
docker-compose exec postgres psql -U trustainvest -d trustainvest -c "SELECT id, username, email, kyc_status, kyc_verified_at FROM users.users WHERE username = 'johndoe';"
```

### View KYC Verification Requests

```bash
docker-compose exec postgres psql -U trustainvest -d trustainvest -c "SELECT * FROM kyc.verification_requests;"
```

### View Notifications

```bash
docker-compose exec postgres psql -U trustainvest -d trustainvest -c "SELECT id, user_id, type, title, message, is_read, created_at FROM notifications.notifications;"
```

## LocalStack AWS Resources

The system uses LocalStack to simulate AWS services locally. Here are some useful commands to interact with these resources:

### List SQS Queues

```bash
aws --endpoint-url=http://localhost:4566 sqs list-queues
```

### View Messages in KYC Queue

```bash
aws --endpoint-url=http://localhost:4566 sqs receive-message --queue-url http://localhost:4566/000000000000/kyc-queue --attribute-names All --message-attribute-names All --max-number-of-messages 10
```

### List SNS Topics

```bash
aws --endpoint-url=http://localhost:4566 sns list-topics
```

### List KMS Keys

```bash
aws --endpoint-url=http://localhost:4566 kms list-keys
```

## Environment Variables

See the `.env.sample` file for a list of all available environment variables and their descriptions.

## Development

### Directory Structure

```
.
├── cmd/                        # Service entry points
│   ├── kyc-worker/             # KYC worker service
│   └── user-registration-service/ # User registration service
├── internal/                   # Internal packages
│   ├── api/                    # API handlers
│   │   └── middleware/         # API middleware
│   ├── config/                 # Configuration
│   ├── db/                     # Database repositories
│   ├── models/                 # Data models
│   └── services/               # Business logic services
├── migrations/                 # Database migrations
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile.kyc-worker       # Dockerfile for KYC worker
├── Dockerfile.registration     # Dockerfile for user registration service
└── init-localstack.sh          # LocalStack initialization script
```

### Building from Source

To build the services from source:

```bash
# Build user registration service
go build -o bin/user-registration-service ./cmd/user-registration-service

# Build KYC worker
go build -o bin/kyc-worker ./cmd/kyc-worker
```

### Running Tests

```bash
go test ./...
```

## Production Considerations

For a production environment, consider the following:

1. Use a managed PostgreSQL service like AWS RDS
2. Use a managed Redis service like AWS ElastiCache
3. Use actual AWS services instead of LocalStack
4. Implement proper secrets management (AWS Secrets Manager)
5. Set up proper logging and monitoring
6. Configure proper scaling for the services
7. Implement CI/CD pipelines
8. Use infrastructure as code (Terraform, CloudFormation)

## Security Considerations

- All sensitive data is encrypted at rest and in transit
- KMS is used for encryption key management
- JWT tokens are used for authentication
- Database access is restricted
- Input validation is enforced
- API rate limiting should be implemented
- Proper error handling to avoid information leakage

## Future Improvements

- Add two-factor authentication
- Implement a more sophisticated KYC verification process
- Add document upload and verification
- Implement administrative dashboard for KYC review
- Add more comprehensive logging and monitoring
- Implement distributed tracing
- Add e2e tests

## License

Proprietary - All Rights Reserved
