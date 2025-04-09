#!/bin/bash

# Execute the SQL script to initialize the admin user
cat scripts/init-admin-user.sql | docker exec -i kyc-verifier-postgres psql -U postgres -d trustainvest

echo "Admin user initialized successfully."
