// lib/core/services/tab_prefs_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tab_config.dart';

class TabPrefsService {
  static const _keyV2 = 'user_tabs_config_v2';
  static const _keyV1 = 'user_tabs_config_v1'; // for migration

  // 중복 제거 + 순서 유지
  static List<String> _dedupe(List<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final id in ids) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  /// V2가 있으면 (비어있어도) 그대로 존중.
  /// V1만 있으면 마이그레이션.
  /// 둘 다 없으면 최초 실행으로 보고 기본값(4개) 저장 후 반환.
  static Future<TabConfig> load() async {
    final sp = await SharedPreferences.getInstance();

    // 1) V2 우선
    final v2 = sp.getString(_keyV2);
    if (v2 != null) {
      try {
        final cfg = TabConfig.fromJson(v2);
        return cfg; // ✅ 비어있어도 그대로 반환
      } catch (_) {
        // 손상되면 아래로
      }
    }

    // 2) V1 → V2 마이그레이션
    final v1 = sp.getString(_keyV1);
    if (v1 != null) {
      try {
        final map = jsonDecode(v1) as Map<String, dynamic>;
        final pinned = (map['pinned'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        final extras = (map['extras'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];

        final enabled = _dedupe([...pinned, ...extras]);

        // V1이 비어 있었다면 최초상태로 보고 기본값(4개)
        final migrated = TabConfig(
          enabled: enabled.isEmpty ? TabConfig.kDefault.enabled : enabled,
        );

        await save(migrated);
        // ✅ 재마이그레이션 방지
        await sp.remove(_keyV1);

        return migrated;
      } catch (_) {
        // 손상되면 아래로
      }
    }

    // 3) 둘 다 없음 → 최초 실행: 기본 4개로 저장
    await save(TabConfig.kDefault);
    return TabConfig.kDefault;
  }

  static Future<void> save(TabConfig config) async {
    final sp = await SharedPreferences.getInstance();
    final deduped = _dedupe(config.enabled);
    await sp.setString(_keyV2, TabConfig(enabled: deduped).toJson());
  }

  /// 편의: enabled 배열만 저장
  static Future<void> setEnabled(List<String> enabled) async {
    await save(TabConfig(enabled: enabled));
  }

  static Future<TabConfig> reset() async {
    await save(TabConfig.kDefault);   // 기본 4개로 초기화
    return TabConfig.kDefault;
  }
}
