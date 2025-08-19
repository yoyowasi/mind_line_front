import 'dart:convert';

/// V2: single ordered list of enabled tab IDs.
/// The BottomNavigationBar always shows the first 4 of this list.
class TabConfig {
  final List<String> enabled; // ordered

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

  /// Default order: 4 base + a few more.
  static const TabConfig kDefault = TabConfig(
    enabled: ['chat', 'schedule', 'expense', 'diary', 'calendar', 'analytics', 'settings'],
  );
}