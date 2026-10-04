import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/insights_provider.dart';
import '../../components/app_chip.dart';
import '../../../domain/models/listening_insights.dart';
import '../../tokens/app_tokens.dart';

/// The window selector.
///
/// Chips rather than a segmented control: the windows are a filter over one
/// dataset, not tabs over sibling panels, and a chip row stays legible when
/// there are five of them.
class StatsRangeBar extends ConsumerWidget {
  const StatsRangeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statsRangeProvider);
    final accent = AppTokens.accentOf(context, ref);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: StatsRange.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.s2),
        itemBuilder: (context, index) {
          final range = StatsRange.values[index];
          return AppChip(
            label: range.label,
            selected: range == selected,
            accent: accent,
            onTap: () => ref.read(statsRangeProvider.notifier).select(range),
          );
        },
      ),
    );
  }
}
