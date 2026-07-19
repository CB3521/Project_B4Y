import 'package:b4y/src/data/gallery_repository.dart';
import 'package:b4y/src/domain/b4y_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery photos can be created, watched, and liked', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreGalleryRepository(firestore);

    await repository.createPhoto(
      targetType: 'route',
      targetId: 'route_1',
      routeId: 'route_1',
      directionId: 'up',
      startStopId: 'stop_1',
      endStopId: 'stop_2',
      spotId: '',
      description: '창밖 풍경',
      imageDataUrl: 'data:image/jpeg;base64,abc',
      authorNickname: '방문자',
      authorUid: 'author',
    );

    var photos = await repository
        .watchPhotos(targetType: 'route', targetId: 'route_1', userId: 'user')
        .first;

    expect(photos, hasLength(1));
    expect(photos.single.routeId, 'route_1');
    expect(photos.single.directionId, 'up');
    expect(photos.single.startStopId, 'stop_1');
    expect(photos.single.endStopId, 'stop_2');
    expect(photos.single.description, '창밖 풍경');
    expect(photos.single.isLiked, isFalse);

    await repository.toggleLike(photos.single.id, 'user');
    photos = await repository
        .watchPhotos(targetType: 'route', targetId: 'route_1', userId: 'user')
        .first;

    expect(photos.single.likeCount, 1);
    expect(photos.single.isLiked, isTrue);
  });

  test('popular gallery sorting breaks ties by latest photo', () {
    final old = _photo('old', likes: 3, day: 1);
    final latest = _photo('latest', likes: 3, day: 2);
    final low = _photo('low', likes: 1, day: 3);

    final sorted = sortGalleryPhotos([old, low, latest], GallerySort.popular);

    expect(sorted.map((photo) => photo.id), ['latest', 'old', 'low']);
  });
}

GalleryPhoto _photo(String id, {required int likes, required int day}) {
  return GalleryPhoto(
    id: id,
    imageUrl: 'https://example.com/$id.jpg',
    authorNickname: '방문자',
    description: '',
    createdAt: DateTime.utc(2026, 7, day),
    likeCount: likes,
    distanceMeters: 0,
    routeId: 'route_1',
  );
}
