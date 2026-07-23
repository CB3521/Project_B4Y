import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/b4y_models.dart';

class MissionGroupMember {
  const MissionGroupMember({
    required this.uid,
    required this.nickname,
    required this.verified,
  });

  final String uid;
  final String nickname;
  final bool verified;
}

class MissionGroup {
  const MissionGroup({
    required this.id,
    required this.missionId,
    required this.inviteCode,
    required this.creatorUid,
    required this.status,
    required this.memberUids,
    required this.members,
  });

  final String id;
  final String missionId;
  final String inviteCode;
  final String creatorUid;
  final String status;
  final List<String> memberUids;
  final List<MissionGroupMember> members;

  bool get isCompleted =>
      status == 'completed' ||
      (members.isNotEmpty && members.every((member) => member.verified));
}

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

  Future<MissionGroup> createMissionGroup({
    required String missionId,
    required String userId,
    required String nickname,
  });

  Stream<MissionGroup?> watchMissionGroup(String missionId, String userId);

  Future<MissionGroup> joinMissionGroup({
    required String inviteCode,
    required String userId,
    required String nickname,
  });

  Future<void> toggleMissionGroupVerification({
    required String groupId,
    required String userId,
  });

  Future<void> leaveMissionGroup({
    required String groupId,
    required String userId,
  });
}

class FirestoreEngagementRepository implements EngagementRepository {
  FirestoreEngagementRepository(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      firestore.collection('reviews');
  CollectionReference<Map<String, dynamic>> get _missions =>
      firestore.collection('missions');
  CollectionReference<Map<String, dynamic>> get _missionGroups =>
      firestore.collection('mission_groups');

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

  @override
  Future<MissionGroup> createMissionGroup({
    required String missionId,
    required String userId,
    required String nickname,
  }) async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      final code = _newMissionGroupCode();
      final existing = await _missionGroups
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;
      final group = _missionGroups.doc();
      final member = group.collection('members').doc(userId);
      final batch = firestore.batch();
      batch.set(group, {
        'missionId': missionId,
        'inviteCode': code,
        'creatorUid': userId,
        'status': 'active',
        'memberUids': [userId],
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      });
      batch.set(member, {
        'uid': userId,
        'nickname': nickname.trim(),
        'verified': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return MissionGroup(
        id: group.id,
        missionId: missionId,
        inviteCode: code,
        creatorUid: userId,
        status: 'active',
        memberUids: [userId],
        members: [
          MissionGroupMember(
            uid: userId,
            nickname: nickname.trim(),
            verified: false,
          ),
        ],
      );
    }
    throw StateError('친구 초대 코드를 만들지 못했어요. 다시 시도해 주세요.');
  }

  @override
  Stream<MissionGroup?> watchMissionGroup(
    String missionId,
    String userId,
  ) async* {
    if (userId.isEmpty) {
      yield null;
      return;
    }
    await for (final snapshot
        in _missionGroups
            .where('memberUids', arrayContains: userId)
            .snapshots()) {
      final group = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['missionId'] == missionId && data['status'] == 'active';
      }).firstOrNull;
      if (group == null) {
        yield null;
        continue;
      }
      yield await _missionGroupFromSnapshot(group);
    }
  }

  @override
  Future<MissionGroup> joinMissionGroup({
    required String inviteCode,
    required String userId,
    required String nickname,
  }) async {
    final snapshot = await _missionGroups
        .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw StateError('초대 코드를 찾을 수 없어요.');
    }
    final group = snapshot.docs.single;
    final data = group.data();
    final members = List<String>.from(data['memberUids'] as List? ?? const []);
    if (data['status'] != 'active') throw StateError('이미 완료된 그룹이에요.');
    if (members.contains(userId)) return _missionGroupFromSnapshot(group);
    if (members.length >= 10) throw StateError('그룹 인원이 가득 찼어요.');
    final member = group.reference.collection('members').doc(userId);
    final batch = firestore.batch();
    batch.update(group.reference, {
      'memberUids': [...members, userId],
    });
    batch.set(member, {
      'uid': userId,
      'nickname': nickname.trim(),
      'verified': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return _missionGroupFromSnapshot(group);
  }

  @override
  Future<void> toggleMissionGroupVerification({
    required String groupId,
    required String userId,
  }) async {
    final group = _missionGroups.doc(groupId);
    final member = group.collection('members').doc(userId);
    await firestore.runTransaction((transaction) async {
      final groupSnapshot = await transaction.get(group);
      final memberSnapshot = await transaction.get(member);
      final data = groupSnapshot.data() ?? const <String, dynamic>{};
      final current = memberSnapshot.data()?['verified'] == true;
      if (!current) {
        final memberUids = List<String>.from(
          data['memberUids'] as List? ?? const [],
        );
        final memberSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final uid in memberUids.where((uid) => uid != userId)) {
          memberSnapshots.add(
            await transaction.get(group.collection('members').doc(uid)),
          );
        }
        final allVerified = memberSnapshots.every(
          (snapshot) => snapshot.data()?['verified'] == true,
        );
        transaction.update(member, {'verified': true});
        if (allVerified) {
          transaction.update(group, {
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });
        }
      } else if (data['status'] == 'completed') {
        transaction.update(member, {'verified': false});
        transaction.update(group, {'status': 'active', 'completedAt': null});
      } else {
        transaction.update(member, {'verified': false});
      }
    });
  }

  @override
  Future<void> leaveMissionGroup({
    required String groupId,
    required String userId,
  }) async {
    final group = _missionGroups.doc(groupId);
    final member = group.collection('members').doc(userId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(group);
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['status'] == 'completed') {
        throw StateError('완료된 그룹에서는 나갈 수 없어요.');
      }
      final members = List<String>.from(data['memberUids'] as List? ?? const [])
        ..remove(userId);
      transaction.delete(member);
      if (members.isEmpty) {
        transaction.delete(group);
      } else {
        transaction.update(group, {'memberUids': members});
      }
    });
  }

  Future<MissionGroup> _missionGroupFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final memberSnapshot = await snapshot.reference.collection('members').get();
    return MissionGroup(
      id: snapshot.id,
      missionId: data['missionId'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      creatorUid: data['creatorUid'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      memberUids: List<String>.from(data['memberUids'] as List? ?? const []),
      members: memberSnapshot.docs
          .map(
            (doc) => MissionGroupMember(
              uid: doc.id,
              nickname: doc.data()['nickname'] as String? ?? '',
              verified: doc.data()['verified'] == true,
            ),
          )
          .toList(),
    );
  }
}

String _newMissionGroupCode() {
  final seed = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return seed.substring(seed.length - 6).toUpperCase().padLeft(6, '0');
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
  try {
    final snapshot = await firestore
        .collectionGroup('reactions')
        .where(FieldPath.documentId, isEqualTo: userId)
        .get();
    return {
      for (final reaction in snapshot.docs)
        if (reaction.reference.parent.parent?.parent.id == collection)
          reaction.reference.parent.parent!.path: reaction.data(),
    };
  } on FirebaseException {
    // A reaction read failure must not prevent the parent content from loading.
    return const {};
  }
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
