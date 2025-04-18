import 'dart:convert';
import 'package:flutter/services.dart';

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

    // Default configuration
    _config = {
      'apiBaseUrl': 'http://localhost:8080'
    };

    try {
      // Load configuration from assets/config/config.json
      print('Loading configuration from config.json');
      final configJson = await rootBundle.loadString('assets/config/config.json');
      final jsonConfig = json.decode(configJson);
      _config.addAll(jsonConfig);
      print('Loaded config.json: $_config');
    } catch (e) {
      print('Error loading config.json: $e');
      print('Using default configuration: $_config');
    }

    _isInitialized = true;
  }

  // Get a value from the config
  String? get(String key) {
    return _config[key]?.toString();
  }

  // Get API base URL
  String getApiBaseUrl() {
    return get('apiBaseUrl') ?? 'http://localhost:8080';
  }
}
