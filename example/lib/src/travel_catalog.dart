// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'widgets/day_card.dart';
import 'widgets/place_card.dart';
import 'widgets/trip_overview_card.dart';

final _tripOverviewItem = CatalogItem(
  name: 'TripOverviewCard',
  dataSchema: S.object(
    description: 'Hero card summarising the whole trip.',
    properties: {
      'destination': S.string(description: 'City or country name.'),
      'days': S.integer(description: 'Total trip duration in days.'),
      'tagline': S.string(description: 'One engaging sentence about the trip.'),
      'budget': S.string(
        description: 'Estimated total budget, e.g. "¥150,000" or "\$1,200".',
      ),
      'emoji': S.string(
        description: 'Single flag or landscape emoji for the destination.',
      ),
    },
    required: ['destination', 'days', 'tagline', 'budget', 'emoji'],
  ),
  widgetBuilder: (ctx) {
    final d = ctx.data as Map<String, dynamic>;
    return TripOverviewCard(
      destination: d['destination'] as String,
      days: (d['days'] as num).toInt(),
      tagline: d['tagline'] as String,
      budget: d['budget'] as String,
      emoji: d['emoji'] as String,
    );
  },
);

final _dayCardItem = CatalogItem(
  name: 'DayCard',
  dataSchema: S.object(
    description: 'Shows the plan for a single day of the trip.',
    properties: {
      'dayNumber': S.integer(description: 'Day number, starting at 1.'),
      'title': S.string(
        description: 'Short title for the day, e.g. "Arrival & Shibuya".',
      ),
      'activities': S.list(
        items: S.string(
          description: 'One activity, meal, or transport note for the day.',
        ),
      ),
    },
    required: ['dayNumber', 'title', 'activities'],
  ),
  widgetBuilder: (ctx) {
    final d = ctx.data as Map<String, dynamic>;
    return DayCard(
      dayNumber: (d['dayNumber'] as num).toInt(),
      title: d['title'] as String,
      activities:
          (d['activities'] as List<dynamic>).map((e) => e as String).toList(),
    );
  },
);

final _placeCardItem = CatalogItem(
  name: 'PlaceCard',
  dataSchema: S.object(
    description:
        'Highlights a specific attraction, restaurant, or experience.',
    properties: {
      'name': S.string(description: 'Place name.'),
      'category': S.string(
        description:
            'Category label, e.g. "Temple", "Restaurant", "Market".',
      ),
      'description': S.string(description: 'One or two sentence description.'),
      'emoji': S.string(description: 'Relevant emoji for the place type.'),
      'tip': S.string(description: 'Optional insider tip for the visitor.'),
    },
    required: ['name', 'category', 'description', 'emoji'],
  ),
  widgetBuilder: (ctx) {
    final d = ctx.data as Map<String, dynamic>;
    return PlaceCard(
      name: d['name'] as String,
      category: d['category'] as String,
      description: d['description'] as String,
      emoji: d['emoji'] as String,
      tip: d['tip'] as String?,
    );
  },
);

final travelCatalog = Catalog(
  [_tripOverviewItem, _dayCardItem, _placeCardItem],
  catalogId: 'travel',
  systemPromptFragments: [
    'You are an enthusiastic travel planning assistant. '
        'When a user asks about a destination or trip, respond with rich '
        'visual components — not plain text.\n\n'
        'Component rules:\n'
        '- Always start with one TripOverviewCard as the root component.\n'
        '- Add one DayCard per day of the trip.\n'
        '- Add PlaceCard entries for 2–4 standout spots per trip.\n'
        '- All component props go inside a "data" object.\n'
        '- Every component needs a unique "id". The first must be "root".\n\n'
        'Example updateComponents payload:\n'
        '{"updateComponents":{"surfaceId":"<id from createSurface>","components":['
        '{"id":"root","component":"TripOverviewCard","data":{'
        '"destination":"Tokyo","days":3,'
        '"tagline":"Neon lights meet ancient temples",'
        '"budget":"¥80,000","emoji":"🗾"}},'
        '{"id":"day1","component":"DayCard","data":{'
        '"dayNumber":1,"title":"Arrival & Shinjuku",'
        '"activities":["Land at Narita, take Narita Express","Check into hotel","Explore Kabukicho at night"]}},'
        '{"id":"place1","component":"PlaceCard","data":{'
        '"name":"Senso-ji Temple","category":"Temple",'
        '"description":"Tokyo\'s oldest temple in Asakusa, built in 628 AD.",'
        '"emoji":"⛩️","tip":"Arrive before 8am to beat the crowds"}}'
        ']}}',
  ],
);
