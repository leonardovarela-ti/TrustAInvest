package models

import (
	"time"
)

// CapitalOneCredentials represents the credentials needed to authenticate with Capital One API
type CapitalOneCredentials struct {
	ClientID     string    `json:"client_id"`
	ClientSecret string    `json:"client_secret"`
	AccessToken  string    `json:"access_token,omitempty"`
	RefreshToken string    `json:"refresh_token,omitempty"`
	ExpiresAt    time.Time `json:"expires_at,omitempty"`
}

// CapitalOneAccount represents a Capital One account
type CapitalOneAccount struct {
	AccountID        string                  `json:"account_id"`
	AccountName      string                  `json:"account_name"`
	AccountType      string                  `json:"account_type"`
	InstitutionID    string                  `json:"institution_id"`
	InstitutionName  string                  `json:"institution_name"`
	Balance          float64                 `json:"balance"`
	Currency         string                  `json:"currency"`
	LastUpdated      time.Time               `json:"last_updated"`
	Status           string                  `json:"status"`
	AccountPositions []CapitalOnePosition    `json:"account_positions,omitempty"`
	Transactions     []CapitalOneTransaction `json:"transactions,omitempty"`
}

// CapitalOnePosition represents a position in a Capital One investment account
type CapitalOnePosition struct {
	Symbol        string    `json:"symbol"`
	Quantity      float64   `json:"quantity"`
	CostBasis     float64   `json:"cost_basis"`
	MarketValue   float64   `json:"market_value"`
	GainLoss      float64   `json:"gain_loss"`
	GainLossPerc  float64   `json:"gain_loss_perc"`
	LastPrice     float64   `json:"last_price"`
	LastPriceTime time.Time `json:"last_price_time"`
}

// CapitalOneTransaction represents a transaction in a Capital One account
type CapitalOneTransaction struct {
	TransactionID   string    `json:"transaction_id"`
	TransactionDate time.Time `json:"transaction_date"`
	PostDate        time.Time `json:"post_date"`
	Description     string    `json:"description"`
	Category        string    `json:"category"`
	Amount          float64   `json:"amount"`
	Type            string    `json:"type"`
	Status          string    `json:"status"`
}

// CapitalOneAuthRequest represents a request to link a Capital One account
type CapitalOneAuthRequest struct {
	UserID      string `json:"user_id" binding:"required"`
	ClientID    string `json:"client_id" binding:"required"`
	RedirectURI string `json:"redirect_uri" binding:"required"`
}

// CapitalOneAuthResponse represents a response from the Capital One auth process
type CapitalOneAuthResponse struct {
	AuthURL string `json:"auth_url"`
	State   string `json:"state"`
}

// CapitalOneAuthCallback represents the callback data from Capital One after user authorization
type CapitalOneAuthCallback struct {
	Code        string `json:"code"`
	State       string `json:"state"`
	UserID      string `json:"user_id"`
	RedirectURI string `json:"redirect_uri"`
}

// CapitalOneTokenResponse represents the response from the Capital One token endpoint
type CapitalOneTokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
}

// CapitalOneAccountLinkRequest represents a request to link a Capital One account to a TrustAInvest account
type CapitalOneAccountLinkRequest struct {
	UserID      string `json:"user_id" binding:"required"`
	AccountID   string `json:"account_id" binding:"required"`
	AccountName string `json:"account_name,omitempty"`
}

// CapitalOneAccountLinkResponse represents a response after linking a Capital One account
type CapitalOneAccountLinkResponse struct {
	Success    bool   `json:"success"`
	Message    string `json:"message,omitempty"`
	AccountID  string `json:"account_id,omitempty"`
	InternalID string `json:"internal_id,omitempty"`
}

// CapitalOneError represents an error from the Capital One API
type CapitalOneError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// BankProductSearchRequest represents a request to search for bank products
type BankProductSearchRequest struct {
	ProductType string  `json:"productType"`
	ZipCode     string  `json:"zipCode"`
	Amount      float64 `json:"amount,omitempty"`
	Term        int     `json:"term,omitempty"`
}

// BankProduct represents a Capital One bank product
type BankProduct struct {
	ProductID       string    `json:"productId"`
	ProductType     string    `json:"productType"`
	ProductName     string    `json:"productName"`
	ProductURL      string    `json:"productUrl"`
	APY             float64   `json:"apy"`
	MinimumDeposit  float64   `json:"minimumDeposit"`
	MaximumDeposit  float64   `json:"maximumDeposit,omitempty"`
	Term            int       `json:"term,omitempty"`
	TermUnit        string    `json:"termUnit,omitempty"`
	Features        []string  `json:"features"`
	EffectiveDate   time.Time `json:"effectiveDate"`
	ExpirationDate  time.Time `json:"expirationDate,omitempty"`
	AvailableOnline bool      `json:"availableOnline"`
}

// BankProductSearchResponse represents a response from searching for bank products
type BankProductSearchResponse struct {
	Products []BankProduct `json:"products"`
}
