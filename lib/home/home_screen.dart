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
    final cfg = await TabPrefsService.load();
    if (!mounted) return;

    final newEnabled = [...cfg.enabled];
    if (newEnabled.isEmpty) newEnabled.addAll(TabConfig.kDefault.enabled);

    int nextIndex = _currentIndex;
    if (nextIndex >= newEnabled.length) nextIndex = 0;

    // 🔧 핵심: 리로드할 때도 컨트롤러 새로 생성
    final old = _pageController;
    final newController = PageController(initialPage: nextIndex);

    setState(() {
      _enabled = newEnabled;
      _ephemeralId = null;      // 임시탭 정리
      _currentIndex = nextIndex;
      _pageController = newController;  // 컨트롤러 교체
      _loading = false;
    });

    // 이전 컨트롤러는 다음 프레임에 안전하게 폐기
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }


  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  // 사이드바에서 ID로 선택
  void _selectById(String id) {
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

    // 타이틀도 _viewIds 기준(임시 탭 포함)
    final idsForView = _viewIds;
    final safeIndex = _currentPageSafeIndex();
    final title = kAllTabs[idsForView[safeIndex]]!.label;

    return TabsReloadScope(
      onTabsReload: _reloadTabs,
      child: Scaffold(
        appBar: AppBar(
          title: Text('DailyCircle - $title'),
          // 배경/글자색은 Theme(AppTheme)에서 제어 (다크/라이트 대응)
        ),

        drawer: AppDrawer(
          enabledIds: _enabled,
          onSelectTabId: _selectById,
          onTabsReload: _reloadTabs,
        ),

        body: SafeArea(
          child: PageView(
            key: ValueKey('pv:${_viewIds.join("|")}'), // child 목록 바뀌면 재구성
            controller: _pageController,
            onPageChanged: (i) {
              setState(() {
                _currentIndex = i;
                // 임시 탭에서 활성 탭(앞쪽)으로 이동하면 임시 탭 제거
                if (_ephemeralId != null && i < _enabled.length) {
                  _ephemeralId = null;
                }
              });
            },
            // 각 페이지에도 키 부여
            children: [
              for (final id in _viewIds)
                KeyedSubtree(
                  key: ValueKey('page-$id'),
                  child: kAllTabs[id]!.builder(context),
                ),
            ],
          ),
        ),

        bottomNavigationBar: _buildBottomBar(),
        floatingActionButton: IconButton( // 로그아웃은 액션 버튼으로 유지
          icon: const Icon(Icons.logout),
          onPressed: _logout,
          tooltip: '로그아웃',
        ),
      ),
    );
  }
}
