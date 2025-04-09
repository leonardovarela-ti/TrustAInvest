package models

import (
	"time"
)

// User represents a user in the system
type User struct {
	ID            string     `json:"id"`
	Username      string     `json:"username"`
	Email         string     `json:"email"`
	PhoneNumber   string     `json:"phone_number,omitempty"`
	FirstName     string     `json:"first_name"`
	LastName      string     `json:"last_name"`
	DateOfBirth   time.Time  `json:"date_of_birth"`
	Address       Address    `json:"address,omitempty"`
	RiskProfile   string     `json:"risk_profile,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
	KYCStatus     string     `json:"kyc_status"`
	KYCVerifiedAt *time.Time `json:"kyc_verified_at,omitempty"`
	IsActive      bool       `json:"is_active"`
}

// Address represents a physical address
type Address struct {
	Street  string `json:"street"`
	City    string `json:"city"`
	State   string `json:"state"`
	ZipCode string `json:"zip_code"`
	Country string `json:"country"`
}

// Account represents a financial account
type Account struct {
	ID                string        `json:"id"`
	UserID            string        `json:"user_id"`
	Type              string        `json:"type"`
	Name              string        `json:"name"`
	Description       string        `json:"description,omitempty"`
	InstitutionID     string        `json:"institution_id,omitempty"`
	InstitutionName   string        `json:"institution_name,omitempty"`
	ExternalAccountID string        `json:"external_account_id,omitempty"`
	Balance           Money         `json:"balance"`
	IsActive          bool          `json:"is_active"`
	CreatedAt         time.Time     `json:"created_at"`
	UpdatedAt         time.Time     `json:"updated_at"`
	TrustID           *string       `json:"trust_id,omitempty"`
	Beneficiaries     []Beneficiary `json:"beneficiaries,omitempty"`
	TaxStatus         string        `json:"tax_status,omitempty"`
}

// Money represents a monetary amount with currency
type Money struct {
	Amount   float64 `json:"amount"`
	Currency string  `json:"currency"`
}

// Beneficiary represents a beneficiary on an account
type Beneficiary struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Relationship string    `json:"relationship,omitempty"`
	Percentage   int       `json:"percentage"`
	DateOfBirth  time.Time `json:"date_of_birth,omitempty"`
}

// Trustee represents a person who manages a trust
type Trustee struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Email         string    `json:"email"`
	PhoneNumber   string    `json:"phone_number,omitempty"`
	Role          string    `json:"role,omitempty"`
	DateAppointed time.Time `json:"date_appointed"`
	IsActive      bool      `json:"is_active"`
}

// DisbursementRule represents rules for disbursing trust funds
type DisbursementRule struct {
	ID               string    `json:"id"`
	Description      string    `json:"description"`
	BeneficiaryID    string    `json:"beneficiary_id"`
	TriggerType      string    `json:"trigger_type"` // e.g., "age", "date", "event"
	TriggerValue     string    `json:"trigger_value"`
	DisbursementType string    `json:"disbursement_type"` // e.g., "percentage", "fixed"
	Amount           Money     `json:"amount,omitempty"`
	Percentage       int       `json:"percentage,omitempty"`
	IsActive         bool      `json:"is_active"`
	CreatedAt        time.Time `json:"created_at"`
}

// Trust represents a legal trust
type Trust struct {
	ID                string             `json:"id"`
	Name              string             `json:"name"`
	Type              string             `json:"type"`
	Status            string             `json:"status"`
	CreatorUserID     string             `json:"creator_user_id"`
	Trustees          []Trustee          `json:"trustees"`
	Beneficiaries     []Beneficiary      `json:"beneficiaries"`
	DisbursementRules []DisbursementRule `json:"disbursement_rules"`
	DocumentID        string             `json:"document_id"`
	CreatedAt         time.Time          `json:"created_at"`
	UpdatedAt         time.Time          `json:"updated_at"`
	ActivatedAt       *time.Time         `json:"activated_at,omitempty"`
	LinkedAccounts    []string           `json:"linked_accounts"`
}
