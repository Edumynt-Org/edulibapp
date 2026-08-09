class Annotation {
  final String id;
  final String profileId;
  final String chapterId;
  final String annotationType; // 'highlight', 'bookmark', 'note'
  final String? color;
  final String? selectedText;
  final String? noteText;
  final String? startPosition;
  final String? endPosition;
  final DateTime createdAt;

  const Annotation({
    required this.id,
    required this.profileId,
    required this.chapterId,
    required this.annotationType,
    this.color,
    this.selectedText,
    this.noteText,
    this.startPosition,
    this.endPosition,
    required this.createdAt,
  });

  Annotation copyWith({
    String? id,
    String? profileId,
    String? chapterId,
    String? annotationType,
    String? color,
    String? selectedText,
    String? noteText,
    String? startPosition,
    String? endPosition,
    DateTime? createdAt,
  }) {
    return Annotation(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      chapterId: chapterId ?? this.chapterId,
      annotationType: annotationType ?? this.annotationType,
      color: color ?? this.color,
      selectedText: selectedText ?? this.selectedText,
      noteText: noteText ?? this.noteText,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
