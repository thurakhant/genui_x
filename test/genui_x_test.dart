import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x/genui_x.dart';

void main() {
  group('ClaudeConfig', () {
    test('has correct defaults', () {
      const config = ClaudeConfig(apiKey: 'test-key');
      expect(config.apiKey, 'test-key');
      expect(config.model, 'claude-haiku-4-5-20251001');
      expect(config.baseUrl, 'https://api.anthropic.com');
      expect(config.endpointPath, '/v1/messages');
      expect(config.maxTokens, 8192);
      expect(config.anthropicVersion, '2023-06-01');
      expect(config.apiKeyHeader, 'x-api-key');
      expect(config.apiKeyPrefix, '');
      expect(config.headers, isEmpty);
      expect(config.streamFormat, ClaudeStreamFormat.anthropic);
    });

    test('accepts custom model and baseUrl', () {
      const config = ClaudeConfig(
        apiKey: 'test-key',
        model: 'claude-sonnet-4-6',
        baseUrl: 'https://my-proxy.example.com',
        endpointPath: '/v1/messages',
        maxTokens: 4096,
      );
      expect(config.model, 'claude-sonnet-4-6');
      expect(config.baseUrl, 'https://my-proxy.example.com');
      expect(config.endpointPath, '/v1/messages');
      expect(config.maxTokens, 4096);
    });

    test('supports custom headers', () {
      const config = ClaudeConfig(
        apiKey: 'test-key',
        apiKeyHeader: 'authorization',
        apiKeyPrefix: 'Bearer ',
        headers: {'x-proxy': 'lite'},
        streamFormat: ClaudeStreamFormat.openai,
        requestBodyOverrides: {
          'response_format': {'type': 'json_object'}
        },
      );
      expect(config.apiKeyHeader, 'authorization');
      expect(config.apiKeyPrefix, 'Bearer ');
      expect(config.headers['x-proxy'], 'lite');
      expect(config.streamFormat, ClaudeStreamFormat.openai);
      expect(config.requestBodyOverrides['response_format'],
          {'type': 'json_object'});
    });
  });

  group('ClaudeApiException', () {
    test('toString includes status code and message', () {
      const e = ClaudeApiException(429, 'Rate limited');
      expect(e.toString(), contains('429'));
      expect(e.toString(), contains('Rate limited'));
    });
  });

  group('ClaudeAuthException', () {
    test('toString includes status code', () {
      const e = ClaudeAuthException(401, 'Unauthorized');
      expect(e.toString(), contains('401'));
    });
  });
}
