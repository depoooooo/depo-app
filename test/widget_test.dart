import 'package:flutter_test/flutter_test.dart';
import 'package:depo/main.dart';

void main() {
  testWidgets('شاشة البداية تظهر زر ابدأ التصفح', (tester) async {
    await tester.pumpWidget(const DepoApp());
    expect(find.text('ابدأ التصفح'), findsOneWidget);
  });
}
