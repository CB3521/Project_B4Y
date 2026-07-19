import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nickname,
    this.photoDataUrl,
  });

  factory UserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: snapshot.id,
      nickname: data['nickname'] as String? ?? '',
      photoDataUrl: data['photoDataUrl'] as String?,
    );
  }

  final String uid;
  final String nickname;
  final String? photoDataUrl;

  bool get isComplete => nickname.trim().isNotEmpty;
}

abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile(String uid);

  Future<void> saveProfile({
    required String uid,
    required String nickname,
    String? photoDataUrl,
  });

  Future<void> updateAuthoredContentNickname({
    required String uid,
    required String nickname,
  });
}

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection('users');

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserProfile.fromSnapshot(snapshot);
    });
  }

  @override
  Future<void> saveProfile({
    required String uid,
    required String nickname,
    String? photoDataUrl,
  }) {
    final data = <String, Object?>{
      'nickname': nickname.trim(),
      'photoDataUrl': photoDataUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return _users.doc(uid).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> updateAuthoredContentNickname({
    required String uid,
    required String nickname,
  }) async {
    final collections = await Future.wait([
      firestore.collection('reviews').where('authorUid', isEqualTo: uid).get(),
      firestore.collection('missions').where('authorUid', isEqualTo: uid).get(),
      firestore
          .collection('gallery_photos')
          .where('authorUid', isEqualTo: uid)
          .get(),
    ]);
    final documents = collections
        .expand((snapshot) => snapshot.docs)
        .where((document) => document.data()['authorNickname'] != nickname)
        .toList();

    for (var start = 0; start < documents.length; start += 450) {
      final end = (start + 450).clamp(0, documents.length);
      final batch = firestore.batch();
      for (final document in documents.sublist(start, end)) {
        batch.update(document.reference, {'authorNickname': nickname});
      }
      await batch.commit();
    }
  }
}
