import 'package:b4y/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login route opens the dedicated login screen', (tester) async {
    await tester.pumpWidget(const B4yApp(initialLocation: '/login'));
    await tester.pump();

    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('이메일 로그인'), findsOneWidget);
    expect(find.text('구글 로그인'), findsOneWidget);
  });
}
