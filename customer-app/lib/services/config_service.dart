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
      print('Asset manifest: ${await rootBundle.loadString('AssetManifest.json')}');
      
      try {
        final configJson = await rootBundle.loadString('assets/config/config.json');
        print('Config JSON content: $configJson');
        final jsonConfig = json.decode(configJson);
        _config.addAll(jsonConfig);
        print('Loaded config.json: $_config');
      } catch (e) {
        print('Error loading config.json: $e');
        print('Trying to load from network...');
        
        // Try to load from network as a fallback
        try {
          final response = await rootBundle.loadString('assets/config/config.json');
          print('Network config content: $response');
          final jsonConfig = json.decode(response);
          _config.addAll(jsonConfig);
          print('Loaded network config: $_config');
        } catch (networkError) {
          print('Error loading from network: $networkError');
        }
      }
    } catch (e) {
      print('Error in config service: $e');
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
    final url = get('apiBaseUrl') ?? 'http://localhost:8080';
    print('Using API base URL: $url');
    return url;
  }
}
