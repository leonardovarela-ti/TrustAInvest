package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/client"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/models"
)

// ETradeService handles the business logic for E-Trade integration
type ETradeService struct {
	db           *pgxpool.Pool
	etradeClient *client.ETradeClient
	callbackURL  string
}

// NewETradeService creates a new E-Trade service
func NewETradeService(db *pgxpool.Pool, consumerKey, consumerSecret, callbackURL string, useSandbox bool) *ETradeService {
	return &ETradeService{
		db:           db,
		etradeClient: client.NewETradeClient(consumerKey, consumerSecret, useSandbox),
		callbackURL:  callbackURL,
	}
}

// InitiateAuth starts the OAuth flow for E-Trade
func (s *ETradeService) InitiateAuth(userID string) (*models.ETradeAuthResponse, error) {
	// Generate the authorization URL
	requestToken, authURL, err := s.etradeClient.GetAuthorizationURL(s.callbackURL)
	if err != nil {
		return nil, fmt.Errorf("failed to get authorization URL: %w", err)
	}

	// Store the request token in the database
	err = s.storeRequestToken(userID, requestToken)
	if err != nil {
		return nil, fmt.Errorf("failed to store request token: %w", err)
	}

	return &models.ETradeAuthResponse{
		RequestToken: requestToken,
		AuthURL:      authURL,
	}, nil
}

// CompleteAuth completes the OAuth flow for E-Trade
func (s *ETradeService) CompleteAuth(callback *models.ETradeAuthCallback) (string, error) {
	// Verify the request token
	storedToken, err := s.getRequestToken(callback.UserID)
	if err != nil {
		return "", fmt.Errorf("failed to get stored request token: %w", err)
	}

	if storedToken != callback.RequestToken {
		return "", errors.New("request token mismatch")
	}

	// Exchange the request token for an access token
	accessToken, tokenSecret, err := s.etradeClient.ExchangeRequestTokenForAccessToken(callback.RequestToken, callback.Verifier)
	if err != nil {
		return "", fmt.Errorf("failed to exchange request token: %w", err)
	}

	// Store the access token in the database
	err = s.storeAccessToken(callback.UserID, accessToken, tokenSecret)
	if err != nil {
		return "", fmt.Errorf("failed to store access token: %w", err)
	}

	return accessToken, nil
}

// GetAccounts retrieves the list of accounts for the authenticated user
func (s *ETradeService) GetAccounts(userID string) ([]models.ETradeAccount, error) {
	// Get the access token from the database
	accessToken, tokenSecret, err := s.getAccessToken(userID)
	if err != nil {
		return nil, fmt.Errorf("failed to get access token: %w", err)
	}

	// Set the credentials in the client
	s.etradeClient.SetCredentials(accessToken, tokenSecret)

	// Get the accounts
	accounts, err := s.etradeClient.GetAccounts()
	if err != nil {
		return nil, fmt.Errorf("failed to get accounts: %w", err)
	}

	return accounts, nil
}

// LinkAccount links an E-Trade account to a TrustAInvest account
func (s *ETradeService) LinkAccount(req *models.ETradeAccountLinkRequest) (*models.ETradeAccountLinkResponse, error) {
	// Get the access token from the database
	accessToken, tokenSecret, err := s.getAccessToken(req.UserID)
	if err != nil {
		return nil, fmt.Errorf("failed to get access token: %w", err)
	}

	// Set the credentials in the client
	s.etradeClient.SetCredentials(accessToken, tokenSecret)

	// Get the accounts to verify the account exists
	accounts, err := s.etradeClient.GetAccounts()
	if err != nil {
		return nil, fmt.Errorf("failed to get accounts: %w", err)
	}

	// Find the account
	var account *models.ETradeAccount
	for i, a := range accounts {
		if a.AccountID == req.AccountID {
			account = &accounts[i]
			break
		}
	}

	if account == nil {
		return nil, errors.New("account not found")
	}

	// Use the provided account name if available, otherwise use the one from E-Trade
	accountName := account.AccountName
	if req.AccountName != "" {
		accountName = req.AccountName
	}

	// Create the account in the database
	internalID, err := s.createAccountInDB(req.UserID, account, accountName)
	if err != nil {
		return nil, fmt.Errorf("failed to create account in database: %w", err)
	}

	return &models.ETradeAccountLinkResponse{
		Success:    true,
		Message:    "Account linked successfully",
		AccountID:  account.AccountID,
		InternalID: internalID,
	}, nil
}

// storeRequestToken stores the request token in the database
func (s *ETradeService) storeRequestToken(userID, requestToken string) error {
	ctx := context.Background()
	_, err := s.db.Exec(
		ctx,
		`INSERT INTO etrade.auth_tokens (user_id, request_token, created_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) DO UPDATE
		SET request_token = $2, created_at = $3`,
		userID, requestToken, time.Now(),
	)
	return err
}

// getRequestToken retrieves the request token from the database
func (s *ETradeService) getRequestToken(userID string) (string, error) {
	ctx := context.Background()
	var requestToken string
	err := s.db.QueryRow(
		ctx,
		`SELECT request_token FROM etrade.auth_tokens WHERE user_id = $1`,
		userID,
	).Scan(&requestToken)
	return requestToken, err
}

// storeAccessToken stores the access token in the database
func (s *ETradeService) storeAccessToken(userID, accessToken, tokenSecret string) error {
	ctx := context.Background()
	_, err := s.db.Exec(
		ctx,
		`UPDATE etrade.auth_tokens
		SET access_token = $1, token_secret = $2, updated_at = $3
		WHERE user_id = $4`,
		accessToken, tokenSecret, time.Now(), userID,
	)
	return err
}

// getAccessToken retrieves the access token from the database
func (s *ETradeService) getAccessToken(userID string) (string, string, error) {
	ctx := context.Background()
	var accessToken, tokenSecret string
	err := s.db.QueryRow(
		ctx,
		`SELECT access_token, token_secret FROM etrade.auth_tokens WHERE user_id = $1`,
		userID,
	).Scan(&accessToken, &tokenSecret)
	return accessToken, tokenSecret, err
}

// createAccountInDB creates an account in the database
func (s *ETradeService) createAccountInDB(userID string, account *models.ETradeAccount, accountName string) (string, error) {
	ctx := context.Background()
	id := uuid.New().String()

	_, err := s.db.Exec(
		ctx,
		`INSERT INTO accounts.accounts (
			id, user_id, type, name, description, institution_id, institution_name,
			external_account_id, balance_amount, balance_currency, is_active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
		)`,
		id, userID, "BROKERAGE", accountName, "E-Trade brokerage account",
		"etrade", "E-Trade", account.AccountID, account.Balance, account.Currency, true,
	)

	if err != nil {
		return "", err
	}

	return id, nil
}
