import '../models/sync_status.dart';

abstract class ISyncConnector {
  Future<void> connect();
  Future<void> disconnect();
  Future<SyncStatus> getSyncStatus();
  Future<void> migrateGuestData(String profileId);
}
