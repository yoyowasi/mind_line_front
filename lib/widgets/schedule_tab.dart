// lib/tabs/schedule_tab.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/* ===================== 데이터 모델 & 저장소 ===================== */

class TodoItem {
  final String id;              // uuid-like
  final String title;           // 제목
  final String note;            // 메모 (optional)
  final DateTime? due;          // 마감(알림) 시간 (optional)
  final bool remind;            // 알림 사용 여부
  final bool done;              // 완료 여부
  final int? notifId;           // 예약된 알림 id (nullable)
  final DateTime createdAt;     // 생성일

  const TodoItem({
    required this.id,
    required this.title,
    required this.note,
    required this.due,
    required this.remind,
    required this.done,
    required this.notifId,
    required this.createdAt,
  });

  TodoItem copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? due,
    bool? remind,
    bool? done,
    int? notifId, // 주의: null도 전달될 수 있어야 함
    DateTime? createdAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      due: due ?? this.due,
      remind: remind ?? this.remind,
      done: done ?? this.done,
      notifId: notifId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'note': note,
    'due': due?.toIso8601String(),
    'remind': remind,
    'done': done,
    'notifId': notifId,
    'createdAt': createdAt.toIso8601String(),
  };

  static TodoItem fromMap(Map<String, dynamic> m) => TodoItem(
    id: m['id'] as String,
    title: m['title'] as String,
    note: (m['note'] as String?) ?? '',
    due: (m['due'] as String?) != null ? DateTime.parse(m['due'] as String) : null,
    remind: (m['remind'] as bool?) ?? false,
    done: (m['done'] as bool?) ?? false,
    notifId: m['notifId'] as int?,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}

class _TodoStore {
  static const _key = 'todos.v1';

  static Future<List<TodoItem>> loadAll() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => TodoItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      // 최신 생성 순으로 정렬
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(List<TodoItem> all) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(all.map((e) => e.toMap()).toList());
    await sp.setString(_key, raw);
  }
}

/* ===================== 알림(로컬) 서비스 ===================== */

class _NotificationService {
  _NotificationService._();
  static final _i = _NotificationService._();
  static _NotificationService get I => _i;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;

    // timezone 초기화
    try {
      tz.initializeTimeZones();
      final local = DateTime.now().timeZoneName; // ex. KST
      // 플랫폼이 자동으로 local 찾아줌; 명시 설정 필요 X
    } catch (_) {}

    // 알림 초기화
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(init);

    // 권한 요청
    await _requestPermissions();

    _inited = true;
  }

  Future<void> _requestPermissions() async {
    // Android 13+ 알림 권한
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    // iOS 권한
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, sound: true, badge: true);
  }

  AndroidNotificationDetails _androidDetails() {
    return const AndroidNotificationDetails(
      'todo_channel',
      '할 일 알림',
      channelDescription: '할 일 마감/리마인더 알림 채널',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      ticker: 'todo',
    );
  }

  DarwinNotificationDetails _iosDetails() {
    return const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
  }

  /// 예약 알림
  Future<int> scheduleAt({
    required String title,
    required String body,
    required DateTime when,
    int? notifId,
  }) async {
    await init();
    // 알림 id 없으면 생성
    final id = notifId ?? Random().nextInt(0x7FFFFFFF);

    final tzTime = tz.TZDateTime.from(when, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(android: _androidDetails(), iOS: _iosDetails()),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
      payload: 'todo',
    );
    return id;
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }
}

/* ===================== UI 탭 ===================== */

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final _df = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');
  List<TodoItem> _all = [];
  bool _showDone = false;

  @override
  void initState() {
    super.initState();
    _load();
    // 알림 서비스 준비
    _NotificationService.I.init();
  }

  Future<void> _load() async {
    final all = await _TodoStore.loadAll();
    setState(() => _all = all);
  }

  Future<void> _save() async => _TodoStore.saveAll(_all);

  /* --------- 파생 데이터 --------- */
  List<TodoItem> get _visible {
    final base = _showDone ? _all : _all.where((e) => !e.done).toList();
    // 정렬: 1) 완료여부 2) 마감 가까운 순 3) 생성 최신
    base.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ad = a.due?.millisecondsSinceEpoch ?? 1 << 62;
      final bd = b.due?.millisecondsSinceEpoch ?? 1 << 62;
      final cmpDue = ad.compareTo(bd);
      if (cmpDue != 0) return cmpDue;
      return b.createdAt.compareTo(a.createdAt);
    });
    return base;
  }

  /* --------- 액션: 추가/수정/삭제/완료/알림 --------- */
  Future<void> _add() async {
    final created = await showModalBottomSheet<TodoItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EditTodoSheet(),
    );
    if (created == null) return;

    // 알림 설정
    int? newNotifId;
    if (created.remind && created.due != null && created.due!.isAfter(DateTime.now())) {
      newNotifId = await _NotificationService.I.scheduleAt(
        title: created.title,
        body: created.note.isEmpty ? '할 일이 있어요' : created.note,
        when: created.due!,
      );
    }

    final withId = created.copyWith(notifId: newNotifId);
    setState(() => _all.insert(0, withId));
    await _save();
  }

  Future<void> _edit(TodoItem item) async {
    final edited = await showModalBottomSheet<TodoItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EditTodoSheet(existing: item),
    );
    if (edited == null) return;

    // 기존 알림 취소
    if (item.notifId != null) {
      await _NotificationService.I.cancel(item.notifId!);
    }

    // 새 알림 예약(조건 충족 시)
    int? newNotifId;
    if (edited.remind && edited.due != null && edited.due!.isAfter(DateTime.now()) && !edited.done) {
      newNotifId = await _NotificationService.I.scheduleAt(
        title: edited.title,
        body: edited.note.isEmpty ? '할 일이 있어요' : edited.note,
        when: edited.due!,
      );
    }

    final idx = _all.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;
    setState(() => _all[idx] = edited.copyWith(notifId: newNotifId));
    await _save();
  }

  Future<void> _toggleDone(TodoItem item) async {
    final idx = _all.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;

    final nowDone = !item.done;

    // 완료로 바꾸면 알림 취소
    if (nowDone && item.notifId != null) {
      await _NotificationService.I.cancel(item.notifId!);
    }

    // 미완료로 바꾸고, 알림 설정 켜져 있고 미래 시점이면 재예약
    int? newNotifId = item.notifId;
    if (!nowDone && item.remind && item.due != null && item.due!.isAfter(DateTime.now())) {
      newNotifId = await _NotificationService.I.scheduleAt(
        title: item.title,
        body: item.note.isEmpty ? '할 일이 있어요' : item.note,
        when: item.due!,
        notifId: item.notifId, // 기존 id 재사용 시도
      );
    }

    setState(() => _all[idx] = item.copyWith(done: nowDone, notifId: newNotifId));
    await _save();
  }

  Future<void> _delete(TodoItem item) async {
    final idx = _all.indexWhere((e) => e.id == item.id);
    if (idx < 0) return;

    final removed = _all[idx];
    setState(() => _all.removeAt(idx));
    await _save();

    // 알림 취소
    if (removed.notifId != null) {
      await _NotificationService.I.cancel(removed.notifId!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('삭제했어요'),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () async {
            setState(() => _all.insert(idx, removed));
            await _save();
            // 알림 되살리기
            if (removed.remind && removed.due != null && removed.due!.isAfter(DateTime.now()) && !removed.done) {
              final nid = await _NotificationService.I.scheduleAt(
                title: removed.title,
                body: removed.note.isEmpty ? '할 일이 있어요' : removed.note,
                when: removed.due!,
                notifId: removed.notifId,
              );
              setState(() => _all[idx] = _all[idx].copyWith(notifId: nid));
              await _save();
            }
          },
        ),
      ),
    );
  }

  /* --------- 빌드 --------- */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _visible;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            children: [
              // 상단 바: 타이틀 + 스위치
              Row(
                children: [
                  Text('할 일', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Row(
                    children: [
                      Text('완료 보기', style: TextStyle(color: cs.onSurfaceVariant)),
                      Switch(
                        value: _showDone,
                        onChanged: (v) => setState(() => _showDone = v),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 리스트
              Expanded(
                child: items.isEmpty
                    ? _EmptySchedule(onAdd: _add)
                    : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final e = items[i];
                    final dueStr = e.due != null ? _df.format(e.due!) : null;
                    final isOverdue = e.due != null && e.due!.isBefore(DateTime.now()) && !e.done;

                    return Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Colors.redAccent,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _delete(e);
                        return false; // 내부에서 처리
                      },
                      child: InkWell(
                        onTap: () => _toggleDone(e),
                        onLongPress: () => _edit(e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: e.done,
                                onChanged: (_) => _toggleDone(e),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        decoration: e.done ? TextDecoration.lineThrough : null,
                                        color: e.done ? cs.onSurfaceVariant : cs.onSurface,
                                      ),
                                    ),
                                    if (e.note.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        e.note,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: cs.onSurfaceVariant,
                                          decoration: e.done ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                    if (dueStr != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: isOverdue ? Colors.redAccent : cs.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            dueStr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isOverdue ? Colors.redAccent : cs.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (e.remind) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.notifications_active, size: 16, color: cs.primary),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '편집',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _edit(e),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 추가 버튼
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.extended(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('할 일 추가'),
          ),
        ),
      ],
    );
  }
}

/* ===================== 빈 상태 ===================== */

class _EmptySchedule extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySchedule({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          const Text('아직 할 일이 없어요.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('할 일 추가'),
          ),
        ],
      ),
    );
  }
}

/* ===================== 추가/편집 바텀시트 ===================== */

class _EditTodoSheet extends StatefulWidget {
  final TodoItem? existing;
  const _EditTodoSheet({this.existing});

  @override
  State<_EditTodoSheet> createState() => _EditTodoSheetState();
}

class _EditTodoSheetState extends State<_EditTodoSheet> {
  final _titleC = TextEditingController();
  final _noteC = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _due;
  bool _remind = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleC.text = e.title;
      _noteC.text = e.note;
      _due = e.due;
      _remind = e.remind;
      _done = e.done;
    }
  }

  @override
  void dispose() {
    _titleC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 2);

    final date = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (date == null) return;

    final timeOfDay = await showTimePicker(
      context: context,
      initialTime: _due != null
          ? TimeOfDay(hour: _due!.hour, minute: _due!.minute)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    final time = timeOfDay ?? const TimeOfDay(hour: 9, minute: 0);

    setState(() {
      _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final base = widget.existing;
    final now = DateTime.now();

    final item = TodoItem(
      id: base?.id ?? UniqueKey().toString(),
      title: _titleC.text.trim(),
      note: _noteC.text.trim(),
      due: _due,
      remind: _remind && _due != null,
      done: _done,
      notifId: base?.notifId, // 실제 예약은 상위에서 수행
      createdAt: base?.createdAt ?? now,
    );

    Navigator.of(context).pop<TodoItem>(item);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + insets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? '할 일 추가' : '할 일 편집',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _titleC,
              decoration: const InputDecoration(
                labelText: '할 일',
                prefixIcon: Icon(Icons.task_alt_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '할 일을 입력해 주세요' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _noteC,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '마감(알림) 시간',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Row(
                        children: [
                          Text(_due == null ? '설정 안 함' : df.format(_due!)),
                          const Spacer(),
                          const Icon(Icons.edit_calendar_outlined),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
              title: const Text('해당 시간에 알림 받기'),
              subtitle: Text(_due == null ? '마감 시간을 먼저 설정하세요' : '앱이 백그라운드여도 울립니다'),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: cs.primary,
            ),

            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _done,
                onChanged: (v) => setState(() => _done = v ?? false),
                title: const Text('완료로 표시'),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    onPressed: _submit,
                    label: const Text('저장'),
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
