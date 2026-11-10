// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:genui_x/genui_x.dart';

/// Renders the A2UI messages a [GenuiXTransport] receives, and keeps the
/// surfaces they create in [surfaces] for an `A2uiSurface` to show.
class SurfaceRenderer {
  SurfaceRenderer({
    required GenuiXTransport transport,
    required List<CatalogImplementation> catalogs,
  }) : processor = MessageProcessor(
          catalogs: catalogs,
          // A surface streams in over several messages, which the strict
          // checks would reject.
          validationConfig: ValidationConfig.relaxed,
          reportErrorsOnly: true,
        ) {
    _subscriptions = [
      processor.model.onSurfaceCreated.subscribe((surface) {
        surfaces.value = [...surfaces.value, surface];
      }),
      processor.model.onSurfaceDeleted.subscribe((surfaceId) {
        surfaces.value = [
          for (final surface in surfaces.value)
            if (surface.id != surfaceId) surface,
        ];
      }),
      processor.model.onError.subscribe(_logError),
    ];
    _messages = transport.incomingMessages.listen(
      (message) => processor.processMessages(
        AgentToRendererMessagePayload.of(message),
      ),
      onError: _logError,
    );
  }

  /// The renderer that holds the surfaces.
  final MessageProcessor<ComponentImplementation> processor;

  /// The surfaces the model has created, in the order it created them.
  final ValueNotifier<List<SurfaceModel<ComponentImplementation>>> surfaces =
      ValueNotifier(const []);

  late final List<Subscription> _subscriptions;
  late final StreamSubscription<AgentToRendererMessage> _messages;

  // A2uiRendererError has no toString, so it is logged as its JSON.
  void _logError(Object error) => debugPrint(
        '[A2UI] ${error is A2uiRendererError ? jsonEncode(error.toJson()) : error}',
      );

  void dispose() {
    unawaited(_messages.cancel());
    for (final subscription in _subscriptions) {
      subscription.unsubscribe();
    }
    processor.dispose();
    surfaces.dispose();
  }
}
