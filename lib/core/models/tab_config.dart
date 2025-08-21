import 'dart:convert';

class TabConfig {
  final List<String> enabled;
  const TabConfig({required this.enabled});

  TabConfig copyWith({List<String>? enabled}) => TabConfig(enabled: enabled ?? this.enabled);

  Map<String, dynamic> toMap() => {'enabled': enabled};
  String toJson() => jsonEncode(toMap());

  static TabConfig fromMap(Map<String, dynamic> map) {
    final list = (map['enabled'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    return TabConfig(enabled: list);
  }

  static TabConfig fromJson(String json) => fromMap(jsonDecode(json) as Map<String, dynamic>);

  static const int bottomBaseCount = 4;

  // ✅ 기본값은 4개
  static const TabConfig kDefault = TabConfig(
    enabled: ['chat', 'schedule', 'expense', 'diary'],
  );
}
