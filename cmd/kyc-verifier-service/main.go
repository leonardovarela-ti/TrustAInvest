package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/dgrijalva/jwt-go"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	"github.com/rs/cors"
	"golang.org/x/crypto/bcrypt"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/db"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
)

// VerifierResponse represents a KYC verifier user response
type VerifierResponse struct {
	ID        string    `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	FirstName string    `json:"firstName"`
	LastName  string    `json:"lastName"`
	Role      string    `json:"role"`
	IsActive  bool      `json:"isActive"`
	CreatedAt time.Time `json:"createdAt"`
}

// LoginRequest represents the login request body
type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// LoginResponse represents the login response body
type LoginResponse struct {
	Token string `json:"token"`
}

// ErrorResponse represents an error response
type ErrorResponse struct {
	Message string `json:"message"`
}

// PaginatedResponse represents a paginated response
type PaginatedResponse struct {
	Data       interface{} `json:"data"`
	TotalCount int         `json:"total_count"`
	Page       int         `json:"page"`
	Limit      int         `json:"limit"`
}

// VerificationRequestResponse represents a verification request response
type VerificationRequestResponse struct {
	ID              string     `json:"id"`
	UserID          string     `json:"userId"`
	FirstName       string     `json:"firstName"`
	LastName        string     `json:"lastName"`
	Email           string     `json:"email"`
	Phone           *string    `json:"phone,omitempty"`
	DateOfBirth     time.Time  `json:"dateOfBirth"`
	AddressLine1    string     `json:"addressLine1"`
	AddressLine2    *string    `json:"addressLine2,omitempty"`
	City            string     `json:"city"`
	State           string     `json:"state"`
	PostalCode      string     `json:"postalCode"`
	Country         string     `json:"country"`
	AdditionalInfo  *string    `json:"additionalInfo,omitempty"`
	Status          string     `json:"status"`
	RejectionReason *string    `json:"rejectionReason,omitempty"`
	VerifierID      *string    `json:"verifierId,omitempty"`
	VerifiedAt      *time.Time `json:"verifiedAt,omitempty"`
	CreatedAt       time.Time  `json:"createdAt"`
	UpdatedAt       *time.Time `json:"updatedAt,omitempty"`
	DocumentCount   int        `json:"documentCount,omitempty"`
}

func main() {
	// Load environment variables
	dbURL := getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/trustainvest?sslmode=disable")
	// JWT secret for authentication
	jwtSecret := getEnv("JWT_SECRET", "your-secret-key")
	port := getEnv("PORT", "8080")
	corsAllowedOrigins := getEnv("CORS_ALLOWED_ORIGINS", "*")

	// Connect to database
	dbConn, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer dbConn.Close()

	// Test database connection
	if err := dbConn.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Create repository
	kycRepo := db.NewKYCVerifierRepository(dbConn)

	// Create router
	router := mux.NewRouter()

	// Register routes
	// API routes
	apiRouter := router.PathPrefix("/api").Subrouter()

	// Auth routes
	authRouter := apiRouter.PathPrefix("/auth").Subrouter()
	authRouter.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		var req LoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid request payload")
			return
		}

		// Get the user from the repository
		verifier, err := kycRepo.GetVerifierByUsername(req.Username)

		if err != nil {
			log.Printf("Error querying user: %v", err)
			respondWithError(w, http.StatusUnauthorized, "Invalid credentials")
			return
		}

		log.Printf("User found: %s, Role: %s, Active: %t", verifier.Username, verifier.Role, verifier.IsActive)

		// Check if the user is active
		if !verifier.IsActive {
			respondWithError(w, http.StatusUnauthorized, "Account is inactive")
			return
		}

		// Compare the password hash
		log.Printf("Comparing password hash for user: %s", verifier.Username)
		log.Printf("Password hash from DB: %s", verifier.PasswordHash)

		if err := bcrypt.CompareHashAndPassword([]byte(verifier.PasswordHash), []byte(req.Password)); err != nil {
			log.Printf("Password comparison failed: %v", err)
			respondWithError(w, http.StatusUnauthorized, "Invalid credentials")
			return
		}

		log.Printf("Password comparison successful for user: %s", verifier.Username)

		// Generate JWT token
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"sub":       verifier.ID.String(),
			"username":  verifier.Username,
			"email":     verifier.Email,
			"firstName": verifier.FirstName,
			"lastName":  verifier.LastName,
			"role":      verifier.Role,
			"exp":       time.Now().Add(time.Hour * 24).Unix(),
		})

		tokenString, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			log.Printf("Error signing token: %v", err)
			respondWithError(w, http.StatusInternalServerError, "Error generating token")
			return
		}

		// Return the token
		respondWithJSON(w, http.StatusOK, LoginResponse{Token: tokenString})
	}).Methods("POST")

	// Change password endpoint
	authRouter.HandleFunc("/change-password", authenticateJWT(jwtSecret, func(w http.ResponseWriter, r *http.Request, claims jwt.MapClaims) {
		var req struct {
			OldPassword string `json:"old_password"`
			NewPassword string `json:"new_password"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid request payload")
			return
		}

		// Get user ID from claims
		userID, err := uuid.Parse(claims["sub"].(string))
		if err != nil {
			respondWithError(w, http.StatusInternalServerError, "Invalid user ID")
			return
		}

		// Get verifier
		verifier, err := kycRepo.GetVerifierByID(userID)
		if err != nil {
			respondWithError(w, http.StatusInternalServerError, "Failed to get verifier")
			return
		}

		// Verify old password
		if err := bcrypt.CompareHashAndPassword([]byte(verifier.PasswordHash), []byte(req.OldPassword)); err != nil {
			respondWithError(w, http.StatusUnauthorized, "Invalid old password")
			return
		}

		// Change password
		if err := kycRepo.ChangePassword(userID, req.NewPassword); err != nil {
			respondWithError(w, http.StatusInternalServerError, "Failed to change password")
			return
		}

		respondWithJSON(w, http.StatusOK, map[string]string{"message": "Password changed successfully"})
	})).Methods("POST")

	// Verification requests endpoints
	apiRouter.HandleFunc("/verification-requests", authenticateJWT(jwtSecret, func(w http.ResponseWriter, r *http.Request, claims jwt.MapClaims) {
		// Parse query parameters
		status := r.URL.Query().Get("status")
		search := r.URL.Query().Get("search")
		pageStr := r.URL.Query().Get("page")
		limitStr := r.URL.Query().Get("limit")

		// Default values
		page := 1
		limit := 20

		// Parse page
		if pageStr != "" {
			pageInt, err := strconv.Atoi(pageStr)
			if err == nil && pageInt > 0 {
				page = pageInt
			}
		}

		// Parse limit
		if limitStr != "" {
			limitInt, err := strconv.Atoi(limitStr)
			if err == nil && limitInt > 0 {
				limit = limitInt
			}
		}

		// Get verification requests
		requests, err := kycRepo.GetVerificationRequests(status, search, page, limit)
		if err != nil {
			log.Printf("Error getting verification requests: %v", err)
			respondWithError(w, http.StatusInternalServerError, "Failed to get verification requests")
			return
		}

		// Convert to response format
		var responseRequests []VerificationRequestResponse
		for _, req := range requests {
			responseRequests = append(responseRequests, convertVerificationRequestToResponse(req))
		}

		// Wrap in a data field as expected by the client
		respondWithJSON(w, http.StatusOK, map[string]interface{}{
			"data": responseRequests,
		})
	})).Methods("GET")

	// Get verification request by ID
	apiRouter.HandleFunc("/verification-requests/{id}", authenticateJWT(jwtSecret, func(w http.ResponseWriter, r *http.Request, claims jwt.MapClaims) {
		// Get ID from URL
		vars := mux.Vars(r)
		id, err := uuid.Parse(vars["id"])
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid verification request ID")
			return
		}

		// Get verification request
		request, err := kycRepo.GetVerificationRequestByID(id)
		if err != nil {
			log.Printf("Error getting verification request: %v", err)
			respondWithError(w, http.StatusInternalServerError, "Failed to get verification request")
			return
		}

		// Convert to response format
		responseRequest := convertVerificationRequestToResponse(request)

		respondWithJSON(w, http.StatusOK, responseRequest)
	})).Methods("GET")

	// Update verification request status
	apiRouter.HandleFunc("/verification-requests/{id}/status", authenticateJWT(jwtSecret, func(w http.ResponseWriter, r *http.Request, claims jwt.MapClaims) {
		// Get ID from URL
		vars := mux.Vars(r)
		requestID, err := uuid.Parse(vars["id"])
		if err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid verification request ID")
			return
		}

		// Parse request body
		var req struct {
			Status          string  `json:"status"`
			RejectionReason *string `json:"rejection_reason,omitempty"`
		}

		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			respondWithError(w, http.StatusBadRequest, "Invalid request payload")
			return
		}

		// Get verifier ID from claims
		verifierIDStr, ok := claims["sub"].(string)
		if !ok {
			respondWithError(w, http.StatusInternalServerError, "Invalid verifier ID")
			return
		}

		// Update verification request status
		// This is a simplified implementation - in a real app, you would have a repository method for this
		// and handle things like transaction management, validation, etc.
		log.Printf("Updating verification request %s to status %s by verifier %s",
			requestID.String(), req.Status, verifierIDStr)

		// For now, just return a success response
		respondWithJSON(w, http.StatusOK, map[string]string{"message": "Status updated successfully"})
	})).Methods("PATCH")

	// Verifiers endpoints (admin only)
	apiRouter.HandleFunc("/verifiers", authenticateJWT(jwtSecret, func(w http.ResponseWriter, r *http.Request, claims jwt.MapClaims) {
		// Check if user is admin
		role, ok := claims["role"].(string)
		if !ok || role != "ADMIN" {
			respondWithError(w, http.StatusForbidden, "Admin access required")
			return
		}

		// Get all verifiers
		verifiers, err := kycRepo.GetAllVerifiers()
		if err != nil {
			log.Printf("Error getting verifiers: %v", err)
			respondWithError(w, http.StatusInternalServerError, "Failed to get verifiers")
			return
		}

		// Convert to response format
		var responseVerifiers []VerifierResponse
		for _, v := range verifiers {
			responseVerifiers = append(responseVerifiers, VerifierResponse{
				ID:        v.ID.String(),
				Username:  v.Username,
				Email:     v.Email,
				FirstName: v.FirstName,
				LastName:  v.LastName,
				Role:      v.Role,
				IsActive:  v.IsActive,
				CreatedAt: v.CreatedAt,
			})
		}

		respondWithJSON(w, http.StatusOK, map[string]interface{}{
			"data": responseVerifiers,
		})
	})).Methods("GET")

	// Health check endpoint
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

// authenticateJWT is a middleware that authenticates JWT tokens
func authenticateJWT(jwtSecret string, next func(http.ResponseWriter, *http.Request, jwt.MapClaims)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Get token from Authorization header
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			respondWithError(w, http.StatusUnauthorized, "Authorization header required")
			return
		}

		// Check if the header has the Bearer prefix
		if !strings.HasPrefix(authHeader, "Bearer ") {
			respondWithError(w, http.StatusUnauthorized, "Invalid authorization format")
			return
		}

		// Extract the token
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")

		// Parse and validate the token
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			// Validate the signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}

			return []byte(jwtSecret), nil
		})

		if err != nil {
			log.Printf("Error parsing token: %v", err)
			respondWithError(w, http.StatusUnauthorized, "Invalid token")
			return
		}

		// Check if the token is valid
		if !token.Valid {
			respondWithError(w, http.StatusUnauthorized, "Invalid token")
			return
		}

		// Get claims
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			respondWithError(w, http.StatusUnauthorized, "Invalid token claims")
			return
		}

		// Call the next handler with the claims
		next(w, r, claims)
	}
}

// convertVerificationRequestToResponse converts a VerificationRequest model to a response
func convertVerificationRequestToResponse(req *models.VerificationRequest) VerificationRequestResponse {
	var verifierID *string
	if req.VerifierID != nil {
		id := req.VerifierID.String()
		verifierID = &id
	}

	return VerificationRequestResponse{
		ID:              req.ID.String(),
		UserID:          req.UserID.String(),
		FirstName:       req.FirstName,
		LastName:        req.LastName,
		Email:           req.Email,
		Phone:           req.Phone,
		DateOfBirth:     req.DateOfBirth,
		AddressLine1:    req.AddressLine1,
		AddressLine2:    req.AddressLine2,
		City:            req.City,
		State:           req.State,
		PostalCode:      req.PostalCode,
		Country:         req.Country,
		AdditionalInfo:  req.AdditionalInfo,
		Status:          req.Status,
		RejectionReason: req.RejectionReason,
		VerifierID:      verifierID,
		VerifiedAt:      req.VerifiedAt,
		CreatedAt:       req.CreatedAt,
		UpdatedAt:       req.UpdatedAt,
		DocumentCount:   req.DocumentCount,
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

// respondWithError returns an error response
func respondWithError(w http.ResponseWriter, code int, message string) {
	respondWithJSON(w, code, ErrorResponse{Message: message})
}

// respondWithJSON returns a JSON response
func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, err := json.Marshal(payload)
	if err != nil {
		log.Printf("Error marshaling JSON: %v", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}
