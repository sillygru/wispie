import 'dart:io';
import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/indexer_provider.dart';
import '../../providers/settings_provider.dart';
import '../../l10n/l10n.dart';
import '../widgets/indexer_choice_dialog.dart';
import '../components/app_surface.dart';
import '../components/app_screen_header.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class IndexerScreen extends ConsumerStatefulWidget {
  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const IndexerScreen({super.key, this.embedded = false});

  @override
  ConsumerState<IndexerScreen> createState() => _IndexerScreenState();
}

class _IndexerScreenState extends ConsumerState<IndexerScreen> {
  @override
  void initState() {
    super.initState();
    // Load counts when screen initializes
    Future.microtask(() {
      ref.read(indexerProvider.notifier).loadCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final content = WideContentCenter(
      maxWidth: WideLayout.maxNarrowWidth,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s4,
          vertical: 8.0,
        ),
        children: [
          _buildSettingsGroup(
            title: context.l10n.indexerSettingsGroupTitle,
            icon: AppIcons.manageSearch,
            children: [
              SwitchListTile(
                secondary: const AppIcon(AppIcons.copy),
                title: Text(context.l10n.indexerPreventDuplicatesTitle),
                subtitle: Text(
                  context.l10n.indexerPreventDuplicatesSubtitle,
                ),
                value: settings.preventDuplicateTracks,
                onChanged: (val) => notifier.setPreventDuplicateTracks(val),
              ),
              SwitchListTile(
                secondary: const AppIcon(AppIcons.personAdd),
                title: Text(context.l10n.indexerExtractFeaturedTitle),
                subtitle: Text(
                  context.l10n.indexerExtractFeaturedSubtitle,
                ),
                value: settings.extractFeatArtists,
                onChanged: (val) => notifier.setExtractFeatArtists(val),
              ),
            ],
          ),
          _buildSettingsGroup(
            title: context.l10n.indexerDatabaseOpsGroupTitle,
            icon: AppIcons.storage,
            children: [
              _buildOperationTile(
                id: 'optimize_databases',
                icon: AppIcons.storage,
                warningMessage: context.l10n.indexerWarnRestart,
              ),
            ],
          ),
          _buildSettingsGroup(
            title: context.l10n.indexerCoverSearchGroupTitle,
            icon: AppIcons.imageSearch,
            children: [
              _buildOperationTile(
                id: 'repair_library_links',
                icon: AppIcons.linkOff,
                warningMessage: context.l10n.indexerWarnRepairLinks,
              ),
              _buildOperationTile(
                id: 'rebuild_cover_caches',
                icon: AppIcons.image,
              ),
              _buildOperationTile(
                id: 'rebuild_search_indexes',
                icon: AppIcons.search,
                warningMessage: context.l10n.indexerWarnSearchRestart,
              ),
              _buildOperationTile(
                id: 'rebuild_artist_album_art',
                icon: AppIcons.album,
              ),
            ],
          ),
          _buildSettingsGroup(
            title: context.l10n.indexerContentCachesGroupTitle,
            icon: AppIcons.collectionsBookmark,
            children: [
              _buildOperationTile(
                id: 'rebuild_lyrics_cache',
                icon: AppIcons.lyrics,
              ),
              _buildOperationTile(
                id: 'rebuild_waveform_cache',
                icon: AppIcons.graphicEq,
              ),
              _buildOperationTile(
                id: 'rebuild_color_cache',
                icon: AppIcons.palette,
              ),
              _buildOperationTile(
                id: 'rebuild_blurred_cache',
                icon: AppIcons.blur,
              ),
            ],
          ),
          _buildSettingsGroup(
            title: context.l10n.indexerRecommendationsGroupTitle,
            icon: AppIcons.autoAwesome,
            children: [
              _buildOperationTile(
                id: 'rebuild_recommendations',
                icon: AppIcons.autoAwesome,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: context.l10n.indexerTitle),
      body: content,
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
    required AppIconData icon,
  }) {
    final theme = Theme.of(context);
    final List<Widget> childrenWithDividers = [];

    for (int i = 0; i < children.length; i++) {
      childrenWithDividers.add(children[i]);
      if (i < children.length - 1) {
        childrenWithDividers.add(
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0, top: 16.0),
          child: Row(
            children: [
              AppIcon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        AppSurface(
          padding: EdgeInsets.zero,
          clipContent: true,
          child: Column(
            children: childrenWithDividers,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationTile({
    required String id,
    required AppIconData icon,
    String? warningMessage,
  }) {
    final operation = ref.watch(indexerProvider).operations[id];
    if (operation == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bool isRunning = operation.isRunning;
    final bool hasError = operation.state == IndexerOperationState.error;
    final bool isCompleted = operation.state == IndexerOperationState.completed;
    final bool isFullyCached = operation.isFullyCached;
    final l10n = context.l10n;

    String subtitle;
    if (isRunning && operation.hasSplitArtProgress) {
      subtitle = l10n.indexerArtistsAlbumsProgress(
        operation.artistProgressText,
        operation.albumProgressText,
      );
    } else if (isRunning) {
      subtitle = l10n.indexerProcessing(operation.progressText);
    } else if (hasError) {
      subtitle = l10n.songListMergeError(
          operation.errorMessage ?? l10n.indexerUnknownError);
    } else if (isCompleted) {
      if (operation.isDatabaseOperation ||
          operation.isRecommendationOperation) {
        subtitle = l10n.indexerCompleted;
      } else if (operation.failedCount > 0) {
        subtitle = l10n.indexerCachedFailed(
          operation.processedCount,
          operation.totalCount,
          operation.failedCount,
        );
      } else {
        subtitle = l10n.indexerCached(
          operation.processedCount,
          operation.totalCount,
        );
      }
    } else {
      // Not running and not completed
      if (operation.isDatabaseOperation ||
          operation.isRecommendationOperation) {
        subtitle = l10n.indexerReadyToRebuild;
      } else if (operation.processedCount == 0 && operation.totalCount > 0) {
        subtitle = l10n.indexerCached(0, operation.totalCount);
      } else if (operation.failedCount > 0) {
        subtitle = l10n.indexerCachedFailed(
          operation.processedCount,
          operation.totalCount,
          operation.failedCount,
        );
      } else {
        subtitle = l10n.indexerCached(
          operation.processedCount,
          operation.totalCount,
        );
      }
    }

    // Determine icon color
    Color iconColor;
    if (hasError) {
      iconColor = AppTokens.danger;
    } else if (isCompleted) {
      iconColor = theme.colorScheme.primary;
    } else if (isFullyCached) {
      iconColor = theme.colorScheme.primary;
    } else {
      iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return ListTile(
      leading: AppIcon(
        icon,
        color: iconColor,
      ),
      title: Text(
        operation.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(operation.description),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: hasError
                  ? AppTokens.danger
                  : isRunning
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
              fontWeight: isRunning ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          if (isRunning &&
              operation.totalCount > 0 &&
              !operation.hasSplitArtProgress) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: operation.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppTokens.brPill,
            ),
          ],
          if (isRunning && operation.hasSplitArtProgress) ...[
            const SizedBox(height: 8),
            Text(
              l10n.indexerArtistsOnly(operation.artistProgressText),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: operation.artistProgress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppTokens.brPill,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.indexerAlbumsOnly(operation.albumProgressText),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: operation.albumProgress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              borderRadius: AppTokens.brPill,
            ),
          ],
        ],
      ),
      trailing: isRunning
          ? IconButton(
              icon: const AppIcon(AppIcons.stop, color: AppTokens.danger),
              onPressed: () => _cancelOperation(),
            )
          : operation.failedCount > 0 && !isRunning
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.danger,
                        borderRadius: AppTokens.brSm,
                      ),
                      child: Text(
                        '${operation.failedCount}',
                        style: TextStyle(
                          color: AppTokens.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const AppIcon(AppIcons.chevronRight, size: 20),
                  ],
                )
              : const AppIcon(AppIcons.chevronRight, size: 20),
      onTap: isRunning
          ? null
          : () => _handleOperationTap(operation, warningMessage),
    );
  }

  Future<void> _handleOperationTap(
      IndexerOperation operation, String? warningMessage) async {
    // If operation has failed items (regardless of completion state), show choice dialog with failed option
    if (operation.failedCount > 0) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(operation.name),
          content: Text(
              context.l10n.indexerFailedItemsQuestion(operation.failedCount)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'view_fails'),
              child:
                  Text(context.l10n.indexerViewFailed(operation.failedCount)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'retry_failed'),
              child: Text(context.l10n.indexerRetryFailed),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'force'),
              child: Text(context.l10n.indexerForceRebuild),
            ),
          ],
        ),
      );

      if (action == 'view_fails') {
        await _showFailedItemsDialog(operation);
        return;
      } else if (action == 'retry_failed') {
        await _retryFailedItems(operation);
        return;
      } else if (action != 'force') {
        return; // Cancelled
      }

      // User chose force, continue with force=true
      await _startOperation(operation,
          force: true, warningMessage: warningMessage);
      return;
    }

    // If operation is fully cached with no failures, show simple choice
    if (operation.isFullyCached &&
        !operation.isDatabaseOperation &&
        !operation.isRepairOperation) {
      final forceRebuild = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(operation.name),
          content: Text(context.l10n.indexerAlreadyCompleteQuestion(
            operation.processedCount,
            operation.totalCount,
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.indexerForceRebuild),
            ),
          ],
        ),
      );

      if (forceRebuild != true) return;
      await _startOperation(operation,
          force: true, warningMessage: warningMessage);
      return;
    }

    // For database or recommendation operations, just show cancel/do-it dialog
    if (operation.isDatabaseOperation ||
        operation.isRecommendationOperation ||
        operation.isRepairOperation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(operation.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(operation.description),
              if (warningMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  // Warning reads as a tinted block, not an outlined one.
                  decoration: BoxDecoration(
                    color: AppTokens.warning.withValues(alpha: 0.14),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.warning,
                        color: AppTokens.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          warningMessage,
                          style: TextStyle(
                            color: AppTokens.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.indexerDoIt),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      await _startOperation(operation,
          force: operation.isRecommendationOperation,
          warningMessage: warningMessage);
      return;
    }

    // Show normal choice dialog (Just Missing / Force All)
    final force = await showIndexerChoiceDialog(
      context,
      title: operation.name,
      description: operation.description,
      warningMessage: warningMessage,
    );

    if (force == null) return; // Cancelled

    await _startOperation(operation,
        force: force, warningMessage: warningMessage);
  }

  Future<void> _startOperation(IndexerOperation operation,
      {required bool force, String? warningMessage}) async {
    // Show progress dialog for blocking operations
    if (operation.isBlocking) {
      _showBlockingProgressDialog(operation);
    }

    final result = await ref.read(indexerProvider.notifier).startOperation(
          operation.id,
          force: force,
        );

    // Close blocking dialog if shown
    if (operation.isBlocking && mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Show restart dialog if required
    if (result.success && operation.requiresRestart && mounted) {
      await _showRestartDialog();
    }

    // Show warning dialog if there are warnings
    if (result.warnings != null && result.warnings!.isNotEmpty && mounted) {
      await _showWarningsDialog(operation.name, result.warnings!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : AppTokens.danger,
      ),
    );
  }

  void _cancelOperation() {
    ref.read(indexerProvider.notifier).cancelOperation();
  }

  void _showBlockingProgressDialog(IndexerOperation operation) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(operation.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                  context.l10n.indexerOptimizing(operation.name.toLowerCase())),
              const SizedBox(height: 8),
              Text(
                context.l10n.indexerDoNotClose,
                style:
                    const TextStyle(fontSize: 12, color: AppTokens.fgTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRestartDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const AppIcon(AppIcons.refresh, color: AppTokens.info, size: 48),
        title: Text(context.l10n.backupRestartTitle),
        content: Text(context.l10n.indexerRestartRequiredMessage),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _restartApp();
            },
            child: Text(context.l10n.backupRestartNow),
          ),
        ],
      ),
    );
  }

  Future<void> _showFailedItemsDialog(IndexerOperation operation) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const AppIcon(AppIcons.error, color: AppTokens.danger, size: 48),
        title:
            Text(context.l10n.indexerFailedItemsTitle(operation.failedCount)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.indexerCouldNotProcess,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: operation.failedItems.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              operation.failedItems[index],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.actionClose),
          ),
        ],
      ),
    );
  }

  Future<void> _retryFailedItems(IndexerOperation operation) async {
    // For now, just restart the operation with force=false to retry failed items
    // This will re-process all missing items including the failed ones
    final result = await ref
        .read(indexerProvider.notifier)
        .startOperation(operation.id, force: false);

    if (result.warnings != null && result.warnings!.isNotEmpty && mounted) {
      await _showWarningsDialog(operation.name, result.warnings!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : AppTokens.danger,
      ),
    );
  }

  Future<void> _showWarningsDialog(
      String operationName, List<String> warnings) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon:
            const AppIcon(AppIcons.warning, color: AppTokens.warning, size: 48),
        title: Text(context.l10n.indexerWarningsTitle(operationName)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.indexerCouldNotProcess,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: warnings.length.clamp(0, 10),
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              warnings[index],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (warnings.length > 10) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.metaMoreItems(warnings.length - 10),
                  style: TextStyle(
                    color: AppTokens.fgTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.indexerOk),
          ),
        ],
      ),
    );
  }

  Future<void> _restartApp() async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('wispie/app');
        await platform.invokeMethod('restartApp');
      } catch (e) {
        exit(0);
      }
    } else {
      exit(0);
    }
  }
}
