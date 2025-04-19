package api

import (
	"context"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/auth"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/services"
	"golang.org/x/crypto/bcrypt"
)

// AuthHandler handles authentication-related HTTP requests
type AuthHandler struct {
	userService    *services.UserService
	tokenService   *auth.TokenService
	sessionService *auth.SessionService
}

// NewAuthHandler creates a new AuthHandler
func NewAuthHandler(userService *services.UserService, tokenService *auth.TokenService, sessionService *auth.SessionService) *AuthHandler {
	return &AuthHandler{
		userService:    userService,
		tokenService:   tokenService,
		sessionService: sessionService,
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
	var loginRequest LoginRequest

	if err := c.ShouldBindJSON(&loginRequest); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user by username
	user, err := h.userService.GetByUsername(c.Request.Context(), loginRequest.Username)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Check if user is active
	if !user.IsActive {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User account is not active"})
		return
	}

	// Check if email is verified (assuming we have this field in the User struct)
	if !user.EmailVerified {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Email not verified. Please verify your email before logging in."})
		return
	}

	// Check if KYC is verified
	if user.KYCStatus != "VERIFIED" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "KYC not verified. Your account is pending KYC verification."})
		return
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword(user.PasswordHash, []byte(loginRequest.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	token, err := h.tokenService.GenerateToken(user.ID, user.Username, user.Email, "USER")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	// Create a new session and invalidate any existing ones
	sessionID, err := h.sessionService.CreateSession(
		c.Request.Context(),
		user.ID,
		token,
		c.GetHeader("User-Agent"),
		c.ClientIP(),
		time.Now().Add(24*time.Hour), // Session expires in 24 hours
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token":      token,
		"session_id": sessionID,
		"user": gin.H{
			"id":       user.ID,
			"email":    user.Email,
			"username": user.Username,
		},
	})
}

// AuthMiddleware creates a middleware for authentication
func (h *AuthHandler) AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "No token provided"})
			c.Abort()
			return
		}

		// Remove "Bearer " prefix if present
		token = strings.TrimPrefix(token, "Bearer ")

		claims, err := h.tokenService.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		// Get session ID from header
		sessionID := c.GetHeader("X-Session-ID")
		if sessionID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "No session ID provided"})
			c.Abort()
			return
		}

		// Validate session
		valid, err := h.sessionService.ValidateSession(c.Request.Context(), sessionID)
		if err != nil || !valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired session"})
			c.Abort()
			return
		}

		// Update session activity
		err = h.sessionService.UpdateSessionActivity(c.Request.Context(), sessionID)
		if err != nil {
			// Log the error but don't fail the request
			log.Printf("Failed to update session activity: %v", err)
		}

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
