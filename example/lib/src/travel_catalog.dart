// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'widgets/day_card.dart';
import 'widgets/place_card.dart';
import 'widgets/trip_overview_card.dart';

String _readString(Map<String, dynamic> data, String key, String fallback) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  if (value != null) {
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

int _readInt(Map<String, dynamic> data, String key, int fallback) {
  final value = data[key];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! List) return const <String>[];
  return value
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}

Map<String, dynamic> _normalizeProps(Map<String, dynamic> data) {
  final nested = data['data'];
  if (nested is Map) {
    return nested.cast<String, dynamic>();
  }
  return data;
}

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
    final raw = (ctx.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final d = _normalizeProps(raw);
    return TripOverviewCard(
      destination: _readString(d, 'destination', 'Your destination'),
      days: _readInt(d, 'days', 1),
      tagline: _readString(d, 'tagline', 'A personalized itinerary is ready.'),
      budget: _readString(d, 'budget', 'Budget TBD'),
      emoji: _readString(d, 'emoji', '✈️'),
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
    final raw = (ctx.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final d = _normalizeProps(raw);
    final activities = _readStringList(d, 'activities');
    return DayCard(
      dayNumber: _readInt(d, 'dayNumber', 1),
      title: _readString(d, 'title', 'Day plan'),
      activities: activities.isEmpty
          ? const ['Details will be added shortly.']
          : activities,
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
    final raw = (ctx.data as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final d = _normalizeProps(raw);
    return PlaceCard(
      name: _readString(d, 'name', 'Recommended place'),
      category: _readString(d, 'category', 'Attraction'),
      description: _readString(
        d,
        'description',
        'A suggested stop for your itinerary.',
      ),
      emoji: _readString(d, 'emoji', '📍'),
      tip: d['tip']?.toString(),
    );
  },
);

Catalog _buildTravelCatalog(String catalogId) {
  return Catalog(
    [_tripOverviewItem, _dayCardItem, _placeCardItem],
    catalogId: catalogId,
    systemPromptFragments: [
      'You are an enthusiastic travel planning assistant. '
          'When a user asks about a destination or trip, respond with rich '
          'visual components — not plain text.\n\n'
          '- Always use catalogId "travel-catalog" when creating surfaces.\n'
          'Component rules:\n'
          '- Always start with one TripOverviewCard as the root component.\n'
          '- Add one DayCard per day of the trip.\n'
          '- Add PlaceCard entries for 2–4 standout spots per trip.\n'
          '- Every component needs a unique "id". The first must be "root".\n\n'
          'Example updateComponents payload:\n'
          '{"updateComponents":{"surfaceId":"<id from createSurface>","components":['
          '{"id":"root","component":"TripOverviewCard",'
          '"destination":"Tokyo","days":3,'
          '"tagline":"Neon lights meet ancient temples",'
          '"budget":"¥80,000","emoji":"🗾"},'
          '{"id":"day1","component":"DayCard",'
          '"dayNumber":1,"title":"Arrival & Shinjuku",'
          '"activities":["Land at Narita, take Narita Express","Check into hotel","Explore Kabukicho at night"]},'
          '{"id":"place1","component":"PlaceCard",'
          '"name":"Senso-ji Temple","category":"Temple",'
          '"description":"Tokyo\'s oldest temple in Asakusa, built in 628 AD.",'
          '"emoji":"⛩️","tip":"Arrive before 8am to beat the crowds"}'
          ']}}',
    ],
  );
}

final travelCatalog = _buildTravelCatalog('travel-catalog');
final travelCatalogLegacy = _buildTravelCatalog('travel');
