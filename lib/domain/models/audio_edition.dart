import 'audio_chapter.dart';

class AudioEdition {
  final String id;
  final String bookId;
  final String title;
  final String slug;
  final String language;
  final String? cover;
  final String? narratorName;
  final List<AudioChapter> chapters;

  const AudioEdition({
    required this.id,
    required this.bookId,
    required this.title,
    required this.slug,
    required this.language,
    this.cover,
    this.narratorName,
    required this.chapters,
  });

  factory AudioEdition.fromJson(Map<String, dynamic> json) {
    return AudioEdition(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      language: json['language'] as String,
      cover: json['cover'] as String?,
      narratorName: json['narratorName'] as String?,
      chapters: (json['chapters'] as List)
          .map((c) => AudioChapter.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
