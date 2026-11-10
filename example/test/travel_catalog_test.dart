// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x_example/src/travel_catalog.dart';

/// Renders [root], a component of the travel catalog, as the root of a
/// surface, and returns the errors the renderer reported.
Future<List<A2uiRendererError>> _pumpRoot(
  WidgetTester tester,
  Map<String, Object?> root,
) async {
  final processor = MessageProcessor<ComponentImplementation>(
    catalogs: [travelCatalog],
    validationConfig: ValidationConfig.strict,
  );
  addTearDown(processor.dispose);
  final errors = <A2uiRendererError>[];
  processor.model.onError.subscribe(errors.add);
  processor.processMessages([
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': 'trip', 'catalogId': 'travel-catalog'},
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': 'trip',
        'components': [
          {'id': 'root', ...root},
        ],
      },
    },
  ]);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: A2uiSurface(surface: processor.model.getSurface('trip')!),
        ),
      ),
    ),
  );
  return errors;
}

void main() {
  testWidgets('renders a TripOverviewCard', (tester) async {
    final errors = await _pumpRoot(tester, {
      'component': 'TripOverviewCard',
      'destination': 'Tokyo',
      'days': 3,
      'tagline': 'Neon lights meet ancient temples',
      'budget': '¥80,000',
      'emoji': '🗾',
    });
    expect(errors, isEmpty);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
  });

  testWidgets('renders a DayCard', (tester) async {
    final errors = await _pumpRoot(tester, {
      'component': 'DayCard',
      'dayNumber': 1,
      'title': 'Arrival & Shinjuku',
      'activities': ['Check into hotel', 'Explore Kabukicho at night'],
    });
    expect(errors, isEmpty);
    expect(find.text('Arrival & Shinjuku'), findsOneWidget);
    expect(find.text('Explore Kabukicho at night'), findsOneWidget);
  });

  testWidgets('renders a PlaceCard', (tester) async {
    final errors = await _pumpRoot(tester, {
      'component': 'PlaceCard',
      'name': 'Senso-ji Temple',
      'category': 'Temple',
      'description': "Tokyo's oldest temple.",
      'emoji': '⛩️',
      'tip': 'Arrive before 8am',
    });
    expect(errors, isEmpty);
    expect(find.text('Senso-ji Temple'), findsOneWidget);
    expect(find.textContaining('Arrive before 8am'), findsOneWidget);
  });
}
