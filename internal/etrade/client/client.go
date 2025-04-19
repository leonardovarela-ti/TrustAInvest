package client

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"github.com/dghubble/oauth1"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/models"
)

const (
	// E-Trade API base URLs
	sandboxBaseURL    = "https://apisb.etrade.com"
	productionBaseURL = "https://api.etrade.com"

	// E-Trade API endpoints
	authRequestTokenEndpoint = "/oauth/request_token"
	authAccessTokenEndpoint  = "/oauth/access_token"
	accountListEndpoint      = "/v1/accounts/list"
	accountBalanceEndpoint   = "/v1/accounts/%s/balance"
	accountPositionsEndpoint = "/v1/accounts/%s/portfolio"

	// Default timeout for HTTP requests
	defaultTimeout = 30 * time.Second
)

// ETradeClient is a client for the E-Trade API
type ETradeClient struct {
	baseURL        string
	consumerKey    string
	consumerSecret string
	accessToken    string
	tokenSecret    string
	httpClient     *http.Client
	oauthConfig    *oauth1.Config
}

// NewETradeClient creates a new E-Trade API client
func NewETradeClient(consumerKey, consumerSecret string, useSandbox bool) *ETradeClient {
	baseURL := productionBaseURL
	if useSandbox {
		baseURL = sandboxBaseURL
	}

	config := oauth1.NewConfig(consumerKey, consumerSecret)
	config.Signer = &oauth1.HMAC256Signer{}

	return &ETradeClient{
		baseURL:        baseURL,
		consumerKey:    consumerKey,
		consumerSecret: consumerSecret,
		httpClient: &http.Client{
			Timeout: defaultTimeout,
		},
		oauthConfig: config,
	}
}

// SetCredentials sets the OAuth credentials for the client
func (c *ETradeClient) SetCredentials(accessToken, tokenSecret string) {
	c.accessToken = accessToken
	c.tokenSecret = tokenSecret
}

// GetAuthorizationURL generates an authorization URL for the user to authorize the application
func (c *ETradeClient) GetAuthorizationURL(callbackURL string) (string, string, error) {
	// Create the OAuth config with the provided callback URL
	config := oauth1.Config{
		ConsumerKey:    c.consumerKey,
		ConsumerSecret: c.consumerSecret,
		CallbackURL:    callbackURL,
		Endpoint: oauth1.Endpoint{
			RequestTokenURL: c.baseURL + authRequestTokenEndpoint,
			AuthorizeURL:    c.baseURL + "/authorize",
			AccessTokenURL:  c.baseURL + authAccessTokenEndpoint,
		},
	}

	// Get the request token
	requestToken, _, err := config.RequestToken()
	if err != nil {
		return "", "", fmt.Errorf("failed to get request token: %w", err)
	}

	// Generate the authorization URL
	authURL, err := config.AuthorizationURL(requestToken)
	if err != nil {
		return "", "", fmt.Errorf("failed to generate authorization URL: %w", err)
	}

	return requestToken, authURL.String(), nil
}

// ExchangeRequestTokenForAccessToken exchanges a request token for an access token
func (c *ETradeClient) ExchangeRequestTokenForAccessToken(requestToken, verifier string) (string, string, error) {
	// Create the access token URL
	accessTokenURL := c.baseURL + authAccessTokenEndpoint

	// Create a temporary token
	tempToken := oauth1.NewToken(requestToken, "")

	// Create an authenticated client
	httpClient := c.oauthConfig.Client(oauth1.NoContext, tempToken)

	// Add the verifier to the URL
	accessTokenURL = fmt.Sprintf("%s?oauth_verifier=%s", accessTokenURL, verifier)

	// Make the request
	resp, err := httpClient.Get(accessTokenURL)
	if err != nil {
		return "", "", fmt.Errorf("failed to exchange request token: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", fmt.Errorf("failed to read response body: %w", err)
	}

	// Parse the response
	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("failed to exchange request token: %s", string(body))
	}

	// Parse the query string
	values, err := url.ParseQuery(string(body))
	if err != nil {
		return "", "", fmt.Errorf("failed to parse response: %w", err)
	}

	// Extract the access token and secret
	accessToken := values.Get("oauth_token")
	tokenSecret := values.Get("oauth_token_secret")

	if accessToken == "" || tokenSecret == "" {
		return "", "", errors.New("access token or token secret not found in response")
	}

	// Set the credentials in the client
	c.SetCredentials(accessToken, tokenSecret)

	return accessToken, tokenSecret, nil
}

// GetAccounts retrieves the list of accounts for the authenticated user
func (c *ETradeClient) GetAccounts() ([]models.ETradeAccount, error) {
	// Check if we have credentials
	if c.accessToken == "" || c.tokenSecret == "" {
		return nil, errors.New("client not authenticated")
	}

	// Create the URL
	accountsURL := c.baseURL + accountListEndpoint

	// Create an authenticated client
	token := oauth1.NewToken(c.accessToken, c.tokenSecret)
	httpClient := c.oauthConfig.Client(oauth1.NoContext, token)

	// Make the request
	resp, err := httpClient.Get(accountsURL)
	if err != nil {
		return nil, fmt.Errorf("failed to get accounts: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// Parse the response
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get accounts: %s", string(body))
	}

	// Parse the JSON response
	var response struct {
		AccountListResponse struct {
			Accounts struct {
				Account []struct {
					AccountID   string `json:"accountId"`
					AccountName string `json:"accountName"`
					AccountType string `json:"accountType"`
				} `json:"Account"`
			} `json:"Accounts"`
		} `json:"AccountListResponse"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to parse accounts response: %w", err)
	}

	// Convert to our model
	accounts := make([]models.ETradeAccount, 0, len(response.AccountListResponse.Accounts.Account))
	for _, account := range response.AccountListResponse.Accounts.Account {
		accounts = append(accounts, models.ETradeAccount{
			AccountID:       account.AccountID,
			AccountName:     account.AccountName,
			AccountType:     account.AccountType,
			InstitutionID:   "etrade",
			InstitutionName: "E-Trade",
			Status:          "active",
			LastUpdated:     time.Now(),
		})
	}

	// Get additional details for each account
	for i := range accounts {
		// Get account balance
		if err := c.enrichAccountWithBalance(&accounts[i]); err != nil {
			// Log the error but continue with other accounts
			fmt.Printf("Failed to get balance for account %s: %v\n", accounts[i].AccountID, err)
		}

		// Get account positions
		if err := c.enrichAccountWithPositions(&accounts[i]); err != nil {
			// Log the error but continue with other accounts
			fmt.Printf("Failed to get positions for account %s: %v\n", accounts[i].AccountID, err)
		}
	}

	return accounts, nil
}

// enrichAccountWithBalance adds balance information to an account
func (c *ETradeClient) enrichAccountWithBalance(account *models.ETradeAccount) error {
	// Create the URL
	balanceURL := c.baseURL + fmt.Sprintf(accountBalanceEndpoint, account.AccountID)

	// Create an authenticated client
	token := oauth1.NewToken(c.accessToken, c.tokenSecret)
	httpClient := c.oauthConfig.Client(oauth1.NoContext, token)

	// Make the request
	resp, err := httpClient.Get(balanceURL)
	if err != nil {
		return fmt.Errorf("failed to get account balance: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response body: %w", err)
	}

	// Parse the response
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to get account balance: %s", string(body))
	}

	// Parse the JSON response
	var response struct {
		BalanceResponse struct {
			AccountBalance struct {
				NetAccountValue float64 `json:"netAccountValue"`
				Currency        string  `json:"currency"`
			} `json:"accountBalance"`
		} `json:"BalanceResponse"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return fmt.Errorf("failed to parse balance response: %w", err)
	}

	// Update the account
	account.Balance = response.BalanceResponse.AccountBalance.NetAccountValue
	account.Currency = response.BalanceResponse.AccountBalance.Currency

	return nil
}

// enrichAccountWithPositions adds position information to an account
func (c *ETradeClient) enrichAccountWithPositions(account *models.ETradeAccount) error {
	// Create the URL
	positionsURL := c.baseURL + fmt.Sprintf(accountPositionsEndpoint, account.AccountID)

	// Create an authenticated client
	token := oauth1.NewToken(c.accessToken, c.tokenSecret)
	httpClient := c.oauthConfig.Client(oauth1.NoContext, token)

	// Make the request
	resp, err := httpClient.Get(positionsURL)
	if err != nil {
		return fmt.Errorf("failed to get account positions: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read response body: %w", err)
	}

	// Parse the response
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to get account positions: %s", string(body))
	}

	// Parse the JSON response
	var response struct {
		PortfolioResponse struct {
			AccountPortfolio struct {
				Position []struct {
					PositionDetails struct {
						Symbol       string  `json:"symbol"`
						Quantity     float64 `json:"quantity"`
						CostBasis    float64 `json:"costBasis"`
						MarketValue  float64 `json:"marketValue"`
						TotalGain    float64 `json:"totalGain"`
						TotalGainPct float64 `json:"totalGainPct"`
					} `json:"positionDetails"`
					Quote struct {
						LastPrice     float64 `json:"lastPrice"`
						LastTradeTime string  `json:"lastTradeTime"`
					} `json:"quote"`
				} `json:"Position"`
			} `json:"accountPortfolio"`
		} `json:"PortfolioResponse"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return fmt.Errorf("failed to parse positions response: %w", err)
	}

	// Convert to our model
	positions := make([]models.ETradePosition, 0, len(response.PortfolioResponse.AccountPortfolio.Position))
	for _, position := range response.PortfolioResponse.AccountPortfolio.Position {
		// Parse the last trade time
		lastTradeTime, err := time.Parse(time.RFC3339, position.Quote.LastTradeTime)
		if err != nil {
			// Use current time if parsing fails
			lastTradeTime = time.Now()
		}

		positions = append(positions, models.ETradePosition{
			Symbol:        position.PositionDetails.Symbol,
			Quantity:      position.PositionDetails.Quantity,
			CostBasis:     position.PositionDetails.CostBasis,
			MarketValue:   position.PositionDetails.MarketValue,
			GainLoss:      position.PositionDetails.TotalGain,
			GainLossPerc:  position.PositionDetails.TotalGainPct,
			LastPrice:     position.Quote.LastPrice,
			LastPriceTime: lastTradeTime,
		})
	}

	// Update the account
	account.AccountPositions = positions

	return nil
}
