import 'package:flutter/material.dart';

class DiaryTab extends StatelessWidget {
  const DiaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '감정 일기',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263FA9),
                ),
              ),
              SizedBox(height: 16),
              Placeholder(fallbackHeight: 200), // TODO: 일기 작성 UI
            ],
          ),
        ),
      ),
    );
  }
}
