// Basic widget test for Radar Keliling app
//
// This test verifies the app loads without crashing.
// For comprehensive testing, see TESTING_GUIDE.md

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:radar_keliling/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: RadarKeliling(),
      ),
    );

    // Verify that the app widget exists
    expect(find.byType(RadarKeliling), findsOneWidget);
  });
}
