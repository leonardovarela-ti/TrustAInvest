package auth

import (
"errors"
"time"

"github.com/golang-jwt/jwt"
)

// Claims represents the JWT claims
type Claims struct {
UserID   string `json:"sub"`
Username string `json:"username"`
Email    string `json:"email"`
Role     string `json:"role"`
jwt.StandardClaims
}

// TokenService handles JWT token generation and validation
type TokenService struct {
secretKey     string
tokenDuration time.Duration
}

// NewTokenService creates a new TokenService
func NewTokenService(secretKey string, tokenDuration time.Duration) *TokenService {
return &TokenService{
secretKey:     secretKey,
tokenDuration: tokenDuration,
}
}

// GenerateToken generates a new JWT token
func (s *TokenService) GenerateToken(userID, username, email, role string) (string, error) {
expirationTime := time.Now().Add(s.tokenDuration)
claims := &Claims{
UserID:   userID,
Username: username,
Email:    email,
Role:     role,
StandardClaims: jwt.StandardClaims{
	ExpiresAt: expirationTime.Unix(),
	IssuedAt:  time.Now().Unix(),
	Issuer:    "trustainvest.com",
	Subject:   userID,
},
}

token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
tokenString, err := token.SignedString([]byte(s.secretKey))
if err != nil {
return "", err
}

return tokenString, nil
}

// ValidateToken validates a JWT token
func (s *TokenService) ValidateToken(tokenString string) (*Claims, error) {
claims := &Claims{}

token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
return []byte(s.secretKey), nil
})

if err != nil {
return nil, err
}

if !token.Valid {
return nil, errors.New("invalid token")
}

return claims, nil
}
