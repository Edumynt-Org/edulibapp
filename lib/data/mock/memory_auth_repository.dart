import 'package:flutter/foundation.dart';
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
  Future<AppUser> register(String email, String password, String firstName, String lastName) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newUser = AppUser(
      id: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: '$firstName $lastName'.trim(),
      role: 'reader',
      isAnonymous: false,
    );
    _currentUser = newUser;
    return newUser;
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

  @override
  Future<void> requestPasswordReset(String email, String resetUrl) async {
    // No-op for memory repo
  }

  @override
  Future<void> resetPassword(String token, String password) async {
    // No-op for memory repo
  }
}
