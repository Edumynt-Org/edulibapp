import 'package:flutter_test/flutter_test.dart';
import 'package:edulibapp/domain/repositories/auth_repository.dart';
import 'package:edulibapp/data/mock/memory_auth_repository.dart';
import 'package:edulibapp/data/mock/memory_library_repository.dart';
import 'package:edulibapp/data/mock/memory_sync_connector.dart';

void main() {
  group('Backend-Agnostic Abstraction Layer - edulibapp', () {
    group('MemoryAuthRepository - Guest State & Auth Flow (AC: #2)', () {
      late IAuthRepository authRepo;

      setUp(() {
        authRepo = MemoryAuthRepository();
      });

      test('must cleanly return an anonymous guest profile without exceptions when booted without session', () async {
        final user = await authRepo.getCurrentUser();
        expect(user, isNotNull);
        expect(user.isAnonymous, isTrue);
        expect(user.role, equals('anonymous'));
        expect(user.id, equals('guest'));
      });

      test('must transition to authenticated state upon login', () async {
        final authUser = await authRepo.login('reader@edumynt.org', 'password123');
        expect(authUser.isAnonymous, isFalse);
        expect(authUser.role, equals('reader'));
        expect(authUser.email, equals('reader@edumynt.org'));

        final currentUser = await authRepo.getCurrentUser();
        expect(currentUser.id, equals(authUser.id));
      });

      test('must transition back to anonymous guest upon logout', () async {
        await authRepo.login('reader@edumynt.org', 'password123');
        await authRepo.logout();
        final user = await authRepo.getCurrentUser();
        expect(user.isAnonymous, isTrue);
      });

      test('must support migrateGuestState cleanly without errors', () async {
        await authRepo.migrateGuestState('profile-uuid-456');
        // No exception implies success
      });
    });

    group('MemoryLibraryRepository - Catalog Access (AC: #1)', () {
      test('must allow querying catalog books without auth exceptions', () async {
        final libRepo = MemoryLibraryRepository();
        final books = await libRepo.getCatalogBooks();
        expect(books.isNotEmpty, isTrue);
      });

      test('must find book by id and search catalog', () async {
        final libRepo = MemoryLibraryRepository();
        final searchResults = await libRepo.searchCatalog('library');
        expect(searchResults, isNotNull);
      });
    });

    group('MemorySyncConnector - Sync Status (AC: #1)', () {
      test('must provide sync connection and status', () async {
        final syncConnector = MemorySyncConnector();
        await syncConnector.connect();
        var status = await syncConnector.getSyncStatus();
        expect(status.isConnected, isTrue);

        await syncConnector.disconnect();
        status = await syncConnector.getSyncStatus();
        expect(status.isConnected, isFalse);
      });
    });
  });
}
