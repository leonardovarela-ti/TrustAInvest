package aws

import (
"bytes"
"context"
"fmt"
"io"
"time"

"github.com/aws/aws-sdk-go/aws"
"github.com/aws/aws-sdk-go/aws/session"
"github.com/aws/aws-sdk-go/service/s3"
"github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider"
)

// S3Client is a wrapper for AWS S3 operations
type S3Client struct {
client *s3.S3
bucket string
}

// NewS3Client creates a new S3Client
func NewS3Client(sess *session.Session, bucket string) *S3Client {
return &S3Client{
client: s3.New(sess),
bucket: bucket,
}
}

// UploadFile uploads a file to S3
func (c *S3Client) UploadFile(ctx context.Context, key string, body io.Reader, contentType string) error {
_, err := c.client.PutObjectWithContext(ctx, &s3.PutObjectInput{
Bucket:      aws.String(c.bucket),
Key:         aws.String(key),
Body:        aws.ReadSeekCloser(body),
ContentType: aws.String(contentType),
})

if err != nil {
return fmt.Errorf("failed to upload file: %w", err)
}

return nil
}

// DownloadFile downloads a file from S3
func (c *S3Client) DownloadFile(ctx context.Context, key string) ([]byte, error) {
result, err := c.client.GetObjectWithContext(ctx, &s3.GetObjectInput{
Bucket: aws.String(c.bucket),
Key:    aws.String(key),
})

if err != nil {
return nil, fmt.Errorf("failed to download file: %w", err)
}
defer result.Body.Close()

buf := new(bytes.Buffer)
_, err = io.Copy(buf, result.Body)
if err != nil {
return nil, fmt.Errorf("failed to read file: %w", err)
}

return buf.Bytes(), nil
}

// CognitoClient is a wrapper for AWS Cognito operations
type CognitoClient struct {
client       *cognitoidentityprovider.CognitoIdentityProvider
userPoolID   string
clientID     string
clientSecret string
}

// NewCognitoClient creates a new CognitoClient
func NewCognitoClient(sess *session.Session, userPoolID, clientID, clientSecret string) *CognitoClient {
return &CognitoClient{
client:       cognitoidentityprovider.New(sess),
userPoolID:   userPoolID,
clientID:     clientID,
clientSecret: clientSecret,
}
}

// CreateUser creates a new user in Cognito
func (c *CognitoClient) CreateUser(ctx context.Context, username, password, email string) error {
_, err := c.client.AdminCreateUser(&cognitoidentityprovider.AdminCreateUserInput{
UserPoolId: aws.String(c.userPoolID),
Username:   aws.String(username),
TemporaryPassword: aws.String(password),
UserAttributes: []*cognitoidentityprovider.AttributeType{
	{
		Name:  aws.String("email"),
		Value: aws.String(email),
	},
	{
		Name:  aws.String("email_verified"),
		Value: aws.String("true"),
	},
},
})

if err != nil {
return fmt.Errorf("failed to create user: %w", err)
}

return nil
}

// SetUserPassword sets a permanent password for a user
func (c *CognitoClient) SetUserPassword(ctx context.Context, username, password string) error {
_, err := c.client.AdminSetUserPassword(&cognitoidentityprovider.AdminSetUserPasswordInput{
UserPoolId: aws.String(c.userPoolID),
Username:   aws.String(username),
Password:   aws.String(password),
Permanent:  aws.Bool(true),
})

if err != nil {
return fmt.Errorf("failed to set user password: %w", err)
}

return nil
}
