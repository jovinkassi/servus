// lib/services/api_config.dart
// Centralized API configuration - reads backend URL from web/env.js
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'api_config_stub.dart'
    if (dart.library.html) 'api_config_web.dart' as platform;

class ApiConfig {
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  String get baseUrl {
    final envUrl = platform.getApiBaseUrl();
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    // Fallback for development
    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }

  void printConfig() {
    if (kDebugMode) {
      print('API Base URL: $baseUrl');
    }
  }
}
