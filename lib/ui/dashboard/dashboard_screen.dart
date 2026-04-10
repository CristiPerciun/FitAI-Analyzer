import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart' show refreshGarminSync;
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart'
    show GarminSyncState, garminSyncNotifierProvider;
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/dashboard/dashboard_suggestions_tab.dart';
import 'package:fitai_analyzer/ui/dashboard/widgets/activity_burn_bar_chart_card.dart';
import 'package:fitai_analyzer/ui/dashboard/widgets/activity_calendar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authNotifierProvider).user?.uid;
    final isGarminSyncing = ref.watch(
      garminSyncNotifierProvider.select((s) => s.isSyncing),
    );

    ref.listen(activitiesStreamProvider, (prev, next) {
      next.whenOrNull(
        error: (e, _) {
          if (context.mounted) showErrorDialog(context, e.toString());
        },
      );
    });

    ref.listen<GarminSyncState>(
      garminSyncNotifierProvider,
      (prev, next) {
        if (!context.mounted) return;
        final prevErr = prev?.error;
        final nextErr = next.error;
        if (nextErr != null && nextErr != prevErr) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync Garmin non riuscita: $nextErr'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (prev != null &&
            prev.isSyncing &&
            !next.isSyncing &&
            next.error == null &&
            (next.trigger == 'dashboard_pull_to_refresh' ||
                next.trigger == 'allenamenti_pull_to_refresh')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dati Garmin aggiornati'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );

    return Scaffold(
          appBar: AppBar(
        title: const Text('Allenamenti'),
        bottom: TabBar(
          controller: _tabController,
          // 1. Disabilita lo scroll (questo permette ai tab di espandersi)
          isScrollable: false, 
          
          // 2. Rimuovi o imposta TabAlignment.fill (default se isScrollable è false)
          tabAlignment: TabAlignment.fill, 
          
          tabs: const [
            Tab(text: 'Suggerimenti e oggi'),
            Tab(text: 'Attività e progressi'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isGarminSyncing) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. PRIMO TAB: Corrisponde a 'Suggerimenti e oggi'
                  const DashboardSuggestionsTab(),

                  // 2. SECONDO TAB: Corrisponde a 'Attività e progressi'
                  _buildProgressiTab(uid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressiTab(String? uid) {
    return RefreshIndicator(
      onRefresh: () => _onRefreshGarmin(uid),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ActivityCalendarCard(),
                  const SizedBox(height: 12),
                  const ActivityBurnBarChartCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefreshGarmin(String? uid) async {
    await refreshGarminSync(ref, uid, trigger: 'dashboard_pull_to_refresh');
  }
}
