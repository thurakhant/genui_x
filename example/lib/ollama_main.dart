// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
//
// Ollama example — runs genui_x against a local Ollama server.
//
// Prerequisites:
//   1. Install Ollama: https://ollama.com/download
//   2. Pull a tool-capable model:  ollama pull llama3.2
//   3. Make sure the Ollama server is running (it auto-starts after install).
//
// Run with:
//   flutter run -t lib/ollama_main.dart
//
// To point at a remote Ollama or change the model:
//   flutter run -t lib/ollama_main.dart \
//     --dart-define=OLLAMA_BASE_URL=http://192.168.1.50:11434 \
//     --dart-define=OLLAMA_MODEL=qwen2.5-coder

import 'dart:async';

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'src/surface_renderer.dart';

void main() {
  runApp(const OllamaExampleApp());
}

class OllamaExampleApp extends StatelessWidget {
  const OllamaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI X — Ollama (local)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const OllamaChatPage(),
    );
  }
}

class OllamaChatPage extends StatefulWidget {
  const OllamaChatPage({super.key});

  @override
  State<OllamaChatPage> createState() => _OllamaChatPageState();
}

class _OllamaChatPageState extends State<OllamaChatPage> {
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

    const baseUrl = String.fromEnvironment(
      'OLLAMA_BASE_URL',
      defaultValue: 'http://localhost:11434',
    );
    const model = String.fromEnvironment(
      'OLLAMA_MODEL',
      defaultValue: 'llama3.2',
    );

    // ── Transport configuration for a local Ollama server ────────────────
    // No API key needed; Ollama's OpenAI-compat layer accepts any token.
    _transport = GenuiXTransport.ollama(
      catalog: weatherCatalog,
      baseUrl: baseUrl,
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
        title: const Text('GenUI X — Ollama (local)'),
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
  id: 'ollama.example.catalog',
  instructions: 'When the user asks about weather, use the WeatherWidget '
      'component to display the information visually.',
);
