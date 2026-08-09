class AudioChapter {
  final String id;
  final String bookId;
  final String title;
  final String slug;
  final String audioFileUrl;
  final int durationSeconds;
  final String? linkedTextChapter;

  AudioChapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.slug,
    required this.audioFileUrl,
    required this.durationSeconds,
    this.linkedTextChapter,
  });

  factory AudioChapter.fromJson(Map<String, dynamic> json) {
    return AudioChapter(
      id: json['id'] as String,
      bookId: json['bookId'] as String? ?? '',
      title: json['title'] as String,
      slug: json['slug'] as String,
      audioFileUrl: json['audioFileUrl'] as String,
      durationSeconds: json['durationSeconds'] as int,
      linkedTextChapter: json['linkedTextChapter'] as String?,
    );
  }
}
