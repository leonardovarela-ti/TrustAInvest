-- Create schemas
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS accounts;
CREATE SCHEMA IF NOT EXISTS trusts;
CREATE SCHEMA IF NOT EXISTS investments;
CREATE SCHEMA IF NOT EXISTS documents;
CREATE SCHEMA IF NOT EXISTS notifications;
CREATE SCHEMA IF NOT EXISTS kyc;

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

CREATE INDEX idx_users_username ON users.users(username);
CREATE INDEX idx_users_email ON users.users(email);
CREATE INDEX idx_users_kyc_status ON users.users(kyc_status);

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

CREATE SCHEMA IF NOT EXISTS notifications;

CREATE TABLE IF NOT EXISTS notifications.notifications (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users.users(id),
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_notifications_user_id ON notifications.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications.notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications.notifications(created_at);

CREATE TABLE IF NOT EXISTS notifications.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users.users(id),
    email_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    marketing_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE SCHEMA IF NOT EXISTS kyc;

CREATE TABLE IF NOT EXISTS kyc.verification_requests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users.users(id),
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    request_data JSONB NOT NULL,
    response_data JSONB,
    provider VARCHAR(50) NOT NULL,
    provider_request_id VARCHAR(255),
    provider_response_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    rejection_reason VARCHAR(255),
    document_ids TEXT[] DEFAULT ARRAY[]::TEXT[],
    verification_method VARCHAR(255)
);

CREATE INDEX idx_kyc_verification_user_id ON kyc.verification_requests(user_id);
CREATE INDEX idx_kyc_verification_status ON kyc.verification_requests(status);
CREATE INDEX idx_kyc_verification_created_at ON kyc.verification_requests(created_at);

CREATE TABLE IF NOT EXISTS kyc.documents (
    id UUID PRIMARY KEY,
    verification_request_id UUID NOT NULL REFERENCES kyc.verification_requests(id),
    type VARCHAR(50) NOT NULL,
    file_key VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_kyc_documents_verification_id ON kyc.documents(verification_request_id);

-- Create example user for development
INSERT INTO users.users (
    username, email, first_name, last_name, date_of_birth, 
    street, city, state, zip_code, country, risk_profile
) VALUES (
    'demo_user', 'demo@trustainvest.com', 'Demo', 'User', '1980-01-01',
    '123 Main St', 'New York', 'NY', '10001', 'USA', 'MODERATE'
) ON CONFLICT (username) DO NOTHING;
