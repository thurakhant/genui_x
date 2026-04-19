// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
//
// Gemini example — shows how to connect genui_x to Google's Gemini API
// using the GenuiXTransport.gemini() factory.
//
// Run with:
//   flutter run -t lib/gemini_main.dart \
//     --dart-define=GEMINI_API_KEY=your-google-api-key

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception(
      'GEMINI_API_KEY not set. '
      'Run with: flutter run -t lib/gemini_main.dart '
      '--dart-define=GEMINI_API_KEY=your_key',
    );
  }

  runApp(GeminiExampleApp(apiKey: apiKey));
}

class GeminiExampleApp extends StatelessWidget {
  const GeminiExampleApp({super.key, required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI X — Gemini',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: GeminiChatPage(apiKey: apiKey),
    );
  }
}

class GeminiChatPage extends StatefulWidget {
  const GeminiChatPage({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<GeminiChatPage> createState() => _GeminiChatPageState();
}

class _GeminiChatPageState extends State<GeminiChatPage> {
  late final GenuiXTransport _transport;
  late final SurfaceController _controller;
  late final Conversation _conversation;

  final _textController = TextEditingController();
  bool _isWaiting = false;
  String _assistantText = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    const model = String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-2.5-flash',
    );

    // ── Transport configuration for Google Gemini ────────────────────────
    _transport = GenuiXTransport.gemini(
      apiKey: widget.apiKey,
      catalog: weatherCatalog,
      model: model,
      debug: true, // remove in production
    );
    // ─────────────────────────────────────────────────────────────────────

    _controller = SurfaceController(catalogs: [weatherCatalog]);
    _conversation = Conversation(
      controller: _controller,
      transport: _transport,
    );

    _conversation.events.listen((event) {
      if (event is ConversationContentReceived) {
        setState(() {
          _assistantText = event.text;
          _errorText = null;
          _isWaiting = false;
        });
      } else if (event is ConversationWaiting) {
        setState(() => _isWaiting = true);
      } else if (event is ConversationError) {
        setState(() {
          _isWaiting = false;
          _errorText = event.error.toString();
        });
      } else if (event is ConversationSurfaceAdded ||
          event is ConversationComponentsUpdated) {
        setState(() => _isWaiting = false);
      }
    });
  }

  @override
  void dispose() {
    _conversation.dispose();
    _controller.dispose();
    _transport.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isWaiting) return;

    setState(() {
      _isWaiting = true;
      _errorText = null;
    });
    _textController.clear();

    await _conversation.sendRequest(ChatMessage.user(text));
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = _conversation.state.value.surfaces;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GenUI + X — Gemini'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (surfaces.isNotEmpty)
            SizedBox(
              height: 240,
              child: ListView.builder(
                itemCount: surfaces.length,
                itemBuilder: (context, index) {
                  return Surface(
                    surfaceContext: _controller.contextFor(surfaces[index]),
                  );
                },
              ),
            ),
          if (_assistantText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _assistantText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          if (_assistantText.isEmpty && _isWaiting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Thinking...'),
            ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_isWaiting) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Ask about the weather...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isWaiting ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherWidget extends StatelessWidget {
  const WeatherWidget({
    super.key,
    required this.city,
    required this.temperature,
    required this.condition,
  });

  final String city;
  final double temperature;
  final String condition;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(city, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              '${temperature.toStringAsFixed(1)}°C',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(condition, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

final weatherCatalog = Catalog(
  [
    CatalogItem(
      name: 'WeatherWidget',
      dataSchema: S.object(
        description: 'Displays current weather information for a city.',
        properties: {
          'city': S.string(description: 'The city name.'),
          'temperature': S.number(description: 'Temperature in Celsius.'),
          'condition': S.string(
            description: 'A short description of the weather condition.',
          ),
        },
        required: ['city', 'temperature', 'condition'],
      ),
      widgetBuilder: (ctx) {
        final data = ctx.data as Map<String, dynamic>;
        return WeatherWidget(
          city: data['city'] as String,
          temperature: (data['temperature'] as num).toDouble(),
          condition: data['condition'] as String,
        );
      },
    ),
  ],
  catalogId: 'gemini.example.catalog',
  systemPromptFragments: [
    'When the user asks about weather, use the WeatherWidget component '
        'to display the information visually.',
  ],
);
