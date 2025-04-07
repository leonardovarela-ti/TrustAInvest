-- migrations/000003_create_kyc_tables.down.sql
DROP TABLE IF EXISTS kyc.documents;
DROP TABLE IF EXISTS kyc.verification_requests;
DROP SCHEMA IF EXISTS kyc;