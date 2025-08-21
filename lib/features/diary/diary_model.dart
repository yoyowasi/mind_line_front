class DiaryEntry {
  // DiaryEntity의 필드와 일치하도록 수정
  final String id;
  final String uid;
  final String date;
  final String content; // 'text'에서 'content'로 변경
  final String mood;    // 'emotion'에서 'mood'로 변경 (enum을 String으로 처리)
  final String? aiReply; // nullable로 추가
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

  // 서버 응답(JSON)을 DiaryEntry 객체로 변환하는 로직
  // 백엔드 DiaryEntity의 필드명('content', 'mood' 등)과 정확히 일치해야 합니다.
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      // MongoDB의 ObjectId는 id 필드 안에 $oid 값으로 들어오는 경우가 많으므로
      // 안전하게 처리합니다.
      id: (json['id'] is Map) ? json['id']['\$oid'] ?? '' : json['id'],
      uid: json['uid'],
      date: json['date'],
      content: json['content'], // 'text' -> 'content'
      mood: json['mood'],       // 'emotion' -> 'mood'
      aiReply: json['aiReply'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  // DiaryEntry를 다시 UI에서 사용할 때 기존 'text'와 'emotion' 속성을
  // 그대로 사용할 수 있도록 getter를 추가해줍니다. (호환성 유지)
  String get text => content;
  String get emotion => mood;
  // confidence는 이제 서버에 없으므로 기본값을 반환하거나 UI에서 사용하지 않도록 처리합니다.
  double get confidence => 1.0;
}