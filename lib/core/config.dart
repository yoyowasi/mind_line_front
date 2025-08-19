import 'dart:io';
import 'package:flutter/foundation.dart';

class Config {
  static const apiBase = 'http://localhost:8080';

  /*static String get apiBase {
    // 우선순위: --dart-define
    const override = String.fromEnvironment('API_BASE', defaultValue: '');
    if (override.isNotEmpty) return override;

    // 기본값(로컬 개발)
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }*/
}
