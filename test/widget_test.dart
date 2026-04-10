// Secondary widget smoke test (non-tautological).
// Keeps a minimal behavior check in the original scaffold file.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_changan/app.dart';

void main() {
  testWidgets('renders app root title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Mi Changan'), findsOneWidget);
  });
}
