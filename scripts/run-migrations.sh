#!/bin/bash
set -e

echo "Running database migrations..."
cd /app/migrations
migrate -path . -database "postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}?sslmode=disable" up
echo "Migrations completed successfully!"