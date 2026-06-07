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

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

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
  late final SurfaceController _controller;
  late final Conversation _conversation;

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
    // enforceJsonMode tightens A2UI compliance for local models that often
    // forget to wrap output in JSON.
    _transport = GenuiXTransport.ollama(
      catalog: weatherCatalog,
      baseUrl: baseUrl,
      model: model,
      enforceJsonMode: true,
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
  catalogId: 'ollama.example.catalog',
  systemPromptFragments: [
    'When the user asks about weather, use the WeatherWidget component '
        'to display the information visually.',
  ],
);
