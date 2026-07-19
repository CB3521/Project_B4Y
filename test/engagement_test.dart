import 'dart:typed_data';

import 'package:b4y/src/data/engagement_repository.dart';
import 'package:b4y/src/data/image_data_url.dart';
import 'package:b4y/src/domain/b4y_models.dart';
import 'package:b4y/src/presentation/widgets/engagement_card.dart';
import 'package:b4y/src/presentation/widgets/photo_thumb.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('representative selection', () {
    test('review uses likes, latest date, then id', () {
      final reviews = [
        _review('old', likes: 3, day: 1),
        _review('b', likes: 3, day: 2),
        _review('a', likes: 3, day: 2),
        _review('low', likes: 2, day: 3),
      ];

      expect(sortReviews(reviews).map((item) => item.id), [
        'a',
        'b',
        'old',
        'low',
      ]);
    });

    test(
      'mission averages reactions and excludes zero-zero from representative',
      () {
        final missions = [
          _mission('zero', likes: 0, verifications: 0, day: 4),
          _mission('likes', likes: 4, verifications: 0, day: 1),
          _mission('balanced', likes: 2, verifications: 2, day: 2),
        ];

        expect(missionRepresentativeScore(0, 0), isNull);
        expect(missionRepresentativeScore(4, 0), 2);
        expect(topRepresentativeMission(missions)?.id, 'balanced');
        expect(sortMissions(missions).last.id, 'zero');
      },
    );
  });

  test('image is resized and round-trips as a jpeg data URL', () {
    final source = img.Image(width: 1400, height: 900);
    img.fill(source, color: img.ColorRgb8(30, 120, 200));

    final dataUrl = encodeImageDataUrl(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decodedBytes = decodeImageDataUrl(dataUrl);
    final decoded = img.decodeImage(decodedBytes!);

    expect(dataUrl, startsWith('data:image/jpeg;base64,'));
    expect(dataUrl.length, lessThan(maxImageDataUrlBytes));
    expect(decoded?.width, maxImageLongSidePixels);
    expect(decoded?.height, lessThanOrEqualTo(maxImageLongSidePixels));
  });

  test('Firestore reactions toggle counts and representative score', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreEngagementRepository(firestore);
    await firestore.collection('reviews').doc('review').set({
      'spotId': 'spot',
      'title': '리뷰',
      'authorNickname': '작성자',
      'authorUid': 'author',
      'imageDataUrl': null,
      'likeCount': 0,
      'createdAt': Timestamp.now(),
    });
    await firestore.collection('missions').doc('mission').set({
      'spotId': 'spot',
      'title': '미션',
      'authorNickname': '작성자',
      'authorUid': 'author',
      'imageDataUrl': null,
      'likeCount': 0,
      'verificationCount': 0,
      'representativeScore': null,
      'createdAt': Timestamp.now(),
    });

    await repository.toggleReviewLike('review', 'user');
    await repository.toggleMissionLike('mission', 'user');
    await repository.toggleMissionVerification('mission', 'user');

    expect(
      (await firestore.collection('reviews').doc('review').get())['likeCount'],
      1,
    );
    final mission = await firestore.collection('missions').doc('mission').get();
    expect(mission['likeCount'], 1);
    expect(mission['verificationCount'], 1);
    expect(mission['representativeScore'], 1);

    await repository.toggleReviewLike('review', 'user');
    await repository.toggleMissionLike('mission', 'user');
    await repository.toggleMissionVerification('mission', 'user');
    expect(
      (await firestore.collection('reviews').doc('review').get())['likeCount'],
      0,
    );
    final reset = await firestore.collection('missions').doc('mission').get();
    expect(reset['likeCount'], 0);
    expect(reset['verificationCount'], 0);
    expect(reset['representativeScore'], isNull);
  });

  test('Firestore review creation stores optional review details', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreEngagementRepository(firestore);

    await repository.createReview(
      spotId: 'spot',
      title: '',
      body: '조용하고 걷기 좋았어요.',
      visitSeason: '2026년 봄',
      cleanlinessRating: 4.5,
      accessibilityRating: 3.5,
      overallRating: 4,
      cleanlinessTags: const ['길이 깨끗해요', '기타'],
      accessibilityTags: const ['정류장과 가까워요'],
      cleanlinessOther: '벤치 주변도 정돈되어 있었어요.',
      accessibilityOther: '',
      authorNickname: '작성자',
      authorUid: 'author',
      imageDataUrls: const [
        'data:image/jpeg;base64,first',
        'data:image/jpeg;base64,second',
      ],
    );

    final snapshot = await firestore.collection('reviews').get();
    final data = snapshot.docs.single.data();
    expect(data['title'], '');
    expect(data['body'], '조용하고 걷기 좋았어요.');
    expect(data['visitSeason'], '2026년 봄');
    expect(data['cleanlinessRating'], 4.5);
    expect(data['accessibilityRating'], 3.5);
    expect(data['overallRating'], 4);
    expect(data['cleanlinessTags'], ['길이 깨끗해요', '기타']);
    expect(data['accessibilityTags'], ['정류장과 가까워요']);
    expect(data['cleanlinessOther'], '벤치 주변도 정돈되어 있었어요.');
    expect(data['imageDataUrl'], isNull);
    expect(data['imageDataUrls'], isEmpty);
    expect(data['likeCount'], 0);

    final photos = await snapshot.docs.single.reference
        .collection('photos')
        .orderBy('order')
        .get();
    expect(photos.docs.map((doc) => doc.data()['imageDataUrl']), [
      'data:image/jpeg;base64,first',
      'data:image/jpeg;base64,second',
    ]);
    final reviews = await repository.watchReviews('spot', '').first;
    expect(reviews.single.imageDataUrls, [
      'data:image/jpeg;base64,first',
      'data:image/jpeg;base64,second',
    ]);
  });

  test(
    'Firestore mission creation stores target and verification details',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreEngagementRepository(firestore);

      await repository.createMission(
        spotId: 'spot',
        title: '정류장 사이 걷기',
        body: '두 정류장 사이 구간을 걸어 보세요.',
        targetType: 'route',
        targetId: 'route_1',
        targetName: '11',
        routeId: 'route_1',
        directionId: 'up',
        startStopId: 'stop_1',
        endStopId: 'stop_2',
        selectedLat: null,
        selectedLng: null,
        difficulty: 4,
        availableSeason: '맑은 날',
        availableStartDate: '2026-07-20',
        availableEndDate: '2026-07-22',
        missionTags: const ['#시흥', '#GPS'],
        difficultyTags: const ['시간대가 중요해요', '날씨가 중요해요'],
        verificationMethod: 'location',
        verificationRadiusMeters: 50,
        authorNickname: '작성자',
        authorUid: 'author',
        imageDataUrl: null,
      );

      final snapshot = await firestore.collection('missions').get();
      final data = snapshot.docs.single.data();
      expect(data['body'], '두 정류장 사이 구간을 걸어 보세요.');
      expect(data['targetType'], 'route');
      expect(data['routeId'], 'route_1');
      expect(data['directionId'], 'up');
      expect(data['startStopId'], 'stop_1');
      expect(data['endStopId'], 'stop_2');
      expect(data['difficulty'], 4);
      expect(data['availableSeason'], '맑은 날');
      expect(data['availableStartDate'], '2026-07-20');
      expect(data['availableEndDate'], '2026-07-22');
      expect(data['missionTags'], ['#시흥', '#GPS']);
      expect(data['difficultyTags'], ['시간대가 중요해요', '날씨가 중요해요']);
      expect(data['verificationMethod'], 'location');
      expect(data['verificationRadiusMeters'], 50);
      expect(data['verificationCount'], 0);
    },
  );

  testWidgets('review card keeps text left and placeholder right', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReviewCard(review: _review('review'), onLike: null),
        ),
      ),
    );

    expect(find.text('제목 review'), findsOneWidget);
    expect(find.text('작성자'), findsOneWidget);
    expect(find.byType(PhotoPlaceholder), findsOneWidget);
    final titleX = tester.getTopLeft(find.text('제목 review')).dx;
    final photoX = tester.getTopLeft(find.byType(PhotoPlaceholder)).dx;
    expect(titleX, lessThan(photoX));
  });
}

Review _review(String id, {int likes = 0, int day = 1}) {
  return Review(
    id: id,
    spotId: 'spot',
    authorNickname: '작성자',
    title: '제목 $id',
    createdAt: DateTime.utc(2026, 6, day),
    likeCount: likes,
  );
}

Mission _mission(
  String id, {
  required int likes,
  required int verifications,
  required int day,
}) {
  return Mission(
    id: id,
    spotId: 'spot',
    title: id,
    authorNickname: '작성자',
    createdAt: DateTime.utc(2026, 6, day),
    likeCount: likes,
    verificationCount: verifications,
  );
}
