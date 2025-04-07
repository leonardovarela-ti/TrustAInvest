package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/sns"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
)

// NotificationType defines the type of notification
type NotificationType string

const (
	NotificationTypeKYCSubmitted NotificationType = "KYC_SUBMITTED"
	NotificationTypeKYCApproved  NotificationType = "KYC_APPROVED"
	NotificationTypeKYCRejected  NotificationType = "KYC_REJECTED"
	NotificationTypeKYCPending   NotificationType = "KYC_PENDING"
)

// Notification represents a notification to a user
type Notification struct {
	ID        string                 `json:"id"`
	UserID    string                 `json:"user_id"`
	Type      string                 `json:"type"`
	Title     string                 `json:"title"`
	Message   string                 `json:"message"`
	Data      map[string]interface{} `json:"data,omitempty"`
	IsRead    bool                   `json:"is_read"`
	CreatedAt time.Time              `json:"created_at"`
	ReadAt    *time.Time             `json:"read_at,omitempty"`
}

// UserPreference represents notification preferences for a user
type UserPreference struct {
	UserID           string `json:"user_id"`
	EmailEnabled     bool   `json:"email_enabled"`
	SMSEnabled       bool   `json:"sms_enabled"`
	PushEnabled      bool   `json:"push_enabled"`
	MarketingEnabled bool   `json:"marketing_enabled"`
}

// NotificationService handles sending notifications to users
type NotificationService struct {
	db           *pgxpool.Pool
	snsClient    *sns.SNS
	sqsClient    *sqs.SQS
	topicARN     string
	queueURL     string
	emailService EmailService
	smsService   SMSService
	pushService  PushNotificationService
}

// EmailService defines methods for sending emails
type EmailService interface {
	SendEmail(ctx context.Context, to, subject, body string) error
}

// SMSService defines methods for sending SMS messages
type SMSService interface {
	SendSMS(ctx context.Context, phoneNumber, message string) error
}

// PushNotificationService defines methods for sending push notifications
type PushNotificationService interface {
	SendPushNotification(ctx context.Context, deviceToken, title, body string, data map[string]interface{}) error
}

// NewNotificationService creates a new NotificationService
func NewNotificationService(
	db *pgxpool.Pool,
	snsClient *sns.SNS,
	sqsClient *sqs.SQS,
	topicARN string,
	queueURL string,
	emailService EmailService,
	smsService SMSService,
	pushService PushNotificationService,
) *NotificationService {
	return &NotificationService{
		db:           db,
		snsClient:    snsClient,
		sqsClient:    sqsClient,
		topicARN:     topicARN,
		queueURL:     queueURL,
		emailService: emailService,
		smsService:   smsService,
		pushService:  pushService,
	}
}

// SendNotification sends a notification to a user via all enabled channels
func (s *NotificationService) SendNotification(
	ctx context.Context,
	userID string,
	notificationType string,
	title string,
	message string,
	data map[string]interface{},
) error {
	// Create notification record
	notification := Notification{
		ID:        uuid.New().String(),
		UserID:    userID,
		Type:      notificationType,
		Title:     title,
		Message:   message,
		Data:      data,
		IsRead:    false,
		CreatedAt: time.Now(),
	}

	// Save notification to database
	err := s.saveNotification(ctx, &notification)
	if err != nil {
		return fmt.Errorf("error saving notification: %w", err)
	}

	// Get user notification preferences
	preferences, err := s.getUserPreferences(ctx, userID)
	if err != nil {
		// If preferences can't be retrieved, use default preferences
		log.Printf("Error getting user preferences: %v. Using defaults.", err)
		preferences = &UserPreference{
			UserID:       userID,
			EmailEnabled: true,
			SMSEnabled:   true,
			PushEnabled:  true,
		}
	}

	// Get user contact information
	user, err := s.getUserContactInfo(ctx, userID)
	if err != nil {
		return fmt.Errorf("error getting user contact info: %w", err)
	}

	// Prepare notification payload
	notificationData := map[string]interface{}{
		"notification_id": notification.ID,
		"user_id":         userID,
		"type":            notificationType,
		"title":           title,
		"message":         message,
		"data":            data,
		"created_at":      notification.CreatedAt.Format(time.RFC3339),
	}

	// Send via enabled channels
	if preferences.EmailEnabled && user.Email != "" {
		go s.sendEmailNotification(ctx, user.Email, title, message)
	}

	if preferences.SMSEnabled && user.PhoneNumber != "" {
		go s.sendSMSNotification(ctx, user.PhoneNumber, message)
	}

	if preferences.PushEnabled && user.DeviceID != "" {
		go s.sendPushNotification(ctx, user.DeviceID, title, message, notificationData)
	}

	// Publish to SNS topic for further processing
	go s.publishToSNS(notification)

	return nil
}

// saveNotification saves a notification to the database
func (s *NotificationService) saveNotification(ctx context.Context, notification *Notification) error {
	dataJSON, err := json.Marshal(notification.Data)
	if err != nil {
		return err
	}

	_, err = s.db.Exec(ctx, `
		INSERT INTO notifications.notifications (
			id, user_id, type, title, message, data, is_read, created_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8
		)
	`, notification.ID, notification.UserID, notification.Type, notification.Title,
		notification.Message, dataJSON, notification.IsRead, notification.CreatedAt)

	return err
}

// getUserPreferences gets a user's notification preferences
func (s *NotificationService) getUserPreferences(ctx context.Context, userID string) (*UserPreference, error) {
	preferences := &UserPreference{
		UserID: userID,
	}

	err := s.db.QueryRow(ctx, `
		SELECT email_enabled, sms_enabled, push_enabled, marketing_enabled
		FROM notifications.user_preferences
		WHERE user_id = $1
	`, userID).Scan(
		&preferences.EmailEnabled,
		&preferences.SMSEnabled,
		&preferences.PushEnabled,
		&preferences.MarketingEnabled,
	)

	if err != nil {
		return nil, err
	}

	return preferences, nil
}

// UserContactInfo represents user contact information
type UserContactInfo struct {
	UserID      string
	Email       string
	PhoneNumber string
	DeviceID    string
}

// getUserContactInfo gets a user's contact information
func (s *NotificationService) getUserContactInfo(ctx context.Context, userID string) (*UserContactInfo, error) {
	contactInfo := &UserContactInfo{
		UserID: userID,
	}

	err := s.db.QueryRow(ctx, `
		SELECT email, phone_number, device_id
		FROM users.users
		WHERE id = $1 AND is_active = true
	`, userID).Scan(
		&contactInfo.Email,
		&contactInfo.PhoneNumber,
		&contactInfo.DeviceID,
	)

	if err != nil {
		return nil, err
	}

	return contactInfo, nil
}

// sendEmailNotification sends an email notification
func (s *NotificationService) sendEmailNotification(ctx context.Context, email, subject, body string) {
	err := s.emailService.SendEmail(ctx, email, subject, body)
	if err != nil {
		log.Printf("Error sending email notification: %v", err)
	}
}

// sendSMSNotification sends an SMS notification
func (s *NotificationService) sendSMSNotification(ctx context.Context, phoneNumber, message string) {
	err := s.smsService.SendSMS(ctx, phoneNumber, message)
	if err != nil {
		log.Printf("Error sending SMS notification: %v", err)
	}
}

// sendPushNotification sends a push notification
func (s *NotificationService) sendPushNotification(ctx context.Context, deviceID, title, body string, data map[string]interface{}) {
	err := s.pushService.SendPushNotification(ctx, deviceID, title, body, data)
	if err != nil {
		log.Printf("Error sending push notification: %v", err)
	}
}

// publishToSNS publishes a notification to an SNS topic
func (s *NotificationService) publishToSNS(notification Notification) {
	// Convert notification to JSON
	messageBytes, err := json.Marshal(notification)
	if err != nil {
		log.Printf("Error marshaling notification: %v", err)
		return
	}

	// Publish to SNS
	input := &sns.PublishInput{
		TopicArn: aws.String(s.topicARN),
		Message:  aws.String(string(messageBytes)),
		MessageAttributes: map[string]*sns.MessageAttributeValue{
			"UserID": {
				DataType:    aws.String("String"),
				StringValue: aws.String(notification.UserID),
			},
			"Type": {
				DataType:    aws.String("String"),
				StringValue: aws.String(notification.Type),
			},
		},
	}

	_, err = s.snsClient.Publish(input)
	if err != nil {
		log.Printf("Error publishing to SNS: %v", err)
	}
}

// MarkNotificationAsRead marks a notification as read
func (s *NotificationService) MarkNotificationAsRead(ctx context.Context, notificationID string) error {
	now := time.Now()
	_, err := s.db.Exec(ctx, `
		UPDATE notifications.notifications
		SET is_read = true, read_at = $1
		WHERE id = $2 AND is_read = false
	`, now, notificationID)

	return err
}

// GetUserNotifications gets a user's notifications
func (s *NotificationService) GetUserNotifications(ctx context.Context, userID string, limit, offset int) ([]Notification, error) {
	if limit <= 0 {
		limit = 50 // Default limit
	}

	rows, err := s.db.Query(ctx, `
		SELECT id, user_id, type, title, message, data, is_read, created_at, read_at
		FROM notifications.notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []Notification
	for rows.Next() {
		var notification Notification
		var dataJSON []byte

		err := rows.Scan(
			&notification.ID,
			&notification.UserID,
			&notification.Type,
			&notification.Title,
			&notification.Message,
			&dataJSON,
			&notification.IsRead,
			&notification.CreatedAt,
			&notification.ReadAt,
		)
		if err != nil {
			return nil, err
		}

		// Parse JSON data
		if len(dataJSON) > 0 {
			err = json.Unmarshal(dataJSON, &notification.Data)
			if err != nil {
				log.Printf("Error unmarshaling notification data: %v", err)
				// Continue with empty data instead of failing
				notification.Data = make(map[string]interface{})
			}
		}

		notifications = append(notifications, notification)
	}

	return notifications, nil
}

// GetUnreadNotifications gets a user's unread notifications
func (s *NotificationService) GetUnreadNotifications(ctx context.Context, userID string) ([]Notification, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, user_id, type, title, message, data, is_read, created_at, read_at
		FROM notifications.notifications
		WHERE user_id = $1 AND is_read = false
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []Notification
	for rows.Next() {
		var notification Notification
		var dataJSON []byte

		err := rows.Scan(
			&notification.ID,
			&notification.UserID,
			&notification.Type,
			&notification.Title,
			&notification.Message,
			&dataJSON,
			&notification.IsRead,
			&notification.CreatedAt,
			&notification.ReadAt,
		)
		if err != nil {
			return nil, err
		}

		// Parse JSON data
		if len(dataJSON) > 0 {
			err = json.Unmarshal(dataJSON, &notification.Data)
			if err != nil {
				log.Printf("Error unmarshaling notification data: %v", err)
				notification.Data = make(map[string]interface{})
			}
		}

		notifications = append(notifications, notification)
	}

	return notifications, nil
}

// GetUnreadNotificationCount gets the count of a user's unread notifications
func (s *NotificationService) GetUnreadNotificationCount(ctx context.Context, userID string) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM notifications.notifications
		WHERE user_id = $1 AND is_read = false
	`, userID).Scan(&count)

	return count, err
}
