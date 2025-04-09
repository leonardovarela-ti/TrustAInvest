package models

import (
	"time"

	"github.com/google/uuid"
)

// Verifier represents a KYC verifier user
type Verifier struct {
	ID           uuid.UUID  `json:"id"`
	Username     string     `json:"username"`
	Email        string     `json:"email"`
	PasswordHash string     `json:"-"`
	FirstName    string     `json:"first_name"`
	LastName     string     `json:"last_name"`
	Role         string     `json:"role"`
	IsActive     bool       `json:"is_active"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    *time.Time `json:"updated_at,omitempty"`
}

// VerificationRequest represents a KYC verification request
type VerificationRequest struct {
	ID              uuid.UUID  `json:"id"`
	UserID          uuid.UUID  `json:"user_id"`
	FirstName       string     `json:"first_name"`
	LastName        string     `json:"last_name"`
	Email           string     `json:"email"`
	Phone           *string    `json:"phone,omitempty"`
	DateOfBirth     time.Time  `json:"date_of_birth"`
	AddressLine1    string     `json:"address_line1"`
	AddressLine2    *string    `json:"address_line2,omitempty"`
	City            string     `json:"city"`
	State           string     `json:"state"`
	PostalCode      string     `json:"postal_code"`
	Country         string     `json:"country"`
	AdditionalInfo  *string    `json:"additional_info,omitempty"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	VerifierID      *uuid.UUID `json:"verifier_id,omitempty"`
	VerifiedAt      *time.Time `json:"verified_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       *time.Time `json:"updated_at,omitempty"`
	DocumentCount   int        `json:"document_count,omitempty"`
}

// Document represents a KYC document
type Document struct {
	ID                uuid.UUID  `json:"id"`
	RequestID         uuid.UUID  `json:"request_id"`
	UserID            uuid.UUID  `json:"user_id"`
	Type              string     `json:"type"`
	FileName          string     `json:"file_name"`
	FileType          string     `json:"file_type"`
	FileSize          int        `json:"file_size"`
	FileURL           string     `json:"file_url"`
	ThumbnailURL      *string    `json:"thumbnail_url,omitempty"`
	IsVerified        bool       `json:"is_verified"`
	VerificationNotes *string    `json:"verification_notes,omitempty"`
	UploadedAt        time.Time  `json:"uploaded_at"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         *time.Time `json:"updated_at,omitempty"`
}

// DashboardStats represents statistics for the dashboard
type DashboardStats struct {
	TotalRequests     int `json:"total_requests"`
	PendingRequests   int `json:"pending_requests"`
	VerifiedRequests  int `json:"verified_requests"`
	RejectedRequests  int `json:"rejected_requests"`
	TotalDocuments    int `json:"total_documents"`
	VerifiedDocuments int `json:"verified_documents"`
	MyVerifications   int `json:"my_verifications"`
}
