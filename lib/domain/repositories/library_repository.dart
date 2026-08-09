import '../models/book.dart';
import '../models/book_details.dart';
import '../models/book_list.dart';
import '../models/chapter.dart';
import '../models/reading_preferences.dart';
import '../models/annotation.dart';
import '../models/dictionary_entry.dart';
import '../models/audio_progress.dart';

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
}
