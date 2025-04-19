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

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/handlers"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/capitalone/service"
)

func main() {
	log.Println("Starting capitalone-service...")

	// Get environment variables
	dbHost := getEnv("DB_HOST", "postgres")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "trustainvest")
	dbPassword := getEnv("DB_PASSWORD", "trustainvest")
	dbName := getEnv("DB_NAME", "trustainvest")
	capitalOneClientID := getEnv("CAPITALONE_CLIENT_ID", "")
	capitalOneClientSecret := getEnv("CAPITALONE_CLIENT_SECRET", "")
	capitalOneRedirectURI := getEnv("CAPITALONE_REDIRECT_URI", "")
	capitalOneSandbox := getEnv("CAPITALONE_SANDBOX", "true") == "true"

	// Validate required environment variables
	if capitalOneClientID == "" || capitalOneClientSecret == "" {
		log.Fatal("CAPITALONE_CLIENT_ID and CAPITALONE_CLIENT_SECRET environment variables are required")
	}

	if capitalOneRedirectURI == "" {
		log.Fatal("CAPITALONE_REDIRECT_URI environment variable is required")
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

	// Create the Capital One service
	capitalOneService := service.NewCapitalOneService(db, capitalOneClientID, capitalOneClientSecret, capitalOneRedirectURI, capitalOneSandbox)

	// Ensure the capitalone schema exists
	if err := capitalOneService.EnsureCapitalOneSchema(); err != nil {
		log.Fatalf("Failed to ensure capitalone schema: %v", err)
	}

	// Create the Capital One handler
	capitalOneHandler := handlers.NewCapitalOneHandler(capitalOneService)

	// Set up Gin router
	router := gin.Default()

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "capitalone-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	capitalOneHandler.RegisterRoutes(v1)

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
	log.Println("Shutting down capitalone-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Capital One service stopped")
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
