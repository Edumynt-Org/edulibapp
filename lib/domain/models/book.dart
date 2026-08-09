class Book {
  final String id;
  final String title;
  final String slug;
  final String author;
  final String description;
  final String? coverUrl;

  const Book({
    required this.id,
    required this.title,
    required this.slug,
    required this.author,
    required this.description,
    this.coverUrl,
  });
}
