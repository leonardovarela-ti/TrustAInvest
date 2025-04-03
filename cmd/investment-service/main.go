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

// Asset represents an investment asset
type Asset struct {
	ID           string    `json:"id"`
	Symbol       string    `json:"symbol"`
	Name         string    `json:"name"`
	AssetClass   string    `json:"asset_class"`
	CurrentPrice float64   `json:"current_price"`
	Currency     string    `json:"currency"`
	LastUpdated  time.Time `json:"last_updated"`
}

// Position represents a user's investment position
type Position struct {
	ID           string    `json:"id"`
	AccountID    string    `json:"account_id"`
	AssetID      string    `json:"asset_id"`
	Quantity     float64   `json:"quantity"`
	CostBasis    float64   `json:"cost_basis"`
	Currency     string    `json:"currency"`
	CurrentValue float64   `json:"current_value"`
	PurchaseDate time.Time `json:"purchase_date"`
	LastUpdated  time.Time `json:"last_updated"`
	IsOpen       bool      `json:"is_open"`
	Gains        float64   `json:"gains"`
	GainPercent  float64   `json:"gain_percent"`
}

var db *pgxpool.Pool

func main() {
	log.Println("Starting investment-service...")

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
			"service": "investment-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		// Assets
		assets := v1.Group("/assets")
		{
			assets.GET("", listAssets)
			assets.GET("/:id", getAssetByID)
			assets.GET("/symbol/:symbol", getAssetBySymbol)
			assets.POST("", createAsset)
			assets.PUT("/:id", updateAsset)
		}

		// Positions
		positions := v1.Group("/positions")
		{
			positions.GET("", listPositions)
			positions.GET("/:id", getPositionByID)
			positions.POST("", createPosition)
			positions.PUT("/:id", updatePosition)
			positions.DELETE("/:id", closePosition)
		}

		// Account positions
		accountPositions := v1.Group("/accounts/:accountId/positions")
		{
			accountPositions.GET("", getAccountPositions)
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
	log.Println("Shutting down investment-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Investment service stopped")
}

// Assets handlers
func listAssets(c *gin.Context) {
	var assets []Asset
	rows, err := db.Query(context.Background(), `
		SELECT id, symbol, name, asset_class, current_price_amount, 
		       current_price_currency, last_updated
		FROM investments.assets
		LIMIT 100
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve assets"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var asset Asset
		err := rows.Scan(
			&asset.ID, &asset.Symbol, &asset.Name, &asset.AssetClass,
			&asset.CurrentPrice, &asset.Currency, &asset.LastUpdated,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan asset data"})
			return
		}
		assets = append(assets, asset)
	}

	c.JSON(http.StatusOK, gin.H{"assets": assets})
}

func getAssetByID(c *gin.Context) {
	id := c.Param("id")
	var asset Asset

	err := db.QueryRow(context.Background(), `
		SELECT id, symbol, name, asset_class, current_price_amount, 
		       current_price_currency, last_updated
		FROM investments.assets
		WHERE id = $1
	`, id).Scan(
		&asset.ID, &asset.Symbol, &asset.Name, &asset.AssetClass,
		&asset.CurrentPrice, &asset.Currency, &asset.LastUpdated,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
		return
	}

	c.JSON(http.StatusOK, asset)
}

func getAssetBySymbol(c *gin.Context) {
	symbol := c.Param("symbol")
	var asset Asset

	err := db.QueryRow(context.Background(), `
		SELECT id, symbol, name, asset_class, current_price_amount, 
		       current_price_currency, last_updated
		FROM investments.assets
		WHERE symbol = $1
	`, symbol).Scan(
		&asset.ID, &asset.Symbol, &asset.Name, &asset.AssetClass,
		&asset.CurrentPrice, &asset.Currency, &asset.LastUpdated,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
		return
	}

	c.JSON(http.StatusOK, asset)
}

func createAsset(c *gin.Context) {
	var input struct {
		Symbol     string  `json:"symbol" binding:"required"`
		Name       string  `json:"name" binding:"required"`
		AssetClass string  `json:"asset_class" binding:"required"`
		Price      float64 `json:"price" binding:"required"`
		Currency   string  `json:"currency"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if asset with symbol already exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM investments.assets WHERE symbol = $1)
	`, input.Symbol).Scan(&exists)

	if err == nil && exists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Asset with this symbol already exists"})
		return
	}

	id := uuid.New().String()
	currency := input.Currency
	if currency == "" {
		currency = "USD"
	}

	_, err = db.Exec(context.Background(), `
		INSERT INTO investments.assets (
			id, symbol, name, asset_class, current_price_amount,
			current_price_currency, last_updated
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
	`, id, input.Symbol, input.Name, input.AssetClass, input.Price, currency, time.Now())

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create asset: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Asset created successfully",
	})
}

func updateAsset(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Name       string  `json:"name"`
		AssetClass string  `json:"asset_class"`
		Price      float64 `json:"price"`
		Currency   string  `json:"currency"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if asset exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM investments.assets WHERE id = $1)
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Asset not found"})
		return
	}

	// Perform update
	_, err = db.Exec(context.Background(), `
		UPDATE investments.assets
		SET 
			name = COALESCE(NULLIF($1, ''), name),
			asset_class = COALESCE(NULLIF($2, ''), asset_class),
			current_price_amount = CASE WHEN $3 > 0 THEN $3 ELSE current_price_amount END,
			current_price_currency = COALESCE(NULLIF($4, ''), current_price_currency),
			last_updated = $5
		WHERE id = $6
	`, input.Name, input.AssetClass, input.Price, input.Currency, time.Now(), id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update asset: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Asset updated successfully"})
}

// Positions handlers
func listPositions(c *gin.Context) {
	var positions []Position
	rows, err := db.Query(context.Background(), `
		SELECT id, account_id, asset_id, quantity, cost_basis, 
		       current_value, purchase_date, last_updated, is_open,
		       current_value - cost_basis AS gains,
		       CASE WHEN cost_basis > 0 THEN ((current_value - cost_basis) / cost_basis) * 100 ELSE 0 END AS gain_percent
		FROM investments.positions
		WHERE is_open = true
		LIMIT 100
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve positions"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var position Position
		err := rows.Scan(
			&position.ID, &position.AccountID, &position.AssetID, &position.Quantity,
			&position.CostBasis, &position.CurrentValue, &position.PurchaseDate,
			&position.LastUpdated, &position.IsOpen, &position.Gains, &position.GainPercent,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan position data"})
			return
		}
		positions = append(positions, position)
	}

	c.JSON(http.StatusOK, gin.H{"positions": positions})
}

func getPositionByID(c *gin.Context) {
	id := c.Param("id")
	var position Position

	err := db.QueryRow(context.Background(), `
		SELECT id, account_id, asset_id, quantity, cost_basis, 
		       current_value, purchase_date, last_updated, is_open,
		       current_value - cost_basis AS gains,
		       CASE WHEN cost_basis > 0 THEN ((current_value - cost_basis) / cost_basis) * 100 ELSE 0 END AS gain_percent
		FROM investments.positions
		WHERE id = $1
	`, id).Scan(
		&position.ID, &position.AccountID, &position.AssetID, &position.Quantity,
		&position.CostBasis, &position.CurrentValue, &position.PurchaseDate,
		&position.LastUpdated, &position.IsOpen, &position.Gains, &position.GainPercent,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Position not found"})
		return
	}

	c.JSON(http.StatusOK, position)
}

func getAccountPositions(c *gin.Context) {
	accountID := c.Param("accountId")
	var positions []Position

	rows, err := db.Query(context.Background(), `
		SELECT id, account_id, asset_id, quantity, cost_basis, 
		       current_value, purchase_date, last_updated, is_open,
		       current_value - cost_basis AS gains,
		       CASE WHEN cost_basis > 0 THEN ((current_value - cost_basis) / cost_basis) * 100 ELSE 0 END AS gain_percent
		FROM investments.positions
		WHERE account_id = $1 AND is_open = true
	`, accountID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve positions"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var position Position
		err := rows.Scan(
			&position.ID, &position.AccountID, &position.AssetID, &position.Quantity,
			&position.CostBasis, &position.CurrentValue, &position.PurchaseDate,
			&position.LastUpdated, &position.IsOpen, &position.Gains, &position.GainPercent,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan position data"})
			return
		}
		positions = append(positions, position)
	}

	c.JSON(http.StatusOK, gin.H{"positions": positions})
}

func createPosition(c *gin.Context) {
	var input struct {
		AccountID string  `json:"account_id" binding:"required"`
		AssetID   string  `json:"asset_id" binding:"required"`
		Quantity  float64 `json:"quantity" binding:"required"`
		Price     float64 `json:"price" binding:"required"`
		Currency  string  `json:"currency"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if account exists
	var accountExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM accounts.accounts WHERE id = $1 AND is_active = true)
	`, input.AccountID).Scan(&accountExists)

	if err != nil || !accountExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Account not found"})
		return
	}

	// Check if asset exists
	var assetExists bool
	err = db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM investments.assets WHERE id = $1)
	`, input.AssetID).Scan(&assetExists)

	if err != nil || !assetExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Asset not found"})
		return
	}

	id := uuid.New().String()
	currency := input.Currency
	if currency == "" {
		currency = "USD"
	}

	// Calculate total cost
	costBasis := input.Quantity * input.Price

	// Create position
	_, err = db.Exec(context.Background(), `
		INSERT INTO investments.positions (
			id, account_id, asset_id, quantity, cost_basis,
			current_value, purchase_date, last_updated, is_open
		) VALUES (
			$1, $2, $3, $4, $5, $5, $6, $6, $7
		)
	`, id, input.AccountID, input.AssetID, input.Quantity, costBasis, time.Now(), true)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create position: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Position created successfully",
	})
}

func updatePosition(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Quantity     float64 `json:"quantity"`
		CurrentValue float64 `json:"current_value"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if position exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM investments.positions WHERE id = $1 AND is_open = true)
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Position not found"})
		return
	}

	// Update position
	_, err = db.Exec(context.Background(), `
		UPDATE investments.positions
		SET 
			quantity = CASE WHEN $1 > 0 THEN $1 ELSE quantity END,
			current_value = CASE WHEN $2 > 0 THEN $2 ELSE current_value END,
			last_updated = $3
		WHERE id = $4 AND is_open = true
	`, input.Quantity, input.CurrentValue, time.Now(), id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update position: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Position updated successfully"})
}

func closePosition(c *gin.Context) {
	id := c.Param("id")

	result, err := db.Exec(context.Background(), `
		UPDATE investments.positions
		SET is_open = false, last_updated = $1
		WHERE id = $2 AND is_open = true
	`, time.Now(), id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to close position: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Position not found"})
		return
	}

	c.Status(http.StatusNoContent)
}
