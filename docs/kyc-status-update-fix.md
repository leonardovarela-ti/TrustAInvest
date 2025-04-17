# KYC Status Update Fix

## Issue

The KYC verification system was experiencing an issue where the user's KYC status in the `users.users` table was not being updated to "VERIFIED" after a successful KYC verification through the API. The logs showed:

```
KYC verification successful through API!
Checking if status was updated in the database...
Status was not updated in the database. Current status: PENDING
User KYC status in database: PENDING
```

The API was returning a success message, but the database status remained as "PENDING" instead of being updated to "VERIFIED".

## Root Cause

After investigation, two potential issues were identified:

1. **Database Trigger Issue**: The trigger function `update_user_kyc_status()` that should update the user's KYC status when a verification request status changes was not working correctly.

2. **Transaction Handling Issue**: The transaction in the `UpdateVerificationRequestStatus` function was being committed, but there was no verification that the changes were persisted properly after the commit.

## Solution

The solution addresses both potential issues:

### 1. Database Trigger Fix

The `fix_init_db.sql` script updates the trigger function and recreates the trigger to ensure it correctly updates the user's KYC status when a verification request status changes:

```sql
-- Create a new function with the correct syntax
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

-- Drop the existing trigger
DROP TRIGGER IF EXISTS update_user_kyc_status_trigger ON kyc.verification_requests;

-- Create the trigger again
CREATE TRIGGER update_user_kyc_status_trigger
BEFORE UPDATE ON kyc.verification_requests
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION update_user_kyc_status();
```

### 2. Code Fix

The `UpdateVerificationRequestStatus` function in `internal/db/kyc_verifier_repository.go` has been enhanced to:

- Add more detailed logging to track the transaction flow
- Verify the update was successful within the transaction
- Add a post-commit verification step to confirm the update was persisted
- Implement a fallback mechanism to directly update the user's KYC status if the transaction-based update fails

The key addition is a post-commit verification and fallback mechanism:

```go
// Double-check that the user's KYC status was updated correctly after the transaction
var finalUserKYCStatusAfterCommit string
err = r.DB.QueryRow("SELECT kyc_status FROM users.users WHERE id = $1", userID).Scan(&finalUserKYCStatusAfterCommit)
if err != nil {
    _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error checking final user KYC status after commit: " + err.Error() + "')")
    return fmt.Errorf("failed to verify user KYC status update after commit: %w", err)
}

// Log the final user KYC status after commit
_, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Final user KYC status after commit: " + finalUserKYCStatusAfterCommit + "')")

// If the status is still not updated, try a direct update outside the transaction
if finalUserKYCStatusAfterCommit != status {
    _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'WARNING: User KYC status still not updated after commit. Attempting direct update.')")
    
    // Direct update as a last resort
    _, err = r.DB.Exec("UPDATE users.users SET kyc_status = $1, updated_at = $2 WHERE id = $3", status, time.Now(), userID)
    if err != nil {
        _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error in direct update of user KYC status: " + err.Error() + "')")
        return fmt.Errorf("failed in direct update of user KYC status: %w", err)
    }
    
    // Verify the direct update
    err = r.DB.QueryRow("SELECT kyc_status FROM users.users WHERE id = $1", userID).Scan(&finalUserKYCStatusAfterCommit)
    if err != nil {
        _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'Error checking user KYC status after direct update: " + err.Error() + "')")
        return fmt.Errorf("failed to verify user KYC status after direct update: %w", err)
    }
    
    _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'User KYC status after direct update: " + finalUserKYCStatusAfterCommit + "')")
    
    if finalUserKYCStatusAfterCommit != status {
        _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'CRITICAL ERROR: User KYC status could not be updated even with direct update!')")
        return fmt.Errorf("critical error: user KYC status could not be updated even with direct update")
    }
    
    _, _ = r.DB.Exec("SELECT pg_notify('kyc_log', 'User KYC status successfully updated with direct update')")
}
```

## Applying the Fix

A script has been created to apply both fixes:

```bash
# Make the script executable
chmod +x scripts/fix-kyc-status-update.sh

# Run the script
./scripts/fix-kyc-status-update.sh
```

The script will:
1. Apply the database fix by executing the SQL in `fix_init_db.sql`
2. Rebuild the KYC verifier service to apply the code changes

## Verifying the Fix

To verify that the fix works correctly, you can use the provided script that applies the fix to the test environment and runs the integration tests:

```bash
# Make the script executable
chmod +x scripts/fix-and-test-kyc-status.sh

# Run the script
./scripts/fix-and-test-kyc-status.sh
```

This script will:
1. Start the test environment
2. Apply the database fix to the test environment
3. Rebuild the KYC verifier service with our code changes
4. Update the test Docker Compose configuration to use our custom image
5. Run the integration tests
6. Restore the original Docker Compose configuration

Alternatively, you can apply the fix to your development environment and then run the integration tests separately:

```bash
# Apply the fix
./scripts/fix-kyc-status-update.sh

# Run the integration tests
cd test
./integration_test.sh
```

The tests should now pass, showing that the user's KYC status is correctly updated to "VERIFIED" after a successful KYC verification.

## Logging and Monitoring

The enhanced logging in the `UpdateVerificationRequestStatus` function will help monitor the KYC verification process and identify any issues that may occur. The logs include:

- Transaction start and commit
- Request ID and status
- User ID associated with the request
- Current status before update
- Current user KYC status before update
- Number of rows affected by the verification request update
- Number of rows affected by the user update
- Final user KYC status after update
- Final user KYC status after commit
- Any errors that occur during the process

These logs can be used to monitor the KYC verification process and identify any issues that may occur in the future.
