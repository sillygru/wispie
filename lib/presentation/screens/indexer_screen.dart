import 'dart:io';
import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
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
          vertical: AppTokens.s2,
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
                id: 'match_song_identity',
                icon: AppIcons.fingerprint,
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
          const SizedBox(height: AppTokens.s6),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTokens.s2,
            bottom: AppTokens.s2,
            top: AppTokens.s4,
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: AppTokens.s2),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
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
          child: Column(children: children),
        ),
      ],
    );
  }

  (String, String) _labels(String id) {
    final l = context.l10n;
    return switch (id) {
      IndexerOps.optimizeDatabases => (
          l.indexerOpOptimizeDatabasesTitle,
          l.indexerOpOptimizeDatabasesDesc
        ),
      IndexerOps.repairLibraryLinks => (
          l.indexerOpRepairLinksTitle,
          l.indexerOpRepairLinksDesc
        ),
      IndexerOps.matchSongIdentity => (
          l.indexerOpMatchIdentityTitle,
          l.indexerOpMatchIdentityDesc
        ),
      IndexerOps.coverCache => (
          l.indexerOpCoverCacheTitle,
          l.indexerOpCoverCacheDesc
        ),
      IndexerOps.searchIndex => (
          l.indexerOpSearchIndexTitle,
          l.indexerOpSearchIndexDesc
        ),
      IndexerOps.lyricsCache => (
          l.indexerOpLyricsCacheTitle,
          l.indexerOpLyricsCacheDesc
        ),
      IndexerOps.waveformCache => (
          l.indexerOpWaveformCacheTitle,
          l.indexerOpWaveformCacheDesc
        ),
      IndexerOps.colorCache => (
          l.indexerOpColorCacheTitle,
          l.indexerOpColorCacheDesc
        ),
      IndexerOps.blurredCache => (
          l.indexerOpBlurredCacheTitle,
          l.indexerOpBlurredCacheDesc
        ),
      IndexerOps.recommendations => (
          l.indexerOpRecommendationsTitle,
          l.indexerOpRecommendationsDesc
        ),
      _ => (l.indexerOpArtistAlbumArtTitle, l.indexerOpArtistAlbumArtDesc),
    };
  }

  String _errorText(String? error) {
    final l = context.l10n;
    return switch (error) {
      'busy' => l.indexerErrorBusy,
      'offline' => l.indexerErrorOffline,
      null => l.indexerUnknownError,
      _ => l.songListMergeError(error),
    };
  }

  String _statusText(IndexerOperation op) {
    final l = context.l10n;
    switch (op.state) {
      case IndexerOperationState.stopping:
        return l.indexerStopping;
      case IndexerOperationState.running:
        if (op.hasSplitArtProgress && op.runTotal > 0) {
          return l.indexerArtistsAlbumsProgress(
            '${op.artistRunDone}/${op.artistRunTotal}',
            '${op.albumRunDone}/${op.albumRunTotal}',
          );
        }
        if (op.runTotal > 0) {
          return op.failedCount > 0
              ? l.indexerProgressFailed(op.runDone, op.runTotal, op.failedCount)
              : l.indexerProcessing('${op.runDone}/${op.runTotal}');
        }
        if (op.runFraction != null) {
          return l.indexerProgressPercent((op.runFraction! * 100).round());
        }
        return l.indexerWorking;
      case IndexerOperationState.error:
        return _errorText(op.errorMessage);
      case IndexerOperationState.cancelled:
        return l.indexerStoppedAt(op.runDone, op.runTotal);
      case IndexerOperationState.idle:
      case IndexerOperationState.completed:
        if (op.isTask) {
          return op.state == IndexerOperationState.completed
              ? l.indexerCompleted
              : l.indexerReadyToRebuild;
        }
        if (!op.countsLoaded) return l.indexerCounting;
        return op.failedCount > 0
            ? l.indexerCachedFailed(op.doneCount, op.totalCount, op.failedCount)
            : l.indexerCached(op.doneCount, op.totalCount);
    }
  }

  Widget _progressBar(double? value) => Padding(
        padding: const EdgeInsets.only(top: AppTokens.s1),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppTokens.brPill,
        ),
      );

  Widget _buildOperationTile({
    required String id,
    required AppIconData icon,
    String? warningMessage,
  }) {
    final operation =
        ref.watch(indexerProvider.select((s) => s.operations[id]));
    if (operation == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    final (name, description) = _labels(id);
    final isRunning = operation.isRunning;
    final hasError = operation.state == IndexerOperationState.error;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );

    final Color iconColor = hasError
        ? AppTokens.danger
        : (isRunning ||
                operation.isFullyCached ||
                operation.state == IndexerOperationState.completed)
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;

    final Widget? trailing;
    if (isRunning) {
      trailing = IconButton(
        tooltip: l10n.indexerStop,
        icon: const AppIcon(AppIcons.stop, color: AppTokens.danger),
        onPressed: operation.state == IndexerOperationState.stopping
            ? null
            : () => ref.read(indexerProvider.notifier).cancelOperation(id),
      );
    } else if (operation.failedCount > 0) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppTokens.danger,
              borderRadius: AppTokens.brSm,
            ),
            child: Text(
              '${operation.failedCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onError,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.s2),
          const AppIcon(AppIcons.chevronRight, size: 20),
        ],
      );
    } else {
      trailing = const AppIcon(AppIcons.chevronRight, size: 20);
    }

    return ListTile(
      leading: AppIcon(icon, color: iconColor),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description),
          const SizedBox(height: 2),
          Text(
            _statusText(operation),
            style: theme.textTheme.bodySmall?.copyWith(
              color: hasError
                  ? AppTokens.danger
                  : isRunning
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
              fontWeight: isRunning ? FontWeight.w500 : null,
            ),
          ),
          if (isRunning && operation.hasSplitArtProgress) ...[
            const SizedBox(height: AppTokens.s2),
            Text(
              l10n.indexerArtistsOnly(
                  '${operation.artistRunDone}/${operation.artistRunTotal}'),
              style: labelStyle,
            ),
            _progressBar(
                operation.runTotal > 0 ? operation.artistProgress : null),
            const SizedBox(height: AppTokens.s2),
            Text(
              l10n.indexerAlbumsOnly(
                  '${operation.albumRunDone}/${operation.albumRunTotal}'),
              style: labelStyle,
            ),
            _progressBar(
                operation.runTotal > 0 ? operation.albumProgress : null),
          ] else if (isRunning) ...[
            const SizedBox(height: AppTokens.s1),
            _progressBar(operation.progress),
          ],
        ],
      ),
      trailing: trailing,
      onTap: isRunning
          ? null
          : () => _handleOperationTap(operation, warningMessage),
    );
  }

  Future<void> _handleOperationTap(
      IndexerOperation operation, String? warningMessage) async {
    final (name, description) = _labels(operation.id);

    if (operation.failedCount > 0) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(name),
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
      } else if (action == 'retry_failed') {
        await _startOperation(operation,
            force: false, onlyItems: operation.failedItems.toSet());
      } else if (action == 'force') {
        await _startOperation(operation, force: true);
      }
      return;
    }

    if (operation.isFullyCached) {
      final forceRebuild = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(name),
          content: Text(context.l10n.indexerAlreadyCompleteQuestion(
            operation.doneCount,
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
      if (forceRebuild == true) await _startOperation(operation, force: true);
      return;
    }

    if (operation.isTask) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description),
              if (warningMessage != null) ...[
                const SizedBox(height: AppTokens.s4),
                Container(
                  padding: const EdgeInsets.all(AppTokens.s3),
                  decoration: BoxDecoration(
                    color: AppTokens.warning.withValues(alpha: 0.14),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: Row(
                    children: [
                      AppIcon(AppIcons.warning,
                          color: AppTokens.warning, size: 20),
                      const SizedBox(width: AppTokens.s2),
                      Expanded(
                        child: Text(
                          warningMessage,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTokens.warning),
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
      if (confirmed == true) await _startOperation(operation, force: true);
      return;
    }

    final force = await showIndexerChoiceDialog(
      context,
      title: name,
      description: description,
      warningMessage: warningMessage,
    );
    if (force == null) return;
    await _startOperation(operation, force: force);
  }

  Future<void> _startOperation(
    IndexerOperation operation, {
    required bool force,
    Set<String>? onlyItems,
  }) async {
    final (name, _) = _labels(operation.id);
    final navigator = Navigator.of(context, rootNavigator: true);
    var dialogOpen = false;
    if (operation.isBlocking) {
      dialogOpen = true;
      _showBlockingProgressDialog(operation.id, name).whenComplete(() {
        dialogOpen = false;
      });
    }

    final result = await ref.read(indexerProvider.notifier).startOperation(
          operation.id,
          force: force,
          onlyItems: onlyItems,
        );

    if (dialogOpen) navigator.pop();
    if (!mounted) return;

    if (result.success && result.requiresRestart) {
      await _showRestartDialog();
      if (!mounted) return;
    }

    final l10n = context.l10n;
    final String message;
    if (result.cancelled) {
      message = l10n.indexerStoppedAt(result.processed, result.total);
    } else if (!result.success) {
      message = _errorText(result.error);
    } else if (operation.isTask) {
      message = l10n.indexerCompleted;
    } else if (result.total == 0) {
      message = l10n.indexerNothingToDo;
    } else {
      message = l10n.indexerFinished(result.processed, result.failed);
    }
    appSnack(
      context,
      message,
      tone:
          result.success || result.cancelled ? AppTone.neutral : AppTone.danger,
    );
  }

  Future<void> _showBlockingProgressDialog(String id, String name) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Consumer(
          builder: (context, ref, _) {
            final op =
                ref.watch(indexerProvider.select((s) => s.operations[id]));
            return AlertDialog(
              title: Text(name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: op?.progress,
                    borderRadius: AppTokens.brPill,
                  ),
                  const SizedBox(height: AppTokens.s4),
                  Text(op == null
                      ? context.l10n.indexerWorking
                      : _statusText(op)),
                  const SizedBox(height: AppTokens.s2),
                  Text(
                    context.l10n.indexerDoNotClose,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTokens.fgTertiary),
                  ),
                ],
              ),
            );
          },
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
