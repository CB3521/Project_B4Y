import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/b4y_models.dart';

abstract class GalleryRepository {
  Stream<List<GalleryPhoto>> watchAllPhotos({required String userId});

  Stream<List<GalleryPhoto>> watchPhotos({
    required String targetType,
    required String targetId,
    required String userId,
  });

  Future<void> createPhoto({
    required String targetType,
    required String targetId,
    required String routeId,
    required String directionId,
    required String startStopId,
    required String endStopId,
    required String spotId,
    required String description,
    required String imageDataUrl,
    required String authorNickname,
    required String authorUid,
  });

  Future<void> toggleLike(String photoId, String userId);
}

class FirestoreGalleryRepository implements GalleryRepository {
  FirestoreGalleryRepository(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _photos =>
      firestore.collection('gallery_photos');

  @override
  Stream<List<GalleryPhoto>> watchAllPhotos({required String userId}) async* {
    await for (final snapshot in _photos.snapshots()) {
      final photos = await Future.wait(
        snapshot.docs.map((doc) async {
          return _photoFromSnapshot(
            doc,
            // Do not make the gallery listing depend on the collection-group
            // reaction lookup. Native Firestore rejects that query on some
            // platforms; liking still works through toggleLike().
            isLiked: false,
          );
        }),
      );
      yield sortGalleryPhotos(photos, GallerySort.latest, limit: photos.length);
    }
  }

  @override
  Stream<List<GalleryPhoto>> watchPhotos({
    required String targetType,
    required String targetId,
    required String userId,
  }) async* {
    final snapshots = _photos
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .snapshots();
    await for (final snapshot in snapshots) {
      final photos = await Future.wait(
        snapshot.docs.map((doc) async {
          return _photoFromSnapshot(doc, isLiked: false);
        }),
      );
      yield sortGalleryPhotos(photos, GallerySort.latest, limit: photos.length);
    }
  }

  @override
  Future<void> createPhoto({
    required String targetType,
    required String targetId,
    required String routeId,
    required String directionId,
    required String startStopId,
    required String endStopId,
    required String spotId,
    required String description,
    required String imageDataUrl,
    required String authorNickname,
    required String authorUid,
  }) {
    return _photos.add({
      'targetType': targetType,
      'targetId': targetId,
      'routeId': routeId,
      'directionId': directionId,
      'startStopId': startStopId,
      'endStopId': endStopId,
      'spotId': spotId,
      'description': description.trim(),
      'imageDataUrl': imageDataUrl,
      'authorNickname': authorNickname.trim(),
      'authorUid': authorUid,
      'likeCount': 0,
      'distanceMeters': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> toggleLike(String photoId, String userId) {
    final photo = _photos.doc(photoId);
    final reaction = photo.collection('reactions').doc(userId);
    return firestore.runTransaction((transaction) async {
      final photoSnapshot = await transaction.get(photo);
      final reactionSnapshot = await transaction.get(reaction);
      final wasLiked = reactionSnapshot.data()?['liked'] == true;
      final current =
          (photoSnapshot.data()?['likeCount'] as num?)?.toInt() ?? 0;
      transaction.set(reaction, {'liked': !wasLiked}, SetOptions(merge: true));
      transaction.update(photo, {
        'likeCount': (current + (wasLiked ? -1 : 1)).clamp(0, 1 << 31),
      });
    });
  }
}

List<GalleryPhoto> sortGalleryPhotos(
  Iterable<GalleryPhoto> photos,
  GallerySort sort, {
  int limit = 5,
}) {
  final sorted = [...photos];
  switch (sort) {
    case GallerySort.popular:
      sorted.sort((a, b) {
        final likes = b.likeCount.compareTo(a.likeCount);
        if (likes != 0) return likes;
        return b.createdAt.compareTo(a.createdAt);
      });
    case GallerySort.latest:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case GallerySort.distance:
      sorted.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }
  return sorted.take(limit).toList();
}

GalleryPhoto _photoFromSnapshot(
  QueryDocumentSnapshot<Map<String, dynamic>> snapshot, {
  required bool isLiked,
}) {
  final data = snapshot.data();
  return GalleryPhoto(
    id: snapshot.id,
    spotId: data['spotId'] as String? ?? '',
    routeId: data['routeId'] as String? ?? '',
    directionId: data['directionId'] as String? ?? '',
    startStopId: data['startStopId'] as String? ?? '',
    endStopId: data['endStopId'] as String? ?? '',
    imageUrl:
        data['imageDataUrl'] as String? ?? data['imageUrl'] as String? ?? '',
    authorNickname: data['authorNickname'] as String? ?? '',
    authorUid: data['authorUid'] as String? ?? '',
    description: data['description'] as String? ?? '',
    createdAt:
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    distanceMeters: (data['distanceMeters'] as num?)?.toInt() ?? 0,
    isLiked: isLiked,
  );
}
