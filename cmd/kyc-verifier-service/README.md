# KYC Verifier Service

This service provides the backend API for the KYC Verifier UI application. It allows KYC verifiers to review and process verification requests from customers.

## Overview

The KYC Verifier Service is a RESTful API that provides the following functionality:

- Authentication for KYC verifiers
- Listing and filtering verification requests
- Viewing verification request details
- Approving or rejecting verification requests
- Managing verifier accounts (admin only)

## API Endpoints

### Authentication

- `POST /api/auth/login` - Login with username and password
- `POST /api/auth/refresh` - Refresh JWT token
- `POST /api/auth/change-password` - Change password

### Verification Requests

- `GET /api/verification-requests` - List verification requests with optional filters
- `GET /api/verification-requests/{id}` - Get verification request details
- `PATCH /api/verification-requests/{id}/status` - Update verification status

### Documents

- `GET /api/verification-requests/{id}/documents` - Get documents for a verification request
- `PATCH /api/documents/{id}/verify` - Verify a document

### Dashboard

- `GET /api/dashboard/stats` - Get dashboard statistics

### Verifier Management (Admin only)

- `GET /api/verifiers` - List all verifiers
- `POST /api/verifiers` - Create a new verifier
- `PATCH /api/verifiers/{id}` - Update a verifier
- `DELETE /api/verifiers/{id}` - Delete a verifier

## Implementation

### Database Tables

The service uses the following database tables:

1. `kyc.verifiers` - Stores KYC verifier users
2. `kyc.verification_requests` - Stores verification requests
3. `kyc.documents` - Stores documents for verification requests

See `scripts/kyc-verifier-tables.sql` for the complete database schema.

### Code Structure

The service follows a layered architecture:

1. **API Layer** (`internal/api/kyc_verifier_handler.go`) - Handles HTTP requests and responses
2. **Repository Layer** (`internal/db/kyc_verifier_repository.go`) - Handles database operations
3. **Model Layer** (`internal/models/kyc_verifier_models.go`) - Defines data models

### Authentication

The service uses JWT (JSON Web Token) for authentication. The token contains the following claims:

- `sub` - User ID
- `username` - Username
- `email` - Email address
- `role` - User role (ADMIN or VERIFIER)
- `exp` - Expiration time

### Authorization

The service implements role-based access control:

- **VERIFIER** - Can view and process verification requests
- **ADMIN** - Can manage verifier accounts and perform all VERIFIER actions

## Implementation Steps

1. Create the database tables using `scripts/kyc-verifier-tables.sql`
2. Implement the model layer in `internal/models/kyc_verifier_models.go`
3. Implement the repository layer in `internal/db/kyc_verifier_repository.go`
4. Implement the API layer in `internal/api/kyc_verifier_handler.go`
5. Create the main service in `cmd/kyc-verifier-service/main.go`

## API Handler Implementation

The API handler should implement the following functionality:

1. **Authentication**
   - Login with username and password
   - Refresh JWT token
   - Change password

2. **Verification Request Management**
   - List verification requests with filtering and pagination
   - Get verification request details
   - Update verification status

3. **Document Management**
   - List documents for a verification request
   - Verify documents

4. **Dashboard Statistics**
   - Get counts of pending, verified, and rejected requests
   - Get counts of total and verified documents
   - Get count of verifications performed by the current user

5. **Verifier Management (Admin only)**
   - List all verifiers
   - Create a new verifier
   - Update a verifier
   - Delete a verifier

## Repository Implementation

The repository layer should implement the following functionality:

1. **Verifier Management**
   - Get verifier by username or ID
   - Create, update, and delete verifiers
   - Change password

2. **Verification Request Management**
   - Get verification requests with filtering and pagination
   - Get verification request by ID
   - Update verification status

3. **Document Management**
   - Get documents for a verification request
   - Verify documents

4. **Dashboard Statistics**
   - Get counts for dashboard statistics

## Integration with Frontend

The KYC Verifier UI application communicates with this service using the API endpoints described above. The frontend uses the following services:

1. **AuthService** - Handles authentication and user management
2. **ApiService** - Handles API communication with the backend

## Running the Service

### Option 1: Local Development

1. Create the database tables:
   ```
   psql -U postgres -d trustainvest -f scripts/init-db.sql
   ```

2. Build the service:
   ```
   go build -o bin/kyc-verifier-service cmd/kyc-verifier-service/main.go
   ```

3. Run the service:
   ```
   ./bin/kyc-verifier-service
   ```

### Option 2: Docker Deployment

1. Make sure Docker and Docker Compose are installed on your system.

2. Navigate to the project root directory (TrustAInvest.com).

3. Build and run the services:
   ```
   docker-compose -f docker-compose.kyc-verifier.yml up -d
   ```

4. The service will be available at http://localhost:8090

## Environment Variables

The service uses the following environment variables:

- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET` - Secret key for JWT token signing
- `PORT` - HTTP server port (default: 8090)
- `CORS_ALLOWED_ORIGINS` - Comma-separated list of allowed origins for CORS

## Docker Configuration

The service is containerized using Docker. The Dockerfile is located at `cmd/kyc-verifier-service/Dockerfile`. It uses a multi-stage build process:

1. **Builder Stage**: Uses golang:1.22-alpine to build the application
2. **Final Stage**: Uses alpine:3.16 to run the application

The Docker Compose configuration is located at `docker-compose.kyc-verifier.yml`. It includes:

1. **PostgreSQL**: Database service
2. **KYC Verifier Service**: Backend API service
3. **KYC Verifier UI**: Frontend web application

## Troubleshooting

1. **Database Connection Issues**: Ensure PostgreSQL is running and accessible. Check the connection string in the environment variables.

2. **Port Conflicts**: If port 8090 is already in use, modify the `PORT` environment variable to use a different port.

3. **CORS Issues**: If you're experiencing CORS issues, ensure the `CORS_ALLOWED_ORIGINS` environment variable includes your frontend URL.

4. **JWT Issues**: If you're experiencing authentication issues, check the `JWT_SECRET` environment variable and ensure it matches the one used by the frontend.
