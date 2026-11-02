import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/cache_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../providers/setup_provider.dart';
import '../../services/backup_service.dart';
import '../../services/library_repair_service.dart';
import '../../services/storage_analysis_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

class StorageManagementScreen extends ConsumerStatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  ConsumerState<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _BucketSpec {
  const _BucketSpec(
      this.bucket, this.title, this.subtitle, this.icon, this.color);

  final CacheBucket bucket;
  final String title;
  final String subtitle;
  final AppIconData icon;
  final Color color;
}

class _StorageManagementScreenState
    extends ConsumerState<StorageManagementScreen> {
  bool _isBusy = true;
  int _databaseSize = 0;
  int _backupsSize = 0;
  int _searchIndexSize = 0;
  String _backupsPath = '';
  CacheUsage _usage = CacheUsage.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) setState(() => _isBusy = true);
    try {
      final service = StorageAnalysisService.instance;
      final usage = await service.getCacheUsage(refresh: refresh);
      final database = await service.getDatabaseSize();
      final backups = await service.getBackupsSize();
      final search = await service.getSearchIndexSize();
      final backupsDir = await BackupService.instance.backupsDir;

      if (!mounted) return;
      setState(() {
        _usage = usage;
        _databaseSize = database;
        _backupsSize = backups;
        _searchIndexSize = search;
        _backupsPath = backupsDir.path;
        _isBusy = false;
      });
    } catch (error) {
      debugPrint('Error loading storage sizes: $error');
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _formatSize(AppLocalizations l10n, int bytes) {
    if (bytes < 1024) return l10n.storageSizeBytes('$bytes');
    if (bytes < 1024 * 1024) {
      return l10n.storageSizeKb((bytes / 1024).toStringAsFixed(1));
    }
    if (bytes < 1024 * 1024 * 1024) {
      return l10n.storageSizeMb((bytes / (1024 * 1024)).toStringAsFixed(1));
    }
    return l10n
        .storageSizeGb((bytes / (1024 * 1024 * 1024)).toStringAsFixed(1));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    required Color color,
    bool requireTextInput = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final first = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(action),
          ),
        ],
      ),
    );

    if (first != true) return false;
    if (!requireTextInput) return true;
    if (!mounted) return false;

    final word = l10n.storageDeleteKeyword;
    final controller = TextEditingController();
    final second = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.storageFinalConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.storageConfirmTypePrompt(word),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: word,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text == word) {
                Navigator.pop(dialogContext, true);
              } else {
                appSnack(context, l10n.storageTypeExactly,
                    tone: AppTone.danger);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.storageConfirmUpper),
          ),
        ],
      ),
    );

    return second == true;
  }

  Future<void> _run(Future<void> Function() action, String successMessage,
      {Future<void> Function()? reload}) async {
    if (mounted) setState(() => _isBusy = true);
    try {
      await action();
      await (reload ?? _load)();
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, successMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, '$error', tone: AppTone.danger);
    }
  }

  Future<void> _handleClearDatabase() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageClearDatabaseTitle,
      body: l10n.storageClearDatabaseBody,
      action: l10n.storageClearDatabaseAction,
      color: AppTokens.danger,
      requireTextInput: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await StorageAnalysisService.instance.clearDatabase();
      final storage = ref.read(storageServiceProvider);
      await storage.setSetupComplete(false);
      ref.read(setupProvider.notifier).setComplete(false);
      exit(0);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, l10n.storageClearDatabaseError('$error'),
          tone: AppTone.danger);
    }
  }

  Future<void> _handleRepairLibrary() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageRepairTitle,
      body: l10n.storageRepairBody,
      action: l10n.storageRepair,
      color: AppTokens.success,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final report = await LibraryRepairService.instance.repairLibrary();
      ref.invalidate(songsProvider);
      await _load(refresh: true);
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, report.summary);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, l10n.storageRepairError('$error'),
          tone: AppTone.danger);
    }
  }

  Future<void> _handleCleanUp() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageCleanCacheTitle,
      body: l10n.storageCleanCacheBody,
      action: l10n.storageCleanCacheAction,
      color: AppTokens.success,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final report = await StorageAnalysisService.instance.cleanUp();
      await _load(refresh: true);
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(
        context,
        report.freedAnything
            ? l10n.storageCleanCacheSuccess(
                _formatSize(l10n, report.reclaimedBytes))
            : l10n.storageCleanCacheNothing,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, l10n.storageCleanCacheError('$error'),
          tone: AppTone.danger);
    }
  }

  Future<void> _handleClearWispieCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageClearWispieCacheTitle,
      body: l10n.storageClearWispieCacheBody,
      action: l10n.actionClear,
      color: AppTokens.warning,
    );
    if (!confirmed || !mounted) return;

    await _run(StorageAnalysisService.instance.clearWispieCache,
        l10n.storageClearWispieCacheSuccess,
        reload: () => _load(refresh: true));
  }

  Future<void> _handleClearBucket(_BucketSpec spec) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageClearBucketTitle(spec.title),
      body: l10n.storageClearBucketBody,
      action: l10n.actionClear,
      color: AppTokens.warning,
    );
    if (!confirmed || !mounted) return;

    await _run(
      () => StorageAnalysisService.instance.clearBucket(spec.bucket),
      l10n.storageClearBucketSuccess(spec.title),
      reload: () => _load(refresh: true),
    );
  }

  Future<void> _handleClearSearchIndex() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageClearSearchTitle,
      body: l10n.storageClearSearchBody,
      action: l10n.storageClearSearchAction,
      color: AppTokens.warning,
    );
    if (!confirmed || !mounted) return;

    await _run(StorageAnalysisService.instance.clearSearchIndex,
        l10n.storageClearSearchSuccess);
  }

  Future<void> _handleClearBackups() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageClearBackupsTitle,
      body: l10n.storageClearBackupsBody,
      action: l10n.storageClearBackupsAction,
      color: AppTokens.warning,
    );
    if (!confirmed || !mounted) return;

    await _run(StorageAnalysisService.instance.clearBackups,
        l10n.storageClearBackupsSuccess);
  }

  Future<void> _handleDangerousClear() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.storageClearAllTitle,
      body: l10n.storageClearAllBody,
      action: l10n.storageClearAllAction,
      color: AppTokens.danger,
      requireTextInput: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await StorageAnalysisService.instance.clearAllUserData();
      if (mounted) exit(0);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      appSnack(context, l10n.storageClearAllError('$error'),
          tone: AppTone.danger);
    }
  }

  List<_BucketSpec> _bucketSpecs(AppLocalizations l10n) => [
        _BucketSpec(CacheBucket.covers, l10n.storageCoverCacheTitle,
            l10n.storageCoverCacheSubtitle, AppIcons.image, AppTokens.info),
        _BucketSpec(CacheBucket.remoteArt, l10n.storageRemoteArtTitle,
            l10n.storageRemoteArtSubtitle, AppIcons.image, AppTokens.info),
        _BucketSpec(CacheBucket.blurred, l10n.storageBlurredCacheTitle,
            l10n.storageBlurredCacheSubtitle, AppIcons.blur, AppTokens.info),
        _BucketSpec(
            CacheBucket.notification,
            l10n.storageNotificationCacheTitle,
            l10n.storageNotificationCacheSubtitle,
            AppIcons.image,
            AppTokens.info),
        _BucketSpec(CacheBucket.waveforms, l10n.storageWaveformCacheTitle,
            l10n.storageWaveformCacheSubtitle, AppIcons.waves, AppTokens.info),
        _BucketSpec(
            CacheBucket.beatMaps,
            l10n.storageBeatAnalysisTitle,
            l10n.storageBeatAnalysisSubtitle,
            AppIcons.graphicEq,
            AppTokens.success),
        _BucketSpec(CacheBucket.lyrics, l10n.storageLyricsCacheTitle,
            l10n.storageLyricsCacheSubtitle, AppIcons.lyrics, AppTokens.info),
        _BucketSpec(CacheBucket.palettes, l10n.storageColorCacheTitle,
            l10n.storageColorCacheSubtitle, AppIcons.palette, AppTokens.danger),
        _BucketSpec(
            CacheBucket.youtube,
            l10n.storageYoutubeCacheTitle,
            l10n.storageYoutubeCacheSubtitle,
            AppIcons.cloudUpload,
            AppTokens.warning),
        _BucketSpec(CacheBucket.onlineAudio, l10n.storageOnlineAudioTitle,
            l10n.storageOnlineAudioSubtitle, AppIcons.download, AppTokens.info),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.storageManageTitle),
      body: _isBusy
          ? const Center(child: CircularProgressIndicator())
          : WideContentCenter(
              maxWidth: WideLayout.maxNarrowWidth,
              child: RefreshIndicator(
                onRefresh: () => _load(refresh: true),
                child: ListView(
                  padding: const EdgeInsets.all(AppTokens.s4),
                  children: [
                    _buildRepairCard(),
                    _buildStorageCard(
                      title: l10n.storageDatabaseTitle,
                      subtitle: l10n.storageDatabaseSubtitle,
                      size: _databaseSize,
                      icon: AppIcons.storage,
                      color: AppTokens.info,
                      onClear: _databaseSize > 0 ? _handleClearDatabase : null,
                      clearLabel: l10n.actionClear,
                      isDestructive: true,
                    ),
                    _buildWispieCacheCard(),
                    for (final spec in _bucketSpecs(l10n))
                      _buildBucketCard(spec),
                    _buildStorageCard(
                      title: l10n.storageSearchIndexTitle,
                      subtitle: l10n.storageSearchIndexSubtitle,
                      size: _searchIndexSize,
                      icon: AppIcons.search,
                      color: AppTokens.success,
                      onClear:
                          _searchIndexSize > 0 ? _handleClearSearchIndex : null,
                      clearLabel: l10n.actionClear,
                    ),
                    _buildStorageCard(
                      title: l10n.storageBackupsTitle,
                      subtitle: l10n.storageBackupsSubtitle,
                      size: _backupsSize,
                      icon: AppIcons.cloudUpload,
                      color: AppTokens.warning,
                      onClear: _backupsSize > 0 ? _handleClearBackups : null,
                      clearLabel: l10n.actionClear,
                      footer: _backupsPath.isEmpty
                          ? null
                          : l10n.storageBackupsLocation(_backupsPath),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    ListTile(
                      title: Text(
                        l10n.storageClearAllTile,
                        style: const TextStyle(
                          color: AppTokens.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Text(
                        l10n.storageClearAllTileSubtitle,
                        style: const TextStyle(color: AppTokens.danger),
                      ),
                      leading: const AppIcon(
                        AppIcons.deleteForever,
                        color: AppTokens.danger,
                        size: 32,
                      ),
                      onTap: _handleDangerousClear,
                      tileColor: AppTokens.danger.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTokens.brSm,
                        side: BorderSide(
                          color: AppTokens.danger.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  /// Sits above the clear buttons on purpose: someone whose artwork vanished
  /// after moving devices comes here to clear something, and repairing links is
  /// what they actually want and the non-destructive option.
  Widget _buildRepairCard() {
    final l10n = AppLocalizations.of(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTokens.success.withValues(alpha: 0.1),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: const AppIcon(AppIcons.linkOff,
                      color: AppTokens.success, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.storageRepairCardTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.storageRepairCardBody,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _handleRepairLibrary,
                icon: const AppIcon(AppIcons.refresh),
                label: Text(l10n.storageRepair),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.surface(2),
                  foregroundColor: AppTokens.fgPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWispieCacheCard() {
    final l10n = AppLocalizations.of(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTokens.info.withValues(alpha: 0.1),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: const AppIcon(AppIcons.dataObject,
                      color: AppTokens.info, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.storageWispieCacheTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.storageWispieCacheSubtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatSize(l10n, _usage.totalBytes),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s4),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _handleCleanUp,
                    icon: const AppIcon(AppIcons.autoFix),
                    label: Text(l10n.storageCleanCacheAction),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.surface(2),
                      foregroundColor: AppTokens.fgPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.s3),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _usage.totalBytes > 0 ? _handleClearWispieCache : null,
                    icon: const AppIcon(AppIcons.delete),
                    label: Text(l10n.actionClear),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTokens.surface(2),
                      foregroundColor: AppTokens.fgPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBucketCard(_BucketSpec spec) {
    final l10n = AppLocalizations.of(context);
    final bytes = _usage.bytesOf(spec.bucket);
    return _buildStorageCard(
      title: spec.title,
      subtitle: spec.subtitle,
      size: bytes,
      icon: spec.icon,
      color: spec.color,
      onClear: bytes > 0 ? () => _handleClearBucket(spec) : null,
      clearLabel: l10n.actionClear,
      sizeLabel: bytes == 0 ? l10n.storageCacheEmpty : null,
    );
  }

  Widget _buildStorageCard({
    required String title,
    required String subtitle,
    required int size,
    required AppIconData icon,
    required Color color,
    VoidCallback? onClear,
    required String clearLabel,
    bool isDestructive = false,
    String? footer,
    String? sizeLabel,
  }) {
    final l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: AppIcon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  sizeLabel ?? _formatSize(l10n, size),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: AppTokens.s2),
              Text(
                footer,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            if (onClear != null) ...[
              const SizedBox(height: AppTokens.s4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onClear,
                  icon: const AppIcon(AppIcons.delete),
                  label: Text(clearLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.surface(2),
                    foregroundColor:
                        isDestructive ? AppTokens.danger : AppTokens.fgPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
