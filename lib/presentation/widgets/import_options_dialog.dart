import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/import_options.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class ImportOptionsDialog extends StatefulWidget {
  final Set<ImportDataCategory> availableCategories;
  final bool defaultRestoreDatabases;

  const ImportOptionsDialog({
    super.key,
    this.availableCategories = const {},
    this.defaultRestoreDatabases = true,
  });

  @override
  State<ImportOptionsDialog> createState() => _ImportOptionsDialogState();
}

class _ImportOptionsDialogState extends State<ImportOptionsDialog> {
  late Set<ImportDataCategory> _selectedCategories;
  late bool _restoreDatabases;

  @override
  void initState() {
    super.initState();
    _selectedCategories = Set.from(widget.availableCategories);
    _restoreDatabases = widget.defaultRestoreDatabases;
  }

  void _toggleCategory(ImportDataCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  void _selectAll(Set<ImportDataCategory> categories) {
    setState(() {
      _selectedCategories.addAll(categories);
    });
  }

  void _deselectAll(Set<ImportDataCategory> categories) {
    setState(() {
      _selectedCategories.removeAll(categories);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final databaseCategories = {
      ImportDataCategory.favorites,
      ImportDataCategory.suggestless,
      ImportDataCategory.hidden,
      ImportDataCategory.playlists,
      ImportDataCategory.mergedGroups,
      ImportDataCategory.recommendations,
      ImportDataCategory.userdata,
      ImportDataCategory.playHistory,
    };
    final databaseCategoriesAvailable =
        databaseCategories.intersection(widget.availableCategories);

    final storageCategories = {
      ImportDataCategory.songs,
      ImportDataCategory.queueHistory,
      ImportDataCategory.shuffleState,
      ImportDataCategory.playbackState,
    };
    final storageCategoriesAvailable =
        storageCategories.intersection(widget.availableCategories);

    final settingsCategories = {
      ImportDataCategory.themeSettings,
      ImportDataCategory.scannerSettings,
      ImportDataCategory.playbackSettings,
      ImportDataCategory.uiSettings,
      ImportDataCategory.backupSettings,
    };
    final settingsCategoriesAvailable =
        settingsCategories.intersection(widget.availableCategories);

    final cacheCategories = {
      ImportDataCategory.coverCache,
      ImportDataCategory.libraryCache,
      ImportDataCategory.searchIndex,
      ImportDataCategory.waveformCache,
      ImportDataCategory.colorCache,
      ImportDataCategory.lyricsCache,
    };
    final cacheCategoriesAvailable =
        cacheCategories.intersection(widget.availableCategories);

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          const AppIcon(AppIcons.restore),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.importSelectTitle)),
          IconButton(
            icon: const AppIcon(AppIcons.close),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (databaseCategoriesAvailable.isNotEmpty)
                _buildCategorySection(
                  context,
                  l10n.importSectionDatabase,
                  databaseCategoriesAvailable,
                  AppIcons.storage,
                ),
              if (storageCategoriesAvailable.isNotEmpty)
                _buildCategorySection(
                  context,
                  l10n.importSectionStorage,
                  storageCategoriesAvailable,
                  AppIcons.folder,
                ),
              if (settingsCategoriesAvailable.isNotEmpty)
                _buildCategorySection(
                  context,
                  l10n.importSectionSettings,
                  settingsCategoriesAvailable,
                  AppIcons.settings,
                ),
              if (cacheCategoriesAvailable.isNotEmpty)
                _buildCategorySection(
                  context,
                  l10n.importSectionCache,
                  cacheCategoriesAvailable,
                  AppIcons.folderZip,
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.importOptionsTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: Text(l10n.importReplaceDatabases),
                      subtitle: Text(l10n.importReplaceDatabasesSubtitle),
                      value: _restoreDatabases,
                      onChanged: (value) {
                        setState(() {
                          _restoreDatabases = value ?? true;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _selectedCategories.isEmpty
              ? null
              : () {
                  final options = ImportOptions(
                    categories: _selectedCategories,
                    additive: false,
                    restoreDatabases: _restoreDatabases,
                  );
                  Navigator.of(context).pop(options);
                },
          child: Text(l10n.importRestoreAction),
        ),
      ],
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    Set<ImportDataCategory> availableCategories,
    AppIconData icon,
  ) {
    if (availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              AppIcon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _selectAll(availableCategories),
                child: Text(context.l10n.importSelectAll),
              ),
              TextButton(
                onPressed: () => _deselectAll(availableCategories),
                child: Text(context.l10n.importSelectNone),
              ),
            ],
          ),
        ),
        ...availableCategories.map((category) {
          return CheckboxListTile(
            title: Text(category.displayName),
            subtitle: Text(category.description),
            value: _selectedCategories.contains(category),
            onChanged: (_) => _toggleCategory(category),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
        const Divider(),
      ],
    );
  }
}
