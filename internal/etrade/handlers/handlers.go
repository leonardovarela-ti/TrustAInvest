package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/models"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/service"
)

// ETradeHandler handles HTTP requests for E-Trade integration
type ETradeHandler struct {
	etradeService *service.ETradeService
}

// NewETradeHandler creates a new E-Trade handler
func NewETradeHandler(etradeService *service.ETradeService) *ETradeHandler {
	return &ETradeHandler{
		etradeService: etradeService,
	}
}

// RegisterRoutes registers the E-Trade routes
func (h *ETradeHandler) RegisterRoutes(router *gin.RouterGroup) {
	etrade := router.Group("/etrade")
	{
		etrade.POST("/auth/initiate", h.InitiateAuth)
		etrade.POST("/auth/callback", h.AuthCallback)
		etrade.GET("/accounts", h.GetAccounts)
		etrade.POST("/accounts/link", h.LinkAccount)
	}
}

// InitiateAuth initiates the OAuth flow for E-Trade
func (h *ETradeHandler) InitiateAuth(c *gin.Context) {
	var req models.ETradeAuthRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate user ID
	if _, err := uuid.Parse(req.UserID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Initiate the auth flow
	resp, err := h.etradeService.InitiateAuth(req.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

// AuthCallback handles the callback from E-Trade after user authorization
func (h *ETradeHandler) AuthCallback(c *gin.Context) {
	var callback models.ETradeAuthCallback
	if err := c.ShouldBindJSON(&callback); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate user ID
	if _, err := uuid.Parse(callback.UserID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Complete the auth flow
	accessToken, err := h.etradeService.CompleteAuth(&callback)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"access_token": accessToken,
	})
}

// GetAccounts retrieves the list of accounts for the authenticated user
func (h *ETradeHandler) GetAccounts(c *gin.Context) {
	userID := c.Query("user_id")
	if userID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	// Validate user ID
	if _, err := uuid.Parse(userID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get the accounts
	accounts, err := h.etradeService.GetAccounts(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"accounts": accounts,
	})
}

// LinkAccount links an E-Trade account to a TrustAInvest account
func (h *ETradeHandler) LinkAccount(c *gin.Context) {
	var req models.ETradeAccountLinkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate user ID
	if _, err := uuid.Parse(req.UserID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Link the account
	resp, err := h.etradeService.LinkAccount(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}
