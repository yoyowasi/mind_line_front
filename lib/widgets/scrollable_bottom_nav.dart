import 'package:flutter/material.dart';
import '../core/tabs_registry.dart';

class ScrollableBottomNav extends StatefulWidget {
  final List<String> enabledIds;      // 모든 탭 ID (순서대로)
  final int currentIndex;             // 현재 선택 인덱스
  final ValueChanged<int> onTap;      // 탭 클릭 시 이동

  const ScrollableBottomNav({
    super.key,
    required this.enabledIds,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<ScrollableBottomNav> createState() => _ScrollableBottomNavState();
}

class _ScrollableBottomNavState extends State<ScrollableBottomNav> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();                      // ✅ 누수 방지
    super.dispose();
  }

  void _ensureVisible(int i, double itemWidth) {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final targetLeft = i * itemWidth;
    final targetRight = targetLeft + itemWidth;
    final current = _scroll.offset;
    double next = current;
    if (targetLeft < current) next = targetLeft;
    else if (targetRight > current + viewport) next = targetRight - viewport;
    next = next.clamp(0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(next, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant ScrollableBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ 선택 없음(-1)일 때는 스크롤 맞추지 않음
    if (oldWidget.currentIndex != widget.currentIndex && widget.currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final w = MediaQuery.of(context).size.width / 4;
        _ensureVisible(widget.currentIndex, w);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final w = MediaQuery.of(context).size.width / 4;
        _ensureVisible(widget.currentIndex, w);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 빈 리스트면 바로 리턴 (드물지만 방어)
    if (widget.enabledIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final themeColor = Theme.of(context).colorScheme.primary;
    final itemWidth = MediaQuery.of(context).size.width / 4;
    final noneSelected = widget.currentIndex < 0;               // ✅ 선택 없음 여부

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemCount: widget.enabledIds.length,
            itemBuilder: (context, i) {
              final id = widget.enabledIds[i];
              final def = kAllTabs[id]!;
              final selected = !noneSelected && i == widget.currentIndex;
              final color = selected ? themeColor : Colors.grey;
              final pillBg = selected ? themeColor.withOpacity(0.10) : Colors.transparent;

              return InkWell(
                onTap: () => widget.onTap(i),
                child: SizedBox(
                  width: itemWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(def.icon, color: color, size: selected ? 24 : 22),
                            const SizedBox(width: 6),
                            Text(
                              def.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 3,
                        width: selected ? 28 : 0,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
