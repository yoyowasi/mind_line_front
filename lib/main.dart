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
  // TODO: 메시지 처리 로직
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
        // ✅ ChangeNotifierProvider 생성 시 loadDiaries()를 바로 호출합니다.
        ChangeNotifierProvider(
          create: (_) => DiaryController()..loadDiaries(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExpenseController()..loadExpenses(),
        ),
      ],
      child: const App(),
    ),
  );
}