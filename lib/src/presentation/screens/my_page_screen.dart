import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/b4y_providers.dart';
import '../../data/image_data_url.dart';
import '../../data/profile_repository.dart';
import '../widgets/engagement_card.dart';
import '../widgets/photo_thumb.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  String? _photoDataUrl;
  bool _savingProfile = false;
  bool _authBusy = false;
  bool _passwordBusy = false;
  bool _pickingImage = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider).valueOrNull;
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    _syncProfileFields(profile);
    final isSignedIn = user != null && !user.isAnonymous;
    final isEmailUser =
        isSignedIn &&
        user.providerData.any((info) => info.providerId == 'password');

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_message != null) ...[
            _MessageBanner(
              message: _message!,
              onClose: () => setState(() => _message = null),
            ),
            const SizedBox(height: 12),
          ],
          if (!isSignedIn)
            _AuthSection(
              emailController: _emailController,
              passwordController: _passwordController,
              busy: _authBusy,
              onEmailSignIn: () => _emailSignIn(createAccount: false),
              onEmailCreate: () => _emailSignIn(createAccount: true),
              onGoogleSignIn: _googleSignIn,
            )
          else ...[
            _ProfileSection(
              user: user,
              profile: profile,
              nicknameController: _nicknameController,
              photoDataUrl: _photoDataUrl,
              saving: _savingProfile,
              pickingImage: _pickingImage,
              onPickImage: _pickProfileImage,
              onRemoveImage: () => setState(() => _photoDataUrl = null),
              onSave: _saveProfile,
              onSignOut: _signOut,
            ),
            if (isEmailUser) ...[
              const SizedBox(height: 12),
              _PasswordSection(
                currentPasswordController: _currentPasswordController,
                newPasswordController: _newPasswordController,
                busy: _passwordBusy,
                onSave: _changePassword,
              ),
            ],
            const SizedBox(height: 18),
            Text('내가 올린 미션', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _MyMissionList(),
            const SizedBox(height: 18),
            Text('내가 올린 리뷰', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _MyReviewList(),
          ],
        ],
      ),
    );
  }

  void _syncProfileFields(UserProfile? profile) {
    if (_savingProfile || _pickingImage) return;
    final nickname = profile?.nickname ?? '';
    if (_nicknameController.text.isEmpty && nickname.isNotEmpty) {
      _nicknameController.text = nickname;
    }
    _photoDataUrl ??= profile?.photoDataUrl;
  }

  Future<void> _emailSignIn({required bool createAccount}) async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      setState(() => _message = 'Firebase Auth 연결을 확인해 주세요.');
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      setState(() => _message = '이메일과 6자 이상의 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _authBusy = true;
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
      setState(() => _message = createAccount ? '계정을 만들었어요.' : '로그인했어요.');
    } on FirebaseAuthException catch (error) {
      if (createAccount && error.code == 'credential-already-in-use') {
        await auth.signInWithEmailAndPassword(email: email, password: password);
        if (mounted) setState(() => _message = '기존 계정으로 로그인했어요.');
      } else {
        setState(() => _message = _authMessage(error));
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _googleSignIn() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      setState(() => _message = 'Firebase Auth 연결을 확인해 주세요.');
      return;
    }
    setState(() {
      _authBusy = true;
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
      setState(() => _message = '구글 계정으로 로그인했어요.');
    } on FirebaseAuthException catch (error) {
      setState(() => _message = _authMessage(error));
    } on Object catch (error) {
      setState(() => _message = '구글 로그인을 완료하지 못했어요: $error');
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }
  }

  Future<void> _pickProfileImage() async {
    setState(() {
      _pickingImage = true;
      _message = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dataUrl = encodeImageDataUrl(await picked.readAsBytes());
      if (mounted) setState(() => _photoDataUrl = dataUrl);
    } on Object catch (error) {
      if (mounted) setState(() => _message = _formMessage(error));
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    final repository = ref.read(profileRepositoryProvider);
    final user = ref.read(authUserProvider).valueOrNull;
    final nickname = _nicknameController.text.trim();
    if (repository == null || user == null || user.isAnonymous) {
      setState(() => _message = '로그인 후 프로필을 저장할 수 있어요.');
      return;
    }
    if (nickname.isEmpty || nickname.length > 30) {
      setState(() => _message = '닉네임은 1자 이상 30자 이하로 입력해 주세요.');
      return;
    }
    setState(() {
      _savingProfile = true;
      _message = null;
    });
    try {
      await repository.saveProfile(
        uid: user.uid,
        nickname: nickname,
        photoDataUrl: _photoDataUrl,
      );
      await repository.updateAuthoredContentNickname(
        uid: user.uid,
        nickname: nickname,
      );
      await user.updateDisplayName(nickname);
      setState(() => _message = '프로필을 저장했어요.');
    } on Object catch (error) {
      setState(() => _message = _formMessage(error));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final user = ref.read(authUserProvider).valueOrNull;
    final email = user?.email;
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    if (user == null || email == null) return;
    if (currentPassword.isEmpty || newPassword.length < 6) {
      setState(() => _message = '현재 비밀번호와 6자 이상의 새 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _passwordBusy = true;
      _message = null;
    });
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      setState(() => _message = '비밀번호를 변경했어요.');
    } on FirebaseAuthException catch (error) {
      setState(() => _message = _authMessage(error));
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  Future<void> _signOut() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) return;
    await GoogleSignIn().signOut();
    await auth.signOut();
    try {
      await auth.signInAnonymously();
    } on FirebaseAuthException {
      // Browsing can continue without an auth session.
    }
    _nicknameController.clear();
    _photoDataUrl = null;
    if (mounted) setState(() => _message = '로그아웃했어요.');
  }
}

class _AuthSection extends StatelessWidget {
  const _AuthSection({
    required this.emailController,
    required this.passwordController,
    required this.busy,
    required this.onEmailSignIn,
    required this.onEmailCreate,
    required this.onGoogleSignIn,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool busy;
  final VoidCallback onEmailSignIn;
  final VoidCallback onEmailCreate;
  final VoidCallback onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('로그인', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('프로필과 내가 올린 미션/리뷰를 관리하려면 로그인해 주세요.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onEmailSignIn,
              child: Text(busy ? '처리 중...' : '이메일 로그인'),
            ),
            OutlinedButton(
              onPressed: busy ? null : onEmailCreate,
              child: const Text('이메일 계정 만들기'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onGoogleSignIn,
              icon: const Icon(Icons.login_rounded),
              label: const Text('구글 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.user,
    required this.profile,
    required this.nicknameController,
    required this.photoDataUrl,
    required this.saving,
    required this.pickingImage,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSave,
    required this.onSignOut,
  });

  final User user;
  final UserProfile? profile;
  final TextEditingController nicknameController;
  final String? photoDataUrl;
  final bool saving;
  final bool pickingImage;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSave;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final hasProfilePhoto = photoDataUrl != null && photoDataUrl!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: hasProfilePhoto
                      ? PhotoThumb(
                          imageUrl: photoDataUrl!,
                          width: 84,
                          height: 84,
                          borderRadius: 999,
                        )
                      : const _DefaultProfileAvatar(size: 84),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.isComplete == true
                            ? profile!.nickname
                            : '프로필을 설정해 주세요',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(user.email ?? '구글 계정'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: pickingImage || saving
                                ? null
                                : onPickImage,
                            child: Text(pickingImage ? '변환 중...' : '사진 변경'),
                          ),
                          if (hasProfilePhoto)
                            TextButton(
                              onPressed: saving ? null : onRemoveImage,
                              child: const Text('사진 제거'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nicknameController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '닉네임',
                border: OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: saving ? null : onSave,
                    child: Text(saving ? '저장 중...' : '프로필 저장'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: saving ? null : onSignOut,
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordSection extends StatelessWidget {
  const _PasswordSection({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.busy,
    required this.onSave,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('비밀번호 변경', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '현재 비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '새 비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : onSave,
              child: Text(busy ? '변경 중...' : '비밀번호 변경'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyMissionList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = ref.watch(myMissionsProvider);
    return missions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Text('미션을 불러오지 못했어요.'),
      data: (items) => items.isEmpty
          ? const _EmptyOwnItem(message: '아직 올린 미션이 없어요.')
          : Column(
              children: [
                for (final mission in items)
                  MissionCard(
                    mission: mission,
                    onLike: null,
                    onVerify: null,
                    onTap: () => context.go(
                      '/spots/${mission.spotId}/missions/${mission.id}',
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MyReviewList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(myReviewsProvider);
    return reviews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Text('리뷰를 불러오지 못했어요.'),
      data: (items) => items.isEmpty
          ? const _EmptyOwnItem(message: '아직 올린 리뷰가 없어요.')
          : Column(
              children: [
                for (final review in items)
                  ReviewCard(
                    review: review,
                    onLike: null,
                    onTap: () => context.go(
                      '/spots/${review.spotId}/reviews/${review.id}',
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DefaultProfileAvatar extends StatelessWidget {
  const _DefaultProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.56,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: '닫기',
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOwnItem extends StatelessWidget {
  const _EmptyOwnItem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(message),
    );
  }
}

String _authMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'email-already-in-use' => '이미 가입된 이메일이에요.',
    'invalid-email' => '이메일 형식을 확인해 주세요.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => '이메일 또는 비밀번호를 확인해 주세요.',
    'weak-password' => '비밀번호는 6자 이상으로 입력해 주세요.',
    'requires-recent-login' => '다시 로그인한 뒤 시도해 주세요.',
    _ => error.message ?? '인증을 완료하지 못했어요.',
  };
}

String _formMessage(Object error) {
  if (error is FormatException) return error.message;
  if (error is FirebaseException) return error.message ?? '저장하지 못했어요.';
  return '처리하지 못했어요: $error';
}
