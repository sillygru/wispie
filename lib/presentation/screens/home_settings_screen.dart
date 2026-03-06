import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';

// All known recommendation type IDs and their metadata.
const _kRecommendationTypes = [
  (
    id: 'quick_picks',
    title: 'Quick Picks',
    subtitle: 'Personalized for you right now.',
    icon: Icons.bolt_rounded,
  ),
  (
    id: 'top_hits',
    title: 'Top Hits',
    subtitle: 'Your all-time favorites.',
    icon: Icons.star_rounded,
  ),
  (
    id: 'fresh_finds',
    title: 'Fresh Finds',
    subtitle: 'Newly added to your library.',
    icon: Icons.fiber_new_rounded,
  ),
  (
    id: 'forgotten_favorites',
    title: 'Forgotten Favorites',
    subtitle: 'Songs you haven\'t heard in a while.',
    icon: Icons.history_rounded,
  ),
  (
    id: 'quick_refresh',
    title: 'Quick Refresh',
    subtitle: 'Give these tracks another spin.',
    icon: Icons.refresh_rounded,
  ),
  (
    id: 'artist_mix',
    title: 'Artist Mix',
    subtitle: 'A collection of tracks from your favorite artist.',
    icon: Icons.person_rounded,
  ),
];

class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider);
    final removedIds = userData.removedRecommendations.toSet();
    final pinnedIds = {
      for (final entry in userData.recommendationPreferences.entries)
        if (entry.value.isPinned) entry.key
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Recommendations'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Choose which recommendation sections appear on your home screen. '
              'Pinned sections are shown before unpinned ones in the "For You" feed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final type in _kRecommendationTypes) ...[
            _RecommendationTypeTile(
              id: type.id,
              title: type.title,
              subtitle: type.subtitle,
              icon: type.icon,
              isEnabled: !removedIds.contains(type.id),
              isPinned: pinnedIds.contains(type.id),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RecommendationTypeTile extends ConsumerWidget {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isEnabled;
  final bool isPinned;

  const _RecommendationTypeTile({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isEnabled,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(userDataProvider.notifier);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        children: [
          SwitchListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEnabled
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isEnabled
                    ? null
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: isEnabled ? 1.0 : 0.5),
              ),
            ),
            value: isEnabled,
            onChanged: (value) {
              if (value) {
                notifier.restoreRecommendation(id);
              } else {
                notifier.removeRecommendation(id);
              }
            },
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const SizedBox(width: 38),
                  const SizedBox(width: 16),
                  Icon(
                    isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 16,
                    color: isPinned
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPinned ? 'Pinned to top' : 'Not pinned',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isPinned
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      notifier.pinRecommendation(id, !isPinned);
                    },
                    child: Text(isPinned ? 'Unpin' : 'Pin'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
