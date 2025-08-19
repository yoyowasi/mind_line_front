import 'package:flutter/material.dart';
import '../layout/app_scaffold.dart';
import '../core/tabs_registry.dart';        // kAllTabs
import '../core/tabs_reload_scope.dart';   // 저장 콜백 전역 주입 (선택)

class AppDrawer extends StatelessWidget {
  final List<String> enabledIds;
  final void Function(String id)? onSelectTabId;
  final Future<void> Function()? onTabsReload;

  const AppDrawer({
    super.key,
    required this.enabledIds,
    this.onSelectTabId,
    this.onTabsReload,
  });

  @override
  Widget build(BuildContext context) {
    const idsInMenu = ['chat','calendar','diary','analytics','expense','schedule','settings'];

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            const DrawerHeader(child: Text('DailyCircle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            for (final id in idsInMenu)
              ListTile(
                leading: Icon(kAllTabs[id]!.icon),
                title: Text(kAllTabs[id]!.label),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelectTabId?.call(id); // ✅ 항상 ID로 Home에 전환 요청
                },
                // (원하면) 비활성 탭은 아이콘을 살짝 옅게
                iconColor: enabledIds.contains(id) ? null : Colors.grey,
                textColor: enabledIds.contains(id) ? null : Colors.grey,
              ),
          ],
        ),
      ),
    );
  }
}