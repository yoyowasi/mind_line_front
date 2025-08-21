import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/fcm_service.dart'; // ✅ FcmService import 추가
import 'features/diary/diary_controller.dart';
import 'firebase_options.dart'; // ← 반드시 import

void main() async {
  // Flutter 엔진과 위젯 트리를 바인딩합니다.
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 앱을 초기화합니다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ FCM 서비스 초기화 코드 추가
  await FcmService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiaryController()),
      ],
      child: const App(),
    ),
  );
}