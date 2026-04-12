import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_log/main.dart';
import 'package:nutri_log/screens/home/home_screen.dart';

void main() {
  testWidgets('App starts and displays HomeScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that HomeScreen is present.
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
