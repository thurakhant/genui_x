import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  // Set your Claude API key via --dart-define=CLAUDE_API_KEY=sk-ant-...
  const apiKey = String.fromEnvironment('CLAUDE_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception(
      'CLAUDE_API_KEY not set. '
      'Run with: flutter run --dart-define=CLAUDE_API_KEY=your_key',
    );
  }

  runApp(GenUiXExampleApp(apiKey: apiKey));
}

class GenUiXExampleApp extends StatelessWidget {
  const GenUiXExampleApp({super.key, required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI X Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: ChatPage(apiKey: apiKey),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ClaudeTransport _transport;
  late final SurfaceController _controller;
  late final Conversation _conversation;

  final _textController = TextEditingController();
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
    _transport = ClaudeTransport(
      apiKey: widget.apiKey,
      catalog: weatherCatalog,
      baseUrl: baseUrl,
      model: 'claude-sonnet-4-6', // Uncomment for higher quality
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
    _textController.dispose();
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
        title: const Text('GenUI + X'),
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
                _displayedText,
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
    'When the user asks about weather, use the WeatherWidget component '
        'to display the information visually.',
  ],
);
