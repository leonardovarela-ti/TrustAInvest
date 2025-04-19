package auth

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
)

// SessionService handles user session management
type SessionService struct {
	db *pgxpool.Pool
}

// NewSessionService creates a new SessionService
func NewSessionService(db *pgxpool.Pool) *SessionService {
	return &SessionService{
		db: db,
	}
}

// CreateSession creates a new session for a user and invalidates any existing sessions
func (s *SessionService) CreateSession(ctx context.Context, userID string, token string, deviceInfo string, ipAddress string, expiresAt time.Time) (string, error) {
	// Begin transaction
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	// Invalidate any existing active sessions for this user
	_, err = tx.Exec(ctx, `
		UPDATE users.active_sessions
		SET is_active = false
		WHERE user_id = $1 AND is_active = true
	`, userID)
	if err != nil {
		return "", err
	}

	// Generate a shorter session ID using UUID v4
	sessionID := uuid.New().String()

	// Generate a unique token ID (not the token itself)
	tokenID := uuid.New().String()

	// Create new session
	_, err = tx.Exec(ctx, `
		INSERT INTO users.active_sessions (
			id, user_id, token_id, device_info, ip_address, created_at, expires_at, last_activity_at, is_active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9
		)
	`, sessionID, userID, tokenID, deviceInfo, ipAddress, time.Now(), expiresAt, time.Now(), true)
	if err != nil {
		return "", err
	}

	if err = tx.Commit(ctx); err != nil {
		return "", err
	}

	return sessionID, nil
}

// ValidateSession checks if a session is valid and active
func (s *SessionService) ValidateSession(ctx context.Context, sessionID string) (bool, error) {
	var exists bool
	err := s.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM users.active_sessions
			WHERE id = $1 AND is_active = true AND expires_at > NOW()
		)
	`, sessionID).Scan(&exists)

	if err != nil {
		return false, err
	}

	return exists, nil
}

// UpdateSessionActivity updates the last activity timestamp for a session
func (s *SessionService) UpdateSessionActivity(ctx context.Context, sessionID string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE users.active_sessions
		SET last_activity_at = NOW()
		WHERE id = $1 AND is_active = true
	`, sessionID)
	return err
}

// InvalidateSession invalidates a specific session
func (s *SessionService) InvalidateSession(ctx context.Context, sessionID string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE users.active_sessions
		SET is_active = false
		WHERE id = $1
	`, sessionID)
	return err
}

// CleanupExpiredSessions removes expired sessions from the database
func (s *SessionService) CleanupExpiredSessions(ctx context.Context) error {
	_, err := s.db.Exec(ctx, `
		DELETE FROM users.active_sessions
		WHERE expires_at < NOW() OR is_active = false
	`)
	return err
}
