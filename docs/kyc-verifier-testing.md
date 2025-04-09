# KYC Verifier System Testing Guide

This document provides instructions for testing the KYC Verifier system, which consists of a Flutter UI application and a Go backend service.

## Prerequisites

- Docker and Docker Compose installed
- Go 1.19 or higher installed
- Flutter SDK installed
- PostgreSQL client installed (for direct database access)

## Setup

1. Clone the repository:
   ```
   git clone https://github.com/TrustAInvest/TrustAInvest.com.git
   cd TrustAInvest.com
   ```

2. Create the database tables:
   ```
   psql -U postgres -d trustainvest -f scripts/kyc-verifier-tables.sql
   ```

3. Build and run the services using Docker Compose:
   ```
   docker-compose -f docker-compose.kyc-verifier.yml up -d
   ```

## Testing the Backend API

You can test the backend API using curl or a tool like Postman.

### Authentication

1. Login with the default admin user:
   ```
   curl -X POST http://localhost:8080/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"admin123"}'
   ```

   This should return a JWT token:
   ```json
   {
     "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   }
   ```

2. Use the token for authenticated requests:
   ```
   export TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
   ```

### Verification Requests

1. List verification requests:
   ```
   curl -X GET http://localhost:8080/api/verification-requests \
     -H "Authorization: Bearer $TOKEN"
   ```

2. Get a specific verification request:
   ```
   curl -X GET http://localhost:8080/api/verification-requests/{id} \
     -H "Authorization: Bearer $TOKEN"
   ```

3. Update verification status:
   ```
   curl -X PATCH http://localhost:8080/api/verification-requests/{id}/status \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{"status":"VERIFIED"}'
   ```

### Verifier Management (Admin only)

1. List all verifiers:
   ```
   curl -X GET http://localhost:8080/api/verifiers \
     -H "Authorization: Bearer $TOKEN"
   ```

2. Create a new verifier:
   ```
   curl -X POST http://localhost:8080/api/verifiers \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $TOKEN" \
     -d '{
       "username": "verifier1",
       "email": "verifier1@trustainvest.com",
       "password": "password123",
       "first_name": "John",
       "last_name": "Doe",
       "role": "VERIFIER"
     }'
   ```

## Testing the Flutter UI

The Flutter UI can be accessed at http://localhost:3000.

### Login

1. Open http://localhost:3000 in your browser
2. Login with the default admin credentials:
   - Username: `admin`
   - Password: `admin123`

### Dashboard

After logging in, you should see the dashboard with statistics about verification requests.

### Verification Requests

1. Click on "Verification Requests" in the sidebar
2. You should see a list of verification requests
3. Click on a request to view its details
4. You can approve or reject the request from the details page

### Verifier Management (Admin only)

1. Click on "Verifier Management" in the sidebar
2. You should see a list of verifiers
3. Click "Add Verifier" to create a new verifier
4. You can edit or delete existing verifiers

## Testing with Sample Data

To test with sample data, you can insert test records into the database:

```sql
-- Insert a test verification request
INSERT INTO kyc.verification_requests (
    user_id,
    first_name,
    last_name,
    email,
    phone,
    date_of_birth,
    address_line1,
    city,
    state,
    postal_code,
    country,
    status
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Jane',
    'Smith',
    'jane.smith@example.com',
    '+1234567890',
    '1990-01-01',
    '123 Main St',
    'New York',
    'NY',
    '10001',
    'USA',
    'PENDING'
);

-- Insert a test document
INSERT INTO kyc.documents (
    request_id,
    user_id,
    type,
    file_name,
    file_type,
    file_size,
    file_url,
    is_verified,
    uploaded_at
) VALUES (
    (SELECT id FROM kyc.verification_requests WHERE email = 'jane.smith@example.com'),
    '00000000-0000-0000-0000-000000000001',
    'PASSPORT',
    'passport.jpg',
    'image/jpeg',
    1024,
    'https://example.com/documents/passport.jpg',
    false,
    NOW()
);
```

## Troubleshooting

### Database Connection Issues

If the service cannot connect to the database, check:
- The database is running
- The DATABASE_URL environment variable is correct
- The database user has the necessary permissions

### Authentication Issues

If you cannot log in:
- Check that the default admin user exists in the database
- Verify the password hash is correct
- Ensure the JWT_SECRET environment variable is set correctly

### CORS Issues

If the UI cannot connect to the API:
- Check that the CORS_ALLOWED_ORIGINS environment variable includes the UI origin
- Verify the API URL in the UI's .env file is correct

## End-to-End Testing

For automated end-to-end testing, you can use tools like Cypress or Selenium to simulate user interactions with the UI.

Example Cypress test for login:

```javascript
describe('Login', () => {
  it('should login with valid credentials', () => {
    cy.visit('http://localhost:3000');
    cy.get('input[name="username"]').type('admin');
    cy.get('input[name="password"]').type('admin123');
    cy.get('button[type="submit"]').click();
    cy.url().should('include', '/dashboard');
  });
});
