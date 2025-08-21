class DiaryEntry {
  final String id;
  final String uid;
  final String date;
  final String content;
  final String mood;
  final String? aiReply;
  final DateTime createdAt;

  DiaryEntry({
    required this.id,
    required this.uid,
    required this.date,
    required this.content,
    required this.mood,
    this.aiReply,
    required this.createdAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: _parseId(json['id']),
      uid: json['uid']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      mood: json['mood']?.toString() ?? 'NEUTRAL',
      aiReply: json['aiReply'],
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  static String _parseId(dynamic id) {
    if (id is Map) {
      // MongoDB ObjectId의 경우 '$oid' 키를 사용
      return id['\$oid']?.toString() ?? '';
    }
    return id?.toString() ?? '';
  }

  static DateTime _parseDateTime(dynamic dateTime) {
    if (dateTime == null) return DateTime.now();
    
    try {
      if (dateTime is String) {
        return DateTime.parse(dateTime);
      } else if (dateTime is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateTime);
      }
    } catch (e) {
      // 파싱 실패 시 현재 시간 반환
      print('DateTime 파싱 실패: $e');
    }
    
    return DateTime.now();
  }

  // UI 호환성을 위한 getter
  String get text => content;
  String get emotion => mood;
  double get confidence => 1.0; // confidence 필드는 더 이상 사용하지 않음
}