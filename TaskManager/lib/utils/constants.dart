import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  /// Android Emulator truy cập máy host qua 10.0.2.2.
  /// Máy thật: đổi thành IP LAN của máy chạy backend, ví dụ http://192.168.1.10:3000/api
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  static const String tokenKey = 'auth_token';
  static const Duration requestTimeout = Duration(seconds: 15);
}
