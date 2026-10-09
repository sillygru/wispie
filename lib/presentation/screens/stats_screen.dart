import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/insights_provider.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
import '../components/app_screen_header.dart';
import '../components/app_section_header.dart';
import '../../domain/models/listening_insights.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import '../widgets/stats/overview_section.dart';
import '../widgets/stats/rhythm_section.dart';
import '../widgets/stats/stats_range_bar.dart';
import '../widgets/stats/taste_section.dart';
import '../widgets/stats/top_lists_section.dart';
import '../widgets/stats/trend_section.dart';

/// Everything the app knows about how you listen.
///
/// Reachable from Profile and the drawer. It is a pushed screen rather than a
/// tab because it is a place you visit deliberately, not one you pass through
/// on the way somewhere else — and because the profile tab has its own job.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = AppTokens.accentOf(context, ref);
    final insights = ref.watch(listeningInsightsProvider);
    // Refreshing keeps the previous value; only a first load should swap the
    // list out, otherwise the scroll position is lost on every refresh.
    final data = insights.value;

    return AmbientScaffold(
      appBar: AppTopBar(title: 'Listening'),
      body: RefreshIndicator(
        // The play log is appended by the player, so a refresh is the only way
        // to pick up a session that ended after the screen was built.
        onRefresh: () => ref.refresh(listeningInsightsProvider.future),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // SliverFillRemaining keeps the view scrollable — and so
            // refreshable — while a single message fills it, which is what
            // makes pull-to-refresh work before the data arrives.
            switch (insights) {
              AsyncError(:final error) when data == null => SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: AppIcons.error,
                    title: "Couldn't load your stats",
                    message: '$error',
                    tone: AppTone.danger,
                    actionLabel: 'Try Again',
                    onAction: () => ref.invalidate(listeningInsightsProvider),
                  ),
                ),
              _ when data == null => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppLoading(message: 'Reading your listening history'),
                ),
              _ when data.isEmpty => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: AppIcons.analytics,
                    title: 'No listening history yet',
                    message: 'Play something and your listening habits will '
                        'show up here.',
                  ),
                ),
              _ => SliverToBoxAdapter(
                  child: _StatsBody(insights: data, accent: accent),
                ),
            },
            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final ListeningInsights insights;
  final Color accent;

  const _StatsBody({required this.insights, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (WideLayout.isWide(context)) return _buildWide(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Gutter(child: StatsRangeBar()),
        _Gutter(child: OverviewSection(insights: insights, accent: accent)),
        const _Section(label: 'Over time'),
        _Gutter(child: TrendSection(insights: insights, accent: accent)),
        const _Section(label: 'When you listen'),
        _Gutter(child: RhythmSection(insights: insights, accent: accent)),
        const _Section(label: 'Your top'),
        _Gutter(child: TopListsSection(insights: insights, accent: accent)),
        const _Section(label: 'Taste'),
        _Gutter(child: TasteSection(insights: insights, accent: accent)),
      ],
    );
  }

  /// Wide windows get two columns: the numbers and the timeline on the left,
  /// the rhythm and the leaderboards on the right. Reading order is preserved
  /// (left column top to bottom, then right), so nothing that belongs together
  /// ends up in different halves.
  Widget _buildWide(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Gutter(child: StatsRangeBar()),
        const SizedBox(height: AppTokens.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OverviewSection(insights: insights, accent: accent),
                  const _Section(label: 'Over time'),
                  TrendSection(insights: insights, accent: accent),
                  const _Section(label: 'Taste'),
                  TasteSection(insights: insights, accent: accent),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.s5),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Section(label: 'When you listen'),
                  RhythmSection(insights: insights, accent: accent),
                  const _Section(label: 'Your top'),
                  TopListsSection(insights: insights, accent: accent),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Side padding shared by every block, so the sections line up with each other
/// and with the range chips above them.
class _Gutter extends StatelessWidget {
  final Widget child;

  const _Gutter({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: WideLayoutGutter.of(context)),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  final String label;

  const _Section({required this.label});

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(
      label: label,
      padding: EdgeInsets.fromLTRB(
        WideLayoutGutter.of(context),
        AppTokens.s5,
        WideLayoutGutter.of(context),
        AppTokens.s2,
      ),
    );
  }
}
