// app.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ✅ 추가
import 'core/app_theme.dart';
import 'routes/app_routes.dart';
import 'core/services/theme_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;

    return AnimatedBuilder(
      animation: theme,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'AI 감정일기',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          routerConfig: appRoutes,

          // ✅ 여기 추가
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko'),
            Locale('en'),
            Locale('ja'),
            Locale('zh'),
          ],
          // 항상 한글 고정 원하면 주석 해제
          // locale: const Locale('ko'),
        );
      },
    );
  }
}
