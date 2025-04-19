# TrustAInvest Integration Tests

This directory contains integration tests for the TrustAInvest platform. These tests verify that the various services work together correctly.

## Prerequisites

- Docker and Docker Compose installed
- Bash shell
- curl command-line tool

## Test Environment

The tests use a dynamic Docker Compose configuration that sets up completely isolated test environments with the following components:

- PostgreSQL database
- Redis
- LocalStack
- User Registration Service
- KYC Worker service
- KYC Verifier Service

Each test gets its own completely isolated environment with:
- Unique Docker Compose project name
- Unique container names
- Unique network names
- Unique volume names
- Unique port mappings

This ensures that tests can run in parallel without interfering with each other, even when accessing the same resources. The project-based isolation means that each test runs in its own Docker Compose project context, providing complete separation between test environments.

## Port Allocation

The system uses the following port ranges:

| Service                | Main Application | Test Environments |
|------------------------|------------------|-------------------|
| PostgreSQL             | 5432             | 15432-15532       |
| Redis                  | 6379             | 16379-16479       |
| LocalStack             | 4566             | 14566-14666       |
| User Registration      | 8086             | 18086-18186       |
| KYC Verifier           | 8090             | 18090-18190       |

When running tests in parallel, each test will use a unique set of ports within these ranges.

## Running the Tests

### Running All Tests Sequentially

You can run all tests sequentially using the test runner script:

```bash
cd test
./run_tests.sh
```

Or using the Makefile:

```bash
cd test
make test
```

### Running All Tests in Parallel

You can run all tests in parallel to speed up execution:

```bash
cd test
make test-parallel
```

By default, this will run up to 3 tests concurrently. You can adjust the maximum number of concurrent tests by setting the `MAX_CONCURRENT` environment variable:

```bash
cd test
MAX_CONCURRENT=5 make test-parallel
```

Each test runs in its own isolated Docker environment, so they won't interfere with each other even when running in parallel. This is achieved by:

1. Generating unique identifiers for each test run
2. Creating a unique Docker Compose project name for each test
3. Creating unique container names with these identifiers
4. Using separate Docker networks for each test
5. Using separate Docker volumes for each test
6. Mapping to different host ports for each test

The project-based isolation is particularly important as it ensures that containers from different tests are completely separated in Docker's management system, allowing for true parallel execution without resource conflicts.

### Running Individual Tests

You can also run individual test scripts directly:

```bash
cd test
./integration_test.sh  # Tests the user registration and KYC flow
./failed_registration_test.sh  # Tests error handling
./login_test.sh  # Tests the login functionality
./user_journey_test.sh  # Tests the complete user journey
```

### Running Tests with Makefile

You can also run individual tests using the Makefile:

```bash
cd test
make test-registration
make test-failed-registration
make test-login
make test-user-journey
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

### Login Test (`login_test.sh`)

This test verifies the login functionality:

1. Registers a new user
2. Verifies the email
3. Updates the KYC status to VERIFIED
4. Tests login functionality
5. Tests session management

### User Journey Test (`user_journey_test.sh`)

This test verifies the complete user journey:

1. Registers a new user
2. Verifies the email
3. Attempts to login before KYC verification (should fail)
4. Updates the KYC status to VERIFIED
5. Successfully logs in

## Adding New Tests

To add a new test:

1. Create a new shell script with a name ending in `_test.sh`
2. Make it executable with `chmod +x your_test.sh`
3. Add the following code at the beginning of your script to use the dynamic environment:

```bash
#!/bin/bash
set -e

# Get test name from filename
TEST_NAME=$(basename "$0" .sh)

# Source the environment generator script
source "$(dirname "$0")/generate_test_env.sh" "$TEST_NAME"
eval $($(dirname "$0")/generate_test_env.sh "$TEST_NAME")
```

4. Use the environment variables provided by the generator script:
   - `$COMPOSE_FILE`: The Docker Compose file to use
   - `$PG_PORT`: The PostgreSQL port
   - `$REDIS_PORT`: The Redis port
   - `$LOCALSTACK_PORT`: The LocalStack port
   - `$USER_REG_PORT`: The User Registration Service port
   - `$KYC_PORT`: The KYC Verifier Service port
   - `$TEST_NETWORK`: The Docker network name

5. Clean up resources at the end of your test:

```bash
# Clean up
docker-compose -f "$(dirname "$0")/$COMPOSE_FILE" down -v
rm -f "$(dirname "$0")/$COMPOSE_FILE"
```

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
2. Ensure that no other services are running on the same ports
3. If tests are hanging, you can use the `timeout` command to limit the execution time
4. Check the test results in the `results/` directory for detailed error information
5. Use the `make clean` command to clean up any leftover resources
