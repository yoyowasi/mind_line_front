// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'controller/expense_controller.dart';
import 'core/services/fcm_service.dart';
import 'features/diary/diary_controller.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // TODO: 백그라운드 메시지 처리 로직
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FcmService().init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        // ✅ 앱 시작 시 최근 일기 + 최근 분석 요약 + 목록까지 한 번에 로드
        ChangeNotifierProvider(
          create: (_) => DiaryController()..loadInitial(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExpenseController()..loadExpenses(),
        ),
      ],
      child: const App(),
    ),
  );
}
