import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yash_honda_crm/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: YashHondaApp(),
      ),
    );
    expect(find.byType(YashHondaApp), findsOneWidget);
  });
}
