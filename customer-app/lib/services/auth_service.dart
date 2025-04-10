import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final String _tokenKey = 'auth_token';
  final String _userIdKey = 'user_id';
  final String _userDataKey = 'user_data';
  
  String? _token;
  String? _userId;
  User? _currentUser;
  
  String? get token => _token;
  String? get userId => _userId;
  User? get currentUser => _currentUser;
  
  // Initialize auth state
  Future<void> init() async {
    await _loadToken();
    await _loadUserId();
    await _loadUserData();
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    if (_token == null) {
      await _loadToken();
    }
    return _token != null;
  }
  
  // Save registration response
  Future<void> saveRegistrationResponse(RegistrationResponse response) async {
    await _secureStorage.write(key: _userIdKey, value: response.id);
    await _saveUserId(response.id);
    notifyListeners();
  }
  
  // Save auth token
  Future<void> saveToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _tokenKey, value: token);
    notifyListeners();
  }
  
  // Save user data
  Future<void> saveUserData(User user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonEncode(user.toJson());
    await prefs.setString(_userDataKey, userData);
    notifyListeners();
  }
  
  // Load token from secure storage
  Future<void> _loadToken() async {
    _token = await _secureStorage.read(key: _tokenKey);
  }
  
  // Load user ID from secure storage
  Future<void> _loadUserId() async {
    _userId = await _secureStorage.read(key: _userIdKey);
  }
  
  // Save user ID
  Future<void> _saveUserId(String userId) async {
    _userId = userId;
    await _secureStorage.write(key: _userIdKey, value: userId);
  }
  
  // Load user data from shared preferences
  Future<void> _loadUserData() async {
    if (_userId == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userDataKey);
    
    if (userData != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userData);
        _currentUser = User.fromJson(userMap);
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }
  
  // Logout
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _currentUser = null;
    
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userIdKey);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    
    notifyListeners();
  }
}
