import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tab_config.dart';

class TabPrefsService {
  static const _keyV2 = 'user_tabs_config_v2';
  static const _keyV1 = 'user_tabs_config_v1'; // for migration

  /// Load user's tab configuration.
  /// Supports migration from V1 (pinned+extras) to V2 (enabled list).
  static Future<TabConfig> load() async {
    final sp = await SharedPreferences.getInstance();

    // Try V2 first
    final v2 = sp.getString(_keyV2);
    if (v2 != null) {
      try {
        final cfg = TabConfig.fromJson(v2);
        if (cfg.enabled.isNotEmpty) return cfg;
      } catch (_) {}
    }

    // Migrate from V1 if present
    final v1 = sp.getString(_keyV1);
    if (v1 != null) {
      try {
        final map = jsonDecode(v1) as Map<String, dynamic>;
        final pinned = (map['pinned'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        final extras = (map['extras'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        final enabled = <String>[...pinned];
        for (final e in extras) {
          if (!enabled.contains(e)) enabled.add(e);
        }
        final migrated = TabConfig(enabled: enabled.isEmpty ? TabConfig.kDefault.enabled : enabled);
        await save(migrated);
        return migrated;
      } catch (_) {}
    }

    // Fallback to default
    await save(TabConfig.kDefault);
    return TabConfig.kDefault;
  }

  static Future<void> save(TabConfig config) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyV2, config.toJson());
  }

  static Future<TabConfig> reset() async {
    await save(TabConfig.kDefault);   // ✅ 그냥 기본값 통째로 저장
    return TabConfig.kDefault;
  }
}