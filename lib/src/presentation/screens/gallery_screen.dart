import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/b4y_providers.dart';
import '../../domain/b4y_models.dart';
import '../widgets/photo_thumb.dart';
import 'gallery_photo_viewer_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key, this.spotId, this.routeId, this.routeLabel});

  final String? spotId;
  final String? routeId;
  final String? routeLabel;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  GallerySort _sort = GallerySort.latest;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(b4yDataProvider).valueOrNull;
    final targetType = widget.routeId == null ? 'spot' : 'route';
    final selectedId = widget.routeId ?? widget.spotId;
    final galleryAsync = selectedId == null
        ? null
        : targetType == 'route'
        ? ref.watch(galleryForRouteProvider(selectedId))
        : ref.watch(galleryForSpotProvider(selectedId));
    final photos = galleryAsync?.valueOrNull ?? const <GalleryPhoto>[];
    final title = targetType == 'route'
        ? _routeLabel(data, selectedId, fallback: widget.routeLabel)
        : _spotLabel(data, selectedId);

    return Scaffold(
      appBar: AppBar(title: Text('$title 갤러리')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          if (galleryAsync?.hasError == true)
            Padding(
              padding: const EdgeInsets.only(top: 72, left: 16, right: 16),
              child: Text(
                '사진 목록을 불러오지 못했습니다.\n${galleryAsync?.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else if (photos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 96),
              child: Center(child: Text('사진이 아직 없어요.')),
            )
          else ...[
            SegmentedButton<GallerySort>(
              segments: const [
                ButtonSegment(value: GallerySort.latest, label: Text('최신순')),
                ButtonSegment(
                  value: GallerySort.popular,
                  label: Text('좋아요 많은 순'),
                ),
              ],
              selected: {_sort},
              onSelectionChanged: (value) =>
                  setState(() => _sort = value.first),
            ),
            const SizedBox(height: 14),
            _GalleryGrid(
              photos: sortedGalleryPhotos(photos, _sort),
              onLike: (photo) => _toggleLike(context, photo),
              onPhotoTap: (index, categoryPhotos) => _openPhotoViewer(
                context,
                categoryPhotos,
                index,
                _sort == GallerySort.latest ? '최신순' : '좋아요 많은 순',
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: selectedId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                Uri(
                  path: '/gallery/upload',
                  queryParameters: {
                    'targetType': targetType,
                    'targetId': selectedId,
                    'routeId': targetType == 'route' ? selectedId : '',
                    'spotId': targetType == 'spot' ? selectedId : '',
                  },
                ).toString(),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('사진 올리기'),
            ),
    );
  }

  void _openPhotoViewer(
    BuildContext context,
    List<GalleryPhoto> photos,
    int initialIndex,
    String categoryTitle,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GalleryPhotoViewerScreen(
          photos: photos,
          initialIndex: initialIndex,
          categoryTitle: categoryTitle,
        ),
      ),
    );
  }

  Future<void> _toggleLike(BuildContext context, GalleryPhoto photo) async {
    try {
      final repository = ref.read(galleryRepositoryProvider);
      final auth = ref.read(firebaseAuthProvider);
      final userId =
          auth?.currentUser?.uid ??
          (await auth?.signInAnonymously())?.user?.uid;
      if (repository == null || userId == null) {
        throw StateError('Firebase unavailable');
      }
      await repository.toggleLike(photo.id, userId);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('좋아요를 반영하지 못했어요.')));
    }
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid({
    required this.photos,
    required this.onLike,
    required this.onPhotoTap,
  });

  final List<GalleryPhoto> photos;
  final ValueChanged<GalleryPhoto> onLike;
  final void Function(int index, List<GalleryPhoto> photos) onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final title = photo.description.trim().isEmpty
            ? '제목 없음'
            : photo.description.trim();
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: () => onPhotoTap(index, photos),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PhotoThumb(imageUrl: photo.imageUrl, borderRadius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.48, 1],
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 6,
                    bottom: 7,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '좋아요 ${photo.likeCount}',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          onPressed: () => onLike(photo),
                          color: Colors.white,
                          icon: Icon(
                            photo.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: photo.isLiked
                                ? Colors.redAccent
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _routeLabel(B4ySampleData? data, String? routeId, {String? fallback}) {
  final route = data?.routes.where((route) => route.id == routeId).firstOrNull;
  return route == null ? fallback ?? '노선' : '${route.number}번';
}

String _spotLabel(B4ySampleData? data, String? spotId) {
  final spot = data?.touristSpots
      .where((spot) => spot.id == spotId)
      .firstOrNull;
  return spot?.name ?? '관광지';
}
