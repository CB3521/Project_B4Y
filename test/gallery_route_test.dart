import 'package:b4y/main.dart';
import 'package:b4y/src/presentation/screens/gallery_screen.dart';
import 'package:b4y/src/presentation/screens/gallery_upload_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route gallery URL opens the gallery screen', (tester) async {
    await tester.pumpWidget(
      const B4yApp(initialLocation: '/gallery?routeId=odsay_route_6517'),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryScreen), findsOneWidget);
  });

  testWidgets('route gallery URL keeps the route label while data loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const B4yApp(
        initialLocation:
            '/gallery?routeId=odsay_route_6517&routeLabel=6517%EB%B2%88',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('6517번 갤러리'), findsOneWidget);
  });

  testWidgets('gallery upload URL opens the separate upload screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const B4yApp(
        initialLocation:
            '/gallery/upload?targetType=route&targetId=odsay_route_6517&routeId=odsay_route_6517',
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(GalleryUploadScreen), findsOneWidget);
    expect(find.text('사진 올리기'), findsNWidgets(2));
    expect(find.text('제목'), findsOneWidget);
  });
}
