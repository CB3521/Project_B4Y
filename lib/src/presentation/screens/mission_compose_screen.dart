import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../application/b4y_providers.dart';
import '../../data/image_data_url.dart';
import '../../domain/b4y_models.dart';
import '../../domain/route_segments.dart';
import '../widgets/compose_step_controls.dart';
import '../widgets/kakao_map_view.dart';
import '../widgets/photo_thumb.dart';

enum _MissionTargetType { route, spot }

enum _VerificationMethod { photo, location }

class MissionComposeScreen extends ConsumerStatefulWidget {
  const MissionComposeScreen({
    super.key,
    this.spotId = '',
    this.routeOnly = false,
    this.touristOnly = false,
    this.initialRouteId,
    this.initialDirectionId,
    this.initialStartStopId,
    this.initialEndStopId,
  });

  final String spotId;
  final bool routeOnly;
  final bool touristOnly;
  final String? initialRouteId;
  final String? initialDirectionId;
  final String? initialStartStopId;
  final String? initialEndStopId;

  @override
  ConsumerState<MissionComposeScreen> createState() =>
      _MissionComposeScreenState();
}

class _MissionComposeScreenState extends ConsumerState<MissionComposeScreen> {
  static const _stepTitles = ['기본 정보', '수행 정보', '사진'];
  static const _baseDifficultyTags = ['시간대가 중요해요', '날씨가 중요해요', '스마트폰 성능이 중요해요'];
  static const _missionTagOptions = [
    '#시흥',
    '#안산',
    '#접근성좋음',
    '#풍경맛집',
    '#테마파크',
    '#GPS',
  ];
  static const _verificationRadiusMeters = 50;

  final _missionController = TextEditingController();
  final _availableSeasonController = TextEditingController();
  final _customTagController = TextEditingController();
  final Set<String> _missionTags = {};
  final Set<String> _difficultyTags = {};
  bool _showCustomTagInput = false;
  String? _imageDataUrl;
  _MissionTargetType? _targetType;
  BusRoute? _selectedRoute;
  RouteDirection? _selectedDirection;
  String? _startStopId;
  String? _endStopId;
  TouristSpot? _selectedSpot;
  LatLng? _selectedSpotPoint;
  LatLng? _missionLocationPoint;
  DateTimeRange? _availableDateRange;
  int _difficulty = 3;
  int _currentStep = 0;
  _VerificationMethod _verificationMethod = _VerificationMethod.photo;
  bool _pickingImage = false;
  bool _saving = false;
  String? _error;
  var _initialRouteApplied = false;
  var _initialSpotApplied = false;

  void _applyInitialRouteSelection(B4ySampleData data) {
    if (_initialRouteApplied ||
        !widget.routeOnly ||
        widget.initialRouteId == null) {
      return;
    }
    final route = data.routes
        .where((item) => item.id == widget.initialRouteId)
        .firstOrNull;
    if (route == null) return;
    _initialRouteApplied = true;
    _targetType = _MissionTargetType.route;
    _selectedRoute = route;
    _selectedDirection = route.directionById(
      widget.initialDirectionId ?? route.defaultDirection.id,
    );
    final stops = _stopsForDirection(data, _selectedDirection!);
    _startStopId = widget.initialStartStopId ?? stops.firstOrNull?.id;
    _endStopId =
        widget.initialEndStopId ??
        (stops.length > 1 ? stops.last.id : _startStopId);
    _missionLocationPoint = stops
        .where((stop) => stop.id == _startStopId)
        .firstOrNull
        ?.position;
  }

  void _applyInitialSpotSelection(B4ySampleData data) {
    if (_initialSpotApplied || widget.routeOnly || widget.spotId.isEmpty) {
      return;
    }
    final spot = data.touristSpots
        .where((item) => item.id == widget.spotId)
        .firstOrNull;
    if (spot == null) return;
    _initialSpotApplied = true;
    _targetType = _MissionTargetType.spot;
    _selectedSpot = spot;
    _selectedSpotPoint = spot.position;
    _missionLocationPoint = spot.position;
  }

  @override
  void initState() {
    super.initState();
    _missionController.addListener(_refreshMissionInput);
  }

  @override
  void dispose() {
    _missionController.removeListener(_refreshMissionInput);
    _missionController.dispose();
    _availableSeasonController.dispose();
    _customTagController.dispose();
    super.dispose();
  }

  void _refreshMissionInput() => setState(() {});

  void _toggleMissionTag(String value) {
    setState(() {
      if (!_missionTags.add(value)) {
        _missionTags.remove(value);
      }
      _error = null;
    });
  }

  void _toggleCustomTagInput() {
    setState(() {
      _showCustomTagInput = !_showCustomTagInput;
      if (!_showCustomTagInput) _customTagController.clear();
    });
  }

  void _addCustomTag() {
    final tag = _normalizeMissionTag(_customTagController.text);
    if (tag == null) return;
    setState(() {
      _missionTags.add(tag);
      _showCustomTagInput = false;
      _error = null;
    });
    _customTagController.clear();
  }

  Future<void> _pickImage() async {
    setState(() {
      _pickingImage = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final value = encodeImageDataUrl(await picked.readAsBytes());
      if (mounted) setState(() => _imageDataUrl = value);
    } on Object catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _openSpotPicker(TouristSpot spot) async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        builder: (context) => _SpotPointPickerScreen(
          spot: spot,
          initialPoint: _selectedSpotPoint,
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedSpotPoint = selected);
    }
  }

  Future<void> _openMissionLocationPicker(B4ySampleData data) async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute<LatLng>(
        fullscreenDialog: true,
        builder: (context) => _MissionLocationPickerScreen(
          initialPoint: _missionLocationPoint ?? _defaultMissionLocation(data),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _missionLocationPoint = selected);
    }
  }

  Future<void> _openTargetSearch(B4ySampleData data) async {
    final selection = await Navigator.of(context).push<_MissionTargetSelection>(
      MaterialPageRoute<_MissionTargetSelection>(
        builder: (context) => _MissionTargetSearchScreen(
          data: data,
          routesOnly: widget.routeOnly,
          spotsOnly: widget.touristOnly || widget.spotId.isNotEmpty,
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      if (selection.route != null) {
        _selectRoute(data, selection.route!);
      } else if (selection.spot != null) {
        _selectSpot(selection.spot!);
      }
    });
  }

  void _selectRoute(B4ySampleData data, BusRoute route) {
    _targetType = _MissionTargetType.route;
    _selectedRoute = route;
    _selectedDirection = route.defaultDirection;
    _selectedSpot = null;
    _selectedSpotPoint = null;
    final stops = _stopsForDirection(data, route.defaultDirection);
    _startStopId = stops.firstOrNull?.id;
    _endStopId = stops.length > 1 ? stops.last.id : _startStopId;
    _missionLocationPoint ??= stops.firstOrNull?.position;
    _difficultyTags.remove('위치가 중요해요');
  }

  void _selectSpot(TouristSpot spot) {
    _targetType = _MissionTargetType.spot;
    _selectedSpot = spot;
    _selectedSpotPoint = spot.position;
    _selectedRoute = null;
    _selectedDirection = null;
    _startStopId = null;
    _endStopId = null;
    _missionLocationPoint ??= spot.position;
  }

  LatLng _defaultMissionLocation(B4ySampleData data) {
    final selectedSpotPoint = _selectedSpotPoint;
    if (selectedSpotPoint != null) return selectedSpotPoint;
    final selectedSpot = _selectedSpot;
    if (selectedSpot != null) return selectedSpot.position;
    final selectedDirection = _selectedDirection;
    if (selectedDirection != null) {
      final stops = _stopsForDirection(data, selectedDirection);
      final startStop = stops
          .where((stop) => stop.id == _startStopId)
          .firstOrNull;
      return startStop?.position ??
          stops.firstOrNull?.position ??
          (widget.spotId.isEmpty
              ? const LatLng(37.3516, 126.7427)
              : data.spotById(widget.spotId).position);
    }
    return widget.spotId.isEmpty
        ? const LatLng(37.3516, 126.7427)
        : data.spotById(widget.spotId).position;
  }

  Future<void> _pickAvailableDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _availableDateRange,
      helpText: '미션 가능 기간 선택',
      saveText: '선택',
      cancelText: '취소',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _availableDateRange = picked;
      _availableSeasonController.text = _formatDateRange(picked);
    });
  }

  Future<void> _submit() async {
    final repository = ref.read(engagementRepositoryProvider);
    final auth = ref.read(firebaseAuthProvider);
    if (repository == null || auth == null) {
      setState(() => _error = 'Firebase 연결을 확인해 주세요.');
      return;
    }
    if (_targetType == null) {
      setState(
        () => _error = widget.routeOnly ? '노선을 선택해 주세요.' : '관광지를 선택해 주세요.',
      );
      return;
    }
    if (_targetType == _MissionTargetType.route && _selectedRoute == null) {
      setState(() => _error = '노선을 선택해 주세요.');
      return;
    }
    if (_targetType == _MissionTargetType.spot &&
        (_selectedSpot?.id ?? widget.spotId).isEmpty) {
      setState(() => _error = '관광지를 선택해 주세요.');
      return;
    }
    final missionText = _missionController.text.trim();
    if (missionText.isEmpty) {
      setState(() => _error = '미션을 입력해 주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
      if (user == null) throw StateError('사용자 정보를 만들 수 없습니다.');
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final nickname = profile?.nickname.trim();
      final missionBody = missionText;
      final missionLocationPoint =
          _verificationMethod == _VerificationMethod.location
          ? _missionLocationPoint
          : _selectedSpotPoint;
      await repository.createMission(
        spotId: _selectedSpot?.id ?? widget.spotId,
        title: missionText,
        body: missionBody,
        targetType: _targetType == _MissionTargetType.route ? 'route' : 'spot',
        targetId: _selectedRoute?.id ?? _selectedSpot?.id ?? '',
        targetName: _selectedRoute?.number ?? _selectedSpot?.name ?? '',
        routeId: _selectedRoute?.id ?? '',
        directionId: _selectedDirection?.id ?? '',
        startStopId: _startStopId ?? '',
        endStopId: _endStopId ?? '',
        selectedLat: missionLocationPoint?.latitude,
        selectedLng: missionLocationPoint?.longitude,
        difficulty: _difficulty,
        availableSeason: _availableSeasonController.text,
        availableStartDate: _availableDateRange == null
            ? null
            : _formatDate(_availableDateRange!.start),
        availableEndDate: _availableDateRange == null
            ? null
            : _formatDate(_availableDateRange!.end),
        missionTags: _missionTags.toList(),
        difficultyTags: _difficultyTags.toList(),
        verificationMethod: _verificationMethod == _VerificationMethod.photo
            ? 'photo'
            : 'location',
        verificationRadiusMeters: _verificationRadiusMeters,
        authorNickname: nickname?.isNotEmpty == true ? nickname! : '방문자',
        authorUid: user.uid,
        imageDataUrl: _imageDataUrl,
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          widget.spotId.isEmpty
              ? '/route-missions?routeId=${Uri.encodeComponent(_selectedRoute?.id ?? '')}'
              : '/spots/${widget.spotId}/missions',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _messageFor(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(b4yDataProvider);
    final kakaoMapKey =
        ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
    final canSubmit = !_saving && !_pickingImage;
    return Scaffold(
      appBar: AppBar(title: const Text('미션 작성')),
      body: SafeArea(
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('미션 작성 정보를 불러오지 못했어요.')),
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Builder(
                builder: (context) {
                  if ((!_initialRouteApplied &&
                          widget.initialRouteId != null) ||
                      (!(_initialSpotApplied) && widget.spotId.isNotEmpty)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _applyInitialRouteSelection(data);
                          _applyInitialSpotSelection(data);
                        });
                      }
                    });
                  }
                  return const SizedBox.shrink();
                },
              ),
              ComposeStepHeader(titles: _stepTitles, currentStep: _currentStep),
              const SizedBox(height: 24),
              ..._buildStepChildren(data, kakaoMapKey, canSubmit),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: ComposeStepNavigation(
        currentStep: _currentStep,
        stepCount: _stepTitles.length,
        canSubmit: canSubmit,
        saving: _saving,
        submitLabel: '미션 등록',
        onPrevious: _previousStep,
        onNext: _nextStep,
        onSubmit: _submit,
      ),
    );
  }

  List<Widget> _buildStepChildren(
    B4ySampleData data,
    String kakaoMapKey,
    bool canSubmit,
  ) {
    return switch (_currentStep) {
      0 => [
        _MissionInputSection(controller: _missionController, enabled: !_saving),
        const SizedBox(height: 12),
        _TargetSearchSection(
          selectedRoute: _selectedRoute,
          selectedSpot: _selectedSpot,
          routeOnly: widget.routeOnly,
          spotOnly: widget.touristOnly || widget.spotId.isNotEmpty,
          enabled: widget.spotId.isEmpty,
          onTap: () => _openTargetSearch(data),
        ),
        if (widget.routeOnly &&
            _selectedRoute != null &&
            _selectedDirection != null) ...[
          const SizedBox(height: 12),
          _RouteSegmentSection(
            data: data,
            route: _selectedRoute!,
            direction: _selectedDirection!,
            startStopId: _startStopId,
            endStopId: _endStopId,
            onDirectionChanged: (direction) => setState(() {
              _selectedDirection = direction;
              final stops = _stopsForDirection(data, direction);
              _startStopId = stops.firstOrNull?.id;
              _endStopId = stops.length > 1 ? stops.last.id : _startStopId;
            }),
            onStartChanged: (value) => setState(() => _startStopId = value),
            onEndChanged: (value) => setState(() => _endStopId = value),
          ),
        ],
        if (_selectedSpot != null) ...[
          const SizedBox(height: 12),
          _SpotMapPreview(
            spot: _selectedSpot!,
            selectedPoint: _selectedSpotPoint,
            kakaoMapKey: kakaoMapKey,
            onTap: () => _openSpotPicker(_selectedSpot!),
          ),
        ],
        const SizedBox(height: 18),
        _MissionTagsSection(
          selected: _missionTags,
          customController: _customTagController,
          showCustomInput: _showCustomTagInput,
          enabled: !_saving,
          onToggleTag: _toggleMissionTag,
          onToggleCustomInput: _toggleCustomTagInput,
          onAddCustomTag: _addCustomTag,
        ),
      ],
      1 => [
        Text('난이도', style: Theme.of(context).textTheme.titleMedium),
        Row(
          children: [
            Expanded(
              child: Slider(
                min: 1,
                max: 5,
                divisions: 4,
                value: _difficulty.toDouble(),
                label: '$_difficulty',
                onChanged: (value) =>
                    setState(() => _difficulty = value.round()),
              ),
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$_difficulty',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        _DifficultyTags(
          includeLocation: _targetType == _MissionTargetType.spot,
          selected: _difficultyTags,
          onChanged: (value) => setState(() {
            if (!_difficultyTags.add(value)) {
              _difficultyTags.remove(value);
            }
          }),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _availableSeasonController,
          readOnly: true,
          onTap: _saving ? null : _pickAvailableDateRange,
          decoration: const InputDecoration(
            labelText: '미션 가능 기간',
            hintText: '기간을 선택하세요',
            prefixIcon: Icon(Icons.calendar_today_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Text('인증 방법', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<_VerificationMethod>(
          segments: const [
            ButtonSegment(
              value: _VerificationMethod.photo,
              icon: Icon(Icons.photo_camera_outlined),
              label: Text('사진'),
            ),
            ButtonSegment(
              value: _VerificationMethod.location,
              icon: Icon(Icons.my_location_outlined),
              label: Text('현위치'),
            ),
          ],
          selected: {_verificationMethod},
          onSelectionChanged: (value) => setState(() {
            _verificationMethod = value.first;
            if (_verificationMethod == _VerificationMethod.location) {
              _missionLocationPoint ??= _defaultMissionLocation(data);
            }
          }),
        ),
        if (_verificationMethod == _VerificationMethod.location) ...[
          const SizedBox(height: 12),
          _MissionLocationMapSection(
            point: _missionLocationPoint ?? _defaultMissionLocation(data),
            kakaoMapKey: kakaoMapKey,
            radiusMeters: _verificationRadiusMeters,
            onTap: () => _openMissionLocationPicker(data),
          ),
        ],
      ],
      _ => [
        _MissionPhotoSection(
          imageDataUrl: _imageDataUrl,
          canSubmit: canSubmit,
          pickingImage: _pickingImage,
          saving: _saving,
          onPickImage: _pickImage,
          onRemove: () => setState(() => _imageDataUrl = null),
        ),
      ],
    };
  }

  void _nextStep() {
    setState(() {
      _currentStep = (_currentStep + 1).clamp(0, _stepTitles.length - 1);
      _error = null;
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep = (_currentStep - 1).clamp(0, _stepTitles.length - 1);
      _error = null;
    });
  }
}

class _MissionPhotoSection extends StatelessWidget {
  const _MissionPhotoSection({
    required this.imageDataUrl,
    required this.canSubmit,
    required this.pickingImage,
    required this.saving,
    required this.onPickImage,
    required this.onRemove,
  });

  final String? imageDataUrl;
  final bool canSubmit;
  final bool pickingImage;
  final bool saving;
  final VoidCallback onPickImage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('사진', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageDataUrl == null
                  ? const PhotoPlaceholder(width: 96, height: 96)
                  : PhotoThumb(
                      imageUrl: imageDataUrl!,
                      width: 96,
                      height: 96,
                      borderRadius: 0,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: canSubmit ? onPickImage : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(pickingImage ? '변환 중...' : '사진 올리기'),
                  ),
                  if (imageDataUrl != null)
                    TextButton(
                      onPressed: saving ? null : onRemove,
                      child: const Text('사진 제거'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MissionInputSection extends StatelessWidget {
  const _MissionInputSection({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          maxLength: 120,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '미션 입력',
            hintText: '예: 등대 앞에서 같은 포즈로 사진 찍기',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _MissionTargetSelection {
  const _MissionTargetSelection.route(this.route) : spot = null;
  const _MissionTargetSelection.spot(this.spot) : route = null;

  final BusRoute? route;
  final TouristSpot? spot;
}

class _TargetSearchSection extends StatelessWidget {
  const _TargetSearchSection({
    required this.selectedRoute,
    required this.selectedSpot,
    required this.routeOnly,
    required this.spotOnly,
    required this.enabled,
    required this.onTap,
  });

  final BusRoute? selectedRoute;
  final TouristSpot? selectedSpot;
  final bool routeOnly;
  final bool spotOnly;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedText = selectedRoute != null
        ? '${selectedRoute!.number}번 노선'
        : selectedSpot?.name;
    final label = routeOnly
        ? '노선 검색'
        : spotOnly
        ? '관광지'
        : '관광지 검색';
    return TextField(
      readOnly: true,
      onTap: enabled ? onTap : null,
      controller: TextEditingController(text: selectedText ?? ''),
      decoration: InputDecoration(
        labelText: label,
        hintText: spotOnly ? '선택된 관광지' : '눌러서 검색',
        prefixIcon: Icon(routeOnly ? Icons.directions_bus : Icons.place),
        suffixIcon: enabled ? const Icon(Icons.chevron_right) : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _MissionTargetSearchScreen extends StatefulWidget {
  const _MissionTargetSearchScreen({
    required this.data,
    this.routesOnly = false,
    this.spotsOnly = false,
  });

  final B4ySampleData data;
  final bool routesOnly;
  final bool spotsOnly;

  @override
  State<_MissionTargetSearchScreen> createState() =>
      _MissionTargetSearchScreenState();
}

class _MissionTargetSearchScreenState
    extends State<_MissionTargetSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final routes = widget.data.routes
        .where((route) {
          if (query.isEmpty) return true;
          return route.number.toLowerCase().contains(query) ||
              route.destination.toLowerCase().contains(query);
        })
        .take(20);
    final spots = widget.data.touristSpots
        .where((spot) {
          if (query.isEmpty) return true;
          return spot.name.toLowerCase().contains(query) ||
              spot.address.toLowerCase().contains(query);
        })
        .take(20);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routesOnly
              ? '노선 검색'
              : widget.spotsOnly
              ? '관광지 검색'
              : '노선 또는 관광지 검색',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (!widget.spotsOnly)
              Text('노선', style: Theme.of(context).textTheme.titleMedium),
            if (!widget.spotsOnly) const SizedBox(height: 8),
            if (!widget.spotsOnly && routes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('검색된 노선이 없어요.'),
              )
            else if (!widget.spotsOnly)
              for (final route in routes)
                ListTile(
                  leading: const Icon(Icons.directions_bus_outlined),
                  title: Text('${route.number}번'),
                  subtitle: Text(route.destination),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_MissionTargetSelection.route(route)),
                ),
            if (!widget.routesOnly) const SizedBox(height: 16),
            if (!widget.routesOnly)
              Text('관광지', style: Theme.of(context).textTheme.titleMedium),
            if (!widget.routesOnly) const SizedBox(height: 8),
            if (!widget.routesOnly && spots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('검색된 관광지가 없어요.'),
              )
            else if (!widget.routesOnly)
              for (final spot in spots)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(spot.name),
                  subtitle: Text(
                    spot.address.isEmpty ? '주소 정보 없음' : spot.address,
                  ),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_MissionTargetSelection.spot(spot)),
                ),
          ],
        ),
      ),
    );
  }
}

class _RouteSegmentSection extends StatelessWidget {
  const _RouteSegmentSection({
    required this.data,
    required this.route,
    required this.direction,
    required this.startStopId,
    required this.endStopId,
    required this.onDirectionChanged,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final B4ySampleData data;
  final BusRoute route;
  final RouteDirection direction;
  final String? startStopId;
  final String? endStopId;
  final ValueChanged<RouteDirection> onDirectionChanged;
  final ValueChanged<String?> onStartChanged;
  final ValueChanged<String?> onEndChanged;

  @override
  Widget build(BuildContext context) {
    final stops = _stopsForDirection(data, direction);
    final segments = buildRouteSegments(route, direction, data);
    final selectedSegment = findRouteSegment(
      segments,
      directionId: direction.id,
      startStopId: startStopId ?? '',
      endStopId: endStopId ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('노선 구간', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('direction-${route.id}-${direction.id}'),
          initialValue: direction.id,
          decoration: const InputDecoration(
            labelText: '방향',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final item in route.directions)
              DropdownMenuItem(
                value: item.id,
                child: Text('${item.name} ${item.destination}'),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onDirectionChanged(route.directionById(value));
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'segment-${direction.id}-${selectedSegment?.index ?? ''}',
          ),
          initialValue: selectedSegment?.index.toString(),
          decoration: const InputDecoration(
            labelText: '3~4개 정류장 구간',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final segment in segments)
              DropdownMenuItem(
                value: segment.index.toString(),
                child: Text(
                  '${segment.startStop.name} → ${segment.endStop.name}',
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            final segment = segments[int.parse(value)];
            onStartChanged(segment.startStop.id);
            onEndChanged(segment.endStop.id);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('start-${direction.id}-$startStopId'),
                initialValue: startStopId,
                decoration: const InputDecoration(
                  labelText: '시작 정류장',
                  border: OutlineInputBorder(),
                ),
                items: _stopItems(stops),
                onChanged: onStartChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('end-${direction.id}-$endStopId'),
                initialValue: endStopId,
                decoration: const InputDecoration(
                  labelText: '종료 정류장',
                  border: OutlineInputBorder(),
                ),
                items: _stopItems(stops),
                onChanged: onEndChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MissionTagsSection extends StatelessWidget {
  const _MissionTagsSection({
    required this.selected,
    required this.customController,
    required this.showCustomInput,
    required this.enabled,
    required this.onToggleTag,
    required this.onToggleCustomInput,
    required this.onAddCustomTag,
  });

  final Set<String> selected;
  final TextEditingController customController;
  final bool showCustomInput;
  final bool enabled;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onToggleCustomInput;
  final VoidCallback onAddCustomTag;

  @override
  Widget build(BuildContext context) {
    final customTags = selected.where(
      (tag) => !_MissionComposeScreenState._missionTagOptions.contains(tag),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('태그', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _MissionComposeScreenState._missionTagOptions)
              FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: enabled ? (_) => onToggleTag(option) : null,
              ),
            FilterChip(
              label: const Text('직접입력'),
              selected: showCustomInput,
              onSelected: enabled ? (_) => onToggleCustomInput() : null,
            ),
            for (final tag in customTags)
              InputChip(
                label: Text(tag),
                selected: true,
                onDeleted: enabled ? () => onToggleTag(tag) : null,
              ),
          ],
        ),
        if (showCustomInput) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: customController,
                  enabled: enabled,
                  maxLength: 20,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAddCustomTag(),
                  decoration: const InputDecoration(
                    labelText: '직접입력 태그',
                    hintText: '예: 야경',
                    prefixText: '#',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 56,
                child: IconButton.filled(
                  onPressed: enabled ? onAddCustomTag : null,
                  icon: const Icon(Icons.add),
                  tooltip: '태그 추가',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DifficultyTags extends StatelessWidget {
  const _DifficultyTags({
    required this.includeLocation,
    required this.selected,
    required this.onChanged,
  });

  final bool includeLocation;
  final Set<String> selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      ..._MissionComposeScreenState._baseDifficultyTags,
      if (includeLocation) '위치가 중요해요',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option),
            selected: selected.contains(option),
            onSelected: (_) => onChanged(option),
          ),
      ],
    );
  }
}

class _MissionLocationMapSection extends StatelessWidget {
  const _MissionLocationMapSection({
    required this.point,
    required this.kakaoMapKey,
    required this.radiusMeters,
    required this.onTap,
  });

  final LatLng point;
  final String kakaoMapKey;
  final int radiusMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('미션 장소', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '포인터가 가리키는 곳에서 ${radiusMeters}m 이내에 있으면 클리어돼요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: KakaoMapView(
                        apiKey: kakaoMapKey,
                        center: point,
                        zoom: 4,
                        markers: [
                          KakaoMapMarker(
                            id: 'mission-location',
                            point: point,
                            kind: 'selectedLocation',
                            title: '선택 위치',
                            accentColor: const Color(0xFFE53935),
                          ),
                        ],
                        fallback: FlutterMap(
                          options: MapOptions(
                            initialCenter: point,
                            initialZoom: 15,
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
                                  child: const _SelectedPointMarker(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Center(child: _CenterPointer()),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      key: const Key('mission-location-picker-button'),
                      onPressed: onTap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('지도에서 선택'),
                    ),
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

class _MissionLocationPickerScreen extends ConsumerStatefulWidget {
  const _MissionLocationPickerScreen({required this.initialPoint});

  final LatLng initialPoint;

  @override
  ConsumerState<_MissionLocationPickerScreen> createState() =>
      _MissionLocationPickerScreenState();
}

class _MissionLocationPickerScreenState
    extends ConsumerState<_MissionLocationPickerScreen> {
  LatLng? _pendingCenter;
  LatLng? _forcedCenter;
  var _mapRevision = 0;

  void _setPendingCenter(LatLng center) {
    setState(() => _pendingCenter = center);
  }

  void _moveToCurrentLocation(LatLng currentLocation) {
    setState(() {
      _forcedCenter = currentLocation;
      _pendingCenter = currentLocation;
      _mapRevision += 1;
    });
  }

  void _selectCenter() {
    Navigator.of(
      context,
    ).pop(_pendingCenter ?? _forcedCenter ?? widget.initialPoint);
  }

  @override
  Widget build(BuildContext context) {
    final kakaoMapKey =
        ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
    final currentLocation = ref.watch(currentLocationProvider).valueOrNull;
    final center = _forcedCenter ?? widget.initialPoint;
    final mapKeySuffix = '$_mapRevision-${center.latitude}-${center.longitude}';
    final markers = [
      KakaoMapMarker(
        id: 'mission-location',
        point: widget.initialPoint,
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
            key: const Key('mission-picker-current-location-button'),
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
              key: ValueKey('mission-location-picker-map-$mapKeySuffix'),
              apiKey: kakaoMapKey,
              center: center,
              zoom: 7,
              markers: markers,
              onCenterChanged: _setPendingCenter,
              fallback: FlutterMap(
                key: ValueKey(
                  'mission-location-picker-flutter-map-$mapKeySuffix',
                ),
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
                      Marker(
                        point: widget.initialPoint,
                        width: 42,
                        height: 42,
                        child: const _SelectedPointMarker(),
                      ),
                      if (currentLocation != null)
                        Marker(
                          point: currentLocation,
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.my_location,
                            color: Color(0xFF167A72),
                            size: 30,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Center(child: _CenterPointer()),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: FilledButton.icon(
              key: const Key('mission-select-map-center-button'),
              onPressed: _selectCenter,
              icon: const Icon(Icons.check_rounded),
              label: const Text('선택'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotMapPreview extends StatelessWidget {
  const _SpotMapPreview({
    required this.spot,
    required this.selectedPoint,
    required this.kakaoMapKey,
    required this.onTap,
  });

  final TouristSpot spot;
  final LatLng? selectedPoint;
  final String kakaoMapKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final markers = [
      KakaoMapMarker(
        id: spot.id,
        point: spot.position,
        kind: 'detailSpot',
        title: spot.name,
      ),
      if (selectedPoint != null)
        KakaoMapMarker(
          id: 'selected',
          point: selectedPoint!,
          kind: 'selectedLocation',
          title: '선택 위치',
          accentColor: const Color(0xFFE53935),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('관광지 위치', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: IgnorePointer(
                child: KakaoMapView(
                  apiKey: kakaoMapKey,
                  center: spot.position,
                  zoom: 5,
                  markers: markers,
                  fitToContent: true,
                  fitPoints: [spot.position, ?selectedPoint],
                  fallback: FlutterMap(
                    options: MapOptions(
                      initialCenter: spot.position,
                      initialZoom: 15,
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
                            point: spot.position,
                            width: 42,
                            height: 42,
                            child: const Icon(
                              Icons.place,
                              color: Color(0xFF167A72),
                              size: 34,
                            ),
                          ),
                          if (selectedPoint != null)
                            Marker(
                              point: selectedPoint!,
                              width: 42,
                              height: 42,
                              child: const _SelectedPointMarker(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotPointPickerScreen extends ConsumerStatefulWidget {
  const _SpotPointPickerScreen({
    required this.spot,
    required this.initialPoint,
  });

  final TouristSpot spot;
  final LatLng? initialPoint;

  @override
  ConsumerState<_SpotPointPickerScreen> createState() =>
      _SpotPointPickerScreenState();
}

class _SpotPointPickerScreenState
    extends ConsumerState<_SpotPointPickerScreen> {
  LatLng? _pendingCenter;
  bool _hasMoved = false;

  @override
  Widget build(BuildContext context) {
    final kakaoMapKey =
        ref.watch(apiKeysProvider).valueOrNull?.kakaoMapKey ?? '';
    final initialCenter = widget.initialPoint ?? widget.spot.position;
    return Scaffold(
      appBar: AppBar(title: Text(widget.spot.name)),
      body: Stack(
        children: [
          Positioned.fill(
            child: KakaoMapView(
              apiKey: kakaoMapKey,
              center: initialCenter,
              zoom: 4,
              markers: [
                KakaoMapMarker(
                  id: widget.spot.id,
                  point: widget.spot.position,
                  kind: 'detailSpot',
                  title: widget.spot.name,
                ),
              ],
              onCenterChanged: (center) => setState(() {
                _pendingCenter = center;
                _hasMoved = true;
              }),
              fallback: FlutterMap(
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 15,
                  onPositionChanged: (camera, hasGesture) {
                    if (!hasGesture) return;
                    setState(() {
                      _pendingCenter = camera.center;
                      _hasMoved = true;
                    });
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
                      Marker(
                        point: widget.spot.position,
                        width: 42,
                        height: 42,
                        child: const Icon(
                          Icons.place,
                          color: Color(0xFF167A72),
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Center(child: _CenterPointer()),
          if (_hasMoved)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_pendingCenter ?? initialCenter),
                icon: const Icon(Icons.check),
                label: const Text('선택'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenterPointer extends StatelessWidget {
  const _CenterPointer();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Icon(Icons.location_pin, color: Color(0xFFE53935), size: 42),
    );
  }
}

class _SelectedPointMarker extends StatelessWidget {
  const _SelectedPointMarker();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.location_pin, color: Color(0xFFE53935), size: 34);
  }
}

List<DropdownMenuItem<String>> _stopItems(List<BusStop> stops) {
  return [
    for (final stop in stops)
      DropdownMenuItem(value: stop.id, child: Text(stop.name)),
  ];
}

List<BusStop> _stopsForDirection(B4ySampleData data, RouteDirection direction) {
  return direction.stopIds
      .map((id) {
        try {
          return data.stopById(id);
        } on StateError {
          return null;
        }
      })
      .whereType<BusStop>()
      .toList();
}

String _messageFor(Object error) {
  if (error is FormatException) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'operation-not-allowed' =>
        '익명 로그인이 비활성화되어 미션을 저장할 수 없습니다. Firebase Authentication에서 익명 로그인을 켜 주세요.',
      'network-request-failed' => '네트워크가 불안정해 로그인하지 못했습니다.',
      _ => '로그인하지 못했습니다. (${error.code})',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        '저장 권한이 거부되었습니다. Firebase 로그인과 Firestore 규칙을 확인해 주세요.',
      'resource-exhausted' => '미션 사진 용량이 너무 큽니다. 더 작은 사진을 선택해 주세요.',
      'unavailable' => '네트워크가 불안정해 저장하지 못했습니다.',
      _ => '저장하지 못했습니다. (${error.code})',
    };
  }
  return '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _formatDateRange(DateTimeRange value) {
  final start = _formatDate(value.start);
  final end = _formatDate(value.end);
  return start == end ? start : '$start ~ $end';
}

String? _normalizeMissionTag(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '#') return null;
  final withoutHash = trimmed.startsWith('#')
      ? trimmed.substring(1).trim()
      : trimmed;
  if (withoutHash.isEmpty) return null;
  return '#$withoutHash';
}
