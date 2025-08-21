import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../widgets/app_drawer.dart';

// 동적 탭 구성
import '../core/models/tab_config.dart';
import '../core/services/tab_prefs_service.dart';
import '../core/tabs_registry.dart';
import '../widgets/scrollable_bottom_nav.dart';
import '../../core/tabs_reload_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late PageController _pageController;

  bool _loading = true;
  int _currentIndex = 0;          // PageView의 현재 페이지 인덱스(소스 오브 트루스)
  List<String> _enabled = [];     // 사용자 설정에서 온 탭 ID 순서
  User? _user;
  String? _ephemeralId;           // 활성 탭에 없지만 임시로 붙인 ID
  String? _anchorTabId;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _pageController = PageController(initialPage: 0);
    _reloadTabs(); // 최초 로드
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 임시 탭 포함한 PageView용 ID들
  List<String> get _viewIds {
    if (_ephemeralId != null && !_enabled.contains(_ephemeralId)) {
      return [..._enabled, _ephemeralId!];
    }
    return _enabled;
  }

  int _currentPageSafeIndex() {
    final ids = _viewIds;
    final max = ids.isEmpty ? 0 : ids.length - 1;
    return _currentIndex.clamp(0, max);
  }

  Future<void> _reloadTabs() async {
    // 0) 리로드 직전, '지금 보고 있는 탭 ID'(임시탭 포함)를 기억
    final beforeIds = _viewIds;
    final currentId = (beforeIds.isNotEmpty && _currentIndex < beforeIds.length)
        ? beforeIds[_currentIndex]
        : null;

    // 1) 저장된 설정 로드 (비어있어도 그대로 존중)
    final cfg = await TabPrefsService.load();
    if (!mounted) return;
    final newEnabled = [...cfg.enabled];

    // 2) 다음 페이지/임시탭 계산
    int nextIndex = 0;
    String? nextEphemeral;

    if (currentId != null) {
      final found = newEnabled.indexOf(currentId);
      if (found >= 0) {
        // 같은 탭이 여전히 enabled면 그 인덱스로 복귀
        nextIndex = found;
      } else {
        // enabled에 없으면 임시탭으로 끝에 붙여서 '지금 화면' 유지
        nextEphemeral = currentId;
        nextIndex = newEnabled.length;
      }
    } else {
      // currentId가 없을 때는 기존 인덱스 보정
      nextIndex = (_currentIndex >= newEnabled.length) ? 0 : _currentIndex;
    }

    // 3) 컨트롤러 교체 (화면/하이라이트 싱크를 확실히 맞춤)
    final old = _pageController;
    final newController = PageController(initialPage: nextIndex);

    setState(() {
      _enabled = newEnabled;
      _ephemeralId = nextEphemeral;
      _currentIndex = nextIndex;
      _pageController = newController;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }





  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  void _rememberAnchor() {
    if (_enabled.isNotEmpty && _currentIndex < _enabled.length) {
      _anchorTabId = _enabled[_currentIndex]; // 지금 보고 있는 '활성 탭' 기억
    } else if (_enabled.isNotEmpty) {
      _anchorTabId = _enabled.first;          // 안전장치
    } else {
      _anchorTabId = null;                    // 탭 0개면 앵커 없음
    }
  }

  // 사이드바에서 ID로 선택
  void _selectById(String id) {
    _rememberAnchor();
    final inEnabled = _enabled.indexOf(id);

    if (inEnabled >= 0) {
      // 임시탭이 붙은 상태에서 활성 탭으로 이동 시 컨트롤러 재생성하여 점프 이슈 차단
      final hadEphemeral = _ephemeralId != null;

      if (hadEphemeral) {
        final old = _pageController;
        final newController = PageController(initialPage: inEnabled);
        setState(() {
          _ephemeralId = null;
          _currentIndex = inEnabled;
          _pageController = newController;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      } else {
        setState(() => _currentIndex = inEnabled);
        _pageController.animateToPage(
          inEnabled,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    // 비활성 탭 → 임시탭으로 끝에 붙여서 즉시 이동
    final targetIndex = _enabled.length;
    final old = _pageController;
    final newController = PageController(initialPage: targetIndex);

    setState(() {
      _ephemeralId = id;
      _currentIndex = targetIndex;
      _pageController = newController;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  // (인덱스로도 이동 가능)
  void _selectByIndex(int index) {
    if (_enabled.isEmpty) return; // ✅ 0개일 때 보호
    final i = index.clamp(0, _enabled.length - 1);
    _goToIndex(i);
  }

  void _goToIndex(int i) {
    Navigator.maybePop(context); // Drawer 닫기

    if (_ephemeralId != null) {
      // 임시탭이 붙어있는 상태라면: 컨트롤러 교체 + 임시탭 제거를 한 번에
      final old = _pageController;
      final newController = PageController(initialPage: i);

      setState(() {
        _ephemeralId = null;   // 임시탭 정리
        _currentIndex = i;
        _pageController = newController; // 컨트롤러 교체(핵심)
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    } else {
      // 임시탭이 없을 때는 기존처럼 부드럽게 애니메이션
      setState(() {
        _currentIndex = i;
      });
      _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }


  // 항상 스크롤 가능한 하단바 사용
  Widget _buildBottomBar() {
    if (_enabled.isEmpty) return const SizedBox.shrink();

    // 임시탭(마지막 인덱스)일 때는 하단바에 항목이 없으므로 -1 전달
    final barIndex = (_currentIndex >= _enabled.length) ? -1 : _currentIndex;

    return ScrollableBottomNav(
      enabledIds: _enabled,
      currentIndex: barIndex,     // 임시탭이면 -1
      onTap: (idx) => _goToIndex(idx),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 임시탭 포함한 실제 PageView 타겟
    final idsForView = _viewIds;

    // ✅ 탭이 0개일 때: 크래시 방지 + 안내 화면
    if (idsForView.isEmpty) {
      return TabsReloadScope(
        onTabsReload: _reloadTabs,
        child: Scaffold(
          appBar: AppBar(title: const Text('DailyCircle')),
          drawer: AppDrawer(
            enabledIds: _enabled,
            onSelectTabId: _selectById,
            onTabsReload: _reloadTabs,
            onLogout: _logout, // ✅ 추가
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tab_unselected, size: 48),
                const SizedBox(height: 12),
                const Text(
                  '선택된 탭이 없어요.\n사이드 메뉴에서 탭을 추가해 주세요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Drawer 여는 버튼은 Builder로 context 분리해서 안전하게 호출
                Builder(
                  builder: (ctx) => FilledButton(
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    child: const Text('탭 추가하기'),
                  ),
                ),
              ],
            ),
          ),
          // 하단바 없음
        ),
      );
    }

    // ✅ 탭이 하나 이상일 때: 기존 흐름
    final safeIndex = _currentPageSafeIndex();
    final title = kAllTabs[idsForView[safeIndex]]!.label;

    return TabsReloadScope(
      onTabsReload: _reloadTabs,
      child: Scaffold(
        appBar: AppBar(title: Text('DailyCircle - $title')),
        drawer: AppDrawer(
          enabledIds: _enabled,
          onSelectTabId: _selectById,
          onTabsReload: _reloadTabs,
          onLogout: _logout, // ✅ 추가
        ),
        body: SafeArea(
          child: PageView(
            key: ValueKey('pv:${idsForView.join("|")}'),
            controller: _pageController,
            onPageChanged: (i) {
              setState(() {
                _currentIndex = i;
                if (_ephemeralId != null && i < _enabled.length) {
                  _ephemeralId = null;
                }
              });
            },
            children: [
              for (final id in idsForView)
                KeyedSubtree(
                  key: ValueKey('page-$id'),
                  child: kAllTabs[id]!.builder(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
