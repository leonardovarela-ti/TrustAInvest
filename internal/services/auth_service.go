package services

import (
	"context"
	"errors"

	"github.com/leonardovarelatrust/TrustAInvest.com/internal/models"
	"golang.org/x/crypto/bcrypt"
)

// AuthService handles authentication-related business logic
type AuthService struct {
	userRepo UserRepository
}

// NewAuthService creates a new AuthService
func NewAuthService(userRepo UserRepository) *AuthService {
	return &AuthService{
		userRepo: userRepo,
	}
}

// GetUserByID retrieves a user by ID
func (s *AuthService) GetUserByID(ctx context.Context, id string) (*models.User, error) {
	return s.userRepo.GetByID(ctx, id)
}

// GetUserByUsername retrieves a user by username
func (s *AuthService) GetUserByUsername(ctx context.Context, username string) (*models.User, error) {
	return s.userRepo.GetByUsername(ctx, username)
}

// GetUserByEmail retrieves a user by email
func (s *AuthService) GetUserByEmail(ctx context.Context, email string) (*models.User, error) {
	return s.userRepo.GetByEmail(ctx, email)
}

// VerifyPassword verifies a user's password
func (s *AuthService) VerifyPassword(ctx context.Context, username, password string) (bool, error) {
	// Get user from repository
	user, err := s.userRepo.GetByUsername(ctx, username)
	if err != nil {
		return false, err
	}

	if user == nil {
		return false, errors.New("user not found")
	}

	// Get password hash from repository
	passwordHash, err := s.userRepo.GetPasswordHash(ctx, user.ID)
	if err != nil {
		return false, err
	}

	// Compare password with hash
	err = bcrypt.CompareHashAndPassword(passwordHash, []byte(password))
	if err != nil {
		if err == bcrypt.ErrMismatchedHashAndPassword {
			return false, nil
		}
		return false, err
	}

	return true, nil
}
