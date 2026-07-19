import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/b4y_providers.dart';
import '../../data/engagement_repository.dart';
import '../../domain/b4y_models.dart';
import '../widgets/engagement_card.dart';

enum ReviewSort { popular, latest }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.spotId});

  final String spotId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  ReviewSort _sort = ReviewSort.popular;

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(reviewsForSpotProvider(widget.spotId));
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/spots/${widget.spotId}/reviews/new'),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('리뷰 작성'),
      ),
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('리뷰를 불러오지 못했어요.')),
        data: (source) {
          final reviews = _sort == ReviewSort.popular
              ? sortReviews(source)
              : ([...source]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('관광지 리뷰', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              SegmentedButton<ReviewSort>(
                segments: const [
                  ButtonSegment(value: ReviewSort.popular, label: Text('인기순')),
                  ButtonSegment(value: ReviewSort.latest, label: Text('최신순')),
                ],
                selected: {_sort},
                onSelectionChanged: (value) =>
                    setState(() => _sort = value.first),
              ),
              const SizedBox(height: 16),
              if (reviews.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(child: Text('아직 리뷰가 없어요. 첫 리뷰를 작성해 보세요.')),
                )
              else
                for (final review in reviews)
                  ReviewCard(
                    review: review,
                    onLike: () => _toggleLike(context, ref, review),
                    onTap: () => context.go(
                      '/spots/${widget.spotId}/reviews/${review.id}',
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _toggleLike(
  BuildContext context,
  WidgetRef ref,
  Review review,
) async {
  final repository = ref.read(engagementRepositoryProvider);
  final auth = ref.read(firebaseAuthProvider);
  try {
    final user = auth?.currentUser ?? (await auth?.signInAnonymously())?.user;
    if (repository == null || user == null) {
      throw StateError('Firebase unavailable');
    }
    await repository.toggleReviewLike(review.id, user.uid);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('좋아요를 반영하지 못했어요.')));
    }
  }
}
