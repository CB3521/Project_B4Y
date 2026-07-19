import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../application/b4y_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_message != null) ...[
            Text(_message!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '이메일',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '비밀번호',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _emailAuth(createAccount: false),
            child: Text(_busy ? '처리 중...' : '이메일 로그인'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _emailAuth(createAccount: true),
            child: const Text('이메일 계정 만들기'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _googleSignIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text('구글 로그인'),
          ),
        ],
      ),
    );
  }

  Future<void> _emailAuth({required bool createAccount}) async {
    final auth = ref.read(firebaseAuthProvider);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (auth == null) {
      setState(() => _message = 'Firebase Auth 연결을 확인해 주세요.');
      return;
    }
    if (email.isEmpty || password.length < 6) {
      setState(() => _message = '이메일과 6자 이상의 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (createAccount) {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        final current = auth.currentUser;
        if (current != null && current.isAnonymous) {
          await current.linkWithCredential(credential);
        } else {
          await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      if (mounted) context.go('/my');
    } on FirebaseAuthException catch (error) {
      if (createAccount && error.code == 'credential-already-in-use') {
        await auth.signInWithEmailAndPassword(email: email, password: password);
        if (mounted) context.go('/my');
      } else if (mounted) {
        setState(() => _message = _authMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      setState(() => _message = 'Firebase Auth 연결을 확인해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final current = auth.currentUser;
        if (current != null && current.isAnonymous) {
          try {
            await current.linkWithCredential(credential);
          } on FirebaseAuthException catch (error) {
            if (error.code == 'credential-already-in-use' ||
                error.code == 'provider-already-linked') {
              await auth.signInWithCredential(credential);
            } else {
              rethrow;
            }
          }
        } else {
          await auth.signInWithCredential(credential);
        }
      }
      if (mounted) context.go('/my');
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _message = _authMessage(error));
    } on Object catch (error) {
      if (mounted) setState(() => _message = '구글 로그인을 완료하지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _authMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' =>
      '이메일 또는 비밀번호를 확인해 주세요.',
    'email-already-in-use' => '이미 사용 중인 이메일이에요.',
    'weak-password' => '더 안전한 비밀번호를 입력해 주세요.',
    'requires-recent-login' => '다시 로그인한 뒤 시도해 주세요.',
    _ => error.message ?? '인증을 완료하지 못했어요.',
  };
}
