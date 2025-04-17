package db

import (
	"database/sql"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	_ "github.com/lib/pq" // PostgreSQL driver
	"golang.org/x/crypto/bcrypt"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
)

// KYCVerifierRepository handles database operations for KYC verifiers
type KYCVerifierRepository struct {
	DB *sql.DB
}

// NewKYCVerifierRepository creates a new KYC verifier repository
func NewKYCVerifierRepository(db *sql.DB) *KYCVerifierRepository {
	return &KYCVerifierRepository{
		DB: db,
	}
}

// GetVerifierByUsername gets a verifier by username
func (r *KYCVerifierRepository) GetVerifierByUsername(username string) (*models.Verifier, error) {
	var verifier models.Verifier
	var updatedAt sql.NullTime

	err := r.DB.QueryRow(`
		SELECT id, username, email, password_hash, first_name, last_name, role, is_active, created_at, updated_at
		FROM kyc.verifiers
		WHERE username = $1
	`, username).Scan(
		&verifier.ID,
		&verifier.Username,
		&verifier.Email,
		&verifier.PasswordHash,
		&verifier.FirstName,
		&verifier.LastName,
		&verifier.Role,
		&verifier.IsActive,
		&verifier.CreatedAt,
		&updatedAt,
	)

	if err != nil {
		return nil, err
	}

	if updatedAt.Valid {
		verifier.UpdatedAt = &updatedAt.Time
	}

	return &verifier, nil
}

// GetVerifierByID gets a verifier by ID
func (r *KYCVerifierRepository) GetVerifierByID(id uuid.UUID) (*models.Verifier, error) {
	var verifier models.Verifier
	var updatedAt sql.NullTime

	err := r.DB.QueryRow(`
		SELECT id, username, email, password_hash, first_name, last_name, role, is_active, created_at, updated_at
		FROM kyc.verifiers
		WHERE id = $1
	`, id).Scan(
		&verifier.ID,
		&verifier.Username,
		&verifier.Email,
		&verifier.PasswordHash,
		&verifier.FirstName,
		&verifier.LastName,
		&verifier.Role,
		&verifier.IsActive,
		&verifier.CreatedAt,
		&updatedAt,
	)

	if err != nil {
		return nil, err
	}

	if updatedAt.Valid {
		verifier.UpdatedAt = &updatedAt.Time
	}

	return &verifier, nil
}

// GetAllVerifiers gets all verifiers
func (r *KYCVerifierRepository) GetAllVerifiers() ([]*models.Verifier, error) {
	rows, err := r.DB.Query(`
		SELECT id, username, email, password_hash, first_name, last_name, role, is_active, created_at, updated_at
		FROM kyc.verifiers
		ORDER BY created_at DESC
	`)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var verifiers []*models.Verifier
	for rows.Next() {
		var verifier models.Verifier
		var updatedAt sql.NullTime

		err := rows.Scan(
			&verifier.ID,
			&verifier.Username,
			&verifier.Email,
			&verifier.PasswordHash,
			&verifier.FirstName,
			&verifier.LastName,
			&verifier.Role,
			&verifier.IsActive,
			&verifier.CreatedAt,
			&updatedAt,
		)

		if err != nil {
			return nil, err
		}

		if updatedAt.Valid {
			verifier.UpdatedAt = &updatedAt.Time
		}

		verifiers = append(verifiers, &verifier)
	}

	return verifiers, nil
}

// CreateVerifier creates a new verifier
func (r *KYCVerifierRepository) CreateVerifier(verifier *models.Verifier, password string) error {
	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	// Generate UUID if not provided
	if verifier.ID == uuid.Nil {
		verifier.ID = uuid.New()
	}

	// Set created_at if not provided
	if verifier.CreatedAt.IsZero() {
		verifier.CreatedAt = time.Now()
	}

	// Insert verifier
	_, err = r.DB.Exec(`
		INSERT INTO kyc.verifiers (
			id, username, email, password_hash, first_name, last_name, role, is_active, created_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9
		)
	`,
		verifier.ID,
		verifier.Username,
		verifier.Email,
		string(hashedPassword),
		verifier.FirstName,
		verifier.LastName,
		verifier.Role,
		verifier.IsActive,
		verifier.CreatedAt,
	)

	return err
}

// UpdateVerifier updates a verifier
func (r *KYCVerifierRepository) UpdateVerifier(verifier *models.Verifier) error {
	// Update verifier
	_, err := r.DB.Exec(`
		UPDATE kyc.verifiers
		SET 
			email = $1,
			first_name = $2,
			last_name = $3,
			role = $4,
			is_active = $5
		WHERE id = $6
	`,
		verifier.Email,
		verifier.FirstName,
		verifier.LastName,
		verifier.Role,
		verifier.IsActive,
		verifier.ID,
	)

	return err
}

// DeleteVerifier deletes a verifier
func (r *KYCVerifierRepository) DeleteVerifier(id uuid.UUID) error {
	_, err := r.DB.Exec(`
		DELETE FROM kyc.verifiers
		WHERE id = $1
	`, id)

	return err
}

// ChangePassword changes a verifier's password
func (r *KYCVerifierRepository) ChangePassword(id uuid.UUID, newPassword string) error {
	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	// Update password
	_, err = r.DB.Exec(`
		UPDATE kyc.verifiers
		SET password_hash = $1
		WHERE id = $2
	`, string(hashedPassword), id)

	return err
}

// UpdateVerificationRequestStatus updates the status of a verification request
func (r *KYCVerifierRepository) UpdateVerificationRequestStatus(requestID uuid.UUID, status string, verifierID uuid.UUID, rejectionReason *string) error {
	now := time.Now()

	// Start a transaction
	tx, err := r.DB.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	// Defer rollback in case of error
	defer func() {
		if p := recover(); p != nil {
			tx.Rollback()
			panic(p) // re-throw panic after rollback
		} else if err != nil {
			tx.Rollback()
		}
	}()

	// Log the transaction start
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Starting transaction for updating verification request status')"); err != nil {
		return fmt.Errorf("failed to log transaction start: %w", err)
	}

	// Log the request ID and status
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Updating request ID: " + requestID.String() + " to status: " + status + "')"); err != nil {
		return fmt.Errorf("failed to log request details: %w", err)
	}

	// Get the user ID for the verification request
	var userID uuid.UUID
	err = tx.QueryRow("SELECT user_id FROM kyc.verification_requests WHERE id = $1", requestID).Scan(&userID)
	if err != nil {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'Error getting user_id: " + err.Error() + "')")
		return fmt.Errorf("failed to get user_id: %w", err)
	}

	// Log the user ID
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'User ID associated with request: " + userID.String() + "')"); err != nil {
		return fmt.Errorf("failed to log user ID: %w", err)
	}

	// Get the current status of the verification request
	var currentStatus string
	err = tx.QueryRow("SELECT status FROM kyc.verification_requests WHERE id = $1", requestID).Scan(&currentStatus)
	if err != nil {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'Error getting current status: " + err.Error() + "')")
		return fmt.Errorf("failed to get current status: %w", err)
	}

	// Log the current status
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Current status before update: " + currentStatus + "')"); err != nil {
		return fmt.Errorf("failed to log current status: %w", err)
	}

	// Get the current KYC status of the user
	var currentUserKYCStatus string
	err = tx.QueryRow("SELECT kyc_status FROM users.users WHERE id = $1", userID).Scan(&currentUserKYCStatus)
	if err != nil {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'Error getting current user KYC status: " + err.Error() + "')")
		return fmt.Errorf("failed to get current user KYC status: %w", err)
	}

	// Log the current user KYC status
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Current user KYC status before update: " + currentUserKYCStatus + "')"); err != nil {
		return fmt.Errorf("failed to log current user KYC status: %w", err)
	}

	// Update the verification request
	var query string
	var args []interface{}

	if status == "VERIFIED" {
		query = `
			UPDATE kyc.verification_requests
			SET status = $1, provider_request_id = $2, updated_at = $3, completed_at = $4
			WHERE id = $5
		`
		args = []interface{}{status, verifierID, now, now, requestID}
	} else if status == "REJECTED" {
		query = `
			UPDATE kyc.verification_requests
			SET status = $1, provider_request_id = $2, updated_at = $3, completed_at = $4, rejection_reason = $5
			WHERE id = $6
		`
		args = []interface{}{status, verifierID, now, now, rejectionReason, requestID}
	} else {
		query = `
			UPDATE kyc.verification_requests
			SET status = $1, provider_request_id = $2, updated_at = $3
			WHERE id = $4
		`
		args = []interface{}{status, verifierID, now, requestID}
	}

	// Log the query being executed
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Executing verification request update query')"); err != nil {
		return fmt.Errorf("failed to log query execution: %w", err)
	}

	// Execute the update
	result, err := tx.Exec(query, args...)
	if err != nil {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'Error updating verification request: " + err.Error() + "')")
		return fmt.Errorf("failed to update verification request: %w", err)
	}

	// Log the number of rows affected
	rowsAffected, _ := result.RowsAffected()
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Rows affected by verification request update: " + strconv.FormatInt(rowsAffected, 10) + "')"); err != nil {
		return fmt.Errorf("failed to log rows affected: %w", err)
	}

	// Directly update the user's KYC status in the same transaction
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Directly updating users.users table with KYC status: " + status + "')"); err != nil {
		return fmt.Errorf("failed to log user update: %w", err)
	}

	// Update the user's KYC status
	updateUserQuery := `
		UPDATE users.users 
		SET kyc_status = $1, updated_at = $2 
		WHERE id = $3
	`
	userUpdateResult, err := tx.Exec(updateUserQuery, status, now, userID)
	if err != nil {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'Error updating user KYC status: " + err.Error() + "')")
		return fmt.Errorf("failed to update user KYC status: %w", err)
	}

	// Log the number of rows affected by the user update
	userRowsAffected, _ := userUpdateResult.RowsAffected()
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Rows affected by user update: " + strconv.FormatInt(userRowsAffected, 10) + "')"); err != nil {
		return fmt.Errorf("failed to log user rows affected: %w", err)
	}

	// Verify the update was successful
	var finalUserKYCStatus string
	err = tx.QueryRow("SELECT kyc_status FROM users.users WHERE id = $1", userID).Scan(&finalUserKYCStatus)
	if err != nil {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'Error checking final user KYC status: " + err.Error() + "')")
		return fmt.Errorf("failed to verify user KYC status update: %w", err)
	}

	// Log the final user KYC status
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Final user KYC status after update: " + finalUserKYCStatus + "')"); err != nil {
		return fmt.Errorf("failed to log final user KYC status: %w", err)
	}

	// Check if the update was actually applied
	if finalUserKYCStatus != status {
		_, _ = tx.Exec("SELECT pg_notify('kyc_log', 'WARNING: User KYC status was not updated correctly. Expected: " + status + ", Got: " + finalUserKYCStatus + "')")
		return fmt.Errorf("user KYC status was not updated correctly. Expected: %s, Got: %s", status, finalUserKYCStatus)
	}

	// Log before commit
	if _, err = tx.Exec("SELECT pg_notify('kyc_log', 'Committing transaction')"); err != nil {
		return fmt.Errorf("failed to log commit: %w", err)
	}

	// Commit the transaction
	if err = tx.Commit(); err != nil {
		_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error committing transaction: " + err.Error() + "')")
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Log after commit (this will be in a new transaction)
	_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Transaction committed successfully')")

	// Double-check that the user's KYC status was updated correctly after the transaction
	var finalUserKYCStatusAfterCommit string
	err = r.DB.QueryRow("SELECT kyc_status FROM users.users WHERE id = $1", userID).Scan(&finalUserKYCStatusAfterCommit)
	if err != nil {
		_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error checking final user KYC status after commit: " + err.Error() + "')")
		return fmt.Errorf("failed to verify user KYC status update after commit: %w", err)
	}

	// Log the final user KYC status after commit
	_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Final user KYC status after commit: " + finalUserKYCStatusAfterCommit + "')")

	// If the status is still not updated, try a direct update outside the transaction
	if finalUserKYCStatusAfterCommit != status {
		_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'WARNING: User KYC status still not updated after commit. Attempting direct update.')")

		// Direct update as a last resort
		_, err = r.DB.Exec("UPDATE users.users SET kyc_status = $1, updated_at = $2 WHERE id = $3", status, time.Now(), userID)
		if err != nil {
			_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error in direct update of user KYC status: " + err.Error() + "')")
			return fmt.Errorf("failed in direct update of user KYC status: %w", err)
		}

		// Verify the direct update
		err = r.DB.QueryRow("SELECT kyc_status FROM users.users WHERE id = $1", userID).Scan(&finalUserKYCStatusAfterCommit)
		if err != nil {
			_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error checking user KYC status after direct update: " + err.Error() + "')")
			return fmt.Errorf("failed to verify user KYC status after direct update: %w", err)
		}

		_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'User KYC status after direct update: " + finalUserKYCStatusAfterCommit + "')")

		if finalUserKYCStatusAfterCommit != status {
			_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'CRITICAL ERROR: User KYC status could not be updated even with direct update!')")
			return fmt.Errorf("critical error: user KYC status could not be updated even with direct update")
		}

		_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'User KYC status successfully updated with direct update')")
	}

	return nil
}

// GetVerificationRequests gets verification requests with optional filters
func (r *KYCVerifierRepository) GetVerificationRequests(status string, search string, page, limit int) ([]*models.VerificationRequest, error) {
	// Build query
	query := `
		SELECT 
			vr.id, vr.user_id, 
			vr.request_data->>'first_name' as first_name, 
			vr.request_data->>'last_name' as last_name, 
			vr.request_data->>'email' as email, 
			vr.request_data->>'phone' as phone,
			(vr.request_data->>'date_of_birth')::date as date_of_birth, 
			vr.request_data->>'address_line1' as address_line1, 
			vr.request_data->>'address_line2' as address_line2, 
			vr.request_data->>'city' as city, 
			vr.request_data->>'state' as state,
			vr.request_data->>'postal_code' as postal_code, 
			vr.request_data->>'country' as country, 
			vr.request_data->>'additional_info' as additional_info, 
			vr.status, vr.rejection_reason,
			vr.provider_request_id as verifier_id, 
			vr.completed_at as verified_at, 
			vr.created_at, vr.updated_at,
			(SELECT COUNT(*) FROM kyc.documents WHERE verification_request_id = vr.id) as document_count
		FROM kyc.verification_requests vr
		WHERE 1=1
	`

	args := []interface{}{}
	argCount := 1

	// Add status filter
	if status != "" {
		query += " AND vr.status = $" + strconv.Itoa(argCount)
		args = append(args, status)
		argCount++
	}

	// Add search filter
	if search != "" {
		query += " AND (vr.request_data->>'first_name' ILIKE $" + strconv.Itoa(argCount) +
			" OR vr.request_data->>'last_name' ILIKE $" + strconv.Itoa(argCount) +
			" OR vr.request_data->>'email' ILIKE $" + strconv.Itoa(argCount) + ")"
		args = append(args, "%"+search+"%")
		argCount++
	}

	// Add pagination
	query += " ORDER BY vr.created_at DESC LIMIT $" + strconv.Itoa(argCount) + " OFFSET $" + strconv.Itoa(argCount+1)
	args = append(args, limit, (page-1)*limit)

	// Execute query
	rows, err := r.DB.Query(query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	// Parse results
	var requests []*models.VerificationRequest
	for rows.Next() {
		var req models.VerificationRequest
		var firstName, lastName, email, phone, addressLine1, addressLine2, city, state, postalCode, country, additionalInfo, rejectionReason sql.NullString
		var verifierID sql.NullString
		var verifiedAt, updatedAt sql.NullTime
		var documentCount sql.NullInt64
		var dateOfBirthStr sql.NullString

		err := rows.Scan(
			&req.ID,
			&req.UserID,
			&firstName,
			&lastName,
			&email,
			&phone,
			&dateOfBirthStr,
			&addressLine1,
			&addressLine2,
			&city,
			&state,
			&postalCode,
			&country,
			&additionalInfo,
			&req.Status,
			&rejectionReason,
			&verifierID,
			&verifiedAt,
			&req.CreatedAt,
			&updatedAt,
			&documentCount,
		)

		if err != nil {
			return nil, err
		}

		// Handle required string fields that might be NULL
		if firstName.Valid {
			req.FirstName = firstName.String
		} else {
			req.FirstName = "" // or set to a default value if needed
		}

		if lastName.Valid {
			req.LastName = lastName.String
		} else {
			req.LastName = "" // or set to a default value if needed
		}

		if email.Valid {
			req.Email = email.String
		} else {
			req.Email = "" // or set to a default value if needed
		}

		if addressLine1.Valid {
			req.AddressLine1 = addressLine1.String
		} else {
			req.AddressLine1 = "" // or set to a default value if needed
		}

		if city.Valid {
			req.City = city.String
		} else {
			req.City = "" // or set to a default value if needed
		}

		if state.Valid {
			req.State = state.String
		} else {
			req.State = "" // or set to a default value if needed
		}

		if postalCode.Valid {
			req.PostalCode = postalCode.String
		} else {
			req.PostalCode = "" // or set to a default value if needed
		}

		if country.Valid {
			req.Country = country.String
		} else {
			req.Country = "" // or set to a default value if needed
		}

		// Parse date of birth
		if dateOfBirthStr.Valid && dateOfBirthStr.String != "" {
			dob, err := time.Parse("2006-01-02", dateOfBirthStr.String)
			if err == nil {
				req.DateOfBirth = dob
			}
		}

		// Handle nullable fields
		if phone.Valid {
			phoneStr := phone.String
			req.Phone = &phoneStr
		}

		if addressLine2.Valid {
			addrLine2 := addressLine2.String
			req.AddressLine2 = &addrLine2
		}

		if additionalInfo.Valid {
			addInfo := additionalInfo.String
			req.AdditionalInfo = &addInfo
		}

		if rejectionReason.Valid {
			rejReason := rejectionReason.String
			req.RejectionReason = &rejReason
		}

		if verifierID.Valid {
			// Try to parse as UUID
			verID, err := uuid.Parse(verifierID.String)
			if err == nil {
				req.VerifierID = &verID
			}
		}

		if verifiedAt.Valid {
			req.VerifiedAt = &verifiedAt.Time
		}

		if updatedAt.Valid {
			req.UpdatedAt = &updatedAt.Time
		}

		if documentCount.Valid {
			req.DocumentCount = int(documentCount.Int64)
		}

		requests = append(requests, &req)
	}

	return requests, nil
}

// GetVerificationRequestCountByStatus gets the count of verification requests with a specific status
func (r *KYCVerifierRepository) GetVerificationRequestCountByStatus(status string) (int, error) {
	var count int
	err := r.DB.QueryRow(`
		SELECT COUNT(*) 
		FROM kyc.verification_requests 
		WHERE status = $1
	`, status).Scan(&count)

	if err != nil {
		return 0, err
	}

	return count, nil
}

// GetVerificationRequestByID gets a verification request by ID
func (r *KYCVerifierRepository) GetVerificationRequestByID(id uuid.UUID) (*models.VerificationRequest, error) {
	var req models.VerificationRequest
	var firstName, lastName, email, phone, addressLine1, addressLine2, city, state, postalCode, country, additionalInfo, rejectionReason sql.NullString
	var verifierID sql.NullString
	var verifiedAt, updatedAt sql.NullTime
	var documentCount int
	var dateOfBirthStr sql.NullString

	err := r.DB.QueryRow(`
		SELECT 
			vr.id, vr.user_id, 
			vr.request_data->>'first_name' as first_name, 
			vr.request_data->>'last_name' as last_name, 
			vr.request_data->>'email' as email, 
			vr.request_data->>'phone' as phone,
			(vr.request_data->>'date_of_birth')::date as date_of_birth, 
			vr.request_data->>'address_line1' as address_line1, 
			vr.request_data->>'address_line2' as address_line2, 
			vr.request_data->>'city' as city, 
			vr.request_data->>'state' as state,
			vr.request_data->>'postal_code' as postal_code, 
			vr.request_data->>'country' as country, 
			vr.request_data->>'additional_info' as additional_info, 
			vr.status, vr.rejection_reason,
			vr.provider_request_id as verifier_id, 
			vr.completed_at as verified_at, 
			vr.created_at, vr.updated_at,
			(SELECT COUNT(*) FROM kyc.documents WHERE verification_request_id = vr.id) as document_count
		FROM kyc.verification_requests vr
		WHERE vr.id = $1
	`, id).Scan(
		&req.ID,
		&req.UserID,
		&firstName,
		&lastName,
		&email,
		&phone,
		&dateOfBirthStr,
		&addressLine1,
		&addressLine2,
		&city,
		&state,
		&postalCode,
		&country,
		&additionalInfo,
		&req.Status,
		&rejectionReason,
		&verifierID,
		&verifiedAt,
		&req.CreatedAt,
		&updatedAt,
		&documentCount,
	)

	if err != nil {
		return nil, err
	}

	// Handle required string fields that might be NULL
	if firstName.Valid {
		req.FirstName = firstName.String
	} else {
		req.FirstName = "" // or set to a default value if needed
	}

	if lastName.Valid {
		req.LastName = lastName.String
	} else {
		req.LastName = "" // or set to a default value if needed
	}

	if email.Valid {
		req.Email = email.String
	} else {
		req.Email = "" // or set to a default value if needed
	}

	if addressLine1.Valid {
		req.AddressLine1 = addressLine1.String
	} else {
		req.AddressLine1 = "" // or set to a default value if needed
	}

	if city.Valid {
		req.City = city.String
	} else {
		req.City = "" // or set to a default value if needed
	}

	if state.Valid {
		req.State = state.String
	} else {
		req.State = "" // or set to a default value if needed
	}

	if postalCode.Valid {
		req.PostalCode = postalCode.String
	} else {
		req.PostalCode = "" // or set to a default value if needed
	}

	if country.Valid {
		req.Country = country.String
	} else {
		req.Country = "" // or set to a default value if needed
	}

	// Parse date of birth
	if dateOfBirthStr.Valid && dateOfBirthStr.String != "" {
		dob, err := time.Parse("2006-01-02", dateOfBirthStr.String)
		if err == nil {
			req.DateOfBirth = dob
		}
	}

	// Handle nullable fields
	if phone.Valid {
		phoneStr := phone.String
		req.Phone = &phoneStr
	}

	if addressLine2.Valid {
		addrLine2 := addressLine2.String
		req.AddressLine2 = &addrLine2
	}

	if additionalInfo.Valid {
		addInfo := additionalInfo.String
		req.AdditionalInfo = &addInfo
	}

	if rejectionReason.Valid {
		rejReason := rejectionReason.String
		req.RejectionReason = &rejReason
	}

	if verifierID.Valid {
		// Try to parse as UUID
		verID, err := uuid.Parse(verifierID.String)
		if err == nil {
			req.VerifierID = &verID
		}
	}

	if verifiedAt.Valid {
		req.VerifiedAt = &verifiedAt.Time
	}

	if updatedAt.Valid {
		req.UpdatedAt = &updatedAt.Time
	}

	req.DocumentCount = documentCount

	return &req, nil
}
