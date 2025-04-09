# Makefile for TrustAInvest integration tests

.PHONY: all test clean

# Default target
all: test

# Run all tests
test:
	@echo "Running all integration tests..."
	@./run_tests.sh

# Run specific tests
test-registration:
	@echo "Running user registration test..."
	@./integration_test.sh

test-failed-registration:
	@echo "Running failed registration test..."
	@./failed_registration_test.sh

# Clean up any leftover resources
clean:
	@echo "Cleaning up resources..."
	@docker-compose -f docker-compose.test.yml down -v

# Help target
help:
	@echo "Available targets:"
	@echo "  all                     - Run all tests (default)"
	@echo "  test                    - Run all tests"
	@echo "  test-registration       - Run user registration test"
	@echo "  test-failed-registration - Run failed registration test"
	@echo "  clean                   - Clean up resources"
	@echo "  help                    - Show this help message"
