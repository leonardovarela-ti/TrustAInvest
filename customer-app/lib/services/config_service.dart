import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static ConfigService? _instance;
  late Map<String, dynamic> _config;
  bool _isInitialized = false;

  // Private constructor
  ConfigService._();

  // Factory constructor to return the singleton instance
  factory ConfigService() {
    _instance ??= ConfigService._();
    return _instance!;
  }

  // Initialize the config service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Try to load config from assets/config/config.json first
      final configJson = await rootBundle.loadString('assets/config/config.json');
      _config = json.decode(configJson);
    } catch (e) {
      // If config.json doesn't exist, create an empty config
      _config = {};
    }

    _isInitialized = true;
  }

  // Get a value from the config, with fallback to .env file
  String? get(String key) {
    // First try to get from config.json
    if (_config.containsKey(key)) {
      return _config[key];
    }
    
    // Then try to get from .env
    return dotenv.env[key];
  }

  // Get API base URL with fallback
  String getApiBaseUrl() {
    return get('apiBaseUrl') ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080';
  }
}
