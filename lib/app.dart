import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'routes/app_routes.dart';
import 'core/services/theme_service.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.instance;

    // ThemeMode 변경 시 즉시 재빌드
    return AnimatedBuilder(
      animation: theme,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'AI 감정일기',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,   // ✅ ThemeService 값 사용
          routerConfig: appRoutes,
        );
      },
    );
  }
}
