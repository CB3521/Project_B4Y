import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../application/b4y_providers.dart';
import '../../domain/b4y_models.dart';
import '../../domain/route_segments.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/photo_thumb.dart';
import 'tourist_spot_detail_screen.dart';
import 'gallery_photo_viewer_screen.dart';

final _mainMapRevisionProvider = StateProvider<int>((ref) => 0);
const _homeMissionTagOptions = [
  '#시흥',
  '#안산',
  '#접근성좋음',
  '#풍경맛집',
  '#테마파크',
  '#GPS',
];

class HomeMissionFilter {
  const HomeMissionFilter({this.title = '', this.tags = const {}});

  final String title;
  final Set<String> tags;

  bool get isActive => title.trim().isNotEmpty || tags.isNotEmpty;
}

final homeMissionFilterProvider = StateProvider<HomeMissionFilter>(
  (ref) => const HomeMissionFilter(),
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(b4yDataProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: const _MyPageButton(),
        titleSpacing: 8,
        title: const _LocationAddressLabel(),
        actions: const [_HomeModeSelector(), _LocationPickerButton()],
      ),
      body: data.when(
        data: (sampleData) => _HomeBody(data: sampleData),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('데이터를 불러오지 못했어요: $error')),
      ),
    );
  }
}

class _MyPageButton extends ConsumerWidget {
  const _MyPageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final photoDataUrl = profile?.isComplete == true
        ? profile?.photoDataUrl
        : null;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Center(
        child: Material(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('my-page-button'),
            onTap: () {
              final user = ref.read(authUserProvider).valueOrNull;
              context.go(user != null && !user.isAnonymous ? '/my' : '/login');
            },
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 42,
              height: 42,
              child: photoDataUrl == null || photoDataUrl.isEmpty
                  ? Icon(
                      Icons.person_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : PhotoThumb(
                      imageUrl: photoDataUrl,
                      width: 42,
                      height: 42,
                      borderRadius: 999,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationAddressLabel extends ConsumerWidget {
  const _LocationAddressLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation = ref.watch(currentLocationProvider);
    final selectedCenter = ref.watch(mapSearchCenterProvider);
    final location = selectedCenter ?? currentLocation.valueOrNull;
    final address = location == null
        ? null
        : ref.watch(locationAddressProvider(location));
    final text = selectedCenter != null
        ? _locationText(address)
        : currentLocation.isLoading
        ? '위치 확인 중'
        : location == null
        ? '위치 권한 필요'
        : _locationText(address);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }

  String _locationText(AsyncValue<String?>? address) {
    if (address == null || address.isLoading) return '주소 확인 중';
    return address.valueOrNull ?? '주소를 확인할 수 없음';
  }
}

class _LocationPickerButton extends StatelessWidget {
  const _LocationPickerButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: IconButton.filledTonal(
        key: const Key('location-picker-button'),
        tooltip: '위치 선택',
        onPressed: () => _openMapCenterPicker(context),
        icon: const Icon(Icons.edit_location_alt_rounded),
      ),
    );
  }
}

class _HomeModeSelector extends ConsumerWidget {
  const _HomeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeContentModeProvider);
    return Row(
      key: const Key('home-content-mode-selector'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in HomeContentMode.values)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: IconButton.filledTonal(
              key: Key('home-mode-${item.name}'),
              tooltip: _modeLabel(item),
              isSelected: item == mode,
              onPressed: () =>
                  ref.read(homeContentModeProvider.notifier).state = item,
              icon: Icon(_modeIcon(item), size: 20),
              style: IconButton.styleFrom(
                minimumSize: const Size(42, 42),
                maximumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
      ],
    );
  }
}

IconData _modeIcon(HomeContentMode mode) {
  return switch (mode) {
    HomeContentMode.tourist => Icons.place_outlined,
    HomeContentMode.photos => Icons.photo_library_outlined,
    HomeContentMode.missions => Icons.flag_outlined,
  };
}

String _modeLabel(HomeContentMode mode) {
  return switch (mode) {
    HomeContentMode.tourist => '관광지',
    HomeContentMode.photos => '사진',
    HomeContentMode.missions => '미션',
  };
}

bool _matchesHomeMissionFilter(Mission mission, HomeMissionFilter filter) {
  final query = filter.title.trim().toLowerCase();
  if (query.isNotEmpty && !mission.title.toLowerCase().contains(query)) {
    return false;
  }
  return filter.tags.every(mission.missionTags.contains);
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});

  final B4ySampleData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routePanel = _RoutePanel(data: data);
    const mapPanel = _RouteMapPanel();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final panelHeight =
            (availableHeight * (constraints.maxWidth < 620 ? 0.45 : 0.36))
                .clamp(240.0, 360.0)
                .toDouble();
        return Stack(
          children: [
            const Positioned.fill(child: mapPanel),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Material(
                  elevation: 10,
                  color: Theme.of(context).colorScheme.surface,
                  shadowColor: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(height: panelHeight, child: routePanel),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoutePanel extends ConsumerStatefulWidget {
  const _RoutePanel({required this.data});

  final B4ySampleData data;

  @override
  ConsumerState<_RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends ConsumerState<_RoutePanel> {
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _HomeSearchScreen(data: widget.data),
      ),
    );
  }

  Future<void> _openPhotoUploadRoutePicker() async {
    final route = await showModalBottomSheet<BusRoute>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              '사진을 추가할 노선 선택',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final route in widget.data.routes)
              ListTile(
                key: Key('photo-upload-route-${route.id}'),
                leading: const Icon(Icons.directions_bus_rounded),
                title: Text(route.number),
                subtitle: Text(route.destination),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(route),
              ),
          ],
        ),
      ),
    );
    if (!mounted || route == null) return;
    final query = Uri(
      queryParameters: {
        'targetType': 'route',
        'targetId': route.id,
        'routeId': route.id,
      },
    ).query;
    context.push('/gallery/upload?$query');
  }

  void _openRouteMissionComposer() {
    context.push('/route-mission-compose');
  }

  Future<void> _openMissionFilter() async {
    final selection = ref.read(selectedRouteProvider);
    final route = selection == null
        ? null
        : widget.data.routeById(selection.routeId);
    final missions =
        ref.read(homeMissionsProvider(route?.id)).valueOrNull ??
        const <Mission>[];
    final tags = <String>{
      ..._homeMissionTagOptions,
      for (final mission in missions) ...mission.missionTags,
    }.where((tag) => tag.trim().isNotEmpty).toList()..sort();
    final current = ref.read(homeMissionFilterProvider);
    final result = await showModalBottomSheet<HomeMissionFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _HomeMissionFilterSheet(initial: current, availableTags: tags),
    );
    if (!mounted || result == null) return;
    ref.read(homeMissionFilterProvider.notifier).state = result;
  }

  void _returnToCurrentLocation() {
    ref.read(mapSearchCenterProvider.notifier).state = null;
    ref.read(pendingMapCenterProvider.notifier).state = null;
    ref.read(selectedRouteProvider.notifier).state = null;
    ref.read(_mainMapRevisionProvider.notifier).state += 1;
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectedRouteProvider);
    final mode = ref.watch(homeContentModeProvider);
    final data = widget.data;
    final selectedRouteId = selection?.routeId;
    final galleryAsync = mode == HomeContentMode.photos
        ? ref.watch(homeGalleryPhotosProvider(selectedRouteId))
        : null;
    final galleryPhotos = galleryAsync?.valueOrNull ?? const <GalleryPhoto>[];
    final selectedRoute = selection == null
        ? null
        : data.routeById(selection.routeId);
    final selectedDirection = selectedRoute?.directionById(
      ref.watch(selectedDirectionIdProvider) ??
          selectedRoute.defaultDirection.id,
    );
    final selectedCenter = ref.watch(mapSearchCenterProvider);
    final routes = selectedCenter == null
        ? data.routes
        : data.routes
              .where(
                (route) =>
                    _touristSpotsForRoute(data: data, route: route).isNotEmpty,
              )
              .toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (mode != HomeContentMode.tourist && selectedRoute != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('home-direction-selector'),
              initialValue: selectedDirection?.id,
              decoration: const InputDecoration(
                labelText: '방향',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final direction in selectedRoute.directions)
                  DropdownMenuItem(
                    value: direction.id,
                    child: Text('${direction.name} · ${direction.destination}'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref.read(selectedDirectionIdProvider.notifier).state = value;
              },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('home-search-entry'),
                  readOnly: true,
                  canRequestFocus: false,
                  onTap: _openSearch,
                  decoration: const InputDecoration(
                    hintText: '관광지 이름·주소, 버스 노선 검색',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '현위치 근처 노선',
                onPressed: _returnToCurrentLocation,
                icon: const Icon(Icons.my_location_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (mode == HomeContentMode.photos) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('home-add-photo-button'),
                onPressed: _openPhotoUploadRoutePicker,
                icon: const Icon(Icons.add_photo_alternate_rounded),
                label: const Text('사진 추가'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (mode == HomeContentMode.missions) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('home-add-mission-button'),
                    onPressed: _openRouteMissionComposer,
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('미션 추가'),
                  ),
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final filter = ref.watch(homeMissionFilterProvider);
                    return IconButton.filledTonal(
                      key: const Key('home-mission-filter-button'),
                      tooltip: '미션 필터',
                      isSelected: filter.isActive,
                      onPressed: _openMissionFilter,
                      icon: const Icon(Icons.filter_list_rounded),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (selectedRoute != null)
              OutlinedButton.icon(
                key: const Key('home-view-route-missions-button'),
                onPressed: () => context.push(
                  '/route-missions?routeId=${Uri.encodeComponent(selectedRoute.id)}',
                ),
                icon: const Icon(Icons.list_alt_rounded),
                label: Text('${selectedRoute.number}번 미션 확인'),
              ),
          ],
          Text('내 근처 정류장 노선', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final route in routes)
            _RouteCard(
              route: route,
              data: data,
              selected: selection?.routeId == route.id,
              photos: galleryPhotos
                  .where((photo) => photo.routeId == route.id)
                  .toList(),
              photosLoading: galleryAsync?.isLoading == true,
            ),
        ],
      ),
    );
  }
}

class _HomeMissionFilterSheet extends StatefulWidget {
  const _HomeMissionFilterSheet({
    required this.initial,
    required this.availableTags,
  });

  final HomeMissionFilter initial;
  final List<String> availableTags;

  @override
  State<_HomeMissionFilterSheet> createState() =>
      _HomeMissionFilterSheetState();
}

class _HomeMissionFilterSheetState extends State<_HomeMissionFilterSheet> {
  late final TextEditingController _titleController;
  late final Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _selectedTags = {...widget.initial.tags};
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      HomeMissionFilter(
        title: _titleController.text.trim(),
        tags: {..._selectedTags},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              '미션 필터',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('home-mission-title-filter'),
              controller: _titleController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: '미션 제목 검색',
                hintText: '검색할 제목을 입력해 주세요',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.availableTags.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('태그', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in widget.availableTags)
                    FilterChip(
                      key: Key('home-mission-tag-filter-$tag'),
                      label: Text(tag),
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('home-mission-filter-clear'),
                    onPressed: () {
                      setState(() {
                        _titleController.clear();
                        _selectedTags.clear();
                      });
                    },
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: const Key('home-mission-filter-apply'),
                    onPressed: _submit,
                    child: const Text('적용'),
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

class _HomeSearchScreen extends ConsumerStatefulWidget {
  const _HomeSearchScreen({required this.data});

  final B4ySampleData data;

  @override
  ConsumerState<_HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends ConsumerState<_HomeSearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTouristSpot(TouristSpot spot) {
    ref.read(mapSearchCenterProvider.notifier).state = null;
    ref.read(pendingMapCenterProvider.notifier).state = null;
    ref.read(selectedRouteProvider.notifier).state = null;
    ref.read(_mainMapRevisionProvider.notifier).state += 1;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => TouristSpotDetailScreen(spotId: spot.id),
      ),
    );
  }

  void _selectRoute(BusRoute route) {
    ref.read(selectedRouteProvider.notifier).state = SelectedRouteState(
      routeId: route.id,
      directionId: route.defaultDirection.id,
    );
    ref.read(mapSearchCenterProvider.notifier).state = null;
    ref.read(pendingMapCenterProvider.notifier).state = null;
    ref.read(_mainMapRevisionProvider.notifier).state += 1;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(currentLocationProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('검색')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                key: const Key('home-search-input'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '관광지 이름, 버스 노선 검색',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _HomeSearchResults(
                  query: _controller.text,
                  data: widget.data,
                  currentLocation: currentLocation,
                  onRouteTap: _selectRoute,
                  onSpotTap: _selectTouristSpot,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSearchResults extends StatelessWidget {
  const _HomeSearchResults({
    required this.query,
    required this.data,
    required this.currentLocation,
    required this.onRouteTap,
    required this.onSpotTap,
  });

  final String query;
  final B4ySampleData data;
  final LatLng? currentLocation;
  final ValueChanged<BusRoute> onRouteTap;
  final ValueChanged<TouristSpot> onSpotTap;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return const Center(child: Text('검색어를 입력해 주세요.'));
    }

    final routeMatches = _routeMatchesNearLocation(
      data: data,
      query: normalizedQuery,
      currentLocation: currentLocation,
    );
    final spotMatches = data.touristSpots
        .where(
          (spot) => _normalizeSearchText(spot.name).contains(normalizedQuery),
        )
        .toList();

    if (routeMatches.isEmpty && spotMatches.isEmpty) {
      return const Center(child: Text('검색 결과가 없어요.'));
    }

    return ListView(
      children: [
        if (routeMatches.isNotEmpty) ...[
          Text('근처 5km 노선', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final match in routeMatches)
            _SearchRouteTile(
              match: match,
              onTap: () => onRouteTap(match.route),
            ),
        ],
        if (spotMatches.isNotEmpty) ...[
          if (routeMatches.isNotEmpty) const SizedBox(height: 16),
          Text('관광지', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final spot in spotMatches)
            _SearchSpotTile(spot: spot, onTap: () => onSpotTap(spot)),
        ],
      ],
    );
  }
}

class _SearchRouteTile extends StatelessWidget {
  const _SearchRouteTile({required this.match, required this.onTap});

  final _NearbyRouteMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.directions_bus_rounded),
      title: Text(match.route.number),
      subtitle: Text('${match.route.destination} · ${match.stop.name}'),
      onTap: onTap,
    );
  }
}

class _SearchSpotTile extends StatelessWidget {
  const _SearchSpotTile({required this.spot, required this.onTap});

  final TouristSpot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.place_rounded),
      title: Text(spot.name),
      subtitle: spot.address.isEmpty ? null : Text(spot.address),
      onTap: onTap,
    );
  }
}

class _NearbyRouteMatch {
  const _NearbyRouteMatch({required this.route, required this.stop});

  final BusRoute route;
  final BusStop stop;
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

List<_NearbyRouteMatch> _routeMatchesNearLocation({
  required B4ySampleData data,
  required String query,
  required LatLng? currentLocation,
}) {
  if (currentLocation == null) {
    return const [];
  }

  const distance = Distance();
  final stopsById = {for (final stop in data.stops) stop.id: stop};
  final nearestStopByRouteId = <String, ({BusStop stop, double distance})>{};

  for (final route in data.routes) {
    if (!_normalizeSearchText(route.number).startsWith(query)) {
      continue;
    }

    for (final direction in route.directions) {
      for (final stopId in direction.stopIds) {
        final stop = stopsById[stopId];
        if (stop == null) {
          continue;
        }

        final stopDistance = distance(currentLocation, stop.position);
        if (stopDistance > 5000) {
          continue;
        }

        final previous = nearestStopByRouteId[route.id];
        if (previous == null || stopDistance < previous.distance) {
          nearestStopByRouteId[route.id] = (stop: stop, distance: stopDistance);
        }
      }
    }
  }

  final matches = [
    for (final route in data.routes)
      if (nearestStopByRouteId[route.id] != null)
        _NearbyRouteMatch(
          route: route,
          stop: nearestStopByRouteId[route.id]!.stop,
        ),
  ];
  matches.sort(
    (a, b) => nearestStopByRouteId[a.route.id]!.distance.compareTo(
      nearestStopByRouteId[b.route.id]!.distance,
    ),
  );
  return matches;
}

class _RouteCard extends ConsumerWidget {
  const _RouteCard({
    required this.route,
    required this.data,
    required this.selected,
    required this.photos,
    required this.photosLoading,
  });

  final BusRoute route;
  final B4ySampleData data;
  final bool selected;
  final List<GalleryPhoto> photos;
  final bool photosLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(homeContentModeProvider);
    final spots = _touristSpotsForRoute(data: data, route: route);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(selectedRouteProvider.notifier).state = selected
              ? null
              : SelectedRouteState(
                  routeId: route.id,
                  directionId: route.defaultDirection.id,
                );
          if (!selected) {
            ref.read(selectedDirectionIdProvider.notifier).state = null;
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      route.number,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (mode == HomeContentMode.photos)
                    IconButton.filledTonal(
                      key: Key('route-gallery-button-${route.id}'),
                      tooltip: '노선 갤러리',
                      onPressed: () => context.go(
                        Uri(
                          path: '/gallery',
                          queryParameters: {
                            'routeId': route.id,
                            'routeLabel': '${route.number}번',
                          },
                        ).toString(),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                route.destination,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (mode == HomeContentMode.tourist) ...[
                const SizedBox(height: 12),
                _RouteTouristContent(spots: spots),
              ],
              if (mode == HomeContentMode.photos) ...[
                const SizedBox(height: 12),
                _RoutePhotoContent(
                  route: route,
                  data: data,
                  photos: photos,
                  loading: photosLoading,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

List<TouristSpot> _touristSpotsForRoute({
  required B4ySampleData data,
  required BusRoute route,
}) {
  final spotsById = <String, TouristSpot>{};
  for (final direction in route.directions) {
    final overlay = buildRouteMapOverlay(data, route, direction);
    for (final marker in overlay.spotMarkers) {
      spotsById[marker.spot.id] = marker.spot;
    }
  }
  return spotsById.values.toList();
}

class _RouteTouristContent extends StatefulWidget {
  const _RouteTouristContent({required this.spots});

  final List<TouristSpot> spots;

  @override
  State<_RouteTouristContent> createState() => _RouteTouristContentState();
}

class _RouteTouristContentState extends State<_RouteTouristContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.spots.isEmpty) {
      return const Text('연결된 관광지가 없어요.');
    }
    final visibleSpots = _expanded
        ? widget.spots
        : widget.spots.take(1).toList();
    return Column(
      children: [
        for (final spot in visibleSpots)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PhotoThumb(
              imageUrl: spot.heroImageUrl,
              width: 68,
              height: 56,
              borderRadius: 8,
            ),
            title: Text(spot.name),
            subtitle: spot.address.isEmpty ? null : Text(spot.address),
            onTap: () => context.go('/spots/${Uri.encodeComponent(spot.id)}'),
          ),
        if (widget.spots.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? '접기' : '더보기'),
            ),
          ),
      ],
    );
  }
}

class _RoutePhotoContent extends StatelessWidget {
  const _RoutePhotoContent({
    required this.route,
    required this.data,
    required this.photos,
    required this.loading,
  });

  final BusRoute route;
  final B4ySampleData data;
  final List<GalleryPhoto> photos;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading && photos.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (photos.isEmpty) {
      return const Text('등록된 사진이 없어요.');
    }
    final representative = _representativePhoto(photos);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: PhotoThumb(
            imageUrl: representative.imageUrl,
            width: 68,
            height: 56,
            borderRadius: 8,
          ),
          title: Text(
            representative.description.isEmpty
                ? '대표 사진'
                : representative.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${_spotName(data, representative.spotId)} · ${route.number}번 · 좋아요 ${representative.likeCount}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => context.go(
            Uri(
              path: '/gallery',
              queryParameters: {
                'routeId': route.id,
                'routeLabel': '${route.number}번',
              },
            ).toString(),
          ),
        ),
      ],
    );
  }
}

GalleryPhoto _representativePhoto(List<GalleryPhoto> photos) {
  return photos.reduce((current, candidate) {
    if (candidate.likeCount != current.likeCount) {
      return candidate.likeCount > current.likeCount ? candidate : current;
    }
    return candidate.createdAt.isAfter(current.createdAt) ? candidate : current;
  });
}

String _spotName(B4ySampleData data, String spotId) {
  if (spotId.isEmpty) return '관광지 정보 없음';
  return data.touristSpots
          .where((spot) => spot.id == spotId)
          .firstOrNull
          ?.name ??
      '관광지 정보 없음';
}

class _RouteMapPanel extends ConsumerWidget {
  const _RouteMapPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(routeMapOverlaysProvider);
    final mode = ref.watch(homeContentModeProvider);
    final selection = ref.watch(selectedRouteProvider);
    final data = ref.watch(b4yDataProvider).valueOrNull;
    final currentLocation = ref.watch(currentLocationProvider).valueOrNull;
    final selectedCenter = ref.watch(mapSearchCenterProvider);
    final mapRevision = ref.watch(_mainMapRevisionProvider);
    final kakaoMapKey =
        ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
    if (overlays.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedRoute = selection == null || data == null
        ? null
        : data.routeById(selection.routeId);
    final selectedRouteId = selectedRoute?.id;
    final galleryAsync = mode == HomeContentMode.photos
        ? ref.watch(homeGalleryPhotosProvider(selectedRouteId))
        : null;
    final missionsAsync = mode == HomeContentMode.missions
        ? ref.watch(homeMissionsProvider(selectedRouteId))
        : null;
    final selectedDirection = selectedRoute?.directionById(
      ref.watch(selectedDirectionIdProvider) ??
          selectedRoute.defaultDirection.id,
    );
    final mapOverlays =
        mode == HomeContentMode.tourist ||
            selectedRoute == null ||
            selectedDirection == null ||
            data == null
        ? overlays
        : [buildRouteMapOverlay(data, selectedRoute, selectedDirection)];
    final routeLines = _routeLinesFor(mapOverlays);
    final displayPolylines = _splitOverlappingRoutePolylines(routeLines);
    final polylines = [
      for (final line in displayPolylines)
        KakaoMapPolyline(
          points: line.points,
          color: line.color,
          strokeWidth: line.strokeWidth,
        ),
    ];
    final routeCenter = mapOverlays.first.shape.isNotEmpty
        ? mapOverlays.first.shape.first
        : const LatLng(37.3516, 126.7427);
    final center = selectedCenter ?? currentLocation ?? routeCenter;
    final missionFilter = ref.watch(homeMissionFilterProvider);
    final visibleStopMarkers = mode == HomeContentMode.tourist
        ? _visibleStopMarkersFor(routeLines, center)
        : const <_VisibleStopMarker>[];
    final contentMarkers = <KakaoMapMarker>[];
    final segmentTargets =
        <
          String,
          ({
            BusRoute route,
            RouteDirection direction,
            RouteSegment segment,
            List<GalleryPhoto> photos,
          })
        >{};
    final missionSpotTargets = <String, ({String spotId, String missionId})>{};
    if (mode == HomeContentMode.photos && data != null) {
      final photoRoutes = selectedRoute == null
          ? const <BusRoute>[]
          : [selectedRoute];
      for (final route in photoRoutes) {
        final loadedPhotos =
            galleryAsync?.valueOrNull ?? const <GalleryPhoto>[];
        final directions = selectedRoute == route && selectedDirection != null
            ? [selectedDirection]
            : route.directions;
        for (final direction in directions) {
          final legacyPhotos = [
            for (final cluster in data.routePhotoClusters)
              if (cluster.routeId == route.id &&
                  cluster.directionId == direction.id)
                for (final photo in cluster.photos)
                  GalleryPhoto(
                    id: photo.id,
                    imageUrl: photo.imageUrl,
                    authorNickname: photo.authorNickname,
                    description: photo.description,
                    createdAt: photo.createdAt,
                    likeCount: photo.likeCount,
                    distanceMeters: photo.distanceMeters,
                    routeId: cluster.routeId,
                    directionId: cluster.directionId,
                    startStopId: cluster.startStopId,
                    endStopId: cluster.endStopId,
                  ),
          ];
          final routePhotos = <GalleryPhoto>[
            ...loadedPhotos,
            for (final legacyPhoto in legacyPhotos)
              if (!loadedPhotos.any((photo) => photo.id == legacyPhoto.id))
                legacyPhoto,
          ];
          for (final segment in buildRouteSegments(route, direction, data)) {
            final photos = routePhotos
                .where(
                  (photo) =>
                      photo.directionId == segment.directionId &&
                      photo.startStopId == segment.startStop.id &&
                      photo.endStopId == segment.endStop.id,
                )
                .toList();
            if (photos.isEmpty) continue;
            final markerId =
                'home-segment:${route.id}:${direction.id}:${segment.index}';
            segmentTargets[markerId] = (
              route: route,
              direction: direction,
              segment: segment,
              photos: photos,
            );
            contentMarkers.add(
              KakaoMapMarker(
                id: markerId,
                point: segment.center,
                kind: 'photo',
                imageUrl: photos.first.imageUrl,
                title: '${segment.startStop.name} → ${segment.endStop.name}',
              ),
            );
          }
        }
      }
    } else if (mode == HomeContentMode.missions && data != null) {
      final missionRoutes = selectedRoute == null
          ? const <BusRoute>[]
          : [selectedRoute];
      for (final route in missionRoutes) {
        final missions = (missionsAsync?.valueOrNull ?? const <Mission>[])
            .where(
              (mission) =>
                  (mission.routeId == route.id ||
                      (mission.targetType == 'spot' &&
                          mission.routeId.isEmpty &&
                          data.touristSpots.any(
                            (spot) =>
                                spot.id == mission.spotId &&
                                spot.routeIds.contains(route.id),
                          ))) &&
                  _matchesHomeMissionFilter(mission, missionFilter),
            )
            .toList();
        final directions = selectedRoute == route && selectedDirection != null
            ? [selectedDirection]
            : route.directions;
        for (final direction in directions) {
          for (final segment in buildRouteSegments(route, direction, data)) {
            final segmentMissions = missions
                .where(
                  (mission) =>
                      mission.directionId == segment.directionId &&
                      mission.startStopId == segment.startStop.id &&
                      mission.endStopId == segment.endStop.id,
                )
                .toList();
            if (segmentMissions.isEmpty) continue;
            final markerId =
                'home-segment:${route.id}:${direction.id}:${segment.index}';
            segmentTargets[markerId] = (
              route: route,
              direction: direction,
              segment: segment,
              photos: const [],
            );
            contentMarkers.add(
              KakaoMapMarker(
                id: markerId,
                point: segment.center,
                kind: 'mission',
                title: segmentMissions.first.title,
                accentColor: const Color(0xFF7B1FA2),
              ),
            );
          }
        }
      }

      for (final spot in data.touristSpots) {
        if (selectedRoute == null ||
            !spot.routeIds.contains(selectedRoute.id)) {
          continue;
        }
        final missions = (missionsAsync?.valueOrNull ?? const <Mission>[])
            .where(
              (mission) =>
                  mission.targetType == 'spot' &&
                  mission.routeId.isEmpty &&
                  _matchesHomeMissionFilter(mission, missionFilter),
            )
            .toList();
        if (missions.isEmpty || !isValidMapPoint(spot.position)) continue;
        final mission = missions.first;
        final markerId = 'home-tourist-mission:${spot.id}';
        missionSpotTargets[markerId] = (spotId: spot.id, missionId: mission.id);
        contentMarkers.add(
          KakaoMapMarker(
            id: markerId,
            point: mission.selectedLat != null && mission.selectedLng != null
                ? LatLng(mission.selectedLat!, mission.selectedLng!)
                : spot.position,
            kind: 'mission',
            title: mission.title,
            accentColor: const Color(0xFF7B1FA2),
          ),
        );
      }
    }
    return KeyedSubtree(
      key: ValueKey('route-map-revision-$mapRevision'),
      child: KakaoMapView(
        key: const Key('route-map'),
        apiKey: kakaoMapKey,
        center: center,
        zoom: 7,
        polylines: polylines,
        markers: [
          if (selectedCenter != null)
            KakaoMapMarker(
              id: '',
              point: selectedCenter,
              kind: 'selectedLocation',
              title: '선택 위치',
              accentColor: const Color(0xFFE53935),
            ),
          for (final marker in visibleStopMarkers)
            KakaoMapMarker(
              id: marker.spot == null ? '' : 'spot:${marker.spot!.id}',
              point: marker.position,
              kind: marker.spot == null ? 'nearestStop' : 'spotStop',
              title: _stopMarkerLabel(marker),
              imageUrl: marker.spot?.heroImageUrl,
              accentColor: marker.color,
            ),
          ...contentMarkers,
          if (currentLocation != null && mode == HomeContentMode.tourist)
            KakaoMapMarker(
              id: '',
              point: currentLocation,
              kind: 'currentLocation',
            ),
        ],
        onMarkerTap: (id) {
          const spotPrefix = 'spot:';
          if (id.startsWith(spotPrefix)) {
            final spotId = id.substring(spotPrefix.length);
            context.go('/spots/${Uri.encodeComponent(spotId)}');
          } else if (missionSpotTargets[id] case final target?) {
            context.go(
              '/spots/${Uri.encodeComponent(target.spotId)}/missions/${Uri.encodeComponent(target.missionId)}',
            );
          } else if (segmentTargets[id] case final target?) {
            if (mode == HomeContentMode.photos && target.photos.isNotEmpty) {
              _openHomePhotoViewer(
                context,
                target.photos,
                target.route,
                target.direction,
                target.segment,
              );
            } else {
              _openRouteSegmentComposer(
                context,
                mode: mode,
                route: target.route,
                direction: target.direction,
                segment: target.segment,
              );
            }
          }
        },
        fallback: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12.6),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.b4y',
            ),
            PolylineLayer(
              polylines: [
                for (final line in displayPolylines)
                  Polyline(
                    points: line.points,
                    color: line.color,
                    strokeWidth: line.strokeWidth,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (selectedCenter != null)
                  Marker(
                    point: selectedCenter,
                    width: 48,
                    height: 48,
                    child: const _SelectedLocationMarker(),
                  ),
                for (final marker in visibleStopMarkers)
                  Marker(
                    point: marker.position,
                    width: 176,
                    height: 68,
                    child: _StopMarker(
                      stop: marker.stop,
                      spot: marker.spot,
                      routeNumbers: marker.routeNumbers,
                      color: marker.color,
                    ),
                  ),
                for (final marker in contentMarkers)
                  Marker(
                    point: marker.point,
                    width: 76,
                    height: 76,
                    child: GestureDetector(
                      onTap: () {
                        final missionTarget = missionSpotTargets[marker.id];
                        if (missionTarget != null) {
                          context.go(
                            '/spots/${Uri.encodeComponent(missionTarget.spotId)}/missions/${Uri.encodeComponent(missionTarget.missionId)}',
                          );
                          return;
                        }
                        final target = segmentTargets[marker.id];
                        if (target != null) {
                          if (mode == HomeContentMode.photos &&
                              target.photos.isNotEmpty) {
                            _openHomePhotoViewer(
                              context,
                              target.photos,
                              target.route,
                              target.direction,
                              target.segment,
                            );
                          } else {
                            _openRouteSegmentComposer(
                              context,
                              mode: mode,
                              route: target.route,
                              direction: target.direction,
                              segment: target.segment,
                            );
                          }
                        }
                      },
                      child: marker.kind == 'photo'
                          ? PhotoThumb(imageUrl: marker.imageUrl ?? '')
                          : const _MissionMapMarker(),
                    ),
                  ),
                if (currentLocation != null && mode == HomeContentMode.tourist)
                  Marker(
                    point: currentLocation,
                    width: 42,
                    height: 42,
                    child: const _CurrentLocationMarker(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openMapCenterPicker(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => const _MapCenterPickerScreen(),
    ),
  );
}

void _openHomePhotoViewer(
  BuildContext context,
  List<GalleryPhoto> photos,
  BusRoute route,
  RouteDirection direction,
  RouteSegment segment,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => GalleryPhotoViewerScreen(
        photos: photos,
        initialIndex: 0,
        categoryTitle: '${route.number}번 노선 사진',
        routeLabel: '${route.number}번',
        directionLabel: direction.destination,
        segmentLabel: '${segment.startStop.name} → ${segment.endStop.name}',
      ),
    ),
  );
}

void _openRouteSegmentComposer(
  BuildContext context, {
  required HomeContentMode mode,
  required BusRoute route,
  required RouteDirection direction,
  required RouteSegment segment,
}) {
  final queryParameters = {
    'targetType': 'route',
    'targetId': route.id,
    'routeId': route.id,
    'directionId': direction.id,
    'startStopId': segment.startStop.id,
    'endStopId': segment.endStop.id,
  };
  final path = mode == HomeContentMode.photos
      ? '/gallery/upload'
      : '/route-mission-compose';
  context.push(Uri(path: path, queryParameters: queryParameters).toString());
}

class _MapCenterPickerScreen extends ConsumerStatefulWidget {
  const _MapCenterPickerScreen();

  @override
  ConsumerState<_MapCenterPickerScreen> createState() =>
      _MapCenterPickerScreenState();
}

class _MapCenterPickerScreenState
    extends ConsumerState<_MapCenterPickerScreen> {
  LatLng? _pendingCenter;
  LatLng? _forcedCenter;
  var _mapRevision = 0;

  void _setPendingCenter(LatLng center) {
    setState(() {
      _pendingCenter = center;
    });
  }

  void _selectPendingCenter() {
    final center = _pendingCenter;
    if (center == null) {
      return;
    }
    ref.read(mapSearchCenterProvider.notifier).state = center;
    ref.read(pendingMapCenterProvider.notifier).state = null;
    ref.read(selectedRouteProvider.notifier).state = null;
    ref.read(_mainMapRevisionProvider.notifier).state += 1;
    Navigator.of(context).pop();
  }

  void _moveToCurrentLocation(LatLng currentLocation) {
    setState(() {
      _forcedCenter = currentLocation;
      _pendingCenter = currentLocation;
      _mapRevision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overlays = ref.watch(routeMapOverlaysProvider);
    final currentLocation = ref.watch(currentLocationProvider).valueOrNull;
    final selectedCenter = ref.watch(mapSearchCenterProvider);
    final kakaoMapKey =
        ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
    final center =
        _forcedCenter ??
        selectedCenter ??
        currentLocation ??
        (overlays.firstOrNull?.shape.firstOrNull) ??
        const LatLng(37.3516, 126.7427);
    final mapKeySuffix = '$_mapRevision-${center.latitude}-${center.longitude}';
    final markers = [
      if (selectedCenter != null)
        KakaoMapMarker(
          id: '',
          point: selectedCenter,
          kind: 'selectedLocation',
          title: '선택 위치',
          accentColor: const Color(0xFFE53935),
        ),
      if (currentLocation != null)
        KakaoMapMarker(id: '', point: currentLocation, kind: 'currentLocation'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택'),
        actions: [
          IconButton(
            key: const Key('picker-current-location-button'),
            tooltip: '현위치',
            onPressed: currentLocation == null
                ? null
                : () => _moveToCurrentLocation(currentLocation),
            icon: const Icon(Icons.my_location_rounded),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: KakaoMapView(
              key: ValueKey('location-picker-map-$mapKeySuffix'),
              apiKey: kakaoMapKey,
              center: center,
              zoom: 7,
              markers: markers,
              onCenterChanged: _setPendingCenter,
              fallback: FlutterMap(
                key: ValueKey('location-picker-flutter-map-$mapKeySuffix'),
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 12.6,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) {
                      _setPendingCenter(camera.center);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.b4y',
                  ),
                  MarkerLayer(
                    markers: [
                      if (selectedCenter != null)
                        Marker(
                          point: selectedCenter,
                          width: 48,
                          height: 48,
                          child: const _SelectedLocationMarker(),
                        ),
                      if (currentLocation != null)
                        Marker(
                          point: currentLocation,
                          width: 42,
                          height: 42,
                          child: const _CurrentLocationMarker(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.location_pin,
              size: 42,
              color: Color(0xFFE53935),
              shadows: [
                Shadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          if (_pendingCenter != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: FilledButton.icon(
                  key: const Key('select-map-center-button'),
                  onPressed: _selectPendingCenter,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('선택'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisibleStopMarker {
  const _VisibleStopMarker({
    required this.stop,
    required this.position,
    required this.color,
    required this.routeNumbers,
    this.spot,
  });

  final BusStop stop;
  final LatLng position;
  final Color color;
  final List<String> routeNumbers;
  final TouristSpot? spot;
}

List<_VisibleStopMarker> _visibleStopMarkersFor(
  List<_RouteLine> routeLines,
  LatLng basis,
) {
  final markersByStopId = <String, _VisibleStopMarker>{};
  final routeNumbersByStopId = <String, Set<String>>{};
  final stopDistance = Distance();
  _VisibleStopMarker? nearestMarker;
  var nearestDistance = double.infinity;

  void addMarker(
    BusStop stop,
    LatLng position,
    Color color,
    TouristSpot? spot,
  ) {
    final routeNumbers = _sortedRouteNumbers(routeNumbersByStopId[stop.id]);
    markersByStopId.putIfAbsent(
      stop.id,
      () => _VisibleStopMarker(
        stop: stop,
        position: position,
        color: color,
        routeNumbers: routeNumbers,
        spot: spot,
      ),
    );
  }

  for (final line in routeLines) {
    for (final stop in line.overlay.stops) {
      routeNumbersByStopId
          .putIfAbsent(stop.id, () => {})
          .add(line.overlay.route.number);
      final position = _nearestPointOnRoute(stop.position, line.overlay.shape);
      final spot = line.overlay.touristSpotByStopId[stop.id];
      if (spot != null) {
        addMarker(stop, position, line.color, spot);
      }

      final distance = stopDistance(basis, stop.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestMarker = _VisibleStopMarker(
          stop: stop,
          position: position,
          color: line.color,
          routeNumbers: _sortedRouteNumbers(routeNumbersByStopId[stop.id]),
          spot: spot,
        );
      }
    }
  }

  final nearest = nearestMarker;
  if (nearest != null) {
    addMarker(nearest.stop, nearest.position, nearest.color, nearest.spot);
  }

  return [
    for (final marker in markersByStopId.values)
      _VisibleStopMarker(
        stop: marker.stop,
        position: marker.position,
        color: marker.color,
        routeNumbers: _sortedRouteNumbers(routeNumbersByStopId[marker.stop.id]),
        spot: marker.spot,
      ),
  ];
}

List<String> _sortedRouteNumbers(Set<String>? routeNumbers) {
  final numbers = [...?routeNumbers]..sort(_compareRouteNumbers);
  return numbers;
}

int _compareRouteNumbers(String a, String b) {
  final aNumber = int.tryParse(a);
  final bNumber = int.tryParse(b);
  if (aNumber != null && bNumber != null) {
    final numeric = aNumber.compareTo(bNumber);
    if (numeric != 0) return numeric;
  }
  return a.compareTo(b);
}

String _stopMarkerLabel(_VisibleStopMarker marker) {
  if (marker.spot != null) return marker.spot!.name;
  final routes = _routeNumberLabel(marker.routeNumbers);
  if (routes.isEmpty) return marker.stop.name;
  return '${marker.stop.name} · $routes';
}

String _routeNumberLabel(List<String> routeNumbers) {
  if (routeNumbers.isEmpty) return '';
  const visibleCount = 3;
  final visible = routeNumbers.take(visibleCount).map((number) => '$number번');
  final hiddenCount = routeNumbers.length - visibleCount;
  return hiddenCount > 0
      ? '${visible.join(', ')} 외 $hiddenCount'
      : visible.join(', ');
}

LatLng _nearestPointOnRoute(LatLng point, List<LatLng> shape) {
  final validShape = shape.where(isValidMapPoint).toList();
  if (validShape.isEmpty) {
    return point;
  }
  if (validShape.length == 1) {
    return validShape.first;
  }

  var nearest = validShape.first;
  var nearestSquaredDistance = double.infinity;
  for (var index = 0; index < validShape.length - 1; index += 1) {
    final start = validShape[index];
    final end = validShape[index + 1];
    final deltaLat = end.latitude - start.latitude;
    final deltaLng = end.longitude - start.longitude;
    final segmentLengthSquared = deltaLat * deltaLat + deltaLng * deltaLng;
    final projection = segmentLengthSquared == 0
        ? 0.0
        : (((point.latitude - start.latitude) * deltaLat +
                      (point.longitude - start.longitude) * deltaLng) /
                  segmentLengthSquared)
              .clamp(0.0, 1.0);
    final candidate = LatLng(
      start.latitude + deltaLat * projection,
      start.longitude + deltaLng * projection,
    );
    final distanceLat = point.latitude - candidate.latitude;
    final distanceLng = point.longitude - candidate.longitude;
    final squaredDistance =
        distanceLat * distanceLat + distanceLng * distanceLng;
    if (squaredDistance < nearestSquaredDistance) {
      nearest = candidate;
      nearestSquaredDistance = squaredDistance;
    }
  }
  return nearest;
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({
    required this.stop,
    required this.routeNumbers,
    required this.color,
    this.spot,
  });

  final BusStop stop;
  final List<String> routeNumbers;
  final TouristSpot? spot;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final linkedSpot = spot;
    final displayName = linkedSpot?.name ?? stop.name;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: linkedSpot == null
          ? null
          : () => context.go('/spots/${Uri.encodeComponent(linkedSpot.id)}'),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color,
                  width: linkedSpot == null ? 1 : 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 7,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 164, minHeight: 28),
                child: Padding(
                  padding: EdgeInsets.all(linkedSpot == null ? 5 : 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (linkedSpot != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: PhotoThumb(
                            imageUrl: linkedSpot.heroImageUrl,
                            width: 32,
                            height: 32,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: linkedSpot == null
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                              ),
                            ),
                            if (linkedSpot == null &&
                                routeNumbers.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _routeNumberLabel(routeNumbers),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.w900,
                                        height: 1.15,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: linkedSpot == null ? 14 : 16,
              height: linkedSpot == null ? 14 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
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

class _SelectedLocationMarker extends StatelessWidget {
  const _SelectedLocationMarker();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: Icon(
        Icons.location_pin,
        size: 42,
        color: Color(0xFFE53935),
        shadows: [
          Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _MissionMapMarker extends StatelessWidget {
  const _MissionMapMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),
      child: const Center(
        child: Icon(Icons.flag_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}

class _RouteLine {
  const _RouteLine({required this.overlay, required this.color});

  final RouteMapOverlay overlay;
  final Color color;
}

class _DisplayPolyline {
  const _DisplayPolyline({
    required this.points,
    required this.color,
    this.strokeWidth = 4,
  });

  final List<LatLng> points;
  final Color color;
  final double strokeWidth;
}

class _RoutePathPiece {
  const _RoutePathPiece({
    required this.routeIndex,
    required this.start,
    required this.end,
    required this.color,
  });

  final int routeIndex;
  final LatLng start;
  final LatLng end;
  final Color color;
}

class _OverlapInterval {
  const _OverlapInterval(this.start, this.end);

  final double start;
  final double end;
}

List<_DisplayPolyline> _splitOverlappingRoutePolylines(
  List<_RouteLine> routeLines,
) {
  final standalone = [
    for (final line in routeLines)
      if (line.overlay.shape.length == 1)
        _DisplayPolyline(points: line.overlay.shape, color: line.color),
  ];
  final pieces = <_RoutePathPiece>[];
  for (var routeIndex = 0; routeIndex < routeLines.length; routeIndex++) {
    final line = routeLines[routeIndex];
    for (var index = 0; index + 1 < line.overlay.shape.length; index++) {
      pieces.add(
        _RoutePathPiece(
          routeIndex: routeIndex,
          start: line.overlay.shape[index],
          end: line.overlay.shape[index + 1],
          color: line.color,
        ),
      );
    }
  }
  if (pieces.isEmpty) return standalone;

  final cuts = [
    for (final _ in pieces) <double>[0, 1],
  ];
  for (var first = 0; first < pieces.length; first++) {
    for (var second = first + 1; second < pieces.length; second++) {
      final firstInterval = _overlapInterval(pieces[first], pieces[second]);
      final secondInterval = _overlapInterval(pieces[second], pieces[first]);
      if (firstInterval == null || secondInterval == null) continue;
      cuts[first]
        ..add(firstInterval.start)
        ..add(firstInterval.end);
      cuts[second]
        ..add(secondInterval.start)
        ..add(secondInterval.end);
    }
  }

  final result = <_DisplayPolyline>[];
  for (var pieceIndex = 0; pieceIndex < pieces.length; pieceIndex++) {
    final piece = pieces[pieceIndex];
    final parameters = cuts[pieceIndex].toSet().toList()..sort();
    for (var index = 0; index + 1 < parameters.length; index++) {
      final startParameter = parameters[index];
      final endParameter = parameters[index + 1];
      if (endParameter - startParameter < 0.000001) continue;
      final start = _interpolate(piece.start, piece.end, startParameter);
      final end = _interpolate(piece.start, piece.end, endParameter);
      final middle = _interpolate(
        piece.start,
        piece.end,
        (startParameter + endParameter) / 2,
      );
      final coveringPieces = [
        for (var candidate = 0; candidate < pieces.length; candidate++)
          if (_isPointOnPiece(middle, pieces[candidate])) candidate,
      ];
      final routeIndices =
          coveringPieces
              .map((candidate) => pieces[candidate].routeIndex)
              .toSet()
              .toList()
            ..sort();
      if (routeIndices.length <= 1) {
        result.add(
          _DisplayPolyline(
            points: [start, end],
            color: piece.color,
            strokeWidth: 4,
          ),
        );
        continue;
      }
      final firstPieceForGroup = coveringPieces.first;
      if (pieceIndex != firstPieceForGroup) continue;
      // Keep the overlap as one visual route line. The colors are divided
      // across its width, perpendicular to the route direction.
      for (var colorIndex = 0; colorIndex < routeIndices.length; colorIndex++) {
        final routeIndex = routeIndices[colorIndex];
        final color = routeLines[routeIndex].color;
        final offset = (colorIndex - (routeIndices.length - 1) / 2) * 4.5;
        result.add(
          _DisplayPolyline(
            points: [
              _offsetPoint(start, end, start, offset),
              _offsetPoint(start, end, end, offset),
            ],
            color: color,
            // Adjacent color bands form one thick overlap line.
            strokeWidth: 5,
          ),
        );
      }
    }
  }
  return [...result, ...standalone];
}

_OverlapInterval? _overlapInterval(
  _RoutePathPiece base,
  _RoutePathPiece other,
) {
  final baseStart = _LocalPoint(0, 0);
  final baseEnd = _toLocal(base.end, base.start, base.end);
  final otherStart = _toLocal(other.start, base.start, base.end);
  final otherEnd = _toLocal(other.end, base.start, base.end);
  final baseVector = _LocalPoint(
    baseEnd.x - baseStart.x,
    baseEnd.y - baseStart.y,
  );
  final baseLength = baseVector.length;
  if (baseLength < 1) return null;
  final otherVector = _LocalPoint(
    otherEnd.x - otherStart.x,
    otherEnd.y - otherStart.y,
  );
  if (otherVector.length < 1) return null;
  final distanceStart = _cross(otherStart, baseVector).abs() / baseLength;
  final distanceEnd = _cross(otherEnd, baseVector).abs() / baseLength;
  final parallel =
      (_cross(baseVector, otherVector).abs() /
      (baseLength * otherVector.length));
  if (distanceStart > 16 || distanceEnd > 16 || parallel > 0.25) return null;

  final startProjection =
      _dot(otherStart, baseVector) / (baseLength * baseLength);
  final endProjection = _dot(otherEnd, baseVector) / (baseLength * baseLength);
  final start = math.max(0.0, math.min(startProjection, endProjection));
  final end = math.min(1.0, math.max(startProjection, endProjection));
  if ((end - start) * baseLength < 8) return null;
  return _OverlapInterval(start, end);
}

class _LocalPoint {
  const _LocalPoint(this.x, this.y);

  final double x;
  final double y;

  double get length => math.sqrt(x * x + y * y);
}

double _dot(_LocalPoint first, _LocalPoint second) {
  return first.x * second.x + first.y * second.y;
}

double _cross(_LocalPoint first, _LocalPoint second) {
  return first.x * second.y - first.y * second.x;
}

_LocalPoint _toLocal(LatLng point, LatLng origin, LatLng referenceEnd) {
  final latitude =
      ((point.latitude + origin.latitude + referenceEnd.latitude) / 3) *
      math.pi /
      180;
  const metersPerDegree = 111320.0;
  return _LocalPoint(
    (point.longitude - origin.longitude) * metersPerDegree * math.cos(latitude),
    (point.latitude - origin.latitude) * metersPerDegree,
  );
}

LatLng _interpolate(LatLng start, LatLng end, double parameter) {
  return LatLng(
    start.latitude + (end.latitude - start.latitude) * parameter,
    start.longitude + (end.longitude - start.longitude) * parameter,
  );
}

LatLng _offsetPoint(LatLng start, LatLng end, LatLng point, double meters) {
  final latitude = (start.latitude + end.latitude) / 2 * math.pi / 180;
  const metersPerDegree = 111320.0;
  final north = (end.latitude - start.latitude) * metersPerDegree;
  final east =
      (end.longitude - start.longitude) * metersPerDegree * math.cos(latitude);
  final length = math.sqrt(north * north + east * east);
  if (length < 1) return point;
  final offsetNorth = -east / length * meters;
  final offsetEast = north / length * meters;
  return LatLng(
    point.latitude + offsetNorth / metersPerDegree,
    point.longitude + offsetEast / (metersPerDegree * math.cos(latitude)),
  );
}

bool _isPointOnPiece(LatLng point, _RoutePathPiece piece) {
  final localStart = _toLocal(piece.start, point, piece.end);
  final localEnd = _toLocal(piece.end, point, piece.start);
  final vector = _LocalPoint(
    localEnd.x - localStart.x,
    localEnd.y - localStart.y,
  );
  final lengthSquared = _dot(vector, vector);
  if (lengthSquared < 1) return false;
  final projection = -_dot(localStart, vector) / lengthSquared;
  if (projection < -0.02 || projection > 1.02) return false;
  final closest = _LocalPoint(
    localStart.x + vector.x * projection,
    localStart.y + vector.y * projection,
  );
  return closest.length <= 16;
}

enum _RouteColorFamily { express, regular, local }

List<_RouteLine> _routeLinesFor(List<RouteMapOverlay> overlays) {
  final familyCounts = <_RouteColorFamily, int>{};
  return [
    for (final overlay in overlays)
      _RouteLine(
        overlay: overlay,
        color: _routeColor(_routeColorFamilyFor(overlay.route), familyCounts),
      ),
  ];
}

Color _routeColor(
  _RouteColorFamily family,
  Map<_RouteColorFamily, int> familyCounts,
) {
  final index = familyCounts.update(
    family,
    (count) => count + 1,
    ifAbsent: () => 0,
  );
  final palette = switch (family) {
    _RouteColorFamily.express => const [
      Color(0xFFE53935),
      Color(0xFFFF7043),
      Color(0xFFEF5350),
      Color(0xFFFF8A80),
    ],
    _RouteColorFamily.regular => const [
      Color(0xFF188038),
      Color(0xFF00A676),
      Color(0xFF34A853),
      Color(0xFF66BB6A),
    ],
    _RouteColorFamily.local => const [
      Color(0xFFF9AB00),
      Color(0xFFFDD663),
      Color(0xFFFFC107),
      Color(0xFFFFE082),
    ],
  };
  return palette[index % palette.length];
}

_RouteColorFamily _routeColorFamilyFor(BusRoute route) {
  final text = '${route.routeType} ${route.number} ${route.destination}'
      .toLowerCase();
  final routeTypeCode = int.tryParse(route.routeType.trim());
  final compactNumber = route.number.replaceAll(RegExp(r'[^0-9a-zA-Z가-힣]'), '');
  final numericNumber = int.tryParse(compactNumber);
  final hasExpressNumberPattern =
      numericNumber != null &&
      numericNumber >= 3000 &&
      numericNumber < 4000 &&
      (numericNumber ~/ 10) % 10 == 0;

  if (hasExpressNumberPattern) {
    return _RouteColorFamily.express;
  }
  if (routeTypeCode == 30 ||
      routeTypeCode == 23 ||
      text.contains('마을') ||
      text.contains('농어촌') ||
      text.contains('village') ||
      text.contains('rural')) {
    return _RouteColorFamily.local;
  }
  if ({11, 12, 14, 16}.contains(routeTypeCode) ||
      text.contains('광역') ||
      text.contains('직행') ||
      text.contains('급행') ||
      text.contains('좌석') ||
      compactNumber.startsWith(RegExp('[mMgGpP]')) ||
      (numericNumber != null && numericNumber >= 9000)) {
    return _RouteColorFamily.express;
  }
  return _RouteColorFamily.regular;
}
