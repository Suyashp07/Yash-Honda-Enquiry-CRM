import 'package:flutter/foundation.dart';

class ApiConstants {
  // Configured via compile-time flag: --dart-define=BACKEND_URL=https://your-backend.com
  static const String _envBackendUrl = String.fromEnvironment('BACKEND_URL');

  static String get baseUrl {
    if (_envBackendUrl.isNotEmpty) {
      final sanitized = _envBackendUrl.endsWith('/')
          ? _envBackendUrl.substring(0, _envBackendUrl.length - 1)
          : _envBackendUrl;
      return sanitized.endsWith('/api') ? sanitized : '$sanitized/api';
    }

    // On Android emulator, 10.0.2.2 maps to host machine localhost:3000
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  static String get wsUrl {
    if (_envBackendUrl.isNotEmpty) {
      final sanitized = _envBackendUrl.endsWith('/')
          ? _envBackendUrl.substring(0, _envBackendUrl.length - 1)
          : _envBackendUrl;
      return '$sanitized/realtime/floor';
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/realtime/floor';
    }
    return 'http://localhost:3000/realtime/floor';
  }
}

