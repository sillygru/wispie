import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final content = AppSettingsList(
      highlightId: highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.storageSettingsDiskGroup,
          icon: AppIcons.storage,
          children: [
            AppSettingsTile(
              searchId: 'data.storage',
              icon: AppIcons.storage,
              title: l10n.storageManageTitle,
              subtitle: l10n.settingsSearchManageStorageSubtitle,
              onTap: () => context.pushApp(const StorageManagementScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.storageSettingsIndexesGroup,
          icon: AppIcons.dataObject,
          children: [
            AppSettingsTile(
              searchId: 'data.indexer',
              icon: AppIcons.dataObject,
              title: l10n.indexerTitle,
              subtitle: l10n.settingsSearchIndexerSubtitle,
              onTap: () => context.pushApp(const IndexerScreen()),
            ),
          ],
        ),
      ],
    );
    if (embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageStorageTitle),
      body: content,
    );
  }
}
