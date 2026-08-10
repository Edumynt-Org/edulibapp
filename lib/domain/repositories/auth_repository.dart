import '../models/user.dart';

abstract class IAuthRepository {
  Future<AppUser> getCurrentUser();
  Future<AppUser> login(String email, String password);
  Future<void> logout();
  Future<void> refreshSession();
  Future<void> migrateGuestState(String newProfileId);
  Future<AppUser> register(String email, String password, String firstName, String lastName);
}
