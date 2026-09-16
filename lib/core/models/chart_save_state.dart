/// Represents the synchronization and persistence state of chart settings and drawings.
enum ChartSaveState {
  /// All recent modifications have been successfully persisted.
  saved,

  /// Asynchronous saving operation is currently in progress.
  saving,

  /// Unsaved local modifications are pending persistence.
  unsaved,
}
