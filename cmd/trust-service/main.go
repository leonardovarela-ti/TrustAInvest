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

// Trust represents a legal trust
type Trust struct {
	ID            string     `json:"id"`
	Name          string     `json:"name"`
	Type          string     `json:"type"`
	Status        string     `json:"status"`
	CreatorUserID string     `json:"creator_user_id"`
	DocumentID    string     `json:"document_id,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
	ActivatedAt   *time.Time `json:"activated_at,omitempty"`
}

// Trustee represents a trustee on a trust
type Trustee struct {
	ID       string     `json:"id"`
	TrustID  string     `json:"trust_id"`
	UserID   string     `json:"user_id,omitempty"`
	Name     string     `json:"name"`
	Email    string     `json:"email"`
	Phone    string     `json:"phone,omitempty"`
	IsActive bool       `json:"is_active"`
	SignedAt *time.Time `json:"signed_at,omitempty"`
}

var db *pgxpool.Pool

func main() {
	log.Println("Starting trust-service...")

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
			"service": "trust-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		trusts := v1.Group("/trusts")
		{
			trusts.GET("", listTrusts)
			trusts.GET("/:id", getTrustByID)
			trusts.POST("", createTrust)
			trusts.PUT("/:id", updateTrust)
			trusts.DELETE("/:id", deleteTrust)

			// Trustees
			trusts.GET("/:id/trustees", getTrustees)
			trusts.POST("/:id/trustees", addTrustee)
			trusts.PUT("/:id/trustees/:trusteeId", updateTrustee)
			trusts.DELETE("/:id/trustees/:trusteeId", removeTrustee)

			// Accounts
			trusts.POST("/:id/accounts", linkAccount)
			trusts.DELETE("/:id/accounts/:accountId", unlinkAccount)

			// Trust actions
			trusts.POST("/:id/activate", activateTrust)
		}

		userTrusts := v1.Group("/users/:userId/trusts")
		{
			userTrusts.GET("", getUserTrusts)
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
	log.Println("Shutting down trust-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Trust service stopped")
}

// Handler functions
func listTrusts(c *gin.Context) {
	var trusts []Trust
	rows, err := db.Query(context.Background(), `
		SELECT id, name, type, status, creator_user_id, document_id, 
		       created_at, updated_at, activated_at
		FROM trusts.trusts
		WHERE status != 'INACTIVE'
		LIMIT 100
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve trusts"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var trust Trust
		err := rows.Scan(
			&trust.ID, &trust.Name, &trust.Type, &trust.Status, &trust.CreatorUserID,
			&trust.DocumentID, &trust.CreatedAt, &trust.UpdatedAt, &trust.ActivatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan trust data"})
			return
		}
		trusts = append(trusts, trust)
	}

	c.JSON(http.StatusOK, gin.H{"trusts": trusts})
}

func getTrustByID(c *gin.Context) {
	id := c.Param("id")
	var trust Trust

	err := db.QueryRow(context.Background(), `
		SELECT id, name, type, status, creator_user_id, document_id, 
		       created_at, updated_at, activated_at
		FROM trusts.trusts
		WHERE id = $1 AND status != 'INACTIVE'
	`, id).Scan(
		&trust.ID, &trust.Name, &trust.Type, &trust.Status, &trust.CreatorUserID,
		&trust.DocumentID, &trust.CreatedAt, &trust.UpdatedAt, &trust.ActivatedAt,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trust not found"})
		return
	}

	c.JSON(http.StatusOK, trust)
}

func getUserTrusts(c *gin.Context) {
	userID := c.Param("userId")
	var trusts []Trust

	rows, err := db.Query(context.Background(), `
		SELECT id, name, type, status, creator_user_id, document_id, 
		       created_at, updated_at, activated_at
		FROM trusts.trusts
		WHERE creator_user_id = $1 AND status != 'INACTIVE'
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve user trusts"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var trust Trust
		err := rows.Scan(
			&trust.ID, &trust.Name, &trust.Type, &trust.Status, &trust.CreatorUserID,
			&trust.DocumentID, &trust.CreatedAt, &trust.UpdatedAt, &trust.ActivatedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan trust data"})
			return
		}
		trusts = append(trusts, trust)
	}

	c.JSON(http.StatusOK, gin.H{"trusts": trusts})
}

func createTrust(c *gin.Context) {
	var input struct {
		Name          string `json:"name" binding:"required"`
		Type          string `json:"type" binding:"required"`
		CreatorUserID string `json:"creator_user_id" binding:"required"`
		DocumentID    string `json:"document_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate if user exists
	var userExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
	`, input.CreatorUserID).Scan(&userExists)

	if err != nil || !userExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
		return
	}

	id := uuid.New().String()

	_, err = db.Exec(context.Background(), `
		INSERT INTO trusts.trusts (
			id, name, type, status, creator_user_id, document_id
		) VALUES (
			$1, $2, $3, $4, $5, $6
		)
	`, id, input.Name, input.Type, "DRAFT", input.CreatorUserID, input.DocumentID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create trust: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Trust created successfully",
	})
}

func updateTrust(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Name       string `json:"name"`
		Type       string `json:"type"`
		Status     string `json:"status"`
		DocumentID string `json:"document_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// First check if trust exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM trusts.trusts WHERE id = $1 AND status != 'INACTIVE')
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trust not found"})
		return
	}

	// Perform update
	_, err = db.Exec(context.Background(), `
		UPDATE trusts.trusts
		SET 
			name = COALESCE(NULLIF($1, ''), name),
			type = COALESCE(NULLIF($2, ''), type),
			status = COALESCE(NULLIF($3, ''), status),
			document_id = COALESCE(NULLIF($4, ''), document_id),
			updated_at = NOW()
		WHERE id = $5 AND status != 'INACTIVE'
	`, input.Name, input.Type, input.Status, input.DocumentID, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update trust: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Trust updated successfully"})
}

func deleteTrust(c *gin.Context) {
	id := c.Param("id")

	result, err := db.Exec(context.Background(), `
		UPDATE trusts.trusts
		SET status = 'INACTIVE', updated_at = NOW()
		WHERE id = $1 AND status != 'INACTIVE'
	`, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete trust: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trust not found"})
		return
	}

	c.Status(http.StatusNoContent)
}

func getTrustees(c *gin.Context) {
	trustID := c.Param("id")
	var trustees []Trustee

	rows, err := db.Query(context.Background(), `
		SELECT id, trust_id, user_id, name, email, phone, is_active, signed_at
		FROM trusts.trustees
		WHERE trust_id = $1 AND is_active = true
	`, trustID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve trustees"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var trustee Trustee
		err := rows.Scan(
			&trustee.ID, &trustee.TrustID, &trustee.UserID, &trustee.Name,
			&trustee.Email, &trustee.Phone, &trustee.IsActive, &trustee.SignedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan trustee data"})
			return
		}
		trustees = append(trustees, trustee)
	}

	c.JSON(http.StatusOK, gin.H{"trustees": trustees})
}

func addTrustee(c *gin.Context) {
	trustID := c.Param("id")

	var input struct {
		UserID string `json:"user_id"`
		Name   string `json:"name" binding:"required"`
		Email  string `json:"email" binding:"required"`
		Phone  string `json:"phone"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if trust exists
	var trustExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM trusts.trusts WHERE id = $1 AND status != 'INACTIVE')
	`, trustID).Scan(&trustExists)

	if err != nil || !trustExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Trust not found"})
		return
	}

	id := uuid.New().String()

	_, err = db.Exec(context.Background(), `
		INSERT INTO trusts.trustees (
			id, trust_id, user_id, name, email, phone, is_active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
	`, id, trustID, input.UserID, input.Name, input.Email, input.Phone, true)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add trustee: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Trustee added successfully",
	})
}

func updateTrustee(c *gin.Context) {
	trustID := c.Param("id")
	trusteeID := c.Param("trusteeId")

	var input struct {
		Name  string `json:"name"`
		Email string `json:"email"`
		Phone string `json:"phone"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if trustee exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM trusts.trustees WHERE id = $1 AND trust_id = $2 AND is_active = true)
	`, trusteeID, trustID).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trustee not found"})
		return
	}

	_, err = db.Exec(context.Background(), `
		UPDATE trusts.trustees
		SET 
			name = COALESCE(NULLIF($1, ''), name),
			email = COALESCE(NULLIF($2, ''), email),
			phone = COALESCE(NULLIF($3, ''), phone)
		WHERE id = $4 AND trust_id = $5 AND is_active = true
	`, input.Name, input.Email, input.Phone, trusteeID, trustID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update trustee: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Trustee updated successfully"})
}

func removeTrustee(c *gin.Context) {
	trustID := c.Param("id")
	trusteeID := c.Param("trusteeId")

	result, err := db.Exec(context.Background(), `
		UPDATE trusts.trustees
		SET is_active = false
		WHERE id = $1 AND trust_id = $2 AND is_active = true
	`, trusteeID, trustID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove trustee: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trustee not found"})
		return
	}

	c.Status(http.StatusNoContent)
}

func linkAccount(c *gin.Context) {
	trustID := c.Param("id")

	var input struct {
		AccountID string `json:"account_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if trust exists
	var trustExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM trusts.trusts WHERE id = $1 AND status != 'INACTIVE')
	`, trustID).Scan(&trustExists)

	if err != nil || !trustExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Trust not found"})
		return
	}

	// Check if account exists
	var accountExists bool
	err = db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM accounts.accounts WHERE id = $1 AND is_active = true)
	`, input.AccountID).Scan(&accountExists)

	if err != nil || !accountExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Account not found"})
		return
	}

	// Link account to trust
	_, err = db.Exec(context.Background(), `
		INSERT INTO trusts.trust_accounts (trust_id, account_id)
		VALUES ($1, $2)
		ON CONFLICT (trust_id, account_id) DO NOTHING
	`, trustID, input.AccountID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to link account: " + err.Error()})
		return
	}

	// Update account to reference trust
	_, err = db.Exec(context.Background(), `
		UPDATE accounts.accounts
		SET trust_id = $1, updated_at = NOW()
		WHERE id = $2
	`, trustID, input.AccountID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update account trust reference: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Account linked to trust successfully"})
}

func unlinkAccount(c *gin.Context) {
	trustID := c.Param("id")
	accountID := c.Param("accountId")

	// Remove link in trust_accounts table
	_, err := db.Exec(context.Background(), `
		DELETE FROM trusts.trust_accounts
		WHERE trust_id = $1 AND account_id = $2
	`, trustID, accountID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unlink account: " + err.Error()})
		return
	}

	// Update account to remove trust reference
	_, err = db.Exec(context.Background(), `
		UPDATE accounts.accounts
		SET trust_id = NULL, updated_at = NOW()
		WHERE id = $1 AND trust_id = $2
	`, accountID, trustID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update account trust reference: " + err.Error()})
		return
	}

	c.Status(http.StatusNoContent)
}

func activateTrust(c *gin.Context) {
	trustID := c.Param("id")

	// Check if trust exists and is in proper state
	var status string
	err := db.QueryRow(context.Background(), `
		SELECT status FROM trusts.trusts WHERE id = $1
	`, trustID).Scan(&status)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trust not found"})
		return
	}

	if status == "ACTIVE" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Trust is already active"})
		return
	}

	if status == "INACTIVE" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot activate an inactive trust"})
		return
	}

	// Activate the trust
	now := time.Now()
	_, err = db.Exec(context.Background(), `
		UPDATE trusts.trusts
		SET status = 'ACTIVE', activated_at = $1, updated_at = $1
		WHERE id = $2
	`, now, trustID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to activate trust: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Trust activated successfully"})
}
