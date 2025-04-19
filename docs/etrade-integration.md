# E-Trade Integration

This document provides information on how to set up and use the E-Trade integration feature in TrustAInvest.

## Overview

The E-Trade integration allows customers to link their existing E-Trade accounts to TrustAInvest. This integration uses the E-Trade API to fetch account information, balances, and positions.

## Architecture

The integration follows a microservices architecture:

1. **E-Trade Service**: A dedicated microservice that handles communication with the E-Trade API
2. **Account Service**: Proxies requests to the E-Trade service and provides a unified API for the frontend

## Setup

### Prerequisites

- E-Trade developer account (register at https://developer.etrade.com)
- E-Trade API keys (Consumer Key and Consumer Secret)
- E-Trade account (for testing)

### Configuration

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update the `.env` file with your E-Trade API keys:
   ```
   ETRADE_SANDBOX_CONSUMER_KEY=your_sandbox_key
   ETRADE_SANDBOX_CONSUMER_SECRET=your_sandbox_secret
   ETRADE_PROD_CONSUMER_KEY=your_production_key
   ETRADE_PROD_CONSUMER_SECRET=your_production_secret
   ```

3. Set the environment to use (sandbox or production):
   ```
   # For sandbox (testing)
   ETRADE_SANDBOX=true
   ETRADE_CONSUMER_KEY=${ETRADE_SANDBOX_CONSUMER_KEY}
   ETRADE_CONSUMER_SECRET=${ETRADE_SANDBOX_CONSUMER_SECRET}

   # For production
   # ETRADE_SANDBOX=false
   # ETRADE_CONSUMER_KEY=${ETRADE_PROD_CONSUMER_KEY}
   # ETRADE_CONSUMER_SECRET=${ETRADE_PROD_CONSUMER_SECRET}
   ```

4. Update the callback URL if needed:
   ```
   ETRADE_CALLBACK_URL=http://localhost:3002/etrade/callback
   ```

### Starting the Services

Start the services using Docker Compose:

```bash
docker-compose up -d
```

## API Endpoints

The E-Trade integration provides the following API endpoints:

### Initiate OAuth Flow

```
# Through account-service
POST http://localhost:8081/api/v1/etrade/auth/initiate

# Direct to etrade-service
POST http://localhost:8087/api/v1/etrade/auth/initiate
```

Request:
```json
{
  "user_id": "user-uuid",
  "consumer_key": "your-consumer-key",
  "callback_url": "http://localhost:3002/etrade/callback"
}
```

Response:
```json
{
  "request_token": "request-token",
  "auth_url": "https://us.etrade.com/e/t/etws/authorize?key=your-consumer-key&token=request-token"
}
```

### Complete OAuth Flow

```
# Through account-service
POST http://localhost:8081/api/v1/etrade/auth/callback

# Direct to etrade-service
POST http://localhost:8087/api/v1/etrade/auth/callback
```

Request:
```json
{
  "request_token": "request-token",
  "verifier": "verification-code",
  "user_id": "user-uuid"
}
```

Response:
```json
{
  "success": true,
  "access_token": "access-token"
}
```

### Get E-Trade Accounts

```
# Through account-service
GET http://localhost:8081/api/v1/etrade/accounts?user_id=user-uuid

# Direct to etrade-service
GET http://localhost:8087/api/v1/etrade/accounts?user_id=user-uuid
```

Response:
```json
{
  "accounts": [
    {
      "account_id": "account-id",
      "account_name": "Account Name",
      "account_type": "MARGIN",
      "institution_id": "etrade",
      "institution_name": "E-Trade",
      "balance": 10000.00,
      "currency": "USD",
      "last_updated": "2025-04-19T00:00:00Z",
      "status": "active",
      "account_positions": [
        {
          "symbol": "AAPL",
          "quantity": 10,
          "cost_basis": 1500.00,
          "market_value": 1800.00,
          "gain_loss": 300.00,
          "gain_loss_perc": 20.00,
          "last_price": 180.00,
          "last_price_time": "2025-04-19T00:00:00Z"
        }
      ]
    }
  ]
}
```

### Link E-Trade Account

```
# Through account-service
POST http://localhost:8081/api/v1/etrade/accounts/link

# Direct to etrade-service
POST http://localhost:8087/api/v1/etrade/accounts/link
```

Request:
```json
{
  "user_id": "user-uuid",
  "account_id": "etrade-account-id",
  "account_name": "My E-Trade Account"
}
```

Response:
```json
{
  "success": true,
  "message": "Account linked successfully",
  "account_id": "etrade-account-id",
  "internal_id": "internal-account-uuid"
}
```

## Testing

### Sandbox Testing

1. Set `ETRADE_SANDBOX=true` in the `.env` file
2. Use the sandbox API keys
3. Follow the OAuth flow to link a sandbox account
4. Test the API endpoints

### Production Testing

1. Set `ETRADE_SANDBOX=false` in the `.env` file
2. Use the production API keys
3. Follow the OAuth flow to link a real E-Trade account
4. Test the API endpoints

## Troubleshooting

### Common Issues

1. **OAuth Flow Fails**: Ensure the callback URL is correctly registered in your E-Trade developer account
2. **API Requests Fail**: Check the E-Trade service logs for error messages
3. **Rate Limiting**: E-Trade has rate limits on API requests, ensure you're not exceeding them

### Logs

Check the logs for the E-Trade service:

```bash
docker-compose logs -f etrade-service
```

## Security Considerations

1. **API Keys**: Never commit API keys to version control
2. **OAuth Tokens**: Tokens are stored securely in the database
3. **HTTPS**: Use HTTPS in production for all API requests
4. **User Authorization**: Ensure users can only access their own accounts

## Future Enhancements

1. **Additional Brokerages**: Add support for other brokerages like Robinhood, Fidelity, etc.
2. **Real-time Updates**: Implement webhooks or polling for real-time account updates
3. **Transaction History**: Add support for retrieving transaction history
4. **Trading**: Add support for executing trades
