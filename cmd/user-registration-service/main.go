package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// User represents a user entity during registration
type User struct {
	ID           string  `json:"id,omitempty"`
	Username     string  `json:"username" binding:"required"`
	Email        string  `json:"email" binding:"required"`
	Password     string  `json:"password" binding:"required"`
	PhoneNumber  string  `json:"phone_number,omitempty"`
	FirstName    string  `json:"first_name" binding:"required"`
	LastName     string  `json:"last_name" binding:"required"`
	DateOfBirth  string  `json:"date_of_birth" binding:"required"`
	Address      Address `json:"address"`
	RiskProfile  string  `json:"risk_profile,omitempty"`
	DeviceID     string  `json:"device_id,omitempty"`
	AcceptTerms  bool    `json:"accept_terms" binding:"required"`
	ReferralCode string  `json:"referral_code,omitempty"`
}

// Address represents a physical address
type Address struct {
	Street  string `json:"street"`
	City    string `json:"city"`
	State   string `json:"state"`
	ZipCode string `json:"zip_code"`
	Country string `json:"country"`
}

// ValidationError represents a validation error
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// Global db connection
var db *pgxpool.Pool

func main() {
	log.Println("Starting user-registration-service...")

	// Connect to database
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://trustainvest:trustainvest@postgres:5432/trustainvest"
	}

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
			"service": "user-registration-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		v1.POST("/register", registerUser)
		v1.POST("/verify-email", verifyEmail)
		v1.POST("/resend-verification", resendVerification)
		v1.POST("/check-username", checkUsername)
		v1.POST("/check-email", checkEmail)
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
	log.Println("Shutting down user-registration-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("User registration service stopped")
}

// registerUser handles new user registration
func registerUser(c *gin.Context) {
	var user User
	if err := c.ShouldBindJSON(&user); err != nil {
		// Check for specific field validation errors and provide user-friendly messages
		errStr := err.Error()
		if strings.Contains(errStr, "User.FirstName") && strings.Contains(errStr, "required") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "First name cannot be empty"})
			return
		}
		if strings.Contains(errStr, "User.LastName") && strings.Contains(errStr, "required") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Last name cannot be empty"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Additional check for whitespace-only first_name
	if len(strings.TrimSpace(user.FirstName)) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "First name cannot be empty"})
		return
	}

	// Additional check for whitespace-only last_name
	if len(strings.TrimSpace(user.LastName)) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Last name cannot be empty"})
		return
	}

	// Validate user input
	errors := validateUser(user)
	if len(errors) > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"errors": errors})
		return
	}

	// Check if terms are accepted
	if !user.AcceptTerms {
		c.JSON(http.StatusBadRequest, gin.H{"error": "You must accept the terms and conditions"})
		return
	}

	// Check if username is taken
	var usernameExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE username = $1)
	`, user.Username).Scan(&usernameExists)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error checking username availability"})
		return
	}

	if usernameExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Username already taken"})
		return
	}

	// Check if email is taken
	var emailExists bool
	err = db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE email = $1)
	`, user.Email).Scan(&emailExists)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error checking email availability"})
		return
	}

	if emailExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email already registered"})
		return
	}

	// Generate user ID
	userID := uuid.New().String()

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error processing password"})
		return
	}

	// Generate verification token
	verificationToken := uuid.New().String()

	// Begin transaction
	tx, err := db.Begin(context.Background())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer tx.Rollback(context.Background())

	// Insert user
	_, err = tx.Exec(context.Background(), `
		INSERT INTO users.users (
			id, username, email, phone_number, first_name, last_name, 
			date_of_birth, street, city, state, zip_code, country,
			risk_profile, device_id, kyc_status, is_active, password_hash
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
		)
	`, userID, user.Username, user.Email, user.PhoneNumber, user.FirstName,
		user.LastName, user.DateOfBirth, user.Address.Street, user.Address.City,
		user.Address.State, user.Address.ZipCode, user.Address.Country,
		user.RiskProfile, user.DeviceID, "PENDING", false, hashedPassword)

	if err != nil {
		log.Printf("Error creating user: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error creating user"})
		return
	}

	// Create verification record
	_, err = tx.Exec(context.Background(), `
		INSERT INTO users.email_verifications (
			user_id, token, expires_at
		) VALUES (
			$1, $2, $3
		)
	`, userID, verificationToken, time.Now().Add(24*time.Hour))

	if err != nil {
		log.Printf("Error creating verification: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error creating verification"})
		return
	}

	// Process referral code if provided
	if user.ReferralCode != "" {
		_, err = tx.Exec(context.Background(), `
			INSERT INTO users.referrals (
				referrer_code, referred_user_id, created_at
			) VALUES (
				$1, $2, $3
			)
		`, user.ReferralCode, userID, time.Now())

		if err != nil {
			log.Printf("Error processing referral: %v", err)
			// Continue even if referral processing fails
		}
	}

	// Commit transaction
	if err = tx.Commit(context.Background()); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error completing registration"})
		return
	}

	// Send verification email (mock in this implementation)
	sendVerificationEmail(user.Email, verificationToken)

	c.JSON(http.StatusCreated, gin.H{
		"message": "User registered successfully. Please check your email to verify your account.",
		"user_id": userID,
	})
}

// verifyEmail handles email verification
func verifyEmail(c *gin.Context) {
	var input struct {
		Token string `json:"token" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Begin transaction
	tx, err := db.Begin(context.Background())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer tx.Rollback(context.Background())

	// Get verification record
	var userID string
	var expiresAt time.Time
	err = tx.QueryRow(context.Background(), `
		SELECT user_id, expires_at
		FROM users.email_verifications
		WHERE token = $1 AND verified_at IS NULL
	`, input.Token).Scan(&userID, &expiresAt)

	if err != nil {
		log.Printf("Error finding verification token %s: %v", input.Token, err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Invalid or expired verification token"})
		return
	}

	// Check if token is expired
	if time.Now().After(expiresAt) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Verification token has expired"})
		return
	}

	// Mark verification as completed
	_, err = tx.Exec(context.Background(), `
		UPDATE users.email_verifications
		SET verified_at = $1
		WHERE token = $2
	`, time.Now(), input.Token)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error updating verification status"})
		return
	}

	// Activate user
	_, err = tx.Exec(context.Background(), `
		UPDATE users.users
		SET is_active = true, email_verified = true
		WHERE id = $1
	`, userID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error activating user account"})
		return
	}

	// Fetch user information for KYC verification
	var firstName, lastName, email, phoneNumber string
	var dateOfBirth time.Time
	var street, city, state, zipCode, country string

	err = tx.QueryRow(context.Background(), `
		SELECT first_name, last_name, email, phone_number, date_of_birth,
		       street, city, state, zip_code, country
		FROM users.users
		WHERE id = $1
	`, userID).Scan(
		&firstName, &lastName, &email, &phoneNumber, &dateOfBirth,
		&street, &city, &state, &zipCode, &country,
	)

	if err != nil {
		log.Printf("Error fetching user information for ID %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error fetching user information"})
		return
	}

	// Ensure required fields are not empty
	if len(strings.TrimSpace(firstName)) == 0 {
		firstName = "Unknown" // Provide a default value if empty
	}
	if len(strings.TrimSpace(lastName)) == 0 {
		lastName = "Unknown" // Provide a default value if empty
	}

	// Create KYC verification request with complete user information
	kycRequestID := uuid.New().String()
	requestData := map[string]interface{}{
		"user_id":       userID,
		"request_type":  "IDENTITY_VERIFICATION",
		"source":        "EMAIL_VERIFICATION",
		"first_name":    firstName,
		"last_name":     lastName,
		"email":         email,
		"phone":         phoneNumber,
		"date_of_birth": dateOfBirth.Format("2006-01-02"),
		"address_line1": street,
		"city":          city,
		"state":         state,
		"postal_code":   zipCode,
		"country":       country,
	}

	// Convert requestData to JSON
	requestDataJSON, err := json.Marshal(requestData)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error creating KYC verification request"})
		return
	}

	_, err = tx.Exec(context.Background(), `
		INSERT INTO kyc.verification_requests (
			id, user_id, status, request_data, provider, created_at
		) VALUES (
			$1, $2, $3, $4, $5, $6
		)
	`, kycRequestID, userID, "PENDING", requestDataJSON, "DEFAULT_PROVIDER", time.Now())

	if err != nil {
		log.Printf("Error creating KYC verification request for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error creating KYC verification request"})
		return
	}

	// Commit transaction
	if err = tx.Commit(context.Background()); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error completing verification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Email verified successfully. Your account is now active.",
	})
}

// resendVerification resends the verification email
func resendVerification(c *gin.Context) {
	var input struct {
		Email string `json:"email" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if user exists
	var userID string
	var isActive bool
	err := db.QueryRow(context.Background(), `
		SELECT id, is_active
		FROM users.users
		WHERE email = $1
	`, input.Email).Scan(&userID, &isActive)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if user is already active
	if isActive {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User is already active"})
		return
	}

	// Generate new verification token
	newToken := uuid.New().String()
	expiresAt := time.Now().Add(24 * time.Hour)

	// Update or insert verification record
	_, err = db.Exec(context.Background(), `
		INSERT INTO users.email_verifications (user_id, token, expires_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id) 
		DO UPDATE SET token = $2, expires_at = $3, verified_at = NULL
	`, userID, newToken, expiresAt)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error creating verification"})
		return
	}

	// Send verification email
	sendVerificationEmail(input.Email, newToken)

	c.JSON(http.StatusOK, gin.H{
		"message": "Verification email has been resent",
	})
}

// checkUsername checks if a username is available
func checkUsername(c *gin.Context) {
	var input struct {
		Username string `json:"username" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate username format
	if !isValidUsername(input.Username) {
		c.JSON(http.StatusBadRequest, gin.H{
			"available": false,
			"message":   "Username must be 3-20 characters, alphanumeric with underscores only",
		})
		return
	}

	// Check if username exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE username = $1)
	`, input.Username).Scan(&exists)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if exists {
		c.JSON(http.StatusOK, gin.H{
			"available": false,
			"message":   "Username is already taken",
		})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"available": true,
			"message":   "Username is available",
		})
	}
}

// checkEmail checks if an email is available
func checkEmail(c *gin.Context) {
	var input struct {
		Email string `json:"email" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate email format
	if !isValidEmail(input.Email) {
		c.JSON(http.StatusBadRequest, gin.H{
			"available": false,
			"message":   "Invalid email format",
		})
		return
	}

	// Check if email exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE email = $1)
	`, input.Email).Scan(&exists)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if exists {
		c.JSON(http.StatusOK, gin.H{
			"available": false,
			"message":   "Email is already registered",
		})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"available": true,
			"message":   "Email is available",
		})
	}
}

// Validation helper functions
func validateUser(user User) []ValidationError {
	var errors []ValidationError

	// Validate first name
	if len(strings.TrimSpace(user.FirstName)) == 0 {
		errors = append(errors, ValidationError{
			Field:   "first_name",
			Message: "First name cannot be empty",
		})
	}

	// Validate last name
	if len(strings.TrimSpace(user.LastName)) == 0 {
		errors = append(errors, ValidationError{
			Field:   "last_name",
			Message: "Last name cannot be empty",
		})
	}

	// Validate username
	if !isValidUsername(user.Username) {
		errors = append(errors, ValidationError{
			Field:   "username",
			Message: "Username must be 3-20 characters, alphanumeric with underscores only",
		})
	}

	// Validate email
	if !isValidEmail(user.Email) {
		errors = append(errors, ValidationError{
			Field:   "email",
			Message: "Invalid email format",
		})
	}

	// Validate password strength
	if !isStrongPassword(user.Password) {
		errors = append(errors, ValidationError{
			Field:   "password",
			Message: "Password must be at least 8 characters and include uppercase, lowercase, number, and special character",
		})
	}

	// Validate date of birth
	if !isValidDateOfBirth(user.DateOfBirth) {
		errors = append(errors, ValidationError{
			Field:   "date_of_birth",
			Message: "Invalid date format (required: YYYY-MM-DD) or user must be at least 18 years old",
		})
	}

	// Validate phone number (if provided)
	if user.PhoneNumber != "" && !isValidPhoneNumber(user.PhoneNumber) {
		errors = append(errors, ValidationError{
			Field:   "phone_number",
			Message: "Invalid phone number format",
		})
	}

	return errors
}

func isValidUsername(username string) bool {
	// Username must be 3-20 characters, alphanumeric with underscores
	matched, _ := regexp.MatchString(`^[a-zA-Z0-9_]{3,20}$`, username)
	return matched
}

func isValidEmail(email string) bool {
	// Simple email validation
	matched, _ := regexp.MatchString(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`, email)
	return matched
}

func isStrongPassword(password string) bool {
	// Password must be at least 8 characters
	if len(password) < 8 {
		return false
	}

	// Check for uppercase, lowercase, number, and special character
	hasUpper := regexp.MustCompile(`[A-Z]`).MatchString(password)
	hasLower := regexp.MustCompile(`[a-z]`).MatchString(password)
	hasNumber := regexp.MustCompile(`[0-9]`).MatchString(password)
	hasSpecial := regexp.MustCompile(`[!@#$%^&*(),.?":{}|<>]`).MatchString(password)

	return hasUpper && hasLower && hasNumber && hasSpecial
}

func isValidDateOfBirth(dob string) bool {
	// Parse date in YYYY-MM-DD format
	t, err := time.Parse("2006-01-02", dob)
	if err != nil {
		return false
	}

	// Check if user is at least 18 years old
	eighteenYearsAgo := time.Now().AddDate(-18, 0, 0)
	return t.Before(eighteenYearsAgo)
}

func isValidPhoneNumber(phone string) bool {
	// Remove any non-digit characters
	cleanPhone := regexp.MustCompile(`\D`).ReplaceAllString(phone, "")

	// Check if the cleaned phone number has a valid length (assuming US)
	return len(cleanPhone) >= 10 && len(cleanPhone) <= 15
}

// Mock email sending function
func sendVerificationEmail(email, token string) {
	// In a real implementation, this would send an actual email
	verificationLink := fmt.Sprintf("https://app.trustainvest.com/verify?token=%s", token)
	log.Printf("Sending verification email to %s with link: %s", email, verificationLink)

	// For demonstration purposes, we just log the email
	emailContent := fmt.Sprintf(`
	To: %s
	Subject: Verify Your TrustAInvest Account
	
	Hello,
	
	Thank you for registering with TrustAInvest. Please click on the link below to verify your email address:
	
	%s
	
	This link will expire in 24 hours.
	
	If you did not create an account, please ignore this email.
	
	Best regards,
	The TrustAInvest Team
	`, email, verificationLink)

	log.Println("Email content:")
	log.Println(emailContent)

	// In production, we would call a notification service or email provider API here
}
