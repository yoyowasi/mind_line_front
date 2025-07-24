import 'package:flutter/material.dart';

class LoginForm extends StatelessWidget {
  final VoidCallback onBack;
  const LoginForm({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('login'), // AnimatedSwitcher 구분용
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const Text('로그인', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 20),
        const TextField(decoration: InputDecoration(labelText: '이메일')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: '비밀번호'), obscureText: true),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: () {}, child: const Text('로그인')),
      ],
    );
  }
}
