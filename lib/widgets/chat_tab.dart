import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => ChatTabState();
}

class ChatTabState extends State<ChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  /// 외부에서 호출 가능한 리셋 함수
  void resetMessages() {
    setState(() {
      _messages.clear();
      _controller.clear();
    });
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String> fetchAiResponse({String? text, File? imageFile}) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (imageFile != null) {
      // Multipart 요청
      final url = Uri.parse('http://localhost:8080/api/gemini/ask-image');
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $idToken';
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('AI 응답 실패: ${response.statusCode} ${response.body}');
      }
    } else {
      // JSON 요청
      final url = Uri.parse('http://localhost:8080/api/gemini/ask');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'message': text}),
      );
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('AI 응답 실패: ${response.statusCode} ${response.body}');
      }
    }
  }


  Future<void> _sendMessage({String? text, File? imageFile}) async {
    if ((text == null || text.trim().isEmpty) && imageFile == null) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'content': imageFile?.path ?? text!,
        'type': imageFile != null ? 'image' : 'text',
      });
      _controller.clear();
      _loading = true;
    });

    _scrollToBottom();

    try {
      final aiResponse = await fetchAiResponse(
        text: text,
        imageFile: imageFile,
      );
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': aiResponse,
          'type': 'text',
        });
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'AI 응답 오류: $e',
          'type': 'text',
        });
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      await _sendMessage(imageFile: File(pickedFile.path));
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
            });
          },
        );
      }
    }
  }

  Widget _buildMessageBubble(String role, String content, String type) {
    final isUser = role == 'user';
    final alignment = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;
    final bubbleColor = isUser ? const Color(0xFF00A5D9) : Colors.grey[300];
    final textColor = isUser ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF00A5D9),
              child: Text('AI', style: TextStyle(color: Colors.white)),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: type == 'image'
                  ? Image.file(File(content), height: 120)
                  : Text(content, style: TextStyle(color: textColor)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(
                  msg['role']!,
                  msg['content']!,
                  msg['type'] ?? 'text',
                );
              },
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImage,
              ),
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                onPressed: _toggleListening,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '텍스트를 입력하거나 음성으로 말하세요',
                      border: InputBorder.none,
                    ),
                    onTap: _scrollToBottom,
                    onSubmitted: (val) => _sendMessage(text: val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _sendMessage(text: _controller.text),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFF00A5D9),
                  child: Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
