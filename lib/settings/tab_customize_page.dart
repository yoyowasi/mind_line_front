import 'package:flutter/material.dart';
import '../core/models/tab_config.dart';
import '../core/services/tab_prefs_service.dart';
import '../core/tabs_registry.dart';


class TabCustomizePage extends StatefulWidget {
  const TabCustomizePage({super.key, this.onSaved});
  final Future<void> Function()? onSaved;

  @override
  State<TabCustomizePage> createState() => _TabCustomizePageState();
}

class _TabCustomizePageState extends State<TabCustomizePage> {
  late Future<TabConfig> _future;
  bool _initialized = false;
  bool _dirty = false;
  late List<String> _enabled; // ordered

  @override
  void initState() {
    super.initState();
    _future = TabPrefsService.load();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    await TabPrefsService.save(TabConfig(enabled: _enabled));
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _initialized = true;
    });

    await widget.onSaved?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('탭 구성이 저장되었습니다.')),
    );

  }

  Future<void> _reset() async {
    final def = await TabPrefsService.reset();
    setState(() {
      _enabled = [...def.enabled];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TabConfig>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('탭 편집')),
            body: const Center(child: Text('탭 구성을 불러오지 못했습니다.')),
          );
        }

        if (!_initialized) {
          // initialize from saved config, keep only known tabs, unique, preserve order
          final seen = <String>{};
          final known = kAllTabs.keys.toSet();
          final fromSaved = <String>[];
          for (final id in snap.data!.enabled) {
            if (known.contains(id) && !seen.contains(id)) {
              seen.add(id);
              fromSaved.add(id);
            }
          }
          // If empty, use default
          // _enabled = fromSaved.isEmpty ? [...TabConfig.kDefault.enabled] : fromSaved;
           _enabled = fromSaved;

          _initialized = true;
        }

        final allIds = kAllTabs.keys.toList();
        final disabled = allIds.where((id) => !_enabled.contains(id)).toList(growable: false);

        return Scaffold(
          appBar: AppBar(
            title: const Text('탭 편집'),
            actions: [
              IconButton(
                onPressed: _dirty ? _save : null,
                icon: const Icon(Icons.save),
                tooltip: '저장',
              ),
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.restore),
                tooltip: '기본값으로',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 설명
              const Text('활성 탭 (상단 4개가 하단 탭으로 표시됩니다)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _enabled.removeAt(oldIndex);
                    _enabled.insert(newIndex, item);
                    _markDirty();
                  });
                },
                children: [
                  for (final id in _enabled)
                    ListTile(
                      key: ValueKey('enabled_$id'),
                      leading: Icon(kAllTabs[id]!.icon),
                      title: Text(kAllTabs[id]!.label),
                      subtitle: Text(_enabled.indexOf(id) < TabConfig.bottomBaseCount
                          ? '하단 탭에 표시됨'
                          : '스와이프로 접근'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            _enabled.remove(id);
                            _markDirty();
                          });
                        },
                        tooltip: '비활성화',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text('비활성 탭', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (disabled.isEmpty)
                const Text('비활성 탭이 없습니다.'),
              for (final id in disabled)
                ListTile(
                  leading: Icon(kAllTabs[id]!.icon),
                  title: Text(kAllTabs[id]!.label),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() {
                        _enabled.add(id); // 마지막에 추가 → 스와이프로 접근 (원하면 위로 드래그)
                        _markDirty();
                      });
                    },
                    tooltip: '활성화',
                  ),
                ),
              const SizedBox(height: 24),
              if (_dirty)
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('변경 사항 저장'),
                ),
            ],
          ),
        );
      },
    );
  }
}