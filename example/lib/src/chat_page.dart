// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';

import 'travel_catalog.dart';

sealed class _ChatEntry {}

class _UserEntry extends _ChatEntry {
  _UserEntry(this.text);
  final String text;
}

class _AssistantTextEntry extends _ChatEntry {
  _AssistantTextEntry({this.text = '', this.isStreaming = false});
  final String text;
  final bool isStreaming;
}

class _SurfaceEntry extends _ChatEntry {
  _SurfaceEntry(this.surfaceIndex);
  final int surfaceIndex;
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

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _entries = <_ChatEntry>[];
  bool _isWaiting = false;
  bool _hasPendingResult = false;
  late final VoidCallback _loadingListener;

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
    final streamFormat = streamFormatRaw == 'openai'
        ? GenuiXStreamFormat.openai
        : GenuiXStreamFormat.anthropic;
    const endpointPathEnv = String.fromEnvironment('CLAUDE_ENDPOINT_PATH');
    final endpointPath = endpointPathEnv.isEmpty
        ? (streamFormat == GenuiXStreamFormat.openai
            ? '/v1/chat/completions'
            : '/v1/messages')
        : endpointPathEnv;
    const apiKeyHeaderEnv = String.fromEnvironment('CLAUDE_API_KEY_HEADER');
    final apiKeyHeader = apiKeyHeaderEnv.isEmpty
        ? (streamFormat == GenuiXStreamFormat.openai
            ? 'authorization'
            : 'x-api-key')
        : apiKeyHeaderEnv;
    const apiKeyPrefixEnv = String.fromEnvironment('CLAUDE_API_KEY_PREFIX');
    final apiKeyPrefix = apiKeyPrefixEnv.isEmpty
        ? (streamFormat == GenuiXStreamFormat.openai ? 'Bearer ' : '')
        : apiKeyPrefixEnv;
    const debug = bool.fromEnvironment('GENUIX_DEBUG', defaultValue: false);

    _transport = GenuiXTransport(
      apiKey: widget.apiKey,
      catalog: travelCatalog,
      model: 'claude-sonnet-4-6',
      baseUrl: baseUrl,
      endpointPath: endpointPath,
      apiKeyHeader: apiKeyHeader,
      apiKeyPrefix: apiKeyPrefix,
      streamFormat: streamFormat,
      requestBodyOverrides: streamFormat == GenuiXStreamFormat.openai
          ? const {
              'response_format': {'type': 'json_object'},
            }
          : const <String, Object?>{},
      debug: debug,
    );
    _controller = SurfaceController(
      catalogs: [travelCatalog, travelCatalogLegacy],
    );
    if (debug) {
      debugPrint(
        '[travel_chat] catalogs: ${travelCatalog.catalogId}, ${travelCatalogLegacy.catalogId}',
      );
    }
    _conversation = Conversation(
      controller: _controller,
      transport: _transport,
    );
    _loadingListener = () {
      if (!mounted) return;
      final loading = _transport.isLoading.value;
      final waiting = loading || _hasPendingResult;
      if (_isWaiting != waiting) {
        setState(() => _isWaiting = waiting);
      }
    };
    _transport.isLoading.addListener(_loadingListener);
    _conversation.events.listen(_handleEvent);
  }

  void _handleEvent(ConversationEvent event) {
    if (event is ConversationWaiting) {
      setState(() => _isWaiting = true);
    } else if (event is ConversationContentReceived) {
      if (_conversation.state.value.surfaces.isNotEmpty) {
        setState(() {
          _hasPendingResult = false;
          _isWaiting = _transport.isLoading.value;
        });
        return;
      }
      if (event.text.trim().isEmpty) {
        return;
      }
      setState(() {
        _hasPendingResult = false;
        _isWaiting = _transport.isLoading.value;
        final idx = _lastAssistantText();
        if (idx >= 0) {
          _entries[idx] = _AssistantTextEntry(text: event.text);
        } else {
          _entries.add(_AssistantTextEntry(text: event.text));
        }
      });
      _scrollToBottom();
    } else if (event is ConversationSurfaceAdded) {
      final surfaceCount = _conversation.state.value.surfaces.length;
      setState(() {
        _hasPendingResult = false;
        _isWaiting = _transport.isLoading.value;
        final placeholderIdx = _lastAssistantText();
        if (placeholderIdx >= 0) _entries.removeAt(placeholderIdx);
        _entries.add(_SurfaceEntry(surfaceCount - 1));
      });
      _scrollToBottom();
    } else if (event is ConversationComponentsUpdated) {
      setState(() {});
    } else if (event is ConversationError) {
      setState(() {
        _hasPendingResult = false;
        _isWaiting = false;
        final idx = _lastAssistantText();
        if (idx >= 0) _entries.removeAt(idx);
        _entries.add(
          _AssistantTextEntry(
            text: 'Sorry, something went wrong. Please try again.',
          ),
        );
      });
    }
  }

  int _lastAssistantText() {
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i] is _AssistantTextEntry) return i;
    }
    return -1;
  }

  Future<void> _sendMessage([String? submittedText]) async {
    final text = (submittedText ?? _textController.text).trim();
    if (text.isEmpty || _isWaiting) return;
    _textController.clear();
    setState(() {
      _entries.add(_UserEntry(text));
      _entries.add(_AssistantTextEntry(isStreaming: true));
      _hasPendingResult = true;
      _isWaiting = true;
    });
    _scrollToBottom();
    await _conversation.sendRequest(ChatMessage.user(text));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _transport.isLoading.removeListener(_loadingListener);
    _conversation.dispose();
    _controller.dispose();
    _transport.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = _conversation.state.value.surfaces;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('✈️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Travel Planner'),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          if (_isWaiting) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _entries.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) =>
                        _buildEntry(_entries[index], surfaces),
                  ),
          ),
          _InputBar(
            controller: _textController,
            isWaiting: _isWaiting,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(_ChatEntry entry, List<dynamic> surfaces) {
    return switch (entry) {
      _UserEntry e => _UserBubble(text: e.text),
      _AssistantTextEntry e => e.isStreaming
          ? const _TypingIndicator()
          : _AssistantBubble(text: e.text),
      _SurfaceEntry e when e.surfaceIndex < surfaces.length => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Surface(
            surfaceContext: _controller.contextFor(surfaces[e.surfaceIndex]),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✈️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Where do you want to go?',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try: "Plan me 5 days in Tokyo"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 40,
          height: 16,
          child: LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isWaiting,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isWaiting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Where do you want to go?',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              enabled: !isWaiting,
              onSubmitted: (value) {
                if (value.trim().isEmpty || isWaiting) return;
                onSend();
              },
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isWaiting ? null : onSend,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: isWaiting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}
