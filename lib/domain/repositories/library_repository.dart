import '../models/book.dart';
import '../models/book_details.dart';
import '../models/book_list.dart';
import '../models/chapter.dart';
import '../models/reading_preferences.dart';
import '../models/annotation.dart';
import '../models/dictionary_entry.dart';
import '../models/audio_progress.dart';
import '../models/user_shelf.dart';
import '../models/user_shelf_item.dart';
import '../models/review.dart';
import '../models/milestone_stats.dart';
import '../models/achievement_badge.dart';

abstract class ILibraryRepository {
  Future<List<Book>> getCatalogBooks();
  Future<Book?> getBookById(String id);
  Future<BookDetails?> getBookDetails(String slug);
  Future<List<Book>> searchCatalog(String query);
  Stream<List<BookList>> watchCuratedLists();
  Future<Chapter?> getChapter(String slug);
  Future<({int progressPercent, int scrollPosition})?> getChapterProgress(String chapterId);
  Future<({int progressPercent, int positionSeconds, int durationSeconds})?> getLinkedAudioProgress(String textChapterId);
  Future<void> updateChapterProgress(String chapterId, int progressPercent, int scrollPosition);
  Future<ReadingPreferences> getReadingPreferences();
  Future<void> updateReadingPreferences(ReadingPreferences prefs);

  Future<List<Annotation>> getAnnotations(String chapterId);
  Future<Annotation> addAnnotation(Annotation annotation);
  Future<void> updateAnnotation(Annotation annotation);
  Future<void> deleteAnnotation(String annotationId);

  Future<DictionaryEntry?> getDefinition(String word);

  Future<AudioProgress?> getAudioProgress(String bookId, String audioChapterId);
  Future<void> saveAudioProgress(AudioProgress progress);
  Future<void> updateBookStatus(String bookId, String status);

  Future<UserShelf> createCustomShelf(String name, bool isPrivate, {String? description});
  Future<void> addBookToShelf(String shelfId, String bookId);
  Future<void> removeBookFromShelf(String shelfId, String bookId);
  Future<void> reorderShelf(String shelfId, List<String> bookIds);
  Future<List<UserShelf>> getPublicShelves(String profileId);
  Future<List<UserShelf>> getUserShelves();
  Future<List<UserShelfItem>> getShelfItems(String shelfId);

  Future<Review> createReview(ReviewDraft review);
  Future<List<Review>> getReviewsForBook(String bookId);
  Future<List<Review>> getReviewsByUser(String profileId);

  Future<void> calculateAndSyncDailyStreak();
  Future<int> getDailyStreakCount(String profileId);

  Future<MilestoneStats> getMilestoneStats(String profileId);
  Future<List<AchievementBadge>> getAchievementBadges(String profileId);
}
