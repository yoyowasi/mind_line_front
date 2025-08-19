import 'package:flutter/widgets.dart';

class TabsReloadScope extends InheritedWidget {
  final Future<void> Function()? onTabsReload;

  const TabsReloadScope({
    super.key,
    required super.child,
    this.onTabsReload,
  });

  static TabsReloadScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabsReloadScope>();
  }

  @override
  bool updateShouldNotify(TabsReloadScope oldWidget) {
    return onTabsReload != oldWidget.onTabsReload;
  }
}
