import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Reads from frontend/.env file, or build-time flag --dart-define=BACKEND_URL
  static String get _envBackendUrl {
    try {
      final fromDotEnv = dotenv.env['BACKEND_URL'];
      if (fromDotEnv != null && fromDotEnv.trim().isNotEmpty) {
        return fromDotEnv.trim();
      }
    } catch (_) {}

    const fromDefine = String.fromEnvironment('BACKEND_URL');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    return '';
  }

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

