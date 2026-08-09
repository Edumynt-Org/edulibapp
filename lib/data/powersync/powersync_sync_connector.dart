import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:powersync/powersync.dart' as ps;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';
import '../../domain/repositories/sync_connector.dart';
import '../../domain/models/sync_status.dart' as domain;

class DirectusBackendConnector extends ps.PowerSyncBackendConnector {
  final String tokenEndpoint;
  final String endpoint;
  final FlutterSecureStorage secureStorage;

  DirectusBackendConnector({
    String? tokenEndpoint,
    String? endpoint,
    this.secureStorage = const FlutterSecureStorage(),
  })  : tokenEndpoint = tokenEndpoint ?? '${AppConfig.directusUrl}/powersync/token',
        endpoint = endpoint ?? AppConfig.powersyncUrl;

  @override
  Future<ps.PowerSyncCredentials?> fetchCredentials() async {
    try {
      final token = await secureStorage.read(key: 'access_token');
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(Uri.parse(tokenEndpoint), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ps.PowerSyncCredentials(
          endpoint: data['endpoint'] ?? endpoint,
          token: data['token'],
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch PowerSync token from API: $e');
    }

    return ps.PowerSyncCredentials(
      endpoint: endpoint,
      token: '',
    );
  }

  @override
  Future<void> uploadData(ps.PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch();
    if (batch == null) return;

    try {
      final token = await secureStorage.read(key: 'access_token');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      for (var op in batch.crud) {
        var opType = op.op.name; // 'put', 'patch', 'delete'
        final isCreate = opType == 'put';
        final url = Uri.parse('${AppConfig.directusUrl}/items/${op.table}${isCreate ? '' : '/${op.id}'}');
        http.Response res;
        
        if (isCreate) {
          final data = {'id': op.id, ...?op.opData};
          res = await http.post(url, headers: headers, body: jsonEncode(data));
        } else if (opType == 'patch') {
          res = await http.patch(url, headers: headers, body: jsonEncode(op.opData));
        } else {
          res = await http.delete(url, headers: headers);
        }

        if (res.statusCode >= 400) {
          debugPrint('Upload error for ${op.table}: ${res.body}');
          if (res.statusCode >= 500) {
            throw Exception('Server error during upload'); // Force retry
          }
        }
      }

      await batch.complete();
    } catch (e) {
      debugPrint('Data upload error: $e');
      rethrow;
    }
  }
}

class PowerSyncSyncConnector implements ISyncConnector {
  final ps.PowerSyncDatabase _db;
  final ps.PowerSyncBackendConnector _connector;
  bool _isConnecting = false;

  PowerSyncSyncConnector(this._db, {ps.PowerSyncBackendConnector? connector}) 
      : _connector = connector ?? DirectusBackendConnector();

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
  @override
  Future<void> migrateGuestData(String profileId) async {
    // 1. Migrate chapter_progress
    final anonChapters = await _db.getAll(
      "SELECT * FROM chapter_progress WHERE profile IS NULL OR profile = 'anonymous' OR profile = ''"
    );
    for (var anon in anonChapters) {
      final existing = await _db.getOptional(
        "SELECT * FROM chapter_progress WHERE profile = ? AND chapter = ?",
        [profileId, anon['chapter']]
      );
      if (existing != null) {
        final anonProgress = (anon['progress_percent'] as num?)?.toInt() ?? 0;
        final existProgress = (existing['progress_percent'] as num?)?.toInt() ?? 0;
        final anonTime = anon['last_read_at'] != null ? DateTime.tryParse(anon['last_read_at'])?.millisecondsSinceEpoch ?? 0 : 0;
        final existTime = existing['last_read_at'] != null ? DateTime.tryParse(existing['last_read_at'])?.millisecondsSinceEpoch ?? 0 : 0;

        if (anonProgress > existProgress || (anonProgress == existProgress && anonTime > existTime)) {
          await _db.execute(
            "UPDATE chapter_progress SET progress_percent = ?, last_position = ?, status = ?, completed_at = ?, last_read_at = ? WHERE id = ?",
            [anon['progress_percent'], anon['last_position'], anon['status'], anon['completed_at'], anon['last_read_at'], existing['id']]
          );
        }
        await _db.execute("DELETE FROM chapter_progress WHERE id = ?", [anon['id']]);
      } else {
        await _db.execute("UPDATE chapter_progress SET profile = ? WHERE id = ?", [profileId, anon['id']]);
      }
    }

    // 2. Migrate audio_progress
    final anonAudio = await _db.getAll(
      "SELECT * FROM audio_progress WHERE profile IS NULL OR profile = 'anonymous' OR profile = ''"
    );
    for (var anon in anonAudio) {
      final existing = await _db.getOptional(
        "SELECT * FROM audio_progress WHERE profile = ? AND audio_chapter = ?",
        [profileId, anon['audio_chapter']]
      );
      if (existing != null) {
        final anonPos = (anon['position_seconds'] as num?)?.toInt() ?? 0;
        final existPos = (existing['position_seconds'] as num?)?.toInt() ?? 0;
        final anonTime = anon['last_listened_at'] != null ? DateTime.tryParse(anon['last_listened_at'])?.millisecondsSinceEpoch ?? 0 : 0;
        final existTime = existing['last_listened_at'] != null ? DateTime.tryParse(existing['last_listened_at'])?.millisecondsSinceEpoch ?? 0 : 0;

        if (anonPos > existPos || (anonPos == existPos && anonTime > existTime)) {
          await _db.execute(
            "UPDATE audio_progress SET position_seconds = ?, duration_seconds = ?, status = ?, completed_at = ?, last_listened_at = ? WHERE id = ?",
            [anon['position_seconds'], anon['duration_seconds'], anon['status'], anon['completed_at'], anon['last_listened_at'], existing['id']]
          );
        }
        await _db.execute("DELETE FROM audio_progress WHERE id = ?", [anon['id']]);
      } else {
        await _db.execute("UPDATE audio_progress SET profile = ? WHERE id = ?", [profileId, anon['id']]);
      }
    }

    // 3. Migrate reading_preferences
    final anonPrefs = await _db.getAll(
      "SELECT * FROM reading_preferences WHERE profile IS NULL OR profile = 'anonymous' OR profile = ''"
    );
    for (var anon in anonPrefs) {
      final existing = await _db.getOptional(
        "SELECT * FROM reading_preferences WHERE profile = ?",
        [profileId]
      );
      if (existing != null) {
        await _db.execute("DELETE FROM reading_preferences WHERE id = ?", [anon['id']]);
      } else {
        await _db.execute("UPDATE reading_preferences SET profile = ? WHERE id = ?", [profileId, anon['id']]);
      }
    }

    // 4. Migrate annotations
    await _db.execute(
      "UPDATE annotations SET profile = ? WHERE profile IS NULL OR profile = 'anonymous' OR profile = ''",
      [profileId]
    );
  }
}
