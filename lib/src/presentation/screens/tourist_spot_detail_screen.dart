import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../application/b4y_providers.dart';
import '../../data/engagement_repository.dart';
import '../../domain/b4y_models.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/engagement_card.dart';
import '../widgets/photo_thumb.dart';
import 'photo_viewer_screen.dart';

class TouristSpotDetailScreen extends ConsumerWidget {
  const TouristSpotDetailScreen({super.key, required this.spotId});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(b4yDataProvider);
    return data.when(
      data: (sampleData) {
        final spot = sampleData.spotById(spotId);
        final routePlan = ref.watch(spotRoutePlanProvider(spotId));
        final kakaoMapKey =
            ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
        final reviews =
            ref.watch(reviewsForSpotProvider(spotId)).valueOrNull ??
            const <Review>[];
        final missions =
            ref.watch(missionsForSpotProvider(spotId)).valueOrNull ??
            const <Mission>[];
        final gallery =
            ref.watch(galleryForSpotProvider(spotId)).valueOrNull ??
            const <GalleryPhoto>[];
        final bestReview = reviews.isEmpty ? null : reviews.first;
        final bestMission = topRepresentativeMission(missions);
        final bestPhoto = sortedGalleryPhotos(
          gallery,
          GallerySort.popular,
        ).cast<GalleryPhoto?>().firstOrNull;

        return Scaffold(
          appBar: AppBar(title: Text(spot.name)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Semantics(
                button: true,
                label: '관광지 사진 전체보기',
                child: InkWell(
                  key: const Key('tourist-spot-hero-photo'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => FullScreenPhotoScreen(
                        imageUrl: spot.heroImageUrl,
                        title: spot.name,
                      ),
                    ),
                  ),
                  child: PhotoThumb(
                    imageUrl: spot.heroImageUrl,
                    width: double.infinity,
                    height: 240,
                    borderRadius: 0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(spot.address.isEmpty ? '주소 정보가 없습니다.' : spot.address),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 220,
                      child: Semantics(
                        button: true,
                        label: '관광지 지도 전체화면',
                        child: GestureDetector(
                          key: const Key('tourist-spot-map-preview'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (context) => _FullScreenSpotMap(
                                spot: spot,
                                overlay: routePlan?.overlay,
                                visibleRouteStops: routePlan?.visibleStops,
                                boardingStop: routePlan?.boardingStop,
                                alightingStop: routePlan?.alightingStop,
                                kakaoMapKey: kakaoMapKey,
                              ),
                            ),
                          ),
                          child: IgnorePointer(
                            child: _SpotMapPreview(
                              spot: spot,
                              overlay: routePlan?.overlay,
                              visibleRouteStops: routePlan?.visibleStops,
                              boardingStop: routePlan?.boardingStop,
                              alightingStop: routePlan?.alightingStop,
                              kakaoMapKey: kakaoMapKey,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (routePlan != null) ...[
                      const SizedBox(height: 12),
                      _RouteStrip(plan: routePlan),
                    ],
                    const SizedBox(height: 18),
                    if (bestReview != null)
                      ReviewCard(
                        heading: '대표 리뷰',
                        review: bestReview,
                        onTap: () => context.go(
                          '/spots/$spotId/reviews/${bestReview.id}',
                        ),
                        onLike: () =>
                            _toggleReviewLike(context, ref, bestReview),
                        onMore: () => context.go('/spots/$spotId/reviews'),
                      )
                    else
                      EmptyEngagementCard(
                        heading: '대표 리뷰',
                        message: '아직 리뷰가 없어요.',
                        actionLabel: '첫 리뷰 작성하기',
                        onAction: () =>
                            context.go('/spots/$spotId/reviews/new'),
                      ),
                    if (bestMission != null)
                      MissionCard(
                        heading: '대표 미션',
                        mission: bestMission,
                        onTap: () => context.go(
                          '/spots/$spotId/missions/${bestMission.id}',
                        ),
                        onLike: () => _toggleMissionReaction(
                          context,
                          ref,
                          bestMission,
                          verification: false,
                        ),
                        onVerify: () => _toggleMissionReaction(
                          context,
                          ref,
                          bestMission,
                          verification: true,
                        ),
                        onMore: () => context.go('/spots/$spotId/missions'),
                      )
                    else
                      EmptyEngagementCard(
                        heading: '대표 미션',
                        message: '아직 대표 점수가 있는 미션이 없어요.',
                        actionLabel: '미션 제안하기',
                        onAction: () =>
                            context.go('/spots/$spotId/missions/new'),
                      ),
                    if (bestPhoto != null)
                      _GalleryPreviewCard(
                        photo: bestPhoto,
                        onAction: () => context.go('/spots/$spotId/gallery'),
                      )
                    else
                      EmptyEngagementCard(
                        heading: '갤러리',
                        message: '아직 공유된 사진이 없어요.',
                        actionLabel: '갤러리 열기',
                        onAction: () => context.go('/spots/$spotId/gallery'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('관광지를 불러오지 못했어요: $error'))),
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

Future<void> _toggleMissionReaction(
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

class _FullScreenSpotMap extends ConsumerWidget {
  const _FullScreenSpotMap({
    required this.spot,
    required this.overlay,
    required this.visibleRouteStops,
    required this.boardingStop,
    required this.alightingStop,
    required this.kakaoMapKey,
  });

  final TouristSpot spot;
  final RouteMapOverlay? overlay;
  final List<BusStop>? visibleRouteStops;
  final BusStop? boardingStop;
  final BusStop? alightingStop;
  final String kakaoMapKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = ref.watch(currentLocationProvider).valueOrNull;
    final selectedLocation = ref.watch(mapSearchCenterProvider);
    return Scaffold(
      key: const Key('full-screen-spot-map'),
      appBar: AppBar(title: Text('${spot.name} 지도')),
      body: _SpotMapPreview(
        spot: spot,
        overlay: overlay,
        visibleRouteStops: visibleRouteStops,
        boardingStop: boardingStop,
        alightingStop: alightingStop,
        kakaoMapKey: kakaoMapKey,
        interactive: true,
        borderRadius: 0,
        currentLocation: currentLocation,
        selectedLocation: selectedLocation,
      ),
    );
  }
}

class _SpotMapPreview extends StatelessWidget {
  const _SpotMapPreview({
    required this.spot,
    required this.overlay,
    required this.alightingStop,
    required this.kakaoMapKey,
    this.visibleRouteStops,
    this.boardingStop,
    this.interactive = false,
    this.borderRadius = 8,
    this.currentLocation,
    this.selectedLocation,
  });

  final TouristSpot spot;
  final RouteMapOverlay? overlay;
  final List<BusStop>? visibleRouteStops;
  final BusStop? boardingStop;
  final BusStop? alightingStop;
  final String kakaoMapKey;
  final bool interactive;
  final double borderRadius;
  final LatLng? currentLocation;
  final LatLng? selectedLocation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleBoardingStop =
        boardingStop != null && isValidMapPoint(boardingStop!.position)
        ? boardingStop
        : null;
    final visibleAlightingStop = _visibleAlightingStop(spot, alightingStop);
    final visibleCurrentLocation =
        currentLocation != null && isValidMapPoint(currentLocation!)
        ? currentLocation
        : null;
    final visibleSelectedLocation =
        selectedLocation != null && isValidMapPoint(selectedLocation!)
        ? selectedLocation
        : null;
    final visibleOriginLocation =
        visibleSelectedLocation ?? visibleCurrentLocation;
    final visibleRouteShape = overlay == null
        ? const <LatLng>[]
        : _routeSegmentShape(overlay!, visibleRouteStops);
    final visiblePathShape = _detailPathShape(
      spot: spot,
      routeShape: visibleRouteShape,
      originLocation: visibleOriginLocation,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: KakaoMapView(
        apiKey: kakaoMapKey,
        center: spot.position,
        zoom: 5,
        interactive: interactive,
        fitToContent:
            visibleBoardingStop != null ||
            visibleAlightingStop != null ||
            visibleCurrentLocation != null ||
            visibleSelectedLocation != null,
        fitPoints: [
          spot.position,
          if (visibleBoardingStop != null) visibleBoardingStop.position,
          if (visibleAlightingStop != null) visibleAlightingStop.position,
          ?visibleCurrentLocation,
          ?visibleSelectedLocation,
        ],
        fitCenter: spot.position,
        polylines: [
          if (overlay != null)
            KakaoMapPolyline(
              points: visiblePathShape,
              color: colorScheme.primary,
              strokeWidth: 4,
            ),
        ],
        markers: [
          KakaoMapMarker(
            id: '',
            point: spot.position,
            kind: 'detailSpot',
            accentColor: colorScheme.error,
          ),
          if (visibleBoardingStop != null)
            KakaoMapMarker(
              id: '',
              point: visibleBoardingStop.position,
              kind: 'boardingStop',
              title: '승차 · ${visibleBoardingStop.name}',
              accentColor: colorScheme.secondary,
            ),
          if (visibleAlightingStop != null)
            KakaoMapMarker(
              id: '',
              point: visibleAlightingStop.position,
              kind: 'nearestStop',
              title: '하차 · ${visibleAlightingStop.name}',
              accentColor: colorScheme.primary,
            ),
          if (visibleCurrentLocation != null)
            KakaoMapMarker(
              id: '',
              point: visibleCurrentLocation,
              kind: 'currentLocation',
            ),
          if (visibleSelectedLocation != null)
            KakaoMapMarker(
              id: '',
              point: visibleSelectedLocation,
              kind: 'selectedLocation',
              title: '선택 위치',
              accentColor: colorScheme.tertiary,
            ),
        ],
        fallback: FlutterMap(
          options: MapOptions(
            initialCenter: spot.position,
            initialZoom: 13.2,
            initialCameraFit:
                visibleBoardingStop == null &&
                    visibleAlightingStop == null &&
                    visibleCurrentLocation == null &&
                    visibleSelectedLocation == null
                ? null
                : CameraFit.coordinates(
                    coordinates: _centeredFitCoordinates(spot.position, [
                      if (visibleBoardingStop != null)
                        visibleBoardingStop.position,
                      if (visibleAlightingStop != null)
                        visibleAlightingStop.position,
                      ?visibleCurrentLocation,
                      ?visibleSelectedLocation,
                    ]),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 56,
                      vertical: 48,
                    ),
                    maxZoom: 13.2,
                  ),
            interactionOptions: InteractionOptions(
              flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.b4y',
            ),
            if (overlay != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: visiblePathShape,
                    color: colorScheme.primary,
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: spot.position,
                  width: 32,
                  height: 32,
                  child: _SpotPointer(color: colorScheme.error),
                ),
                if (visibleBoardingStop != null)
                  Marker(
                    point: visibleBoardingStop.position,
                    width: 110,
                    height: 48,
                    child: _StopMapMarker(
                      label: '승차 · ${visibleBoardingStop.name}',
                      color: colorScheme.secondary,
                    ),
                  ),
                if (visibleAlightingStop != null)
                  Marker(
                    point: visibleAlightingStop.position,
                    width: 110,
                    height: 48,
                    child: _StopMapMarker(
                      label: '하차 · ${visibleAlightingStop.name}',
                      color: colorScheme.primary,
                    ),
                  ),
                if (visibleCurrentLocation != null)
                  Marker(
                    point: visibleCurrentLocation,
                    width: 42,
                    height: 42,
                    child: const _CurrentLocationMarker(),
                  ),
                if (visibleSelectedLocation != null)
                  Marker(
                    point: visibleSelectedLocation,
                    width: 110,
                    height: 48,
                    child: _StopMapMarker(
                      label: '선택 위치',
                      color: colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _maxDetailStopDistanceMeters = 3000.0;

List<LatLng> _centeredFitCoordinates(
  LatLng center,
  Iterable<LatLng> otherPoints,
) {
  return [
    center,
    for (final other in otherPoints) ...[
      other,
      LatLng(
        (2 * center.latitude) - other.latitude,
        (2 * center.longitude) - other.longitude,
      ),
    ],
  ];
}

BusStop? _visibleAlightingStop(TouristSpot spot, BusStop? alightingStop) {
  if (alightingStop == null ||
      !isValidMapPoint(spot.position) ||
      !isValidMapPoint(alightingStop.position)) {
    return null;
  }
  const distance = Distance();
  return distance(spot.position, alightingStop.position) <=
          _maxDetailStopDistanceMeters
      ? alightingStop
      : null;
}

List<LatLng> _routeSegmentShape(
  RouteMapOverlay overlay,
  List<BusStop>? visibleStops,
) {
  if (visibleStops == null || visibleStops.length < 2) {
    return overlay.shape;
  }

  final stops = visibleStops
      .where((stop) => isValidMapPoint(stop.position))
      .toList();
  if (stops.length < 2) {
    return overlay.shape;
  }

  final startPoint = stops.first.position;
  final endPoint = stops.last.position;
  final shape = overlay.shape.where(isValidMapPoint).toList();
  if (shape.length < 2) {
    return [startPoint, endPoint];
  }

  final startIndex = _nearestShapePointIndex(shape, startPoint);
  final endIndex = _nearestShapePointIndex(shape, endPoint);
  final segment = startIndex <= endIndex
      ? shape.sublist(startIndex, endIndex + 1)
      : shape.sublist(endIndex, startIndex + 1).reversed.toList();
  if (segment.length < 2) {
    return [startPoint, endPoint];
  }

  final middle = segment.length > 2
      ? segment.sublist(1, segment.length - 1)
      : const <LatLng>[];
  return [startPoint, ...middle, endPoint];
}

List<LatLng> _detailPathShape({
  required TouristSpot spot,
  required List<LatLng> routeShape,
  required LatLng? originLocation,
}) {
  final points = <LatLng>[
    if (originLocation != null && isValidMapPoint(originLocation))
      originLocation,
    ...routeShape.where(isValidMapPoint),
    if (isValidMapPoint(spot.position)) spot.position,
  ];
  if (points.length < 2) {
    return routeShape;
  }

  final deduped = <LatLng>[];
  for (final point in points) {
    if (deduped.isEmpty || !_sameMapPoint(deduped.last, point)) {
      deduped.add(point);
    }
  }
  return deduped;
}

bool _sameMapPoint(LatLng a, LatLng b) {
  return (a.latitude - b.latitude).abs() < 0.000001 &&
      (a.longitude - b.longitude).abs() < 0.000001;
}

int _nearestShapePointIndex(List<LatLng> shape, LatLng point) {
  const distance = Distance();
  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  for (var index = 0; index < shape.length; index++) {
    final pointDistance = distance(point, shape[index]);
    if (pointDistance < nearestDistance) {
      nearestDistance = pointDistance;
      nearestIndex = index;
    }
  }
  return nearestIndex;
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0x2E2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x612563EB), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 7,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotPointer extends StatelessWidget {
  const _SpotPointer({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(2),
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 7,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopMapMarker extends StatelessWidget {
  const _StopMapMarker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ],
    );
  }
}

class _RouteStrip extends StatefulWidget {
  const _RouteStrip({required this.plan});

  final SpotRoutePlan plan;

  @override
  State<_RouteStrip> createState() => _RouteStripState();
}

class _RouteStripState extends State<_RouteStrip> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plan = widget.plan;
    final canExpand = plan.legs.any((leg) => leg.visibleStops.length > 2);
    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.hasTransfer
                        ? '환승 ${plan.transferCount}회'
                        : plan.overlay.route.number,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.hasTransfer
                        ? '${plan.boardingStop.name} → ${plan.alightingStop.name}'
                        : '${plan.overlay.direction.name} ${plan.overlay.direction.destination}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              children: [
                for (
                  var legIndex = 0;
                  legIndex < plan.legs.length;
                  legIndex++
                ) ...[
                  if (plan.hasTransfer) ...[
                    _RouteLegHeader(leg: plan.legs[legIndex]),
                    const SizedBox(height: 8),
                  ],
                  _RouteLegStops(
                    leg: plan.legs[legIndex],
                    expanded: _expanded,
                    isFirstLeg: legIndex == 0,
                    isLastLeg: legIndex == plan.legs.length - 1,
                  ),
                  if (legIndex < plan.legs.length - 1) ...[
                    const SizedBox(height: 8),
                    _TransferDivider(stop: plan.legs[legIndex].alightingStop),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
            if (canExpand || _expanded) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(_expanded ? '접기' : '더보기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteLegHeader extends StatelessWidget {
  const _RouteLegHeader({required this.leg});

  final SpotRouteLeg leg;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            leg.overlay.route.number,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${leg.overlay.direction.name} ${leg.overlay.direction.destination}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _RouteLegStops extends StatelessWidget {
  const _RouteLegStops({
    required this.leg,
    required this.expanded,
    required this.isFirstLeg,
    required this.isLastLeg,
  });

  final SpotRouteLeg leg;
  final bool expanded;
  final bool isFirstLeg;
  final bool isLastLeg;

  @override
  Widget build(BuildContext context) {
    final stops = expanded
        ? leg.visibleStops
        : [
            leg.boardingStop,
            if (leg.alightingStop.id != leg.boardingStop.id) leg.alightingStop,
          ];
    return Column(
      children: [
        for (var index = 0; index < stops.length; index++)
          _VerticalRouteStopNode(
            stop: stops[index],
            isBoarding: isFirstLeg && stops[index].id == leg.boardingStop.id,
            isAlighting: isLastLeg && stops[index].id == leg.alightingStop.id,
            showConnector: index < stops.length - 1,
          ),
      ],
    );
  }
}

class _TransferDivider extends StatelessWidget {
  const _TransferDivider({required this.stop});

  final BusStop stop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.swap_vert_rounded, size: 18, color: colorScheme.tertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${stop.name}에서 환승',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerticalRouteStopNode extends StatelessWidget {
  const _VerticalRouteStopNode({
    required this.stop,
    required this.isBoarding,
    required this.isAlighting,
    required this.showConnector,
  });

  final BusStop stop;
  final bool isBoarding;
  final bool isAlighting;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = isBoarding || isAlighting;
    final badge = isBoarding && isAlighting
        ? '승하차'
        : isBoarding
        ? '승차'
        : isAlighting
        ? '하차'
        : '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: active ? 18 : 12,
                  height: active ? 18 : 12,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: active
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.surface, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 4,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 18 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stop.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isAlighting
                            ? colorScheme.tertiaryContainer
                            : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isAlighting
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPreviewCard extends StatelessWidget {
  const _GalleryPreviewCard({required this.photo, required this.onAction});

  final GalleryPhoto photo;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PhotoThumb(imageUrl: photo.imageUrl, width: 96, height: 96),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('대표 사진', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(photo.description),
                  Text('좋아요 ${photo.likeCount} · ${photo.authorNickname}'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onAction,
                      child: const Text('갤러리 보기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
