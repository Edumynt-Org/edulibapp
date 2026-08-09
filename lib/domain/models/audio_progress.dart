class AudioProgress {
  final String? profileId;
  final String bookId;
  final String audioChapterId;
  final int positionSeconds;
  final int durationSeconds;
  final String status;
  final DateTime? completedAt;
  final DateTime lastListenedAt;

  const AudioProgress({
    this.profileId,
    required this.bookId,
    required this.audioChapterId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.status,
    this.completedAt,
    required this.lastListenedAt,
  });

  factory AudioProgress.fromJson(Map<String, dynamic> json) {
    return AudioProgress(
      profileId: json['profileId'] as String?,
      bookId: json['bookId'] as String,
      audioChapterId: json['audioChapterId'] as String,
      positionSeconds: json['positionSeconds'] as int,
      durationSeconds: json['durationSeconds'] as int,
      status: json['status'] as String,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      lastListenedAt: DateTime.parse(json['lastListenedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'bookId': bookId,
    'audioChapterId': audioChapterId,
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
    'status': status,
    'completedAt': completedAt?.toIso8601String(),
    'lastListenedAt': lastListenedAt.toIso8601String(),
  };
}
