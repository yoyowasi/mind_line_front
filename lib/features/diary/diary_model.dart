class DiaryEntry {
  final String id;
  final String text;
  final String emotion;
  final double confidence;
  final DateTime createdAt;

  DiaryEntry({
    required this.id,
    required this.text,
    required this.emotion,
    required this.confidence,
    required this.createdAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'],
    text: json['text'],
    emotion: json['emotion'],
    confidence: json['confidence'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}
