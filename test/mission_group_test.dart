import 'package:b4y/src/data/engagement_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mission group creates, joins, and completes independently', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreEngagementRepository(firestore);

    final group = await repository.createMissionGroup(
      missionId: 'mission-1',
      userId: 'user-1',
      nickname: '첫 친구',
    );
    expect(group.inviteCode, hasLength(6));

    await repository.joinMissionGroup(
      inviteCode: group.inviteCode,
      userId: 'user-2',
      nickname: '둘째 친구',
    );
    await repository.toggleMissionGroupVerification(
      groupId: group.id,
      userId: 'user-1',
    );

    final beforeComplete = await firestore
        .collection('mission_groups')
        .doc(group.id)
        .get();
    expect(beforeComplete.data()?['status'], 'active');

    await repository.toggleMissionGroupVerification(
      groupId: group.id,
      userId: 'user-2',
    );
    final afterComplete = await firestore
        .collection('mission_groups')
        .doc(group.id)
        .get();
    expect(afterComplete.data()?['status'], 'completed');
    expect(
      (await firestore.collection('missions').doc('mission-1').get()).exists,
      isFalse,
    );
  });
}
