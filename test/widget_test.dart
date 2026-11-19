import 'package:flutter_test/flutter_test.dart';
import 'package:depo/main.dart';

void main() {
  testWidgets('التطبيق يفتح بشاشة البداية', (tester) async {
    await tester.pumpWidget(const DepoApp());
    expect(find.text('بسعر أطيب'), findsOneWidget);
  });
}
