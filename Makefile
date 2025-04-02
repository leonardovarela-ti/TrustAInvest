# TrustAInvest.com Makefile

.PHONY: setup build run test clean deploy

# Default environment
ENV ?= dev

# Project settings
PROJECT_NAME := trustainvest
SERVICES := user-service account-service trust-service investment-service document-service notification-service

# Build settings
GO := go
GOFLAGS := -v
BUILD_DIR := ./bin

# Docker settings
DOCKER_COMPOSE := docker-compose
DOCKER_COMPOSE_FILE := docker-compose.yml

# AWS settings
AWS_REGION ?= us-east-1
AWS_PROFILE ?= default
TERRAFORM := terraform
TERRAFORM_DIR := ./deployments/terraform

# Setup development environment
setup:
	@echo "Setting up development environment..."
	@mkdir -p $(BUILD_DIR)
	@echo "Installing dependencies..."
	$(GO) mod tidy
	@echo "Setting up database..."
	$(DOCKER_COMPOSE) up -d postgres redis
	@echo "Setup complete!"

# Build all services
build:
	@echo "Building all services..."
	@mkdir -p $(BUILD_DIR)
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		$(GO) build $(GOFLAGS) -o $(BUILD_DIR)/$$service ./cmd/$$service; \
	done
	@echo "Build complete!"

# Run services locally using Docker Compose
run:
	@echo "Starting all services..."
	$(DOCKER_COMPOSE) up -d

# Stop all services
stop:
	@echo "Stopping all services..."
	$(DOCKER_COMPOSE) down

# Run tests
test:
	@echo "Running tests..."
	$(GO) test ./...

# Clean build artifacts
clean:
	@echo "Cleaning up..."
	rm -rf $(BUILD_DIR)
	$(DOCKER_COMPOSE) down -v
	@echo "Cleanup complete!"

# Deploy to AWS
deploy:
	@echo "Deploying to $(ENV) environment..."
	cd $(TERRAFORM_DIR)/$(ENV) && \
	$(TERRAFORM) init && \
	$(TERRAFORM) apply -auto-approve

# Generate database migrations
migrate-create:
	@echo "Creating new migration..."
	@read -p "Enter migration name: " name; \
	migrate create -ext sql -dir ./migrations -seq $$name

# Apply database migrations
migrate-up:
	@echo "Applying migrations..."
	migrate -path ./migrations -database "postgres://trustainvest:trustainvest@localhost:5432/trustainvest?sslmode=disable" up

# Rollback database migrations
migrate-down:
	@echo "Rolling back migrations..."
	migrate -path ./migrations -database "postgres://trustainvest:trustainvest@localhost:5432/trustainvest?sslmode=disable" down 1

# Generate API documentation
gen-docs:
	@echo "Generating API documentation..."
	swag init -g ./cmd/user-service/main.go -o ./docs/user-service
	swag init -g ./cmd/account-service/main.go -o ./docs/account-service
	swag init -g ./cmd/trust-service/main.go -o ./docs/trust-service
	swag init -g ./cmd/investment-service/main.go -o ./docs/investment-service
	swag init -g ./cmd/document-service/main.go -o ./docs/document-service
	swag init -g ./cmd/notification-service/main.go -o ./docs/notification-service

# Show logs for a specific service
logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Please specify a service with SERVICE=<service-name>"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) logs -f $(SERVICE)

# Create a new service
create-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Please specify a service name with SERVICE=<service-name>"; \
		exit 1; \
	fi
	@echo "Creating new service: $(SERVICE)..."
	@mkdir -p ./cmd/$(SERVICE)
	@echo "package main\n\nimport (\n\t\"log\"\n\t\"os\"\n\t\"os/signal\"\n\t\"syscall\"\n)\n\nfunc main() {\n\tlog.Printf(\"Starting $(SERVICE)...\")\n\n\t// TODO: Initialize configuration\n\t\n\t// TODO: Set up database connection\n\t\n\t// TODO: Initialize services\n\t\n\t// TODO: Set up HTTP/gRPC server\n\t\n\t// Wait for termination signal\n\tsigChan := make(chan os.Signal, 1)\n\tsignal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)\n\t<-sigChan\n\t\n\tlog.Printf(\"Shutting down $(SERVICE)...\")\n\t\n\t// TODO: Graceful shutdown logic\n}" > ./cmd/$(SERVICE)/main.go
	@echo "Service $(SERVICE) created! Don't forget to add it to docker-compose.yml"
