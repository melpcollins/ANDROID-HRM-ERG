import 'package:android_hrm_erg/src/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows device setup and control inputs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HrmErgApp()));

    expect(find.text('Device Setup'), findsOneWidget);
    expect(find.text('HRM'), findsOneWidget);
    expect(find.text('Wattbike Trainer'), findsOneWidget);
    expect(find.text('Starting Watts'), findsOneWidget);
    expect(find.text('Target Heart Rate'), findsOneWidget);
    expect(find.text('Loop Interval (seconds)'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('DISCONNECTED'), findsNWidgets(2));
  });
}
