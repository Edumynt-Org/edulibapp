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
      print('Failed to get chapter progress: $e');
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
      print('Failed to get linked audio progress: $e');
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
        await _db.execute('''
          UPDATE chapter_progress 
          SET progress_percent = ?, last_position = ?, last_read_at = ?, status = ?, completed_at = ?
          WHERE id = ?
        ''', [progressPercent, scrollPosition, now, status, completedAt, existing['id']]);
      } else {
        final newId = const Uuid().v4();
        await _db.execute('''
          INSERT INTO chapter_progress (id, profile, chapter, progress_percent, last_position, last_read_at, status, completed_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [newId, profileId, chapterId, progressPercent, scrollPosition, now, status, completedAt]);
      }
    } catch (e) {
      print('Failed to update chapter progress: $e');
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
      print('Failed to get reading preferences: $e');
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
      print('Failed to update reading preferences: $e');
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
      print('Failed to get annotations: $e');
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
      print('Failed to get definition: $e');
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
      print('Failed to get audio progress: $e');
      return null;
    }
  }

  @override
  Future<void> saveAudioProgress(AudioProgress progress) async {
    const profileToUse = 'guest';

    try {
      final existing = await getAudioProgress(progress.bookId, progress.audioChapterId);
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
      print('Failed to save audio progress: $e');
    }
  }
}
