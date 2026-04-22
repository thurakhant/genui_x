// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x_example/src/widgets/trip_overview_card.dart';
import 'package:genui_x_example/src/widgets/day_card.dart';
import 'package:genui_x_example/src/widgets/place_card.dart';

void main() {
  group('TripOverviewCard', () {
    testWidgets('renders destination and days', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TripOverviewCard(
              destination: 'Tokyo',
              days: 5,
              tagline: 'City of contrasts',
              budget: '¥150,000',
              emoji: '🗾',
            ),
          ),
        ),
      );
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('5 days'), findsOneWidget);
    });
  });

  group('DayCard', () {
    testWidgets('renders day number and activities', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DayCard(
              dayNumber: 1,
              title: 'Arrival & Shinjuku',
              activities: ['Check into hotel', 'Explore Kabukicho at night'],
            ),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Arrival & Shinjuku'), findsOneWidget);
      expect(find.text('Check into hotel'), findsOneWidget);
    });
  });

  group('PlaceCard', () {
    testWidgets('renders name and category', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaceCard(
              name: 'Senso-ji Temple',
              category: 'Temple',
              description: 'Tokyo\'s oldest temple in Asakusa.',
              emoji: '⛩️',
            ),
          ),
        ),
      );
      expect(find.text('Senso-ji Temple'), findsOneWidget);
      expect(find.text('Temple'), findsOneWidget);
    });

    testWidgets('renders optional tip when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaceCard(
              name: 'Senso-ji Temple',
              category: 'Temple',
              description: 'Old temple.',
              emoji: '⛩️',
              tip: 'Arrive early to avoid crowds',
            ),
          ),
        ),
      );
      expect(find.textContaining('Arrive early'), findsOneWidget);
    });

    testWidgets('does not render tip section when tip is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaceCard(
              name: 'Senso-ji Temple',
              category: 'Temple',
              description: 'Old temple.',
              emoji: '⛩️',
            ),
          ),
        ),
      );
      expect(find.textContaining('💡'), findsNothing);
    });
  });
}
