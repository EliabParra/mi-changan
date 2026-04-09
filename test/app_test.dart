// app_test.dart
//
// Smoke test — verifies that the root App widget bootstraps and renders
// the home placeholder screen with the expected title and key.
//
// TDD Batch C — Phase 5:
//   5.1 RED  → test references Key('home_placeholder') which doesn't exist yet
//   5.2 GREEN → add Key to _PlaceholderHomeScreen.build in app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_changan/app.dart';

void main() {
  group('App bootstrap', () {
    testWidgets(
        'renders home placeholder with title "Mi Changan" and home_placeholder key',
        (WidgetTester tester) async {
      // Arrange: wrap App in ProviderScope (required for ConsumerWidget)
      await tester.pumpWidget(
        const ProviderScope(
          child: App(),
        ),
      );

      // Act: settle all pending frames
      await tester.pumpAndSettle();

      // Assert (1): app bar title is visible — proves routing delivered a screen
      expect(find.text('Mi Changan'), findsOneWidget);

      // Assert (2): scaffold has the expected key — proves home_placeholder
      // is the active route.
      expect(find.byKey(const Key('home_placeholder')), findsOneWidget);
    });

    // TRIANGULATE — different code path: body content of placeholder
    testWidgets(
        'home placeholder body shows "en construcción" under-construction text',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(
          child: App(),
        ),
      );
      await tester.pumpAndSettle();

      // Assert: body text is visible — different widget than AppBar title,
      // exercises the Scaffold body rendering path
      expect(
        find.text('Mi Changan — en construcción'),
        findsOneWidget,
      );
    });
  });
}
