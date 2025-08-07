import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/diary/diary_screen.dart';
import '../features/diary/diary_list_screen.dart';
import '../features/diary/emotion_stats_screen.dart';
import '../home/home_screen.dart';

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
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/diary', builder: (_, __) => const DiaryScreen()),
    GoRoute(path: '/diary/list', builder: (_, __) => const DiaryListScreen()),
    GoRoute(path: '/stats', builder: (_, __) => const EmotionStatsScreen()),
  ],
);
