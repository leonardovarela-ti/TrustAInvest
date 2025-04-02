package db

import (
"context"
"errors"
"fmt"
"time"

"github.com/jackc/pgx/v4/pgxpool"
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

// User represents a user entity in the database
type User struct {
ID           string
Username     string
Email        string
PhoneNumber  string
FirstName    string
LastName     string
DateOfBirth  time.Time
Street       string
City         string
State        string
ZipCode      string
Country      string
SSNEncrypted []byte
RiskProfile  string
CreatedAt    time.Time
UpdatedAt    time.Time
DeviceID     string
KYCStatus    string
KYCVerifiedAt *time.Time
IsActive     bool
}

// GetByID retrieves a user by ID
func (r *UserRepository) GetByID(ctx context.Context, id string) (*User, error) {
query := `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE id = $1 AND is_active = true
`

var user User
err := r.db.QueryRow(ctx, query, id).Scan(
&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
&user.DateOfBirth, &user.Street, &user.City, &user.State, &user.ZipCode, &user.Country,
&user.SSNEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
&user.DeviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
)

if err != nil {
return nil, fmt.Errorf("error getting user by ID: %w", err)
}

return &user, nil
}

// Create inserts a new user into the database
func (r *UserRepository) Create(ctx context.Context, user *User) error {
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
user.DateOfBirth, user.Street, user.City, user.State, user.ZipCode, user.Country,
user.SSNEncrypted, user.RiskProfile, user.DeviceID, user.KYCStatus, user.IsActive,
)

if err != nil {
return fmt.Errorf("error creating user: %w", err)
}

return nil
}

// Update updates an existing user in the database
func (r *UserRepository) Update(ctx context.Context, user *User) error {
query := `
UPDATE users.users
SET username = $2, email = $3, phone_number = $4, first_name = $5, last_name = $6,
date_of_birth = $7, street = $8, city = $9, state = $10, zip_code = $11, country = $12,
risk_profile = $13, updated_at = NOW()
WHERE id = $1 AND is_active = true
`

result, err := r.db.Exec(ctx, query,
user.ID, user.Username, user.Email, user.PhoneNumber, user.FirstName, user.LastName,
user.DateOfBirth, user.Street, user.City, user.State, user.ZipCode, user.Country,
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

// GetByUsername retrieves a user by username
func (r *UserRepository) GetByUsername(ctx context.Context, username string) (*User, error) {
query := `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE username = $1 AND is_active = true
`

var user User
err := r.db.QueryRow(ctx, query, username).Scan(
&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
&user.DateOfBirth, &user.Street, &user.City, &user.State, &user.ZipCode, &user.Country,
&user.SSNEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
&user.DeviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
)

if err != nil {
return nil, fmt.Errorf("error getting user by username: %w", err)
}

return &user, nil
}
