import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/backup_service.dart';
import '../tokens/app_tokens.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class BackupOptionsDialog extends StatefulWidget {
  final Set<BackupContentType> initialTypes;
  final String? title;
  final String? subtitle;
  final String? buttonLabel;
  final AppIconData buttonIcon;

  const BackupOptionsDialog({
    super.key,
    required this.initialTypes,
    this.title,
    this.subtitle,
    this.buttonLabel,
    this.buttonIcon = AppIcons.cloudUpload,
  });

  @override
  State<BackupOptionsDialog> createState() => _BackupOptionsDialogState();
}

class _BackupOptionsDialogState extends State<BackupOptionsDialog> {
  late final Set<BackupContentType> _selectedTypes =
      Set.of(widget.initialTypes);

  String _getContentTypeName(BackupContentType type) {
    switch (type) {
      case BackupContentType.userStats:
        return context.l10n.backupContentUserStats;
      case BackupContentType.userData:
        return context.l10n.backupContentUserData;
      case BackupContentType.userSettings:
        return context.l10n.backupContentUserSettings;
      case BackupContentType.coverCache:
        return context.l10n.storageCoverCacheTitle;
      case BackupContentType.libraryCache:
        return context.l10n.storageLibraryCacheTitle;
      case BackupContentType.searchIndex:
        return context.l10n.storageSearchIndexTitle;
      case BackupContentType.waveformCache:
        return context.l10n.storageWaveformCacheTitle;
      case BackupContentType.colorCache:
        return context.l10n.storageColorCacheTitle;
      case BackupContentType.lyricsCache:
        return context.l10n.storageLyricsCacheTitle;
      case BackupContentType.artistArtCache:
        return context.l10n.backupContentArtistArtCache;
      case BackupContentType.albumArtCache:
        return context.l10n.backupContentAlbumArtCache;
    }
  }

  String _getContentTypeDescription(BackupContentType type) {
    switch (type) {
      case BackupContentType.userStats:
        return context.l10n.backupContentDescUserStats;
      case BackupContentType.userData:
        return context.l10n.backupContentDescUserData;
      case BackupContentType.userSettings:
        return context.l10n.backupContentDescUserSettings;
      case BackupContentType.coverCache:
        return context.l10n.backupContentDescCoverCache;
      case BackupContentType.libraryCache:
        return context.l10n.backupContentDescLibraryCache;
      case BackupContentType.searchIndex:
        return context.l10n.backupContentDescSearchIndex;
      case BackupContentType.waveformCache:
        return context.l10n.backupContentDescWaveformCache;
      case BackupContentType.colorCache:
        return context.l10n.backupContentDescColorCache;
      case BackupContentType.lyricsCache:
        return context.l10n.backupContentDescLyricsCache;
      case BackupContentType.artistArtCache:
        return context.l10n.backupContentDescArtistArtCache;
      case BackupContentType.albumArtCache:
        return context.l10n.backupContentDescAlbumArtCache;
    }
  }

  AppIconData _getContentTypeIcon(BackupContentType type) {
    switch (type) {
      case BackupContentType.userStats:
        return AppIcons.analytics;
      case BackupContentType.userData:
        return AppIcons.person;
      case BackupContentType.userSettings:
        return AppIcons.settings;
      case BackupContentType.coverCache:
        return AppIcons.album;
      case BackupContentType.libraryCache:
        return AppIcons.library;
      case BackupContentType.searchIndex:
        return AppIcons.search;
      case BackupContentType.waveformCache:
        return AppIcons.waves;
      case BackupContentType.colorCache:
        return AppIcons.palette;
      case BackupContentType.lyricsCache:
        return AppIcons.lyrics;
      case BackupContentType.artistArtCache:
        return AppIcons.person;
      case BackupContentType.albumArtCache:
        return AppIcons.album;
    }
  }

  void _toggleType(BackupContentType type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: AppTokens.brSm,
            ),
            child: AppIcon(widget.buttonIcon,
                color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title ?? l10n.backupCreateAction,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle ?? l10n.backupSelectContentSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: AppTokens.brMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: BackupContentType.values.map((type) {
            final isSelected = _selectedTypes.contains(type);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleType(type),
                borderRadius: AppTokens.brSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.12)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppTokens.brSm,
                        ),
                        child: AppIcon(
                          _getContentTypeIcon(type),
                          size: 17,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getContentTypeName(type),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: isSelected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _getContentTypeDescription(type),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AppIcon(
                        isSelected ? AppIcons.checkCircle : AppIcons.circle,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.surface(2),
                    foregroundColor: AppTokens.fgPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTokens.brSm,
                    ),
                  ),
                  child: Text(l10n.actionCancel),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: _selectedTypes.isEmpty
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            BackupOptions(contentTypes: _selectedTypes),
                          );
                        },
                  icon: AppIcon(widget.buttonIcon, size: 18),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTokens.brSm,
                    ),
                  ),
                  label: Text(widget.buttonLabel ?? l10n.actionCreate),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
