# Makefile for TrustAInvest integration tests

.PHONY: all test test-parallel clean

# Default target
all: test

# Run all tests sequentially
test:
	@echo "Running all integration tests sequentially..."
	@./run_tests.sh

# Run all tests in parallel
test-parallel:
	@echo "Running all integration tests in parallel..."
	@MAX_CONCURRENT=3 ./run_tests.sh

# Run specific tests
test-registration:
	@echo "Running user registration test..."
	@./integration_test.sh

test-failed-registration:
	@echo "Running failed registration test..."
	@./failed_registration_test.sh

test-login:
	@echo "Running login test..."
	@./login_test.sh

test-user-journey:
	@echo "Running user journey test..."
	@./user_journey_test.sh

# Clean up any leftover resources
clean:
	@echo "Cleaning up resources..."
	@find . -name "docker-compose.*_test.sh.yml" -type f -delete
	@docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true
	@docker network prune -f --filter "name=test-network-*" > /dev/null 2>&1
	@docker volume prune -f --filter "name=postgres_data_*" --filter "name=redis_data_*" > /dev/null 2>&1

# Help target
help:
	@echo "Available targets:"
	@echo "  all                     - Run all tests (default)"
	@echo "  test                    - Run all tests sequentially"
	@echo "  test-parallel           - Run all tests in parallel"
	@echo "  test-registration       - Run user registration test"
	@echo "  test-failed-registration - Run failed registration test"
	@echo "  test-login              - Run login test"
	@echo "  test-user-journey       - Run user journey test"
	@echo "  clean                   - Clean up resources"
	@echo "  help                    - Show this help message"
