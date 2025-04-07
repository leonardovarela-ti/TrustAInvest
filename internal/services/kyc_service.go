package services

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/sqs"
	"github.com/google/uuid"
)

// KYCData represents the data required for KYC verification
type KYCData struct {
	UserID      string    `json:"user_id"`
	FirstName   string    `json:"first_name"`
	LastName    string    `json:"last_name"`
	DateOfBirth string    `json:"date_of_birth"`
	SSN         string    `json:"ssn"`
	Address     Address   `json:"address"`
	Email       string    `json:"email"`
	PhoneNumber string    `json:"phone_number"`
	CreatedAt   time.Time `json:"created_at"`
}

// Address represents a physical address
type Address struct {
	Street  string `json:"street"`
	City    string `json:"city"`
	State   string `json:"state"`
	ZipCode string `json:"zip_code"`
	Country string `json:"country"`
}

// KYCService handles KYC verification processes
type KYCService struct {
	sqsClient           *sqs.SQS
	kycQueueURL         string
	encryptionService   EncryptionService
	notificationService NotificationService
}

// EncryptionService defines methods for encrypting sensitive data
type EncryptionService interface {
	EncryptData(data string) ([]byte, error)
}

// NotificationService defines methods for sending notifications
type NotificationService interface {
	SendNotification(ctx context.Context, userID, notificationType, title, message string, data map[string]interface{}) error
}

// NewKYCService creates a new KYCService
func NewKYCService(sqsClient *sqs.SQS, kycQueueURL string, encryptionService EncryptionService, notificationService NotificationService) *KYCService {
	return &KYCService{
		sqsClient:           sqsClient,
		kycQueueURL:         kycQueueURL,
		encryptionService:   encryptionService,
		notificationService: notificationService,
	}
}

// EnqueueKYCVerification sends a KYC verification request to the queue
func (s *KYCService) EnqueueKYCVerification(ctx context.Context, userID string, kycData *KYCData) error {
	// Encrypt sensitive data before sending to the queue
	encryptedSSN, err := s.encryptionService.EncryptData(kycData.SSN)
	if err != nil {
		return fmt.Errorf("error encrypting SSN: %w", err)
	}

	// Remove sensitive data from KYCData object
	kycData.SSN = "" // Clear the plaintext SSN as we'll pass the encrypted version separately

	// Convert KYC data to JSON
	dataBytes, err := json.Marshal(kycData)
	if err != nil {
		return fmt.Errorf("error marshaling KYC data: %w", err)
	}

	// Create message attributes for the SQS message
	messageAttributes := map[string]*sqs.MessageAttributeValue{
		"UserID": {
			DataType:    aws.String("String"),
			StringValue: aws.String(userID),
		},
		"RequestType": {
			DataType:    aws.String("String"),
			StringValue: aws.String("KYC_VERIFICATION"),
		},
		"RequestID": {
			DataType:    aws.String("String"),
			StringValue: aws.String(uuid.New().String()),
		},
		"EncryptedSSN": {
			DataType:    aws.String("Binary"),
			BinaryValue: encryptedSSN,
		},
		"Timestamp": {
			DataType:    aws.String("String"),
			StringValue: aws.String(time.Now().Format(time.RFC3339)),
		},
	}

	// Prepare the SQS message
	msgInput := &sqs.SendMessageInput{
		QueueUrl:          aws.String(s.kycQueueURL),
		MessageBody:       aws.String(string(dataBytes)),
		MessageAttributes: messageAttributes,
	}

	// Send message to SQS
	_, err = s.sqsClient.SendMessageWithContext(ctx, msgInput)
	if err != nil {
		return fmt.Errorf("error sending message to KYC queue: %w", err)
	}

	// Send notification to user about pending KYC
	notificationData := map[string]interface{}{
		"user_id": userID,
		"status":  "PENDING",
	}

	err = s.notificationService.SendNotification(
		ctx,
		userID,
		"KYC_SUBMITTED",
		"Identity Verification Pending",
		"Your identity verification request has been submitted and is pending review.",
		notificationData,
	)

	if err != nil {
		// Log but don't return error as this is not critical
		log.Printf("Failed to send notification: %v", err)
	}

	return nil
}

// ProcessKYCVerification processes a KYC verification from the queue
// This would typically be called by a separate worker service that processes the queue
func (s *KYCService) ProcessKYCVerification(ctx context.Context, messageBody string, messageAttributes map[string]*sqs.MessageAttributeValue) error {
	// Parse KYC data
	var kycData KYCData
	if err := json.Unmarshal([]byte(messageBody), &kycData); err != nil {
		return fmt.Errorf("error unmarshaling KYC data: %w", err)
	}

	userID := *messageAttributes["UserID"].StringValue
	encryptedSSN := messageAttributes["EncryptedSSN"].BinaryValue

	// This is where you would implement the actual KYC verification process
	// For example, call a third-party KYC provider API
	// For now, we're just simulating the process

	// Simulate KYC verification
	// In a real implementation, this would call out to a third-party KYC provider
	kycResult, err := simulateKYCVerification(kycData, encryptedSSN)
	if err != nil {
		return fmt.Errorf("error performing KYC verification: %w", err)
	}

	// Process the KYC result
	// This would typically update the user's KYC status in the database
	// and send a notification to the user

	// For now, we'll just log the result
	log.Printf("KYC verification for user %s: %s", userID, kycResult)

	return nil
}

// simulateKYCVerification simulates a KYC verification process
// In a real implementation, this would call out to a third-party KYC provider
func simulateKYCVerification(kycData KYCData, encryptedSSN []byte) (string, error) {
	// Simulate a delay for the verification process
	time.Sleep(2 * time.Second)

	// In a real implementation, this would perform various checks:
	// 1. Verify SSN against credit bureaus
	// 2. Verify identity documents
	// 3. Check against watchlists (AML/CFT)
	// 4. Verify address

	// For this simulation, we'll randomly approve or require additional information
	// In a real system, this would be based on actual verification results

	// For demonstration purposes, always return APPROVED
	return "APPROVED", nil
}
