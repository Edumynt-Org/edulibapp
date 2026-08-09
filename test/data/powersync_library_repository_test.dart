import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:edulibapp/data/powersync/app_schema.dart';
import 'package:edulibapp/data/powersync/fts_setup.dart';
import 'package:edulibapp/data/powersync/powersync_library_repository.dart';
import 'package:edulibapp/data/powersync/powersync_sync_connector.dart';

import 'dart:io';

void main() {
  group('PowerSync Integration - edulibapp', () {
    late PowerSyncDatabase mockDb;
    late PowerSyncLibraryRepository repo;
    late PowerSyncSyncConnector connector;
    final dbPath = 'test_db.sqlite';

    setUp(() async {
      try { File(dbPath).deleteSync(); } catch (_) {}
      mockDb = PowerSyncDatabase(schema: appSchema, path: dbPath);
      await mockDb.initialize();
      
      await mockDb.execute(
        'INSERT INTO books (id, title, slug, description, cover) VALUES (?, ?, ?, ?, ?)',
        ['11111111-1111-4b01-90e6-111111111111', 'Test Book', 'test-book', 'Desc', null]
      );
      await mockDb.execute(
        'INSERT INTO authors (id, name, bio) VALUES (?, ?, ?)',
        ['22222222-2222-4b01-90e6-222222222222', 'Author', null]
      );
      await mockDb.execute(
        'INSERT INTO book_authors (id, book_id, author_id) VALUES (?, ?, ?)',
        ['33333333-3333-4b01-90e6-333333333333', '11111111-1111-4b01-90e6-111111111111', '22222222-2222-4b01-90e6-222222222222']
      );

      await configureFts(mockDb);

      repo = PowerSyncLibraryRepository(mockDb);
      connector = PowerSyncSyncConnector(mockDb);
    });

    tearDown(() async {
      await mockDb.disconnect();
      await mockDb.close();
      try { File(dbPath).deleteSync(); } catch (_) {}
    });

    group('AppSchema (AC: #1, #2)', () {
      test('must contain required tables', () {
        expect(appSchema.tables.length, greaterThanOrEqualTo(6));
        final tableNames = appSchema.tables.map((t) => t.name).toList();
        expect(tableNames, contains('books'));
        expect(tableNames, contains('editions'));
        expect(tableNames, contains('authors'));
        expect(tableNames, contains('genres'));
        expect(tableNames, contains('book_authors'));
      });
    });

    group('PowerSyncSyncConnector - Anonymous Auth (AC: #1)', () {
      test('must provide anonymous credentials', () async {
        final creds = await AnonymousConnector().fetchCredentials();
        expect(creds?.endpoint, equals('https://powersync.edumynt.org'));
        expect(creds?.token, equals('anonymous-guest-token'));
      });
    });

    group('PowerSyncLibraryRepository - Catalog Queries (AC: #2)', () {
      test('must fetch catalog books from local cache', () async {
        final books = await repo.getCatalogBooks();
        expect(books.length, equals(1));
        expect(books[0].title, equals('Test Book'));
        expect(books[0].author, equals('Author'));
      });

      test('must handle empty search queries defensively', () async {
        final results = await repo.searchCatalog('   ');
        expect(results, isEmpty);
      });

      test('must search catalog books via FTS MATCH operator', () async {
        final results = await repo.searchCatalog('Non-existent');
        expect(results, isEmpty);
        
        final resultsFound = await repo.searchCatalog('test book');
        expect(resultsFound.length, equals(1));
        expect(resultsFound[0].title, equals('Test Book'));
      });

      test('must fetch hierarchical book details (AC: #3, #4)', () async {
        // Setup hierarchical data
        await mockDb.execute(
          'INSERT INTO editions (id, book_id, format, title, cover) VALUES (?, ?, ?, ?, ?)',
          ['ed1', '11111111-1111-4b01-90e6-111111111111', 'EPUB', 'Test Edition', 'edition-cover-uuid']
        );
        await mockDb.execute(
          'INSERT INTO parts (id, edition_id, title, sort_order) VALUES (?, ?, ?, ?)',
          ['p1', 'ed1', 'Part 1', 1]
        );
        await mockDb.execute(
          'INSERT INTO chapters (id, title, slug, chapter_type, counts_toward_completion) VALUES (?, ?, ?, ?, ?)',
          ['c1', 'Chapter 1', 'chapter-1', 'TEXT', 1]
        );
        await mockDb.execute(
          'INSERT INTO part_chapters (id, part_id, chapter_id, sort_order) VALUES (?, ?, ?, ?)',
          ['pc1', 'p1', 'c1', 1]
        );

        final book = await repo.getBookDetails('test-book');
        expect(book, isNotNull);
        expect(book!.title, equals('Test Book'));
        expect(book.editions, isNotEmpty);
        expect(book.editions[0].title, equals('Test Edition'));
        
        // Edge Cover Display (AC: #4)
        expect(book.editions[0].cover, contains('edition-cover-uuid?key=cover'));
        
        // Hierarchical layout (AC: #3)
        expect(book.editions[0].parts, isNotEmpty);
        expect(book.editions[0].parts[0].chapters, isNotEmpty);
        expect(book.editions[0].parts[0].chapters[0].title, equals('Chapter 1'));
        expect(book.editions[0].parts[0].chapters[0].countsTowardCompletion, isTrue);
      });

      test('must watch curated lists (AC: 1.5)', () async {
        await mockDb.execute(
          'INSERT INTO book_lists (id, title, slug, sort_order) VALUES (?, ?, ?, ?)',
          ['list1', 'Staff Picks', 'staff-picks', 1]
        );
        await mockDb.execute(
          'INSERT INTO book_list_items (id, book_list_id, book_id, sort_order) VALUES (?, ?, ?, ?)',
          ['item1', 'list1', '11111111-1111-4b01-90e6-111111111111', 1]
        );

        final stream = repo.watchCuratedLists();
        final firstEmission = await stream.first;

        expect(firstEmission.length, equals(1));
        expect(firstEmission[0].title, equals('Staff Picks'));
        expect(firstEmission[0].books.length, equals(1));
        expect(firstEmission[0].books[0].title, equals('Test Book'));
      });
    });
  });
}
