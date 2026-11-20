import 'package:flutter/foundation.dart';

class ApiConstants {
  // On Android emulator, 10.0.2.2 maps to host machine localhost:3000
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  static String get wsUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/realtime/floor';
    }
    return 'http://localhost:3000/realtime/floor';
  }
}

