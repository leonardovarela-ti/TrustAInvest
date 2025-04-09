package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	"github.com/rs/cors"
)

func main() {
	// Load environment variables
	dbURL := getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/trustainvest?sslmode=disable")
	// JWT secret will be used when implementing authentication
	_ = getEnv("JWT_SECRET", "your-secret-key")
	port := getEnv("PORT", "8080")
	corsAllowedOrigins := getEnv("CORS_ALLOWED_ORIGINS", "*")

	// Connect to database
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test database connection
	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Create router
	router := mux.NewRouter()

	// Register routes
	// Note: In a real implementation, you would initialize your handlers and register routes here
	// For example:
	// kycVerifierRepo := db.NewKYCVerifierRepository(db)
	// kycVerifierHandler := api.NewKYCVerifierHandler(kycVerifierRepo)
	// authMiddleware := auth.NewMiddleware(jwtSecret, time.Hour*24)
	// kycVerifierHandler.RegisterRoutes(router, authMiddleware)

	// For demonstration purposes, we'll just add a simple health check endpoint
	router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("KYC Verifier Service is running"))
	}).Methods("GET")

	// Configure CORS
	c := cors.New(cors.Options{
		AllowedOrigins:   strings.Split(corsAllowedOrigins, ","),
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"},
		AllowedHeaders:   []string{"Content-Type", "Authorization"},
		AllowCredentials: true,
		MaxAge:           86400, // 24 hours
	})

	// Start server
	addr := fmt.Sprintf(":%s", port)
	log.Printf("Starting server on %s", addr)
	if err := http.ListenAndServe(addr, c.Handler(router)); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// getEnv gets an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
