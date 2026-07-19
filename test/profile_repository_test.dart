import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:b4y/src/data/profile_repository.dart';

void main() {
  test(
    'nickname changes update authored reviews, missions, and gallery photos',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('reviews').doc('mine').set({
        'authorUid': 'user-1',
        'authorNickname': '이전 닉네임',
      });
      await firestore.collection('missions').doc('mine').set({
        'authorUid': 'user-1',
        'authorNickname': '이전 닉네임',
      });
      await firestore.collection('gallery_photos').doc('mine').set({
        'authorUid': 'user-1',
        'authorNickname': '이전 닉네임',
      });
      await firestore.collection('reviews').doc('other').set({
        'authorUid': 'user-2',
        'authorNickname': '다른 사람',
      });

      await FirestoreProfileRepository(
        firestore,
      ).updateAuthoredContentNickname(uid: 'user-1', nickname: '새 닉네임');

      expect(
        (await firestore
            .collection('reviews')
            .doc('mine')
            .get())['authorNickname'],
        '새 닉네임',
      );
      expect(
        (await firestore
            .collection('missions')
            .doc('mine')
            .get())['authorNickname'],
        '새 닉네임',
      );
      expect(
        (await firestore
            .collection('gallery_photos')
            .doc('mine')
            .get())['authorNickname'],
        '새 닉네임',
      );
      expect(
        (await firestore
            .collection('reviews')
            .doc('other')
            .get())['authorNickname'],
        '다른 사람',
      );
    },
  );
}
