# KYC Verifier UI

A Flutter application for KYC (Know Your Customer) verification management at TrustAInvest.com.

## Overview

This application provides a user interface for KYC verifiers to review and process verification requests from customers. It allows verifiers to:

- View pending verification requests
- Review customer documents and information
- Approve or reject verification requests
- Manage verifier accounts (admin only)

## Features

- **Authentication**: Secure login for verifiers
- **Dashboard**: Overview of verification statistics
- **Verification List**: List of all verification requests with filtering options
- **Verification Details**: Detailed view of customer information and documents
- **Profile Management**: User profile viewing and editing
- **Verifier Management**: Admin interface for managing verifier accounts

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Docker and Docker Compose (for containerized deployment)
- PostgreSQL (for local development without Docker)

### Installation

#### Option 1: Local Development

1. Clone the repository:
   ```
   git clone https://github.com/TrustAInvest/kyc-verifier-ui.git
   cd kyc-verifier-ui
   ```

2. Install dependencies:
   ```
   flutter pub get
   ```

3. Configure environment:
   - Create a `.env` file in the project root (or copy from `.env.example`)
   - Set the `API_URL` to point to your backend API (default: `http://localhost:8090/api`)

4. Run code generation for JSON serialization:
   ```
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. Run the application:
   ```
   flutter run -d chrome --web-port=3000
   ```

#### Option 2: Docker Deployment

1. Make sure Docker and Docker Compose are installed on your system.

2. Navigate to the project root directory (TrustAInvest.com).

3. Build and run the services:
   ```
   docker-compose -f docker-compose.kyc-verifier.yml up -d
   ```

4. Access the application at http://localhost:3000

5. Log in with the default admin credentials:
   - Username: `admin`
   - Password: `admin123`

### Placeholder Web UI

During development or when the Flutter web app is not built, a placeholder HTML page is served at http://localhost:3000. This page includes:

- A simple login form with the default admin credentials
- Information about the KYC Verifier system
- Visual styling that matches the application theme

To replace the placeholder with the actual Flutter web app:

```bash
flutter build web
cp -r build/web/* web/
```

## Project Structure

```
lib/
├── main.dart                  # Application entry point
├── models/                    # Data models
│   ├── document.dart          # Document model
│   ├── verification_request.dart # Verification request model
│   └── verifier.dart          # Verifier user model
├── screens/                   # UI screens
│   ├── dashboard_screen.dart  # Dashboard screen
│   ├── login_screen.dart      # Login screen
│   ├── profile_screen.dart    # Profile screen
│   ├── verification_detail_screen.dart # Verification details
│   ├── verification_list_screen.dart   # List of verifications
│   └── verifier_management_screen.dart # Admin verifier management
├── services/                  # Business logic and API services
│   ├── api_service.dart       # API communication
│   └── auth_service.dart      # Authentication service
└── utils/                     # Utilities
    ├── theme.dart             # App theme configuration
    └── validators.dart        # Form validation helpers
```

## Authentication

The application uses JWT (JSON Web Token) authentication. The default admin credentials are:

- Username: `admin`
- Password: `admin123`

For security reasons, change these credentials in a production environment.

## API Integration

The application communicates with a backend API for all data operations. The API URL is configured in the `.env` file.

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
