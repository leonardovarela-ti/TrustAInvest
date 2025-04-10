# TrustAInvest Customer App

A Flutter application for TrustAInvest customers to register and manage their accounts.

## Features

- User registration with multi-step form
- Connection to user registration backend
- Secure storage of user credentials
- Form validation
- Responsive UI design

## Getting Started

### Prerequisites

- Flutter SDK (version 3.0.0 or higher)
- Dart SDK (version 3.0.0 or higher)
- An IDE (VS Code, Android Studio, etc.)
- Docker and Docker Compose (for containerized deployment)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/TrustAInvest.com.git
cd TrustAInvest.com/customer-app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Create a `.env` file in the root directory with the following content:
```
API_BASE_URL=http://localhost:8080
```
Replace the URL with your actual backend API URL.

### Running the App

#### Local Development

```bash
flutter run
```

#### Docker Deployment

The app is containerized and can be run as part of the TrustAInvest microservices architecture using Docker Compose:

```bash
# From the root directory of the project
docker-compose up -d customer-app
```

This will build and run the customer app container, exposing it on port 3001. You can access the app at http://localhost:3001.

## Project Structure

- `lib/main.dart` - Entry point of the application
- `lib/models/` - Data models
- `lib/screens/` - UI screens
- `lib/services/` - API and authentication services
- `lib/utils/` - Utility functions and theme
- `lib/widgets/` - Reusable UI components

## Backend Connection

The app connects to the TrustAInvest user registration backend API. The API endpoints used are:

- `POST /api/v1/register` - Register a new user
- `GET /api/v1/check-username` - Check if a username is available
- `GET /api/v1/check-email` - Check if an email is available
- `GET /api/v1/users/{userId}` - Get user profile
- `GET /api/v1/users/{userId}/kyc-status` - Get KYC status

## Docker Configuration

The app is containerized using a multi-stage Docker build:

1. The first stage uses an Ubuntu image with Flutter installed to build the web version of the app
2. The second stage uses Nginx to serve the built web app

The Docker setup includes:
- `Dockerfile` - Multi-stage build configuration
- `nginx.conf` - Nginx configuration for serving the web app
- Docker Compose integration in the main project's `docker-compose.yml`

## Security

- User credentials are stored securely using `flutter_secure_storage`
- Sensitive data like SSN is masked in the UI
- Passwords are never stored locally

## License

This project is licensed under the MIT License - see the LICENSE file for details.
