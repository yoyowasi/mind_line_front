class DiaryEntry {
  final String id;
  final String uid;
  final String date;
  final String content;
  final String mood;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiaryEntry({
    required this.id,
    required this.uid,
    required this.date,
    required this.content,
    required this.mood,
    this.createdAt,
    this.updatedAt,
  });

  // ✅ 백엔드가 반환하는 새로운 JSON 형식에 맞게 수정
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? '',
      uid: json['uid'] ?? 'unknown_uid',
      date: json['date'] ?? '',
      content: json['content'] ?? '내용 없음',
      mood: json['mood'] ?? 'NEUTRAL',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  // UI 호환성을 위한 getter
  String get text => content;
  String get emotion => mood;
}