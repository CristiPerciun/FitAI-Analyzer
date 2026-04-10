import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/ui/dashboard/activity_detail_screen.dart';
import 'package:fitai_analyzer/ui/widgets/compact_activity_card.dart';
import 'package:fitai_analyzer/utils/date_utils.dart' show formatDateForDisplay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivityDayScreen extends ConsumerWidget {
  const ActivityDayScreen({
    super.key,
    required this.dateKey,
  });

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byDate = ref.watch(activitiesByDateProvider);
    final activities = byDate[dateKey] ?? const [];
    final title = formatDateForDisplay(dateKey);

    return Scaffold(
      appBar: AppBar(
        title: Text('Attivita $title'),
      ),
      body: activities.isEmpty
          ? Center(
              child: Text(
                'Nessuna attivita per questa data.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return CompactActivityCard(
                  activity: activity,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActivityDetailScreen(activity: activity),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
