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

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'src/surface_renderer.dart';

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
  late final SurfaceRenderer _renderer;
  late final StreamSubscription<String> _textSubscription;

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

    _renderer = SurfaceRenderer(
      transport: _transport,
      catalogs: [weatherCatalog],
    );

    _textSubscription = _transport.incomingText.listen((text) {
      setState(() {
        _assistantText = text;
        _errorText = null;
        _isWaiting = false;
      });
    });
    _renderer.surfaces.addListener(_onSurfacesChanged);
  }

  void _onSurfacesChanged() {
    setState(() => _isWaiting = false);
  }

  @override
  void dispose() {
    _renderer.surfaces.removeListener(_onSurfacesChanged);
    unawaited(_textSubscription.cancel());
    _renderer.dispose();
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

    try {
      await _transport.sendRequest(text);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isWaiting = false;
        _errorText = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = _renderer.surfaces.value;

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
                  return A2uiSurface(
                    key: ObjectKey(surfaces[index]),
                    surface: surfaces[index],
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

final weatherCatalog = CatalogImplementation(
  components: [
    ComponentImplementation(
      name: 'WeatherWidget',
      schema: S.object(
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
      builder: (context, node, props, buildChild) {
        return WeatherWidget(
          city: props.string('city') ?? '',
          temperature: props.number('temperature') ?? 0,
          condition: props.string('condition') ?? '',
        );
      },
    ),
  ],
  id: 'gemini.example.catalog',
  instructions: 'When the user asks about weather, use the WeatherWidget '
      'component to display the information visually.',
);
