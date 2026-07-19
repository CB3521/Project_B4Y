import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/b4y_providers.dart';
import '../../data/image_data_url.dart';
import 'photo_thumb.dart';

Future<void> showEngagementForm(
  BuildContext context, {
  required String spotId,
  required bool isMission,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _EngagementForm(spotId: spotId, isMission: isMission),
  );
}

class _EngagementForm extends ConsumerStatefulWidget {
  const _EngagementForm({required this.spotId, required this.isMission});

  final String spotId;
  final bool isMission;

  @override
  ConsumerState<_EngagementForm> createState() => _EngagementFormState();
}

class _EngagementFormState extends ConsumerState<_EngagementForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  String? _imageDataUrl;
  bool _pickingImage = false;
  bool _saving = false;
  String? _error;
  bool _syncedProfile = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final value = encodeImageDataUrl(await picked.readAsBytes());
      if (mounted) setState(() => _imageDataUrl = value);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(engagementRepositoryProvider);
    final auth = ref.read(firebaseAuthProvider);
    if (repository == null || auth == null) {
      setState(() => _error = 'Firebase 연결을 확인해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user == null) throw StateError('사용자 정보를 만들 수 없습니다.');
      if (widget.isMission) {
        await repository.createMission(
          spotId: widget.spotId,
          title: _titleController.text,
          body: '',
          targetType: '',
          targetId: '',
          targetName: '',
          routeId: '',
          directionId: '',
          startStopId: '',
          endStopId: '',
          selectedLat: null,
          selectedLng: null,
          difficulty: 3,
          availableSeason: '',
          missionTags: const [],
          difficultyTags: const [],
          verificationMethod: 'photo',
          verificationRadiusMeters: 50,
          authorNickname: _authorController.text,
          authorUid: user.uid,
          imageDataUrl: _imageDataUrl,
        );
      } else {
        await repository.createReview(
          spotId: widget.spotId,
          title: _titleController.text,
          body: '',
          visitSeason: '',
          cleanlinessRating: 3,
          accessibilityRating: 3,
          overallRating: 3,
          cleanlinessTags: const [],
          accessibilityTags: const [],
          cleanlinessOther: '',
          accessibilityOther: '',
          authorNickname: _authorController.text,
          authorUid: user.uid,
          imageDataUrl: _imageDataUrl,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _messageFor(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (!_syncedProfile && profile?.nickname.trim().isNotEmpty == true) {
      _authorController.text = profile!.nickname;
      _syncedProfile = true;
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isMission ? '미션 작성' : '리뷰 작성',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _authorController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '작성자',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imageDataUrl == null
                        ? const PhotoPlaceholder(width: 88, height: 88)
                        : PhotoThumb(
                            imageUrl: _imageDataUrl!,
                            width: 88,
                            height: 88,
                            borderRadius: 0,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickingImage || _saving
                              ? null
                              : _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_pickingImage ? '변환 중...' : '사진 선택'),
                        ),
                        if (_imageDataUrl != null)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _imageDataUrl = null),
                            child: const Text('사진 제거'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving || _pickingImage ? null : _submit,
                  child: Text(_saving ? '등록 중...' : '등록'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _requiredText(String? value) {
  return value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;
}

String _messageFor(Object error) {
  if (error is FormatException) return error.message;
  return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
