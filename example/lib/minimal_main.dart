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
      'Run with: flutter run -t lib/minimal_main.dart '
      '--dart-define=CLAUDE_API_KEY=your_key',
    );
  }

  runApp(GenUiXMinimalApp(apiKey: apiKey));
}

class GenUiXMinimalApp extends StatelessWidget {
  const GenUiXMinimalApp({super.key, required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI X Minimal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: MinimalChatPage(apiKey: apiKey),
    );
  }
}

class MinimalChatPage extends StatefulWidget {
  const MinimalChatPage({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<MinimalChatPage> createState() => _MinimalChatPageState();
}

class _MinimalChatPageState extends State<MinimalChatPage> {
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
    _transport = GenuiXTransport(
      apiKey: widget.apiKey,
      catalog: weatherCatalog,
      model: 'claude-sonnet-4-6',
    );
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
      ChatMessage.user('Use WeatherWidget for Tokyo, 26C, Sunny.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = _conversation.state.value.surfaces;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GenUI + X (Minimal)'),
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
            if (_assistantText.isEmpty && _isWaiting)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Thinking...'),
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

final weatherCatalogItem = CatalogItem(
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
);

final weatherCatalog = Catalog(
  [weatherCatalogItem],
  catalogId: 'default',
  systemPromptFragments: [
    'For weather questions, respond ONLY with an A2UI JSON block that '
        'calls WeatherWidget. Do not include any plain text.',
  ],
);
