package services

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/kms"
)

// EncryptionService handles encryption and decryption of sensitive data
type EncryptionService struct {
	kmsClient *kms.KMS
	keyID     string
	// For envelope encryption: data key is used to encrypt data,
	// and KMS is used to encrypt the data key
	dataKey []byte
}

// NewEncryptionService creates a new EncryptionService
func NewEncryptionService(kmsClient *kms.KMS, keyID string) (*EncryptionService, error) {
	service := &EncryptionService{
		kmsClient: kmsClient,
		keyID:     keyID,
	}

	// Generate a data key using KMS
	err := service.rotateDataKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate data key: %w", err)
	}

	return service, nil
}

// rotateDataKey generates a new data key using KMS
func (s *EncryptionService) rotateDataKey() error {
	// Generate a data key using KMS
	// The data key is used for envelope encryption
	result, err := s.kmsClient.GenerateDataKey(&kms.GenerateDataKeyInput{
		KeyId:   aws.String(s.keyID),
		KeySpec: aws.String("AES_256"),
	})
	if err != nil {
		return err
	}

	// Store the plaintext data key for encryption operations
	s.dataKey = result.Plaintext

	return nil
}

// EncryptData encrypts the provided data using envelope encryption
func (s *EncryptionService) EncryptData(data string) ([]byte, error) {
	if len(s.dataKey) == 0 {
		return nil, errors.New("data key not initialized")
	}

	// Create a new AES cipher using the data key
	block, err := aes.NewCipher(s.dataKey)
	if err != nil {
		return nil, err
	}

	// Generate a random IV (Initialization Vector)
	iv := make([]byte, aes.BlockSize)
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return nil, err
	}

	// Create the GCM mode with the AES cipher
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	// Encrypt the data
	plaintext := []byte(data)
	ciphertext := aesGCM.Seal(nil, iv, plaintext, nil)

	// Combine IV and ciphertext
	result := make([]byte, len(iv)+len(ciphertext))
	copy(result[:len(iv)], iv)
	copy(result[len(iv):], ciphertext)

	return result, nil
}

// DecryptData decrypts the provided encrypted data
func (s *EncryptionService) DecryptData(encryptedData []byte) (string, error) {
	if len(s.dataKey) == 0 {
		return "", errors.New("data key not initialized")
	}

	// Create a new AES cipher using the data key
	block, err := aes.NewCipher(s.dataKey)
	if err != nil {
		return "", err
	}

	// Create the GCM mode with the AES cipher
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	// Split IV and ciphertext
	if len(encryptedData) < aes.BlockSize {
		return "", errors.New("encrypted data too short")
	}

	iv := encryptedData[:aes.BlockSize]
	ciphertext := encryptedData[aes.BlockSize:]

	// Decrypt the data
	plaintext, err := aesGCM.Open(nil, iv, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

// EncryptWithKMS directly encrypts data using KMS
// Use this for very small pieces of data or keys
func (s *EncryptionService) EncryptWithKMS(data string) (string, error) {
	input := &kms.EncryptInput{
		KeyId:     aws.String(s.keyID),
		Plaintext: []byte(data),
	}

	result, err := s.kmsClient.Encrypt(input)
	if err != nil {
		return "", err
	}

	// Base64 encode the ciphertext for easier storage
	encryptedData := base64.StdEncoding.EncodeToString(result.CiphertextBlob)
	return encryptedData, nil
}

// DecryptWithKMS decrypts data that was directly encrypted with KMS
func (s *EncryptionService) DecryptWithKMS(encryptedData string) (string, error) {
	// Decode the base64 encoded ciphertext
	ciphertextBlob, err := base64.StdEncoding.DecodeString(encryptedData)
	if err != nil {
		return "", err
	}

	input := &kms.DecryptInput{
		CiphertextBlob: ciphertextBlob,
	}

	result, err := s.kmsClient.Decrypt(input)
	if err != nil {
		return "", err
	}

	return string(result.Plaintext), nil
}
