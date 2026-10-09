import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/insights_provider.dart';
import '../../components/app_icon.dart';
import '../../components/app_list_row.dart';
import '../../components/app_surface.dart';
import '../../routes/app_page_route.dart';
import '../../screens/stats_screen.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_tokens.dart';
import '../../utils/stats_format.dart';

/// Profile's doorway to the stats screen: one line of the current window's
/// headline figures, so the tab answers "how have I been listening" without
/// having to open anything.
///
/// Shows the same numbers the screen opens on — reading them from the provider
/// rather than recomputing a summary keeps the tab and the screen from ever
/// disagreeing about what "this month" means.
class InsightsSummaryRow extends ConsumerWidget {
  const InsightsSummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = AppTokens.accentOf(context, ref);
    final insights = ref.watch(listeningInsightsProvider);

    final subtitle = switch (insights) {
      AsyncData(value: final data) when !data.isEmpty =>
        '${StatsFormat.duration(data.listened)} · ${data.plays} plays · '
            '${data.activeDays} active ${data.activeDays == 1 ? 'day' : 'days'}',
      AsyncData() => 'Play something to start your history',
      AsyncError() => 'Could not load your stats',
      _ => 'Reading your listening history',
    };

    return AppSurface(
      clipContent: true,
      padding: EdgeInsets.zero,
      child: AppListRow(
        leading: AppRowIcon(icon: AppIcons.analytics, color: accent),
        title: 'Listening',
        subtitle: subtitle,
        trailing: AppIcon(
          AppIcons.chevronRight,
          size: AppTokens.iconSm + AppTokens.s1,
          color: AppTokens.fgTertiary,
        ),
        onTap: () => context.pushApp(const StatsScreen()),
      ),
    );
  }
}
