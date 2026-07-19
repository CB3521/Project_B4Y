import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/b4y_providers.dart';
import '../../data/image_data_url.dart';
import '../../domain/b4y_models.dart';
import '../../domain/route_segments.dart';
import '../widgets/photo_thumb.dart';

class GalleryUploadScreen extends ConsumerStatefulWidget {
  const GalleryUploadScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.routeId,
    required this.spotId,
    this.initialDirectionId = '',
    this.initialStartStopId = '',
    this.initialEndStopId = '',
  });

  final String targetType;
  final String targetId;
  final String routeId;
  final String spotId;
  final String initialDirectionId;
  final String initialStartStopId;
  final String initialEndStopId;

  @override
  ConsumerState<GalleryUploadScreen> createState() =>
      _GalleryUploadScreenState();
}

class _GalleryUploadScreenState extends ConsumerState<GalleryUploadScreen> {
  final _titleController = TextEditingController();
  final _photos = <String>[];
  String? _directionId;
  String? _startStopId;
  String? _endStopId;

  @override
  void initState() {
    super.initState();
    _directionId = widget.initialDirectionId.isEmpty
        ? null
        : widget.initialDirectionId;
    _startStopId = widget.initialStartStopId.isEmpty
        ? null
        : widget.initialStartStopId;
    _endStopId = widget.initialEndStopId.isEmpty
        ? null
        : widget.initialEndStopId;
  }

  var _picking = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: imageJpegQuality,
        maxWidth: maxImageLongSidePixels.toDouble(),
        maxHeight: maxImageLongSidePixels.toDouble(),
      );
      for (final photo in picked) {
        if (!mounted) return;
        try {
          final encoded = encodeImageDataUrl(await photo.readAsBytes());
          if (!_photos.contains(encoded)) _photos.add(encoded);
        } on Object catch (caught) {
          _error = '$caught';
        }
      }
      if (mounted) setState(() {});
    } on Object catch (caught) {
      if (mounted) setState(() => _error = '$caught');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final repository = ref.read(galleryRepositoryProvider);
    final auth = ref.read(firebaseAuthProvider);
    if (repository == null || auth == null) {
      setState(() => _error = 'Firebase 연결을 확인해 주세요.');
      return;
    }
    if (_photos.isEmpty) {
      setState(() => _error = '공유할 사진을 하나 이상 선택해 주세요.');
      return;
    }
    if (widget.targetId.trim().isEmpty ||
        (widget.targetType != 'route' && widget.targetType != 'spot')) {
      setState(() => _error = '사진을 올릴 대상을 확인해 주세요.');
      return;
    }
    if (widget.targetType == 'route') {
      _selectDefaultRouteSegment();
    }
    if (widget.targetType == 'route' &&
        (_directionId == null || _startStopId == null || _endStopId == null)) {
      setState(() => _error = '사진을 올릴 노선 구간을 선택해 주세요.');
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
      for (final photo in _photos) {
        await repository.createPhoto(
          targetType: widget.targetType,
          targetId: widget.targetId,
          routeId: widget.routeId,
          directionId: _directionId ?? '',
          startStopId: _startStopId ?? '',
          endStopId: _endStopId ?? '',
          spotId: widget.spotId,
          description: _titleController.text,
          imageDataUrl: photo,
          authorNickname: nickname?.isNotEmpty == true ? nickname! : '방문자',
          authorUid: user.uid,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (caught) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _messageFor(caught);
        });
      }
    }
  }

  void _selectDefaultRouteSegment() {
    if (_directionId != null && _startStopId != null && _endStopId != null) {
      return;
    }
    final data = ref.read(b4yDataProvider).valueOrNull;
    final route = data?.routes
        .where((item) => item.id == widget.routeId)
        .firstOrNull;
    if (data == null || route == null) return;
    final direction = _directionId == null
        ? route.defaultDirection
        : route.directionById(_directionId!);
    final firstSegment = buildRouteSegments(route, direction, data).firstOrNull;
    if (firstSegment == null) return;
    _directionId = direction.id;
    _startStopId = firstSegment.startStop.id;
    _endStopId = firstSegment.endStop.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진 올리기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _picking || _saving ? null : _pickPhotos,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_picking ? '불러오는 중...' : '사진 올리기'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '선택 입력',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          if (widget.targetType == 'route') ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('gallery-segment-picker-button'),
              onPressed: _saving ? null : _pickSegment,
              icon: const Icon(Icons.alt_route_rounded),
              label: Text(
                _startStopId == null
                    ? '구간 선택'
                    : '선택 구간: $_startStopId → $_endStopId',
              ),
            ),
          ],
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('추가된 사진 ${_photos.length}장'),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    PhotoThumb(imageUrl: _photos[index]),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filled(
                        tooltip: '사진 삭제',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _photos.removeAt(index)),
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving || _picking ? null : _submit,
            child: Text(_saving ? '올리는 중...' : '게시하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSegment() async {
    final data = ref.read(b4yDataProvider).valueOrNull;
    if (data == null) return;
    final route = data.routes
        .where((item) => item.id == widget.routeId)
        .firstOrNull;
    if (route == null) return;
    final result = await Navigator.of(context).push<RouteSegment>(
      MaterialPageRoute<RouteSegment>(
        builder: (context) => _GallerySegmentPicker(data: data, route: route),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _directionId = result.directionId;
      _startStopId = result.startStop.id;
      _endStopId = result.endStop.id;
    });
  }
}

class _GallerySegmentPicker extends StatefulWidget {
  const _GallerySegmentPicker({required this.data, required this.route});

  final B4ySampleData data;
  final BusRoute route;

  @override
  State<_GallerySegmentPicker> createState() => _GallerySegmentPickerState();
}

class _GallerySegmentPickerState extends State<_GallerySegmentPicker> {
  late RouteDirection _direction;

  @override
  void initState() {
    super.initState();
    _direction = widget.route.defaultDirection;
  }

  @override
  Widget build(BuildContext context) {
    final segments = buildRouteSegments(widget.route, _direction, widget.data);
    return Scaffold(
      appBar: AppBar(title: const Text('사진 구간 선택')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _direction.id,
            decoration: const InputDecoration(
              labelText: '방향',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final direction in widget.route.directions)
                DropdownMenuItem(
                  value: direction.id,
                  child: Text('${direction.name} · ${direction.destination}'),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _direction = widget.route.directionById(value));
            },
          ),
          const SizedBox(height: 12),
          for (final segment in segments)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${segment.index + 1}')),
                title: Text(
                  '${segment.startStop.name} → ${segment.endStop.name}',
                ),
                subtitle: Text('${segment.stops.length}개 정류장'),
                onTap: () => Navigator.of(context).pop(segment),
              ),
            ),
        ],
      ),
    );
  }
}

String _messageFor(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'operation-not-allowed' =>
        '익명 로그인이 비활성화되어 사진을 저장할 수 없습니다. Firebase Authentication에서 익명 로그인을 켜 주세요.',
      'network-request-failed' => '네트워크가 불안정해 로그인하지 못했습니다.',
      _ => '로그인하지 못했습니다. (${error.code})',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        '사진 저장 권한이 거부되었습니다. Firebase 로그인과 Firestore 규칙을 확인해 주세요.',
      'resource-exhausted' => '사진 용량이 너무 큽니다. 더 작은 사진을 선택해 주세요.',
      'unavailable' => '네트워크가 불안정해 사진을 저장하지 못했습니다.',
      _ => '사진을 저장하지 못했습니다. (${error.code})',
    };
  }
  return '사진을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
