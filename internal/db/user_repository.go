package db

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v4/pgxpool"
	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
)

// UserRepository handles database operations for users
type UserRepository struct {
	db *pgxpool.Pool
}

// NewUserRepository creates a new UserRepository
func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{
		db: db,
	}
}

// GetByID retrieves a user by ID
func (r *UserRepository) GetByID(ctx context.Context, id string) (*models.User, error) {
	query := `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE id = $1 AND is_active = true
`

	var user models.User
	var dateOfBirth time.Time
	var street, city, state, zipCode, country string
	var ssnEncrypted []byte
	var deviceID string

	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
		&dateOfBirth, &street, &city, &state, &zipCode, &country,
		&ssnEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
		&deviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
	)

	if err != nil {
		// Check if no rows were found
		if err.Error() == "no rows in result set" {
			return nil, nil
		}
		return nil, fmt.Errorf("error getting user by ID: %w", err)
	}

	user.DateOfBirth = dateOfBirth
	user.Address = models.Address{
		Street:  street,
		City:    city,
		State:   state,
		ZipCode: zipCode,
		Country: country,
	}

	return &user, nil
}

// GetByUsername retrieves a user by username
func (r *UserRepository) GetByUsername(ctx context.Context, username string) (*models.User, error) {
	query := `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE username = $1 AND is_active = true
`

	var user models.User
	var dateOfBirth time.Time
	var street, city, state, zipCode, country string
	var ssnEncrypted []byte
	var deviceID string

	err := r.db.QueryRow(ctx, query, username).Scan(
		&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
		&dateOfBirth, &street, &city, &state, &zipCode, &country,
		&ssnEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
		&deviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
	)

	if err != nil {
		// Check if no rows were found
		if err.Error() == "no rows in result set" {
			return nil, nil
		}
		return nil, fmt.Errorf("error getting user by username: %w", err)
	}

	user.DateOfBirth = dateOfBirth
	user.Address = models.Address{
		Street:  street,
		City:    city,
		State:   state,
		ZipCode: zipCode,
		Country: country,
	}

	return &user, nil
}

// GetByEmail retrieves a user by email
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	query := `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE email = $1 AND is_active = true
`

	var user models.User
	var dateOfBirth time.Time
	var street, city, state, zipCode, country string
	var ssnEncrypted []byte
	var deviceID string

	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
		&dateOfBirth, &street, &city, &state, &zipCode, &country,
		&ssnEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
		&deviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
	)

	if err != nil {
		// Check if no rows were found
		if err.Error() == "no rows in result set" {
			return nil, nil
		}
		return nil, fmt.Errorf("error getting user by email: %w", err)
	}

	user.DateOfBirth = dateOfBirth
	user.Address = models.Address{
		Street:  street,
		City:    city,
		State:   state,
		ZipCode: zipCode,
		Country: country,
	}

	return &user, nil
}

// GetPasswordHash retrieves a user's password hash
func (r *UserRepository) GetPasswordHash(ctx context.Context, userID string) ([]byte, error) {
	query := `
SELECT password_hash
FROM users.user_credentials
WHERE user_id = $1
`

	var passwordHash []byte
	err := r.db.QueryRow(ctx, query, userID).Scan(&passwordHash)
	if err != nil {
		if err.Error() == "no rows in result set" {
			return nil, errors.New("user credentials not found")
		}
		return nil, fmt.Errorf("error getting password hash: %w", err)
	}

	return passwordHash, nil
}

// Create inserts a new user into the database
func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	query := `
INSERT INTO users.users (
id, username, email, phone_number, first_name, last_name, 
date_of_birth, street, city, state, zip_code, country,
ssn_encrypted, risk_profile, device_id, kyc_status, is_active
) VALUES (
$1, $2, $3, $4, $5, $6, 
$7, $8, $9, $10, $11, $12,
$13, $14, $15, $16, $17
)
`

	_, err := r.db.Exec(ctx, query,
		user.ID, user.Username, user.Email, user.PhoneNumber, user.FirstName, user.LastName,
		user.DateOfBirth, user.Address.Street, user.Address.City, user.Address.State, user.Address.ZipCode, user.Address.Country,
		nil, user.RiskProfile, "", user.KYCStatus, user.IsActive,
	)

	if err != nil {
		return fmt.Errorf("error creating user: %w", err)
	}

	return nil
}

// Update updates an existing user in the database
func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	query := `
UPDATE users.users
SET username = $2, email = $3, phone_number = $4, first_name = $5, last_name = $6,
date_of_birth = $7, street = $8, city = $9, state = $10, zip_code = $11, country = $12,
risk_profile = $13, updated_at = NOW()
WHERE id = $1 AND is_active = true
`

	result, err := r.db.Exec(ctx, query,
		user.ID, user.Username, user.Email, user.PhoneNumber, user.FirstName, user.LastName,
		user.DateOfBirth, user.Address.Street, user.Address.City, user.Address.State, user.Address.ZipCode, user.Address.Country,
		user.RiskProfile,
	)

	if err != nil {
		return fmt.Errorf("error updating user: %w", err)
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("user not found")
	}

	return nil
}

// Delete soft-deletes a user by setting isActive to false
func (r *UserRepository) Delete(ctx context.Context, id string) error {
	query := `
UPDATE users.users
SET is_active = false, updated_at = NOW()
WHERE id = $1 AND is_active = true
`

	result, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting user: %w", err)
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("user not found")
	}

	return nil
}
