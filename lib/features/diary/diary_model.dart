// lib/features/diary/diary_model.dart
class DiaryEntry {
  final String? id;
  final String uid;
  final DateTime date;
  final String? content;
  final String? legacyText;
  final String? mood; // enum name as String
  final String? aiReply;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DiaryEntry({
    this.id,
    required this.uid,
    required this.date,
    this.content,
    this.legacyText,
    this.mood,
    this.aiReply,
    this.createdAt,
    this.updatedAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final d = DateTime.parse(json['date'] as String);
    return DiaryEntry(
      id: json['id'] as String?,
      uid: json['uid'] as String? ?? '',
      date: DateTime(d.year, d.month, d.day), // ⬅️ 자정으로 고정
      content: json['content'] as String?,
      legacyText: json['legacyText'] as String?,
      mood: json['mood'] as String?,
      aiReply: json['aiReply'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      "date": date.toIso8601String().split('T').first,
      if (content != null) "content": content,
      if (legacyText != null) "legacyText": legacyText,
      // mood는 서버에서 enum 문자열을 기대: e.g., "HAPPY"
      if (mood != null) "mood": mood,
    };
  }

  String get text => content ?? legacyText ?? '';

  Map<String, dynamic> toJson() => {
        "id": id,
        "uid": uid,
        "date": date.toIso8601String().split('T').first,
        "content": content,
      "legacyText": legacyText,
       "mood": mood,
        "aiReply": aiReply,
        "createdAt": createdAt?.toIso8601String(),
        "updatedAt": updatedAt?.toIso8601String(),
    };
}
