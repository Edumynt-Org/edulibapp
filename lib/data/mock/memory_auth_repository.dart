import '../../domain/repositories/auth_repository.dart';
import '../../domain/models/user.dart';

const _anonymousGuest = AppUser(
  id: 'guest',
  role: 'anonymous',
  isAnonymous: true,
  displayName: 'Guest Reader',
);

class MemoryAuthRepository implements IAuthRepository {
  AppUser _currentUser = _anonymousGuest;

  @override
  Future<AppUser> getCurrentUser() async {
    // Always returns guest state cleanly without exceptions (AC: #2)
    return _currentUser;
  }
  @override
  Future<AppUser> register(String email, String password, String displayName, String username) async {
    print('Mock: Registering user $username ($email)');
    return _currentUser;
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final prefix = email.split('@').first.trim();
    _currentUser = AppUser(
      id: 'f6a84c12-97b1-4c12-97b1-21ff7803e082',
      role: 'reader',
      isAnonymous: false,
      email: email,
      displayName: prefix.isEmpty ? 'Reader' : prefix,
    );
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    _currentUser = _anonymousGuest;
  }

  @override
  Future<void> refreshSession() async {
    // No-op for memory repo
  }

  @override
  Future<void> migrateGuestState(String newProfileId) async {
    // Simulated guest state migration
  }
}
