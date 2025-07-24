import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/diary/diary_screen.dart';
import '../features/diary/diary_list_screen.dart';
import '../features/diary/emotion_stats_screen.dart';

import '../layout/main_scaffold.dart';

final GoRouter appRoutes = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isLoggingIn = state.uri.toString() == '/login' || state.uri.toString() == '/register';

    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    } else if (isLoggedIn && isLoggingIn) {
      return '/home';
    }
    return null;
  },
  routes: [
    // 로그인, 회원가입은 그냥 builder로
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

    // 아래는 모두 슬라이드 전환 적용
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _fadeTransition(
        state,
        const MainScaffold(
          title: 'AI 감정 일기',
          child: HomeScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/stats',
      pageBuilder: (context, state) => _fadeTransition(
        state,
        const MainScaffold(
          title: '감정 통계 보기',
          child: EmotionStatsScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/diary',
      pageBuilder: (context, state) => _fadeTransition(
        state,
        const MainScaffold(
          title: '일기 쓰기',
          child: DiaryScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/diary/list',
      pageBuilder: (context, state) => _fadeTransition(
        state,
        const MainScaffold(
          title: '내 일기 보기',
          child: DiaryListScreen(),
        ),
      ),
    ),

  ],
);

CustomTransitionPage _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

