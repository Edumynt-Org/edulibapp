import 'book.dart';

class BookList {
  final String id;
  final String title;
  final String slug;
  final String? listType;
  final String? coverUrl;
  final List<Book> books;

  const BookList({
    required this.id,
    required this.title,
    required this.slug,
    this.listType,
    this.coverUrl,
    required this.books,
  });
}
