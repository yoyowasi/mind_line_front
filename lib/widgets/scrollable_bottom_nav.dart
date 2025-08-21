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
    _scroll.dispose();
    super.dispose();
  }

  // ✅ 탭 1~3개: 전폭/탭수, 4개: 전폭/4, 5개~: 전폭/4 + 스크롤
  double _itemWidth(BuildContext context) {
    final count = widget.enabledIds.length;
    final slots = count < 4 ? count : 4;
    final width = MediaQuery.of(context).size.width;
    return slots == 0 ? width : width / slots;
  }

  bool get _needsScroll => widget.enabledIds.length > 4;

  void _ensureVisible(int i, double itemWidth) {
    if (!_scroll.hasClients || !_needsScroll) return; // ✅ 5개 이상일 때만 스크롤 보정
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
    if (oldWidget.currentIndex != widget.currentIndex && widget.currentIndex >= 0 && _needsScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureVisible(widget.currentIndex, _itemWidth(context));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.currentIndex >= 0 && _needsScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureVisible(widget.currentIndex, _itemWidth(context));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enabledIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final themeColor = Theme.of(context).colorScheme.primary;
    final itemWidth = _itemWidth(context);
    final noneSelected = widget.currentIndex < 0;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: _needsScroll ? null : const NeverScrollableScrollPhysics(), // ✅ 4개 이하면 스크롤 OFF
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
                  width: itemWidth, // ✅ 가변 폭
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(def.icon, color: color, size: selected ? 24 : 22),
                            const SizedBox(width: 6),
                            Flexible( // ✅ 라벨 길어도 줄바꿈/흘러넘침 방지
                              child: Text(
                                def.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: color,
                                ),
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
