package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/client"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/models"
)

// CapitalOneService handles the business logic for Capital One integration
type CapitalOneService struct {
	db               *pgxpool.Pool
	capitalOneClient *client.CapitalOneClient
	redirectURI      string
}

// NewCapitalOneService creates a new Capital One service
func NewCapitalOneService(db *pgxpool.Pool, clientID, clientSecret, redirectURI string, useSandbox bool) *CapitalOneService {
	return &CapitalOneService{
		db:               db,
		capitalOneClient: client.NewCapitalOneClient(clientID, clientSecret, useSandbox),
		redirectURI:      redirectURI,
	}
}

// InitiateAuth starts the OAuth flow for Capital One
func (s *CapitalOneService) InitiateAuth(userID string) (*models.CapitalOneAuthResponse, error) {
	// Generate the authorization URL
	state, authURL, err := s.capitalOneClient.GetAuthorizationURL(s.redirectURI)
	if err != nil {
		return nil, fmt.Errorf("failed to get authorization URL: %w", err)
	}

	// Store the state in the database
	err = s.storeAuthState(userID, state)
	if err != nil {
		return nil, fmt.Errorf("failed to store auth state: %w", err)
	}

	return &models.CapitalOneAuthResponse{
		AuthURL: authURL,
		State:   state,
	}, nil
}

// CompleteAuth completes the OAuth flow for Capital One
func (s *CapitalOneService) CompleteAuth(callback *models.CapitalOneAuthCallback) (string, error) {
	// Verify the state
	storedState, err := s.getAuthState(callback.UserID)
	if err != nil {
		return "", fmt.Errorf("failed to get stored auth state: %w", err)
	}

	if storedState != callback.State {
		return "", errors.New("state mismatch")
	}

	// Exchange the code for an access token
	accessToken, refreshToken, expiresIn, err := s.capitalOneClient.ExchangeCodeForToken(callback.Code, callback.RedirectURI)
	if err != nil {
		return "", fmt.Errorf("failed to exchange code for token: %w", err)
	}

	// Store the tokens in the database
	err = s.storeTokens(callback.UserID, accessToken, refreshToken, expiresIn)
	if err != nil {
		return "", fmt.Errorf("failed to store tokens: %w", err)
	}

	return accessToken, nil
}

// GetAccounts retrieves the list of accounts for the authenticated user
func (s *CapitalOneService) GetAccounts(userID string) ([]models.CapitalOneAccount, error) {
	// Get the tokens from the database
	accessToken, refreshToken, expiresIn, err := s.getTokens(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tokens: %w", err)
	}

	// Set the credentials in the client
	s.capitalOneClient.SetCredentials(accessToken, refreshToken, expiresIn)

	// Get the accounts
	accounts, err := s.capitalOneClient.GetAccounts()
	if err != nil {
		return nil, fmt.Errorf("failed to get accounts: %w", err)
	}

	return accounts, nil
}

// LinkAccount links a Capital One account to a TrustAInvest account
func (s *CapitalOneService) LinkAccount(req *models.CapitalOneAccountLinkRequest) (*models.CapitalOneAccountLinkResponse, error) {
	// Get the tokens from the database
	accessToken, refreshToken, expiresIn, err := s.getTokens(req.UserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get tokens: %w", err)
	}

	// Set the credentials in the client
	s.capitalOneClient.SetCredentials(accessToken, refreshToken, expiresIn)

	// Get the account details to verify the account exists
	account, err := s.capitalOneClient.GetAccountDetails(req.AccountID)
	if err != nil {
		return nil, fmt.Errorf("failed to get account details: %w", err)
	}

	// Use the provided account name if available, otherwise use the one from Capital One
	accountName := account.AccountName
	if req.AccountName != "" {
		accountName = req.AccountName
	}

	// Create the account in the database
	internalID, err := s.createAccountInDB(req.UserID, account, accountName)
	if err != nil {
		return nil, fmt.Errorf("failed to create account in database: %w", err)
	}

	return &models.CapitalOneAccountLinkResponse{
		Success:    true,
		Message:    "Account linked successfully",
		AccountID:  account.AccountID,
		InternalID: internalID,
	}, nil
}

// SearchBankProducts searches for bank products based on the provided criteria
func (s *CapitalOneService) SearchBankProducts(productID string, searchRequest *models.BankProductSearchRequest) (*models.BankProductSearchResponse, error) {
	// Search for bank products using the client
	return s.capitalOneClient.SearchBankProducts(productID, searchRequest)
}

// storeAuthState stores the auth state in the database
func (s *CapitalOneService) storeAuthState(userID, state string) error {
	ctx := context.Background()
	_, err := s.db.Exec(
		ctx,
		`INSERT INTO capitalone.auth_states (user_id, state, created_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE
		SET state = $2, created_at = $3`,
		userID, state, time.Now(),
	)
	return err
}

// getAuthState retrieves the auth state from the database
func (s *CapitalOneService) getAuthState(userID string) (string, error) {
	ctx := context.Background()
	var state string
	err := s.db.QueryRow(
		ctx,
		`SELECT state FROM capitalone.auth_states WHERE user_id = $1`,
		userID,
	).Scan(&state)
	return state, err
}

// storeTokens stores the tokens in the database
func (s *CapitalOneService) storeTokens(userID, accessToken, refreshToken string, expiresIn int) error {
	ctx := context.Background()
	expiresAt := time.Now().Add(time.Duration(expiresIn) * time.Second)
	_, err := s.db.Exec(
		ctx,
		`INSERT INTO capitalone.auth_tokens (user_id, access_token, refresh_token, expires_at, created_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id) DO UPDATE
		SET access_token = $2, refresh_token = $3, expires_at = $4, updated_at = $5`,
		userID, accessToken, refreshToken, expiresAt, time.Now(),
	)
	return err
}

// getTokens retrieves the tokens from the database
func (s *CapitalOneService) getTokens(userID string) (string, string, int, error) {
	ctx := context.Background()
	var accessToken, refreshToken string
	var expiresAt time.Time
	err := s.db.QueryRow(
		ctx,
		`SELECT access_token, refresh_token, expires_at FROM capitalone.auth_tokens WHERE user_id = $1`,
		userID,
	).Scan(&accessToken, &refreshToken, &expiresAt)

	// Calculate the remaining time until expiration
	expiresIn := int(time.Until(expiresAt).Seconds())
	if expiresIn < 0 {
		expiresIn = 0
	}

	return accessToken, refreshToken, expiresIn, err
}

// createAccountInDB creates an account in the database
func (s *CapitalOneService) createAccountInDB(userID string, account *models.CapitalOneAccount, accountName string) (string, error) {
	ctx := context.Background()
	id := uuid.New().String()

	// Determine the account type for our system
	accountType := "CHECKING"
	if account.AccountType == "CREDIT_CARD" {
		accountType = "CREDIT_CARD"
	} else if account.AccountType == "INVESTMENT" {
		accountType = "BROKERAGE"
	} else if account.AccountType == "SAVINGS" {
		accountType = "SAVINGS"
	}

	_, err := s.db.Exec(
		ctx,
		`INSERT INTO accounts.accounts (
			id, user_id, type, name, description, institution_id, institution_name,
			external_account_id, balance_amount, balance_currency, is_active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
		)`,
		id, userID, accountType, accountName, "Capital One "+account.AccountType+" account",
		"capitalone", "Capital One", account.AccountID, account.Balance, account.Currency, true,
	)

	if err != nil {
		return "", err
	}

	return id, nil
}

// ensureCapitalOneSchema ensures the capitalone schema and tables exist
func (s *CapitalOneService) EnsureCapitalOneSchema() error {
	ctx := context.Background()

	// Create the capitalone schema if it doesn't exist
	_, err := s.db.Exec(ctx, "CREATE SCHEMA IF NOT EXISTS capitalone")
	if err != nil {
		return err
	}

	// Create the auth_states table if it doesn't exist
	_, err = s.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS capitalone.auth_states (
			user_id UUID PRIMARY KEY REFERENCES users.users(id),
			state TEXT NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
		)
	`)
	if err != nil {
		return err
	}

	// Create the auth_tokens table if it doesn't exist
	_, err = s.db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS capitalone.auth_tokens (
			user_id UUID PRIMARY KEY REFERENCES users.users(id),
			access_token TEXT NOT NULL,
			refresh_token TEXT NOT NULL,
			expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
			created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMP WITH TIME ZONE
		)
	`)
	if err != nil {
		return err
	}

	// Create indexes
	_, err = s.db.Exec(ctx, "CREATE INDEX IF NOT EXISTS idx_capitalone_auth_states_user_id ON capitalone.auth_states(user_id)")
	if err != nil {
		return err
	}

	_, err = s.db.Exec(ctx, "CREATE INDEX IF NOT EXISTS idx_capitalone_auth_tokens_user_id ON capitalone.auth_tokens(user_id)")
	if err != nil {
		return err
	}

	return nil
}
