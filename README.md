# TrustAInvest Platform

TrustAInvest is a comprehensive financial platform that provides investment and trust management services with a focus on secure user registration, KYC (Know Your Customer) verification, and financial services.

## Table of Contents

- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Getting the Code](#getting-the-code)
  - [Building the Project](#building-the-project)
  - [Running the System](#running-the-system)
  - [Rebuilding the System](#rebuilding-the-system)
- [API Documentation](#api-documentation)
  - [User Registration](#user-registration)
  - [Email Verification](#email-verification)
  - [KYC Verification](#kyc-verification)
- [Running Tests](#running-tests)
  - [Integration Tests](#integration-tests)
  - [KYC Status Update Fix](#kyc-status-update-fix)
  - [KYC Verifier Testing](#kyc-verifier-testing)
- [Deployment](#deployment)
- [Understanding the Codebase](#understanding-the-codebase)
  - [Microservices Architecture](#microservices-architecture)
  - [Key Components](#key-components)
- [License](#license)

## Project Overview

TrustAInvest is built on a microservices architecture, with each service responsible for a specific domain:

- **User Registration Service**: Handles user registration and initial KYC data collection
- **User Service**: Manages user profiles and authentication
- **Account Service**: Manages user accounts and financial data
- **Document Service**: Handles document storage and retrieval
- **Investment Service**: Manages investment products and transactions
- **KYC Worker**: Processes Know Your Customer verification requests
- **KYC Verifier Service**: Provides an interface for KYC verification staff
- **Notification Service**: Handles user notifications
- **Trust Service**: Manages trust accounts and operations

## Project Structure

- `cmd/`: Contains the main applications for each service
  - `account-service/`: Manages user accounts and financial data
  - `document-service/`: Handles document storage and retrieval
  - `investment-service/`: Manages investment products and transactions
  - `kyc-verifier-service/`: Interface for KYC verification staff
  - `kyc-worker/`: Processes Know Your Customer verification requests
  - `notification-service/`: Handles user notifications
  - `trust-service/`: Manages trust accounts and operations
  - `user-registration-service/`: Handles user registration and verification
  - `user-service/`: Manages user profiles and authentication
- `internal/`: Shared internal packages
  - `api/`: API handlers and middleware
  - `auth/`: Authentication and authorization
  - `aws/`: AWS service integrations
  - `config/`: Configuration management
  - `db/`: Database repositories
  - `models/`: Data models
  - `services/`: Business logic services
  - `util/`: Utility functions
- `scripts/`: Utility scripts for development and deployment
- `test/`: Integration tests
- `deployments/`: Deployment configurations
  - `cloudformation/`: AWS CloudFormation templates
  - `k8s/`: Kubernetes manifests
  - `terraform/`: Terraform configurations
- `kyc-verifier-ui/`: Flutter-based UI for KYC verification staff

## Getting Started

### Prerequisites

- Go 1.20 or higher
- Docker and Docker Compose
- Make
- PostgreSQL client (for direct database access)
- AWS CLI (for deployment)

### Getting the Code

Clone the repository:

```bash
git clone https://github.com/TrustAInvest/TrustAInvest.com.git
cd TrustAInvest.com
```

### Building the Project

You can build all services using the provided Makefile:

```bash
# Set up development environment
make setup

# Build all services
make build
```

This will compile all services and place the binaries in the `bin/` directory.

### Running the System

To start all services locally using Docker Compose:

```bash
docker-compose up
```

This will start all services, including:
- PostgreSQL database on port 5432
- Redis on port 6379
- LocalStack (AWS services emulator) on port 4566
- All microservices on their respective ports

To stop all services:

```bash
docker-compose down
```

To view logs for a specific service:

```bash
make logs SERVICE=user-registration-service
```

### Rebuilding the System

If you need to completely rebuild the system from scratch (for example, when setting up a new environment or troubleshooting issues), you can use the provided rebuild scripts:

#### Interactive Rebuild

The interactive rebuild script will guide you through the process and offer to run integration tests:

```bash
./scripts/rebuild-all.sh
```

This script:
1. Stops and removes all containers, volumes, and networks
2. Rebuilds all Docker images from scratch (with `--no-cache`)
3. Starts all services
4. Performs health checks to ensure everything is working
5. Optionally runs integration tests

#### Automated Rebuild

For CI/CD pipelines or automated environments, use the non-interactive version:

```bash
./scripts/rebuild-all-auto.sh
```

To also run integration tests automatically:

```bash
./scripts/rebuild-all-auto.sh --run-tests
```

The automated script performs the same steps as the interactive one but exits with an error code if any step fails, making it suitable for automated environments.

## API Documentation

### User Registration

To register a new user, send a POST request to the user registration endpoint:

```bash
curl -X POST http://localhost:8086/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john.doe@example.com",
    "password": "securePassword123!",
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

A successful response will look like:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "johndoe",
  "email": "john.doe@example.com",
  "status": "PENDING",
  "message": "Registration successful. Your account is pending KYC verification."
}
```

### Email Verification

After registration, the user will receive an email with a verification link. To verify the email programmatically, send a POST request to the email verification endpoint:

```bash
curl -X POST http://localhost:8086/api/v1/verify-email \
  -H "Content-Type: application/json" \
  -d '{
    "token": "verification-token-from-email"
  }'
```

A successful response will look like:

```json
{
  "message": "Email verified successfully"
}
```

### KYC Verification

#### Checking Verification Status

To check the status of a KYC verification request, send a GET request to the verification status endpoint:

```bash
curl -X GET http://localhost:8086/api/v1/verification-status/{user_id} \
  -H "Authorization: Bearer {jwt_token}"
```

A successful response will look like:

```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "PENDING",
  "submitted_at": "2025-04-09T12:00:00Z",
  "updated_at": "2025-04-09T12:00:00Z"
}
```

#### KYC Verifier API

For KYC verification staff, the KYC Verifier Service provides an API for managing verification requests:

1. Login with admin credentials to obtain a JWT token:
   ```bash
   curl -X POST http://localhost:8090/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"admin123"}'
   ```

   Note: The system comes with a default admin user (username: "admin", password: "admin123") that is created during database initialization.

   This will return a response containing a JWT token:
   ```json
   {
     "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   }
   ```

   Store this token for use in subsequent requests:
   ```bash
   export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```

2. List verification requests to find the ID of the request you want to verify:
   ```bash
   curl -X GET http://localhost:8090/api/verification-requests \
     -H "Authorization: Bearer $TOKEN"
   ```

   This will return a list of verification requests:
   ```json
   {
     "data": [
       {
         "id": "550e8400-e29b-41d4-a716-446655440000",
         "userId": "123e4567-e89b-12d3-a456-426614174000",
         "firstName": "John",
         "lastName": "Doe",
         "email": "john.doe@example.com",
         "status": "PENDING",
         "createdAt": "2025-04-09T12:00:00Z"
       },
       ...
     ]
   }
   ```

3. Get details of a specific verification request:
   ```bash
   curl -X GET http://localhost:8090/api/verification-requests/550e8400-e29b-41d4-a716-446655440000 \
     -H "Authorization: Bearer $TOKEN"
   ```

   This will return detailed information about the verification request.

4. Verify a customer verification request by updating its status to "VERIFIED":
   ```bash
   curl -X PATCH http://localhost:8090/api/verification-requests/550e8400-e29b-41d4-a716-446655440000/status \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"status":"VERIFIED"}'
   ```

   A successful response will look like:
   ```json
   {
     "message": "Status updated successfully"
   }
   ```

   You can also reject a verification request by setting the status to "REJECTED" and providing a reason:
   ```bash
   curl -X PATCH http://localhost:8090/api/verification-requests/550e8400-e29b-41d4-a716-446655440000/status \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"status":"REJECTED", "rejection_reason":"Documentation does not match provided information"}'
   ```

## Running Tests

### Integration Tests

The project includes comprehensive integration tests that verify the correct functioning of the entire system. These tests are located in the `test/` directory.

To run all tests:

```bash
cd test
./run_tests.sh
```

To run a specific test:

```bash
cd test
./integration_test.sh  # Tests the user registration and KYC flow
./failed_registration_test.sh  # Tests error handling
```

The tests use a dedicated Docker Compose configuration (`test/docker-compose.test.yml`) that sets up an isolated test environment with different port mappings to avoid conflicts with the development environment.

The test runner generates detailed reports in the `test/results/` directory, including:
- Detailed logs of all test executions
- Plain text summary of test results
- HTML report with test results and statistics

For more information about the tests, see the [test README](test/README.md).

### KYC Status Update Fix

There was an issue with the KYC verification system where the user's KYC status in the `users.users` table was not being updated to "VERIFIED" after a successful KYC verification through the API. This issue has been fixed with:

1. An enhanced `UpdateVerificationRequestStatus` function in the KYC verifier repository
2. A fixed database trigger to ensure the user's KYC status is updated correctly

To apply the fix:

```bash
# Make the script executable
chmod +x scripts/fix-kyc-status-update.sh

# Run the script
./scripts/fix-kyc-status-update.sh
```

To verify the fix with integration tests:

```bash
# Make the script executable
chmod +x scripts/fix-and-test-kyc-status.sh

# Run the script
./scripts/fix-and-test-kyc-status.sh
```

For more details about the issue and the fix, see the [KYC Status Update Fix documentation](docs/kyc-status-update-fix.md).

### KYC Verifier Testing

To test the KYC Verifier system:

1. Build and run the services using Docker Compose:
   ```bash
   docker-compose -f docker-compose.kyc-verifier.yml up -d
   ```

2. Access the KYC Verifier UI at http://localhost:3000
   - Login with the default admin credentials:
     - Username: `admin`
     - Password: `admin123`

3. Test the API directly:
   ```bash
   # Login
   curl -X POST http://localhost:8090/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"admin123"}'
   
   # List verification requests
   curl -X GET http://localhost:8090/api/verification-requests \
     -H "Authorization: Bearer {jwt_token}"
   ```

For more detailed testing instructions, see the [KYC Verifier Testing Guide](docs/kyc-verifier-testing.md).

## Deployment

The project includes deployment configurations for various environments:

- `deployments/cloudformation/`: AWS CloudFormation templates
- `deployments/k8s/`: Kubernetes manifests
- `deployments/terraform/`: Terraform configurations

To deploy to AWS using Terraform:

```bash
cd deployments/terraform/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS credentials and configuration
terraform init
terraform apply
```

## Understanding the Codebase

### Microservices Architecture

TrustAInvest uses a microservices architecture, with each service responsible for a specific domain. Services communicate with each other through RESTful APIs and message queues.

Key technologies used:
- Go for backend services
- PostgreSQL for persistent storage
- Redis for caching and session management
- AWS services (or LocalStack for local development):
  - SQS for message queues
  - SNS for notifications
  - S3 for document storage
  - KMS for encryption
- Flutter for the KYC Verifier UI

### Key Components

#### User Registration Flow

1. User submits registration data to the User Registration Service
2. Service validates the data and creates a new user record
3. Service encrypts sensitive data (SSN) using KMS
4. Service sends a verification email to the user
5. User clicks the verification link in the email
6. Service verifies the email and updates the user's status
7. Service enqueues a KYC verification request

#### KYC Verification Flow

1. KYC Worker picks up verification requests from the queue
2. Worker processes the request (may involve third-party KYC providers)
3. Worker updates the verification status
4. Notification Service sends a notification to the user

#### KYC Verifier UI

The KYC Verifier UI is a Flutter-based web application that allows KYC verification staff to:
- View pending verification requests
- Review user information and documents
- Approve or reject verification requests
- Manage verifier accounts (admin only)

## License

This project is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.
