import 'package:flutter/material.dart';
import '../settings/tab_customize_page.dart';
import '../../core/tabs_reload_scope.dart';
import '../../core/services/theme_service.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, this.onTabsReload});
  final Future<void> Function()? onTabsReload;

  @override
  Widget build(BuildContext context) {
    final reload = onTabsReload ?? TabsReloadScope.of(context)?.onTabsReload;
    final themeSvc = ThemeService.instance;

    return Scaffold(
      backgroundColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withAlpha(15),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '설정',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ✅ 테마 설정 (라이트/다크/시스템)
            AnimatedBuilder(
              animation: themeSvc,
              builder: (context, _) {
                final subtitle = switch (themeSvc.mode) {
                  ThemeMode.light => '라이트',
                  ThemeMode.dark => '다크',
                  _ => '시스템 기본',
                };
                return ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('테마'),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton<ThemeMode>(
                    icon: const Icon(Icons.tune),
                    onSelected: (m) => themeSvc.set(m),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: ThemeMode.system,
                        child: Text('시스템 기본'),
                      ),
                      PopupMenuItem(
                        value: ThemeMode.light,
                        child: Text('라이트'),
                      ),
                      PopupMenuItem(
                        value: ThemeMode.dark,
                        child: Text('다크'),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 32),

            // 탭 편집
            ListTile(
              leading: const Icon(Icons.view_week_outlined),
              title: const Text('탭 편집'),
              subtitle: const Text('하단 탭 순서/추가 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => TabCustomizePage(onSaved: reload),
                  ),
                );
                if (changed == true) {
                  await reload?.call();
                }
              },
            ),

            // (예시) 다른 설정들
            const ListTile(leading: Icon(Icons.person), title: Text('계정 관리')),
            const ListTile(
                leading: Icon(Icons.notifications),
                title: Text('알림 설정')),
          ],
        ),
      ),
    );
  }
}
