import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({http.Client? client})
      : _client = client ?? http.Client(),
        baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';

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
        return RegistrationResponse.fromJson(jsonDecode(response.body));
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
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
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
