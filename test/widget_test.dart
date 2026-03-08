import 'package:android_hrm_erg/src/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows device setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HrmErgApp()));

    expect(find.text('Device Setup'), findsOneWidget);
    expect(find.text('Heart Rate Monitor'), findsOneWidget);
    expect(find.text('Wattbike Trainer'), findsOneWidget);
  });
}
