package api

import (
	"context"
	"errors"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
)

// RegistrationRequest represents the data needed for user registration
type RegistrationRequest struct {
	Username    string  `json:"username" binding:"required"`
	Email       string  `json:"email" binding:"required,email"`
	Password    string  `json:"password" binding:"required,min=8"`
	PhoneNumber string  `json:"phone_number" binding:"required"`
	FirstName   string  `json:"first_name" binding:"required"`
	LastName    string  `json:"last_name" binding:"required"`
	DateOfBirth string  `json:"date_of_birth" binding:"required"` // Format: YYYY-MM-DD
	Address     Address `json:"address" binding:"required"`
	SSN         string  `json:"ssn" binding:"required"` // Will be encrypted
	RiskProfile string  `json:"risk_profile" binding:"omitempty"`
}

// Address represents a physical address
type Address struct {
	Street  string `json:"street" binding:"required"`
	City    string `json:"city" binding:"required"`
	State   string `json:"state" binding:"required"`
	ZipCode string `json:"zip_code" binding:"required"`
	Country string `json:"country" binding:"required"`
}

// RegistrationResponse represents the response for a successful registration
type RegistrationResponse struct {
	ID       string `json:"id"`
	Username string `json:"username"`
	Email    string `json:"email"`
	Status   string `json:"status"`
	Message  string `json:"message"`
}

// UserRegistrationHandler handles the user registration process
type UserRegistrationHandler struct {
	userService    UserService
	kycService     KYCService
	encryptService EncryptionService
}

// UserService defines methods for working with users
type UserService interface {
	CreateUser(ctx context.Context, user *models.User) error
	GetUserByUsername(ctx context.Context, username string) (*models.User, error)
	GetUserByEmail(ctx context.Context, email string) (*models.User, error)
	UpdateUserKYCStatus(ctx context.Context, userID string, status string) error
}

// KYCService defines methods for KYC verification
type KYCService interface {
	EnqueueKYCVerification(ctx context.Context, userID string, kycData *KYCData) error
}

// EncryptionService defines methods for encrypting sensitive data
type EncryptionService interface {
	EncryptData(data string) ([]byte, error)
}

// KYCData represents the data required for KYC verification
type KYCData struct {
	UserID      string    `json:"user_id"`
	FirstName   string    `json:"first_name"`
	LastName    string    `json:"last_name"`
	DateOfBirth string    `json:"date_of_birth"`
	SSN         string    `json:"ssn"`
	Address     Address   `json:"address"`
	Email       string    `json:"email"`
	PhoneNumber string    `json:"phone_number"`
	CreatedAt   time.Time `json:"created_at"`
}

// NewUserRegistrationHandler creates a new UserRegistrationHandler
func NewUserRegistrationHandler(userService UserService, kycService KYCService, encryptService EncryptionService) *UserRegistrationHandler {
	return &UserRegistrationHandler{
		userService:    userService,
		kycService:     kycService,
		encryptService: encryptService,
	}
}

// Register handles the user registration request
func (h *UserRegistrationHandler) Register(c *gin.Context) {
	var request RegistrationRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate request
	if err := h.validateRegistration(c.Request.Context(), request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Create a new user ID
	userID := uuid.New().String()

	// Encrypt sensitive data
	ssnEncrypted, err := h.encryptService.EncryptData(request.SSN)
	if err != nil {
		log.Printf("Error encrypting SSN: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process sensitive data"})
		return
	}

	// Parse date of birth
	dob, err := time.Parse("2006-01-02", request.DateOfBirth)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format for date_of_birth. Use YYYY-MM-DD"})
		return
	}

	// Create user object
	user := &models.User{
		ID:           userID,
		Username:     request.Username,
		Email:        request.Email,
		PhoneNumber:  request.PhoneNumber,
		FirstName:    request.FirstName,
		LastName:     request.LastName,
		DateOfBirth:  dob,
		Street:       request.Address.Street,
		City:         request.Address.City,
		State:        request.Address.State,
		ZipCode:      request.Address.ZipCode,
		Country:      request.Address.Country,
		SSNEncrypted: ssnEncrypted,
		RiskProfile:  request.RiskProfile,
		KYCStatus:    "PENDING",
		IsActive:     true,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	// Save user to database
	if err := h.userService.CreateUser(c.Request.Context(), user); err != nil {
		log.Printf("Error creating user: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	// Prepare KYC data
	kycData := &KYCData{
		UserID:      userID,
		FirstName:   request.FirstName,
		LastName:    request.LastName,
		DateOfBirth: request.DateOfBirth,
		SSN:         request.SSN, // Will be encrypted by the KYC service
		Address:     request.Address,
		Email:       request.Email,
		PhoneNumber: request.PhoneNumber,
		CreatedAt:   time.Now(),
	}

	// Send to KYC verification queue
	if err := h.kycService.EnqueueKYCVerification(c.Request.Context(), userID, kycData); err != nil {
		log.Printf("Error enqueueing KYC verification: %v", err)
		// We still return success to the user, but log the error
		// The system should have a background job to retry failed KYC enqueues
	}

	// Return success response
	c.JSON(http.StatusCreated, RegistrationResponse{
		ID:       userID,
		Username: user.Username,
		Email:    user.Email,
		Status:   "PENDING",
		Message:  "Registration successful. Your account is pending KYC verification.",
	})
}

// validateRegistration validates the registration request
func (h *UserRegistrationHandler) validateRegistration(ctx context.Context, request RegistrationRequest) error {
	// Check if username already exists
	existingUser, err := h.userService.GetUserByUsername(ctx, request.Username)
	if err == nil && existingUser != nil {
		return errors.New("username already exists")
	}

	// Check if email already exists
	existingUser, err = h.userService.GetUserByEmail(ctx, request.Email)
	if err == nil && existingUser != nil {
		return errors.New("email already exists")
	}

	// Additional validations can be added here
	return nil
}

// RegisterRoutes registers the user registration routes
func (h *UserRegistrationHandler) RegisterRoutes(router *gin.Engine) {
	router.POST("/api/v1/register", h.Register)
}
