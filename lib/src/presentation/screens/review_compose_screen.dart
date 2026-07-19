import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/b4y_providers.dart';
import '../../data/image_data_url.dart';
import '../widgets/compose_step_controls.dart';
import '../widgets/photo_thumb.dart';

class ReviewComposeScreen extends ConsumerStatefulWidget {
  const ReviewComposeScreen({super.key, required this.spotId});

  final String spotId;

  @override
  ConsumerState<ReviewComposeScreen> createState() =>
      _ReviewComposeScreenState();
}

class _ReviewComposeScreenState extends ConsumerState<ReviewComposeScreen> {
  static const _maxPhotoCount = 6;
  static const _stepTitles = ['기본 정보', '평점', '사진'];

  static const _cleanlinessOptions = [
    '화장실이 깨끗해요',
    '길이 깨끗해요',
    '냄새가 나지 않아요',
    '길에 쓰래기가 없어요',
    '기타',
  ];

  static const _accessibilityOptions = [
    '정류장과 가까워요',
    '화장실이 가까워요',
    '관광 장소 간 거리가 짧아요',
    '기타',
  ];

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _visitSeasonController = TextEditingController();
  final _cleanlinessOtherController = TextEditingController();
  final _accessibilityOtherController = TextEditingController();
  final Set<String> _cleanlinessTags = {};
  final Set<String> _accessibilityTags = {};
  final List<String> _imageDataUrls = [];
  DateTime? _visitDate;
  double _cleanlinessRating = 3;
  double _accessibilityRating = 3;
  double _overallRating = 3;
  int _currentStep = 0;
  bool _pickingImage = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _visitSeasonController.dispose();
    _cleanlinessOtherController.dispose();
    _accessibilityOtherController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    try {
      final remaining = _maxPhotoCount - _imageDataUrls.length;
      if (remaining <= 0) {
        setState(() => _error = '사진은 최대 $_maxPhotoCount장까지 올릴 수 있어요.');
        return;
      }
      final picked = await ImagePicker().pickMultiImage(limit: remaining);
      if (picked.isEmpty) return;
      final values = <String>[];
      for (final image in picked.take(remaining)) {
        values.add(encodeImageDataUrl(await image.readAsBytes()));
      }
      if (mounted) setState(() => _imageDataUrls.addAll(values));
    } on Object catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _pickVisitDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      helpText: '방문 시기 선택',
      cancelText: '취소',
      confirmText: '선택',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _visitDate = picked;
      _visitSeasonController.text = _formatDate(picked);
    });
  }

  Future<void> _submit() async {
    final repository = ref.read(engagementRepositoryProvider);
    final auth = ref.read(firebaseAuthProvider);
    if (repository == null || auth == null) {
      setState(() => _error = 'Firebase 연결을 확인해 주세요.');
      return;
    }
    if (widget.spotId.trim().isEmpty) {
      setState(() => _error = '리뷰를 등록할 관광지를 확인해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user == null) throw StateError('사용자 정보를 만들 수 없습니다.');
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final nickname = profile?.nickname.trim();
      await repository.createReview(
        spotId: widget.spotId,
        title: _titleController.text,
        body: _bodyController.text,
        visitSeason: _visitSeasonController.text,
        cleanlinessRating: _cleanlinessRating,
        accessibilityRating: _accessibilityRating,
        overallRating: _overallRating,
        cleanlinessTags: _cleanlinessTags.toList(),
        accessibilityTags: _accessibilityTags.toList(),
        cleanlinessOther: _cleanlinessTags.contains('기타')
            ? _cleanlinessOtherController.text
            : '',
        accessibilityOther: _accessibilityTags.contains('기타')
            ? _accessibilityOtherController.text
            : '',
        authorNickname: nickname?.isNotEmpty == true ? nickname! : '방문자',
        authorUid: user.uid,
        imageDataUrls: _imageDataUrls,
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/spots/${widget.spotId}/reviews');
      }
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
    final canSubmit = !_saving && !_pickingImage;
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰 작성')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            ComposeStepHeader(titles: _stepTitles, currentStep: _currentStep),
            const SizedBox(height: 24),
            ..._buildStepChildren(canSubmit),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: ComposeStepNavigation(
        currentStep: _currentStep,
        stepCount: _stepTitles.length,
        canSubmit: canSubmit,
        saving: _saving,
        submitLabel: '리뷰 등록',
        onPrevious: _previousStep,
        onNext: _nextStep,
        onSubmit: _submit,
      ),
    );
  }

  List<Widget> _buildStepChildren(bool canSubmit) {
    return switch (_currentStep) {
      0 => [
        TextField(
          controller: _titleController,
          maxLength: 100,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '리뷰 제목',
            hintText: '자신이 소개하고 싶은 관광지를 적어보세요!',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bodyController,
          maxLines: 5,
          maxLength: 600,
          decoration: const InputDecoration(
            labelText: '리뷰 내용',
            hintText: '이 관광지에 대해 좋았던 점, 아쉬웠던 점 등을 적어보세요!',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _visitSeasonController,
          readOnly: true,
          onTap: _saving ? null : _pickVisitDate,
          decoration: InputDecoration(
            labelText: '방문 시기',
            hintText: '날짜 선택',
            prefixIcon: const Icon(Icons.calendar_month_outlined),
            suffixIcon: _visitDate == null
                ? null
                : IconButton(
                    tooltip: '방문 시기 지우기',
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _visitDate = null;
                            _visitSeasonController.clear();
                          }),
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
      1 => [
        _RatingSection(
          title: '청결성 평점',
          value: _cleanlinessRating,
          onChanged: (value) => setState(() => _cleanlinessRating = value),
          children: [
            _TagSelector(
              options: _cleanlinessOptions,
              selected: _cleanlinessTags,
              onChanged: (value) =>
                  setState(() => _toggleTag(_cleanlinessTags, value)),
            ),
            if (_cleanlinessTags.contains('기타')) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _cleanlinessOtherController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '기타 의견',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        _RatingSection(
          title: '접근성 평점',
          value: _accessibilityRating,
          onChanged: (value) => setState(() => _accessibilityRating = value),
          children: [
            _TagSelector(
              options: _accessibilityOptions,
              selected: _accessibilityTags,
              onChanged: (value) =>
                  setState(() => _toggleTag(_accessibilityTags, value)),
            ),
            if (_accessibilityTags.contains('기타')) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _accessibilityOtherController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: '기타 의견',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        _RatingSection(
          title: '종합 평점',
          value: _overallRating,
          onChanged: (value) => setState(() => _overallRating = value),
          footer: const _OverallRatingLabels(),
        ),
      ],
      _ => [
        _ReviewPhotoSection(
          imageDataUrls: _imageDataUrls,
          maxPhotoCount: _maxPhotoCount,
          canSubmit: canSubmit,
          pickingImage: _pickingImage,
          saving: _saving,
          onPickImages: _pickImages,
          onRemove: (index) => setState(() => _imageDataUrls.removeAt(index)),
        ),
      ],
    };
  }

  void _nextStep() {
    setState(() {
      _currentStep = (_currentStep + 1).clamp(0, _stepTitles.length - 1);
      _error = null;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep = (_currentStep - 1).clamp(0, _stepTitles.length - 1);
      _error = null;
    });
  }

  void _toggleTag(Set<String> source, String value) {
    if (!source.add(value)) {
      source.remove(value);
    }
  }
}

class _ReviewPhotoSection extends StatelessWidget {
  const _ReviewPhotoSection({
    required this.imageDataUrls,
    required this.maxPhotoCount,
    required this.canSubmit,
    required this.pickingImage,
    required this.saving,
    required this.onPickImages,
    required this.onRemove,
  });

  final List<String> imageDataUrls;
  final int maxPhotoCount;
  final bool canSubmit;
  final bool pickingImage;
  final bool saving;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text('사진', style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(
              '${imageDataUrls.length}/$maxPhotoCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageDataUrls.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == imageDataUrls.length) {
                return _AddPhotoButton(
                  enabled: canSubmit && imageDataUrls.length < maxPhotoCount,
                  busy: pickingImage,
                  onPressed: onPickImages,
                );
              }
              return _ReviewPhotoThumb(
                imageDataUrl: imageDataUrls[index],
                onRemove: saving ? null : () => onRemove(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 104,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(busy ? Icons.hourglass_empty : Icons.photo_library_outlined),
        label: Text(busy ? '변환 중...' : '사진 올리기'),
      ),
    );
  }
}

class _ReviewPhotoThumb extends StatelessWidget {
  const _ReviewPhotoThumb({required this.imageDataUrl, required this.onRemove});

  final String imageDataUrl;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PhotoThumb(
                imageUrl: imageDataUrl,
                width: 104,
                height: 104,
                borderRadius: 0,
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filledTonal(
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.title,
    required this.value,
    required this.onChanged,
    this.children = const [],
    this.footer,
  });

  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _formatRating(value),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          Slider(
            min: 1,
            max: 5,
            divisions: 8,
            value: value,
            label: _formatRating(value),
            onChanged: onChanged,
          ),
          ?footer,
          ...children,
        ],
      ),
    );
  }
}

class _TagSelector extends StatelessWidget {
  const _TagSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option),
            selected: selected.contains(option),
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }
}

class _OverallRatingLabels extends StatelessWidget {
  const _OverallRatingLabels();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in const [
            ('1', '매우 안좋음'),
            ('2', '안좋음'),
            ('3', '보통'),
            ('4', '좋음'),
            ('5', '매우 좋음'),
          ])
            Expanded(
              child: Column(
                children: [
                  Text(item.$1, style: style, textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(item.$2, style: style, textAlign: TextAlign.center),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatRating(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _messageFor(Object error) {
  if (error is FormatException) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'operation-not-allowed' =>
        '익명 로그인이 비활성화되어 리뷰를 저장할 수 없습니다. Firebase Authentication에서 익명 로그인을 켜 주세요.',
      'network-request-failed' => '네트워크가 불안정해 로그인하지 못했습니다.',
      _ => '로그인하지 못했습니다. (${error.code})',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => '저장 권한이 거부됐어요. Firestore 규칙을 확인해 주세요.',
      'resource-exhausted' => '사진 용량이 아직 커요. 사진 수를 줄이거나 더 작은 사진을 선택해 주세요.',
      'unavailable' => '네트워크가 불안정해 저장하지 못했어요.',
      _ => '저장하지 못했어요. (${error.code}) ${error.message ?? ''}'.trim(),
    };
  }
  return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
