import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  static const _frequencyOptions = {
    0: 'Disabled',
    24: 'Every 24 hours',
    48: 'Every 48 hours',
    72: 'Every 3 days',
    168: 'Every 7 days',
  };

  static const _deleteOptions = {
    0: 'Never',
    7: '7 days',
    14: '14 days',
    30: '30 days',
    90: '90 days',
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: 'Backup & Restore',
          icon: AppIcons.cloudUpload,
          children: [
            AppSettingsTile(
              searchId: 'data.export',
              icon: AppIcons.upload,
              title: 'Export App Data',
              subtitle: 'Backup your stats, favorites, and playlists',
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final options = await _showExportOptionsDialog();
                  if (options == null) return;

                  await BackupService.instance.exportUserData(options: options);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              },
            ),
            AppSettingsTile(
              searchId: 'data.import',
              icon: AppIcons.download,
              title: 'Import App Data',
              subtitle: 'Restore data from a backup (replaces all)',
              onTap: () => _handleImport(),
            ),
            AppSettingsTile(
              searchId: 'data.backups',
              icon: AppIcons.cloudUpload,
              title: 'Manage Backups',
              subtitle: 'Create, restore, and manage app backups',
              onTap: () => context.pushApp(const BackupManagementScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: 'Automatic Backups',
          icon: AppIcons.cloudUpload,
          children: [
            _dropdownRow(
              searchId: 'data.auto_backup',
              icon: AppIcons.cloudUpload,
              title: 'Auto Backup',
              subtitle: 'How often a backup is taken',
              value: settings.autoBackupFrequencyHours,
              options: _frequencyOptions,
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
              title: 'Auto-Delete Old Backups',
              subtitle: 'Discard backups older than this',
              value: settings.autoBackupDeleteAfterDays,
              options: _deleteOptions,
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
      appBar: const AppTopBar(title: 'Backup & Restore'),
      body: content,
    );
  }

  Widget _contentTypeRow(BuildContext context, WidgetRef ref) {
    final accent = AppTokens.accentOf(context, ref);

    return AppSettingsAnchor(
      id: 'data.auto_backup_content',
      child: AppListRow(
        dense: true,
        leading: AppRowIcon(icon: AppIcons.tune, color: accent, size: 40),
        title: 'Auto Backup Content',
        subtitle: 'What data is included in automatic backups',
        trailing: AppIcon(AppIcons.chevronRight,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => _configureAutoContent(context),
      ),
    );
  }

  Future<void> _configureAutoContent(BuildContext context) async {
    final storage = StorageService();
    final initialTypes = await storage.loadAutoBackupContentTypes();

    if (!context.mounted) return;

    final options = await showDialog<BackupOptions>(
      context: context,
      builder: (context) => BackupOptionsDialog(
        initialTypes: initialTypes,
        title: 'Auto Backup Content',
        subtitle: 'Select content for automatic backups',
        buttonLabel: 'Save',
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
            title: const Text("Export Options"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select content to export:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  _buildExportCheckbox(
                    title: 'User Stats',
                    subtitle: 'Play counts, sessions, fun stats',
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
                    title: 'User Data',
                    subtitle: 'Favorites, hidden, playlists',
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
                    title: 'User Settings',
                    subtitle: 'Theme, sort order, preferences',
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
                    title: 'Cover Cache',
                    subtitle: 'Album artwork images',
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
                    title: 'Library Cache',
                    subtitle: 'Cached song metadata',
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
                    title: 'Search Index',
                    subtitle: 'Indexed search data',
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
                    title: 'Waveform Cache',
                    subtitle: 'Audio waveform data',
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
                    title: 'Color Cache',
                    subtitle: 'Album color themes',
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
                    title: 'Lyrics Cache',
                    subtitle: 'Stored lyrics data',
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
                child: const Text("CANCEL"),
              ),
              TextButton(
                onPressed: selectedTypes.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context, BackupOptions(contentTypes: selectedTypes)),
                child: const Text("EXPORT"),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Import Data"),
        content: const Text(
          "This will replace ALL existing data with the imported data.\n\n"
          "Your current stats, favorites, playlists, and settings will be overwritten.\n\n"
          "This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("CONTINUE"),
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
        const ImportProgress(progress: 0, label: 'Importing…'),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ImportProgressDialog(
            progress: progress,
            title: 'Importing data',
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
        appSnack(context, "Import successful!");
        ref.invalidate(userDataProvider);
        ref.invalidate(songsProvider);
      }
    } catch (e) {
      await BackupService.instance.discardValidation(validation);
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        appSnack(context, "Import failed: $e");
      }
    }
  }
}
