class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String criteriaType;
  final int threshold;
  final String badgeIcon;
  final DateTime? awardedAt;

  AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.criteriaType,
    required this.threshold,
    required this.badgeIcon,
    this.awardedAt,
  });

  bool get isAwarded => awardedAt != null;
}
