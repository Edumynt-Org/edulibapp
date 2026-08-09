import '../../domain/repositories/sync_connector.dart';
import '../../domain/models/sync_status.dart';

class MemorySyncConnector implements ISyncConnector {
  bool _connected = false;
  DateTime? _lastSync;

  @override
  Future<void> connect() async {
    if (_connected) return;
    _connected = true;
    _lastSync = DateTime.now();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus(
      isConnected: _connected,
      lastSyncedAt: _lastSync,
      pendingChangesCount: 0,
    );
  }
}
