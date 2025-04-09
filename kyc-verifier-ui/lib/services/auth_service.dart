import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/verifier.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final String _baseUrl;
  
  Verifier? _currentUser;
  bool _isInitialized = false;
  
  AuthService() {
    _baseUrl = dotenv.get('API_URL', fallback: 'http://localhost:8080/api');
    _initializeUser();
  }
  
  Verifier? get currentUser => _currentUser;
  
  Future<void> _initializeUser() async {
    final token = await getToken();
    if (token != null) {
      try {
        // Decode JWT token to get user info
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        
        // Check if token is expired
        if (JwtDecoder.isExpired(token)) {
          await logout();
          return;
        }
        
        // Create user from token data
        _currentUser = Verifier(
          id: decodedToken['sub'] ?? '',
          username: decodedToken['username'] ?? '',
          email: decodedToken['email'] ?? '',
          firstName: decodedToken['firstName'] ?? '',
          lastName: decodedToken['lastName'] ?? '',
          role: decodedToken['role'] ?? 'VERIFIER',
          isActive: true,
          createdAt: DateTime.now(), // This would normally come from the token
        );
        
        _isInitialized = true;
        notifyListeners();
      } catch (e) {
        // If there's an error parsing the token, log the user out
        debugPrint('Error initializing user: $e');
        await logout();
      }
    } else {
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  Future<bool> isLoggedIn() async {
    // Wait for initialization to complete
    while (!_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return _currentUser != null;
  }
  
  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['token'];
      
      // Save token to secure storage
      await _storage.write(key: 'auth_token', value: token);
      
      // Initialize user from token
      await _initializeUser();
      notifyListeners();
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to login');
    }
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _currentUser = null;
    notifyListeners();
  }
  
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'auth_token');
    } catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }
  
  Future<void> refreshToken() async {
    try {
      final currentToken = await getToken();
      if (currentToken == null) {
        return;
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['token'];
        
        // Save new token to secure storage
        await _storage.write(key: 'auth_token', value: newToken);
      } else {
        // If refresh fails, log the user out
        await logout();
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      await logout();
    }
  }
}
