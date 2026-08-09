import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/models/milestone_stats.dart';
import '../../domain/models/achievement_badge.dart';

class MilestonesTab extends StatefulWidget {
  final String profileId;
  const MilestonesTab({super.key, required this.profileId});

  @override
  State<MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends State<MilestonesTab> {
  MilestoneStats? _stats;
  List<AchievementBadge>? _badges;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = context.read<ILibraryRepository>();
    try {
      final stats = await repo.getMilestoneStats(widget.profileId);
      final badges = await repo.getAchievementBadges(widget.profileId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _badges = badges;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return const Center(child: Text('Failed to load milestones'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overall Progress', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Finished', '\${_stats!.totalBooksFinished}', 'Books', Colors.blue),
              _buildStatCard('Read', '\${_stats!.totalPagesRead}', 'Pages', Colors.green),
              _buildStatCard('Listened', '\${_stats!.totalHoursListened}', 'Hours', Colors.orange),
            ],
          ),
          const SizedBox(height: 32),
          Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _buildBadgesGrid(),
          const SizedBox(height: 32),
          Text('Reading Activity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, MaterialColor color) {
    return Card(
      elevation: 2,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.shade700)),
            Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesGrid() {
    if (_badges == null || _badges!.isEmpty) {
      return const Text('No badges earned yet.');
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _badges!.length,
      itemBuilder: (context, index) {
        final badge = _badges![index];
        final isAwarded = badge.isAwarded;
        return Opacity(
          opacity: isAwarded ? 1.0 : 0.4,
          child: Tooltip(
            message: '\${badge.name}\\n\${badge.description}',
            child: Container(
              decoration: BoxDecoration(
                color: isAwarded ? Colors.amber.shade100 : Colors.grey.shade200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAwarded ? Colors.amber.shade700 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(badge.badgeIcon, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  Text(
                    badge.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isAwarded ? Colors.amber.shade900 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChart() {
    // A placeholder chart if monthly pages is empty
    final points = _stats!.monthlyPages.isEmpty 
        ? [const FlSpot(1, 10), const FlSpot(2, 30), const FlSpot(3, 20), const FlSpot(4, 50), const FlSpot(5, 40)]
        : _stats!.monthlyPages.map((m) => FlSpot(m.month.toDouble(), m.value.toDouble())).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text('M\${value.toInt()}'),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: points.map((spot) => BarChartGroupData(
          x: spot.x.toInt(),
          barRods: [
            BarChartRodData(
              toY: spot.y,
              color: Colors.blue.shade400,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        )).toList(),
      ),
    );
  }
}
