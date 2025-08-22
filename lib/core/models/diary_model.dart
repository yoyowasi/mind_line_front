class DiaryEntry {
  final String? id;
  final String uid;
  final DateTime date;        // 서버 LocalDate -> DateTime(자정)
  final String? content;      // 본문
  final String? legacyText;   // 예전 필드
  final String? mood;         // VERY_BAD/BAD/NEUTRAL/GOOD/VERY_GOOD
  final String? aiReply;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiaryEntry({
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

  factory DiaryEntry.fromJson(Map<String, dynamic> j) {
    // 서버 date= "yyyy-MM-dd"
    final d = DateTime.parse(j['date'] as String);
    final date = DateTime(d.year, d.month, d.day);

    DateTime? _dt(String? s) => (s == null) ? null : DateTime.parse(s);

    return DiaryEntry(
      id: j['id'] as String?,
      uid: j['uid'] as String? ?? '',
      date: date,
      content: j['content'] as String?,
      legacyText: j['legacyText'] as String?,
      mood: j['mood'] as String?,       // 예: "GOOD"
      aiReply: j['aiReply'] as String?,
      createdAt: _dt(j['createdAt']?.toString()),
      updatedAt: _dt(j['updatedAt']?.toString()),
    );
  }
}
