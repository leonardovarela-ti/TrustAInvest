package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v4/pgxpool"
)

// KYCStatus represents the status of a KYC verification
type KYCStatus string

const (
	KYCStatusPending   KYCStatus = "PENDING"
	KYCStatusInProcess KYCStatus = "IN_PROCESS"
	KYCStatusVerified  KYCStatus = "VERIFIED"
	KYCStatusRejected  KYCStatus = "REJECTED"
	KYCStatusRetry     KYCStatus = "RETRY"
)

// KYCRequest represents a request for KYC verification
type KYCRequest struct {
	ID                 string     `json:"id"`
	UserID             string     `json:"user_id"`
	Status             KYCStatus  `json:"status"`
	CreatedAt          time.Time  `json:"created_at"`
	ProcessedAt        *time.Time `json:"processed_at,omitempty"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
	DocumentIDs        []string   `json:"document_ids"`
	VerificationMethod string     `json:"verification_method"`
	RejectionReason    *string    `json:"rejection_reason,omitempty"`
}

// Global db connection
var db *pgxpool.Pool

func main() {
	log.Println("Starting kyc-worker...")

	// Connect to database
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://trustainvest:trustainvest@postgres:5432/trustainvest"
	}

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

	// Create context that listens for signals
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Start the worker
	go processKYCRequests(ctx)

	// Wait for termination signal
	<-ctx.Done()
	log.Println("Shutting down KYC worker...")

	// Allow some time for graceful shutdown
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Perform any cleanup needed
	if err := performCleanup(shutdownCtx); err != nil {
		log.Printf("Error during shutdown: %v", err)
	}

	log.Println("KYC worker stopped")
}

func processKYCRequests(ctx context.Context) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Process pending KYC requests
			if err := processPendingRequests(ctx); err != nil {
				log.Printf("Error processing pending requests: %v", err)
			}
		}
	}
}

func processPendingRequests(ctx context.Context) error {
	// Fetch pending KYC requests
	rows, err := db.Query(ctx, `
		SELECT id, user_id, status, created_at, processed_at, 
		       completed_at, document_ids, verification_method, 
		       rejection_reason
		FROM kyc.verification_requests
		WHERE status = $1
		LIMIT 10
	`, KYCStatusPending)

	if err != nil {
		return err
	}
	defer rows.Close()

	var requests []KYCRequest
	for rows.Next() {
		var req KYCRequest
		log.Printf("Requests: %v", &req.ID)
		var documentIDs []string

		if err := rows.Scan(
			&req.ID, &req.UserID, &req.Status, &req.CreatedAt,
			&req.ProcessedAt, &req.CompletedAt, &documentIDs,
			&req.VerificationMethod, &req.RejectionReason,
		); err != nil {
			log.Printf("Error scanning KYC request: %v", err)
			continue
		}

		req.DocumentIDs = documentIDs
		requests = append(requests, req)
	}

	// Process each request
	for _, req := range requests {
		if err := processKYCRequest(ctx, req); err != nil {
			log.Printf("Error processing KYC request %s: %v", req.ID, err)
			continue
		}
	}

	return nil
}

func processKYCRequest(ctx context.Context, req KYCRequest) error {
	log.Printf("Processing KYC request for user %s", req.UserID)

	// Update status to IN_PROCESS
	now := time.Now()
	if _, err := db.Exec(ctx, `
		UPDATE kyc.verification_requests
		SET status = $1, processed_at = $2
		WHERE id = $3
	`, KYCStatusInProcess, now, req.ID); err != nil {
		return err
	}

	// Perform KYC verification (in a real system, this would call an external service)
	// For the demo, we'll simulate a verification process with random results
	verificationResult, err := simulateKYCVerification(ctx, req)
	if err != nil {
		log.Printf("Error verifying KYC for user %s: %v", req.UserID, err)

		// Mark as retry if there's a transient error
		if _, err := db.Exec(ctx, `
			UPDATE kyc.verification_requests
			SET status = $1, rejection_reason = $2
			WHERE id = $3
		`, KYCStatusRetry, "Verification service error", req.ID); err != nil {
			log.Printf("Error updating KYC request to retry: %v", err)
		}

		return err
	}

	// Update user's KYC status based on verification result
	completedAt := time.Now()
	if verificationResult.Verified {
		// Update KYC request
		if _, err := db.Exec(ctx, `
			UPDATE kyc.verification_requests
			SET status = $1, completed_at = $2
			WHERE id = $3
		`, KYCStatusVerified, completedAt, req.ID); err != nil {
			return err
		}

		// Update user record
		if _, err := db.Exec(ctx, `
			UPDATE users.users
			SET kyc_status = $1, kyc_verified_at = $2
			WHERE id = $3
		`, "VERIFIED", completedAt, req.UserID); err != nil {
			return err
		}

		log.Printf("KYC verification successful for user %s", req.UserID)
	} else {
		// Update KYC request to rejected
		if _, err := db.Exec(ctx, `
			UPDATE users.kyc_requests
			SET status = $1, completed_at = $2, rejection_reason = $3
			WHERE id = $4
		`, KYCStatusRejected, completedAt, verificationResult.Reason, req.ID); err != nil {
			return err
		}

		// Update user record
		if _, err := db.Exec(ctx, `
			UPDATE users.users
			SET kyc_status = $1
			WHERE id = $2
		`, "REJECTED", req.UserID); err != nil {
			return err
		}

		log.Printf("KYC verification rejected for user %s: %s", req.UserID, *verificationResult.Reason)
	}

	return nil
}

type VerificationResult struct {
	Verified bool
	Reason   *string
}

func simulateKYCVerification(ctx context.Context, req KYCRequest) (VerificationResult, error) {
	// In a real implementation, this would call an external KYC service API
	// For this example, we'll simulate a successful verification most of the time

	// Sleep to simulate processing time
	time.Sleep(500 * time.Millisecond)

	// Check if documents exist (simulate)
	if len(req.DocumentIDs) == 0 {
		reason := "No identity documents provided"
		return VerificationResult{
			Verified: false,
			Reason:   &reason,
		}, nil
	}

	// Simulate a verification success rate of 90%
	if time.Now().Unix()%10 == 0 {
		reason := "Identity could not be verified with provided documents"
		return VerificationResult{
			Verified: false,
			Reason:   &reason,
		}, nil
	}

	// Success case
	return VerificationResult{
		Verified: true,
		Reason:   nil,
	}, nil
}

func performCleanup(ctx context.Context) error {
	// Update any stuck IN_PROCESS requests to RETRY
	_, err := db.Exec(ctx, `
		UPDATE kyc.verification_requests
		SET status = $1, rejection_reason = $2
		WHERE status = $3 AND processed_at < $4
	`, KYCStatusRetry, "Worker shutdown while processing", KYCStatusInProcess, time.Now().Add(-1*time.Hour))

	return err
}
