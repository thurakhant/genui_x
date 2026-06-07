// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/material.dart';

import 'src/chat_page.dart';

void main() {
  const apiKey = String.fromEnvironment('CLAUDE_API_KEY');
  if (apiKey.isEmpty) {
    throw Exception(
      'CLAUDE_API_KEY not set.\n'
      'Run: flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...',
    );
  }
  runApp(TravelDemoApp(apiKey: apiKey));
}

class TravelDemoApp extends StatelessWidget {
  const TravelDemoApp({super.key, required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'genui_x Travel Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0077B6),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: TravelChatPage(apiKey: apiKey),
    );
  }
}
