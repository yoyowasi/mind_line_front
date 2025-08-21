import 'package:flutter/material.dart';
import '../core/tabs_registry.dart';        // kAllTabs

class AppDrawer extends StatelessWidget {
  final List<String> enabledIds;
  final void Function(String id)? onSelectTabId;
  final Future<void> Function()? onTabsReload;
  final Future<void> Function() onLogout; // ✅ 추가


  const AppDrawer({
    super.key,
    required this.enabledIds,
    this.onSelectTabId,
    this.onTabsReload,
    required this.onLogout, // ✅ 추가
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
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () async {
                Navigator.of(context).pop(); // Drawer 먼저 닫고
                await onLogout();            // 실제 로그아웃 실행
              },
            ),

          ],
        ),
      ),
    );
  }
}