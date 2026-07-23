import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../application/b4y_providers.dart';
import '../../data/engagement_repository.dart';
import '../../domain/b4y_models.dart';
import '../widgets/kakao_map_view.dart';
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
    final kakaoMapKey =
        ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
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
              if (mission.verificationMethod == 'location') ...[
                const SizedBox(height: 18),
                if (mission.selectedLat != null && mission.selectedLng != null)
                  _MissionLocationMap(
                    point: LatLng(mission.selectedLat!, mission.selectedLng!),
                    kakaoMapKey: kakaoMapKey,
                    label: mission.targetName,
                  )
                else
                  const Text('誘몄뀡 ?꾩튂 吏?꾩씠 ?놁뒿?덈떎.'),
              ],
              const SizedBox(height: 18),
              _MissionGroupPanel(mission: mission),
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

class _MissionGroupPanel extends ConsumerWidget {
  const _MissionGroupPanel({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(missionGroupProvider(mission.id));
    return group.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) => Text(
        '함께하기 정보를 불러오지 못했어요.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (value) => value == null
          ? _MissionGroupStartActions(mission: mission)
          : _MissionGroupActiveCard(mission: mission, group: value),
    );
  }
}

class _MissionGroupStartActions extends ConsumerWidget {
  const _MissionGroupStartActions({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('친구와 함께하기', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _createGroup(context, ref),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('그룹 만들기'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/mission-groups/join?missionId=${Uri.encodeComponent(mission.id)}',
                ),
                icon: const Icon(Icons.login_outlined),
                label: const Text('코드 참여'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth?.currentUser;
    if (user == null || user.isAnonymous) {
      if (context.mounted) context.push('/login');
      return;
    }
    final repository = ref.read(engagementRepositoryProvider);
    if (repository == null) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    try {
      final group = await repository.createMissionGroup(
        missionId: mission.id,
        userId: user.uid,
        nickname: profile?.nickname.trim().isNotEmpty == true
            ? profile!.nickname
            : (user.displayName ?? '참여자'),
      );
      ref.invalidate(missionGroupProvider(mission.id));
      if (context.mounted) {
        await Clipboard.setData(ClipboardData(text: group.inviteCode));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 코드 ${group.inviteCode}를 복사했어요.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }
}

class _MissionGroupActiveCard extends ConsumerWidget {
  const _MissionGroupActiveCard({required this.mission, required this.group});

  final Mission mission;
  final MissionGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authUserProvider).valueOrNull?.uid;
    final me = group.members
        .where((member) => member.uid == userId)
        .firstOrNull;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.isCompleted ? '함께하기 완료' : '친구와 함께하기',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (group.isCompleted)
                  const Icon(Icons.verified, color: Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '코드: ${group.inviteCode}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: '코드 복사',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: group.inviteCode),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('초대 코드를 복사했어요.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
            for (final member in group.members)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  member.verified
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: member.verified ? Colors.green : null,
                ),
                title: Text(member.nickname),
                subtitle: Text(member.verified ? '인증 완료' : '인증 대기'),
              ),
            if (me != null && !group.isCompleted)
              FilledButton.icon(
                onPressed: () => _toggleVerification(context, ref),
                icon: Icon(me.verified ? Icons.undo : Icons.verified_outlined),
                label: Text(me.verified ? '내 인증 취소' : '내 인증 완료'),
              ),
            if (!group.isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _leaveGroup(context, ref),
                  child: const Text('그룹 나가기'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVerification(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(engagementRepositoryProvider);
    final user = ref.read(authUserProvider).valueOrNull;
    if (repository == null || user == null) return;
    try {
      await repository.toggleMissionGroupVerification(
        groupId: group.id,
        userId: user.uid,
      );
      ref.invalidate(missionGroupProvider(mission.id));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _leaveGroup(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authUserProvider).valueOrNull;
    final repository = ref.read(engagementRepositoryProvider);
    if (user == null || repository == null) return;
    await repository.leaveMissionGroup(groupId: group.id, userId: user.uid);
    ref.invalidate(missionGroupProvider(mission.id));
  }
}

class MissionGroupJoinScreen extends ConsumerStatefulWidget {
  const MissionGroupJoinScreen({super.key, this.missionId = ''});

  final String missionId;

  @override
  ConsumerState<MissionGroupJoinScreen> createState() =>
      _MissionGroupJoinScreenState();
}

class _MissionGroupJoinScreenState
    extends ConsumerState<MissionGroupJoinScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구와 함께하기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('친구에게 받은 6자리 코드를 입력해 주세요.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '참여 코드',
              border: OutlineInputBorder(),
            ),
          ),
          if (_message != null)
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _join,
            child: Text(_busy ? '참여 중...' : '그룹 참여하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _join() async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth?.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) context.push('/login');
      return;
    }
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _message = '6자리 코드를 입력해 주세요.');
      return;
    }
    final repository = ref.read(engagementRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final group = await repository.joinMissionGroup(
        inviteCode: code,
        userId: user.uid,
        nickname: profile?.nickname.trim().isNotEmpty == true
            ? profile!.nickname
            : (user.displayName ?? '참여자'),
      );
      if (widget.missionId.isNotEmpty && group.missionId != widget.missionId) {
        throw StateError('다른 미션의 초대 코드예요.');
      }
      if (mounted) context.pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MissionLocationMap extends StatelessWidget {
  const _MissionLocationMap({
    required this.point,
    required this.kakaoMapKey,
    required this.label,
  });

  final LatLng point;
  final String kakaoMapKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('미션 위치', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: KakaoMapView(
              apiKey: kakaoMapKey,
              center: point,
              zoom: 5,
              fitToContent: true,
              fitPoints: [point],
              fitCenter: point,
              markers: [
                KakaoMapMarker(
                  id: 'mission-location',
                  point: point,
                  kind: 'selectedLocation',
                  title: label.trim().isEmpty
                      ? '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}'
                      : label.trim(),
                  accentColor: colorScheme.error,
                ),
              ],
              fallback: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: [point],
                    padding: EdgeInsets.zero,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.b4y',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.location_pin,
                          size: 42,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
