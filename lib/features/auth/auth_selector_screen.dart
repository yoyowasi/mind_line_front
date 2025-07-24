import 'package:flutter/material.dart';
import 'login_form.dart';
import 'register_form.dart';

class AuthSelectorScreen extends StatefulWidget {
  const AuthSelectorScreen({super.key});

  @override
  State<AuthSelectorScreen> createState() => _AuthSelectorScreenState();
}

class _AuthSelectorScreenState extends State<AuthSelectorScreen> {
  String _currentView = 'initial'; // 'initial' | 'login' | 'register'

  void _show(String target) {
    setState(() => _currentView = target);
  }

  Widget _buildView() {
    switch (_currentView) {
      case 'login':
        return LoginForm(onBack: () => _show('initial'));
      case 'register':
        return RegisterForm(onBack: () => _show('initial'));
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _show('login'),
              child: const Text('로그인하기'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _show('register'),
              child: const Text('회원가입하기'),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _buildView(),
        ),
      ),
    );
  }
}
