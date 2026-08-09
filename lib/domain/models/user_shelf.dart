class UserShelf {
  final String id;
  final String profileId;
  final String name;
  final String slug;
  final String? description;
  final bool isPrivate;
  final int sortOrder;
  final DateTime dateCreated;
  final DateTime? dateUpdated;

  UserShelf({
    required this.id,
    required this.profileId,
    required this.name,
    required this.slug,
    this.description,
    required this.isPrivate,
    required this.sortOrder,
    required this.dateCreated,
    this.dateUpdated,
  });

  factory UserShelf.fromMap(Map<String, dynamic> map) {
    return UserShelf(
      id: map['id'] as String,
      profileId: map['profile'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      description: map['description'] as String?,
      isPrivate: (map['is_private'] == 1 || map['is_private'] == true),
      sortOrder: map['sort_order'] as int? ?? 0,
      dateCreated: DateTime.parse(map['date_created'] as String),
      dateUpdated: map['date_updated'] != null ? DateTime.parse(map['date_updated'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile': profileId,
      'name': name,
      'slug': slug,
      'description': description,
      'is_private': isPrivate ? 1 : 0,
      'sort_order': sortOrder,
      'date_created': dateCreated.toIso8601String(),
      'date_updated': dateUpdated?.toIso8601String(),
    };
  }
}
