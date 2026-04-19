import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x/genui_x.dart';

void main() {
  group('GenuiXConfig', () {
    test('has correct defaults', () {
      const config = GenuiXConfig(apiKey: 'test-key');
      expect(config.apiKey, 'test-key');
      expect(config.model, 'claude-haiku-4-5-20251001');
      expect(config.baseUrl, 'https://api.anthropic.com');
      expect(config.endpointPath, '/v1/messages');
      expect(config.maxTokens, 8192);
      expect(config.anthropicVersion, '2023-06-01');
      expect(config.apiKeyHeader, 'x-api-key');
      expect(config.apiKeyPrefix, '');
      expect(config.headers, isEmpty);
      expect(config.streamFormat, GenuiXStreamFormat.anthropic);
      expect(config.enforceJsonMode, isFalse);
    });

    test('GenuiXStreamFormat exposes a gemini variant', () {
      expect(GenuiXStreamFormat.values, contains(GenuiXStreamFormat.gemini));
    });

    test('enforceJsonMode can be set', () {
      const config = GenuiXConfig(apiKey: 'test-key', enforceJsonMode: true);
      expect(config.enforceJsonMode, isTrue);
    });

    test('accepts custom model and baseUrl', () {
      const config = GenuiXConfig(
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
      final config = GenuiXConfig(
        apiKey: 'test-key',
        apiKeyHeader: 'authorization',
        apiKeyPrefix: 'Bearer ',
        headers: const {'x-proxy': 'lite'},
        streamFormat: GenuiXStreamFormat.openai,
        requestBodyOverrides: const {
          'response_format': {'type': 'json_object'},
        },
      );
      expect(config.apiKeyHeader, 'authorization');
      expect(config.apiKeyPrefix, 'Bearer ');
      expect(config.headers['x-proxy'], 'lite');
      expect(config.streamFormat, GenuiXStreamFormat.openai);
      expect(config.requestBodyOverrides['response_format'], {
        'type': 'json_object',
      });
    });
  });

  group('GenuiXConfig — surfaceOperations and clientDataModel', () {
    test('surfaceOperations defaults to null', () {
      const config = GenuiXConfig(apiKey: 'test-key');
      expect(config.surfaceOperations, isNull);
    });

    test('clientDataModel defaults to null', () {
      const config = GenuiXConfig(apiKey: 'test-key');
      expect(config.clientDataModel, isNull);
    });

    test('accepts SurfaceOperations.all', () {
      final config = GenuiXConfig(
        apiKey: 'test-key',
        surfaceOperations: SurfaceOperations.all(dataModel: true),
      );
      expect(config.surfaceOperations, isNotNull);
      expect(config.surfaceOperations!.create, isTrue);
      expect(config.surfaceOperations!.update, isTrue);
      expect(config.surfaceOperations!.delete, isTrue);
      expect(config.surfaceOperations!.dataModel, isTrue);
    });

    test('accepts SurfaceOperations.createOnly', () {
      final config = GenuiXConfig(
        apiKey: 'test-key',
        surfaceOperations: SurfaceOperations.createOnly(dataModel: false),
      );
      expect(config.surfaceOperations!.create, isTrue);
      expect(config.surfaceOperations!.update, isFalse);
      expect(config.surfaceOperations!.delete, isFalse);
    });

    test('accepts clientDataModel map', () {
      final config = GenuiXConfig(
        apiKey: 'test-key',
        clientDataModel: {'userName': 'Alice', 'plan': 'pro'},
      );
      expect(config.clientDataModel, isNotNull);
      expect(config.clientDataModel!['userName'], 'Alice');
      expect(config.clientDataModel!['plan'], 'pro');
    });
  });

  group('re-exports', () {
    test('PromptFragments.currentDate is accessible from genui_x', () {
      // If this compiles, the re-export works.
      final fragment = PromptFragments.currentDate();
      expect(fragment, contains('Current Date'));
    });

    test('SurfaceOperations is accessible from genui_x', () {
      final ops = SurfaceOperations.all(dataModel: true);
      expect(ops.create, isTrue);
      expect(ops.delete, isTrue);
    });
  });

  group('GenuiXApiError', () {
    test('toString includes status code and message', () {
      const e = GenuiXApiError(429, 'Rate limited');
      expect(e.toString(), contains('429'));
      expect(e.toString(), contains('Rate limited'));
    });
  });

  group('GenuiXAuthError', () {
    test('toString includes status code', () {
      const e = GenuiXAuthError(401, 'Unauthorized');
      expect(e.toString(), contains('401'));
    });
  });
}
