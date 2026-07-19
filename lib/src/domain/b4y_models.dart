import 'package:latlong2/latlong.dart';

enum GallerySort { popular, latest, distance }

class BusStop {
  const BusStop({
    required this.id,
    required this.name,
    required this.position,
    required this.sequence,
    this.isTurnaround = false,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      id: json['id'] as String,
      name: json['name'] as String,
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      sequence: json['sequence'] as int,
      isTurnaround: json['isTurnaround'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final LatLng position;
  final int sequence;
  final bool isTurnaround;
}

class RouteDirection {
  const RouteDirection({
    required this.id,
    required this.name,
    required this.destination,
    required this.stopIds,
    required this.shape,
  });

  factory RouteDirection.fromJson(Map<String, dynamic> json) {
    return RouteDirection(
      id: json['id'] as String,
      name: json['name'] as String,
      destination: json['destination'] as String,
      stopIds: (json['stopIds'] as List<dynamic>).cast<String>(),
      shape: (json['shape'] as List<dynamic>)
          .map(
            (point) => LatLng(
              (point['lat'] as num).toDouble(),
              (point['lng'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }

  final String id;
  final String name;
  final String destination;
  final List<String> stopIds;
  final List<LatLng> shape;
}

class BusRoute {
  const BusRoute({
    required this.id,
    required this.number,
    required this.destination,
    required this.directions,
    this.routeType = '',
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as String,
      number: json['number'] as String,
      destination: json['destination'] as String,
      routeType: json['routeType'] as String? ?? '',
      directions: (json['directions'] as List<dynamic>)
          .map((item) => RouteDirection.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String number;
  final String destination;
  final String routeType;
  final List<RouteDirection> directions;

  RouteDirection get defaultDirection => directions.first;

  RouteDirection directionById(String directionId) {
    return directions.firstWhere(
      (direction) => direction.id == directionId,
      orElse: () => defaultDirection,
    );
  }
}

class B4yPhoto {
  const B4yPhoto({
    required this.id,
    required this.imageUrl,
    required this.authorNickname,
    required this.description,
    required this.createdAt,
    required this.likeCount,
    required this.distanceMeters,
  });

  factory B4yPhoto.fromJson(Map<String, dynamic> json) {
    return B4yPhoto(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      authorNickname: json['authorNickname'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int,
      distanceMeters: json['distanceMeters'] as int,
    );
  }

  final String id;
  final String imageUrl;
  final String authorNickname;
  final String description;
  final DateTime createdAt;
  final int likeCount;
  final int distanceMeters;
}

class RoutePhotoCluster {
  const RoutePhotoCluster({
    required this.id,
    required this.routeId,
    required this.directionId,
    required this.startStopId,
    required this.endStopId,
    required this.photos,
  });

  factory RoutePhotoCluster.fromJson(Map<String, dynamic> json) {
    return RoutePhotoCluster(
      id: json['id'] as String,
      routeId: json['routeId'] as String,
      directionId: json['directionId'] as String,
      startStopId: json['startStopId'] as String,
      endStopId: json['endStopId'] as String,
      photos: (json['photos'] as List<dynamic>)
          .map((item) => B4yPhoto.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String routeId;
  final String directionId;
  final String startStopId;
  final String endStopId;
  final List<B4yPhoto> photos;
}

class TouristSpot {
  const TouristSpot({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.heroImageUrl,
    required this.nearestStopId,
    required this.routeIds,
    this.address = '',
  });

  factory TouristSpot.fromJson(Map<String, dynamic> json) {
    return TouristSpot(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      address: json['address'] as String? ?? '',
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      heroImageUrl: json['heroImageUrl'] as String,
      nearestStopId: json['nearestStopId'] as String,
      routeIds: (json['routeIds'] as List<dynamic>).cast<String>(),
    );
  }

  final String id;
  final String name;
  final String description;
  final String address;
  final LatLng position;
  final String heroImageUrl;
  final String nearestStopId;
  final List<String> routeIds;
}

class Review {
  const Review({
    required this.id,
    required this.spotId,
    required this.authorNickname,
    required this.title,
    this.body = '',
    this.visitSeason = '',
    this.cleanlinessRating = 3,
    this.accessibilityRating = 3,
    this.overallRating = 3,
    this.cleanlinessTags = const [],
    this.accessibilityTags = const [],
    this.cleanlinessOther = '',
    this.accessibilityOther = '',
    required this.createdAt,
    required this.likeCount,
    this.authorUid = '',
    this.imageDataUrl,
    this.imageDataUrls = const [],
    this.isLiked = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      spotId: json['spotId'] as String,
      authorNickname: json['authorNickname'] as String,
      title: (json['title'] ?? json['summary']) as String,
      body: json['body'] as String? ?? '',
      visitSeason: json['visitSeason'] as String? ?? '',
      cleanlinessRating: ((json['cleanlinessRating'] as num?)?.toDouble() ?? 3)
          .clamp(1, 5)
          .toDouble(),
      accessibilityRating:
          ((json['accessibilityRating'] as num?)?.toDouble() ?? 3)
              .clamp(1, 5)
              .toDouble(),
      overallRating: ((json['overallRating'] as num?)?.toDouble() ?? 3)
          .clamp(1, 5)
          .toDouble(),
      cleanlinessTags: (json['cleanlinessTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      accessibilityTags:
          (json['accessibilityTags'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      cleanlinessOther: json['cleanlinessOther'] as String? ?? '',
      accessibilityOther: json['accessibilityOther'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int,
      imageDataUrl: json['imageDataUrl'] as String?,
      imageDataUrls: (json['imageDataUrls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  final String id;
  final String spotId;
  final String authorNickname;
  final String title;
  final String body;
  final String visitSeason;
  final double cleanlinessRating;
  final double accessibilityRating;
  final double overallRating;
  final List<String> cleanlinessTags;
  final List<String> accessibilityTags;
  final String cleanlinessOther;
  final String accessibilityOther;
  final DateTime createdAt;
  final int likeCount;
  final String authorUid;
  final String? imageDataUrl;
  final List<String> imageDataUrls;
  final bool isLiked;

  List<String> get allImageDataUrls {
    if (imageDataUrls.isNotEmpty) return imageDataUrls;
    final image = imageDataUrl;
    return image == null || image.isEmpty ? const [] : [image];
  }
}

class Mission {
  const Mission({
    required this.id,
    required this.spotId,
    required this.title,
    required this.authorNickname,
    required this.createdAt,
    required this.likeCount,
    required this.verificationCount,
    this.body = '',
    this.targetType = '',
    this.targetId = '',
    this.targetName = '',
    this.routeId = '',
    this.directionId = '',
    this.startStopId = '',
    this.endStopId = '',
    this.selectedLat,
    this.selectedLng,
    this.difficulty = 3,
    this.availableSeason = '',
    this.availableStartDate = '',
    this.availableEndDate = '',
    this.missionTags = const [],
    this.difficultyTags = const [],
    this.verificationMethod = 'photo',
    this.verificationRadiusMeters = 50,
    this.authorUid = '',
    this.imageDataUrl,
    this.isLiked = false,
    this.isVerified = false,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      spotId: json['spotId'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      targetName: json['targetName'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      directionId: json['directionId'] as String? ?? '',
      startStopId: json['startStopId'] as String? ?? '',
      endStopId: json['endStopId'] as String? ?? '',
      selectedLat: (json['selectedLat'] as num?)?.toDouble(),
      selectedLng: (json['selectedLng'] as num?)?.toDouble(),
      difficulty: json['difficulty'] as int? ?? 3,
      availableSeason: json['availableSeason'] as String? ?? '',
      availableStartDate: json['availableStartDate'] as String? ?? '',
      availableEndDate: json['availableEndDate'] as String? ?? '',
      missionTags: (json['missionTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      difficultyTags: (json['difficultyTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      verificationMethod: json['verificationMethod'] as String? ?? 'photo',
      verificationRadiusMeters:
          (json['verificationRadiusMeters'] as num?)?.toInt() ?? 50,
      authorNickname: json['authorNickname'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int,
      verificationCount: json['verificationCount'] as int,
      imageDataUrl: json['imageDataUrl'] as String?,
    );
  }

  final String id;
  final String spotId;
  final String title;
  final String authorNickname;
  final DateTime createdAt;
  final int likeCount;
  final int verificationCount;
  final String body;
  final String targetType;
  final String targetId;
  final String targetName;
  final String routeId;
  final String directionId;
  final String startStopId;
  final String endStopId;
  final double? selectedLat;
  final double? selectedLng;
  final int difficulty;
  final String availableSeason;
  final String availableStartDate;
  final String availableEndDate;
  final List<String> missionTags;
  final List<String> difficultyTags;
  final String verificationMethod;
  final int verificationRadiusMeters;
  final String authorUid;
  final String? imageDataUrl;
  final bool isLiked;
  final bool isVerified;

  double? get representativeScore {
    if (likeCount == 0 && verificationCount == 0) {
      return null;
    }
    return (likeCount + verificationCount) / 2;
  }
}

class GalleryPhoto extends B4yPhoto {
  const GalleryPhoto({
    required super.id,
    required super.imageUrl,
    required super.authorNickname,
    required super.description,
    required super.createdAt,
    required super.likeCount,
    required super.distanceMeters,
    this.spotId = '',
    this.routeId = '',
    this.directionId = '',
    this.startStopId = '',
    this.endStopId = '',
    this.authorUid = '',
    this.isLiked = false,
  });

  factory GalleryPhoto.fromJson(Map<String, dynamic> json) {
    return GalleryPhoto(
      id: json['id'] as String,
      spotId: json['spotId'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      directionId: json['directionId'] as String? ?? '',
      startStopId: json['startStopId'] as String? ?? '',
      endStopId: json['endStopId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String,
      authorNickname: json['authorNickname'] as String,
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      likeCount: json['likeCount'] as int,
      distanceMeters: json['distanceMeters'] as int,
      authorUid: json['authorUid'] as String? ?? '',
    );
  }

  final String spotId;
  final String routeId;
  final String directionId;
  final String startStopId;
  final String endStopId;
  final String authorUid;
  final bool isLiked;

  GalleryPhoto copyWith({int? likeCount, bool? isLiked}) {
    return GalleryPhoto(
      id: id,
      imageUrl: imageUrl,
      authorNickname: authorNickname,
      description: description,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      distanceMeters: distanceMeters,
      spotId: spotId,
      routeId: routeId,
      directionId: directionId,
      startStopId: startStopId,
      endStopId: endStopId,
      authorUid: authorUid,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class B4ySampleData {
  const B4ySampleData({
    required this.stops,
    required this.routes,
    required this.routePhotoClusters,
    required this.touristSpots,
    required this.reviews,
    required this.missions,
    required this.galleryPhotos,
  });

  factory B4ySampleData.fromJson(Map<String, dynamic> json) {
    return B4ySampleData(
      stops: (json['stops'] as List<dynamic>)
          .map((item) => BusStop.fromJson(item as Map<String, dynamic>))
          .toList(),
      routes: (json['routes'] as List<dynamic>)
          .map((item) => BusRoute.fromJson(item as Map<String, dynamic>))
          .toList(),
      routePhotoClusters: (json['routePhotoClusters'] as List<dynamic>)
          .map(
            (item) => RoutePhotoCluster.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      touristSpots: (json['touristSpots'] as List<dynamic>)
          .map((item) => TouristSpot.fromJson(item as Map<String, dynamic>))
          .toList(),
      reviews: (json['reviews'] as List<dynamic>)
          .map((item) => Review.fromJson(item as Map<String, dynamic>))
          .toList(),
      missions: (json['missions'] as List<dynamic>)
          .map((item) => Mission.fromJson(item as Map<String, dynamic>))
          .toList(),
      galleryPhotos: (json['galleryPhotos'] as List<dynamic>)
          .map((item) => GalleryPhoto.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<BusStop> stops;
  final List<BusRoute> routes;
  final List<RoutePhotoCluster> routePhotoClusters;
  final List<TouristSpot> touristSpots;
  final List<Review> reviews;
  final List<Mission> missions;
  final List<GalleryPhoto> galleryPhotos;

  BusStop stopById(String id) => stops.firstWhere((stop) => stop.id == id);

  BusRoute routeById(String id) => routes.firstWhere((route) => route.id == id);

  TouristSpot spotById(String id) =>
      touristSpots.firstWhere((spot) => spot.id == id);
}
