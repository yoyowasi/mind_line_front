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

  // --- 임시 분류 상태 ---
  _Cat _selectedCat = _Cat.none;

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
      _selectedCat = _Cat.none; // 분류 초기화
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

  // --- 일기 요약 엔드포인트 바로 호출 ---

  Future<void> _summarizeDiaryToday() async {
    await _summarizeDiaryByDate(DateTime.now());
  }

  Future<void> _summarizeDiaryByDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    final dateStr = date.toIso8601String().split('T').first; // YYYY-MM-DD

    setState(() {
      _loading = true;
      _resultText = null;
      _resultIsError = false;
      _lastImage = null;
    });

    try {
      final url = _buildUrl('/api/ai/diary/latest-summary');
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _resultText = data['summary']; // ✅ answer → summary
          _resultIsError = false;
        });
      } else {
        throw Exception('요약 실패: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      setState(() {
        _resultText = '일기 요약 오류: $e';
        _resultIsError = true;
      });
      _saveCache();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 입력창의 텍스트를 원문으로 POST 요약 (/api/ai/diary/summary)
  Future<void> _summarizeDiaryFromInput() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요약할 텍스트를 입력해 주세요.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    setState(() {
      _loading = true;
      _resultText = null;
      _resultIsError = false;
      _lastImage = null;
    });
    _focus.unfocus();
  }

  // -------------------- 백엔드 URL 보정 --------------------
  Uri _buildUrl(String path) {
    final baseRaw = (Config.apiBase ?? '').trim();
    if (baseRaw.isEmpty) {
      throw Exception('Config.apiBase가 비어 있습니다.');
    }
    final hasScheme = baseRaw.contains('://');
    final baseUri = Uri.parse(hasScheme ? baseRaw : 'http://$baseRaw');
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(normalized);
  }

  // ---------- 백엔드 호출 ----------
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
      final url = _buildUrl('/api/ai/ask');
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }
      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'message': text}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);     // ✅ JSON 파싱
        return data['answer'];                 // ✅ answer 값만 반환
      }
      throw Exception('AI 응답 실패: ${res.statusCode} ${res.body}');
    }
  }

  // 선택된 분류를 텍스트 앞에 태그로 붙인다. (백엔드가 태그만 파싱해도 라우팅 가능)
  String _applyCategoryTag(String raw) {
    if (_selectedCat == _Cat.none) return raw;
    return '[CATEGORY:${_selectedCat.name}] $raw';
  }

  Future<void> _ask({String? text, File? imageFile}) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty && imageFile == null) return;

    // 전송 직전 입력창 클리어
    _controller.clear();

    setState(() {
      _loading = true;
      _resultText = null;
      _resultIsError = false;
      _lastImage = imageFile;
    });
    _focus.unfocus();

    try {
      final sendText = t.isEmpty ? null : _applyCategoryTag(t);
      final res = await fetchAiResponse(text: sendText, imageFile: imageFile)
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
        : cs.primaryContainer.withOpacity(0.30);
    final bg2 =
    isDark ? cs.surface : (cs.tertiaryContainer ?? cs.secondaryContainer).withOpacity(0.28);

    final showQuickChips = !_loading && _resultText == null && _lastImage == null;

    return GestureDetector(
      onTap: () => _focus.unfocus(),
      child: Stack(
        children: [
          // 1) 배경
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 장식
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(color: cs.primary.withOpacity(0.20), size: 220),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: _Blob(color: cs.secondary.withOpacity(0.18), size: 180),
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

                    // 헤더
                    _Glass(
                      radius: 18,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: cs.primary.withOpacity(0.12),
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
                    const SizedBox(height: 12),

                    // ✅ 일기 요약 퀵액션 바 (채팅 입력창 위에 배치 추천)
                    _Glass(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _loading ? null : _summarizeDiaryToday,
                            icon: const Icon(Icons.today),
                            label: const Text('오늘 일기 요약'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2023),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                await _summarizeDiaryByDate(picked);
                              }
                            },
                            icon: const Icon(Icons.event),
                            label: const Text('다른 날짜 요약'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _summarizeDiaryFromInput,
                            icon: const Icon(Icons.note_alt_outlined),
                            label: const Text('텍스트로 요약'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),


                    // 검색창(유리카드)
                    _Glass(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
                            tooltip: '이미지',
                            onPressed: _pickImage,
                          ),
                          IconButton(
                            icon: Icon(_listening ? Icons.mic : Icons.mic_none, color: cs.onSurfaceVariant),
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
                                hintText: _selectedCat == _Cat.none
                                    ? '무엇이든 물어보세요…'
                                    : '[${_selectedCat.label}] 내용 입력…',
                                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                                border: InputBorder.none,
                              ),
                              style: TextStyle(color: cs.onSurface),
                              onSubmitted: (v) => _ask(text: v),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ScaleTransition(
                            scale: _loading ? _scale : const AlwaysStoppedAnimation(1.0),
                            child: InkWell(
                              onTap: _loading ? null : () => _ask(text: _controller.text),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withOpacity(0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: _loading
                                    ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                                    : const Icon(Icons.arrow_upward, color: Colors.white),
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
                            avatar: Icon(Icons.auto_awesome, size: 18, color: cs.primary),
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
                                    _resultIsError ? Icons.error_outline : Icons.auto_awesome,
                                    color: _resultIsError ? Colors.redAccent : cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _resultIsError ? '오류가 있었어요' : 'AI의 생각',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: _resultIsError ? Colors.redAccent : cs.onSurface,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_selectedCat != _Cat.none)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_selectedCat.icon, size: 14, color: cs.primary),
                                          const SizedBox(width: 4),
                                          Text(_selectedCat.label, style: TextStyle(color: cs.primary, fontSize: 12)),
                                        ],
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
                              if (_lastImage != null) const SizedBox(height: 10),
                              if (_loading)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else
                                Text(
                                  _resultText ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.48,
                                    color: _resultIsError ? Colors.red[300] : cs.onSurface,
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

  // ----- 분류 칩 위젯 -----
  Widget _catChip(ColorScheme cs, _Cat c) {
    final selected = _selectedCat == c;
    final bg = selected ? cs.primary.withOpacity(0.12) : Colors.transparent;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;

    return ChoiceChip(
      selected: selected,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      avatar: Icon(c.icon, size: 16, color: fg),
      label: Text(c.label, style: TextStyle(color: fg)),
      selectedColor: bg,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
      onSelected: (_) {
        setState(() {
          _selectedCat = (selected ? _Cat.none : c);
        });
      },
    );
  }
}

/// 임시 분류용 enum
enum _Cat { none, diary, expense, schedule, memo }

extension on _Cat {
  String get label {
    switch (this) {
      case _Cat.none:
        return '분류 안함';
      case _Cat.diary:
        return '일기';
      case _Cat.expense:
        return '지출';
      case _Cat.schedule:
        return '일정';
      case _Cat.memo:
        return '메모';
    }
  }

  IconData get icon {
    switch (this) {
      case _Cat.none:
        return Icons.block_outlined;
      case _Cat.diary:
        return Icons.book_outlined;
      case _Cat.expense:
        return Icons.attach_money;
      case _Cat.schedule:
        return Icons.calendar_month;
      case _Cat.memo:
        return Icons.sticky_note_2_outlined;
    }
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
    isDark ? cs.surface.withOpacity(0.55) : Colors.white.withOpacity(0.72);

    final borderColor = isDark
        ? cs.outlineVariant.withOpacity(0.28)
        : Colors.white.withOpacity(0.65);

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
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.06),
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
        boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 30)],
      ),
    );
  }
}
