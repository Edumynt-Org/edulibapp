import 'book.dart';
import 'chapter.dart';

class Part {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final List<Chapter> chapters;

  const Part({
    required this.id,
    required this.title,
    this.description,
    required this.sortOrder,
    required this.chapters,
  });
}

class Edition {
  final String id;
  final String? format;
  final String? isbn;
  final int? pages;
  final String? title;
  final String? slug;
  final String? language;
  final String? cover;
  final List<Part> parts;
  final List<Chapter> chapters; // For direct chapters without parts

  const Edition({
    required this.id,
    this.format,
    this.isbn,
    this.pages,
    this.title,
    this.slug,
    this.language,
    this.cover,
    required this.parts,
    required this.chapters,
  });
}

class AudioChapter {
  final String id;
  final String title;
  final String slug;
  final String? audioFile;
  final int? durationSeconds;
  final String? linkedTextChapter;
  final String? rightsStatus;
  final int sortOrder;

  const AudioChapter({
    required this.id,
    required this.title,
    required this.slug,
    this.audioFile,
    this.durationSeconds,
    this.linkedTextChapter,
    this.rightsStatus,
    required this.sortOrder,
  });
}

class AudioPart {
  final String id;
  final String title;
  final String? description;
  final int sortOrder;
  final List<AudioChapter> audioChapters;

  const AudioPart({
    required this.id,
    required this.title,
    this.description,
    required this.sortOrder,
    required this.audioChapters,
  });
}

class AudioEdition {
  final String id;
  final String? title;
  final String? slug;
  final String? language;
  final String? cover;
  final String? narratorName;
  final bool isComplete;
  final String? linkedTextEdition;
  final String? rightsStatus;
  final List<AudioPart> parts;
  final List<AudioChapter> audioChapters;

  const AudioEdition({
    required this.id,
    this.title,
    this.slug,
    this.language,
    this.cover,
    this.narratorName,
    this.isComplete = false,
    this.linkedTextEdition,
    this.rightsStatus,
    required this.parts,
    required this.audioChapters,
  });
}

class BookDetails extends Book {
  final String? originalTitle;
  final String? originalLanguage;
  final int? firstPublishedYear;
  final List<Edition> editions;
  final List<AudioEdition> audioEditions;

  const BookDetails({
    required super.id,
    required super.title,
    required super.slug,
    required super.author,
    required super.description,
    super.coverUrl,
    this.originalTitle,
    this.originalLanguage,
    this.firstPublishedYear,
    required this.editions,
    required this.audioEditions,
  });
}
