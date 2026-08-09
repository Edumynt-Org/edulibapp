class SyncStatus {
  final bool isConnected;
  final DateTime? lastSyncedAt;
  final int pendingChangesCount;

  const SyncStatus({
    required this.isConnected,
    this.lastSyncedAt,
    this.pendingChangesCount = 0,
  });
}
