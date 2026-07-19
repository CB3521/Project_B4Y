import 'package:b4y/src/application/b4y_providers.dart';
import 'package:b4y/src/config/api_keys.dart';
import 'package:b4y/src/data/b4y_repository.dart';
import 'package:b4y/src/presentation/screens/mission_compose_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('mission compose steps split mission rows and execution info', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiKeysProvider.overrideWith((ref) async => ApiKeys.empty),
          currentLocationProvider.overrideWith(
            (ref) async => const LatLng(37.3516, 126.7427),
          ),
          b4yDataProvider.overrideWith(
            (ref) => const AssetB4yRepository().loadSampleData(),
          ),
        ],
        child: const MaterialApp(
          home: MissionComposeScreen(spotId: 'spot_oido'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 100 && find.text('미션 입력').evaluate().isEmpty; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('미션 작성'), findsOneWidget);
    expect(find.text('기본 정보'), findsWidgets);
    expect(find.text('미션 제목'), findsNothing);
    expect(find.text('미션 내용'), findsNothing);

    const missionText = '상가 앞에서 사진 찍기';
    await tester.enterText(find.byType(EditableText).first, missionText);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text(missionText), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      missionText,
    );

    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('수행 정보'), findsWidgets);
    await tester.tap(find.text('현위치'));
    await tester.pump();
    expect(find.text('미션 장소'), findsOneWidget);
    expect(find.textContaining('50m 이내'), findsOneWidget);
    expect(find.byIcon(Icons.location_pin), findsWidgets);
    expect(
      find.byKey(const Key('mission-location-picker-button')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('mission-location-picker-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mission-location-picker-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mission-picker-current-location-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mission-select-map-center-button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('mission-picker-current-location-button')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mission-select-map-center-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mission-location-picker-button')),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    final availableSeasonField = find.byType(TextField).last;
    await tester.ensureVisible(availableSeasonField);
    await tester.pumpAndSettle();
    await tester.tap(availableSeasonField);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });
}
