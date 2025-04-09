# TrustAInvest Integration Tests

This directory contains integration tests for the TrustAInvest platform. These tests verify that the various services work together correctly.

## Prerequisites

- Docker and Docker Compose installed
- Bash shell
- curl command-line tool

## Test Environment

The tests use a dedicated Docker Compose configuration file (`docker-compose.test.yml`) that sets up an isolated test environment with the following components:

- PostgreSQL database on port 15432 (instead of the default 5432)
- Redis on port 16379 (instead of the default 6379)
- LocalStack on port 14566 (instead of the default 4566)
- User Registration Service on port 18086 (instead of the default 8086)
- KYC Worker service

This port configuration ensures that the tests don't interfere with any development or production environments that might be running simultaneously.

## Running the Tests

You can run all tests using the test runner script:

```bash
cd test
./run_tests.sh
```

This will execute all test scripts in the directory and provide a summary of the results.

## Running Individual Tests

You can also run individual test scripts directly:

```bash
cd test
./integration_test.sh  # Tests the user registration and KYC flow
./failed_registration_test.sh  # Tests error handling
```

## Available Tests

### User Registration and KYC Flow Test (`integration_test.sh`)

This test verifies the complete user registration and KYC flow:

1. Starts the system using docker-compose
2. Registers a user through the API
3. Extracts the verification token from the logs
4. Verifies the email using the token
5. Checks that the entry is in the kyc.verification_requests table

### Failed Registration Test (`failed_registration_test.sh`)

This test verifies that the system properly handles various error cases:

1. Registration with missing required fields
2. Registration with invalid email format
3. Registration with weak password
4. Email verification with invalid token
5. Registration with duplicate username

## Adding New Tests

To add a new test:

1. Create a new shell script with a name ending in `_test.sh`
2. Make it executable with `chmod +x your_test.sh`
3. Implement your test logic
4. The script should return exit code 0 for success and non-zero for failure

## Test Structure Guidelines

When writing new tests, follow these guidelines:

1. Use clear, descriptive step messages
2. Include proper error handling and cleanup
3. Use color-coded output for better readability
4. Clean up resources (e.g., docker containers) after the test completes
5. Include detailed error messages when tests fail

## Test Reports

The test runner generates detailed reports in the `results/` directory:

- `test_results.log`: Detailed log of all test executions
- `summary.txt`: Plain text summary of test results
- `report.html`: HTML report with test results and statistics

## Continuous Integration

These tests can be integrated into a CI/CD pipeline by running the `run_tests.sh` script. The script will exit with a non-zero status code if any tests fail, which will cause the CI pipeline to fail.

A GitHub Actions workflow configuration is provided in `.github/workflows/integration-tests.yml` that demonstrates how to run these tests in a CI environment. The workflow:

1. Runs on pushes to main and develop branches, and on pull requests
2. Sets up Docker Buildx for building Docker images
3. Runs the integration tests
4. Archives the test results as artifacts

## Troubleshooting

If you encounter issues with the tests:

1. Check the logs for each service using `docker-compose -f docker-compose.test.yml logs [service-name]`
2. Ensure that no other services are running on the same ports (15432, 16379, 14566, 18086)
3. If tests are hanging, you can use the `timeout` command to limit the execution time
4. Check the test results in the `results/` directory for detailed error information
