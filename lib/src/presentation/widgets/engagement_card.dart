import 'package:flutter/material.dart';

import '../../domain/b4y_models.dart';
import 'photo_thumb.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.onLike,
    this.heading,
    this.onTap,
    this.onMore,
  });

  final Review review;
  final VoidCallback? onLike;
  final String? heading;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return _EngagementCard(
      heading: heading,
      title: review.title.trim().isEmpty ? '제목 없는 리뷰' : review.title,
      author: review.authorNickname,
      meta: '종합 평점 ${_formatRating(review.overallRating)}',
      supportingText: review.body.trim().isEmpty ? null : review.body.trim(),
      imageDataUrl: review.allImageDataUrls.firstOrNull,
      actions: [
        _CountButton(
          icon: review.isLiked ? Icons.favorite : Icons.favorite_border,
          label: '좋아요 ${review.likeCount}',
          selected: review.isLiked,
          onPressed: onLike,
        ),
      ],
      onTap: onTap,
      onMore: onMore,
    );
  }
}

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.onLike,
    required this.onVerify,
    this.heading,
    this.onTap,
    this.onMore,
  });

  final Mission mission;
  final VoidCallback? onLike;
  final VoidCallback? onVerify;
  final String? heading;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return _EngagementCard(
      heading: heading,
      title: mission.title.trim().isEmpty ? '제목 없는 미션' : mission.title,
      author: mission.authorNickname,
      meta:
          '난이도 ${mission.difficulty} · 인증 ${mission.verificationMethod == 'location' ? '현위치' : '사진'}',
      supportingText: mission.body.trim().isEmpty ? null : mission.body.trim(),
      tags: mission.missionTags,
      imageDataUrl: mission.imageDataUrl,
      actions: [
        _CountButton(
          icon: mission.isLiked ? Icons.favorite : Icons.favorite_border,
          label: '좋아요 ${mission.likeCount}',
          selected: mission.isLiked,
          onPressed: onLike,
        ),
        _CountButton(
          icon: mission.isVerified ? Icons.verified : Icons.verified_outlined,
          label: '인증 ${mission.verificationCount}',
          selected: mission.isVerified,
          onPressed: onVerify,
        ),
      ],
      onTap: onTap,
      onMore: onMore,
    );
  }
}

class EmptyEngagementCard extends StatelessWidget {
  const EmptyEngagementCard({
    super.key,
    required this.heading,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String heading;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({
    required this.title,
    required this.author,
    required this.imageDataUrl,
    required this.actions,
    this.heading,
    this.meta,
    this.supportingText,
    this.tags = const [],
    this.onTap,
    this.onMore,
  });

  final String title;
  final String author;
  final String? imageDataUrl;
  final List<Widget> actions;
  final String? heading;
  final String? meta;
  final String? supportingText;
  final List<String> tags;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heading != null) ...[
                Text(heading!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 104),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            author,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (meta != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              meta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (supportingText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              supportingText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final tag in tags.take(3))
                                  Chip(
                                    label: Text(tag),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(spacing: 4, children: actions),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imageDataUrl == null || imageDataUrl!.isEmpty
                        ? const PhotoPlaceholder(width: 104, height: 104)
                        : PhotoThumb(
                            imageUrl: imageDataUrl!,
                            width: 104,
                            height: 104,
                            borderRadius: 0,
                          ),
                  ),
                ],
              ),
              if (onMore != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onMore,
                    child: const Text('더보기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatRating(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 34),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: selected ? Colors.red : null),
      label: Text(label),
    );
  }
}
