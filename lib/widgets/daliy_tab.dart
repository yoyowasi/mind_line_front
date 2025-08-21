import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryEntry {
  final String id;            // 고유 ID (timestamp 기반)
  final DateTime date;        // 일자 (시간 00:00:00로 normalize)
  final String title;
  final String content;
  final String mood;          // 이모지 등 간단 표기
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  DiaryEntry copyWith({
    String? title,
    String? content,
    String? mood,
    DateTime? date,
  }) {
    return DiaryEntry(
      id: id,
      date: date ?? this.date,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': DateTime(date.year, date.month, date.day).toIso8601String(),
    'title': title,
    'content': content,
    'mood': mood,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static DiaryEntry fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as String,
      date: DateTime.parse(map['date'] as String),
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      mood: (map['mood'] as String?) ?? '🙂',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class DaliyTab extends StatefulWidget {
  const DaliyTab({super.key});

  @override
  State<DaliyTab> createState() => _DaliyTabState();
}

class _DaliyTabState extends State<DaliyTab>
    with AutomaticKeepAliveClientMixin {
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  List<DiaryEntry> _entries = [];
  DateTime _selectedDate =
  DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  // 검색
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  String get _spKey {
    final uid = _auth.currentUser?.uid ?? 'anon';
    return 'diary.$uid.v1';
    // 사용자별로 분리 저장
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_spKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => DiaryEntry.fromMap(e as Map<String, dynamic>))
            .toList();
        _entries = list..sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {
        // 손상되었으면 초기화
        _entries = [];
      }
    } else {
      _entries = [];
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final json = jsonEncode(_entries.map((e) => e.toMap()).toList());
    await sp.setString(_spKey, json);
  }

  List<DiaryEntry> get _entriesForSelected {
    final d = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final filtered = _entries.where((e) =>
    e.date.year == d.year && e.date.month == d.month && e.date.day == d.day);
    if (_query.trim().isEmpty) return filtered.toList();
    final q = _query.toLowerCase();
    return filtered
        .where((e) =>
    e.title.toLowerCase().contains(q) ||
        e.content.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _goPrevDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _goNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> _createOrEdit([DiaryEntry? existing]) async {
    final result = await showModalBottomSheet<_EditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DiaryEditorSheet(
        date: existing?.date ?? _selectedDate,
        initialTitle: existing?.title ?? '',
        initialContent: existing?.content ?? '',
        initialMood: existing?.mood ?? '🙂',
      ),
    );

    if (result == null) return;

    if (existing == null) {
      // 새로 추가
      final now = DateTime.now();
      final entry = DiaryEntry(
        id: now.microsecondsSinceEpoch.toString(),
        date: DateTime(result.date.year, result.date.month, result.date.day),
        title: result.title,
        content: result.content,
        mood: result.mood,
        createdAt: now,
        updatedAt: now,
      );
      setState(() {
        _entries.add(entry);
        _entries.sort((a, b) => b.date.compareTo(a.date));
        _selectedDate = entry.date;
      });
      await _save();
    } else {
      // 편집
      final idx = _entries.indexWhere((e) => e.id == existing.id);
      if (idx >= 0) {
        final updated = existing.copyWith(
          title: result.title,
          content: result.content,
          mood: result.mood,
          date: DateTime(result.date.year, result.date.month, result.date.day),
        );
        setState(() {
          _entries[idx] = updated;
          _entries.sort((a, b) => b.date.compareTo(a.date));
          _selectedDate = updated.date;
        });
        await _save();
      }
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: const Text('이 일기 항목을 삭제합니다. 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
    await _save();
  }

  String _dateKorean(DateTime d) {
    const w = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.year}년 ${d.month}월 ${d.day}일 (${w[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _entriesForSelected;

    return Scaffold(
      backgroundColor:
      Theme.of(context).brightness == Brightness.dark ? cs.surface : Colors.grey[100],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  Text('일기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary)),
                  const Spacer(),
                  IconButton(onPressed: _goPrevDay, icon: const Icon(Icons.chevron_left)),
                  Flexible(
                    child: Text(_dateKorean(_selectedDate),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurface)),
                  ),
                  IconButton(onPressed: _goNextDay, icon: const Icon(Icons.chevron_right)),
                  const SizedBox(width: 6),
                  FilledButton.tonal(onPressed: _goToday, child: const Text('오늘')),
                  const SizedBox(width: 6),
                  IconButton(onPressed: _pickDate, icon: const Icon(Icons.event)),
                ],
              ),
              const SizedBox(height: 12),

              // 검색
              TextField(
                decoration: InputDecoration(
                  hintText: '제목/내용 검색…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),

              // 리스트
              Expanded(
                child: items.isEmpty
                    ? _EmptyState(
                  onWrite: () => _createOrEdit(),
                  message: '이 날 작성한 일기가 없어요.\n아래 버튼으로 새 일기를 써 보세요!',
                )
                    : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return _DiaryCard(
                      entry: e,
                      onEdit: () => _createOrEdit(e),
                      onDelete: () => _delete(e.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.edit),
        label: const Text('새 일기'),
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DiaryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  String _timeLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Text(entry.mood, style: const TextStyle(fontSize: 22)),
        title: Text(
          entry.title.isEmpty ? '(제목 없음)' : entry.title,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            entry.content.isEmpty ? '(내용 없음)' : entry.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'del') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('편집')),
            PopupMenuItem(value: 'del', child: Text('삭제')),
          ],
        ),
        dense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onWrite;
  const _EmptyState({required this.message, required this.onWrite});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_outlined, size: 48, color: cs.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onWrite, child: const Text('지금 쓰기')),
        ],
      ),
    );
  }
}

class _EditorResult {
  final DateTime date;
  final String title;
  final String content;
  final String mood;
  _EditorResult(this.date, this.title, this.content, this.mood);
}

class _DiaryEditorSheet extends StatefulWidget {
  final DateTime date;
  final String initialTitle;
  final String initialContent;
  final String initialMood;

  const _DiaryEditorSheet({
    required this.date,
    required this.initialTitle,
    required this.initialContent,
    required this.initialMood,
  });

  @override
  State<_DiaryEditorSheet> createState() => _DiaryEditorSheetState();
}

class _DiaryEditorSheetState extends State<_DiaryEditorSheet> {
  late DateTime _date;
  late final TextEditingController _title;
  late final TextEditingController _content;
  late String _mood;

  final _moods = const ['🙂', '😊', '😐', '😔', '🎉', '💡', '🔥', '😴'];

  @override
  void initState() {
    super.initState();
    _date = widget.date;
    _title = TextEditingController(text: widget.initialTitle);
    _content = TextEditingController(text: widget.initialContent);
    _mood = widget.initialMood;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 바
            Row(
              children: [
                Text('일기 작성', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),

            // 날짜 & 오늘 버튼
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event),
                  label: Text('${_date.year}.${_date.month}.${_date.day}'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() {
                      _date = DateTime(now.year, now.month, now.day);
                    });
                  },
                  child: const Text('오늘'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 무드 선택
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _moods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = _moods[i];
                  final selected = m == _mood;
                  return ChoiceChip(
                    label: Text(m, style: const TextStyle(fontSize: 18)),
                    selected: selected,
                    onSelected: (_) => setState(() => _mood = m),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _title,
              decoration: InputDecoration(
                hintText: '제목',
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: '오늘 있었던 일을 적어보세요…',
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.6)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        _EditorResult(_date, _title.text.trim(), _content.text.trim(), _mood),
                      );
                    },
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
