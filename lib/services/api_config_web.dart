// lib/services/api_config_web.dart
// Web implementation - reads API_BASE_URL from window.ENV (env.js)
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;

String? getApiBaseUrl() {
  try {
    final env = js.context['ENV'];
    if (env != null) {
      final url = env['API_BASE_URL'];
      if (url != null) return url.toString();
    }
  } catch (_) {}
  return null;
}
