// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

/// The A2UI operations the model may use on surfaces.
///
/// Passed to [GenuiXTransport] as `surfaceOperations`. The transport tells the
/// model which messages it may write, and keeps the surfaces of earlier turns
/// for the model to update only when [update] or [delete] is enabled.
final class SurfaceOperations {
  /// Creates a [SurfaceOperations]. At least one of [create], [update] and
  /// [delete] must be enabled.
  SurfaceOperations({
    this.create = false,
    this.update = false,
    this.delete = false,
    this.dataModel = false,
  }) : assert(
         create || update || delete,
         'At least one operation must be enabled.',
       );

  /// The model creates a new surface for each reply.
  SurfaceOperations.createOnly({required bool dataModel})
    : this(create: true, dataModel: dataModel);

  /// The model updates the surfaces of earlier turns.
  SurfaceOperations.updateOnly({required bool dataModel})
    : this(update: true, dataModel: dataModel);

  /// The model creates surfaces and updates the surfaces of earlier turns.
  SurfaceOperations.createAndUpdate({required bool dataModel})
    : this(create: true, update: true, dataModel: dataModel);

  /// The model creates, updates and deletes surfaces.
  SurfaceOperations.all({required bool dataModel})
    : this(create: true, update: true, delete: true, dataModel: dataModel);

  /// Whether the model may create surfaces.
  final bool create;

  /// Whether the model may update the surfaces of earlier turns.
  final bool update;

  /// Whether the model may delete surfaces.
  final bool delete;

  /// Whether the model may write the data model with `updateDataModel`.
  final bool dataModel;

  /// The A2UI message types these operations allow.
  List<String> get allowedMessages => [
    if (create) 'createSurface',
    if (create || update) 'updateComponents',
    if (dataModel) 'updateDataModel',
    if (delete) 'deleteSurface',
  ];

  /// Whether the surfaces of earlier turns stay open to later turns.
  bool get keepsSurfaces => update || delete;
}
