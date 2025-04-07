-- migrations/000003_create_kyc_tables.up.sql
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
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE
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
