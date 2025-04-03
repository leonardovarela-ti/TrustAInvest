package main

import (
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudformation"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/sts"
	"github.com/briandowns/spinner"
	"github.com/fatih/color"
	"github.com/manifoldco/promptui"
	"golang.org/x/crypto/ssh/terminal"
)

// Configuration holds the user's configuration for the project
type Configuration struct {
	AWSAccessKeyID     string `json:"aws_access_key_id"`
	AWSSecretAccessKey string `json:"aws_secret_access_key"`
	AWSRegion          string `json:"aws_region"`
	ProjectName        string `json:"project_name"`
	Environment        string `json:"environment"`
	StackName          string `json:"stack_name"`
	DockerHubUsername  string `json:"dockerhub_username"`
	S3BucketArtifacts  string `json:"s3_bucket_artifacts"`
	GitHubToken        string `json:"github_token,omitempty"`
	LocalDevEnabled    bool   `json:"local_dev_enabled"`
}

func main() {
	showBanner()
	
	config, err := loadOrCreateConfig()
	if err != nil {
		log.Fatalf("Error with configuration: %v", err)
	}

	// Validate AWS credentials
	spin := showSpinner("Validating AWS credentials...")
	awsSession, err := createAWSSession(config)
	if err != nil {
		spin.Stop()
		log.Fatalf("Error validating AWS credentials: %v", err)
	}
	stsClient := sts.New(awsSession)
	_, err = stsClient.GetCallerIdentity(&sts.GetCallerIdentityInput{})
	if err != nil {
		spin.Stop()
		log.Fatalf("Error validating AWS credentials: %v", err)
	}
	spin.Stop()
	fmt.Println(color.GreenString("✓ AWS credentials validated successfully"))

	// Check required tools
	checkRequiredTools()

	// Main menu
	for {
		option := showMainMenu()
		switch option {
		case "Setup Development Environment":
			setupDevEnvironment(config)
		case "Generate Code Templates":
			generateCodeTemplates(config)
		case "Deploy to AWS":
			deployToAWS(config, awsSession)
		case "Configure Project Settings":
			config = configureProjectSettings(config)
			saveConfig(config)
		case "Exit":
			fmt.Println("Exiting...")
			return
		}
	}
}

func showBanner() {
	banner := `
  _______              _      _____                     _   
 |__   __|            | |    |_   _|                   | |  
    | |_ __ _   _ ___| |_     | |  _ ____   _____  ___| |_ 
    | | '__| | | / __| __|    | | | '_ \ \ / / _ \/ __| __|
    | | |  | |_| \__ \ |_    _| |_| | | \ V /  __/\__ \ |_ 
    |_|_|   \__,_|___/\__|  |_____|_| |_|\_/ \___||___/\__|
                                                                                                  
    TrustAInvest.com Development Environment Setup
    ----------------------------------------------
`
	color.New(color.FgCyan, color.Bold).Println(banner)
}

func showSpinner(message string) *spinner.Spinner {
	s := spinner.New(spinner.CharSets[9], 100*time.Millisecond)
	s.Suffix = " " + message
	s.Color("cyan")
	s.Start()
	return s
}

func loadOrCreateConfig() (Configuration, error) {
	config := Configuration{}
	
	// Check if config file exists
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return config, err
	}
	
	configDir := filepath.Join(homeDir, ".trustainvest")
	if _, err := os.Stat(configDir); os.IsNotExist(err) {
		if err := os.MkdirAll(configDir, 0755); err != nil {
			return config, err
		}
	}
	
	configFile := filepath.Join(configDir, "config.json")
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		// Config doesn't exist, create a new one
		fmt.Println(color.YellowString("Configuration file not found. Let's set up your project."))
		config = configureProjectSettings(config)
		saveConfig(config)
	} else {
		// Load existing config
		data, err := ioutil.ReadFile(configFile)
		if err != nil {
			return config, err
		}
		err = json.Unmarshal(data, &config)
		if err != nil {
			return config, err
		}
	}
	
	return config, nil
}

func saveConfig(config Configuration) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	
	configDir := filepath.Join(homeDir, ".trustainvest")
	configFile := filepath.Join(configDir, "config.json")
	
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	
	return ioutil.WriteFile(configFile, data, 0644)
}

func configureProjectSettings(config Configuration) Configuration {
	fmt.Println(color.CyanString("\n📝 Configuring Project Settings"))
	fmt.Println(color.CyanString("---------------------------"))
	
	// Project name
	prompt := promptui.Prompt{
		Label:     "Project Name",
		Default:   config.ProjectName,
		AllowEdit: true,
	}
	projectName, err := prompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.ProjectName = projectName
	
	// Environment
	envPrompt := promptui.Select{
		Label: "Select Environment",
		Items: []string{"dev", "stage", "prod"},
	}
	_, environment, err := envPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.Environment = environment
	
	// Stack name
	stackPrompt := promptui.Prompt{
		Label:     "CloudFormation Stack Name",
		Default:   fmt.Sprintf("%s-%s", config.ProjectName, config.Environment),
		AllowEdit: true,
	}
	stackName, err := stackPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.StackName = stackName
	
	// AWS Region
	regionPrompt := promptui.Select{
		Label: "Select AWS Region",
		Items: []string{
			"us-east-1", "us-east-2", "us-west-1", "us-west-2",
			"eu-west-1", "eu-west-2", "eu-central-1",
			"ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
		},
	}
	_, region, err := regionPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.AWSRegion = region
	
	// AWS Access Key ID
	awsKeyPrompt := promptui.Prompt{
		Label:     "AWS Access Key ID",
		Default:   config.AWSAccessKeyID,
		AllowEdit: true,
	}
	awsKey, err := awsKeyPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.AWSAccessKeyID = awsKey
	
	// AWS Secret Access Key (hidden input)
	fmt.Print("AWS Secret Access Key (input will be hidden): ")
	byteSecret, err := terminal.ReadPassword(int(syscall.Stdin))
	if err != nil {
		log.Fatalf("Failed to read secret: %v", err)
	}
	fmt.Println()
	config.AWSSecretAccessKey = string(byteSecret)
	
	// S3 bucket for artifacts
	s3Prompt := promptui.Prompt{
		Label:     "S3 Bucket for Artifacts",
		Default:   fmt.Sprintf("%s-artifacts-%s", config.ProjectName, config.Environment),
		AllowEdit: true,
	}
	s3Bucket, err := s3Prompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.S3BucketArtifacts = s3Bucket
	
	// DockerHub username
	dockerPrompt := promptui.Prompt{
		Label:     "DockerHub Username (leave empty if not using)",
		Default:   config.DockerHubUsername,
		AllowEdit: true,
	}
	dockerUsername, err := dockerPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.DockerHubUsername = dockerUsername
	
	// GitHub token (optional)
	githubPrompt := promptui.Prompt{
		Label:     "GitHub Token (optional, for private repos)",
		Default:   config.GitHubToken,
		AllowEdit: true,
	}
	githubToken, err := githubPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.GitHubToken = githubToken
	
	// Local development
	localDevPrompt := promptui.Select{
		Label: "Enable Local Development Environment",
		Items: []string{"Yes", "No"},
	}
	_, localDev, err := localDevPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	config.LocalDevEnabled = localDev == "Yes"
	
	fmt.Println(color.GreenString("\n✓ Project settings configured successfully"))
	return config
}

func createAWSSession(config Configuration) (*session.Session, error) {
	return session.NewSession(&aws.Config{
		Region:      aws.String(config.AWSRegion),
		Credentials: credentials.NewStaticCredentials(config.AWSAccessKeyID, config.AWSSecretAccessKey, ""),
	})
}

func checkRequiredTools() {
	fmt.Println(color.CyanString("\n🔍 Checking required tools..."))
	
	requiredTools := map[string]string{
		"git":       "Git",
		"docker":    "Docker",
		"go":        "Go",
		"terraform": "Terraform",
		"aws":       "AWS CLI",
	}
	
	for cmd, name := range requiredTools {
		if _, err := exec.LookPath(cmd); err != nil {
			fmt.Printf("%s %s not found. Please install it before continuing.\n", color.RedString("✗"), name)
		} else {
			fmt.Printf("%s %s is installed\n", color.GreenString("✓"), name)
		}
	}
}

func showMainMenu() string {
	prompt := promptui.Select{
		Label: "Select an option",
		Items: []string{
			"Setup Development Environment",
			"Generate Code Templates",
			"Deploy to AWS",
			"Configure Project Settings",
			"Exit",
		},
	}
	
	_, result, err := prompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	
	return result
}

func setupDevEnvironment(config Configuration) {
	fmt.Println(color.CyanString("\n🚀 Setting up Development Environment"))
	fmt.Println(color.CyanString("----------------------------------"))
	
	// Create project directory if it doesn't exist
	projectDir := createProjectDirectory(config)
	
	// Clone project repository from GitHub if needed
	cloneRepositoryPrompt := promptui.Select{
		Label: "Do you want to clone an existing repository?",
		Items: []string{"Yes", "No"},
	}
	_, cloneRepoResult, err := cloneRepositoryPrompt.Run()
	if err != nil {
		log.Fatalf("Prompt failed: %v", err)
	}
	
	if cloneRepoResult == "Yes" {
		repoPrompt := promptui.Prompt{
			Label: "Enter repository URL",
		}
		repoURL, err := repoPrompt.Run()
		if err != nil {
			log.Fatalf("Prompt failed: %v", err)
		}
		
		cloneRepository(projectDir, repoURL, config.GitHubToken)
	} else {
		// Initialize a new Git repository
		initRepository(projectDir)
		
		// Create project structure
		createProjectStructure(projectDir)
		
		// Create initial README
		createReadme(projectDir, config)
		
		// Create .gitignore
		createGitignore(projectDir)
		
		// Create Docker Compose file
		createDockerCompose(projectDir)
		
		// Create Makefile
		createMakefile(projectDir)
		
		// Create initialization scripts
		createInitScripts(projectDir)
	}
	
	// Set up local environment if enabled
	if config.LocalDevEnabled {
		setupLocalEnvironment(projectDir, config)
	}
	
	// Create infrastructure code
	createInfrastructureCode(projectDir, config)
	
	fmt.Println(color.GreenString("\n✓ Development environment set up successfully at %s", projectDir))
}

func createProjectDirectory(config Configuration) string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		log.Fatalf("Error getting home directory: %v", err)
	}
	
	projectDir := filepath.Join(homeDir, "projects", config.ProjectName)
	if _, err := os.Stat(projectDir); os.IsNotExist(err) {
		if err := os.MkdirAll(projectDir, 0755); err != nil {
			log.Fatalf("Error creating project directory: %v", err)
		}
		fmt.Printf("%s Created project directory at %s\n", color.GreenString("✓"), projectDir)
	} else {
		fmt.Printf("%s Project directory already exists at %s\n", color.YellowString("!"), projectDir)
	}
	
	return projectDir
}

func cloneRepository(projectDir string, repoURL string, githubToken string) {
	fmt.Printf("Cloning repository from %s...\n", repoURL)
	
	// If project directory already has files, ask for confirmation to overwrite
	empty, err := isDirEmpty(projectDir)
	if err != nil {
		log.Fatalf("Error checking if directory is empty: %v", err)
	}
	
	if !empty {
		overwritePrompt := promptui.Select{
			Label: "Directory is not empty. This will overwrite existing files. Continue?",
			Items: []string{"Yes", "No"},
		}
		_, overwriteResult, err := overwritePrompt.Run()
		if err != nil {
			log.Fatalf("Prompt failed: %v", err)
		}
		
		if overwriteResult == "No" {
			fmt.Println("Clone operation cancelled.")
			return
		}
	}
	
	// Construct clone command
	gitCmd := exec.Command("git", "clone", repoURL, projectDir)
	
	// If GitHub token is provided, modify the URL to include it
	if githubToken != "" && strings.Contains(repoURL, "github.com") {
		// Convert https://github.com/username/repo.git to https://token@github.com/username/repo.git
		repoURL = strings.Replace(repoURL, "https://github.com", fmt.Sprintf("https://%s@github.com", githubToken), 1)
		gitCmd = exec.Command("git", "clone", repoURL, projectDir)
	}
	
	output, err := gitCmd.CombinedOutput()
	if err != nil {
		log.Fatalf("Error cloning repository: %v\n%s", err, output)
	}
	
	fmt.Println(color.GreenString("✓ Repository cloned successfully"))
}

func isDirEmpty(dir string) (bool, error) {
	f, err := os.Open(dir)
	if err != nil {
		return false, err
	}
	defer f.Close()
	
	// Read up to 10 file names from the directory
	names, err := f.Readdirnames(10)
	if err != nil && err != io.EOF {
		return false, err
	}
	
	// If the directory is empty except for .git, it's considered empty
	if len(names) == 0 || (len(names) == 1 && names[0] == ".git") {
		return true, nil
	}
	
	return false, nil
}

func initRepository(projectDir string) {
	fmt.Println("Initializing a new Git repository...")
	
	// Check if Git is already initialized
	gitDir := filepath.Join(projectDir, ".git")
	if _, err := os.Stat(gitDir); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! Git repository already initialized"))
		return
	}
	
	gitCmd := exec.Command("git", "init")
	gitCmd.Dir = projectDir
	output, err := gitCmd.CombinedOutput()
	if err != nil {
		log.Fatalf("Error initializing Git repository: %v\n%s", err, output)
	}
	
	fmt.Println(color.GreenString("✓ Git repository initialized"))
}

func createProjectStructure(projectDir string) {
	fmt.Println("Creating project structure...")
	
	// Create directory structure
	dirs := []string{
		"cmd",
		"internal",
		"internal/api",
		"internal/config",
		"internal/db",
		"internal/models",
		"internal/services",
		"internal/util",
		"pkg",
		"scripts",
		"web",
		"web/app",
		"web/public",
		"deployments",
		"deployments/terraform",
		"deployments/cloudformation",
		"deployments/k8s",
		"docs",
		"test",
	}
	
	for _, dir := range dirs {
		dirPath := filepath.Join(projectDir, dir)
		if _, err := os.Stat(dirPath); os.IsNotExist(err) {
			if err := os.MkdirAll(dirPath, 0755); err != nil {
				log.Fatalf("Error creating directory %s: %v", dir, err)
			}
		}
	}
	
	// Create service-specific directories
	services := []string{
		"user-service",
		"account-service",
		"trust-service",
		"investment-service",
		"document-service",
		"notification-service",
	}
	
	for _, service := range services {
		serviceDir := filepath.Join(projectDir, "cmd", service)
		if _, err := os.Stat(serviceDir); os.IsNotExist(err) {
			if err := os.MkdirAll(serviceDir, 0755); err != nil {
				log.Fatalf("Error creating service directory %s: %v", service, err)
			}
			
			// Create service main.go file
			createServiceMainFile(serviceDir, service)
			
			// Create service Dockerfile
			createServiceDockerfile(serviceDir, service)
		}
	}
	
	fmt.Println(color.GreenString("✓ Project structure created"))
}

func createServiceMainFile(serviceDir string, serviceName string) {
	mainFilePath := filepath.Join(serviceDir, "main.go")
	
	// Check if file already exists
	if _, err := os.Stat(mainFilePath); !os.IsNotExist(err) {
		fmt.Printf("%s main.go for %s already exists\n", color.YellowString("!"), serviceName)
		return
	}
	
	mainContent := fmt.Sprintf(`package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	log.Printf("Starting %s...")

	// TODO: Initialize configuration
	
	// TODO: Set up database connection
	
	// TODO: Initialize services
	
	// TODO: Set up HTTP/gRPC server
	
	// Wait for termination signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan
	
	log.Printf("Shutting down %s...")
	
	// TODO: Graceful shutdown logic
}
`, serviceName, serviceName)
	
	if err := ioutil.WriteFile(mainFilePath, []byte(mainContent), 0644); err != nil {
		log.Fatalf("Error creating service main file: %v", err)
	}
}

func createServiceDockerfile(serviceDir string, serviceName string) {
	dockerfilePath := filepath.Join(serviceDir, "Dockerfile")
	
	// Check if file already exists
	if _, err := os.Stat(dockerfilePath); !os.IsNotExist(err) {
		fmt.Printf("%s Dockerfile for %s already exists\n", color.YellowString("!"), serviceName)
		return
	}
	
	dockerfileContent := fmt.Sprintf(`# Builder stage
FROM golang:1.18-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the service
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/%s ./cmd/%s

# Final stage
FROM alpine:3.15

WORKDIR /app

# Install necessary packages
RUN apk --no-cache add ca-certificates tzdata

# Copy the binary from builder
COPY --from=builder /bin/%s /app/%s

# Expose the service port
EXPOSE 8080

# Run the service
ENTRYPOINT ["/app/%s"]
`, serviceName, serviceName, serviceName, serviceName, serviceName)
	
	if err := ioutil.WriteFile(dockerfilePath, []byte(dockerfileContent), 0644); err != nil {
		log.Fatalf("Error creating Dockerfile for %s: %v", serviceName, err)
	}
}

func createReadme(projectDir string, config Configuration) {
	readmePath := filepath.Join(projectDir, "README.md")
	
	// Check if file already exists
	if _, err := os.Stat(readmePath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! README.md already exists"))
		return
	}
	
	readmeContent := fmt.Sprintf(`# %s

## Overview

TrustAInvest.com is a secure financial technology platform that enables users to create and manage investment accounts, set up trusts, and automate investment strategies.

## Getting Started

### Prerequisites

- Go 1.18+
- Docker
- Docker Compose
- AWS CLI
- Terraform

### Setup Development Environment

1. Clone this repository
2. Run \"make setup\" to set up the local development environment
3. Run \"make run\" to start all services

### Project Structure

- \"cmd/\": Service entry points
- \"internal/\": Internal packages
- \"pkg/\": Public packages that can be imported by other projects
- \"deployments/\": Deployment configurations
- \"docs/\": Documentation
- \"test/\": Integration and e2e tests
- \"web/\": Web application

### Services

- User Service: User management and authentication
- Account Service: Financial account management
- Trust Service: Trust creation and management
- Investment Service: Investment management
- Document Service: Document generation and management
- Notification Service: Notifications and alerts

## Deployment

To deploy to AWS:

1. Configure AWS credentials
2. Run \"make deploy ENV=%s\"

## License

Proprietary - All Rights Reserved
`, config.ProjectName, config.Environment)
	
	if err := ioutil.WriteFile(readmePath, []byte(readmeContent), 0644); err != nil {
		log.Fatalf("Error creating README: %v", err)
	}
}

func createGitignore(projectDir string) {
	gitignorePath := filepath.Join(projectDir, ".gitignore")
	
	// Check if file already exists
	if _, err := os.Stat(gitignorePath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! .gitignore already exists"))
		return
	}
	
	gitignoreContent := `# Binaries for programs and plugins
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/

# Test binary, built with 'go test -c'
*.test

# Output of the go coverage tool
*.out

# Dependency directories
vendor/

# Environment variables
.env
.env.*
!.env.example

# IDE files
.idea/
.vscode/
*.swp
*.swo

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Build artifacts
dist/
*.zip
*.tar.gz

# Terraform
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars

# Docker
.docker-data/

# Local development
*.local
`
	
	if err := ioutil.WriteFile(gitignorePath, []byte(gitignoreContent), 0644); err != nil {
		log.Fatalf("Error creating .gitignore: %v", err)
	}
}

func createDockerCompose(projectDir string) {
	dockerComposePath := filepath.Join(projectDir, "docker-compose.yml")
	
	// Check if file already exists
	if _, err := os.Stat(dockerComposePath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! docker-compose.yml already exists"))
		return
	}
	
	dockerComposeContent := `version: '3.8'

services:
  postgres:
    image: postgres:14
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: trustainvest
      POSTGRES_PASSWORD: trustainvest
      POSTGRES_DB: trustainvest
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    networks:
      - backend

  redis:
    image: redis:6
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - backend

  localstack:
    image: localstack/localstack
    ports:
      - "4566:4566"
    environment:
      - SERVICES=s3,dynamodb,cognito,apigateway,lambda,sqs,sns
      - DEBUG=1
      - DATA_DIR=/tmp/localstack/data
    volumes:
      - ./scripts/init-localstack.sh:/docker-entrypoint-initdb.d/init-localstack.sh
      - localstack-data:/tmp/localstack
    networks:
      - backend

  user-service:
    build:
      context: .
      dockerfile: ./cmd/user-service/Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=trustainvest
      - DB_PASSWORD=trustainvest
      - DB_NAME=trustainvest
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - AWS_ENDPOINT=http://localstack:4566
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    networks:
      - backend
    depends_on:
      - postgres
      - redis
      - localstack

  account-service:
    build:
      context: .
      dockerfile: ./cmd/account-service/Dockerfile
    ports:
      - "8081:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=trustainvest
      - DB_PASSWORD=trustainvest
      - DB_NAME=trustainvest
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - AWS_ENDPOINT=http://localstack:4566
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - USER_SERVICE_URL=http://user-service:8080
    networks:
      - backend
    depends_on:
      - postgres
      - redis
      - localstack
      - user-service

  trust-service:
    build:
      context: .
      dockerfile: ./cmd/trust-service/Dockerfile
    ports:
      - "8082:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=trustainvest
      - DB_PASSWORD=trustainvest
      - DB_NAME=trustainvest
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - AWS_ENDPOINT=http://localstack:4566
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - USER_SERVICE_URL=http://user-service:8080
      - ACCOUNT_SERVICE_URL=http://account-service:8080
    networks:
      - backend
    depends_on:
      - postgres
      - redis
      - localstack
      - user-service
      - account-service

  investment-service:
    build:
      context: .
      dockerfile: ./cmd/investment-service/Dockerfile
    ports:
      - "8083:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=trustainvest
      - DB_PASSWORD=trustainvest
      - DB_NAME=trustainvest
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - AWS_ENDPOINT=http://localstack:4566
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
      - USER_SERVICE_URL=http://user-service:8080
      - ACCOUNT_SERVICE_URL=http://account-service:8080
    networks:
      - backend
    depends_on:
      - postgres
      - redis
      - localstack
      - user-service
      - account-service

  document-service:
    build:
      context: .
      dockerfile: ./cmd/document-service/Dockerfile
    ports:
      - "8084:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=trustainvest
      - DB_PASSWORD=trustainvest
      - DB_NAME=trustainvest
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - AWS_ENDPOINT=http://localstack:4566
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    networks:
      - backend
    depends_on:
      - postgres
      - redis
      - localstack

  notification-service:
    build:
      context: .
      dockerfile: ./cmd/notification-service/Dockerfile
    ports:
      - "8085:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=trustainvest
      - DB_PASSWORD=trustainvest
      - DB_NAME=trustainvest
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - AWS_ENDPOINT=http://localstack:4566
      - AWS_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    networks:
      - backend
    depends_on:
      - postgres
      - redis
      - localstack

networks:
  backend:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  localstack-data:
`
	
	if err := ioutil.WriteFile(dockerComposePath, []byte(dockerComposeContent), 0644); err != nil {
		log.Fatalf("Error creating docker-compose.yml: %v", err)
	}
}

func createMakefile(projectDir string) {
	makefilePath := filepath.Join(projectDir, "Makefile")
	
	// Check if file already exists
	if _, err := os.Stat(makefilePath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! Makefile already exists"))
		return
	}
	
	makefileContent := `# TrustAInvest.com Makefile

.PHONY: setup build run test clean deploy

# Default environment
ENV ?= dev

# Project settings
PROJECT_NAME := trustainvest
SERVICES := user-service account-service trust-service investment-service document-service notification-service

# Build settings
GO := go
GOFLAGS := -v
BUILD_DIR := ./bin

# Docker settings
DOCKER_COMPOSE := docker-compose
DOCKER_COMPOSE_FILE := docker-compose.yml

# AWS settings
AWS_REGION ?= us-east-1
AWS_PROFILE ?= default
TERRAFORM := terraform
TERRAFORM_DIR := ./deployments/terraform

# Setup development environment
setup:
	@echo "Setting up development environment..."
	@mkdir -p $(BUILD_DIR)
	@echo "Installing dependencies..."
	$(GO) mod tidy
	@echo "Setting up database..."
	$(DOCKER_COMPOSE) up -d postgres redis
	@echo "Setup complete!"

# Build all services
build:
	@echo "Building all services..."
	@mkdir -p $(BUILD_DIR)
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		$(GO) build $(GOFLAGS) -o $(BUILD_DIR)/$$service ./cmd/$$service; \
	done
	@echo "Build complete!"

# Run services locally using Docker Compose
run:
	@echo "Starting all services..."
	$(DOCKER_COMPOSE) up -d

# Stop all services
stop:
	@echo "Stopping all services..."
	$(DOCKER_COMPOSE) down

# Run tests
test:
	@echo "Running tests..."
	$(GO) test ./...

# Clean build artifacts
clean:
	@echo "Cleaning up..."
	rm -rf $(BUILD_DIR)
	$(DOCKER_COMPOSE) down -v
	@echo "Cleanup complete!"

# Deploy to AWS
deploy:
	@echo "Deploying to $(ENV) environment..."
	cd $(TERRAFORM_DIR)/$(ENV) && \
	$(TERRAFORM) init && \
	$(TERRAFORM) apply -auto-approve

# Generate database migrations
migrate-create:
	@echo "Creating new migration..."
	@read -p "Enter migration name: " name; \
	migrate create -ext sql -dir ./migrations -seq $$name

# Apply database migrations
migrate-up:
	@echo "Applying migrations..."
	migrate -path ./migrations -database "postgres://trustainvest:trustainvest@localhost:5432/trustainvest?sslmode=disable" up

# Rollback database migrations
migrate-down:
	@echo "Rolling back migrations..."
	migrate -path ./migrations -database "postgres://trustainvest:trustainvest@localhost:5432/trustainvest?sslmode=disable" down 1

# Generate API documentation
gen-docs:
	@echo "Generating API documentation..."
	swag init -g ./cmd/user-service/main.go -o ./docs/user-service
	swag init -g ./cmd/account-service/main.go -o ./docs/account-service
	swag init -g ./cmd/trust-service/main.go -o ./docs/trust-service
	swag init -g ./cmd/investment-service/main.go -o ./docs/investment-service
	swag init -g ./cmd/document-service/main.go -o ./docs/document-service
	swag init -g ./cmd/notification-service/main.go -o ./docs/notification-service

# Show logs for a specific service
logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Please specify a service with SERVICE=<service-name>"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) logs -f $(SERVICE)

# Create a new service
create-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "Please specify a service name with SERVICE=<service-name>"; \
		exit 1; \
	fi
	@echo "Creating new service: $(SERVICE)..."
	@mkdir -p ./cmd/$(SERVICE)
	@echo "package main\n\nimport (\n\t\"log\"\n\t\"os\"\n\t\"os/signal\"\n\t\"syscall\"\n)\n\nfunc main() {\n\tlog.Printf(\"Starting $(SERVICE)...\")\n\n\t// TODO: Initialize configuration\n\t\n\t// TODO: Set up database connection\n\t\n\t// TODO: Initialize services\n\t\n\t// TODO: Set up HTTP/gRPC server\n\t\n\t// Wait for termination signal\n\tsigChan := make(chan os.Signal, 1)\n\tsignal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)\n\t<-sigChan\n\t\n\tlog.Printf(\"Shutting down $(SERVICE)...\")\n\t\n\t// TODO: Graceful shutdown logic\n}" > ./cmd/$(SERVICE)/main.go
	@echo "Service $(SERVICE) created! Don't forget to add it to docker-compose.yml"
`
	
	if err := ioutil.WriteFile(makefilePath, []byte(makefileContent), 0644); err != nil {
		log.Fatalf("Error creating Makefile: %v", err)
	}
}

func createInitScripts(projectDir string) {
	fmt.Println("Creating initialization scripts...")
	
	scriptsDir := filepath.Join(projectDir, "scripts")
	if _, err := os.Stat(scriptsDir); os.IsNotExist(err) {
		if err := os.MkdirAll(scriptsDir, 0755); err != nil {
			log.Fatalf("Error creating scripts directory: %v", err)
		}
	}
	
	// Create init-db.sql
	initDbPath := filepath.Join(scriptsDir, "init-db.sql")
	if _, err := os.Stat(initDbPath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! init-db.sql already exists"))
	} else {
		initDbContent := `-- Create schemas
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS accounts;
CREATE SCHEMA IF NOT EXISTS trusts;
CREATE SCHEMA IF NOT EXISTS investments;
CREATE SCHEMA IF NOT EXISTS documents;
CREATE SCHEMA IF NOT EXISTS notifications;

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users schema tables
CREATE TABLE IF NOT EXISTS users.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone_number VARCHAR(50),
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    date_of_birth DATE NOT NULL,
    street VARCHAR(255),
    city VARCHAR(255),
    state VARCHAR(50),
    zip_code VARCHAR(20),
    country VARCHAR(50) DEFAULT 'USA',
    ssn_encrypted BYTEA,
    risk_profile VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    device_id VARCHAR(255),
    kyc_status VARCHAR(50) DEFAULT 'PENDING',
    kyc_verified_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create accounts schema tables
CREATE TABLE IF NOT EXISTS accounts.accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users.users(id),
    type VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    institution_id VARCHAR(255),
    institution_name VARCHAR(255),
    external_account_id VARCHAR(255),
    balance_amount DECIMAL(19, 4) NOT NULL DEFAULT 0,
    balance_currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    trust_id UUID,
    tax_status VARCHAR(50)
);

-- Create example user for development
INSERT INTO users.users (
    username, email, first_name, last_name, date_of_birth, 
    street, city, state, zip_code, country, risk_profile
) VALUES (
    'demo_user', 'demo@trustainvest.com', 'Demo', 'User', '1980-01-01',
    '123 Main St', 'New York', 'NY', '10001', 'USA', 'MODERATE'
) ON CONFLICT (username) DO NOTHING;
`
		
		if err := ioutil.WriteFile(initDbPath, []byte(initDbContent), 0644); err != nil {
			log.Fatalf("Error creating init-db.sql: %v", err)
		}
	}
	
	// Create init-localstack.sh
	initLocalstackPath := filepath.Join(scriptsDir, "init-localstack.sh")
	if _, err := os.Stat(initLocalstackPath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! init-localstack.sh already exists"))
	} else {
		initLocalstackContent := `#!/bin/bash
set -e

echo "Initializing LocalStack resources..."

# Create S3 buckets
echo "Creating S3 buckets..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-documents || true
aws --endpoint-url=http://localhost:4566 s3 mb s3://trustainvest-artifacts || true

# Create DynamoDB tables
echo "Creating DynamoDB tables..."
aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name user-sessions \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    || true

aws --endpoint-url=http://localhost:4566 dynamodb create-table \
    --table-name market-data \
    --attribute-definitions AttributeName=symbol,AttributeType=S AttributeName=timestamp,AttributeType=N \
    --key-schema AttributeName=symbol,KeyType=HASH AttributeName=timestamp,KeyType=RANGE \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    || true

# Create Cognito User Pool
echo "Creating Cognito User Pool..."
aws --endpoint-url=http://localhost:4566 cognito-idp create-user-pool \
    --pool-name trustainvest-user-pool \
    --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":true}}' \
    --auto-verified-attributes email \
    --schema '[{"Name":"email","Required":true},{"Name":"phone_number","Required":false}]' \
    --mfa-configuration OFF \
    || true

# Create API Gateway
echo "Creating API Gateway..."
aws --endpoint-url=http://localhost:4566 apigateway create-rest-api \
    --name trustainvest-api \
    || true

# Create SQS queues
echo "Creating SQS queues..."
aws --endpoint-url=http://localhost:4566 sqs create-queue \
    --queue-name notification-queue \
    || true

aws --endpoint-url=http://localhost:4566 sqs create-queue \
    --queue-name document-processing-queue \
    || true

# Create SNS topics
echo "Creating SNS topics..."
aws --endpoint-url=http://localhost:4566 sns create-topic \
    --name user-events \
    || true

aws --endpoint-url=http://localhost:4566 sns create-topic \
    --name transaction-events \
    || true

echo "LocalStack initialization complete!"
`
		
		if err := ioutil.WriteFile(initLocalstackPath, []byte(initLocalstackContent), 0644); err != nil {
			log.Fatalf("Error creating init-localstack.sh: %v", err)
		}
		
		// Make script executable
		if err := os.Chmod(initLocalstackPath, 0755); err != nil {
			log.Fatalf("Error making script executable: %v", err)
		}
	}
}

func setupLocalEnvironment(projectDir string, config Configuration) {
	fmt.Println(color.CyanString("\nSetting up local development environment..."))
	
	// Create example service configuration file
	createConfigFile(projectDir)
	
	// Create go.mod file
	createGoModFile(projectDir, config)
	
	fmt.Println(color.GreenString("✓ Local development environment set up successfully"))
}

func createConfigFile(projectDir string) {
	configDir := filepath.Join(projectDir, "internal", "config")
	configFilePath := filepath.Join(configDir, "config.go")
	
	// Check if file already exists
	if _, err := os.Stat(configFilePath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! config.go already exists"))
		return
	}
	
	configContent := `package config

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
`
	
	if err := os.MkdirAll(configDir, 0755); err != nil {
		log.Fatalf("Error creating config directory: %v", err)
	}
	
	if err := ioutil.WriteFile(configFilePath, []byte(configContent), 0644); err != nil {
		log.Fatalf("Error creating config file: %v", err)
	}
}

func createGoModFile(projectDir string, config Configuration) {
	goModPath := filepath.Join(projectDir, "go.mod")
	
	// Check if file already exists
	if _, err := os.Stat(goModPath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! go.mod already exists"))
		return
	}
	
	goModContent := fmt.Sprintf(`module github.com/%s/%s

go 1.18

require (
	github.com/aws/aws-sdk-go v1.44.69
	github.com/gin-gonic/gin v1.8.1
	github.com/go-playground/validator/v10 v10.11.0
	github.com/golang-jwt/jwt v3.2.2+incompatible
	github.com/google/uuid v1.3.0
	github.com/jackc/pgx/v4 v4.17.0
	github.com/joho/godotenv v1.4.0
	github.com/redis/go-redis/v9 v9.0.2
	github.com/sirupsen/logrus v1.9.0
	github.com/swaggo/gin-swagger v1.5.2
	github.com/swaggo/swag v1.8.4
	golang.org/x/crypto v0.0.0-20220722155217-630584e8d5aa
	gopkg.in/yaml.v2 v2.4.0
)
`, config.DockerHubUsername, config.ProjectName)
	
	if err := ioutil.WriteFile(goModPath, []byte(goModContent), 0644); err != nil {
		log.Fatalf("Error creating go.mod file: %v", err)
	}
}

func createInfrastructureCode(projectDir string, config Configuration) {
	fmt.Println(color.CyanString("\nGenerating infrastructure code..."))
	
	// Create Terraform files
	createTerraformFiles(projectDir, config)
	
	// Create CloudFormation template
	createCloudFormationTemplate(projectDir, config)
	
	fmt.Println(color.GreenString("✓ Infrastructure code generated successfully"))
}

func createTerraformFiles(projectDir string, config Configuration) {
	terraformDir := filepath.Join(projectDir, "deployments", "terraform", config.Environment)
	if _, err := os.Stat(terraformDir); os.IsNotExist(err) {
		if err := os.MkdirAll(terraformDir, 0755); err != nil {
			log.Fatalf("Error creating Terraform directory: %v", err)
		}
	}
	
	// Check if files already exist
	mainTfPath := filepath.Join(terraformDir, "main.tf")
	if _, err := os.Stat(mainTfPath); !os.IsNotExist(err) {
		fmt.Println(color.YellowString("! Terraform files already exist"))
		return
	}
	
	// Create main.tf
	mainTfContent := fmt.Sprintf(`provider "aws" {
  region = "%s"
}

module "vpc" {
  source = "../modules/vpc"
  
  environment = "%s"
  project_name = "%s"
  cidr_block = "10.0.0.0/16"
  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
}

module "security" {
  source = "../modules/security"
  
  environment = "%s"
  project_name = "%s"
  vpc_id = module.vpc.vpc_id
}

module "database" {
  source = "../modules/database"
  
  environment = "%s"
  project_name = "%s"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.db_security_group_id
  instance_class = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  password = var.db_password
}

module "cache" {
  source = "../modules/cache"
  
  environment = "%s"
  project_name = "%s"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.cache_security_group_id
}

module "cognito" {
  source = "../modules/cognito"
  
  environment = "%s"
  project_name = "%s"
}

module "storage" {
  source = "../modules/storage"
  
  environment = "%s"
  project_name = "%s"
  documents_bucket_name = "%s-documents-${var.environment}"
  artifacts_bucket_name = "%s"
}

module "api_gateway" {
  source = "../modules/api_gateway"
  
  environment = "%s"
  project_name = "%s"
  cognito_user_pool_id = module.cognito.user_pool_id
}

module "ecs" {
  source = "../modules/ecs"
  
  environment = "%s"
  project_name = "%s"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_id = module.security.ecs_security_group_id
  db_host = module.database.db_host
  db_name = module.database.db_name
  db_user = module.database.db_user
  db_password = var.db_password
  redis_host = module.cache.redis_host
  cognito_user_pool_id = module.cognito.user_pool_id
  documents_bucket_name = module.storage.documents_bucket_name
}
`, config.AWSRegion, config.Environment, config.ProjectName, 
   config.Environment, config.ProjectName,
   config.Environment, config.ProjectName,
   config.Environment, config.ProjectName,
   config.Environment, config.ProjectName,
   config.Environment, config.ProjectName, config.ProjectName, config.S3BucketArtifacts,
   config.Environment, config.ProjectName,
   config.Environment, config.ProjectName)
	
	if err := ioutil.WriteFile(mainTfPath, []byte(mainTfContent), 0644); err != nil {
		log.Fatalf("Error creating main.tf: %v", err)
	}
	
	// Create variables.tf
	variablesTfPath := filepath.Join(terraformDir, "variables.tf")
	variablesTfContent := fmt.Sprintf(`variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "%s"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  default     = "%s"
}

variable "project_name" {
  description = "Project name"
  default     = "%s"
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  default     = 20
}

variable "db_password" {
  description = "RDS master password"
  sensitive   = true
}
`, config.AWSRegion, config.Environment, config.ProjectName)
	
	if err := ioutil.WriteFile(variablesTfPath, []byte(variablesTfContent), 0644); err != nil {
		log.Fatalf("Error creating variables.tf: %v", err)
	}
	
	// Create outputs.tf
	outputsTfPath := filepath.Join(terraformDir, "outputs.tf")
	outputsTfContent := `output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.database.db_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache endpoint"
  value       = module.cache.redis_endpoint
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_gateway_url
}

output "documents_bucket_name" {
  description = "S3 bucket for documents"
  value       = module.storage.documents_bucket_name
}
`
	
	if err := ioutil.WriteFile(outputsTfPath, []byte(outputsTfContent), 0644); err != nil {
		log.Fatalf("Error creating outputs.tf: %v", err)
	}
	
	// Create terraform.tfvars example
	tfvarsPath := filepath.Join(terraformDir, "terraform.tfvars.example")
	tfvarsContent := fmt.Sprintf(`aws_region = "%s"
environment = "%s"
project_name = "%s"
db_instance_class = "db.t3.small"
db_allocated_storage = 20
db_password = "changeme"
`, config.AWSRegion, config.Environment, config.ProjectName)
	
	if err := ioutil.WriteFile(tfvarsPath, []byte(tfvarsContent), 0644); err != nil {
		log.Fatalf("Error creating terraform.tfvars.example: %v", err)
	}
	
	// Create modules directory structure
	modulesDir := filepath.Join(projectDir, "deployments", "terraform", "modules")
	moduleDirs := []string{
		"vpc", "security", "database", "cache", "cognito", "storage", "api_gateway", "ecs",
	}
	
	for _, dir := range moduleDirs {
		moduleDir := filepath.Join(modulesDir, dir)
		if _, err := os.Stat(moduleDir); os.IsNotExist(err) {
			if err := os.MkdirAll(moduleDir, 0755); err != nil {
				log.Fatalf("Error creating module directory %s: %v", dir, err)
			}
			
			// Create empty main.tf, variables.tf, and outputs.tf
			emptyMainTf := fmt.Sprintf(`# %s module
# TODO: Implement the %s module
`, dir, dir)
			emptyMainPath := filepath.Join(moduleDir, "main.tf")
			if err := ioutil.WriteFile(emptyMainPath, []byte(emptyMainTf), 0644); err != nil {
				log.Fatalf("Error creating empty main.tf for %s: %v", dir, err)
			}
			
			emptyVarsTf := `# Module input variables
`
			emptyVarsPath := filepath.Join(moduleDir, "variables.tf")
			if err := ioutil.WriteFile(emptyVarsPath, []byte(emptyVarsTf), 0644); err != nil {
				log.Fatalf("Error creating empty variables.tf for %s: %v", dir, err)
			}
			
			emptyOutputsTf := `# Module outputs
`
emptyOutputsPath := filepath.Join(moduleDir, "outputs.tf")
if err := ioutil.WriteFile(emptyOutputsPath, []byte(emptyOutputsTf), 0644); err != nil {
	log.Fatalf("Error creating empty outputs.tf for %s: %v", dir, err)
}
}
}
}

func createCloudFormationTemplate(projectDir string, config Configuration) {
cfDir := filepath.Join(projectDir, "deployments", "cloudformation")
if _, err := os.Stat(cfDir); os.IsNotExist(err) {
if err := os.MkdirAll(cfDir, 0755); err != nil {
log.Fatalf("Error creating CloudFormation directory: %v", err)
}
}

cfPath := filepath.Join(cfDir, "trustainvest-stack.yaml")
if _, err := os.Stat(cfPath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! CloudFormation template already exists"))
return
}

cfContent := fmt.Sprintf(`AWSTemplateFormatVersion: '2010-09-09'
Description: 'TrustAInvest Infrastructure Stack'

Parameters:
Environment:
Type: String
Default: %s
AllowedValues:
- dev
- stage
- prod
Description: Environment name

ProjectName:
Type: String
Default: %s
Description: Project name

DBPassword:
Type: String
NoEcho: true
Description: Database master password

Resources:
# VPC and Network
VPC:
Type: AWS::EC2::VPC
Properties:
CidrBlock: 10.0.0.0/16
EnableDnsSupport: true
EnableDnsHostnames: true
Tags:
- Key: Name
Value: !Sub ${ProjectName}-${Environment}-vpc

# Example of RDS instance
RDSInstance:
Type: AWS::RDS::DBInstance
Properties:
DBInstanceIdentifier: !Sub ${ProjectName}-${Environment}
AllocatedStorage: 20
DBInstanceClass: db.t3.small
Engine: postgres
MasterUsername: trustainvest
MasterUserPassword: !Ref DBPassword
VPCSecurityGroups:
- !GetAtt DBSecurityGroup.GroupId
DBSubnetGroupName: !Ref DBSubnetGroup
Tags:
- Key: Name
Value: !Sub ${ProjectName}-${Environment}-db

# Cognito User Pool
UserPool:
Type: AWS::Cognito::UserPool
Properties:
UserPoolName: !Sub ${ProjectName}-${Environment}-user-pool
AutoVerifiedAttributes:
- email
Policies:
PasswordPolicy:
MinimumLength: 8
RequireUppercase: true
RequireLowercase: true
RequireNumbers: true
RequireSymbols: true
Schema:
- Name: email
AttributeDataType: String
Mutable: true
Required: true
- Name: phone_number
AttributeDataType: String
Mutable: true
Required: false

Outputs:
VpcId:
Description: VPC ID
Value: !Ref VPC
Export:
Name: !Sub ${ProjectName}-${Environment}-vpc-id

DBEndpoint:
Description: RDS Endpoint
Value: !GetAtt RDSInstance.Endpoint.Address
Export:
Name: !Sub ${ProjectName}-${Environment}-db-endpoint

UserPoolId:
Description: Cognito User Pool ID
Value: !Ref UserPool
Export:
Name: !Sub ${ProjectName}-${Environment}-user-pool-id
`, config.Environment, config.ProjectName)

if err := ioutil.WriteFile(cfPath, []byte(cfContent), 0644); err != nil {
log.Fatalf("Error creating CloudFormation template: %v", err)
}
}

func generateCodeTemplates(config Configuration) {
fmt.Println(color.CyanString("\n🧩 Generating Code Templates"))
fmt.Println(color.CyanString("-------------------------"))

// Ask user for what templates to generate
templates := []string{
"API Handler",
"Database Repository",
"Service Layer",
"Model",
"Middleware",
"AWS Integration",
"Authentication",
"All Templates",
"Cancel",
}

prompt := promptui.Select{
Label: "What templates would you like to generate?",
Items: templates,
}

_, result, err := prompt.Run()
if err != nil {
log.Fatalf("Prompt failed: %v", err)
}

if result == "Cancel" {
return
}

homeDir, err := os.UserHomeDir()
if err != nil {
log.Fatalf("Error getting home directory: %v", err)
}

projectDir := filepath.Join(homeDir, "projects", config.ProjectName)

if _, err := os.Stat(projectDir); os.IsNotExist(err) {
fmt.Println(color.YellowString("Project directory does not exist. Please set up the development environment first."))
return
}

// Generate the requested templates
if result == "All Templates" || result == "API Handler" {
generateAPIHandler(projectDir)
}

if result == "All Templates" || result == "Database Repository" {
generateRepository(projectDir)
}

if result == "All Templates" || result == "Service Layer" {
generateService(projectDir)
}

if result == "All Templates" || result == "Model" {
generateModel(projectDir)
}

if result == "All Templates" || result == "Middleware" {
generateMiddleware(projectDir)
}

if result == "All Templates" || result == "AWS Integration" {
generateAWSIntegration(projectDir)
}

if result == "All Templates" || result == "Authentication" {
generateAuthentication(projectDir)
}

fmt.Println(color.GreenString("✓ Code templates generated successfully"))
}

func generateAPIHandler(projectDir string) {
fmt.Println("Generating API Handler template...")

apiDir := filepath.Join(projectDir, "internal", "api")
if err := os.MkdirAll(apiDir, 0755); err != nil {
log.Fatalf("Error creating API directory: %v", err)
}

handlerPath := filepath.Join(apiDir, "user_handler.go")
if _, err := os.Stat(handlerPath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! API Handler already exists"))
return
}

handlerContent := `package api

import (
"net/http"

"github.com/gin-gonic/gin"
"github.com/google/uuid"
)

// UserHandler handles HTTP requests for user operations
type UserHandler struct {
userService UserService
}

// NewUserHandler creates a new UserHandler
func NewUserHandler(userService UserService) *UserHandler {
return &UserHandler{
userService: userService,
}
}

// UserService defines the user service interface
type UserService interface {
GetUserByID(id string) (*User, error)
CreateUser(user *User) error
UpdateUser(user *User) error
DeleteUser(id string) error
}

// User represents a user entity
type User struct {
ID        string ` + "`json:\"id\"`" + `
Username  string ` + "`json:\"username\"`" + `
Email     string ` + "`json:\"email\"`" + `
FirstName string ` + "`json:\"first_name\"`" + `
LastName  string ` + "`json:\"last_name\"`" + `
}

// RegisterRoutes registers the user API routes
func (h *UserHandler) RegisterRoutes(router *gin.Engine) {
userGroup := router.Group("/api/v1/users")
{
userGroup.GET("/:id", h.GetUser)
userGroup.POST("/", h.CreateUser)
userGroup.PUT("/:id", h.UpdateUser)
userGroup.DELETE("/:id", h.DeleteUser)
}
}

// GetUser godoc
// @Summary Get a user by ID
// @Description Get user details by user ID
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} User
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users/{id} [get]
func (h *UserHandler) GetUser(c *gin.Context) {
id := c.Param("id")

user, err := h.userService.GetUserByID(id)
if err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

if user == nil {
c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
return
}

c.JSON(http.StatusOK, user)
}

// CreateUser godoc
// @Summary Create a new user
// @Description Create a new user with the provided details
// @Tags users
// @Accept json
// @Produce json
// @Param user body User true "User details"
// @Success 201 {object} User
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users [post]
func (h *UserHandler) CreateUser(c *gin.Context) {
var user User
if err := c.ShouldBindJSON(&user); err != nil {
c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
return
}

// Generate a new UUID for the user
user.ID = uuid.New().String()

if err := h.userService.CreateUser(&user); err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

c.JSON(http.StatusCreated, user)
}

// UpdateUser godoc
// @Summary Update a user
// @Description Update an existing user's details
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Param user body User true "User details"
// @Success 200 {object} User
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users/{id} [put]
func (h *UserHandler) UpdateUser(c *gin.Context) {
id := c.Param("id")

var user User
if err := c.ShouldBindJSON(&user); err != nil {
c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
return
}

user.ID = id

if err := h.userService.UpdateUser(&user); err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

c.JSON(http.StatusOK, user)
}

// DeleteUser godoc
// @Summary Delete a user
// @Description Delete a user by ID
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Success 204 "No Content"
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users/{id} [delete]
func (h *UserHandler) DeleteUser(c *gin.Context) {
id := c.Param("id")

if err := h.userService.DeleteUser(id); err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

c.Status(http.StatusNoContent)
}

// ErrorResponse represents an error response
type ErrorResponse struct {
Error string ` + "`json:\"error\"`" + `
}
`

if err := ioutil.WriteFile(handlerPath, []byte(handlerContent), 0644); err != nil {
log.Fatalf("Error creating API handler file: %v", err)
}
}

func generateRepository(projectDir string) {
fmt.Println("Generating Repository template...")

dbDir := filepath.Join(projectDir, "internal", "db")
if err := os.MkdirAll(dbDir, 0755); err != nil {
log.Fatalf("Error creating database directory: %v", err)
}

repoPath := filepath.Join(dbDir, "user_repository.go")
if _, err := os.Stat(repoPath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! Repository already exists"))
return
}

repoContent := `package db

import (
"context"
"errors"
"fmt"
"time"

"github.com/jackc/pgx/v4/pgxpool"
)

// UserRepository handles database operations for users
type UserRepository struct {
db *pgxpool.Pool
}

// NewUserRepository creates a new UserRepository
func NewUserRepository(db *pgxpool.Pool) *UserRepository {
return &UserRepository{
db: db,
}
}

// User represents a user entity in the database
type User struct {
ID           string
Username     string
Email        string
PhoneNumber  string
FirstName    string
LastName     string
DateOfBirth  time.Time
Street       string
City         string
State        string
ZipCode      string
Country      string
SSNEncrypted []byte
RiskProfile  string
CreatedAt    time.Time
UpdatedAt    time.Time
DeviceID     string
KYCStatus    string
KYCVerifiedAt *time.Time
IsActive     bool
}

// GetByID retrieves a user by ID
func (r *UserRepository) GetByID(ctx context.Context, id string) (*User, error) {
query := ` + "`" + `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE id = $1 AND is_active = true
` + "`" + `

var user User
err := r.db.QueryRow(ctx, query, id).Scan(
&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
&user.DateOfBirth, &user.Street, &user.City, &user.State, &user.ZipCode, &user.Country,
&user.SSNEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
&user.DeviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
)

if err != nil {
return nil, fmt.Errorf("error getting user by ID: %w", err)
}

return &user, nil
}

// Create inserts a new user into the database
func (r *UserRepository) Create(ctx context.Context, user *User) error {
query := ` + "`" + `
INSERT INTO users.users (
id, username, email, phone_number, first_name, last_name, 
date_of_birth, street, city, state, zip_code, country,
ssn_encrypted, risk_profile, device_id, kyc_status, is_active
) VALUES (
$1, $2, $3, $4, $5, $6, 
$7, $8, $9, $10, $11, $12,
$13, $14, $15, $16, $17
)
` + "`" + `

_, err := r.db.Exec(ctx, query,
user.ID, user.Username, user.Email, user.PhoneNumber, user.FirstName, user.LastName,
user.DateOfBirth, user.Street, user.City, user.State, user.ZipCode, user.Country,
user.SSNEncrypted, user.RiskProfile, user.DeviceID, user.KYCStatus, user.IsActive,
)

if err != nil {
return fmt.Errorf("error creating user: %w", err)
}

return nil
}

// Update updates an existing user in the database
func (r *UserRepository) Update(ctx context.Context, user *User) error {
query := ` + "`" + `
UPDATE users.users
SET username = $2, email = $3, phone_number = $4, first_name = $5, last_name = $6,
date_of_birth = $7, street = $8, city = $9, state = $10, zip_code = $11, country = $12,
risk_profile = $13, updated_at = NOW()
WHERE id = $1 AND is_active = true
` + "`" + `

result, err := r.db.Exec(ctx, query,
user.ID, user.Username, user.Email, user.PhoneNumber, user.FirstName, user.LastName,
user.DateOfBirth, user.Street, user.City, user.State, user.ZipCode, user.Country,
user.RiskProfile,
)

if err != nil {
return fmt.Errorf("error updating user: %w", err)
}

rowsAffected := result.RowsAffected()
if rowsAffected == 0 {
return errors.New("user not found")
}

return nil
}

// Delete soft-deletes a user by setting isActive to false
func (r *UserRepository) Delete(ctx context.Context, id string) error {
query := ` + "`" + `
UPDATE users.users
SET is_active = false, updated_at = NOW()
WHERE id = $1 AND is_active = true
` + "`" + `

result, err := r.db.Exec(ctx, query, id)
if err != nil {
return fmt.Errorf("error deleting user: %w", err)
}

rowsAffected := result.RowsAffected()
if rowsAffected == 0 {
return errors.New("user not found")
}

return nil
}

// GetByUsername retrieves a user by username
func (r *UserRepository) GetByUsername(ctx context.Context, username string) (*User, error) {
query := ` + "`" + `
SELECT id, username, email, phone_number, first_name, last_name, 
   date_of_birth, street, city, state, zip_code, country,
   ssn_encrypted, risk_profile, created_at, updated_at,
   device_id, kyc_status, kyc_verified_at, is_active
FROM users.users
WHERE username = $1 AND is_active = true
` + "`" + `

var user User
err := r.db.QueryRow(ctx, query, username).Scan(
&user.ID, &user.Username, &user.Email, &user.PhoneNumber, &user.FirstName, &user.LastName,
&user.DateOfBirth, &user.Street, &user.City, &user.State, &user.ZipCode, &user.Country,
&user.SSNEncrypted, &user.RiskProfile, &user.CreatedAt, &user.UpdatedAt,
&user.DeviceID, &user.KYCStatus, &user.KYCVerifiedAt, &user.IsActive,
)

if err != nil {
return nil, fmt.Errorf("error getting user by username: %w", err)
}

return &user, nil
}
`

if err := ioutil.WriteFile(repoPath, []byte(repoContent), 0644); err != nil {
log.Fatalf("Error creating repository file: %v", err)
}
}

func generateService(projectDir string) {
fmt.Println("Generating Service template...")

servicesDir := filepath.Join(projectDir, "internal", "services")
if err := os.MkdirAll(servicesDir, 0755); err != nil {
log.Fatalf("Error creating services directory: %v", err)
}

servicePath := filepath.Join(servicesDir, "user_service.go")
if _, err := os.Stat(servicePath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! Service already exists"))
return
}

serviceContent := `package services

import (
"context"
"errors"
"time"

"github.com/google/uuid"
"golang.org/x/crypto/bcrypt"
)

// UserRepository defines the user repository interface
type UserRepository interface {
GetByID(ctx context.Context, id string) (*User, error)
GetByUsername(ctx context.Context, username string) (*User, error)
GetByEmail(ctx context.Context, email string) (*User, error)
Create(ctx context.Context, user *User) error
Update(ctx context.Context, user *User) error
Delete(ctx context.Context, id string) error
}

// User represents a user entity
type User struct {
ID           string
Username     string
Email        string
PhoneNumber  string
FirstName    string
LastName     string
DateOfBirth  time.Time
Street       string
City         string
State        string
ZipCode      string
Country      string
SSNEncrypted []byte
Password     string
PasswordHash []byte
RiskProfile  string
CreatedAt    time.Time
UpdatedAt    time.Time
DeviceID     string
KYCStatus    string
KYCVerifiedAt *time.Time
IsActive     bool
}

// UserService handles business logic for users
type UserService struct {
repo UserRepository
}

// NewUserService creates a new UserService
func NewUserService(repo UserRepository) *UserService {
return &UserService{
repo: repo,
}
}

// GetUserByID retrieves a user by ID
func (s *UserService) GetUserByID(ctx context.Context, id string) (*User, error) {
return s.repo.GetByID(ctx, id)
}

// CreateUser creates a new user
func (s *UserService) CreateUser(ctx context.Context, user *User) error {
// Validate user input
if user.Username == "" || user.Email == "" || user.FirstName == "" || user.LastName == "" {
return errors.New("missing required fields")
}

// Check if username or email already exists
existingByUsername, _ := s.repo.GetByUsername(ctx, user.Username)
if existingByUsername != nil {
return errors.New("username already exists")
}

existingByEmail, _ := s.repo.GetByEmail(ctx, user.Email)
if existingByEmail != nil {
return errors.New("email already exists")
}

// Generate ID if not provided
if user.ID == "" {
user.ID = uuid.New().String()
}

// Hash password if provided
if user.Password != "" {
hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
if err != nil {
return err
}
user.PasswordHash = hashedPassword
}

// Set default values
user.CreatedAt = time.Now()
user.UpdatedAt = time.Now()
user.IsActive = true
user.KYCStatus = "PENDING"

// Save user to database
return s.repo.Create(ctx, user)
}

// UpdateUser updates an existing user
func (s *UserService) UpdateUser(ctx context.Context, user *User) error {
// Validate user input
if user.ID == "" {
return errors.New("user ID is required")
}

// Get existing user
existingUser, err := s.repo.GetByID(ctx, user.ID)
if err != nil {
return err
}

if existingUser == nil {
return errors.New("user not found")
}

// Update fields
if user.Username != "" && user.Username != existingUser.Username {
// Check if new username is already taken
existingByUsername, _ := s.repo.GetByUsername(ctx, user.Username)
if existingByUsername != nil && existingByUsername.ID != user.ID {
return errors.New("username already exists")
}
existingUser.Username = user.Username
}

if user.Email != "" && user.Email != existingUser.Email {
// Check if new email is already taken
existingByEmail, _ := s.repo.GetByEmail(ctx, user.Email)
if existingByEmail != nil && existingByEmail.ID != user.ID {
return errors.New("email already exists")
}
existingUser.Email = user.Email
}

// Update other fields
if user.FirstName != "" {
existingUser.FirstName = user.FirstName
}

if user.LastName != "" {
existingUser.LastName = user.LastName
}

if !user.DateOfBirth.IsZero() {
existingUser.DateOfBirth = user.DateOfBirth
}

if user.PhoneNumber != "" {
existingUser.PhoneNumber = user.PhoneNumber
}

if user.Street != "" {
existingUser.Street = user.Street
}

if user.City != "" {
existingUser.City = user.City
}

if user.State != "" {
existingUser.State = user.State
}

if user.ZipCode != "" {
existingUser.ZipCode = user.ZipCode
}

if user.Country != "" {
existingUser.Country = user.Country
}

if user.RiskProfile != "" {
existingUser.RiskProfile = user.RiskProfile
}

// Update password if provided
if user.Password != "" {
hashedPassword, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
if err != nil {
return err
}
existingUser.PasswordHash = hashedPassword
}

// Update timestamp
existingUser.UpdatedAt = time.Now()

// Save updated user
return s.repo.Update(ctx, existingUser)
}

// DeleteUser deletes a user by ID
func (s *UserService) DeleteUser(ctx context.Context, id string) error {
return s.repo.Delete(ctx, id)
}
`

if err := ioutil.WriteFile(servicePath, []byte(serviceContent), 0644); err != nil {
log.Fatalf("Error creating service file: %v", err)
}
}

func deployToAWS(config Configuration, awsSession *session.Session) {
fmt.Println(color.CyanString("\n🚀 Deploying to AWS"))
fmt.Println(color.CyanString("----------------"))

// Ask for deployment confirmation
confirmPrompt := promptui.Select{
Label: fmt.Sprintf("Are you sure you want to deploy to the %s environment?", config.Environment),
Items: []string{"Yes", "No"},
}
_, confirmResult, err := confirmPrompt.Run()
if err != nil {
log.Fatalf("Prompt failed: %v", err)
}

if confirmResult == "No" {
fmt.Println("Deployment canceled.")
return
}

// Determine deployment strategy
deploymentPrompt := promptui.Select{
Label: "Select deployment strategy",
Items: []string{"CloudFormation", "Terraform", "Cancel"},
}
_, deploymentStrategy, err := deploymentPrompt.Run()
if err != nil {
log.Fatalf("Prompt failed: %v", err)
}

if deploymentStrategy == "Cancel" {
fmt.Println("Deployment canceled.")
return
}

homeDir, err := os.UserHomeDir()
if err != nil {
log.Fatalf("Error getting home directory: %v", err)
}

projectDir := filepath.Join(homeDir, "projects", config.ProjectName)

if deploymentStrategy == "CloudFormation" {
deployCFStack(projectDir, config, awsSession)
} else if deploymentStrategy == "Terraform" {
deployTerraform(projectDir, config)
}
}

func deployCFStack(projectDir string, config Configuration, awsSession *session.Session) {
fmt.Println("Deploying using CloudFormation...")

// Check if CloudFormation template exists
cfPath := filepath.Join(projectDir, "deployments", "cloudformation", "trustainvest-stack.yaml")
if _, err := os.Stat(cfPath); os.IsNotExist(err) {
log.Fatalf("CloudFormation template not found at %s", cfPath)
}

// Read CloudFormation template
cfTemplate, err := ioutil.ReadFile(cfPath)
if err != nil {
log.Fatalf("Error reading CloudFormation template: %v", err)
}

// Create CloudFormation client
cfClient := cloudformation.New(awsSession)

// Check if stack exists
_, err = cfClient.DescribeStacks(&cloudformation.DescribeStacksInput{
StackName: aws.String(config.StackName),
})

// Get DB password
dbPasswordPrompt := promptui.Prompt{
Label: "Enter database password",
Mask:  '*',
}
dbPassword, err := dbPasswordPrompt.Run()
if err != nil {
log.Fatalf("Prompt failed: %v", err)
}

// Create or update stack based on existence
stackExists := err == nil

if !stackExists {
// Stack doesn't exist, create it
fmt.Printf("Creating CloudFormation stack %s...\n", config.StackName)

_, err = cfClient.CreateStack(&cloudformation.CreateStackInput{
	StackName:    aws.String(config.StackName),
	TemplateBody: aws.String(string(cfTemplate)),
	Parameters: []*cloudformation.Parameter{
		{
			ParameterKey:   aws.String("Environment"),
			ParameterValue: aws.String(config.Environment),
		},
		{
			ParameterKey:   aws.String("ProjectName"),
			ParameterValue: aws.String(config.ProjectName),
		},
		{
			ParameterKey:   aws.String("DBPassword"),
			ParameterValue: aws.String(dbPassword),
		},
	},
	Capabilities: []*string{
		aws.String("CAPABILITY_IAM"),
		aws.String("CAPABILITY_NAMED_IAM"),
	},
})

if err != nil {
	log.Fatalf("Error creating CloudFormation stack: %v", err)
}

fmt.Println("Stack creation initiated. Check the AWS CloudFormation console for status.")
} else {
// Stack exists, update it
fmt.Printf("Updating CloudFormation stack %s...\n", config.StackName)

_, err = cfClient.UpdateStack(&cloudformation.UpdateStackInput{
	StackName:    aws.String(config.StackName),
	TemplateBody: aws.String(string(cfTemplate)),
	Parameters: []*cloudformation.Parameter{
		{
			ParameterKey:   aws.String("Environment"),
			ParameterValue: aws.String(config.Environment),
		},
		{
			ParameterKey:   aws.String("ProjectName"),
			ParameterValue: aws.String(config.ProjectName),
		},
		{
			ParameterKey:   aws.String("DBPassword"),
			ParameterValue: aws.String(dbPassword),
		},
	},
	Capabilities: []*string{
		aws.String("CAPABILITY_IAM"),
		aws.String("CAPABILITY_NAMED_IAM"),
	},
})

if err != nil {
	if strings.Contains(err.Error(), "No updates are to be performed") {
		fmt.Println("No updates are needed for the stack.")
	} else {
		log.Fatalf("Error updating CloudFormation stack: %v", err)
	}
} else {
	fmt.Println("Stack update initiated. Check the AWS CloudFormation console for status.")
}
}

// Create/check S3 bucket for artifacts
s3Client := s3.New(awsSession)

// Check if bucket exists
_, err = s3Client.HeadBucket(&s3.HeadBucketInput{
Bucket: aws.String(config.S3BucketArtifacts),
})

if err != nil {
// Bucket doesn't exist, create it
fmt.Printf("Creating S3 bucket %s...\n", config.S3BucketArtifacts)

_, err = s3Client.CreateBucket(&s3.CreateBucketInput{
	Bucket: aws.String(config.S3BucketArtifacts),
	CreateBucketConfiguration: &s3.CreateBucketConfiguration{
		LocationConstraint: aws.String(config.AWSRegion),
	},
})

if err != nil {
	fmt.Printf("Error creating S3 bucket: %v\n", err)
} else {
	fmt.Printf("S3 bucket %s created successfully.\n", config.S3BucketArtifacts)
}
} else {
fmt.Printf("S3 bucket %s already exists.\n", config.S3BucketArtifacts)
}
}

func deployTerraform(projectDir string, config Configuration) {
fmt.Println("Deploying using Terraform...")

// Check if Terraform files exist
tfDir := filepath.Join(projectDir, "deployments", "terraform", config.Environment)
if _, err := os.Stat(tfDir); os.IsNotExist(err) {
log.Fatalf("Terraform directory not found at %s", tfDir)
}

// Check if .tfvars file exists
tfvarsPath := filepath.Join(tfDir, "terraform.tfvars")
if _, err := os.Stat(tfvarsPath); os.IsNotExist(err) {
// Create .tfvars file from example
tfvarsExamplePath := filepath.Join(tfDir, "terraform.tfvars.example")
if _, err := os.Stat(tfvarsExamplePath); os.IsNotExist(err) {
	log.Fatalf("terraform.tfvars.example not found at %s", tfvarsExamplePath)
}

// Read example file
tfvarsExample, err := ioutil.ReadFile(tfvarsExamplePath)
if err != nil {
	log.Fatalf("Error reading terraform.tfvars.example: %v", err)
}

// Get DB password
dbPasswordPrompt := promptui.Prompt{
	Label: "Enter database password",
	Mask:  '*',
}
dbPassword, err := dbPasswordPrompt.Run()
if err != nil {
	log.Fatalf("Prompt failed: %v", err)
}

// Replace placeholder with actual password
tfvarsContent := strings.Replace(string(tfvarsExample), "db_password = \"changeme\"", fmt.Sprintf("db_password = \"%s\"", dbPassword), 1)

// Write .tfvars file
if err := ioutil.WriteFile(tfvarsPath, []byte(tfvarsContent), 0644); err != nil {
	log.Fatalf("Error creating terraform.tfvars: %v", err)
}
}

// Run Terraform init
fmt.Println("Initializing Terraform...")
terraformInit := exec.Command("terraform", "init")
terraformInit.Dir = tfDir
terraformInit.Stdout = os.Stdout
terraformInit.Stderr = os.Stderr
if err := terraformInit.Run(); err != nil {
log.Fatalf("Error initializing Terraform: %v", err)
}

// Run Terraform plan
fmt.Println("Planning Terraform deployment...")
terraformPlan := exec.Command("terraform", "plan", "-out=tfplan")
terraformPlan.Dir = tfDir
terraformPlan.Stdout = os.Stdout
terraformPlan.Stderr = os.Stderr
if err := terraformPlan.Run(); err != nil {
log.Fatalf("Error planning Terraform deployment: %v", err)
}

// Ask for confirmation
confirmPrompt := promptui.Select{
Label: "Do you want to apply the Terraform plan?",
Items: []string{"Yes", "No"},
}
_, confirmResult, err := confirmPrompt.Run()
if err != nil {
log.Fatalf("Prompt failed: %v", err)
}

if confirmResult == "No" {
fmt.Println("Terraform apply canceled.")
return
}

// Run Terraform apply
fmt.Println("Applying Terraform plan...")
terraformApply := exec.Command("terraform", "apply", "tfplan")
terraformApply.Dir = tfDir
terraformApply.Stdout = os.Stdout
terraformApply.Stderr = os.Stderr
if err := terraformApply.Run(); err != nil {
log.Fatalf("Error applying Terraform plan: %v", err)
}

fmt.Println(color.GreenString("✓ Terraform deployment successful!"))
}

func generateMiddleware(projectDir string) {
fmt.Println("Generating Middleware template...")

middlewareDir := filepath.Join(projectDir, "internal", "api", "middleware")
if err := os.MkdirAll(middlewareDir, 0755); err != nil {
log.Fatalf("Error creating middleware directory: %v", err)
}

middlewarePath := filepath.Join(middlewareDir, "middleware.go")
if _, err := os.Stat(middlewarePath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! Middleware already exists"))
return
}

middlewareContent := `package middleware

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
`

if err := ioutil.WriteFile(middlewarePath, []byte(middlewareContent), 0644); err != nil {
log.Fatalf("Error creating middleware file: %v", err)
}
}

func generateAWSIntegration(projectDir string) {
fmt.Println("Generating AWS Integration template...")

awsDir := filepath.Join(projectDir, "internal", "aws")
if err := os.MkdirAll(awsDir, 0755); err != nil {
log.Fatalf("Error creating AWS directory: %v", err)
}

awsPath := filepath.Join(awsDir, "aws.go")
if _, err := os.Stat(awsPath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! AWS Integration already exists"))
return
}

awsContent := `package aws

import (
"bytes"
"context"
"fmt"
"io"
"time"

"github.com/aws/aws-sdk-go/aws"
"github.com/aws/aws-sdk-go/aws/session"
"github.com/aws/aws-sdk-go/service/s3"
"github.com/aws/aws-sdk-go/service/cognito/cognitoidentityprovider"
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
`

if err := ioutil.WriteFile(awsPath, []byte(awsContent), 0644); err != nil {
log.Fatalf("Error creating AWS integration file: %v", err)
}
}

func generateAuthentication(projectDir string) {
fmt.Println("Generating Authentication template...")

authDir := filepath.Join(projectDir, "internal", "auth")
if err := os.MkdirAll(authDir, 0755); err != nil {
log.Fatalf("Error creating auth directory: %v", err)
}

authPath := filepath.Join(authDir, "auth.go")
if _, err := os.Stat(authPath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! Authentication already exists"))
return
}

authContent := `package auth

import (
"errors"
"time"

"github.com/golang-jwt/jwt"
)

// Claims represents the JWT claims
type Claims struct {
UserID   string ` + "`json:\"sub\"`" + `
Username string ` + "`json:\"username\"`" + `
Email    string ` + "`json:\"email\"`" + `
Role     string ` + "`json:\"role\"`" + `
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
`

if err := ioutil.WriteFile(authPath, []byte(authContent), 0644); err != nil {
log.Fatalf("Error creating authentication file: %v", err)
}
}

func generateModel(projectDir string) {
fmt.Println("Generating Model template...")

modelsDir := filepath.Join(projectDir, "internal", "models")
if err := os.MkdirAll(modelsDir, 0755); err != nil {
log.Fatalf("Error creating models directory: %v", err)
}

modelPath := filepath.Join(modelsDir, "models.go")
if _, err := os.Stat(modelPath); !os.IsNotExist(err) {
fmt.Println(color.YellowString("! Model already exists"))
return
}

modelContent := `package models

import (
"time"
)

// User represents a user in the system
type User struct {
ID           string     ` + "`json:\"id\"`" + `
Username     string     ` + "`json:\"username\"`" + `
Email        string     ` + "`json:\"email\"`" + `
PhoneNumber  string     ` + "`json:\"phone_number,omitempty\"`" + `
FirstName    string     ` + "`json:\"first_name\"`" + `
LastName     string     ` + "`json:\"last_name\"`" + `
DateOfBirth  time.Time  ` + "`json:\"date_of_birth\"`" + `
Address      Address    ` + "`json:\"address,omitempty\"`" + `
RiskProfile  string     ` + "`json:\"risk_profile,omitempty\"`" + `
CreatedAt    time.Time  ` + "`json:\"created_at\"`" + `
UpdatedAt    time.Time  ` + "`json:\"updated_at\"`" + `
KYCStatus    string     ` + "`json:\"kyc_status\"`" + `
KYCVerifiedAt *time.Time ` + "`json:\"kyc_verified_at,omitempty\"`" + `
IsActive     bool       ` + "`json:\"is_active\"`" + `
}

// Address represents a physical address
type Address struct {
Street  string ` + "`json:\"street\"`" + `
City    string ` + "`json:\"city\"`" + `
State   string ` + "`json:\"state\"`" + `
ZipCode string ` + "`json:\"zip_code\"`" + `
Country string ` + "`json:\"country\"`" + `
}

// Account represents a financial account
type Account struct {
ID                string      ` + "`json:\"id\"`" + `
UserID            string      ` + "`json:\"user_id\"`" + `
Type              string      ` + "`json:\"type\"`" + `
Name              string      ` + "`json:\"name\"`" + `
Description       string      ` + "`json:\"description,omitempty\"`" + `
InstitutionID     string      ` + "`json:\"institution_id,omitempty\"`" + `
InstitutionName   string      ` + "`json:\"institution_name,omitempty\"`" + `
ExternalAccountID string      ` + "`json:\"external_account_id,omitempty\"`" + `
Balance           Money       ` + "`json:\"balance\"`" + `
IsActive          bool        ` + "`json:\"is_active\"`" + `
CreatedAt         time.Time   ` + "`json:\"created_at\"`" + `
UpdatedAt         time.Time   ` + "`json:\"updated_at\"`" + `
TrustID           *string     ` + "`json:\"trust_id,omitempty\"`" + `
Beneficiaries     []Beneficiary ` + "`json:\"beneficiaries,omitempty\"`" + `
TaxStatus         string      ` + "`json:\"tax_status,omitempty\"`" + `
}

// Money represents a monetary amount with currency
type Money struct {
Amount   float64 ` + "`json:\"amount\"`" + `
Currency string  ` + "`json:\"currency\"`" + `
}

// Beneficiary represents a beneficiary on an account
type Beneficiary struct {
ID           string    ` + "`json:\"id\"`" + `
Name         string    ` + "`json:\"name\"`" + `
Relationship string    ` + "`json:\"relationship,omitempty\"`" + `
Percentage   int       ` + "`json:\"percentage\"`" + `
DateOfBirth  time.Time ` + "`json:\"date_of_birth,omitempty\"`" + `
}

// Trust represents a legal trust
type Trust struct {
ID                string       ` + "`json:\"id\"`" + `
Name              string       ` + "`json:\"name\"`" + `
Type              string       ` + "`json:\"type\"`" + `
Status            string       ` + "`json:\"status\"`" + `
CreatorUserID     string       ` + "`json:\"creator_user_id\"`" + `
Trustees          []Trustee    ` + "`json:\"trustees\"`" + `
Beneficiaries     []Beneficiary ` + "`json:\"beneficiaries\"`" + `
DisbursementRules []DisbursementRule ` + "`json:\"disbursement_rules\"`" + `
DocumentID        string       ` + "`json:\"document_id\"`" + `
CreatedAt         time.Time    ` + "`json:\"created_at\"`" + `
UpdatedAt         time.Time    ` + "`json:\"updated_at\"`" + `
ActivatedAt       *time.Time   ` + "`json:\"activated_at,omitempty\"`" + `
LinkedAccounts    []string     ` + "`json:\"linked_accounts\"`" + `
}
`

if err := ioutil.WriteFile(modelPath, []byte(modelContent), 0644); err != nil {
log.Fatalf("Error creating model file: %v", err)
}
}