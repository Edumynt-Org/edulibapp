abstract class IProfileRepository {
  void setCurrentUserId(String userId);
  Future<void> followUser(String targetProfileId);
  Future<void> unfollowUser(String targetProfileId);
  Future<bool> checkIsFollowing(String targetProfileId);
}
