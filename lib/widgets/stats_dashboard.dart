import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/stats_service.dart';

/// Dashboard widget displaying user ride statistics
class StatsDashboard extends ConsumerWidget {
  const StatsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return statsAsync.when(
      loading: () => const _LoadingSkeleton(),
      error: (e, _) => _ErrorCard(error: e.toString()),
      data: (stats) => _StatsDashboardContent(stats: stats),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 20,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (_) => _SkeletonBox()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text('Unable to load stats: $error')),
          ],
        ),
      ),
    );
  }
}

class _StatsDashboardContent extends StatefulWidget {
  final UserStats stats;

  const _StatsDashboardContent({required this.stats});

  @override
  State<_StatsDashboardContent> createState() => _StatsDashboardContentState();
}

class _StatsDashboardContentState extends State<_StatsDashboardContent> {
  bool _showWeekly = true;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period Toggle
        Row(
          children: [
            Text(
              'Your Stats',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              isSelected: [_showWeekly, !_showWeekly],
              onPressed: (index) => setState(() => _showWeekly = index == 0),
              constraints: const BoxConstraints(minWidth: 60, minHeight: 32),
              children: const [
                Text('Week', style: TextStyle(fontSize: 12)),
                Text('Month', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Main Stats Grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.teal.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.directions_bike,
                    value: _showWeekly
                        ? '${stats.tripsThisWeek}'
                        : '${stats.tripsThisMonth}',
                    label: 'Rides',
                  ),
                  _StatItem(
                    icon: Icons.map,
                    value: _showWeekly
                        ? '${stats.distanceWeekKm.toStringAsFixed(1)} km'
                        : '${stats.distanceMonthKm.toStringAsFixed(1)} km',
                    label: 'Distance',
                  ),
                  _StatItem(
                    icon: Icons.timer,
                    value: _showWeekly
                        ? _formatDuration(stats.rideTimeWeek)
                        : _formatDuration(stats.rideTimeMonth),
                    label: 'Time',
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.speed,
                    value: _showWeekly
                        ? '${stats.avgSpeedWeek.toStringAsFixed(1)}'
                        : '${stats.avgSpeedMonth.toStringAsFixed(1)}',
                    label: 'Avg km/h',
                  ),
                  _StatItem(
                    icon: Icons.local_fire_department,
                    value: '${stats.streakDays}',
                    label: 'Day Streak',
                    highlight: stats.streakDays > 0,
                  ),
                  _StatItem(
                    icon: Icons.emoji_events,
                    value: '${stats.tripsAllTime}',
                    label: 'All-Time',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Records Section
        if (stats.longestRide != null || stats.fastestRide != null) ...[
          const SizedBox(height: 16),
          Text(
            'Personal Records',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (stats.longestRide != null)
                Expanded(
                  child: _RecordCard(
                    icon: Icons.straighten,
                    title: 'Longest Ride',
                    value:
                        '${(stats.longestRide!.distanceMeters / 1000).toStringAsFixed(1)} km',
                    color: Colors.blue,
                  ),
                ),
              if (stats.longestRide != null && stats.fastestRide != null)
                const SizedBox(width: 12),
              if (stats.fastestRide != null)
                Expanded(
                  child: _RecordCard(
                    icon: Icons.bolt,
                    title: 'Fastest Avg',
                    value: _calculateAvgSpeed(stats.fastestRide!),
                    color: Colors.orange,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  String _calculateAvgSpeed(trip) {
    final duration = trip.endTime.difference(trip.startTime).inSeconds;
    if (duration == 0) return '0 km/h';
    final speed = (trip.distanceMeters / 1000) / (duration / 3600);
    return '${speed.toStringAsFixed(1)} km/h';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: highlight ? Colors.amber : Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _RecordCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
