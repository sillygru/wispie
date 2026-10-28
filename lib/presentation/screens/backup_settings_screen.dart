import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/storage_service.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../tokens/app_tokens.dart';
import '../widgets/backup_options_dialog.dart';
import '../../services/backup_service.dart';
import '../../services/import_options.dart';
import '../../presentation/widgets/import_options_dialog.dart';
import '../../presentation/widgets/import_progress_dialog.dart';
import 'backup_management_screen.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../components/app_feedback.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_icons.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const BackupSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  Map<int, String> _frequencyOptions(AppLocalizations l10n) => {
        0: l10n.backupFrequencyDisabled,
        24: l10n.backupFrequencyEvery24Hours,
        48: l10n.backupFrequencyEvery48Hours,
        72: l10n.backupFrequencyEvery3Days,
        168: l10n.backupFrequencyEvery7Days,
      };

  Map<int, String> _deleteOptions(AppLocalizations l10n) => {
        0: l10n.syncNever,
        7: l10n.backupDeleteAfterDays(7),
        14: l10n.backupDeleteAfterDays(14),
        30: l10n.backupDeleteAfterDays(30),
        90: l10n.backupDeleteAfterDays(90),
      };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.settingsPageBackupRestoreTitle,
          icon: AppIcons.cloudUpload,
          children: [
            AppSettingsTile(
              searchId: 'data.export',
              icon: AppIcons.upload,
              title: l10n.backupExportAppData,
              subtitle: l10n.backupExportAppDataSubtitle,
              onTap: () async {
                try {
                  final options = await _showExportOptionsDialog();
                  if (options == null) return;

                  await BackupService.instance.exportUserData(options: options);
                } catch (e) {
                  if (!context.mounted) return;
                  appSnack(context, l10n.backupExportFailed('$e'),
                      tone: AppTone.danger);
                }
              },
            ),
            AppSettingsTile(
              searchId: 'data.import',
              icon: AppIcons.download,
              title: l10n.backupImportAppData,
              subtitle: l10n.backupImportAppDataSubtitle,
              onTap: () => _handleImport(),
            ),
            AppSettingsTile(
              searchId: 'data.backups',
              icon: AppIcons.cloudUpload,
              title: l10n.backupManageBackups,
              subtitle: l10n.backupManageBackupsSubtitle,
              onTap: () => context.pushApp(const BackupManagementScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.backupAutomaticBackups,
          icon: AppIcons.cloudUpload,
          children: [
            _dropdownRow(
              searchId: 'data.auto_backup',
              icon: AppIcons.cloudUpload,
              title: l10n.backupAutoBackup,
              subtitle: l10n.backupAutoBackupSubtitle,
              value: settings.autoBackupFrequencyHours,
              options: _frequencyOptions(l10n),
              onChanged: (val) async {
                await ref
                    .read(settingsProvider.notifier)
                    .setAutoBackupFrequencyHours(val);
                await ref
                    .read(autoBackupProvider.notifier)
                    .setFrequencyHours(val);
              },
            ),
            _contentTypeRow(context, ref),
            _dropdownRow(
              searchId: 'data.auto_delete_backups',
              icon: AppIcons.delete,
              title: l10n.backupAutoDeleteOld,
              subtitle: l10n.backupAutoDeleteOldSubtitle,
              value: settings.autoBackupDeleteAfterDays,
              options: _deleteOptions(l10n),
              onChanged: (val) async {
                await ref
                    .read(settingsProvider.notifier)
                    .setAutoBackupDeleteAfterDays(val);
                await ref
                    .read(autoBackupProvider.notifier)
                    .setDeleteAfterDays(val);
              },
            ),
          ],
        ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageBackupRestoreTitle),
      body: content,
    );
  }

  Widget _contentTypeRow(BuildContext context, WidgetRef ref) {
    final accent = AppTokens.accentOf(context, ref);
    final l10n = AppLocalizations.of(context);

    return AppSettingsAnchor(
      id: 'data.auto_backup_content',
      child: AppListRow(
        dense: true,
        leading: AppRowIcon(icon: AppIcons.tune, color: accent, size: 40),
        title: l10n.backupAutoBackupContent,
        subtitle: l10n.backupAutoBackupContentSubtitle,
        trailing: AppIcon(AppIcons.chevronRight,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => _configureAutoContent(context),
      ),
    );
  }

  Future<void> _configureAutoContent(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final storage = StorageService();
    final initialTypes = await storage.loadAutoBackupContentTypes();

    if (!context.mounted) return;

    final options = await showDialog<BackupOptions>(
      context: context,
      builder: (context) => BackupOptionsDialog(
        initialTypes: initialTypes,
        title: l10n.backupAutoBackupContent,
        subtitle: l10n.backupAutoBackupContentDialogSubtitle,
        buttonLabel: l10n.backupSave,
        buttonIcon: AppIcons.save,
      ),
    );

    if (options != null) {
      await storage.saveAutoBackupContentTypes(options.contentTypes);
    }
  }

  Widget _dropdownRow({
    required String searchId,
    required AppIconData icon,
    required String title,
    required String subtitle,
    required int value,
    required Map<int, String> options,
    required ValueChanged<int> onChanged,
  }) {
    final accent = AppTokens.accentOf(context, ref);

    return AppSettingsAnchor(
      id: searchId,
      child: AppListRow(
        dense: true,
        leading: AppRowIcon(icon: icon, color: accent, size: 40),
        title: title,
        subtitle: subtitle,
        trailing: DropdownButton<int>(
          value: value,
          underline: const SizedBox.shrink(),
          borderRadius: AppTokens.brMd,
          style: AppTokens.rowSubtitle(context).copyWith(color: Colors.white),
          items: options.entries
              .map((entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Future<BackupOptions?> _showExportOptionsDialog() async {
    final l10n = AppLocalizations.of(context);
    final selectedTypes = <BackupContentType>{
      BackupContentType.userStats,
      BackupContentType.userData,
      BackupContentType.userSettings,
    };

    return showDialog<BackupOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.backupExportOptionsTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.backupExportSelectContent,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  _buildExportCheckbox(
                    title: l10n.backupContentUserStats,
                    subtitle: l10n.backupContentUserStatsSubtitle,
                    value: selectedTypes.contains(BackupContentType.userStats),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.userStats);
                        } else {
                          selectedTypes.remove(BackupContentType.userStats);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.backupContentUserData,
                    subtitle: l10n.backupContentUserDataSubtitle,
                    value: selectedTypes.contains(BackupContentType.userData),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.userData);
                        } else {
                          selectedTypes.remove(BackupContentType.userData);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.backupContentUserSettings,
                    subtitle: l10n.backupContentUserSettingsSubtitle,
                    value:
                        selectedTypes.contains(BackupContentType.userSettings),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.userSettings);
                        } else {
                          selectedTypes.remove(BackupContentType.userSettings);
                        }
                      });
                    },
                  ),
                  const Divider(height: 24),
                  _buildExportCheckbox(
                    title: l10n.storageCoverCacheTitle,
                    subtitle: l10n.backupContentCoverCacheSubtitle,
                    value: selectedTypes.contains(BackupContentType.coverCache),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.coverCache);
                        } else {
                          selectedTypes.remove(BackupContentType.coverCache);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.storageLibraryCacheTitle,
                    subtitle: l10n.backupContentLibraryCacheSubtitle,
                    value:
                        selectedTypes.contains(BackupContentType.libraryCache),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.libraryCache);
                        } else {
                          selectedTypes.remove(BackupContentType.libraryCache);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.storageSearchIndexTitle,
                    subtitle: l10n.backupContentSearchIndexSubtitle,
                    value:
                        selectedTypes.contains(BackupContentType.searchIndex),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.searchIndex);
                        } else {
                          selectedTypes.remove(BackupContentType.searchIndex);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.storageWaveformCacheTitle,
                    subtitle: l10n.backupContentWaveformCacheSubtitle,
                    value:
                        selectedTypes.contains(BackupContentType.waveformCache),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.waveformCache);
                        } else {
                          selectedTypes.remove(BackupContentType.waveformCache);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.storageColorCacheTitle,
                    subtitle: l10n.backupContentColorCacheSubtitle,
                    value: selectedTypes.contains(BackupContentType.colorCache),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.colorCache);
                        } else {
                          selectedTypes.remove(BackupContentType.colorCache);
                        }
                      });
                    },
                  ),
                  _buildExportCheckbox(
                    title: l10n.storageLyricsCacheTitle,
                    subtitle: l10n.backupContentLyricsCacheSubtitle,
                    value:
                        selectedTypes.contains(BackupContentType.lyricsCache),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedTypes.add(BackupContentType.lyricsCache);
                        } else {
                          selectedTypes.remove(BackupContentType.lyricsCache);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.backupCancelUpper),
              ),
              TextButton(
                onPressed: selectedTypes.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, BackupOptions(contentTypes: selectedTypes)),
                child: Text(l10n.backupExportUpper),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExportCheckbox({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Future<void> _handleImport() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupImportDataTitle),
        content: Text(l10n.backupImportWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backupCancelUpper),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.backupContinueUpper),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    Map<String, dynamic>? validation;
    try {
      validation = await BackupService.instance.pickAndValidateBackup();

      if (validation == null) return;

      final availableCategories =
          BackupService.instance.getAvailableCategories(validation);

      if (!mounted) {
        await BackupService.instance.discardValidation(validation);
        return;
      }

      final importOptions = await showDialog<ImportOptions>(
        context: context,
        builder: (context) => ImportOptionsDialog(
          availableCategories: availableCategories,
          defaultRestoreDatabases: true,
        ),
      );

      if (importOptions == null) {
        await BackupService.instance.discardValidation(validation);
        return;
      }

      final progress = ValueNotifier<ImportProgress>(
        ImportProgress(progress: 0, label: l10n.backupImportingLabel),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ImportProgressDialog(
            progress: progress,
            title: l10n.backupImportingTitle,
          ),
        );
      }

      await BackupService.instance.performImport(
        validation: validation,
        options: importOptions,
        onProgress: (value, label) =>
            progress.value = ImportProgress(progress: value, label: label),
      );

      if (mounted) {
        Navigator.pop(context);
        appSnack(context, l10n.backupImportSuccess);
        ref.invalidate(userDataProvider);
        ref.invalidate(songsProvider);
      }
    } catch (e) {
      await BackupService.instance.discardValidation(validation);
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        appSnack(context, l10n.backupImportFailed('$e'));
      }
    }
  }
}
