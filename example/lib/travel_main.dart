// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  const apiKey = String.fromEnvironment('CLAUDE_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception(
      'CLAUDE_API_KEY not set. '
      'Run with: flutter run -t lib/travel_main.dart '
      '--dart-define=CLAUDE_API_KEY=your_key',
    );
  }

  runApp(GenUiXTravelApp(apiKey: apiKey));
}

class GenUiXTravelApp extends StatelessWidget {
  const GenUiXTravelApp({super.key, required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI X Travel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: TravelChatPage(apiKey: apiKey),
    );
  }
}

class TravelChatPage extends StatefulWidget {
  const TravelChatPage({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<TravelChatPage> createState() => _TravelChatPageState();
}

class _TravelChatPageState extends State<TravelChatPage> {
  late final GenuiXTransport _transport;
  late final SurfaceController _controller;
  late final Conversation _conversation;

  bool _isWaiting = false;
  String _assistantText = '';
  String _displayedText = '';
  String? _errorText;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    const baseUrl = String.fromEnvironment(
      'CLAUDE_BASE_URL',
      defaultValue: 'https://api.anthropic.com',
    );
    const streamFormatRaw = String.fromEnvironment(
      'CLAUDE_STREAM_FORMAT',
      defaultValue: 'anthropic',
    );
    final streamFormat =
        streamFormatRaw == 'openai' ? GenuiXStreamFormat.openai : GenuiXStreamFormat.anthropic;
    const endpointPathEnv = String.fromEnvironment('CLAUDE_ENDPOINT_PATH');
    final endpointPath = endpointPathEnv.isEmpty
        ? (streamFormat == GenuiXStreamFormat.openai ? '/v1/chat/completions' : '/v1/messages')
        : endpointPathEnv;
    const apiKeyHeaderEnv = String.fromEnvironment('CLAUDE_API_KEY_HEADER');
    final apiKeyHeader = apiKeyHeaderEnv.isEmpty
        ? (streamFormat == GenuiXStreamFormat.openai ? 'authorization' : 'x-api-key')
        : apiKeyHeaderEnv;
    const apiKeyPrefixEnv = String.fromEnvironment('CLAUDE_API_KEY_PREFIX');
    final apiKeyPrefix = apiKeyPrefixEnv.isEmpty
        ? (streamFormat == GenuiXStreamFormat.openai ? 'Bearer ' : '')
        : apiKeyPrefixEnv;
    final requestBodyOverrides = streamFormat == GenuiXStreamFormat.openai
        ? const {
            'response_format': {'type': 'json_object'},
          }
        : const <String, Object?>{};
    _transport = GenuiXTransport(
      apiKey: widget.apiKey,
      catalog: travelCatalog,
      baseUrl: baseUrl,
      endpointPath: endpointPath,
      apiKeyHeader: apiKeyHeader,
      apiKeyPrefix: apiKeyPrefix,
      streamFormat: streamFormat,
      requestBodyOverrides: requestBodyOverrides,
      model: 'claude-sonnet-4-6',
    );
    _controller = SurfaceController(catalogs: [travelCatalog]);
    _conversation = Conversation(controller: _controller, transport: _transport);

    _conversation.events.listen((event) {
      if (event is ConversationContentReceived) {
        setState(() {
          _assistantText = event.text;
          _errorText = null;
          _isWaiting = false;
        });
        _startTypingAnimation(event.text);
      } else if (event is ConversationWaiting) {
        setState(() => _isWaiting = true);
      } else if (event is ConversationError) {
        setState(() {
          _isWaiting = false;
          _errorText = event.error.toString();
        });
      } else if (event is ConversationSurfaceAdded || event is ConversationComponentsUpdated) {
        setState(() => _isWaiting = false);
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _conversation.dispose();
    _controller.dispose();
    _transport.dispose();
    super.dispose();
  }

  void _startTypingAnimation(String text) {
    _typingTimer?.cancel();
    if (text.isEmpty) {
      setState(() => _displayedText = '');
      return;
    }

    if (text.length <= _displayedText.length) {
      setState(() => _displayedText = text);
      return;
    }

    var index = _displayedText.length;
    _typingTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        index += 2;
        if (index >= text.length) {
          index = text.length;
          timer.cancel();
        }
        setState(() => _displayedText = text.substring(0, index));
      },
    );
  }

  Future<void> _sendSample() async {
    if (_isWaiting) return;
    setState(() {
      _isWaiting = true;
      _errorText = null;
    });

    await _conversation.sendRequest(
      ChatMessage.user('Plan a 3-day trip to Kyoto.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = _conversation.state.value.surfaces;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GenUI + X (Travel)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isWaiting ? null : _sendSample,
              child: const Text('Send sample request'),
            ),
            if (_isWaiting) const LinearProgressIndicator(),
            if (_assistantText.isEmpty && _isWaiting)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Thinking...'),
              ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (_assistantText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _displayedText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            if (surfaces.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: surfaces.length,
                  itemBuilder: (context, index) {
                    return Surface(
                      surfaceContext: _controller.contextFor(surfaces[index]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TravelPlanWidget extends StatelessWidget {
  const TravelPlanWidget({
    super.key,
    required this.destination,
    required this.days,
    required this.highlights,
  });

  final String destination;
  final int days;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(destination, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('$days-day plan', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            ...highlights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final travelCatalogItem = CatalogItem(
  name: 'TravelPlanWidget',
  dataSchema: S.object(
    description: 'Shows a concise travel plan for a destination.',
    properties: {
      'destination': S.string(description: 'Destination city or country.'),
      'days': S.integer(description: 'Number of days in the trip.'),
      'highlights': S.list(
        items: S.string(description: 'A highlight for the itinerary.'),
      ),
    },
    required: ['destination', 'days', 'highlights'],
  ),
  widgetBuilder: (ctx) {
    final data = ctx.data as Map<String, dynamic>;
    return TravelPlanWidget(
      destination: data['destination'] as String,
      days: (data['days'] as num).toInt(),
      highlights: (data['highlights'] as List<dynamic>).map((item) => item as String).toList(),
    );
  },
);

final travelCatalog = Catalog(
  [travelCatalogItem],
  catalogId: 'default',
  systemPromptFragments: [
    'For travel planning requests, use TravelPlanWidget to display the plan visually.',
    'Every component object MUST have an "id" field. The root component must use "id":"root". '
        'Widget properties go flat alongside "component" and "id" — no nesting. Example component:\n'
        '{"id":"root","component":"TravelPlanWidget","destination":"Kyoto","days":3,'
        '"highlights":["Fushimi Inari Shrine","Arashiyama Bamboo Grove"]}',
  ],
);
