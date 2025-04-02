package config

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

// Config represents the application configuration
type Config struct {
	// Server settings
	ServerPort int
	ServerHost string
	
	// Database settings
	DBHost     string
	DBPort     int
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string
	
	// Redis settings
	RedisHost string
	RedisPort int
	
	// AWS settings
	AWSRegion          string
	AWSAccessKeyID     string
	AWSSecretAccessKey string
	AWSEndpoint        string
	
	// Service URLs
	UserServiceURL     string
	AccountServiceURL  string
	TrustServiceURL    string
	InvestmentServiceURL string
	DocumentServiceURL  string
	NotificationServiceURL string
	
	// JWT settings
	JWTSecret     string
	JWTExpiration time.Duration
	
	// Logging
	LogLevel string
	
	// Environment
	Environment string
}

// LoadConfig loads the configuration from environment variables
func LoadConfig() (*Config, error) {
	// Load .env file if exists
	godotenv.Load()
	
	config := &Config{
		// Server settings
		ServerPort: getEnvAsInt("SERVER_PORT", 8080),
		ServerHost: getEnv("SERVER_HOST", "0.0.0.0"),
		
		// Database settings
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnvAsInt("DB_PORT", 5432),
		DBUser:     getEnv("DB_USER", "trustainvest"),
		DBPassword: getEnv("DB_PASSWORD", "trustainvest"),
		DBName:     getEnv("DB_NAME", "trustainvest"),
		DBSSLMode:  getEnv("DB_SSLMODE", "disable"),
		
		// Redis settings
		RedisHost: getEnv("REDIS_HOST", "localhost"),
		RedisPort: getEnvAsInt("REDIS_PORT", 6379),
		
		// AWS settings
		AWSRegion:          getEnv("AWS_REGION", "us-east-1"),
		AWSAccessKeyID:     getEnv("AWS_ACCESS_KEY_ID", ""),
		AWSSecretAccessKey: getEnv("AWS_SECRET_ACCESS_KEY", ""),
		AWSEndpoint:        getEnv("AWS_ENDPOINT", ""),
		
		// Service URLs
		UserServiceURL:     getEnv("USER_SERVICE_URL", "http://localhost:8080"),
		AccountServiceURL:  getEnv("ACCOUNT_SERVICE_URL", "http://localhost:8081"),
		TrustServiceURL:    getEnv("TRUST_SERVICE_URL", "http://localhost:8082"),
		InvestmentServiceURL: getEnv("INVESTMENT_SERVICE_URL", "http://localhost:8083"),
		DocumentServiceURL:  getEnv("DOCUMENT_SERVICE_URL", "http://localhost:8084"),
		NotificationServiceURL: getEnv("NOTIFICATION_SERVICE_URL", "http://localhost:8085"),
		
		// JWT settings
		JWTSecret:     getEnv("JWT_SECRET", "your-secret-key"),
		JWTExpiration: time.Duration(getEnvAsInt("JWT_EXPIRATION", 24)) * time.Hour,
		
		// Logging
		LogLevel: getEnv("LOG_LEVEL", "info"),
		
		// Environment
		Environment: getEnv("ENVIRONMENT", "development"),
	}
	
	return config, nil
}

// GetDatabaseURL returns the database connection string
func (c *Config) GetDatabaseURL() string {
	return fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName, c.DBSSLMode)
}

// GetRedisURL returns the Redis connection string
func (c *Config) GetRedisURL() string {
	return fmt.Sprintf("%s:%d", c.RedisHost, c.RedisPort)
}

// IsProduction returns true if the environment is production
func (c *Config) IsProduction() bool {
	return c.Environment == "production"
}

// Helper functions

func getEnv(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := getEnv(key, "")
	if value, err := strconv.Atoi(valueStr); err == nil {
		return value
	}
	return defaultValue
}
