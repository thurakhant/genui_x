// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
//
// Proxy example — shows how to connect genui_x to any OpenAI-compatible
// backend: LiteLLM, OpenRouter, a custom proxy, or a self-hosted model.
//
// Run with:
//   flutter run -t lib/proxy_main.dart \
//     --dart-define=PROXY_BASE_URL=https://your-proxy.example.com \
//     --dart-define=PROXY_API_KEY=your-key \
//     --dart-define=PROXY_MODEL=gpt-4o

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  const baseUrl = String.fromEnvironment('PROXY_BASE_URL');
  const apiKey = String.fromEnvironment('PROXY_API_KEY');
  const model = String.fromEnvironment('PROXY_MODEL', defaultValue: 'gpt-4o');

  if (baseUrl.isEmpty || apiKey.isEmpty) {
    throw Exception(
      'PROXY_BASE_URL and PROXY_API_KEY are required.\n'
      'Run with:\n'
      '  flutter run -t lib/proxy_main.dart \\\n'
      '    --dart-define=PROXY_BASE_URL=https://your-proxy.example.com \\\n'
      '    --dart-define=PROXY_API_KEY=your-key',
    );
  }

  runApp(ProxyExampleApp(baseUrl: baseUrl, apiKey: apiKey, model: model));
}

class ProxyExampleApp extends StatelessWidget {
  const ProxyExampleApp({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI X — Proxy Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: ProxyChatPage(baseUrl: baseUrl, apiKey: apiKey, model: model),
    );
  }
}

class ProxyChatPage extends StatefulWidget {
  const ProxyChatPage({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  @override
  State<ProxyChatPage> createState() => _ProxyChatPageState();
}

class _ProxyChatPageState extends State<ProxyChatPage> {
  late final GenuiXTransport _transport;
  late final SurfaceController _controller;
  late final Conversation _conversation;

  @override
  void initState() {
    super.initState();

    // ── Transport configuration for an OpenAI-compatible proxy ──────────
    _transport = GenuiXTransport(
      apiKey: widget.apiKey,
      catalog: weatherCatalog,
      model: widget.model,
      baseUrl: widget.baseUrl,
      endpointPath: '/v1/chat/completions', // OpenAI-style endpoint
      apiKeyHeader: 'authorization',        // Authorization header
      apiKeyPrefix: 'Bearer ',              // Bearer token format
      streamFormat: GenuiXStreamFormat.openai,
      debug: true, // remove in production
    );
    // ────────────────────────────────────────────────────────────────────

    _controller = SurfaceController(catalogs: [weatherCatalog]);
    _conversation = Conversation(
      controller: _controller,
      transport: _transport,
    );
  }

  @override
  void dispose() {
    _conversation.dispose();
    _controller.dispose();
    _transport.dispose();
    super.dispose();
  }

  Future<void> _sendSample() async {
    await _conversation.sendRequest(
      ChatMessage.user('Show weather for Tokyo: 28°C, Sunny.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Proxy: ${widget.model}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backend: ${widget.baseUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<bool>(
              valueListenable: _transport.isLoading,
              builder: (context, loading, _) => Column(
                children: [
                  ElevatedButton(
                    onPressed: loading ? null : _sendSample,
                    child: const Text('Send sample request'),
                  ),
                  if (loading) const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: _conversation.state,
              builder: (context, state, _) {
                if (state.surfaces.isEmpty) return const SizedBox.shrink();
                return Expanded(
                  child: ListView.builder(
                    itemCount: state.surfaces.length,
                    itemBuilder: (context, i) => Surface(
                      surfaceContext: _controller.contextFor(state.surfaces[i]),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Catalog ──────────────────────────────────────────────────────────────────

final weatherCatalog = Catalog(
  [
    CatalogItem(
      name: 'WeatherWidget',
      dataSchema: S.object(
        description: 'Displays current weather for a city.',
        properties: {
          'city': S.string(description: 'City name.'),
          'temperature': S.number(description: 'Temperature in Celsius.'),
          'condition': S.string(description: 'Weather condition, e.g. Sunny.'),
        },
        required: ['city', 'temperature', 'condition'],
      ),
      widgetBuilder: (ctx) {
        final data = ctx.data as Map<String, dynamic>;
        return _WeatherCard(
          city: data['city'] as String,
          temperature: (data['temperature'] as num).toDouble(),
          condition: data['condition'] as String,
        );
      },
    ),
  ],
  catalogId: 'proxy.example.catalog',
);

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(city, style: Theme.of(context).textTheme.headlineMedium),
            Text('${temperature.toStringAsFixed(1)}°C',
                style: Theme.of(context).textTheme.displaySmall),
            Text(condition),
          ],
        ),
      ),
    );
  }
}
