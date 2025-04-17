package api

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
)

// AuthHandler handles authentication-related HTTP requests
type AuthHandler struct {
	userService  AuthUserService
	tokenService TokenService
}

// NewAuthHandler creates a new AuthHandler
func NewAuthHandler(userService AuthUserService, tokenService TokenService) *AuthHandler {
	return &AuthHandler{
		userService:  userService,
		tokenService: tokenService,
	}
}

// AuthUserService defines the user service interface for authentication
type AuthUserService interface {
	GetUserByID(ctx context.Context, id string) (*models.User, error)
	GetUserByUsername(ctx context.Context, username string) (*models.User, error)
	GetUserByEmail(ctx context.Context, email string) (*models.User, error)
	VerifyPassword(ctx context.Context, username, password string) (bool, error)
}

// TokenService defines methods for JWT token operations
type TokenService interface {
	GenerateToken(userID, username, email, role string) (string, error)
	ValidateToken(tokenString string) (*Claims, error)
}

// Claims represents the JWT claims
type Claims struct {
	UserID   string
	Username string
	Email    string
	Role     string
}

// LoginRequest represents the login request payload
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// LoginResponse represents the login response
type LoginResponse struct {
	Token     string `json:"token"`
	ExpiresIn int64  `json:"expires_in"`
	UserID    string `json:"user_id"`
	Username  string `json:"username"`
	Email     string `json:"email"`
}

// RegisterRoutes registers the auth API routes
func (h *AuthHandler) RegisterRoutes(router *gin.Engine) {
	authGroup := router.Group("/api/v1/auth")
	{
		authGroup.POST("/login", h.Login)
		authGroup.GET("/me", h.AuthMiddleware(), h.GetCurrentUser)
	}
}

// Login handles user login
func (h *AuthHandler) Login(c *gin.Context) {
	var request LoginRequest
	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user by username and verify password
	user, err := h.userService.GetUserByUsername(c.Request.Context(), request.Username)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to authenticate user"})
		return
	}

	if user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Verify password
	valid, err := h.userService.VerifyPassword(c.Request.Context(), request.Username, request.Password)
	if err != nil || !valid {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Check if user is active
	if !user.IsActive {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Account is inactive"})
		return
	}

	// Check if user's KYC is verified
	if user.KYCStatus != "VERIFIED" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Account is pending KYC verification"})
		return
	}

	// Generate JWT token
	token, err := h.tokenService.GenerateToken(user.ID, user.Username, user.Email, "USER")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Return token and user info
	c.JSON(http.StatusOK, LoginResponse{
		Token:     token,
		ExpiresIn: 3600, // 1 hour
		UserID:    user.ID,
		Username:  user.Username,
		Email:     user.Email,
	})
}

// AuthMiddleware creates a middleware for authentication
func (h *AuthHandler) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		// Check if the header starts with "Bearer "
		if len(authHeader) < 7 || authHeader[:7] != "Bearer " {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid authorization format"})
			c.Abort()
			return
		}

		// Extract the token
		tokenString := authHeader[7:]

		// Validate the token
		claims, err := h.tokenService.ValidateToken(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		// Set the user ID in the context
		c.Set("userID", claims.UserID)
		c.Set("username", claims.Username)
		c.Set("email", claims.Email)
		c.Set("role", claims.Role)

		c.Next()
	}
}

// GetCurrentUser returns the current authenticated user
func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Get user by ID
	user, err := h.userService.GetUserByID(c.Request.Context(), userID.(string))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve user information"})
		return
	}

	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Return user info
	c.JSON(http.StatusOK, gin.H{
		"id":           user.ID,
		"username":     user.Username,
		"email":        user.Email,
		"first_name":   user.FirstName,
		"last_name":    user.LastName,
		"phone_number": user.PhoneNumber,
		"kyc_status":   user.KYCStatus,
		"risk_profile": user.RiskProfile,
		"created_at":   user.CreatedAt,
	})
}
