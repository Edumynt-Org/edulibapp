import 'dart:convert';
import 'package:powersync/powersync.dart' as ps;
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../domain/repositories/sync_connector.dart';
import '../../domain/models/sync_status.dart' as domain;

class AnonymousConnector extends ps.PowerSyncBackendConnector {
  final String tokenEndpoint;
  final String endpoint;

  AnonymousConnector({
    String? tokenEndpoint,
    String? endpoint,
  })  : tokenEndpoint = tokenEndpoint ?? '${AppConfig.directusUrl.replaceFirst(RegExp(r':\d+$'), ':3000')}/api/powersync-token',
        endpoint = endpoint ?? AppConfig.powersyncUrl;

  @override
  Future<ps.PowerSyncCredentials?> fetchCredentials() async {
    try {
      final response = await http.get(Uri.parse(tokenEndpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ps.PowerSyncCredentials(
          endpoint: data['endpoint'] ?? endpoint,
          token: data['token'],
        );
      }
    } catch (e) {
      print('Failed to fetch PowerSync token from API: $e');
    }

    // Fallback: return endpoint with empty token (will fail gracefully)
    return ps.PowerSyncCredentials(
      endpoint: endpoint,
      token: '',
    );
  }

  @override
  Future<void> uploadData(ps.PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) return;
    
    // For now, we are in read-only guest mode. Just complete the batch to discard local changes 
    // and prevent the upload loop from getting permanently blocked.
    await batch.complete();
  }
}

class PowerSyncSyncConnector implements ISyncConnector {
  final ps.PowerSyncDatabase _db;
  final ps.PowerSyncBackendConnector _connector;
  bool _isConnecting = false;

  PowerSyncSyncConnector(this._db, {ps.PowerSyncBackendConnector? connector}) 
      : _connector = connector ?? AnonymousConnector();

  @override
  Future<void> connect() async {
    if (_db.currentStatus.connected || _isConnecting) return;
    
    _isConnecting = true;
    try {
      await _db.connect(connector: _connector);
    } catch (e) {
      throw Exception('Failed to connect to sync service: $e');
    } finally {
      _isConnecting = false;
    }
  }

  @override
  Future<void> disconnect() async {
    await _db.disconnect();
  }

  @override
  Future<domain.SyncStatus> getSyncStatus() async {
    final status = _db.currentStatus;
    return domain.SyncStatus(
      isConnected: status.connected,
      lastSyncedAt: status.lastSyncedAt,
      pendingChangesCount: status.uploading ? 1 : 0,
    );
  }
}
