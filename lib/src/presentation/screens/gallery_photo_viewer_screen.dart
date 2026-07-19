import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/b4y_providers.dart';
import '../../domain/b4y_models.dart';
import '../widgets/photo_thumb.dart';

class GalleryPhotoViewerScreen extends ConsumerStatefulWidget {
  const GalleryPhotoViewerScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.categoryTitle,
    this.routeLabel,
    this.directionLabel,
    this.segmentLabel,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;
  final String categoryTitle;
  final String? routeLabel;
  final String? directionLabel;
  final String? segmentLabel;

  @override
  ConsumerState<GalleryPhotoViewerScreen> createState() =>
      _GalleryPhotoViewerScreenState();
}

class _GalleryPhotoViewerScreenState
    extends ConsumerState<GalleryPhotoViewerScreen> {
  late int _currentIndex;
  late List<GalleryPhoto> _photos;
  var _showInfo = false;
  final _likingPhotoIds = <String>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _photos = [...widget.photos];
  }

  Future<void> _toggleLike(GalleryPhoto photo) async {
    if (_likingPhotoIds.contains(photo.id)) return;
    final repository = ref.read(galleryRepositoryProvider);
    final auth = ref.read(firebaseAuthProvider);
    String? userId;
    try {
      userId =
          auth?.currentUser?.uid ??
          (await auth?.signInAnonymously())?.user?.uid;
    } on Object {
      _showLikeError();
      return;
    }
    if (repository == null || userId == null) {
      _showLikeError();
      return;
    }
    final index = _photos.indexWhere((item) => item.id == photo.id);
    if (index < 0) return;
    final previous = photo;
    setState(() {
      _likingPhotoIds.add(photo.id);
      _photos[index] = photo.copyWith(
        isLiked: !photo.isLiked,
        likeCount: (photo.likeCount + (photo.isLiked ? -1 : 1)).clamp(
          0,
          1 << 31,
        ),
      );
    });
    try {
      await repository.toggleLike(photo.id, userId);
    } on Object {
      if (!mounted) return;
      setState(() => _photos[index] = previous);
      _showLikeError();
    } finally {
      if (mounted) {
        setState(() => _likingPhotoIds.remove(photo.id));
      }
    }
  }

  void _showLikeError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('좋아요를 반영하지 못했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photos[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.categoryTitle} · ${_currentIndex + 1}/${_photos.length}',
        ),
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! < -4) {
                setState(() => _showInfo = true);
              }
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 200) {
                setState(() => _showInfo = false);
              }
            },
            child: PageView.builder(
              itemCount: _photos.length,
              onPageChanged: (index) => setState(() {
                _currentIndex = index;
                _showInfo = false;
              }),
              itemBuilder: (context, index) => Center(
                child: PhotoThumb(
                  imageUrl: _photos[index].imageUrl,
                  fit: BoxFit.contain,
                  borderRadius: 0,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    key: const Key('gallery-viewer-like-button'),
                    tooltip: '좋아요',
                    onPressed: _likingPhotoIds.contains(photo.id)
                        ? null
                        : () => _toggleLike(photo),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      foregroundColor: photo.isLiked
                          ? Colors.redAccent
                          : Colors.white,
                      disabledForegroundColor: Colors.white54,
                    ),
                    icon: Icon(
                      photo.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                  Text(
                    '${photo.likeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: _showInfo ? 0 : -160,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        photo.description.isEmpty ? '설명 없음' : photo.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (widget.routeLabel?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text(
                          '노선 ${widget.routeLabel}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                      if (widget.directionLabel?.isNotEmpty == true)
                        Text('방향 ${widget.directionLabel}'),
                      if (widget.segmentLabel?.isNotEmpty == true)
                        Text('구간 ${widget.segmentLabel}'),
                      const SizedBox(height: 8),
                      Text(
                        '좋아요 ${photo.likeCount}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
