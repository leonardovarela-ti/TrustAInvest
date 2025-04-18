import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'config_service.dart';

class ApiService {
  late String baseUrl;
  final http.Client _client;
  final ConfigService _configService;

  ApiService({http.Client? client})
      : _client = client ?? http.Client(),
        _configService = ConfigService() {
    baseUrl = _configService.getApiBaseUrl();
  }

  // Register a new user
  Future<RegistrationResponse> registerUser(
      User user, String password) async {
    try {
      final registrationData = user.toRegistrationJson();
      // Add password to the registration data
      registrationData['password'] = password;

      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(registrationData),
      );

      if (response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          print('Registration response: $responseData');
          return RegistrationResponse.fromJson(responseData);
        } catch (parseError) {
          print('Error parsing registration response: $parseError');
          print('Response body: ${response.body}');
          throw ApiException(
            statusCode: 500,
            message: 'Error parsing server response: $parseError',
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: errorData['error'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      print('Registration error: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Check if a username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/check-username?username=$username'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Check if an email is available
  Future<bool> isEmailAvailable(String email) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/check-email?email=$email'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Get user profile
  Future<User> getUserProfile(String userId, String token) async {
    try {
      print('Getting user profile for ID: $userId');
      
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get user profile response status code: ${response.statusCode}');
      print('Get user profile response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('Get user profile response parsed: $responseData');
          
          // Ensure KYC status is set correctly
          if (responseData['kyc_status'] == null) {
            print('KYC status is null, fetching KYC status separately...');
            final kycStatus = await getKycStatus(userId, token);
            responseData['kyc_status'] = kycStatus;
          }
          
          return User.fromJson(responseData);
        } catch (parseError) {
          print('Error parsing get user profile response: $parseError');
          print('Response body: ${response.body}');
          throw ApiException(
            statusCode: 500,
            message: 'Error parsing server response: $parseError',
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: errorData['error'] ?? 'Failed to get user profile',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      print('Get user profile error: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get KYC status
  Future<String> getKycStatus(String userId, String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/users/$userId/kyc-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] ?? 'UNKNOWN';
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: errorData['error'] ?? 'Failed to get KYC status',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Login user
  Future<LoginResponse> login(String username, String password) async {
    try {
      print('Sending login request to: $baseUrl/api/v1/auth/login');
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('Login response status code: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('Login response parsed: $responseData');
          
          // Check for null values in the response
          print('Token: ${responseData['token']}');
          print('Expires in: ${responseData['expires_in']}');
          print('User ID: ${responseData['user_id']}');
          print('Username: ${responseData['username']}');
          print('Email: ${responseData['email']}');
          
          return LoginResponse.fromJson(responseData);
        } catch (parseError) {
          print('Error parsing login response: $parseError');
          print('Response body: ${response.body}');
          throw ApiException(
            statusCode: 500,
            message: 'Error parsing server response: $parseError',
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: errorData['error'] ?? 'Login failed',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      print('Login error: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get current user profile
  Future<User> getCurrentUser(String token) async {
    try {
      print('Getting current user with token: ${token.substring(0, 10)}...');
      
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get current user response status code: ${response.statusCode}');
      print('Get current user response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('Get current user response parsed: $responseData');
          print('Phone number from response: ${responseData['phone_number']}');
          print('Risk profile from response: ${responseData['risk_profile']}');
          
          // Create a complete user object with default values for missing fields
          final userData = {
            'id': responseData['id'],
            'username': responseData['username'],
            'email': responseData['email'],
            'phone_number': responseData['phone_number'],
            'first_name': responseData['first_name'] ?? '',
            'last_name': responseData['last_name'] ?? '',
            'date_of_birth': responseData['date_of_birth'] ?? '1990-01-01',
            'address': responseData['address'] ?? {
              'street': '',
              'city': '',
              'state': '',
              'zip_code': '',
              'country': '',
            },
            'ssn': responseData['ssn'] ?? '',
            'risk_profile': responseData['risk_profile'],
            'kyc_status': responseData['kyc_status'] ?? 'VERIFIED',
            'kyc_verified_at': responseData['kyc_verified_at'],
            'is_active': responseData['is_active'] ?? true,
            'created_at': responseData['created_at'],
            'updated_at': responseData['updated_at'],
          };
          
          print('Complete user data: $userData');
          print('Phone number in userData: ${userData['phone_number']}');
          print('Risk profile in userData: ${userData['risk_profile']}');
          
          final user = User.fromJson(userData);
          print('User object created:');
          print('Phone number in User object: ${user.phoneNumber}');
          print('Risk profile in User object: ${user.riskProfile}');
          
          return user;
        } catch (parseError) {
          print('Error parsing get current user response: $parseError');
          print('Response body: ${response.body}');
          throw ApiException(
            statusCode: 500,
            message: 'Error parsing server response: $parseError',
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: errorData['error'] ?? 'Failed to get current user profile',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      print('Get current user error: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  // Get user address
  Future<Address> getUserAddress(String userId, String token) async {
    try {
      print('Getting user address for ID: $userId');
      
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/users/$userId/address'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Get user address response status code: ${response.statusCode}');
      print('Get user address response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          print('Get user address response parsed: $responseData');
          return Address.fromJson(responseData);
        } catch (parseError) {
          print('Error parsing get user address response: $parseError');
          print('Response body: ${response.body}');
          throw ApiException(
            statusCode: 500,
            message: 'Error parsing server response: $parseError',
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw ApiException(
          statusCode: response.statusCode,
          message: errorData['error'] ?? 'Failed to get user address',
        );
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      print('Get user address error: $e');
      throw ApiException(
        statusCode: 500,
        message: 'Network error: ${e.toString()}',
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() {
    return 'ApiException: $statusCode - $message';
  }
}
