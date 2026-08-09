import 'book.dart';

class UserShelfItem {
  final String id;
  final String shelfId;
  final String bookId;
  final int sortOrder;
  final DateTime dateAdded;
  final Book? book;

  UserShelfItem({
    required this.id,
    required this.shelfId,
    required this.bookId,
    required this.sortOrder,
    required this.dateAdded,
    this.book,
  });

  factory UserShelfItem.fromMap(Map<String, dynamic> map, {Book? book}) {
    return UserShelfItem(
      id: map['id'] as String,
      shelfId: map['shelf'] as String,
      bookId: map['book'] as String,
      sortOrder: map['sort_order'] as int? ?? 0,
      dateAdded: DateTime.parse(map['date_added'] as String),
      book: book,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shelf': shelfId,
      'book': bookId,
      'sort_order': sortOrder,
      'date_added': dateAdded.toIso8601String(),
    };
  }
}
