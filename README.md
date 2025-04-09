# TrustAInvest Platform

TrustAInvest is a comprehensive financial platform that provides investment and trust management services.

## Project Structure

- `cmd/`: Contains the main applications for each service
  - `account-service/`: Manages user accounts and financial data
  - `document-service/`: Handles document storage and retrieval
  - `investment-service/`: Manages investment products and transactions
  - `kyc-worker/`: Processes Know Your Customer verification requests
  - `notification-service/`: Handles user notifications
  - `trust-service/`: Manages trust accounts and operations
  - `user-registration-service/`: Handles user registration and verification
  - `user-service/`: Manages user profiles and authentication
- `internal/`: Shared internal packages
- `scripts/`: Utility scripts for development and deployment
- `test/`: Integration tests

## Development

### Prerequisites

- Go 1.20 or higher
- Docker and Docker Compose
- Make

### Running the Services

To start all services locally:

```bash
docker-compose up
```

### Running Tests

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

The tests use a dedicated Docker Compose configuration (`test/docker-compose.test.yml`) that sets up an isolated test environment with different port mappings to avoid conflicts with the development environment. This allows you to run tests without interfering with your local development setup.

The test runner generates detailed reports in the `test/results/` directory, including:
- Detailed logs of all test executions
- Plain text summary of test results
- HTML report with test results and statistics

For more information about the tests, see the [test README](test/README.md).

## Deployment

The project includes deployment configurations for various environments:

- `deployments/cloudformation/`: AWS CloudFormation templates
- `deployments/k8s/`: Kubernetes manifests
- `deployments/terraform/`: Terraform configurations

## License

This project is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.
