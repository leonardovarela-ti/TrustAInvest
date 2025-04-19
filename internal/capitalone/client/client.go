package client

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/models"
)

const (
	// Capital One API base URLs
	sandboxBaseURL    = "https://api-sandbox.capitalone.com"
	productionBaseURL = "https://api.capitalone.com"

	// Capital One API endpoints
	authEndpoint           = "/oauth2/authorize"
	tokenEndpoint          = "/oauth2/token"
	accountsEndpoint       = "/accounts"
	accountDetailsEndpoint = "/accounts/%s"
	transactionsEndpoint   = "/accounts/%s/transactions"
	investmentsEndpoint    = "/investments/accounts/%s/positions"
	bankProductsEndpoint   = "/deposits/products/%s/search"

	// Default timeout for HTTP requests
	defaultTimeout = 30 * time.Second
)

// CapitalOneClient is a client for the Capital One API
type CapitalOneClient struct {
	baseURL      string
	clientID     string
	clientSecret string
	accessToken  string
	refreshToken string
	expiresAt    time.Time
	httpClient   *http.Client
}

// NewCapitalOneClient creates a new Capital One API client
func NewCapitalOneClient(clientID, clientSecret string, useSandbox bool) *CapitalOneClient {
	baseURL := productionBaseURL
	if useSandbox {
		baseURL = sandboxBaseURL
	}

	return &CapitalOneClient{
		baseURL:      baseURL,
		clientID:     clientID,
		clientSecret: clientSecret,
		httpClient: &http.Client{
			Timeout: defaultTimeout,
		},
	}
}

// SetCredentials sets the OAuth credentials for the client
func (c *CapitalOneClient) SetCredentials(accessToken, refreshToken string, expiresIn int) {
	c.accessToken = accessToken
	c.refreshToken = refreshToken
	c.expiresAt = time.Now().Add(time.Duration(expiresIn) * time.Second)
}

// GetAuthorizationURL generates an authorization URL for the user to authorize the application
func (c *CapitalOneClient) GetAuthorizationURL(redirectURI string) (string, string, error) {
	// Generate a random state parameter to prevent CSRF
	state := uuid.New().String()

	// Build the authorization URL
	authURL, err := url.Parse(c.baseURL + authEndpoint)
	if err != nil {
		return "", "", fmt.Errorf("failed to parse authorization URL: %w", err)
	}

	// Add query parameters
	q := authURL.Query()
	q.Add("client_id", c.clientID)
	q.Add("response_type", "code")
	q.Add("redirect_uri", redirectURI)
	q.Add("state", state)
	q.Add("scope", "accounts transactions investments")
	authURL.RawQuery = q.Encode()

	return state, authURL.String(), nil
}

// ExchangeCodeForToken exchanges an authorization code for an access token
func (c *CapitalOneClient) ExchangeCodeForToken(code, redirectURI string) (string, string, int, error) {
	// Create the token URL
	tokenURL := c.baseURL + tokenEndpoint

	// Create the request body
	data := url.Values{}
	data.Set("grant_type", "authorization_code")
	data.Set("code", code)
	data.Set("redirect_uri", redirectURI)
	data.Set("client_id", c.clientID)
	data.Set("client_secret", c.clientSecret)

	// Create the request
	req, err := http.NewRequest("POST", tokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to create token request: %w", err)
	}
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to send token request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to read token response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return "", "", 0, fmt.Errorf("token request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the response
	var tokenResp models.CapitalOneTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return "", "", 0, fmt.Errorf("failed to parse token response: %w", err)
	}

	// Set the credentials in the client
	c.SetCredentials(tokenResp.AccessToken, tokenResp.RefreshToken, tokenResp.ExpiresIn)

	return tokenResp.AccessToken, tokenResp.RefreshToken, tokenResp.ExpiresIn, nil
}

// RefreshAccessToken refreshes the access token using the refresh token
func (c *CapitalOneClient) RefreshAccessToken() (string, string, int, error) {
	// Check if we have a refresh token
	if c.refreshToken == "" {
		return "", "", 0, errors.New("no refresh token available")
	}

	// Create the token URL
	tokenURL := c.baseURL + tokenEndpoint

	// Create the request body
	data := url.Values{}
	data.Set("grant_type", "refresh_token")
	data.Set("refresh_token", c.refreshToken)
	data.Set("client_id", c.clientID)
	data.Set("client_secret", c.clientSecret)

	// Create the request
	req, err := http.NewRequest("POST", tokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to create refresh token request: %w", err)
	}
	req.Header.Add("Content-Type", "application/x-www-form-urlencoded")

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to send refresh token request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", 0, fmt.Errorf("failed to read refresh token response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return "", "", 0, fmt.Errorf("refresh token request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the response
	var tokenResp models.CapitalOneTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return "", "", 0, fmt.Errorf("failed to parse refresh token response: %w", err)
	}

	// Set the credentials in the client
	c.SetCredentials(tokenResp.AccessToken, tokenResp.RefreshToken, tokenResp.ExpiresIn)

	return tokenResp.AccessToken, tokenResp.RefreshToken, tokenResp.ExpiresIn, nil
}

// ensureValidToken ensures that the access token is valid, refreshing it if necessary
func (c *CapitalOneClient) ensureValidToken() error {
	// Check if the token is expired or about to expire (within 5 minutes)
	if time.Now().Add(5 * time.Minute).After(c.expiresAt) {
		// Token is expired or about to expire, refresh it
		_, _, _, err := c.RefreshAccessToken()
		if err != nil {
			return fmt.Errorf("failed to refresh access token: %w", err)
		}
	}
	return nil
}

// GetAccounts retrieves the list of accounts for the authenticated user
func (c *CapitalOneClient) GetAccounts() ([]models.CapitalOneAccount, error) {
	// Ensure we have a valid token
	if err := c.ensureValidToken(); err != nil {
		return nil, err
	}

	// Create the URL
	accountsURL := c.baseURL + accountsEndpoint

	// Create the request
	req, err := http.NewRequest("GET", accountsURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create accounts request: %w", err)
	}
	req.Header.Add("Authorization", "Bearer "+c.accessToken)
	req.Header.Add("Accept", "application/json")

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send accounts request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read accounts response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("accounts request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the JSON response
	var response struct {
		Accounts []struct {
			AccountID   string  `json:"accountId"`
			AccountName string  `json:"accountName"`
			AccountType string  `json:"accountType"`
			Balance     float64 `json:"balance"`
			Currency    string  `json:"currency"`
		} `json:"accounts"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to parse accounts response: %w", err)
	}

	// Convert to our model
	accounts := make([]models.CapitalOneAccount, 0, len(response.Accounts))
	for _, account := range response.Accounts {
		accounts = append(accounts, models.CapitalOneAccount{
			AccountID:       account.AccountID,
			AccountName:     account.AccountName,
			AccountType:     account.AccountType,
			InstitutionID:   "capitalone",
			InstitutionName: "Capital One",
			Balance:         account.Balance,
			Currency:        account.Currency,
			Status:          "active",
			LastUpdated:     time.Now(),
		})
	}

	// Get additional details for each account
	for i := range accounts {
		// Get account transactions
		if err := c.enrichAccountWithTransactions(&accounts[i]); err != nil {
			// Log the error but continue with other accounts
			fmt.Printf("Failed to get transactions for account %s: %v\n", accounts[i].AccountID, err)
		}

		// If it's an investment account, get positions
		if accounts[i].AccountType == "INVESTMENT" {
			if err := c.enrichAccountWithPositions(&accounts[i]); err != nil {
				// Log the error but continue with other accounts
				fmt.Printf("Failed to get positions for account %s: %v\n", accounts[i].AccountID, err)
			}
		}
	}

	return accounts, nil
}

// enrichAccountWithTransactions adds transaction information to an account
func (c *CapitalOneClient) enrichAccountWithTransactions(account *models.CapitalOneAccount) error {
	// Ensure we have a valid token
	if err := c.ensureValidToken(); err != nil {
		return err
	}

	// Create the URL
	transactionsURL := c.baseURL + fmt.Sprintf(transactionsEndpoint, account.AccountID)

	// Create the request
	req, err := http.NewRequest("GET", transactionsURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create transactions request: %w", err)
	}
	req.Header.Add("Authorization", "Bearer "+c.accessToken)
	req.Header.Add("Accept", "application/json")

	// Add query parameters for date range (last 30 days)
	q := req.URL.Query()
	q.Add("startDate", time.Now().AddDate(0, 0, -30).Format("2006-01-02"))
	q.Add("endDate", time.Now().Format("2006-01-02"))
	req.URL.RawQuery = q.Encode()

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send transactions request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read transactions response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("transactions request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the JSON response
	var response struct {
		Transactions []struct {
			TransactionID   string  `json:"transactionId"`
			TransactionDate string  `json:"transactionDate"`
			PostDate        string  `json:"postDate"`
			Description     string  `json:"description"`
			Category        string  `json:"category"`
			Amount          float64 `json:"amount"`
			Type            string  `json:"type"`
			Status          string  `json:"status"`
		} `json:"transactions"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return fmt.Errorf("failed to parse transactions response: %w", err)
	}

	// Convert to our model
	transactions := make([]models.CapitalOneTransaction, 0, len(response.Transactions))
	for _, tx := range response.Transactions {
		// Parse dates
		transactionDate, err := time.Parse("2006-01-02", tx.TransactionDate)
		if err != nil {
			// Use current time if parsing fails
			transactionDate = time.Now()
		}

		postDate, err := time.Parse("2006-01-02", tx.PostDate)
		if err != nil {
			// Use transaction date if parsing fails
			postDate = transactionDate
		}

		transactions = append(transactions, models.CapitalOneTransaction{
			TransactionID:   tx.TransactionID,
			TransactionDate: transactionDate,
			PostDate:        postDate,
			Description:     tx.Description,
			Category:        tx.Category,
			Amount:          tx.Amount,
			Type:            tx.Type,
			Status:          tx.Status,
		})
	}

	// Update the account
	account.Transactions = transactions

	return nil
}

// enrichAccountWithPositions adds position information to an investment account
func (c *CapitalOneClient) enrichAccountWithPositions(account *models.CapitalOneAccount) error {
	// Ensure we have a valid token
	if err := c.ensureValidToken(); err != nil {
		return err
	}

	// Create the URL
	positionsURL := c.baseURL + fmt.Sprintf(investmentsEndpoint, account.AccountID)

	// Create the request
	req, err := http.NewRequest("GET", positionsURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create positions request: %w", err)
	}
	req.Header.Add("Authorization", "Bearer "+c.accessToken)
	req.Header.Add("Accept", "application/json")

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send positions request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("failed to read positions response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("positions request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the JSON response
	var response struct {
		Positions []struct {
			Symbol        string  `json:"symbol"`
			Quantity      float64 `json:"quantity"`
			CostBasis     float64 `json:"costBasis"`
			MarketValue   float64 `json:"marketValue"`
			GainLoss      float64 `json:"gainLoss"`
			GainLossPerc  float64 `json:"gainLossPerc"`
			LastPrice     float64 `json:"lastPrice"`
			LastPriceTime string  `json:"lastPriceTime"`
		} `json:"positions"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return fmt.Errorf("failed to parse positions response: %w", err)
	}

	// Convert to our model
	positions := make([]models.CapitalOnePosition, 0, len(response.Positions))
	for _, position := range response.Positions {
		// Parse the last price time
		lastPriceTime, err := time.Parse(time.RFC3339, position.LastPriceTime)
		if err != nil {
			// Use current time if parsing fails
			lastPriceTime = time.Now()
		}

		positions = append(positions, models.CapitalOnePosition{
			Symbol:        position.Symbol,
			Quantity:      position.Quantity,
			CostBasis:     position.CostBasis,
			MarketValue:   position.MarketValue,
			GainLoss:      position.GainLoss,
			GainLossPerc:  position.GainLossPerc,
			LastPrice:     position.LastPrice,
			LastPriceTime: lastPriceTime,
		})
	}

	// Update the account
	account.AccountPositions = positions

	return nil
}

// GetAccountDetails retrieves detailed information for a specific account
func (c *CapitalOneClient) GetAccountDetails(accountID string) (*models.CapitalOneAccount, error) {
	// Ensure we have a valid token
	if err := c.ensureValidToken(); err != nil {
		return nil, err
	}

	// Create the URL
	accountURL := c.baseURL + fmt.Sprintf(accountDetailsEndpoint, accountID)

	// Create the request
	req, err := http.NewRequest("GET", accountURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create account details request: %w", err)
	}
	req.Header.Add("Authorization", "Bearer "+c.accessToken)
	req.Header.Add("Accept", "application/json")

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send account details request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read account details response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("account details request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the JSON response
	var response struct {
		Account struct {
			AccountID   string  `json:"accountId"`
			AccountName string  `json:"accountName"`
			AccountType string  `json:"accountType"`
			Balance     float64 `json:"balance"`
			Currency    string  `json:"currency"`
		} `json:"account"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to parse account details response: %w", err)
	}

	// Convert to our model
	account := &models.CapitalOneAccount{
		AccountID:       response.Account.AccountID,
		AccountName:     response.Account.AccountName,
		AccountType:     response.Account.AccountType,
		InstitutionID:   "capitalone",
		InstitutionName: "Capital One",
		Balance:         response.Account.Balance,
		Currency:        response.Account.Currency,
		Status:          "active",
		LastUpdated:     time.Now(),
	}

	// Get account transactions
	if err := c.enrichAccountWithTransactions(account); err != nil {
		// Log the error but continue
		fmt.Printf("Failed to get transactions for account %s: %v\n", account.AccountID, err)
	}

	// If it's an investment account, get positions
	if account.AccountType == "INVESTMENT" {
		if err := c.enrichAccountWithPositions(account); err != nil {
			// Log the error but continue
			fmt.Printf("Failed to get positions for account %s: %v\n", account.AccountID, err)
		}
	}

	return account, nil
}

// SearchBankProducts searches for bank products based on the provided criteria
func (c *CapitalOneClient) SearchBankProducts(productID string, searchRequest *models.BankProductSearchRequest) (*models.BankProductSearchResponse, error) {
	// Create the URL
	productsURL := c.baseURL + fmt.Sprintf(bankProductsEndpoint, productID)

	// Create the request body
	reqBody, err := json.Marshal(searchRequest)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal search request: %w", err)
	}

	// Create the request
	req, err := http.NewRequest("POST", productsURL, bytes.NewBuffer(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create bank products request: %w", err)
	}
	req.Header.Add("Content-Type", "application/json")
	req.Header.Add("Accept", "application/json")

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send bank products request: %w", err)
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read bank products response: %w", err)
	}

	// Check the response status code
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bank products request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Parse the JSON response
	var response models.BankProductSearchResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to parse bank products response: %w", err)
	}

	return &response, nil
}
