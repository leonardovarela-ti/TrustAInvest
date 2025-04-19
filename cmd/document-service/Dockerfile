# Builder stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the service
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/document-service ./cmd/document-service

# Final stage
FROM alpine:3.16

WORKDIR /app

# Install necessary packages
RUN apk --no-cache add ca-certificates tzdata

# Copy the binary from builder
COPY --from=builder /bin/document-service /app/document-service

# Expose the service port
EXPOSE 8080

# Run the service
ENTRYPOINT ["/app/document-service"]
