import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _auth = FirebaseAuth.instance;

  // 닉네임
  late final TextEditingController _nameCtrl;

  // 비밀번호 변경
  final _formKeyPwd = GlobalKey<FormState>();
  final _curPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _newPwd2Ctrl = TextEditingController();
  bool _showCur = false;
  bool _showNew = false;
  bool _showNew2 = false;

  bool _savingName = false;
  bool _savingPwd  = false;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _curPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _newPwd2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해 주세요.')),
      );
      return;
    }
    if (name == (user.displayName ?? '')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경된 내용이 없어요.')),
      );
      return;
    }

    setState(() => _savingName = true);
    try {
      await user.updateDisplayName(name);
      await user.reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임이 저장됐어요.')),
      );
      setState(() {}); // 헤더 등 즉시 갱신
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('닉네임 저장 실패: ${e.code}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('닉네임 저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  bool get _isEmailPasswordUser {
    final u = _auth.currentUser;
    if (u == null) return false;
    return u.providerData.any((p) => p.providerId == 'password');
  }

  Future<void> _changePassword() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!_isEmailPasswordUser) return;

    if (!_formKeyPwd.currentState!.validate()) return;

    setState(() => _savingPwd = true);
    try {
      // 1) 재인증
      final email = user.email!;
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _curPwdCtrl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);

      // 2) 비밀번호 변경
      await user.updatePassword(_newPwdCtrl.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경됐어요.')),
      );
      _curPwdCtrl.clear();
      _newPwdCtrl.clear();
      _newPwd2Ctrl.clear();
    } on FirebaseAuthException catch (e) {
      String msg = '비밀번호 변경 실패: ${e.code}';
      if (e.code == 'wrong-password') msg = '현재 비밀번호가 올바르지 않아요.';
      if (e.code == 'weak-password') msg = '새 비밀번호가 너무 약해요.';
      if (e.code == 'requires-recent-login') msg = '보안을 위해 다시 로그인해 주세요.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호 변경 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPwd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('계정 설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 프로필 카드
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('프로필', style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
                  const SizedBox(height: 12),
                  if (user?.email != null)
                    Text('이메일: ${user!.email}', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '닉네임',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _savingName ? null : _saveDisplayName,
                      icon: _savingName
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('닉네임 저장'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 비밀번호 변경 카드
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  if (!_isEmailPasswordUser) ...[
                    const Text('현재 계정은 소셜 로그인(예: Google/Apple)입니다. 비밀번호를 변경하려면 이메일/비밀번호 로그인과 연결이 필요해요.'),
                  ] else Form(
                    key: _formKeyPwd,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _curPwdCtrl,
                          obscureText: !_showCur,
                          decoration: InputDecoration(
                            labelText: '현재 비밀번호',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_showCur ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showCur = !_showCur),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return '현재 비밀번호를 입력해 주세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newPwdCtrl,
                          obscureText: !_showNew,
                          decoration: InputDecoration(
                            labelText: '새 비밀번호 (6자 이상)',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showNew = !_showNew),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return '새 비밀번호를 입력해 주세요.';
                            if (v.length < 6) return '6자 이상으로 입력해 주세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newPwd2Ctrl,
                          obscureText: !_showNew2,
                          decoration: InputDecoration(
                            labelText: '새 비밀번호 확인',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_showNew2 ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showNew2 = !_showNew2),
                            ),
                          ),
                          validator: (v) {
                            if (v != _newPwdCtrl.text) return '새 비밀번호가 일치하지 않아요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _savingPwd ? null : _changePassword,
                            icon: _savingPwd
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.lock_reset),
                            label: const Text('비밀번호 변경'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? cs.surface.withOpacity(0.55) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? cs.outlineVariant.withOpacity(0.28) : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.18 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
