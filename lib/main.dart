import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/fcm_service.dart';
import 'features/diary/diary_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FcmService().init();

  runApp(
    MultiProvider(
      providers: [
        // ✅ ChangeNotifierProvider 생성 시 loadDiaries()를 바로 호출합니다.
        ChangeNotifierProvider(
          create: (_) => DiaryController()..loadDiaries(),
        ),
      ],
      child: const App(),
    ),
  );
}