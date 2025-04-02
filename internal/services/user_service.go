package services

import (
"context"
"errors"
"time"

"github.com/google/uuid"
"golang.org/x/crypto/bcrypt"
)

// UserRepository defines the user repository interface
type UserRepository interface {
GetByID(ctx context.Context, id string) (*User, error)
GetByUsername(ctx context.Context, username string) (*User, error)
GetByEmail(ctx context.Context, email string) (*User, error)
Create(ctx context.Context, user *User) error
Update(ctx context.Context, user *User) error
Delete(ctx context.Context, id string) error
}

// User represents a user entity
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
Password     string
PasswordHash []byte
RiskProfile  string
CreatedAt    time.Time
UpdatedAt    time.Time
DeviceID     string
KYCStatus    string
KYCVerifiedAt *time.Time
IsActive     bool
}

// UserService handles business logic for users
type UserService struct {
repo UserRepository
}

// NewUserService creates a new UserService
func NewUserService(repo UserRepository) *UserService {
return &UserService{
repo: repo,
}
}

// GetUserByID retrieves a user by ID
func (s *UserService) GetUserByID(ctx context.Context, id string) (*User, error) {
return s.repo.GetByID(ctx, id)
}

// CreateUser creates a new user
func (s *UserService) CreateUser(ctx context.Context, user *User) error {
// Validate user input
if user.Username == "" || user.Email == "" || user.FirstName == "" || user.LastName == "" {
return errors.New("missing required fields")
}

// Check if username or email already exists
existingByUsername, _ := s.repo.GetByUsername(ctx, user.Username)
if existingByUsername != nil {
return errors.New("username already exists")
}

existingByEmail, _ := s.repo.GetByEmail(ctx, user.Email)
if existingByEmail != nil {
return errors.New("email already exists")
}

// Generate ID if not provided
if user.ID == "" {
user.ID = uuid.New().String()
}

// Hash password if provided
if user.Password != "" {
hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
if err != nil {
return err
}
user.PasswordHash = hashedPassword
}

// Set default values
user.CreatedAt = time.Now()
user.UpdatedAt = time.Now()
user.IsActive = true
user.KYCStatus = "PENDING"

// Save user to database
return s.repo.Create(ctx, user)
}

// UpdateUser updates an existing user
func (s *UserService) UpdateUser(ctx context.Context, user *User) error {
// Validate user input
if user.ID == "" {
return errors.New("user ID is required")
}

// Get existing user
existingUser, err := s.repo.GetByID(ctx, user.ID)
if err != nil {
return err
}

if existingUser == nil {
return errors.New("user not found")
}

// Update fields
if user.Username != "" && user.Username != existingUser.Username {
// Check if new username is already taken
existingByUsername, _ := s.repo.GetByUsername(ctx, user.Username)
if existingByUsername != nil && existingByUsername.ID != user.ID {
return errors.New("username already exists")
}
existingUser.Username = user.Username
}

if user.Email != "" && user.Email != existingUser.Email {
// Check if new email is already taken
existingByEmail, _ := s.repo.GetByEmail(ctx, user.Email)
if existingByEmail != nil && existingByEmail.ID != user.ID {
return errors.New("email already exists")
}
existingUser.Email = user.Email
}

// Update other fields
if user.FirstName != "" {
existingUser.FirstName = user.FirstName
}

if user.LastName != "" {
existingUser.LastName = user.LastName
}

if !user.DateOfBirth.IsZero() {
existingUser.DateOfBirth = user.DateOfBirth
}

if user.PhoneNumber != "" {
existingUser.PhoneNumber = user.PhoneNumber
}

if user.Street != "" {
existingUser.Street = user.Street
}

if user.City != "" {
existingUser.City = user.City
}

if user.State != "" {
existingUser.State = user.State
}

if user.ZipCode != "" {
existingUser.ZipCode = user.ZipCode
}

if user.Country != "" {
existingUser.Country = user.Country
}

if user.RiskProfile != "" {
existingUser.RiskProfile = user.RiskProfile
}

// Update password if provided
if user.Password != "" {
hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
if err != nil {
return err
}
existingUser.PasswordHash = hashedPassword
}

// Update timestamp
existingUser.UpdatedAt = time.Now()

// Save updated user
return s.repo.Update(ctx, existingUser)
}

// DeleteUser deletes a user by ID
func (s *UserService) DeleteUser(ctx context.Context, id string) error {
return s.repo.Delete(ctx, id)
}
