import 'dart:convert';
import 'dart:io';
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

  // Check if running in container
  bool _isRunningInContainer() {
    try {
      return File('/.dockerenv').existsSync();
    } catch (e) {
      return false;
    }
  }

  // Get default API base URL based on environment
  String _getDefaultApiBaseUrl() {
    return _isRunningInContainer() 
      ? 'http://user-registration-service:8080'
      : 'http://localhost:8086';
  }

  // Initialize the config service
  Future<void> init() async {
    if (_isInitialized) {
      print('Config Service - Already initialized');
      return;
    }

    print('Config Service - Initializing');
    print('Running in container: ${_isRunningInContainer()}');

    // Default configuration
    _config = {
      'apiBaseUrl': _getDefaultApiBaseUrl()
    };
    print('Config Service - Default config: $_config');

    try {
      // Load configuration from assets/config/config.json
      print('Config Service - Loading configuration from config.json');
      print('Asset manifest: ${await rootBundle.loadString('AssetManifest.json')}');
      
      try {
        final configJson = await rootBundle.loadString('assets/config/config.json');
        print('Config Service - Config JSON content: $configJson');
        final jsonConfig = json.decode(configJson);
        print('Config Service - Parsed JSON config: $jsonConfig');
        _config.addAll(jsonConfig);
        print('Config Service - Final config after merging: $_config');
      } catch (e) {
        print('Config Service - Error loading config.json: $e');
        print('Config Service - Trying to load from network...');
        
        // Try to load from network as a fallback
        try {
          final response = await rootBundle.loadString('assets/config/config.json');
          print('Config Service - Network config content: $response');
          final jsonConfig = json.decode(response);
          print('Config Service - Parsed network config: $jsonConfig');
          _config.addAll(jsonConfig);
          print('Config Service - Final config after network load: $_config');
        } catch (networkError) {
          print('Config Service - Error loading from network: $networkError');
          print('Config Service - Using default configuration: $_config');
        }
      }
    } catch (e) {
      print('Config Service - Error in config service: $e');
      print('Config Service - Using default configuration: $_config');
    }

    _isInitialized = true;
    print('Config Service - Initialization complete');
  }

  // Get a value from the config
  String? get(String key) {
    final value = _config[key]?.toString();
    print('Config Service - Getting config key "$key": $value');
    return value;
  }

  // Get API base URL
  String getApiBaseUrl() {
    final url = get('apiBaseUrl') ?? _getDefaultApiBaseUrl();
    print('Config Service - Using API base URL: $url');
    return url;
  }
}
