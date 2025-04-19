package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/models"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/service"
)

// CapitalOneHandler handles HTTP requests for Capital One integration
type CapitalOneHandler struct {
	capitalOneService *service.CapitalOneService
}

// NewCapitalOneHandler creates a new Capital One handler
func NewCapitalOneHandler(capitalOneService *service.CapitalOneService) *CapitalOneHandler {
	return &CapitalOneHandler{
		capitalOneService: capitalOneService,
	}
}

// RegisterRoutes registers the Capital One routes
func (h *CapitalOneHandler) RegisterRoutes(router *gin.RouterGroup) {
	capitalone := router.Group("/capitalone")
	{
		capitalone.POST("/auth/initiate", h.InitiateAuth)
		capitalone.POST("/auth/callback", h.AuthCallback)
		capitalone.GET("/accounts", h.GetAccounts)
		capitalone.POST("/accounts/link", h.LinkAccount)
		capitalone.POST("/products/:productId/search", h.SearchBankProducts)
	}
}

// InitiateAuth initiates the OAuth flow for Capital One
func (h *CapitalOneHandler) InitiateAuth(c *gin.Context) {
	var req models.CapitalOneAuthRequest
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
	resp, err := h.capitalOneService.InitiateAuth(req.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

// AuthCallback handles the callback from Capital One after user authorization
func (h *CapitalOneHandler) AuthCallback(c *gin.Context) {
	var callback models.CapitalOneAuthCallback
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
	accessToken, err := h.capitalOneService.CompleteAuth(&callback)
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
func (h *CapitalOneHandler) GetAccounts(c *gin.Context) {
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
	accounts, err := h.capitalOneService.GetAccounts(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"accounts": accounts,
	})
}

// LinkAccount links a Capital One account to a TrustAInvest account
func (h *CapitalOneHandler) LinkAccount(c *gin.Context) {
	var req models.CapitalOneAccountLinkRequest
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
	resp, err := h.capitalOneService.LinkAccount(&req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

// SearchBankProducts searches for bank products based on the provided criteria
func (h *CapitalOneHandler) SearchBankProducts(c *gin.Context) {
	// Get the product ID from the URL parameter
	productID := c.Param("productId")
	if productID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Product ID is required"})
		return
	}

	// Parse the search request from the request body
	var searchRequest models.BankProductSearchRequest
	if err := c.ShouldBindJSON(&searchRequest); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Search for bank products
	response, err := h.capitalOneService.SearchBankProducts(productID, &searchRequest)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}
