class MonthlyStat {
  final int month; // 1-12
  final int year;
  final int value; // could be pages or hours

  MonthlyStat({required this.month, required this.year, required this.value});
}

class MilestoneStats {
  final int totalBooksFinished;
  final int totalPagesRead;
  final int totalHoursListened;
  final List<MonthlyStat> monthlyPages;
  final List<MonthlyStat> monthlyHours;

  MilestoneStats({
    required this.totalBooksFinished,
    required this.totalPagesRead,
    required this.totalHoursListened,
    required this.monthlyPages,
    required this.monthlyHours,
  });

  factory MilestoneStats.empty() {
    return MilestoneStats(
      totalBooksFinished: 0,
      totalPagesRead: 0,
      totalHoursListened: 0,
      monthlyPages: [],
      monthlyHours: [],
    );
  }
}
