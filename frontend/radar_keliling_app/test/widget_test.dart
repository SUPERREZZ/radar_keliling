// Basic widget test for Radar Keliling app
//
// This test verifies the app loads without crashing.
// For comprehensive testing, see TESTING_GUIDE.md

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:radar_keliling/main.dart';

void main() {
  testWidgets('App loads and shows splash screen', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: RadarKeliling()));

    // Verify that the app and splash branding are rendered.
    expect(find.byType(RadarKeliling), findsOneWidget);
    expect(find.text('Radar Keliling'), findsOneWidget);

    // Selesaikan timer splash agar tidak meninggalkan pending timer.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
