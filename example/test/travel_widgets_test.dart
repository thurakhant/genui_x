// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x_example/src/widgets/trip_overview_card.dart';

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
}
