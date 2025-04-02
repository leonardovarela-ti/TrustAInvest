package middleware

import (
"errors"
"fmt"
"net/http"
"strings"
"time"

"github.com/gin-gonic/gin"
"github.com/golang-jwt/jwt"
)

// AuthMiddleware is middleware for JWT authentication
func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
return func(c *gin.Context) {
// Get the Authorization header
authHeader := c.GetHeader("Authorization")
if authHeader == "" {
	c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header is required"})
	c.Abort()
	return
}

// Check if it's a Bearer token
if !strings.HasPrefix(authHeader, "Bearer ") {
	c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization format, expected Bearer token"})
	c.Abort()
	return
}

// Extract the token
tokenString := strings.TrimPrefix(authHeader, "Bearer ")

// Parse and validate the token
token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
	// Validate the signing method
	if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
		return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
	}
	
	// Return the secret key
	return []byte(jwtSecret), nil
})

if err != nil {
	c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token: " + err.Error()})
	c.Abort()
	return
}

// Check if the token is valid
if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
	// Check if the token is expired
	if exp, ok := claims["exp"].(float64); ok {
		if time.Now().Unix() > int64(exp) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "token expired"})
			c.Abort()
			return
		}
	}
	
	// Store user information in the context
	userID, ok := claims["sub"].(string)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token claims"})
		c.Abort()
		return
	}
	
	c.Set("userID", userID)
	c.Next()
} else {
	c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
	c.Abort()
	return
}
}
}

// CORSMiddleware adds CORS headers to responses
func CORSMiddleware() gin.HandlerFunc {
return func(c *gin.Context) {
c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

if c.Request.Method == "OPTIONS" {
	c.AbortWithStatus(204)
	return
}

c.Next()
}
}

// LoggingMiddleware logs each request
func LoggingMiddleware() gin.HandlerFunc {
return func(c *gin.Context) {
// Start time
startTime := time.Now()

// Process request
c.Next()

// End time
endTime := time.Now()

// Execution time
latency := endTime.Sub(startTime)

// Request details
method := c.Request.Method
path := c.Request.URL.Path
statusCode := c.Writer.Status()
clientIP := c.ClientIP()

// Log format
log := fmt.Sprintf("[%s] %s | %d | %s | %s | %s",
	time.Now().Format("2006-01-02 15:04:05"),
	method,
	statusCode,
	path,
	clientIP,
	latency,
)

fmt.Println(log)
}
}
