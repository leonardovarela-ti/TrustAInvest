# KYC Service API Documentation

## Overview

The KYC (Know Your Customer) Service API provides endpoints for identity verification, document validation, and compliance checks. It handles customer onboarding, identity verification, document processing, and compliance monitoring for TrustAInvest.com.

## Base URL

```
https://api.trustainvest.com/v1/kyc
```

## Authentication

All endpoints require a valid JWT token issued by Cognito. Include the token in the Authorization header:

```
Authorization: Bearer <jwt-token>
```

## Endpoints

### Verification

#### Start Verification Process

```
POST /verify
```

Initiates a new KYC verification process for a user.

**Request Body:**
```json
{
  "user_id": "string",
  "verification_level": "string",  // "BASIC", "STANDARD", "ENHANCED"
  "redirect_url": "string"
}
```

**Response:**
```json
{
  "verification_id": "string",
  "status": "string",
  "created_at": "string",
  "expires_at": "string",
  "verification_url": "string"
}
```

#### Get Verification Status

```
GET /verify/{verification_id}
```

Returns the current status of a verification process.

**Response:**
```json
{
  "verification_id": "string",
  "user_id": "string",
  "status": "string",  // "PENDING", "IN_PROGRESS", "COMPLETED", "REJECTED", "EXPIRED"
  "created_at": "string",
  "updated_at": "string",
  "expires_at": "string",
  "rejection_reason": "string",
  "verification_level": "string",
  "steps_completed": [
    {
      "name": "string",
      "status": "string",
      "completed_at": "string"
    }
  ],
  "steps_remaining": [
    {
      "name": "string",
      "required": true
    }
  ]
}
```

#### Cancel Verification

```
DELETE /verify/{verification_id}
```

Cancels an in-progress verification process.

**Response:**
```json
{
  "verification_id": "string",
  "status": "CANCELLED",
  "cancelled_at": "string"
}
```

### Documents

#### Upload Document

```
POST /documents
```

Uploads a document for KYC verification.

**Request Body (multipart/form-data):**
```
verification_id: string
document_type: string (ID_CARD, PASSPORT, DRIVERS_LICENSE, UTILITY_BILL, BANK_STATEMENT)
document_file: file
```

**Response:**
```json
{
  "document_id": "string",
  "verification_id": "string",
  "document_type": "string",
  "status": "string",  // "UPLOADED", "PROCESSING", "VERIFIED", "REJECTED"
  "uploaded_at": "string"
}
```

#### Get Document Status

```
GET /documents/{document_id}
```

Retrieves the status of a document.

**Response:**
```json
{
  "document_id": "string",
  "verification_id": "string",
  "document_type": "string",
  "status": "string",
  "uploaded_at": "string",
  "processed_at": "string",
  "rejection_reason": "string",
  "verification_details": {
    "name": "string",
    "date_of_birth": "string",
    "document_number": "string",
    "expiry_date": "string",
    "issuing_country": "string"
  }
}
```

#### List Documents

```
GET /verify/{verification_id}/documents
```

Lists all documents associated with a verification.

**Response:**
```json
{
  "documents": [
    {
      "document_id": "string",
      "document_type": "string",
      "status": "string",
      "uploaded_at": "string"
    }
  ]
}
```

### User Verification Status

#### Get User Verification Status

```
GET /users/{user_id}/verification
```

Gets the current verification status for a user.

**Response:**
```json
{
  "user_id": "string",
  "verification_status": "string",  // "NOT_STARTED", "IN_PROGRESS", "VERIFIED", "REJECTED"
  "verification_level": "string",
  "verified_at": "string",
  "expiry_date": "string",
  "latest_verification": {
    "verification_id": "string",
    "status": "string",
    "created_at": "string"
  }
}
```

### PEP and Sanctions Screening

#### Run Screening

```
POST /screening
```

Performs a PEP (Politically Exposed Person) and sanctions screening check.

**Request Body:**
```json
{
  "user_id": "string",
  "first_name": "string",
  "last_name": "string",
  "date_of_birth": "string",
  "nationality": "string",
  "country_of_residence": "string"
}
```

**Response:**
```json
{
  "screening_id": "string",
  "user_id": "string",
  "status": "string",  // "CLEAR", "POTENTIAL_MATCH", "MATCH"
  "completed_at": "string",
  "matches": [
    {
      "list_type": "string",  // "PEP", "SANCTION", "WATCHLIST"
      "match_level": "string",  // "LOW", "MEDIUM", "HIGH"
      "details": "string"
    }
  ]
}
```

### Address Verification

#### Verify Address

```
POST /address/verify
```

Verifies a user's address.

**Request Body:**
```json
{
  "user_id": "string",
  "verification_id": "string",
  "street": "string",
  "city": "string",
  "state": "string",
  "zip_code": "string",
  "country": "string"
}
```

**Response:**
```json
{
  "address_verification_id": "string",
  "verification_id": "string",
  "status": "string",  // "VERIFIED", "UNVERIFIED", "PENDING"
  "verified_at": "string",
  "verification_method": "string"
}
```

### Administration

#### Get Verification Metrics

```
GET /admin/metrics
```

Gets aggregate metrics on verifications (admin only).

**Response:**
```json
{
  "total_verifications": 0,
  "verifications_completed": 0,
  "verifications_pending": 0,
  "verifications_rejected": 0,
  "average_completion_time": 0,
  "verification_breakdown": {
    "BASIC": 0,
    "STANDARD": 0,
    "ENHANCED": 0
  }
}
```

## Error Codes

| Status Code | Description |
|-------------|-------------|
| 400 | Bad Request - Invalid parameters |
| 401 | Unauthorized - Invalid token |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found - Resource not found |
| 409 | Conflict - Resource already exists |
| 422 | Unprocessable Entity - Invalid document format |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error |

## Data Retention

All KYC data is securely stored in compliance with data protection regulations:
- ID documents are encrypted at rest
- Data is retained for the legally required period
- Data deletion is available upon request (subject to regulatory requirements)

## Webhooks

The KYC service can send webhooks to notify your application of important events:

```
POST /webhooks
```

**Request Body:**
```json
{
  "url": "string",
  "events": ["VERIFICATION_COMPLETED", "VERIFICATION_REJECTED", "DOCUMENT_PROCESSED"],
  "secret": "string"
}
```

**Response:**
```json
{
  "webhook_id": "string",
  "url": "string",
  "events": ["string"],
  "created_at": "string"
}
```

## Compliance

The KYC Service complies with:
- AML (Anti-Money Laundering) regulations
- KYC (Know Your Customer) requirements
- GDPR (General Data Protection Regulation)
- CCPA (California Consumer Privacy Act)