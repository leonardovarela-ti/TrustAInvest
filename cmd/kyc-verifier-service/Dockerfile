FROM golang:1.22-alpine AS builder

# Install git for dependency management
RUN apk add --no-cache git

WORKDIR /app

# Copy go.mod and go.sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Update go.mod and build the application
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -o /kyc-verifier-service ./cmd/kyc-verifier-service

# Use a minimal alpine image for the final stage
FROM alpine:3.16

WORKDIR /

# Copy the binary from the builder stage
COPY --from=builder /kyc-verifier-service /kyc-verifier-service

# Expose the port the service runs on
EXPOSE 8080

# Run the service
CMD ["/kyc-verifier-service"]
