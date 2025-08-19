import 'package:flutter/material.dart';
import '../core/models/tab_config.dart';

// Import your tab pages (adjust paths if needed)
import '../tabs/analytics_tab.dart';
import '../tabs/calendar_tab.dart';
import '../tabs/diary_tab.dart';
import '../tabs/expense_tab.dart' as tabs_expense; // avoid clash with widgets/expense_tab
import '../tabs/schedule_tab.dart';
import '../tabs/settings_tab.dart';

// Widgets in widgets/
import '../widgets/chat_tab.dart' as widgets_chat;
import '../widgets/expense_tab.dart' as widgets_expense;
import '../widgets/daliy_tab.dart' as widgets_diary;
import '../widgets/schedule_tab.dart' as widgets_schedule;

class TabDefinition {
  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const TabDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });
}

/// NOTE: schedule/expense mapping may be swapped in your project; adjust below if needed.
final Map<String, TabDefinition> kAllTabs = {
  'chat': TabDefinition(
    id: 'chat',
    label: '채팅',
    icon: Icons.chat_bubble_outline,
    builder: (ctx) => const widgets_chat.ChatTab(key: PageStorageKey('chat-tab')),
  ),
  'schedule': TabDefinition(
    id: 'schedule',
    label: '내 일정',
    icon: Icons.calendar_month,
    builder: (ctx) => const widgets_expense.ExpenseTab(),
  ),
  'expense': TabDefinition(
    id: 'expense',
    label: '지출내역',
    icon: Icons.attach_money,
    builder: (ctx) => const widgets_schedule.ScheduleTab(),
  ),
  'diary': TabDefinition(
    id: 'diary',
    label: '일기 보기',
    icon: Icons.book_outlined,
    builder: (ctx) => const widgets_diary.DaliyTab(),
  ),
  'calendar': TabDefinition(
    id: 'calendar',
    label: '달력',
    icon: Icons.calendar_today,
    builder: (ctx) => const CalendarTab(),
  ),
  'analytics': TabDefinition(
    id: 'analytics',
    label: '분석',
    icon: Icons.pie_chart_outline,
    builder: (ctx) => const AnalyticsTab(),
  ),
  'settings': TabDefinition(
    id: 'settings',
    label: '설정',
    icon: Icons.settings_outlined,
    builder: (ctx) => const SettingsTab(),
  ),
};

List<BottomNavigationBarItem> buildBottomItemsFromEnabled(List<String> enabled) {
  final ids = enabled.take(TabConfig.bottomBaseCount);
  return ids.map((id) {
    final def = kAllTabs[id]!;
    return BottomNavigationBarItem(icon: Icon(def.icon), label: def.label);
  }).toList(growable: false);
}

List<Widget> buildPagesFromEnabled(BuildContext context, List<String> enabled) {
  return enabled.map((id) => kAllTabs[id]!.builder(context)).toList(growable: false);
}