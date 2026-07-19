import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/b4y_providers.dart';
import '../../domain/b4y_models.dart';
import '../widgets/photo_thumb.dart';

class ReviewDetailScreen extends ConsumerWidget {
  const ReviewDetailScreen({
    super.key,
    required this.spotId,
    required this.reviewId,
  });

  final String spotId;
  final String reviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsForSpotProvider(spotId));
    return reviews.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          const Scaffold(body: Center(child: Text('리뷰를 불러오지 못했어요.'))),
      data: (items) {
        final review = items.where((item) => item.id == reviewId).firstOrNull;
        if (review == null) {
          return const Scaffold(body: Center(child: Text('리뷰를 찾지 못했어요.')));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('리뷰')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _PhotoStrip(images: review.allImageDataUrls),
              const SizedBox(height: 18),
              Text(
                review.title.trim().isEmpty ? '제목 없는 리뷰' : review.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(review.authorNickname),
              if (review.visitSeason.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('방문 시기 ${review.visitSeason}'),
              ],
              const SizedBox(height: 16),
              _RatingRow(label: '청결성', value: review.cleanlinessRating),
              _RatingRow(label: '접근성', value: review.accessibilityRating),
              _RatingRow(label: '종합 평점', value: review.overallRating),
              _TagWrap(
                title: '청결성',
                tags: [
                  ...review.cleanlinessTags,
                  if (review.cleanlinessOther.trim().isNotEmpty)
                    review.cleanlinessOther.trim(),
                ],
              ),
              _TagWrap(
                title: '접근성',
                tags: [
                  ...review.accessibilityTags,
                  if (review.accessibilityOther.trim().isNotEmpty)
                    review.accessibilityOther.trim(),
                ],
              ),
              if (review.body.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(review.body.trim()),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _toggleReviewLike(context, ref, review),
                  icon: Icon(
                    review.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: review.isLiked ? Colors.red : null,
                  ),
                  label: Text('좋아요 ${review.likeCount}'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MissionDetailScreen extends ConsumerWidget {
  const MissionDetailScreen({
    super.key,
    this.spotId = '',
    this.routeId = '',
    required this.missionId,
  });

  final String spotId;
  final String routeId;
  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missions = routeId.isNotEmpty
        ? ref.watch(missionsForRouteProvider(routeId))
        : ref.watch(missionsForSpotProvider(spotId));
    return missions.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          const Scaffold(body: Center(child: Text('미션을 불러오지 못했어요.'))),
      data: (items) {
        final mission = items.where((item) => item.id == missionId).firstOrNull;
        if (mission == null) {
          return const Scaffold(body: Center(child: Text('미션을 찾지 못했어요.')));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('미션')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _PhotoStrip(
                images: [
                  if (mission.imageDataUrl?.isNotEmpty == true)
                    mission.imageDataUrl!,
                ],
              ),
              const SizedBox(height: 18),
              Text(
                mission.title.trim().isEmpty ? '제목 없는 미션' : mission.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(mission.authorNickname),
              const SizedBox(height: 16),
              _InfoLine(label: '대상', value: mission.targetName),
              _InfoLine(label: '난이도', value: '${mission.difficulty}'),
              _InfoLine(
                label: '인증 방법',
                value: mission.verificationMethod == 'location' ? '현위치' : '사진',
              ),
              if (mission.verificationMethod == 'location')
                _InfoLine(
                  label: '클리어 반경',
                  value: '${mission.verificationRadiusMeters}m',
                ),
              if (mission.availableStartDate.trim().isNotEmpty &&
                  mission.availableEndDate.trim().isNotEmpty)
                _InfoLine(
                  label: '미션 가능 기간',
                  value:
                      '${mission.availableStartDate} ~ ${mission.availableEndDate}',
                )
              else if (mission.availableSeason.trim().isNotEmpty)
                _InfoLine(label: '미션 가능 시기', value: mission.availableSeason),
              _TagWrap(title: '태그', tags: mission.missionTags),
              _TagWrap(title: '난이도 조건', tags: mission.difficultyTags),
              if (mission.body.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(mission.body.trim()),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleMission(
                      context,
                      ref,
                      mission,
                      verification: false,
                    ),
                    icon: Icon(
                      mission.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: mission.isLiked ? Colors.red : null,
                    ),
                    label: Text('좋아요 ${mission.likeCount}'),
                  ),
                  TextButton.icon(
                    onPressed: () => _toggleMission(
                      context,
                      ref,
                      mission,
                      verification: true,
                    ),
                    icon: Icon(
                      mission.isVerified
                          ? Icons.verified
                          : Icons.verified_outlined,
                    ),
                    label: Text('인증 ${mission.verificationCount}'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: PhotoPlaceholder(width: double.infinity, height: 220),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: PageView(
        children: [
          for (final image in images)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PhotoThumb(
                imageUrl: image,
                width: double.infinity,
                height: 240,
                borderRadius: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return _InfoLine(label: label, value: _formatRating(value));
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in tags) Chip(label: Text(tag))],
          ),
        ],
      ),
    );
  }
}

Future<String?> _engagementUserId(WidgetRef ref) async {
  final auth = ref.read(firebaseAuthProvider);
  return auth?.currentUser?.uid ?? (await auth?.signInAnonymously())?.user?.uid;
}

Future<void> _toggleReviewLike(
  BuildContext context,
  WidgetRef ref,
  Review review,
) async {
  try {
    final repository = ref.read(engagementRepositoryProvider);
    final userId = await _engagementUserId(ref);
    if (repository == null || userId == null) {
      throw StateError('Firebase unavailable');
    }
    await repository.toggleReviewLike(review.id, userId);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('좋아요를 반영하지 못했어요.')));
    }
  }
}

Future<void> _toggleMission(
  BuildContext context,
  WidgetRef ref,
  Mission mission, {
  required bool verification,
}) async {
  try {
    final repository = ref.read(engagementRepositoryProvider);
    final userId = await _engagementUserId(ref);
    if (repository == null || userId == null) {
      throw StateError('Firebase unavailable');
    }
    if (verification) {
      await repository.toggleMissionVerification(mission.id, userId);
    } else {
      await repository.toggleMissionLike(mission.id, userId);
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(verification ? '인증을 반영하지 못했어요.' : '좋아요를 반영하지 못했어요.'),
        ),
      );
    }
  }
}

String _formatRating(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
