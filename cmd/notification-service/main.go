package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
)

// Notification represents a notification to a user
type Notification struct {
	ID        string     `json:"id"`
	UserID    string     `json:"user_id"`
	Type      string     `json:"type"`
	Title     string     `json:"title"`
	Message   string     `json:"message"`
	Data      string     `json:"data,omitempty"`
	IsRead    bool       `json:"is_read"`
	CreatedAt time.Time  `json:"created_at"`
	ReadAt    *time.Time `json:"read_at,omitempty"`
}

// UserPreference represents notification preferences for a user
type UserPreference struct {
	UserID           string    `json:"user_id"`
	EmailEnabled     bool      `json:"email_enabled"`
	SMSEnabled       bool      `json:"sms_enabled"`
	PushEnabled      bool      `json:"push_enabled"`
	MarketingEnabled bool      `json:"marketing_enabled"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

var db *pgxpool.Pool

func main() {
	log.Println("Starting notification-service...")

	// Connect to database
	dbURL := "postgres://trustainvest:trustainvest@postgres:5432/trustainvest"
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

	// Set up Gin router
	router := gin.Default()

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "notification-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		// Notifications
		notifications := v1.Group("/notifications")
		{
			notifications.GET("", listNotifications)
			notifications.GET("/:id", getNotificationByID)
			notifications.POST("", createNotification)
			notifications.PUT("/:id/read", markNotificationAsRead)
		}

		// User notifications
		userNotifications := v1.Group("/users/:userId/notifications")
		{
			userNotifications.GET("", getUserNotifications)
			userNotifications.GET("/unread", getUserUnreadNotifications)
			userNotifications.POST("/read-all", markAllNotificationsAsRead)
		}

		// User preferences
		preferences := v1.Group("/users/:userId/preferences")
		{
			preferences.GET("", getUserPreferences)
			preferences.PUT("", updateUserPreferences)
		}
	}

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
	log.Println("Shutting down notification-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Notification service stopped")
}

// Notification handlers
func listNotifications(c *gin.Context) {
	limit := 100
	offset := 0

	// Parse query parameters
	limitParam := c.Query("limit")
	offsetParam := c.Query("offset")

	if limitParam != "" {
		_, err := fmt.Sscanf(limitParam, "%d", &limit)
		if err != nil || limit <= 0 {
			limit = 100
		}
	}

	if offsetParam != "" {
		_, err := fmt.Sscanf(offsetParam, "%d", &offset)
		if err != nil || offset < 0 {
			offset = 0
		}
	}

	var notifications []Notification
	rows, err := db.Query(context.Background(), `
		SELECT id, user_id, type, title, message, data, is_read, created_at, read_at
		FROM notifications.notifications
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve notifications"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var notification Notification
		err := rows.Scan(
			&notification.ID, &notification.UserID, &notification.Type,
			&notification.Title, &notification.Message, &notification.Data,
			&notification.IsRead, &notification.CreatedAt, &notification.ReadAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan notification data"})
			return
		}
		notifications = append(notifications, notification)
	}

	c.JSON(http.StatusOK, gin.H{"notifications": notifications})
}

func getNotificationByID(c *gin.Context) {
	id := c.Param("id")
	var notification Notification

	err := db.QueryRow(context.Background(), `
		SELECT id, user_id, type, title, message, data, is_read, created_at, read_at
		FROM notifications.notifications
		WHERE id = $1
	`, id).Scan(
		&notification.ID, &notification.UserID, &notification.Type,
		&notification.Title, &notification.Message, &notification.Data,
		&notification.IsRead, &notification.CreatedAt, &notification.ReadAt,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
		return
	}

	c.JSON(http.StatusOK, notification)
}

func getUserNotifications(c *gin.Context) {
	userID := c.Param("userId")
	limit := 100
	offset := 0

	// Parse query parameters
	limitParam := c.Query("limit")
	offsetParam := c.Query("offset")

	if limitParam != "" {
		_, err := fmt.Sscanf(limitParam, "%d", &limit)
		if err != nil || limit <= 0 {
			limit = 100
		}
	}

	if offsetParam != "" {
		_, err := fmt.Sscanf(offsetParam, "%d", &offset)
		if err != nil || offset < 0 {
			offset = 0
		}
	}

	var notifications []Notification
	rows, err := db.Query(context.Background(), `
		SELECT id, user_id, type, title, message, data, is_read, created_at, read_at
		FROM notifications.notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve user notifications"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var notification Notification
		err := rows.Scan(
			&notification.ID, &notification.UserID, &notification.Type,
			&notification.Title, &notification.Message, &notification.Data,
			&notification.IsRead, &notification.CreatedAt, &notification.ReadAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan notification data"})
			return
		}
		notifications = append(notifications, notification)
	}

	c.JSON(http.StatusOK, gin.H{"notifications": notifications})
}

func getUserUnreadNotifications(c *gin.Context) {
	userID := c.Param("userId")

	var notifications []Notification
	rows, err := db.Query(context.Background(), `
		SELECT id, user_id, type, title, message, data, is_read, created_at, read_at
		FROM notifications.notifications
		WHERE user_id = $1 AND is_read = false
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve unread notifications"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var notification Notification
		err := rows.Scan(
			&notification.ID, &notification.UserID, &notification.Type,
			&notification.Title, &notification.Message, &notification.Data,
			&notification.IsRead, &notification.CreatedAt, &notification.ReadAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan notification data"})
			return
		}
		notifications = append(notifications, notification)
	}

	// Get unread count
	var unreadCount int
	err = db.QueryRow(context.Background(), `
		SELECT COUNT(*)
		FROM notifications.notifications
		WHERE user_id = $1 AND is_read = false
	`, userID).Scan(&unreadCount)

	if err != nil {
		log.Printf("Warning: Failed to get unread count: %v", err)
		unreadCount = len(notifications)
	}

	c.JSON(http.StatusOK, gin.H{
		"notifications": notifications,
		"unread_count":  unreadCount,
	})
}

func createNotification(c *gin.Context) {
	var input struct {
		UserID  string `json:"user_id" binding:"required"`
		Type    string `json:"type" binding:"required"`
		Title   string `json:"title" binding:"required"`
		Message string `json:"message" binding:"required"`
		Data    string `json:"data"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if user exists
	var userExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
	`, input.UserID).Scan(&userExists)

	if err != nil || !userExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
		return
	}

	id := uuid.New().String()

	_, err = db.Exec(context.Background(), `
		INSERT INTO notifications.notifications (
			id, user_id, type, title, message, data, is_read
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
	`, id, input.UserID, input.Type, input.Title, input.Message, input.Data, false)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create notification: " + err.Error()})
		return
	}

	// TODO: Send actual notification based on user preferences

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Notification created successfully",
	})
}

func markNotificationAsRead(c *gin.Context) {
	id := c.Param("id")

	now := time.Now()
	result, err := db.Exec(context.Background(), `
		UPDATE notifications.notifications
		SET is_read = true, read_at = $1
		WHERE id = $2 AND is_read = false
	`, now, id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark notification as read: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		// Check if notification exists
		var exists bool
		err := db.QueryRow(context.Background(), `
			SELECT EXISTS(SELECT 1 FROM notifications.notifications WHERE id = $1)
		`, id).Scan(&exists)

		if err != nil || !exists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
			return
		}

		// Notification exists but was already read
		c.JSON(http.StatusOK, gin.H{"message": "Notification was already marked as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification marked as read"})
}

func markAllNotificationsAsRead(c *gin.Context) {
	userID := c.Param("userId")

	now := time.Now()
	result, err := db.Exec(context.Background(), `
		UPDATE notifications.notifications
		SET is_read = true, read_at = $1
		WHERE user_id = $2 AND is_read = false
	`, now, userID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark notifications as read: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()

	c.JSON(http.StatusOK, gin.H{
		"message": fmt.Sprintf("%d notifications marked as read", rowsAffected),
	})
}

// User preferences handlers
func getUserPreferences(c *gin.Context) {
	userID := c.Param("userId")

	var preferences UserPreference

	err := db.QueryRow(context.Background(), `
		SELECT user_id, email_enabled, sms_enabled, push_enabled, 
		       marketing_enabled, created_at, updated_at
		FROM notifications.user_preferences
		WHERE user_id = $1
	`, userID).Scan(
		&preferences.UserID, &preferences.EmailEnabled, &preferences.SMSEnabled,
		&preferences.PushEnabled, &preferences.MarketingEnabled,
		&preferences.CreatedAt, &preferences.UpdatedAt,
	)

	if err != nil {
		// Check if user exists
		var userExists bool
		err := db.QueryRow(context.Background(), `
			SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
		`, userID).Scan(&userExists)

		if err != nil || !userExists {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// User exists but preferences not set, return defaults
		now := time.Now()
		preferences = UserPreference{
			UserID:           userID,
			EmailEnabled:     true,
			SMSEnabled:       true,
			PushEnabled:      true,
			MarketingEnabled: false,
			CreatedAt:        now,
			UpdatedAt:        now,
		}
	}

	c.JSON(http.StatusOK, preferences)
}

func updateUserPreferences(c *gin.Context) {
	userID := c.Param("userId")

	var input struct {
		EmailEnabled     *bool `json:"email_enabled"`
		SMSEnabled       *bool `json:"sms_enabled"`
		PushEnabled      *bool `json:"push_enabled"`
		MarketingEnabled *bool `json:"marketing_enabled"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if user exists
	var userExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
	`, userID).Scan(&userExists)

	if err != nil || !userExists {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if preferences already exist
	var preferencesExist bool
	err = db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM notifications.user_preferences WHERE user_id = $1)
	`, userID).Scan(&preferencesExist)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check preferences: " + err.Error()})
		return
	}

	now := time.Now()

	if preferencesExist {
		// Update existing preferences
		query := `
			UPDATE notifications.user_preferences
			SET updated_at = $1
		`
		args := []interface{}{now}
		argIndex := 2

		if input.EmailEnabled != nil {
			query += fmt.Sprintf(", email_enabled = $%d", argIndex)
			args = append(args, *input.EmailEnabled)
			argIndex++
		}

		if input.SMSEnabled != nil {
			query += fmt.Sprintf(", sms_enabled = $%d", argIndex)
			args = append(args, *input.SMSEnabled)
			argIndex++
		}

		if input.PushEnabled != nil {
			query += fmt.Sprintf(", push_enabled = $%d", argIndex)
			args = append(args, *input.PushEnabled)
			argIndex++
		}

		if input.MarketingEnabled != nil {
			query += fmt.Sprintf(", marketing_enabled = $%d", argIndex)
			args = append(args, *input.MarketingEnabled)
			argIndex++
		}

		query += fmt.Sprintf(" WHERE user_id = $%d", argIndex)
		args = append(args, userID)

		_, err := db.Exec(context.Background(), query, args...)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update preferences: " + err.Error()})
			return
		}
	} else {
		// Create new preferences
		emailEnabled := true
		if input.EmailEnabled != nil {
			emailEnabled = *input.EmailEnabled
		}

		smsEnabled := true
		if input.SMSEnabled != nil {
			smsEnabled = *input.SMSEnabled
		}

		pushEnabled := true
		if input.PushEnabled != nil {
			pushEnabled = *input.PushEnabled
		}

		marketingEnabled := false
		if input.MarketingEnabled != nil {
			marketingEnabled = *input.MarketingEnabled
		}

		_, err := db.Exec(context.Background(), `
			INSERT INTO notifications.user_preferences (
				user_id, email_enabled, sms_enabled, push_enabled,
				marketing_enabled, created_at, updated_at
			) VALUES (
				$1, $2, $3, $4, $5, $6, $6
			)
		`, userID, emailEnabled, smsEnabled, pushEnabled,
			marketingEnabled, now)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create preferences: " + err.Error()})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Preferences updated successfully"})
}
