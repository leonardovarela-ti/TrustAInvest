CREATE OR REPLACE FUNCTION update_user_kyc_status()
RETURNS trigger AS $$
BEGIN
    IF NEW.status = 'VERIFIED' AND OLD.status != 'VERIFIED' THEN
        -- Update the user's KYC status to verified
        UPDATE users.users SET kyc_status = 'VERIFIED', updated_at = NOW()
        WHERE id = NEW.user_id;
        
        -- Set the verified_at timestamp
        NEW.verified_at = NOW();
    ELSIF NEW.status = 'REJECTED' AND OLD.status != 'REJECTED' THEN
        -- Update the user's KYC status to rejected
        UPDATE users.users SET kyc_status = 'REJECTED', updated_at = NOW()
        WHERE id = NEW.user_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
