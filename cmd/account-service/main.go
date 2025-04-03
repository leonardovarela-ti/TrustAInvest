package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
)

// Account represents a financial account
type Account struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	Type            string    `json:"type"`
	Name            string    `json:"name"`
	Description     string    `json:"description,omitempty"`
	InstitutionName string    `json:"institution_name,omitempty"`
	Balance         float64   `json:"balance"`
	Currency        string    `json:"currency"`
	IsActive        bool      `json:"is_active"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
	TrustID         *string   `json:"trust_id,omitempty"`
}

var db *pgxpool.Pool

func main() {
	log.Println("Starting account-service...")

	// Connect to database
	dbURL := "postgres://trustainvest:trustainvest@postgres:5432/trustainvest"
	var err error
	db, err = pgxpool.Connect(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer db.Close()

	// Verify database connection
	if err := db.Ping(context.Background()); err != nil {
		log.Fatalf("Unable to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Set up Gin router
	router := gin.Default()

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "account-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		accounts := v1.Group("/accounts")
		{
			accounts.GET("", listAccounts)
			accounts.GET("/:id", getAccountByID)
			accounts.POST("", createAccount)
			accounts.PUT("/:id", updateAccount)
			accounts.DELETE("/:id", deleteAccount)
		}

		userAccounts := v1.Group("/users/:userId/accounts")
		{
			userAccounts.GET("", getUserAccounts)
		}
	}

	// Start server
	srv := &http.Server{
		Addr:    ":8080",
		Handler: router,
	}

	// Run server in a goroutine
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shut down
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down account-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Account service stopped")
}

// Handler functions
func listAccounts(c *gin.Context) {
	var accounts []Account
	rows, err := db.Query(context.Background(), `
		SELECT id, user_id, type, name, description, institution_name, 
		       balance_amount, balance_currency, is_active, created_at, 
		       updated_at, trust_id
		FROM accounts.accounts
		WHERE is_active = true
		LIMIT 100
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve accounts"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var account Account
		err := rows.Scan(
			&account.ID, &account.UserID, &account.Type, &account.Name,
			&account.Description, &account.InstitutionName, &account.Balance,
			&account.Currency, &account.IsActive, &account.CreatedAt,
			&account.UpdatedAt, &account.TrustID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan account data"})
			return
		}
		accounts = append(accounts, account)
	}

	c.JSON(http.StatusOK, gin.H{"accounts": accounts})
}

func getAccountByID(c *gin.Context) {
	id := c.Param("id")
	var account Account

	err := db.QueryRow(context.Background(), `
		SELECT id, user_id, type, name, description, institution_name, 
		       balance_amount, balance_currency, is_active, created_at, 
		       updated_at, trust_id
		FROM accounts.accounts
		WHERE id = $1 AND is_active = true
	`, id).Scan(
		&account.ID, &account.UserID, &account.Type, &account.Name,
		&account.Description, &account.InstitutionName, &account.Balance,
		&account.Currency, &account.IsActive, &account.CreatedAt,
		&account.UpdatedAt, &account.TrustID,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Account not found"})
		return
	}

	c.JSON(http.StatusOK, account)
}

func getUserAccounts(c *gin.Context) {
	userID := c.Param("userId")
	var accounts []Account

	rows, err := db.Query(context.Background(), `
		SELECT id, user_id, type, name, description, institution_name, 
		       balance_amount, balance_currency, is_active, created_at, 
		       updated_at, trust_id
		FROM accounts.accounts
		WHERE user_id = $1 AND is_active = true
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve user accounts"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var account Account
		err := rows.Scan(
			&account.ID, &account.UserID, &account.Type, &account.Name,
			&account.Description, &account.InstitutionName, &account.Balance,
			&account.Currency, &account.IsActive, &account.CreatedAt,
			&account.UpdatedAt, &account.TrustID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan account data"})
			return
		}
		accounts = append(accounts, account)
	}

	c.JSON(http.StatusOK, gin.H{"accounts": accounts})
}

func createAccount(c *gin.Context) {
	var input struct {
		UserID          string  `json:"user_id" binding:"required"`
		Type            string  `json:"type" binding:"required"`
		Name            string  `json:"name" binding:"required"`
		Description     string  `json:"description"`
		InstitutionName string  `json:"institution_name"`
		Balance         float64 `json:"balance"`
		Currency        string  `json:"currency"`
		TrustID         string  `json:"trust_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate if user exists
	var userExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
	`, input.UserID).Scan(&userExists)

	if err != nil || !userExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
		return
	}

	id := uuid.New().String()
	currency := input.Currency
	if currency == "" {
		currency = "USD"
	}

	var trustID *string
	if input.TrustID != "" {
		trustID = &input.TrustID
	}

	_, err = db.Exec(context.Background(), `
		INSERT INTO accounts.accounts (
			id, user_id, type, name, description, institution_name, 
			balance_amount, balance_currency, is_active, trust_id
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10
		)
	`, id, input.UserID, input.Type, input.Name, input.Description,
		input.InstitutionName, input.Balance, currency, true, trustID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create account: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Account created successfully",
	})
}

func updateAccount(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Type            string  `json:"type"`
		Name            string  `json:"name"`
		Description     string  `json:"description"`
		InstitutionName string  `json:"institution_name"`
		Balance         float64 `json:"balance"`
		Currency        string  `json:"currency"`
		TrustID         string  `json:"trust_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// First check if account exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM accounts.accounts WHERE id = $1 AND is_active = true)
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Account not found"})
		return
	}

	var trustID *string
	if input.TrustID != "" {
		trustID = &input.TrustID
	}

	// Perform update
	_, err = db.Exec(context.Background(), `
		UPDATE accounts.accounts
		SET 
			type = COALESCE(NULLIF($1, ''), type),
			name = COALESCE(NULLIF($2, ''), name),
			description = COALESCE(NULLIF($3, ''), description),
			institution_name = COALESCE(NULLIF($4, ''), institution_name),
			balance_amount = CASE WHEN $5 <> 0 THEN $5 ELSE balance_amount END,
			balance_currency = COALESCE(NULLIF($6, ''), balance_currency),
			trust_id = $7,
			updated_at = NOW()
		WHERE id = $8 AND is_active = true
	`, input.Type, input.Name, input.Description, input.InstitutionName,
		input.Balance, input.Currency, trustID, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update account: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account updated successfully"})
}

func deleteAccount(c *gin.Context) {
	id := c.Param("id")

	result, err := db.Exec(context.Background(), `
		UPDATE accounts.accounts
		SET is_active = false, updated_at = NOW()
		WHERE id = $1 AND is_active = true
	`, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete account: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Account not found"})
		return
	}

	c.Status(http.StatusNoContent)
}
