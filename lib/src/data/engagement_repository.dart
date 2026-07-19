import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/b4y_models.dart';

abstract class EngagementRepository {
  Stream<List<Mission>> watchAllMissions(String userId);

  Stream<List<Review>> watchReviews(String spotId, String userId);

  Stream<List<Review>> watchReviewsByAuthor(String authorUid, String userId);

  Stream<List<Mission>> watchMissions(String spotId, String userId);

  Stream<List<Mission>> watchMissionsForRoute(String routeId, String userId);

  Stream<List<Mission>> watchMissionsByAuthor(String authorUid, String userId);

  Future<void> createReview({
    required String spotId,
    required String title,
    required String body,
    required String visitSeason,
    required double cleanlinessRating,
    required double accessibilityRating,
    required double overallRating,
    required List<String> cleanlinessTags,
    required List<String> accessibilityTags,
    required String cleanlinessOther,
    required String accessibilityOther,
    required String authorNickname,
    required String authorUid,
    String? imageDataUrl,
    List<String> imageDataUrls = const [],
  });

  Future<void> createMission({
    required String spotId,
    required String title,
    required String body,
    required String targetType,
    required String targetId,
    required String targetName,
    required String routeId,
    required String directionId,
    required String startStopId,
    required String endStopId,
    required double? selectedLat,
    required double? selectedLng,
    required int difficulty,
    required String availableSeason,
    String? availableStartDate,
    String? availableEndDate,
    required List<String> missionTags,
    required List<String> difficultyTags,
    required String verificationMethod,
    required int verificationRadiusMeters,
    required String authorNickname,
    required String authorUid,
    String? imageDataUrl,
  });

  Future<void> toggleReviewLike(String reviewId, String userId);

  Future<void> toggleMissionLike(String missionId, String userId);

  Future<void> toggleMissionVerification(String missionId, String userId);
}

class FirestoreEngagementRepository implements EngagementRepository {
  FirestoreEngagementRepository(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      firestore.collection('reviews');
  CollectionReference<Map<String, dynamic>> get _missions =>
      firestore.collection('missions');

  @override
  Stream<List<Mission>> watchAllMissions(String userId) async* {
    await for (final snapshot in _missions.snapshots()) {
      final reactions = await _userReactions(firestore, 'missions', userId);
      final missions = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = reactions[doc.reference.path];
          return _missionFromSnapshot(
            doc,
            isLiked: data?['liked'] == true,
            isVerified: data?['verified'] == true,
          );
        }),
      );
      yield sortMissions(missions);
    }
  }

  @override
  Stream<List<Review>> watchReviews(String spotId, String userId) async* {
    final snapshots = _reviews.where('spotId', isEqualTo: spotId).snapshots();
    await for (final snapshot in snapshots) {
      final reactions = await _userReactions(firestore, 'reviews', userId);
      final reviews = await Future.wait(
        snapshot.docs.map((doc) async {
          final photos = await _reviewPhotos(doc.reference);
          return _reviewFromSnapshot(
            doc,
            imageDataUrls: photos,
            isLiked: reactions[doc.reference.path]?['liked'] == true,
          );
        }),
      );
      yield sortReviews(reviews);
    }
  }

  @override
  Stream<List<Review>> watchReviewsByAuthor(
    String authorUid,
    String userId,
  ) async* {
    if (authorUid.isEmpty) {
      yield const <Review>[];
      return;
    }
    final snapshots = _reviews
        .where('authorUid', isEqualTo: authorUid)
        .snapshots();
    await for (final snapshot in snapshots) {
      final reactions = await _userReactions(firestore, 'reviews', userId);
      final reviews = await Future.wait(
        snapshot.docs.map((doc) async {
          final photos = await _reviewPhotos(doc.reference);
          return _reviewFromSnapshot(
            doc,
            imageDataUrls: photos,
            isLiked: reactions[doc.reference.path]?['liked'] == true,
          );
        }),
      );
      yield sortReviews(reviews);
    }
  }

  @override
  Stream<List<Mission>> watchMissions(String spotId, String userId) async* {
    final snapshots = _missions.where('spotId', isEqualTo: spotId).snapshots();
    await for (final snapshot in snapshots) {
      final reactions = await _userReactions(firestore, 'missions', userId);
      final missions = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = reactions[doc.reference.path];
          return _missionFromSnapshot(
            doc,
            isLiked: data?['liked'] == true,
            isVerified: data?['verified'] == true,
          );
        }),
      );
      yield sortMissions(missions);
    }
  }

  @override
  Stream<List<Mission>> watchMissionsForRoute(
    String routeId,
    String userId,
  ) async* {
    final snapshots = _missions
        .where('routeId', isEqualTo: routeId)
        .snapshots();
    await for (final snapshot in snapshots) {
      final reactions = await _userReactions(firestore, 'missions', userId);
      final missions = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = reactions[doc.reference.path];
          return _missionFromSnapshot(
            doc,
            isLiked: data?['liked'] == true,
            isVerified: data?['verified'] == true,
          );
        }),
      );
      yield sortMissions(missions);
    }
  }

  @override
  Stream<List<Mission>> watchMissionsByAuthor(
    String authorUid,
    String userId,
  ) async* {
    if (authorUid.isEmpty) {
      yield const <Mission>[];
      return;
    }
    final snapshots = _missions
        .where('authorUid', isEqualTo: authorUid)
        .snapshots();
    await for (final snapshot in snapshots) {
      final reactions = await _userReactions(firestore, 'missions', userId);
      final missions = await Future.wait(
        snapshot.docs.map((doc) async {
          final data = reactions[doc.reference.path];
          return _missionFromSnapshot(
            doc,
            isLiked: data?['liked'] == true,
            isVerified: data?['verified'] == true,
          );
        }),
      );
      yield sortMissions(missions);
    }
  }

  @override
  Future<void> createReview({
    required String spotId,
    required String title,
    required String body,
    required String visitSeason,
    required double cleanlinessRating,
    required double accessibilityRating,
    required double overallRating,
    required List<String> cleanlinessTags,
    required List<String> accessibilityTags,
    required String cleanlinessOther,
    required String accessibilityOther,
    required String authorNickname,
    required String authorUid,
    String? imageDataUrl,
    List<String> imageDataUrls = const [],
  }) {
    final images = imageDataUrls.isNotEmpty
        ? imageDataUrls
        : [if (imageDataUrl != null && imageDataUrl.isNotEmpty) imageDataUrl];
    final batch = firestore.batch();
    final review = _reviews.doc();
    batch.set(review, {
      'spotId': spotId,
      'title': title.trim(),
      'body': body.trim(),
      'visitSeason': visitSeason.trim(),
      'cleanlinessRating': cleanlinessRating,
      'accessibilityRating': accessibilityRating,
      'overallRating': overallRating,
      'cleanlinessTags': cleanlinessTags,
      'accessibilityTags': accessibilityTags,
      'cleanlinessOther': cleanlinessOther.trim(),
      'accessibilityOther': accessibilityOther.trim(),
      'authorNickname': authorNickname.trim(),
      'authorUid': authorUid,
      'imageDataUrl': null,
      'imageDataUrls': const <String>[],
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var index = 0; index < images.length; index += 1) {
      batch.set(review.collection('photos').doc(), {
        'imageDataUrl': images[index],
        'order': index,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return batch.commit();
  }

  @override
  Future<void> createMission({
    required String spotId,
    required String title,
    required String body,
    required String targetType,
    required String targetId,
    required String targetName,
    required String routeId,
    required String directionId,
    required String startStopId,
    required String endStopId,
    required double? selectedLat,
    required double? selectedLng,
    required int difficulty,
    required String availableSeason,
    String? availableStartDate,
    String? availableEndDate,
    required List<String> missionTags,
    required List<String> difficultyTags,
    required String verificationMethod,
    required int verificationRadiusMeters,
    required String authorNickname,
    required String authorUid,
    String? imageDataUrl,
  }) {
    return _missions.add({
      'spotId': spotId,
      'title': title.trim(),
      'body': body.trim(),
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'routeId': routeId,
      'directionId': directionId,
      'startStopId': startStopId,
      'endStopId': endStopId,
      'selectedLat': selectedLat,
      'selectedLng': selectedLng,
      'difficulty': difficulty,
      'availableSeason': availableSeason.trim(),
      if (availableStartDate != null && availableStartDate.trim().isNotEmpty)
        'availableStartDate': availableStartDate.trim(),
      if (availableEndDate != null && availableEndDate.trim().isNotEmpty)
        'availableEndDate': availableEndDate.trim(),
      'missionTags': missionTags,
      'difficultyTags': difficultyTags,
      'verificationMethod': verificationMethod,
      'verificationRadiusMeters': verificationRadiusMeters,
      'authorNickname': authorNickname.trim(),
      'authorUid': authorUid,
      'imageDataUrl': imageDataUrl,
      'likeCount': 0,
      'verificationCount': 0,
      'representativeScore': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> toggleReviewLike(String reviewId, String userId) {
    final review = _reviews.doc(reviewId);
    final reaction = review.collection('reactions').doc(userId);
    return firestore.runTransaction((transaction) async {
      final reviewSnapshot = await transaction.get(review);
      final reactionSnapshot = await transaction.get(reaction);
      final wasLiked = reactionSnapshot.data()?['liked'] == true;
      final current =
          (reviewSnapshot.data()?['likeCount'] as num?)?.toInt() ?? 0;
      transaction.set(reaction, {'liked': !wasLiked}, SetOptions(merge: true));
      transaction.update(review, {
        'likeCount': (current + (wasLiked ? -1 : 1)).clamp(0, 1 << 31),
      });
    });
  }

  @override
  Future<void> toggleMissionLike(String missionId, String userId) {
    return _toggleMissionReaction(missionId, userId, field: 'liked');
  }

  @override
  Future<void> toggleMissionVerification(String missionId, String userId) {
    return _toggleMissionReaction(missionId, userId, field: 'verified');
  }

  Future<void> _toggleMissionReaction(
    String missionId,
    String userId, {
    required String field,
  }) {
    final mission = _missions.doc(missionId);
    final reaction = mission.collection('reactions').doc(userId);
    return firestore.runTransaction((transaction) async {
      final missionSnapshot = await transaction.get(mission);
      final reactionSnapshot = await transaction.get(reaction);
      final reactionData = reactionSnapshot.data() ?? const <String, dynamic>{};
      var liked = reactionData['liked'] == true;
      var verified = reactionData['verified'] == true;
      final wasActive = field == 'liked' ? liked : verified;
      final data = missionSnapshot.data() ?? const <String, dynamic>{};
      var likes = (data['likeCount'] as num?)?.toInt() ?? 0;
      var verifications = (data['verificationCount'] as num?)?.toInt() ?? 0;
      if (field == 'liked') {
        likes = (likes + (wasActive ? -1 : 1)).clamp(0, 1 << 31);
        liked = !liked;
      } else {
        verifications = (verifications + (wasActive ? -1 : 1)).clamp(
          0,
          1 << 31,
        );
        verified = !verified;
      }
      transaction.set(reaction, {'liked': liked, 'verified': verified});
      transaction.update(mission, {
        'likeCount': likes,
        'verificationCount': verifications,
        'representativeScore': missionRepresentativeScore(likes, verifications),
      });
    });
  }
}

List<Review> sortReviews(Iterable<Review> reviews) {
  final sorted = [...reviews];
  sorted.sort((a, b) {
    final likes = b.likeCount.compareTo(a.likeCount);
    if (likes != 0) return likes;
    final created = b.createdAt.compareTo(a.createdAt);
    if (created != 0) return created;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

List<Mission> sortMissions(Iterable<Mission> missions) {
  final sorted = [...missions];
  sorted.sort((a, b) {
    final score = (b.representativeScore ?? -1).compareTo(
      a.representativeScore ?? -1,
    );
    if (score != 0) return score;
    final created = b.createdAt.compareTo(a.createdAt);
    if (created != 0) return created;
    return a.id.compareTo(b.id);
  });
  return sorted;
}

Mission? topRepresentativeMission(Iterable<Mission> missions) {
  return sortMissions(
    missions.where((mission) => mission.representativeScore != null),
  ).firstOrNull;
}

double? missionRepresentativeScore(int likeCount, int verificationCount) {
  if (likeCount == 0 && verificationCount == 0) return null;
  return (likeCount + verificationCount) / 2;
}

Future<Map<String, Map<String, dynamic>>> _userReactions(
  FirebaseFirestore firestore,
  String collection,
  String userId,
) async {
  if (userId.isEmpty) return const {};
  final snapshot = await firestore
      .collectionGroup('reactions')
      .where(FieldPath.documentId, isEqualTo: userId)
      .get();
  return {
    for (final reaction in snapshot.docs)
      if (reaction.reference.parent.parent?.parent.id == collection)
        reaction.reference.parent.parent!.path: reaction.data(),
  };
}

Future<List<String>> _reviewPhotos(
  DocumentReference<Map<String, dynamic>> review,
) async {
  final snapshot = await review.collection('photos').orderBy('order').get();
  return snapshot.docs
      .map((doc) => doc.data()['imageDataUrl'])
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .toList();
}

Review _reviewFromSnapshot(
  QueryDocumentSnapshot<Map<String, dynamic>> snapshot, {
  required List<String> imageDataUrls,
  required bool isLiked,
}) {
  final data = snapshot.data();
  final legacyImageDataUrls =
      (data['imageDataUrls'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
  final imageDataUrl = data['imageDataUrl'] as String?;
  final images = imageDataUrls.isNotEmpty
      ? imageDataUrls
      : legacyImageDataUrls.isNotEmpty
      ? legacyImageDataUrls
      : [if (imageDataUrl != null && imageDataUrl.isNotEmpty) imageDataUrl];
  return Review(
    id: snapshot.id,
    spotId: data['spotId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    visitSeason: data['visitSeason'] as String? ?? '',
    cleanlinessRating: ((data['cleanlinessRating'] as num?)?.toDouble() ?? 3)
        .clamp(1, 5)
        .toDouble(),
    accessibilityRating:
        ((data['accessibilityRating'] as num?)?.toDouble() ?? 3)
            .clamp(1, 5)
            .toDouble(),
    overallRating: ((data['overallRating'] as num?)?.toDouble() ?? 3)
        .clamp(1, 5)
        .toDouble(),
    cleanlinessTags: (data['cleanlinessTags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    accessibilityTags: (data['accessibilityTags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    cleanlinessOther: data['cleanlinessOther'] as String? ?? '',
    accessibilityOther: data['accessibilityOther'] as String? ?? '',
    authorNickname: data['authorNickname'] as String? ?? '',
    authorUid: data['authorUid'] as String? ?? '',
    imageDataUrl: imageDataUrl,
    imageDataUrls: images,
    createdAt:
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    isLiked: isLiked,
  );
}

Mission _missionFromSnapshot(
  QueryDocumentSnapshot<Map<String, dynamic>> snapshot, {
  required bool isLiked,
  required bool isVerified,
}) {
  final data = snapshot.data();
  return Mission(
    id: snapshot.id,
    spotId: data['spotId'] as String? ?? '',
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    targetType: data['targetType'] as String? ?? '',
    targetId: data['targetId'] as String? ?? '',
    targetName: data['targetName'] as String? ?? '',
    routeId: data['routeId'] as String? ?? '',
    directionId: data['directionId'] as String? ?? '',
    startStopId: data['startStopId'] as String? ?? '',
    endStopId: data['endStopId'] as String? ?? '',
    selectedLat: (data['selectedLat'] as num?)?.toDouble(),
    selectedLng: (data['selectedLng'] as num?)?.toDouble(),
    difficulty: (data['difficulty'] as num?)?.toInt() ?? 3,
    availableSeason: data['availableSeason'] as String? ?? '',
    availableStartDate: data['availableStartDate'] as String? ?? '',
    availableEndDate: data['availableEndDate'] as String? ?? '',
    missionTags: (data['missionTags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    difficultyTags: (data['difficultyTags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    verificationMethod: data['verificationMethod'] as String? ?? 'photo',
    verificationRadiusMeters:
        (data['verificationRadiusMeters'] as num?)?.toInt() ?? 50,
    authorNickname: data['authorNickname'] as String? ?? '',
    authorUid: data['authorUid'] as String? ?? '',
    imageDataUrl: data['imageDataUrl'] as String?,
    createdAt:
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    verificationCount: (data['verificationCount'] as num?)?.toInt() ?? 0,
    isLiked: isLiked,
    isVerified: isVerified,
  );
}
