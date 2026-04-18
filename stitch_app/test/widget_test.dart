import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_app/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StitchApp());
    expect(find.text('Welcome back!'), findsOneWidget);
  });
}
