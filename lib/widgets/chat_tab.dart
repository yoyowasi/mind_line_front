import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/config.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});
  @override
  State<ChatTab> createState() => ChatTabState();
}

class ChatTabState extends State<ChatTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _stt = stt.SpeechToText();

  bool _loading = false;
  bool _listening = false;
  String? _resultText; // 응답/오류
  bool _resultIsError = false;
  File? _lastImage; // 최근 보낸 이미지(미리보기)
  Timer? _debounce;

  // send 버튼 살짝 펄스
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.98, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Home에서 쓰던 refresh 버튼 호환
  void resetMessages() {
    setState(() {
      _controller.clear();
      _resultText = null;
      _resultIsError = false;
      _lastImage = null;
      _cachedLastText = null;
      _cachedLastImagePath = null;
    });
    final ps = PageStorage.of(context);
    ps.writeState(context, null, identifier: 'chat.lastText');
    ps.writeState(context, null, identifier: 'chat.lastImage');
  }

  // ---------- 유틸: 날짜/인삿말 ----------
  String _dateLine() {
    final now = DateTime.now();
    const w = ['', '월', '화', '수', '목', '금', '토', '일'];
    return '${now.year}년 ${now.month}월 ${now.day}일 (${w[now.weekday]})';
  }

  String _greet() {
    final h = DateTime.now().hour;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? '친구';
    if (h < 6) return '늦은 밤이에요, $name';
    if (h < 12) return '좋은 아침이에요, $name';
    if (h < 18) return '좋은 오후예요, $name';
    return '좋은 저녁이에요, $name';
  }

  String? _cachedLastText;
  String? _cachedLastImagePath;

  void _saveCache() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final ps = PageStorage.of(context);
    ps.writeState(context, _resultText, identifier: 'chat.$uid.lastText');
    ps.writeState(context, _lastImage?.path, identifier: 'chat.$uid.lastImage');
    _cachedLastText = _resultText;
    _cachedLastImagePath = _lastImage?.path;
  }

  void _loadCache() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final ps = PageStorage.of(context);
    _cachedLastText =
    ps.readState(context, identifier: 'chat.$uid.lastText') as String?;
    _cachedLastImagePath =
    ps.readState(context, identifier: 'chat.$uid.lastImage') as String?;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCache();
  }

  Widget _previousAnswerBanner(ColorScheme cs) {
    final hasPrev =
    (_cachedLastText != null && _cachedLastText!.trim().isNotEmpty);
    final shouldShow = !_loading && _resultText == null && hasPrev;

    if (!shouldShow) return const SizedBox.shrink();

    final preview = _cachedLastText!;
    final short =
    preview.length > 60 ? '${preview.substring(0, 60)}…' : preview;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Glass(
        radius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.history, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '이전 답변: $short',
                style:
                TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _resultText = _cachedLastText;
                  _resultIsError = false;
                  _lastImage = (_cachedLastImagePath != null &&
                      _cachedLastImagePath!.isNotEmpty)
                      ? File(_cachedLastImagePath!)
                      : null;
                });
              },
              child: const Text('열기'),
            ),
            TextButton(
              onPressed: () {
                final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
                final ps = PageStorage.of(context);
                ps.writeState(context, null, identifier: 'chat.$uid.lastText');
                ps.writeState(context, null, identifier: 'chat.$uid.lastImage');
                setState(() {
                  _cachedLastText = null;
                  _cachedLastImagePath = null;
                });
              },
              child: const Text('지우기'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- 백엔드 URL 보정 --------------------
  // http 패키지는 "절대 URL"만 허용합니다. (scheme 포함: http/https)
  // Config.apiBase가 'localhost:8080' 같은 형식이면 아래에서 http:// 를 붙여 절대 URL로 만듭니다.
  Uri _buildUrl(String path) {
    final baseRaw = (Config.apiBase ?? '').trim();
    if (baseRaw.isEmpty) {
      throw Exception('Config.apiBase가 비어 있습니다.');
    }
    // scheme 없으면 기본 http 붙임
    final hasScheme = baseRaw.contains('://');
    final baseUri = Uri.parse(hasScheme ? baseRaw : 'http://$baseRaw');

    // path 합치기 (base에 슬래시 유무 상관없이 안전하게 합침)
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(normalized);
  }

  // ---------- 백엔드 호출(엔드포인트: /api/gemini/ask, /api/gemini/ask-image) ----------
  Future<String> fetchAiResponse({String? text, File? imageFile}) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    if (imageFile != null) {
      final url = _buildUrl('/api/gemini/ask-image');
      final req = http.MultipartRequest('POST', url);
      if (idToken != null) {
        req.headers['Authorization'] = 'Bearer $idToken';
      }
      req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) return res.body;
      throw Exception('AI 응답 실패: ${res.statusCode} ${res.body}');
    } else {
      final url = _buildUrl('/api/gemini/ask');
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'message': text}),
      );
      if (res.statusCode == 200) return res.body;
      throw Exception('AI 응답 실패: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> _ask({String? text, File? imageFile}) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty && imageFile == null) return;

    _controller.clear();

    setState(() {
      _loading = true;
      _resultText = null;
      _resultIsError = false;
      _lastImage = imageFile;
    });
    _focus.unfocus();

    try {
      final res = await fetchAiResponse(
          text: t.isEmpty ? null : t, imageFile: imageFile)
          .timeout(const Duration(seconds: 30)); // 30초 타임아웃
      setState(() {
        _resultText = res;
        _resultIsError = false;
      });
      _saveCache(); // ✅ 최근 답변 캐시
    } on TimeoutException catch (_) {
      setState(() {
        _resultText = '응답 시간이 초과되었습니다. 다시 시도해주세요.';
        _resultIsError = true;
      });
    } catch (e) {
      setState(() {
        _resultText = 'AI 응답 오류: $e';
        _resultIsError = true;
      });
      _saveCache(); // ✅ 오류도 최근값으로 보관(원하면 생략 가능)
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await _ask(imageFile: File(picked.path));
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      return;
    }
    final ok = await _stt.initialize();
    if (!ok) return;
    setState(() => _listening = true);
    _stt.listen(onResult: (r) {
      setState(() => _controller.text = r.recognizedWords);
    });
  }

  // 빠른 예시 칩
  List<String> get _quickChips => [
    '오늘 할 일 3개만 정리해줘',
    '지출 12,000원 편의점으로 기록해줘',
    '다음주 화요일 오후 2시 미팅 잡아줘',
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    const maxW = 720.0;

    final bg1 = isDark
        ? cs.surfaceContainerHighest
        : cs.primaryContainer.withAlpha(77);
    final bg2 =
    isDark ? cs.surface : cs.tertiaryContainer.withAlpha(71);

    final showQuickChips = !_loading && _resultText == null && _lastImage == null;

    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: Stack(
        children: [
          // 1) 배경: 감성 그라데이션(다크/라이트 대응)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 살짝 도형 겹침
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(color: cs.primary.withAlpha(51), size: 220),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: _Blob(color: cs.secondary.withAlpha(46), size: 180),
          ),

          // 2) 콘텐츠
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: keyboard + 32, top: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxW),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _previousAnswerBanner(cs),

                    // 헤더: 날짜 + 인삿말 (글라스 카드)
                    _Glass(
                      radius: 18,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: cs.primary.withAlpha(31),
                            child: Icon(Icons.auto_awesome, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dateLine(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _greet(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 검색창(유리카드)
                    _Glass(
                      radius: 24,
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon:
                            Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
                            tooltip: '이미지',
                            onPressed: _pickImage,
                          ),
                          IconButton(
                            icon: Icon(
                                _listening ? Icons.mic : Icons.mic_none,
                                color: cs.onSurfaceVariant),
                            tooltip: '음성 입력',
                            onPressed: _toggleMic,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: '무엇이든 물어보세요…',
                                hintStyle:
                                TextStyle(color: cs.onSurfaceVariant),
                                border: InputBorder.none,
                              ),
                              style: TextStyle(color: cs.onSurface),
                              onSubmitted: (v) => _ask(text: v),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ScaleTransition(
                            scale: _loading
                                ? _scale
                                : const AlwaysStoppedAnimation(1.0),
                            child: InkWell(
                              onTap: _loading ? null : () => _ask(text: _controller.text),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient:
                                  LinearGradient(colors: [cs.primary, cs.secondary]),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withAlpha(89),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: _loading
                                    ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                                    : const Icon(Icons.arrow_upward,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 빠른 예시 칩
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: showQuickChips
                          ? Wrap(
                        key: const ValueKey('chips'),
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickChips.map((t) {
                          return ActionChip(
                            label: Text(t),
                            avatar: Icon(Icons.auto_awesome,
                                size: 18, color: cs.primary),
                            onPressed: () {
                              setState(() => _controller.text = t);
                              _focus.requestFocus();
                            },
                          );
                        }).toList(),
                      )
                          : const SizedBox.shrink(key: ValueKey('nochips')),
                    ),

                    // 결과 카드 (응답/오류)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      child: (_resultText == null && !_loading)
                          ? const SizedBox(height: 24)
                          : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _Glass(
                          key: ValueKey(_resultText ?? _loading),
                          radius: 18,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _resultIsError
                                        ? Icons.error_outline
                                        : Icons.auto_awesome,
                                    color: _resultIsError
                                        ? Colors.redAccent
                                        : cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _resultIsError ? '오류가 있었어요' : 'AI의 생각',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _resultIsError
                                          ? Colors.redAccent
                                          : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_lastImage != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_lastImage!, height: 140),
                                ),
                              if (_lastImage != null)
                                const SizedBox(height: 10),
                              if (_loading)
                                const Center(
                                  child: Padding(
                                    padding:
                                    EdgeInsets.symmetric(vertical: 16),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else
                                Text(
                                  _resultText ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.48,
                                    color: _resultIsError
                                        ? Colors.red[300]
                                        : cs.onSurface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 블러(글라스) 컨테이너: 다크/라이트 대응
class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const _Glass(
      {super.key,
        required this.child,
        required this.padding,
        required this.radius});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor =
    isDark ? cs.surface.withAlpha(140) : Colors.white.withAlpha(184);

    final borderColor = isDark
        ? cs.outlineVariant.withAlpha(71)
        : Colors.white.withAlpha(166);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 77 : 15),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 둥근 블롭 장식
class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withAlpha(115), blurRadius: 30)],
      ),
    );
  }
}
