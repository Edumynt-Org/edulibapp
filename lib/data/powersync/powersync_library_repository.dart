import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_details.dart';
import '../../domain/models/book_list.dart';
import '../../domain/models/chapter.dart';
import '../../domain/models/reading_preferences.dart';
import '../../domain/models/annotation.dart';
import '../../domain/models/dictionary_entry.dart';
import '../../domain/models/audio_progress.dart';
import '../../domain/models/review.dart';
import '../../domain/models/user_shelf.dart';
import '../../domain/models/user_shelf_item.dart';
import '../../domain/models/milestone_stats.dart';
import '../../domain/models/achievement_badge.dart';
import '../../config/app_config.dart';
import 'package:http/http.dart' as http;

class PowerSyncLibraryRepository implements ILibraryRepository {
  final PowerSyncDatabase _db;

  PowerSyncLibraryRepository(this._db);

  String get _baseQuery => '''
    SELECT b.*, group_concat(a.name, ', ') as author
    FROM books b
    LEFT JOIN book_authors ba ON b.id = ba.book
    LEFT JOIN authors a ON ba.author = a.id
    GROUP BY b.id
  ''';

  Book _mapRowToBook(Map<String, dynamic> row) {
    return Book(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      slug: row['slug'] as String? ?? '',
      author: row['author'] as String? ?? '',
      description: row['description'] as String? ?? '',
      coverUrl: row['cover'] as String?,
    );
  }

  @override
  Future<List<Book>> getCatalogBooks() async {
    try {
      final rows = await _db.getAll('$_baseQuery ORDER BY b.title ASC');
      return rows.map(_mapRowToBook).toList();
    } catch (e) {
      throw Exception('Failed to fetch catalog books: $e');
    }
  }

  @override
  Future<Book?> getBookById(String id) async {
    try {
      final row = await _db.getOptional('$_baseQuery HAVING b.id = ?', [id]);
      return row != null ? _mapRowToBook(row) : null;
    } catch (e) {
      throw Exception('Failed to fetch book by id: $e');
    }
  }

  @override
  Future<BookDetails?> getBookDetails(String slug) async {
    try {
      final row = await _db.getOptional('''
        SELECT 
          b.*,
          group_concat(a.name, ', ') as author,
          (
            SELECT json_group_array(
              json_object(
                'id', e.id,
                'format', e.format,
                'title', e.title,
                'slug', e.slug,
                'isbn', e.isbn,
                'pages', e.pages,
                'language', e.language,
                'cover', e.cover,
                'chapters', (
                  SELECT json_group_array(
                    json_object(
                      'id', c.id,
                      'title', c.title,
                      'slug', c.slug,
                      'chapterType', c.chapter_type,
                      'countsTowardCompletion', c.counts_toward_completion,
                      'sortOrder', c.sort_order
                    )
                  )
                  FROM (
                    SELECT c.*, ec.sort_order 
                    FROM editions_chapters ec
                    JOIN chapters c ON ec.chapters_id = c.id
                    WHERE ec.editions_id = e.id
                    ORDER BY ec.sort_order
                  ) c
                ),
                'parts', (
                  SELECT json_group_array(
                    json_object(
                      'id', p.id,
                      'title', p.title,
                      'description', p.description,
                      'sortOrder', p.sort_order,
                      'chapters', (
                        SELECT json_group_array(
                          json_object(
                            'id', c.id,
                            'title', c.title,
                            'slug', c.slug,
                            'chapterType', c.chapter_type,
                            'countsTowardCompletion', c.counts_toward_completion,
                            'sortOrder', c.sort_order
                          )
                        )
                        FROM (
                          SELECT c.*, pc.sort_order 
                          FROM parts_chapters pc
                          JOIN chapters c ON pc.chapters_id = c.id
                          WHERE pc.parts_id = p.id
                          ORDER BY pc.sort_order
                        ) c
                      )
                    )
                  )
                  FROM (
                    SELECT p.* FROM parts p
                    WHERE p.edition = e.id
                    ORDER BY p.sort_order
                  ) p
                )
              )
            )
            FROM editions e
            WHERE e.book = b.id
          ) as editions_json,
          (
            SELECT json_group_array(
              json_object(
                'id', ae.id,
                'title', ae.title,
                'slug', ae.slug,
                'language', ae.language,
                'cover', ae.cover,
                'narratorName', ae.narrator_name,
                'isComplete', ae.is_complete,
                'linkedTextEdition', ae.linked_text_edition,
                'rightsStatus', ae.rights_status,
                'audioChapters', (
                  SELECT json_group_array(
                    json_object(
                      'id', ac.id,
                      'title', ac.title,
                      'slug', ac.slug,
                      'audioFile', ac.audio_file,
                      'durationSeconds', ac.duration_seconds,
                      'linkedTextChapter', ac.linked_text_chapter,
                      'rightsStatus', ac.rights_status,
                      'sortOrder', ac.sort_order
                    )
                  )
                  FROM (
                    SELECT ac.*, ae_ac.sort_order 
                    FROM audio_editions_audio_chapters ae_ac
                    JOIN audio_chapters ac ON ae_ac.audio_chapters_id = ac.id
                    WHERE ae_ac.audio_editions_id = ae.id
                    ORDER BY ae_ac.sort_order
                  ) ac
                ),
                'parts', (
                  SELECT json_group_array(
                    json_object(
                      'id', ap.id,
                      'title', ap.title,
                      'description', ap.description,
                      'sortOrder', ap.sort_order,
                      'audioChapters', (
                        SELECT json_group_array(
                          json_object(
                            'id', ac.id,
                            'title', ac.title,
                            'slug', ac.slug,
                            'audioFile', ac.audio_file,
                            'durationSeconds', ac.duration_seconds,
                            'linkedTextChapter', ac.linked_text_chapter,
                            'rightsStatus', ac.rights_status,
                            'sortOrder', ac.sort_order
                          )
                        )
                        FROM (
                          SELECT ac.*, ap_ac.sort_order 
                          FROM audio_parts_audio_chapters ap_ac
                          JOIN audio_chapters ac ON ap_ac.audio_chapters_id = ac.id
                          WHERE ap_ac.audio_parts_id = ap.id
                          ORDER BY ap_ac.sort_order
                        ) ac
                      )
                    )
                  )
                  FROM (
                    SELECT ap.* FROM audio_parts ap
                    WHERE ap.audio_edition = ae.id
                    ORDER BY ap.sort_order
                  ) ap
                )
              )
            )
            FROM audio_editions ae
            WHERE ae.book = b.id
          ) as audio_editions_json
        FROM books b
        LEFT JOIN book_authors ba ON b.id = ba.book
        LEFT JOIN authors a ON ba.author = a.id
        WHERE b.slug = ?
        GROUP BY b.id
      ''', [slug]);

      if (row == null) return null;

      final directusUrl = AppConfig.directusUrl;
      String? getCoverUrl(String? coverId) {
        if (coverId == null) return null;
        return '$directusUrl/assets/$coverId';
      }

      List<Chapter> parseChapters(List<dynamic> list) {
        return list.map((c) => Chapter(
          id: c['id'],
          title: c['title'],
          slug: c['slug'],
          chapterType: c['chapterType'],
          countsTowardCompletion: c['countsTowardCompletion'] == 1,
          sortOrder: c['sortOrder'],
        )).toList();
      }

      List<Part> parseParts(List<dynamic> list) {
        return list.map((p) => Part(
          id: p['id'],
          title: p['title'],
          description: p['description'],
          sortOrder: p['sortOrder'],
          chapters: parseChapters(p['chapters'] ?? []),
        )).toList();
      }

      List<AudioChapter> parseAudioChapters(List<dynamic> list) {
        return list.map((ac) => AudioChapter(
          id: ac['id'],
          title: ac['title'],
          slug: ac['slug'],
          audioFile: ac['audioFile'],
          durationSeconds: ac['durationSeconds'],
          linkedTextChapter: ac['linkedTextChapter'],
          rightsStatus: ac['rightsStatus'],
          sortOrder: ac['sortOrder'],
        )).toList();
      }

      List<AudioPart> parseAudioParts(List<dynamic> list) {
        return list.map((ap) => AudioPart(
          id: ap['id'],
          title: ap['title'],
          description: ap['description'],
          sortOrder: ap['sortOrder'],
          audioChapters: parseAudioChapters(ap['audioChapters'] ?? []),
        )).toList();
      }

      final editionsJsonStr = row['editions_json'] as String?;
      final audioEditionsJsonStr = row['audio_editions_json'] as String?;
      
      final editionsList = editionsJsonStr != null ? jsonDecode(editionsJsonStr) as List<dynamic> : [];
      final audioEditionsList = audioEditionsJsonStr != null ? jsonDecode(audioEditionsJsonStr) as List<dynamic> : [];

      final editions = editionsList.map((e) => Edition(
        id: e['id'],
        format: e['format'],
        isbn: e['isbn'],
        pages: e['pages'],
        title: e['title'],
        slug: e['slug'],
        language: e['language'],
        cover: getCoverUrl(e['cover']),
        chapters: parseChapters(e['chapters'] ?? []),
        parts: parseParts(e['parts'] ?? []),
      )).toList();

      final audioEditions = audioEditionsList.map((ae) => AudioEdition(
        id: ae['id'],
        title: ae['title'],
        slug: ae['slug'],
        language: ae['language'],
        cover: getCoverUrl(ae['cover']),
        narratorName: ae['narratorName'],
        isComplete: ae['isComplete'] == 1,
        linkedTextEdition: ae['linkedTextEdition'],
        rightsStatus: ae['rightsStatus'],
        parts: parseAudioParts(ae['parts'] ?? []),
        audioChapters: parseAudioChapters(ae['audioChapters'] ?? []),
      )).toList();

      return BookDetails(
        id: row['id'] as String? ?? '',
        title: row['title'] as String? ?? '',
        slug: row['slug'] as String? ?? '',
        author: row['author'] as String? ?? '',
        description: row['description'] as String? ?? '',
        coverUrl: getCoverUrl(row['cover'] as String?),
        originalTitle: row['original_title'] as String?,
        originalLanguage: row['original_language'] as String?,
        firstPublishedYear: row['first_published_year'] as int?,
        editions: editions,
        audioEditions: audioEditions,
      );
    } catch (e) {
      throw Exception('Failed to fetch book details: $e');
    }
  }

  @override
  Future<List<Book>> searchCatalog(String query) async {
    // Strip special characters that break SQLite FTS5 MATCH syntax
    final safeQuery = query.replaceAll(RegExp(r'''['"\-*\(\)\[\]\{\}~^:]'''), ' ').trim();
    if (safeQuery.isEmpty) return <Book>[];
    
    // Split into tokens and append * to each token for prefix matching
    final matchQuery = safeQuery.split(RegExp(r'\s+')).map((t) => '$t*').join(' ');

    try {
      final rows = await _db.getAll('''
        SELECT b.*, group_concat(a.name, ', ') as author
        FROM fts_books f
        JOIN books b ON f.id = b.id
        LEFT JOIN book_authors ba ON b.id = ba.book
        LEFT JOIN authors a ON ba.author = a.id
        WHERE fts_books MATCH ?
        GROUP BY b.id
        ORDER BY rank
        LIMIT 20
      ''', [matchQuery]);
      return rows.map(_mapRowToBook).toList();
    } catch (e) {
      throw Exception('Failed to search catalog: $e');
    }
  }

  @override
  Stream<List<BookList>> watchCuratedLists() {
    final directusUrl = AppConfig.directusUrl;
    String? getCoverUrl(String? coverId) {
      if (coverId == null) return null;
      return '$directusUrl/assets/$coverId';
    }

    final sql = '''
      SELECT 
        l.*,
        (
          SELECT json_group_array(
            json_object(
              'id', b.id,
              'title', b.title,
              'slug', b.slug,
              'description', b.description,
              'cover', b.cover,
              'author', (
                 SELECT group_concat(a.name, ', ')
                 FROM book_authors ba 
                 JOIN authors a ON ba.author = a.id 
                 WHERE ba.book = b.id
              )
            )
          )
          FROM (
            SELECT b.*, li.sort_order 
            FROM book_list_items li
            JOIN books b ON li.book = b.id
            WHERE li.list = l.id
            ORDER BY li.sort_order ASC
          ) b
        ) as books_json
      FROM book_lists l
      ORDER BY l.sort_order ASC
    ''';

    return _db.watch(sql).map((results) {
      return results.map((row) {
        final booksJsonStr = row['books_json'] as String?;
        final booksList = booksJsonStr != null ? jsonDecode(booksJsonStr) as List<dynamic> : [];
        final books = booksList.map((b) => Book(
          id: b['id'] as String? ?? '',
          title: b['title'] as String? ?? '',
          slug: b['slug'] as String? ?? '',
          description: b['description'] as String? ?? '',
          coverUrl: getCoverUrl(b['cover'] as String?),
          author: b['author'] as String? ?? '',
        )).toList();

        return BookList(
          id: row['id'] as String? ?? '',
          title: row['title'] as String? ?? '',
          slug: row['slug'] as String? ?? '',
          listType: row['list_type'] as String?,
          coverUrl: getCoverUrl(row['cover'] as String?),
          books: books,
        );
      }).toList();
    });
  }

  @override
  Future<Chapter?> getChapter(String slug) async {
    try {
      final record = await _db.getOptional('''
        SELECT * FROM chapters WHERE slug = ?
      ''', [slug]);
      
      if (record == null) return null;
      return Chapter(
        id: record['id'],
        title: record['title'],
        slug: record['slug'],
        chapterType: record['chapter_type'],
        countsTowardCompletion: record['counts_toward_completion'] == 1,
        content: record['content'] ?? '',
        summary: record['summary'] ?? '',
      );
    } catch (e) {
      throw Exception('Failed to fetch chapter: $e');
    }
  }

  @override
  Future<({int progressPercent, int scrollPosition})?> getChapterProgress(String chapterId) async {
    final profileId = 'guest'; 
    try {
      final result = await _db.getOptional(
        'SELECT progress_percent, last_position FROM chapter_progress WHERE chapter = ? AND profile = ?',
        [chapterId, profileId],
      );
      if (result == null) return null;
      return (
        progressPercent: result['progress_percent'] as int? ?? 0, 
        scrollPosition: result['last_position'] as int? ?? 0
      );
    } catch (e) {
      debugPrint('Failed to get chapter progress: $e');
      return null;
    }
  }

  @override
  Future<({int progressPercent, int positionSeconds, int durationSeconds})?> getLinkedAudioProgress(String textChapterId) async {
    final profileId = 'guest';
    try {
      // Find linked audio chapter
      final acResult = await _db.getOptional(
        'SELECT id, duration_seconds FROM audio_chapters WHERE linked_text_chapter = ?',
        [textChapterId],
      );
      if (acResult == null) return null;
      
      final audioChapterId = acResult['id'] as String;
      final durationSeconds = acResult['duration_seconds'] as int? ?? 0;
      
      // Get audio progress
      final apResult = await _db.getOptional(
        'SELECT progress_seconds FROM audio_progress WHERE audio_chapter = ? AND profile = ?',
        [audioChapterId, profileId],
      );
      if (apResult == null) return null;
      
      final progressSeconds = apResult['progress_seconds'] as int? ?? 0;
      int percent = 0;
      if (durationSeconds > 0) {
        percent = ((progressSeconds / durationSeconds) * 100).round();
      }
      
      return (
        progressPercent: percent,
        positionSeconds: progressSeconds,
        durationSeconds: durationSeconds
      );
    } catch (e) {
      debugPrint('Failed to get linked audio progress: $e');
      return null;
    }
  }

  @override
  Future<void> updateChapterProgress(String chapterId, int progressPercent, int scrollPosition) async {
    try {
      // In local-first offline writes, we insert/update chapter_progress locally.
      const profileId = 'guest'; // We will update this in Epic 4
      
      final existing = await _db.getOptional('''
        SELECT id FROM chapter_progress WHERE chapter = ? AND profile = ?
      ''', [chapterId, profileId]);
      
      final now = DateTime.now().toIso8601String();
      final status = progressPercent >= 100 ? 'completed' : 'in_progress';
      final completedAt = progressPercent >= 100 ? now : null;
      
      if (existing != null) {
        final oldProgress = await getChapterProgress(chapterId);
        if (oldProgress != null) {
          final advancement = progressPercent - oldProgress.progressPercent;
          if (advancement >= 1) {
            await calculateAndSyncDailyStreak();
          }
        }
        await _db.execute('''
          UPDATE chapter_progress 
          SET progress_percent = ?, last_position = ?, last_read_at = ?, status = ?, completed_at = ?
          WHERE id = ?
        ''', [progressPercent, scrollPosition, now, status, completedAt, existing['id']]);
      } else {
        if (progressPercent >= 1) {
          await calculateAndSyncDailyStreak();
        }
        final newId = const Uuid().v4();
        await _db.execute('''
          INSERT INTO chapter_progress (id, profile, chapter, progress_percent, last_position, last_read_at, status, completed_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [newId, profileId, chapterId, progressPercent, scrollPosition, now, status, completedAt]);
      }
    } catch (e) {
      debugPrint('Failed to update chapter progress: $e');
    }
  }

  @override
  Future<ReadingPreferences> getReadingPreferences() async {
    try {
      const profileId = 'guest'; // Epic 4 will replace this
      final record = await _db.getOptional('SELECT * FROM reading_preferences WHERE profile = ?', [profileId]);
      if (record != null) {
        return ReadingPreferences(
          profileId: record['profile'] as String?,
          fontFamily: record['font_family'] as String? ?? 'serif',
          fontSizePx: (record['font_size_px'] as int?) ?? 18,
          lineSpacing: record['line_spacing'] as String? ?? 'normal',
          theme: record['theme'] as String? ?? 'light',
          margins: record['margins'] as String? ?? 'normal',
        );
      }
    } catch (e) {
      debugPrint('Failed to get reading preferences: $e');
    }
    return const ReadingPreferences();
  }

  @override
  Future<void> updateReadingPreferences(ReadingPreferences prefs) async {
    try {
      const profileId = 'guest'; // Epic 4 will replace this
      
      final existing = await _db.getOptional('SELECT id FROM reading_preferences WHERE profile = ?', [profileId]);
      
      if (existing != null) {
        await _db.execute('''
          UPDATE reading_preferences 
          SET font_family = ?, font_size_px = ?, line_spacing = ?, theme = ?, margins = ?
          WHERE id = ?
        ''', [prefs.fontFamily, prefs.fontSizePx, prefs.lineSpacing, prefs.theme, prefs.margins, existing['id']]);
      } else {
        final newId = const Uuid().v4();
        await _db.execute('''
          INSERT INTO reading_preferences (id, profile, font_family, font_size_px, line_spacing, theme, margins)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [newId, profileId, prefs.fontFamily, prefs.fontSizePx, prefs.lineSpacing, prefs.theme, prefs.margins]);
      }
    } catch (e) {
      debugPrint('Failed to update reading preferences: $e');
    }
  }

  @override
  Future<List<Annotation>> getAnnotations(String chapterId) async {
    try {
      final records = await _db.getAll('SELECT * FROM annotations WHERE chapter_id = ?', [chapterId]);
      return records.map((r) => Annotation(
        id: r['id'] as String,
        profileId: r['profile'] as String,
        chapterId: r['chapter_id'] as String,
        annotationType: r['annotation_type'] as String,
        color: r['color'] as String?,
        selectedText: r['selected_text'] as String?,
        noteText: r['note_text'] as String?,
        startPosition: r['start_position'] as String?,
        endPosition: r['end_position'] as String?,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      )).toList();
    } catch (e) {
      debugPrint('Failed to get annotations: $e');
      return [];
    }
  }

  @override
  Future<Annotation> addAnnotation(Annotation annotation) async {
    try {
      const profileId = 'guest'; // Epic 4 will replace this
      final newId = const Uuid().v4();
      final createdAt = DateTime.now();

      await _db.execute('''
        INSERT INTO annotations (id, profile, chapter_id, annotation_type, color, selected_text, note_text, start_position, end_position, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [newId, profileId, annotation.chapterId, annotation.annotationType, annotation.color, annotation.selectedText, annotation.noteText, annotation.startPosition, annotation.endPosition, createdAt.toIso8601String()]);

      return annotation.copyWith(
        id: newId,
        profileId: profileId,
        createdAt: createdAt,
      );
    } catch (e) {
      throw Exception('Failed to add annotation: $e');
    }
  }

  @override
  Future<void> updateAnnotation(Annotation annotation) async {
    try {
      await _db.execute('''
        UPDATE annotations 
        SET color = ?, note_text = ?, start_position = ?, end_position = ?
        WHERE id = ?
      ''', [annotation.color, annotation.noteText, annotation.startPosition, annotation.endPosition, annotation.id]);
    } catch (e) {
      throw Exception('Failed to update annotation: $e');
    }
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    try {
      await _db.execute('DELETE FROM annotations WHERE id = ?', [annotationId]);
    } catch (e) {
      throw Exception('Failed to delete annotation: $e');
    }
  }

  @override
  Future<DictionaryEntry?> getDefinition(String word) async {
    final cleanWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.isEmpty) return null;

    try {
      // 1. Check local cache
      final cached = await _db.getOptional('SELECT definition_json FROM dictionary_cache WHERE word = ?', [cleanWord]);
      if (cached != null && cached['definition_json'] != null) {
        return DictionaryEntry.fromJson(jsonDecode(cached['definition_json'] as String));
      }

      // 2. Fetch from API
      final response = await http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord'));
      if (response.statusCode != 200) return null;
      
      final data = jsonDecode(response.body);
      if (data != null && data is List && data.isNotEmpty) {
        final entry = DictionaryEntry.fromJson(data[0]);

        // 3. Save to cache
        await _db.execute(
          'INSERT OR REPLACE INTO dictionary_cache (word, definition_json, timestamp) VALUES (?, ?, ?)',
          [cleanWord, jsonEncode(entry.toJson()), DateTime.now().toIso8601String()]
        );

        return entry;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get definition: $e');
      return null;
    }
  }

  @override
  Future<AudioProgress?> getAudioProgress(String bookId, String audioChapterId) async {
    const profileId = 'guest';
    final query = 'SELECT * FROM audio_progress WHERE profile = ? AND book = ? AND audio_chapter = ?';
    final params = [profileId, bookId, audioChapterId];

    try {
      final row = await _db.getOptional(query, params);
      if (row == null) return null;
      return AudioProgress(
        profileId: row['profile'] as String?,
        bookId: row['book'] as String,
        audioChapterId: row['audio_chapter'] as String,
        positionSeconds: row['position_seconds'] as int,
        durationSeconds: row['duration_seconds'] as int,
        status: row['status'] as String,
        completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
        lastListenedAt: DateTime.parse(row['last_listened_at'] as String),
      );
    } catch (e) {
      debugPrint('Failed to get audio progress: $e');
      return null;
    }
  }

  @override
  Future<void> saveAudioProgress(AudioProgress progress) async {
    const profileToUse = 'guest';

    try {
      final existing = await getAudioProgress(progress.bookId, progress.audioChapterId);
      if (existing != null) {
        final oldSeconds = existing.positionSeconds;
        if (progress.positionSeconds - oldSeconds >= 300) {
          await calculateAndSyncDailyStreak();
        }
      } else if (progress.positionSeconds >= 300) {
        await calculateAndSyncDailyStreak();
      }

      if (existing != null) {
        await _db.execute(
          'UPDATE audio_progress SET position_seconds = ?, duration_seconds = ?, status = ?, completed_at = ?, last_listened_at = ? WHERE profile IS ? AND book = ? AND audio_chapter = ?',
          [
            progress.positionSeconds,
            progress.durationSeconds,
            progress.status,
            progress.completedAt?.toIso8601String(),
            progress.lastListenedAt.toIso8601String(),
            profileToUse,
            progress.bookId,
            progress.audioChapterId,
          ]
        );
      } else {
        await _db.execute(
          'INSERT INTO audio_progress (profile, book, audio_chapter, position_seconds, duration_seconds, status, completed_at, last_listened_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            profileToUse,
            progress.bookId,
            progress.audioChapterId,
            progress.positionSeconds,
            progress.durationSeconds,
            progress.status,
            progress.completedAt?.toIso8601String(),
            progress.lastListenedAt.toIso8601String(),
          ]
        );
      }
    } catch (e) {
      debugPrint('Failed to save audio progress: $e');
    }
  }

  @override
  Future<void> updateBookStatus(String bookId, String status) async {
    const profileId = 'guest'; 
    try {
      final existing = await _db.getOptional('''
        SELECT id FROM user_books WHERE book = ? AND profile = ?
      ''', [bookId, profileId]);
      
      final now = DateTime.now().toIso8601String();
      final dateFinished = status == 'completed' ? now : null;
      
      if (existing != null) {
        await _db.execute('''
          UPDATE user_books 
          SET reading_status = ?, last_activity_at = ?, date_finished = ?
          WHERE id = ?
        ''', [status, now, dateFinished, existing['id']]);
      } else {
        final newId = const Uuid().v4();
        await _db.execute('''
          INSERT INTO user_books (id, profile, book, reading_status, date_started, date_finished, last_activity_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [newId, profileId, bookId, status, now, dateFinished, now]);
      }
    } catch (e) {
      debugPrint('Failed to update book status: $e');
      rethrow;
    }
  }

  @override
  Future<Review> createReview(ReviewDraft review) async {
    if (review.rating < 0 || review.rating > 5 || (review.rating * 2) % 1 != 0) {
      throw ArgumentError('Ratings must be between 0 and 5 in 0.5 increments.');
    }

    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.execute('''
      INSERT INTO reviews (id, profile, book, rating, title, body, contains_spoilers, status, date_created, date_updated)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      id,
      review.profileId,
      review.bookId,
      review.rating,
      review.title,
      review.body,
      review.containsSpoilers ? 1 : 0,
      'published',
      now,
      now,
    ]);

    return Review(
      id: id,
      profileId: review.profileId,
      bookId: review.bookId,
      rating: review.rating,
      title: review.title,
      body: review.body,
      containsSpoilers: review.containsSpoilers,
      status: 'published',
      dateCreated: DateTime.parse(now),
      dateUpdated: DateTime.parse(now),
    );
  }

  @override
  Future<List<Review>> getReviewsForBook(String bookId) async {
    final rows = await _db.getAll(
      'SELECT * FROM reviews WHERE book = ? AND status = ? ORDER BY date_created DESC',
      [bookId, 'published'],
    );
    return rows.map(Review.fromMap).toList();
  }

  @override
  Future<List<Review>> getReviewsByUser(String profileId) async {
    final rows = await _db.getAll(
      'SELECT * FROM reviews WHERE profile = ? ORDER BY date_created DESC',
      [profileId],
    );
    return rows.map(Review.fromMap).toList();
  }

  @override
  Future<UserShelf> createCustomShelf(String name, bool isPrivate, {String? description}) async {
    const profileId = 'guest';
    final id = const Uuid().v4();
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final now = DateTime.now().toUtc().toIso8601String();

    await _db.execute('''
      INSERT INTO user_shelves (id, profile, name, slug, description, is_private, sort_order, date_created, date_updated)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [id, profileId, name, slug, description, isPrivate ? 1 : 0, 0, now, now]);

    return UserShelf(
      id: id,
      profileId: profileId,
      name: name,
      slug: slug,
      description: description,
      isPrivate: isPrivate,
      sortOrder: 0,
      dateCreated: DateTime.parse(now),
      dateUpdated: DateTime.parse(now),
    );
  }

  @override
  Future<void> addBookToShelf(String shelfId, String bookId) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    final result = await _db.getOptional('SELECT MAX(sort_order) as max_sort FROM user_shelf_items WHERE shelf = ?', [shelfId]);
    final maxSort = result?['max_sort'] as int? ?? 0;
    final nextSort = maxSort + 1;

    await _db.execute('''
      INSERT INTO user_shelf_items (id, shelf, book, sort_order, date_added)
      VALUES (?, ?, ?, ?, ?)
    ''', [id, shelfId, bookId, nextSort, now]);
  }

  @override
  Future<void> removeBookFromShelf(String shelfId, String bookId) async {
    await _db.execute('DELETE FROM user_shelf_items WHERE shelf = ? AND book = ?', [shelfId, bookId]);
  }

  @override
  Future<void> reorderShelf(String shelfId, List<String> bookIds) async {
    await _db.writeTransaction((tx) async {
      for (int i = 0; i < bookIds.length; i++) {
        await tx.execute('UPDATE user_shelf_items SET sort_order = ? WHERE shelf = ? AND book = ?', [i, shelfId, bookIds[i]]);
      }
    });
  }

  @override
  Future<List<UserShelf>> getPublicShelves(String profileId) async {
    final rows = await _db.getAll('SELECT * FROM user_shelves WHERE profile = ? AND is_private = 0 ORDER BY sort_order', [profileId]);
    return rows.map((r) => UserShelf.fromMap(r)).toList();
  }

  @override
  Future<List<UserShelf>> getUserShelves() async {
    const profileId = 'guest';
    final rows = await _db.getAll('SELECT * FROM user_shelves WHERE profile = ? ORDER BY sort_order', [profileId]);
    return rows.map((r) => UserShelf.fromMap(r)).toList();
  }

  @override
  Future<List<UserShelfItem>> getShelfItems(String shelfId) async {
    final rows = await _db.getAll('''
      SELECT si.*, b.title as book_title, b.slug as book_slug, b.cover as book_cover
      FROM user_shelf_items si
      JOIN books b ON si.book = b.id
      WHERE si.shelf = ?
      ORDER BY si.sort_order
    ''', [shelfId]);
    
    final directusUrl = AppConfig.directusUrl;
    String? getCoverUrl(String? coverId) {
      if (coverId == null) return null;
      return '$directusUrl/assets/$coverId';
    }

    return rows.map((r) {
      final book = Book(
        id: r['book'] as String? ?? '',
        title: r['book_title'] as String? ?? '',
        slug: r['book_slug'] as String? ?? '',
        coverUrl: getCoverUrl(r['book_cover'] as String?),
        author: '',
        description: '',
      );
      return UserShelfItem.fromMap(r, book: book);
    }).toList();
  }

  @override
  Future<int> getDailyStreakCount(String profileId) async {
    try {
      final row = await _db.getOptional('SELECT current_streak FROM profiles WHERE id = ?', [profileId]);
      return row != null ? (row['current_streak'] as int? ?? 0) : 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<void> calculateAndSyncDailyStreak() async {
    const profileId = 'guest'; // We would ideally get the current authenticated user's ID
    try {
      final row = await _db.getOptional('SELECT current_streak, last_streak_date FROM profiles WHERE id = ?', [profileId]);
      if (row == null) return;
      
      final lastStreakDateStr = row['last_streak_date'] as String?;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      if (lastStreakDateStr == null) {
        await _db.execute('UPDATE profiles SET current_streak = 1, last_streak_date = ? WHERE id = ?', [today.toIso8601String(), profileId]);
        return;
      }
      
      final lastDate = DateTime.parse(lastStreakDateStr);
      final lastDateMidnight = DateTime(lastDate.year, lastDate.month, lastDate.day);
      
      final diffTime = (today.millisecondsSinceEpoch - lastDateMidnight.millisecondsSinceEpoch).abs();
      final diffDays = (diffTime / (1000 * 60 * 60 * 24)).ceil();
      
      if (diffDays == 0) {
        return;
      } else if (diffDays <= 3) {
        await _db.execute('UPDATE profiles SET current_streak = current_streak + 1, last_streak_date = ? WHERE id = ?', [today.toIso8601String(), profileId]);
      } else {
        await _db.execute('UPDATE profiles SET current_streak = 1, last_streak_date = ? WHERE id = ?', [today.toIso8601String(), profileId]);
      }
    } catch (e) {
      debugPrint('Failed to update daily streak: $e');
    }
  }

  @override
  Future<MilestoneStats> getMilestoneStats(String profileId) async {
    final completedBooksResult = await _db.getOptional('SELECT count(*) as count FROM chapter_progress WHERE profile = ? AND status = ?', [profileId, 'Completed']);
    int totalBooksFinished = (completedBooksResult?['count'] as int?) ?? 0;

    final pagesResult = await _db.getOptional('SELECT sum(progress_percent) as total FROM chapter_progress WHERE profile = ?', [profileId]);
    int totalPagesRead = (pagesResult?['total'] as int?) ?? 0; // rough approximation

    final hoursResult = await _db.getOptional('SELECT sum(position_seconds) as total FROM audio_progress WHERE profile = ?', [profileId]);
    int totalHoursListened = ((hoursResult?['total'] as int?) ?? 0) ~/ 3600;

    return MilestoneStats(
      totalBooksFinished: totalBooksFinished,
      totalPagesRead: totalPagesRead,
      totalHoursListened: totalHoursListened,
      monthlyPages: [],
      monthlyHours: [],
    );
  }

  @override
  Future<List<AchievementBadge>> getAchievementBadges(String profileId) async {
    final results = await _db.getAll('''
      SELECT a.*, ua.awarded_at 
      FROM achievements a
      LEFT JOIN user_achievements ua ON a.name = ua.achievement_id AND ua.profile = ?
    ''', [profileId]);
    
    return results.map((r) => AchievementBadge(
      id: r['name'] as String,
      name: r['name'] as String,
      description: r['description'] as String,
      criteriaType: r['criteria_type'] as String,
      threshold: r['threshold'] as int,
      badgeIcon: r['badge_icon'] as String,
      awardedAt: r['awarded_at'] != null ? DateTime.parse(r['awarded_at'] as String) : null,
    )).toList();
  }
}
