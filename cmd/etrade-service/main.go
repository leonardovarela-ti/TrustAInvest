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
	"github.com/jackc/pgx/v4/pgxpool"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/handlers"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/etrade/service"
)

func main() {
	log.Println("Starting etrade-service...")

	// Get environment variables
	dbHost := getEnv("DB_HOST", "postgres")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "trustainvest")
	dbPassword := getEnv("DB_PASSWORD", "trustainvest")
	dbName := getEnv("DB_NAME", "trustainvest")
	etradeConsumerKey := getEnv("ETRADE_CONSUMER_KEY", "")
	etradeConsumerSecret := getEnv("ETRADE_CONSUMER_SECRET", "")
	etradeCallbackURL := getEnv("ETRADE_CALLBACK_URL", "oob")
	etradeSandbox := getEnv("ETRADE_SANDBOX", "true") == "true"

	// Validate required environment variables
	if etradeConsumerKey == "" || etradeConsumerSecret == "" {
		log.Fatal("ETRADE_CONSUMER_KEY and ETRADE_CONSUMER_SECRET environment variables are required")
	}

	// Connect to database
	dbURL := "postgres://" + dbUser + ":" + dbPassword + "@" + dbHost + ":" + dbPort + "/" + dbName
	db, err := pgxpool.Connect(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer db.Close()

	// Verify database connection
	if err := db.Ping(context.Background()); err != nil {
		log.Fatalf("Unable to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Ensure the etrade schema exists
	if err := ensureEtradeSchema(db); err != nil {
		log.Fatalf("Failed to ensure etrade schema: %v", err)
	}

	// Create the E-Trade service
	etradeService := service.NewETradeService(db, etradeConsumerKey, etradeConsumerSecret, etradeCallbackURL, etradeSandbox)

	// Create the E-Trade handler
	etradeHandler := handlers.NewETradeHandler(etradeService)

	// Set up Gin router
	router := gin.Default()

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "etrade-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	etradeHandler.RegisterRoutes(v1)

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
	log.Println("Shutting down etrade-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("E-Trade service stopped")
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// ensureEtradeSchema ensures the etrade schema and tables exist
func ensureEtradeSchema(db *pgxpool.Pool) error {
	ctx := context.Background()

	// Create the etrade schema if it doesn't exist
	_, err := db.Exec(ctx, "CREATE SCHEMA IF NOT EXISTS etrade")
	if err != nil {
		return err
	}

	// Create the auth_tokens table if it doesn't exist
	_, err = db.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS etrade.auth_tokens (
			user_id UUID PRIMARY KEY REFERENCES users.users(id),
			request_token TEXT,
			access_token TEXT,
			token_secret TEXT,
			created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
			updated_at TIMESTAMP WITH TIME ZONE
		)
	`)
	if err != nil {
		return err
	}

	// Create an index on user_id
	_, err = db.Exec(ctx, "CREATE INDEX IF NOT EXISTS idx_etrade_auth_tokens_user_id ON etrade.auth_tokens(user_id)")
	if err != nil {
		return err
	}

	return nil
}
