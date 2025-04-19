package models

import (
	"time"
)

// ETradeCredentials represents the credentials needed to authenticate with E-Trade API
type ETradeCredentials struct {
	ConsumerKey    string    `json:"consumer_key"`
	ConsumerSecret string    `json:"consumer_secret"`
	AccessToken    string    `json:"access_token,omitempty"`
	TokenSecret    string    `json:"token_secret,omitempty"`
	ExpiresAt      time.Time `json:"expires_at,omitempty"`
}

// ETradeAccount represents an E-Trade account
type ETradeAccount struct {
	AccountID        string           `json:"account_id"`
	AccountName      string           `json:"account_name"`
	AccountType      string           `json:"account_type"`
	InstitutionID    string           `json:"institution_id"`
	InstitutionName  string           `json:"institution_name"`
	Balance          float64          `json:"balance"`
	Currency         string           `json:"currency"`
	LastUpdated      time.Time        `json:"last_updated"`
	Status           string           `json:"status"`
	AccountPositions []ETradePosition `json:"account_positions,omitempty"`
}

// ETradePosition represents a position in an E-Trade account
type ETradePosition struct {
	Symbol        string    `json:"symbol"`
	Quantity      float64   `json:"quantity"`
	CostBasis     float64   `json:"cost_basis"`
	MarketValue   float64   `json:"market_value"`
	GainLoss      float64   `json:"gain_loss"`
	GainLossPerc  float64   `json:"gain_loss_perc"`
	LastPrice     float64   `json:"last_price"`
	LastPriceTime time.Time `json:"last_price_time"`
}

// ETradeAuthRequest represents a request to link an E-Trade account
type ETradeAuthRequest struct {
	UserID      string `json:"user_id" binding:"required"`
	ConsumerKey string `json:"consumer_key" binding:"required"`
	CallbackURL string `json:"callback_url" binding:"required"`
}

// ETradeAuthResponse represents a response from the E-Trade auth process
type ETradeAuthResponse struct {
	RequestToken string `json:"request_token"`
	AuthURL      string `json:"auth_url"`
}

// ETradeAuthCallback represents the callback data from E-Trade after user authorization
type ETradeAuthCallback struct {
	RequestToken string `json:"request_token"`
	Verifier     string `json:"verifier"`
	UserID       string `json:"user_id"`
}

// ETradeAccountLinkRequest represents a request to link an E-Trade account to a TrustAInvest account
type ETradeAccountLinkRequest struct {
	UserID      string `json:"user_id" binding:"required"`
	AccountID   string `json:"account_id" binding:"required"`
	AccountName string `json:"account_name,omitempty"`
}

// ETradeAccountLinkResponse represents a response after linking an E-Trade account
type ETradeAccountLinkResponse struct {
	Success    bool   `json:"success"`
	Message    string `json:"message,omitempty"`
	AccountID  string `json:"account_id,omitempty"`
	InternalID string `json:"internal_id,omitempty"`
}

// ETradeError represents an error from the E-Trade API
type ETradeError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
