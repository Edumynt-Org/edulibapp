class Review {
  final String id;
  final String profileId;
  final String bookId;
  final double rating;
  final String? title;
  final String body;
  final bool containsSpoilers;
  final String status;
  final DateTime dateCreated;
  final DateTime dateUpdated;

  const Review({
    required this.id,
    required this.profileId,
    required this.bookId,
    required this.rating,
    required this.body,
    required this.containsSpoilers,
    required this.status,
    required this.dateCreated,
    required this.dateUpdated,
    this.title,
  });

  factory Review.fromMap(Map<String, dynamic> row) => Review(
    id: row['id'] as String,
    profileId: row['profile'] as String,
    bookId: row['book'] as String,
    rating: (row['rating'] as num).toDouble(),
    title: row['title'] as String?,
    body: row['body'] as String? ?? '',
    containsSpoilers: (row['contains_spoilers'] as num? ?? 0) == 1,
    status: row['status'] as String? ?? 'published',
    dateCreated: DateTime.parse(row['date_created'] as String),
    dateUpdated: DateTime.parse(row['date_updated'] as String),
  );
}

class ReviewDraft {
  final String profileId;
  final String bookId;
  final double rating;
  final String? title;
  final String body;
  final bool containsSpoilers;

  const ReviewDraft({
    required this.profileId,
    required this.bookId,
    required this.rating,
    required this.body,
    required this.containsSpoilers,
    this.title,
  });
}
