# Builder stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy go.mod and go.sum
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the service
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/notification-service ./cmd/notification-service

# Final stage
FROM alpine:3.16

WORKDIR /app

# Install necessary packages
RUN apk --no-cache add ca-certificates tzdata

# Copy the binary from builder
COPY --from=builder /bin/notification-service /app/notification-service

# Expose the service port
EXPOSE 8080

# Run the service
ENTRYPOINT ["/app/notification-service"]
