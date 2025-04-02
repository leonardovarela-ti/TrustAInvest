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

## License

Proprietary - All Rights Reserved
