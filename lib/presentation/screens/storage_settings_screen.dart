import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_icons.dart';
import 'indexer_screen.dart';
import 'storage_management_screen.dart';

class StorageSettingsScreen extends ConsumerWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const StorageSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = AppSettingsList(
      highlightId: highlightId,
      children: [
        AppSettingsGroup(
          label: 'Disk',
          icon: AppIcons.storage,
          children: [
            AppSettingsTile(
              searchId: 'data.storage',
              icon: AppIcons.storage,
              title: 'Manage Storage',
              subtitle: 'Disk usage and data management',
              onTap: () => context.pushApp(const StorageManagementScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: 'Indexes & Caches',
          icon: AppIcons.dataObject,
          children: [
            AppSettingsTile(
              searchId: 'data.indexer',
              icon: AppIcons.dataObject,
              title: 'Indexer',
              subtitle: 'Rebuild indexes and caches',
              onTap: () => context.pushApp(const IndexerScreen()),
            ),
          ],
        ),
      ],
    );
    if (embedded) return content;
    return AmbientScaffold(
      appBar: const AppTopBar(title: 'Storage'),
      body: content,
    );
  }
}
