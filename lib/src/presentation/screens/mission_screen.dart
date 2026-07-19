import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/b4y_providers.dart';
import '../../data/engagement_repository.dart';
import '../../domain/b4y_models.dart';
import '../widgets/engagement_card.dart';

enum _MissionBrowseTargetType { route, spot }

class MissionScreen extends ConsumerStatefulWidget {
  const MissionScreen({
    super.key,
    this.spotId,
    this.initialRouteId,
    this.routeOnly = false,
    this.touristOnly = false,
  });

  final String? spotId;
  final String? initialRouteId;
  final bool routeOnly;
  final bool touristOnly;

  @override
  ConsumerState<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends ConsumerState<MissionScreen> {
  _MissionBrowseTargetType _targetType = _MissionBrowseTargetType.spot;
  String? _selectedRouteId;
  String? _selectedSpotId;

  bool get _isSpotLocked => widget.spotId != null;
  bool get _isRouteLocked => widget.initialRouteId != null && !_isSpotLocked;

  @override
  void initState() {
    super.initState();
    _targetType = widget.routeOnly
        ? _MissionBrowseTargetType.route
        : _MissionBrowseTargetType.spot;
    _selectedRouteId = widget.initialRouteId;
    _selectedSpotId = widget.spotId;
    if (widget.spotId != null) {
      _targetType = _MissionBrowseTargetType.spot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(b4yDataProvider).valueOrNull;
    final selectedRoute = _selectedRouteId == null || data == null
        ? null
        : _routeByIdOrNull(data, _selectedRouteId!);
    final selectedSpot = _selectedSpotId == null || data == null
        ? null
        : _spotByIdOrNull(data, _selectedSpotId!);
    final missionsAsync = _missionsForSelection();

    return Scaffold(
      appBar: AppBar(title: const Text('미션')),
      floatingActionButton: _isSpotLocked && widget.spotId != null
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.go('/spots/${widget.spotId}/missions/new'),
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('미션 작성'),
            )
          : null,
      body: missionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('미션을 불러오지 못했어요.')),
        data: (source) {
          final popularMissions = sortMissions(source);
          final latestMissions = _sortMissionsByLatest(source);
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, _isSpotLocked ? 96 : 24),
            children: [
              Text(
                _isSpotLocked
                    ? '관광지 미션'
                    : _isRouteLocked
                    ? '노선 미션'
                    : '미션 보기',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (!_isSpotLocked && !_isRouteLocked) ...[
                const SizedBox(height: 14),
                _MissionTargetControls(
                  targetType: _targetType,
                  selectedRoute: selectedRoute,
                  selectedSpot: selectedSpot,
                  routesOnly: widget.routeOnly,
                  spotsOnly: widget.touristOnly,
                  onTargetTypeChanged: (targetType) {
                    setState(() {
                      _targetType = targetType;
                    });
                  },
                  onRouteTap: data == null
                      ? null
                      : () async {
                          final route = await Navigator.of(context)
                              .push<BusRoute>(
                                MaterialPageRoute<BusRoute>(
                                  builder: (context) =>
                                      _RoutePickerScreen(data: data),
                                ),
                              );
                          if (route == null || !context.mounted) return;
                          setState(() {
                            _targetType = _MissionBrowseTargetType.route;
                            _selectedRouteId = route.id;
                          });
                        },
                  onSpotTap: data == null
                      ? null
                      : () async {
                          final spot = await Navigator.of(context)
                              .push<TouristSpot>(
                                MaterialPageRoute<TouristSpot>(
                                  builder: (context) =>
                                      _SpotPickerScreen(data: data),
                                ),
                              );
                          if (spot == null || !context.mounted) return;
                          setState(() {
                            _targetType = _MissionBrowseTargetType.spot;
                            _selectedSpotId = spot.id;
                          });
                        },
                ),
              ],
              const SizedBox(height: 16),
              if (!_isSpotLocked && !_isRouteLocked && _currentTargetId == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(child: Text('노선 또는 관광지를 선택해 주세요.')),
                )
              else if (source.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(child: Text('아직 미션이 없어요.')),
                )
              else ...[
                _MissionListSection(
                  title: '인기순 미션',
                  missions: popularMissions,
                  onOpen: (mission) => _openMissionDetail(context, mission),
                  onLike: (mission) =>
                      _toggleMission(context, ref, mission, verify: false),
                  onVerify: (mission) =>
                      _toggleMission(context, ref, mission, verify: true),
                ),
                const SizedBox(height: 24),
                _MissionListSection(
                  title: '최신순 미션',
                  missions: latestMissions,
                  onOpen: (mission) => _openMissionDetail(context, mission),
                  onLike: (mission) =>
                      _toggleMission(context, ref, mission, verify: false),
                  onVerify: (mission) =>
                      _toggleMission(context, ref, mission, verify: true),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String? get _currentTargetId {
    return _targetType == _MissionBrowseTargetType.route
        ? _selectedRouteId
        : _selectedSpotId;
  }

  AsyncValue<List<Mission>> _missionsForSelection() {
    if (_targetType == _MissionBrowseTargetType.route) {
      final routeId = _selectedRouteId;
      if (routeId == null) return const AsyncData(<Mission>[]);
      return ref.watch(missionsForRouteProvider(routeId));
    }

    final spotId = _selectedSpotId;
    if (spotId == null) return const AsyncData(<Mission>[]);
    return ref.watch(missionsForSpotProvider(spotId));
  }

  void _openMissionDetail(BuildContext context, Mission mission) {
    final spotId = mission.spotId.isNotEmpty ? mission.spotId : _selectedSpotId;
    if (spotId == null || spotId.isEmpty) return;
    context.go('/spots/$spotId/missions/${mission.id}');
  }
}

class _MissionListSection extends StatelessWidget {
  const _MissionListSection({
    required this.title,
    required this.missions,
    required this.onOpen,
    required this.onLike,
    required this.onVerify,
  });

  final String title;
  final List<Mission> missions;
  final ValueChanged<Mission> onOpen;
  final ValueChanged<Mission> onLike;
  final ValueChanged<Mission> onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final mission in missions)
          MissionCard(
            mission: mission,
            onTap: () => onOpen(mission),
            onLike: () => onLike(mission),
            onVerify: () => onVerify(mission),
          ),
      ],
    );
  }
}

class _MissionTargetControls extends StatelessWidget {
  const _MissionTargetControls({
    required this.targetType,
    required this.selectedRoute,
    required this.selectedSpot,
    this.routesOnly = false,
    this.spotsOnly = false,
    required this.onTargetTypeChanged,
    required this.onRouteTap,
    required this.onSpotTap,
  });

  final _MissionBrowseTargetType targetType;
  final BusRoute? selectedRoute;
  final TouristSpot? selectedSpot;
  final bool routesOnly;
  final bool spotsOnly;
  final ValueChanged<_MissionBrowseTargetType> onTargetTypeChanged;
  final VoidCallback? onRouteTap;
  final VoidCallback? onSpotTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!routesOnly && !spotsOnly)
          SegmentedButton<_MissionBrowseTargetType>(
            segments: const [
              ButtonSegment(
                value: _MissionBrowseTargetType.route,
                label: Text('노선'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
              ButtonSegment(
                value: _MissionBrowseTargetType.spot,
                label: Text('관광지'),
                icon: Icon(Icons.place_outlined),
              ),
            ],
            selected: {targetType},
            onSelectionChanged: (value) => onTargetTypeChanged(value.first),
          ),
        if (!routesOnly && !spotsOnly) const SizedBox(height: 10),
        if (!spotsOnly && (routesOnly || targetType == _MissionBrowseTargetType.route))
          OutlinedButton.icon(
            onPressed: onRouteTap,
            icon: const Icon(Icons.directions_bus_outlined),
            label: Text(
              selectedRoute == null
                  ? '노선 선택'
                  : '${selectedRoute!.number}번 · ${selectedRoute!.destination}',
            ),
          ),
        if (!routesOnly && (spotsOnly || targetType == _MissionBrowseTargetType.spot))
          OutlinedButton.icon(
            onPressed: onSpotTap,
            icon: const Icon(Icons.place_outlined),
            label: Text(selectedSpot == null ? '관광지 선택' : selectedSpot!.name),
          ),
      ],
    );
  }
}

class _RoutePickerScreen extends ConsumerStatefulWidget {
  const _RoutePickerScreen({required this.data});

  final B4ySampleData data;

  @override
  ConsumerState<_RoutePickerScreen> createState() => _RoutePickerScreenState();
}

class _RoutePickerScreenState extends ConsumerState<_RoutePickerScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final routes = query.isEmpty
        ? const AsyncData(<BusRoute>[])
        : ref.watch(regionalRouteSearchProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('노선 선택')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '노선 검색',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (query.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('시흥·안산 노선 번호를 입력해 주세요.')),
            )
          else
            routes.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('노선을 불러오지 못했어요.')),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('검색된 노선이 없어요.')),
                    )
                  : Column(
                      children: [
                        for (final route in items)
                          ListTile(
                            leading: const Icon(Icons.directions_bus_outlined),
                            title: Text('${route.number}번'),
                            subtitle: Text(route.destination),
                            onTap: () => Navigator.of(context).pop(route),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _SpotPickerScreen extends StatefulWidget {
  const _SpotPickerScreen({required this.data});

  final B4ySampleData data;

  @override
  State<_SpotPickerScreen> createState() => _SpotPickerScreenState();
}

class _SpotPickerScreenState extends State<_SpotPickerScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _normalizeSearchText(_controller.text);
    final spots = widget.data.touristSpots
        .where((spot) {
          if (query.isEmpty) return true;
          return _normalizeSearchText(
            '${spot.name} ${spot.address}',
          ).contains(query);
        })
        .take(30);

    return Scaffold(
      appBar: AppBar(title: const Text('관광지 선택')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '관광지 검색',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          for (final spot in spots)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(spot.name),
              subtitle: Text(spot.address.isEmpty ? '주소 정보 없음' : spot.address),
              onTap: () => Navigator.of(context).pop(spot),
            ),
        ],
      ),
    );
  }
}

Future<void> _toggleMission(
  BuildContext context,
  WidgetRef ref,
  Mission mission, {
  required bool verify,
}) async {
  final repository = ref.read(engagementRepositoryProvider);
  final auth = ref.read(firebaseAuthProvider);
  try {
    final user = auth?.currentUser ?? (await auth?.signInAnonymously())?.user;
    if (repository == null || user == null) {
      throw StateError('Firebase unavailable');
    }
    if (verify) {
      await repository.toggleMissionVerification(mission.id, user.uid);
    } else {
      await repository.toggleMissionLike(mission.id, user.uid);
    }
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(verify ? '인증을 반영하지 못했어요.' : '좋아요를 반영하지 못했어요.')),
      );
    }
  }
}

BusRoute? _routeByIdOrNull(B4ySampleData data, String routeId) {
  for (final route in data.routes) {
    if (route.id == routeId) return route;
  }
  return null;
}

TouristSpot? _spotByIdOrNull(B4ySampleData data, String spotId) {
  for (final spot in data.touristSpots) {
    if (spot.id == spotId) return spot;
  }
  return null;
}

List<Mission> _sortMissionsByLatest(Iterable<Mission> missions) {
  return [...missions]..sort((a, b) {
    final created = b.createdAt.compareTo(a.createdAt);
    if (created != 0) return created;
    return a.id.compareTo(b.id);
  });
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}
