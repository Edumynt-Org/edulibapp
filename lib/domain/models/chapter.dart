class Chapter {
  final String id;
  final String title;
  final String slug;
  final String chapterType;
  final bool countsTowardCompletion;
  final String content;
  final String? summary;
  final int sortOrder;

  const Chapter({
    required this.id,
    required this.title,
    required this.slug,
    this.chapterType = 'chapter',
    this.countsTowardCompletion = true,
    this.content = '',
    this.summary,
    this.sortOrder = 0,
  });
}
