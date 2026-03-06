import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/recommendation_config.dart';
import '../../providers/settings_provider.dart';

class RecommendationSettingsScreen extends ConsumerWidget {
  const RecommendationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final config = settings.recommendationConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Recommendation Types',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enable or disable specific recommendation categories on the home screen.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ...RecommendationType.values.map((type) {
            final enabled = config.isEnabled(type);
            final priority = config.priority(type);
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                RecommendationConfig.typeDisplayName(type),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                RecommendationConfig.typeDescription(type),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: enabled,
                          onChanged: (val) {
                            final updated = Map<RecommendationType, bool>.from(
                                config.enabledTypes);
                            updated[type] = val;
                            ref
                                .read(settingsProvider.notifier)
                                .setRecommendationConfig(
                                    config.copyWith(enabledTypes: updated));
                          },
                        ),
                      ],
                    ),
                    if (enabled) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Priority',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                          Expanded(
                            child: Slider(
                              value: priority.toDouble(),
                              min: 0,
                              max: 3,
                              divisions: 3,
                              label: _priorityLabel(priority),
                              onChanged: (val) {
                                final updated =
                                    Map<RecommendationType, int>.from(
                                        config.priorities);
                                updated[type] = val.round();
                                ref
                                    .read(settingsProvider.notifier)
                                    .setRecommendationConfig(
                                        config.copyWith(priorities: updated));
                              },
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Text(
                              _priorityLabel(priority),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setRecommendationConfig(RecommendationConfig.defaults);
            },
            child: const Text('Reset to Defaults'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _priorityLabel(int value) {
    switch (value) {
      case 0:
        return 'Off';
      case 1:
        return 'Low';
      case 2:
        return 'Med';
      case 3:
        return 'High';
      default:
        return 'Low';
    }
  }
}
