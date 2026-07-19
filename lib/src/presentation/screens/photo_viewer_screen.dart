import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/b4y_providers.dart';
import '../../domain/b4y_models.dart';
import '../widgets/photo_thumb.dart';

class FullScreenPhotoScreen extends StatelessWidget {
  const FullScreenPhotoScreen({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  final String imageUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('full-screen-photo'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: PhotoThumb(
            imageUrl: imageUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            borderRadius: 0,
          ),
        ),
      ),
    );
  }
}

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.clusterId});

  final String clusterId;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(b4yDataProvider);
    return data.when(
      data: (sampleData) {
        final cluster = sampleData.routePhotoClusters.firstWhere(
          (item) => item.id == widget.clusterId,
        );
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text('${_currentIndex + 1}/${cluster.photos.length}'),
          ),
          body: Stack(
            children: [
              PageView.builder(
                itemCount: cluster.photos.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final photo = cluster.photos[index];
                  return Center(
                    child: PhotoThumb(
                      imageUrl: photo.imageUrl,
                      fit: BoxFit.contain,
                      borderRadius: 0,
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _PhotoInfoSheet(
                  photo: cluster.photos[_currentIndex],
                  allPhotos: cluster.photos,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('사진을 불러오지 못했어요: $error'))),
    );
  }
}

class _PhotoInfoSheet extends StatelessWidget {
  const _PhotoInfoSheet({required this.photo, required this.allPhotos});

  final B4yPhoto photo;
  final List<B4yPhoto> allPhotos;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.16,
      minChildSize: 0.13,
      maxChildSize: 0.48,
      builder: (context, controller) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _showVerificationUpload(context),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('사진 인증'),
              ),
              const SizedBox(height: 16),
              Text(
                photo.authorNickname,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(photo.description.isEmpty ? '설명 없음' : photo.description),
              const SizedBox(height: 16),
              Text('인증사진', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              for (final item in allPhotos)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PhotoThumb(
                    imageUrl: item.imageUrl,
                    width: 56,
                    height: 56,
                  ),
                  title: Text(item.authorNickname),
                  subtitle: Text(item.description),
                  trailing: Text('좋아요 ${item.likeCount}'),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showVerificationUpload(BuildContext context) async {
  final titleController = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사진 인증 올리기', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('사진 선택'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '간단한 설명',
                hintText: '입력하지 않아도 됩니다',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('올리기'),
              ),
            ),
          ],
        ),
      );
    },
  );
  titleController.dispose();
}
