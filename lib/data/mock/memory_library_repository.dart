import '../../domain/repositories/library_repository.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_details.dart';
import '../../domain/models/book_list.dart';

import '../../domain/models/chapter.dart';
import '../../domain/models/reading_preferences.dart';
import '../../domain/models/annotation.dart';
import '../../domain/models/dictionary_entry.dart';
import '../../domain/models/audio_progress.dart';
import '../../domain/models/user_shelf_item.dart';
import '../../domain/models/review.dart';
import '../../domain/models/milestone_stats.dart';
import '../../domain/models/achievement_badge.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _sampleBooks = [
  Book(
    id: 'a1111111-1111-4b01-90e6-111111111111',
    title: 'The Open Architecture of Knowledge',
    slug: 'open-architecture-knowledge',
    author: 'Elena Rostova',
    description: 'A deep exploration of barrier-free digital libraries.',
    coverUrl: '/covers/open-arch.jpg',
  ),
  Book(
    id: 'b2222222-2222-4b01-90e6-222222222222',
    title: 'Zero Latency Reading Systems',
    slug: 'zero-latency-reading-systems',
    author: 'Dr. Marcus Vance',
    description: 'Optimizing edge storage and local SQLite persistence for books.',
    coverUrl: '/covers/zero-latency.jpg',
  ),
];

class MemoryLibraryRepository implements ILibraryRepository {
  final List<Book> _books = List.of(_sampleBooks);
  ReadingPreferences _readingPrefs = const ReadingPreferences();
  final List<Annotation> _annotations = [];
  final Map<String, DictionaryEntry> _dictionaryCache = {};
  final List<AudioProgress> _audioProgress = [];
  final List<Review> _reviews = [];

  @override
  Future<List<Book>> getCatalogBooks() async {
    return List.unmodifiable(_books);
  }

  @override
  Future<Book?> getBookById(String id) async {
    for (final book in _books) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Future<BookDetails?> getBookDetails(String slug) async {
    // For mock repo, just return null or dummy implementation
    return null;
  }

  @override
  Future<List<Book>> searchCatalog(String query) async {
    if (query.trim().isEmpty) return <Book>[];
    final lower = query.toLowerCase();
    return _books.where((b) =>
      b.title.toLowerCase().contains(lower) ||
      b.description.toLowerCase().contains(lower) ||
      b.author.toLowerCase().contains(lower)
    ).toList();
  }

  @override
  Stream<List<BookList>> watchCuratedLists() {
    return Stream.value([
      BookList(
        id: 'mock-list-1',
        title: 'Top Staff Picks',
        slug: 'top-staff-picks',
        books: _books,
      )
    ]);
  }

  @override
  Future<Chapter?> getChapter(String slug) async {
    return Chapter(
      id: 'c3333333-3333-4b01-90e6-333333333333',
      title: 'Mock Chapter',
      slug: slug,
      chapterType: 'chapter',
      countsTowardCompletion: true,
      content: '# Mock Chapter\n\nThis is a mock chapter for testing.',
    );
  }

  @override
  Future<({int progressPercent, int scrollPosition})?> getChapterProgress(String chapterId) async {
    return null;
  }

  @override
  Future<({int progressPercent, int positionSeconds, int durationSeconds})?> getLinkedAudioProgress(String textChapterId) async {
    return null;
  }

  @override
  Future<void> updateChapterProgress(String chapterId, int progressPercent, int scrollPosition) async {
    print('Mock: Updated progress for chapter $chapterId to $progressPercent% (scroll: ${scrollPosition}px)');
  }

  @override
  Future<ReadingPreferences> getReadingPreferences() async {
    return _readingPrefs;
  }

  @override
  Future<void> updateReadingPreferences(ReadingPreferences prefs) async {
    _readingPrefs = prefs;
    print('Mock: Updated reading preferences');
  }

  @override
  Future<List<Annotation>> getAnnotations(String chapterId) async {
    return _annotations.where((a) => a.chapterId == chapterId).toList();
  }

  @override
  Future<Annotation> addAnnotation(Annotation annotation) async {
    final newAnnotation = annotation.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: 'guest',
      createdAt: DateTime.now(),
    );
    _annotations.add(newAnnotation);
    return newAnnotation;
  }

  @override
  Future<void> updateAnnotation(Annotation annotation) async {
    final idx = _annotations.indexWhere((a) => a.id == annotation.id);
    if (idx >= 0) {
      _annotations[idx] = annotation;
    }
  }

  @override
  Future<void> deleteAnnotation(String annotationId) async {
    _annotations.removeWhere((a) => a.id == annotationId);
  }

  @override
  Future<DictionaryEntry?> getDefinition(String word) async {
    final cleanWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.isEmpty) return null;

    if (_dictionaryCache.containsKey(cleanWord)) {
      return _dictionaryCache[cleanWord];
    }

    try {
      final response = await http.get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$cleanWord'));
      if (response.statusCode != 200) return null;
      
      final data = jsonDecode(response.body);
      if (data != null && data is List && data.isNotEmpty) {
        final entry = DictionaryEntry.fromJson(data[0]);
        _dictionaryCache[cleanWord] = entry;
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
    try {
      return _audioProgress.firstWhere(
        (p) => p.bookId == bookId && p.audioChapterId == audioChapterId,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveAudioProgress(AudioProgress progress) async {
    final index = _audioProgress.indexWhere(
      (p) => p.bookId == progress.bookId && p.audioChapterId == progress.audioChapterId,
    );
    if (index >= 0) {
      _audioProgress[index] = progress;
    } else {
      _audioProgress.add(progress);
    }
  }

  @override
  Future<void> updateBookStatus(String bookId, String status) async {
    print('Mock updateBookStatus $bookId $status');
  }

  @override
  Future<UserShelf> createCustomShelf(String name, bool isPrivate, {String? description}) async {
    final now = DateTime.now();
    return UserShelf(
      id: 'mock-id-${now.millisecondsSinceEpoch}',
      profileId: 'guest',
      name: name,
      slug: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      description: description,
      isPrivate: isPrivate,
      sortOrder: 0,
      dateCreated: now,
      dateUpdated: now,
    );
  }

  @override
  Future<void> addBookToShelf(String shelfId, String bookId) async {}

  @override
  Future<void> removeBookFromShelf(String shelfId, String bookId) async {}

  @override
  Future<void> reorderShelf(String shelfId, List<String> bookIds) async {}

  @override
  Future<List<UserShelf>> getPublicShelves(String profileId) async => [];

  @override
  Future<List<UserShelf>> getUserShelves() async => [];

  @override
  Future<List<UserShelfItem>> getShelfItems(String shelfId) async => [];

  @override
  Future<Review> createReview(ReviewDraft review) async {
    if (review.rating < 0 || review.rating > 5 || (review.rating * 2) % 1 != 0) {
      throw ArgumentError('Ratings must be between 0 and 5 in 0.5 increments.');
    }
    final now = DateTime.now().toUtc();
    final created = Review(
      id: 'review-${now.microsecondsSinceEpoch}',
      profileId: review.profileId,
      bookId: review.bookId,
      rating: review.rating,
      title: review.title,
      body: review.body,
      containsSpoilers: review.containsSpoilers,
      status: 'published',
      dateCreated: now,
      dateUpdated: now,
    );
    _reviews.insert(0, created);
    return created;
  }

  @override
  Future<List<Review>> getReviewsForBook(String bookId) async =>
      _reviews.where((review) => review.bookId == bookId && review.status == 'published').toList();

  @override
  Future<List<Review>> getReviewsByUser(String profileId) async =>
      _reviews.where((review) => review.profileId == profileId).toList();

  @override
  Future<MilestoneStats> getMilestoneStats(String profileId) async {
    return MilestoneStats.empty();
  }

  @override
  Future<List<AchievementBadge>> getAchievementBadges(String profileId) async {
    return [];
  }
}
