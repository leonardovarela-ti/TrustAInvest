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

// User represents a user entity
type User struct {
	ID          string    `json:"id"`
	Username    string    `json:"username"`
	Email       string    `json:"email"`
	PhoneNumber string    `json:"phone_number,omitempty"`
	FirstName   string    `json:"first_name"`
	LastName    string    `json:"last_name"`
	DateOfBirth string    `json:"date_of_birth"`
	RiskProfile string    `json:"risk_profile,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
	KYCStatus   string    `json:"kyc_status"`
	IsActive    bool      `json:"is_active"`
}

// Global db connection
var db *pgxpool.Pool

func main() {
	log.Println("Starting user-service...")

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
			"service": "user-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		users := v1.Group("/users")
		{
			users.GET("", listUsers)
			users.GET("/:id", getUserByID)
			users.POST("", createUser)
			users.PUT("/:id", updateUser)
			users.DELETE("/:id", deleteUser)
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
	log.Println("Shutting down user-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("User service stopped")
}

// Handler functions
func listUsers(c *gin.Context) {
	var users []User
	rows, err := db.Query(context.Background(), `
		SELECT id, username, email, phone_number, first_name, last_name, 
		       date_of_birth, risk_profile, created_at, updated_at,
		       kyc_status, is_active
		FROM users.users
		WHERE is_active = true
		LIMIT 100
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve users"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var user User
		var dateOfBirth time.Time
		err := rows.Scan(
			&user.ID, &user.Username, &user.Email, &user.PhoneNumber,
			&user.FirstName, &user.LastName, &dateOfBirth, &user.RiskProfile,
			&user.CreatedAt, &user.UpdatedAt, &user.KYCStatus, &user.IsActive,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan user data"})
			return
		}
		user.DateOfBirth = dateOfBirth.Format("2006-01-02")
		users = append(users, user)
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}

func getUserByID(c *gin.Context) {
	id := c.Param("id")
	var user User
	var dateOfBirth time.Time

	err := db.QueryRow(context.Background(), `
		SELECT id, username, email, phone_number, first_name, last_name, 
		       date_of_birth, risk_profile, created_at, updated_at,
		       kyc_status, is_active
		FROM users.users
		WHERE id = $1 AND is_active = true
	`, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PhoneNumber,
		&user.FirstName, &user.LastName, &dateOfBirth, &user.RiskProfile,
		&user.CreatedAt, &user.UpdatedAt, &user.KYCStatus, &user.IsActive,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	user.DateOfBirth = dateOfBirth.Format("2006-01-02")
	c.JSON(http.StatusOK, user)
}

func createUser(c *gin.Context) {
	var input struct {
		Username    string `json:"username" binding:"required"`
		Email       string `json:"email" binding:"required"`
		PhoneNumber string `json:"phone_number"`
		FirstName   string `json:"first_name" binding:"required"`
		LastName    string `json:"last_name" binding:"required"`
		DateOfBirth string `json:"date_of_birth" binding:"required"`
		RiskProfile string `json:"risk_profile"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	id := uuid.New().String()

	_, err := db.Exec(context.Background(), `
		INSERT INTO users.users (
			id, username, email, phone_number, first_name, last_name, 
			date_of_birth, risk_profile, kyc_status, is_active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10
		)
	`, id, input.Username, input.Email, input.PhoneNumber, input.FirstName,
		input.LastName, input.DateOfBirth, input.RiskProfile, "PENDING", false)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "User created successfully",
	})
}

func updateUser(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Username    string `json:"username"`
		Email       string `json:"email"`
		PhoneNumber string `json:"phone_number"`
		FirstName   string `json:"first_name"`
		LastName    string `json:"last_name"`
		DateOfBirth string `json:"date_of_birth"`
		RiskProfile string `json:"risk_profile"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// First check if user exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Perform update
	_, err = db.Exec(context.Background(), `
		UPDATE users.users
		SET 
			username = COALESCE(NULLIF($1, ''), username),
			email = COALESCE(NULLIF($2, ''), email),
			phone_number = COALESCE(NULLIF($3, ''), phone_number),
			first_name = COALESCE(NULLIF($4, ''), first_name),
			last_name = COALESCE(NULLIF($5, ''), last_name),
			date_of_birth = COALESCE(NULLIF($6, '')::date, date_of_birth),
			risk_profile = COALESCE(NULLIF($7, ''), risk_profile),
			updated_at = NOW()
		WHERE id = $8 AND is_active = true
	`, input.Username, input.Email, input.PhoneNumber, input.FirstName,
		input.LastName, input.DateOfBirth, input.RiskProfile, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "User updated successfully"})
}

func deleteUser(c *gin.Context) {
	id := c.Param("id")

	result, err := db.Exec(context.Background(), `
		UPDATE users.users
		SET is_active = false, updated_at = NOW()
		WHERE id = $1 AND is_active = true
	`, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.Status(http.StatusNoContent)
}
