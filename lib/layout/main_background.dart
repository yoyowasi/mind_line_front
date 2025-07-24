// lib/screens/auth_selector_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/main_background.dart';

class AuthSelectorScreen extends StatelessWidget {
  const AuthSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MainBackground(
      child: AuthSelectorBody(),
    );
  }
}

class AuthSelectorBody extends StatelessWidget {
  const AuthSelectorBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '하루 감정 일기',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                backgroundColor: Colors.white.withOpacity(0.9),
                foregroundColor: Colors.deepPurple,
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('로그인하기'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/register'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('회원가입하기'),
            )
          ],
        ),
      ),
    );
  }
}
