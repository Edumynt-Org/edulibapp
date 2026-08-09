import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/profile_repository.dart';

class PowerSyncProfileRepository implements IProfileRepository {
  final PowerSyncDatabase _db;
  String _currentUserId = 'guest'; // This will be updated later

  PowerSyncProfileRepository(this._db);

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  @override
  Future<void> followUser(String targetProfileId) async {
    try {
      if (_currentUserId == 'guest') return;

      final newId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();

      await _db.execute('''
        INSERT OR IGNORE INTO follows (id, follower, following, date_created)
        VALUES (?, ?, ?, ?)
      ''', [newId, _currentUserId, targetProfileId, now]);
    } catch (e) {
      print('Failed to follow user: $e');
      throw Exception('Failed to follow user: $e');
    }
  }

  @override
  Future<void> unfollowUser(String targetProfileId) async {
    try {
      if (_currentUserId == 'guest') return;

      await _db.execute('''
        DELETE FROM follows
        WHERE follower = ? AND following = ?
      ''', [_currentUserId, targetProfileId]);
    } catch (e) {
      print('Failed to unfollow user: $e');
      throw Exception('Failed to unfollow user: $e');
    }
  }

  @override
  Future<bool> checkIsFollowing(String targetProfileId) async {
    try {
      if (_currentUserId == 'guest') return false;

      final result = await _db.getOptional('''
        SELECT id FROM follows
        WHERE follower = ? AND following = ?
      ''', [_currentUserId, targetProfileId]);

      return result != null;
    } catch (e) {
      print('Failed to check follow status: $e');
      return false;
    }
  }
}
