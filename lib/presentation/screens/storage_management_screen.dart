import 'dart:io' show exit;
import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../services/library_repair_service.dart';
import '../../services/storage_analysis_service.dart';
import '../../providers/setup_provider.dart';
import '../../providers/providers.dart';
import '../components/app_surface.dart';
import '../components/app_screen_header.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class StorageManagementScreen extends ConsumerStatefulWidget {
  const StorageManagementScreen({super.key});

  @override
  ConsumerState<StorageManagementScreen> createState() =>
      _StorageManagementScreenState();
}

class _StorageManagementScreenState
    extends ConsumerState<StorageManagementScreen> {
  bool _isLoading = true;
  int _databaseSize = 0;
  int _coversSize = 0;
  int _backupsSize = 0;
  int _libraryCacheSize = 0;
  int _searchIndexSize = 0;
  int _waveformCacheSize = 0;
  int _beatMapCacheSize = 0;
  int _colorCacheSize = 0;
  int _lyricsCacheSize = 0;
  int _blurredCacheSize = 0;
  int _onlineAudioCacheSize = 0;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final dbSize = await StorageAnalysisService.instance.getDatabaseSize();
      final coversSize =
          await StorageAnalysisService.instance.getCoversCacheSize();
      final backupsSize =
          await StorageAnalysisService.instance.getBackupsSize();
      final libSize =
          await StorageAnalysisService.instance.getLibraryCacheSize();
      final searchSize =
          await StorageAnalysisService.instance.getSearchIndexSize();
      final waveformSize =
          await StorageAnalysisService.instance.getWaveformCacheSize();
      final beatMapSize =
          await StorageAnalysisService.instance.getBeatMapCacheSize();
      final colorSize =
          await StorageAnalysisService.instance.getColorCacheSize();
      final lyricsSize =
          await StorageAnalysisService.instance.getLyricsCacheSize();
      final blurredSize =
          await StorageAnalysisService.instance.getBlurredCacheSize();
      final onlineAudioSize =
          await StorageAnalysisService.instance.getOnlineAudioCacheSize();

      if (mounted) {
        setState(() {
          _databaseSize = dbSize;
          _coversSize = coversSize;
          _backupsSize = backupsSize;
          _libraryCacheSize = libSize;
          _searchIndexSize = searchSize;
          _waveformCacheSize = waveformSize;
          _beatMapCacheSize = beatMapSize;
          _colorCacheSize = colorSize;
          _lyricsCacheSize = lyricsSize;
          _blurredCacheSize = blurredSize;
          _onlineAudioCacheSize = onlineAudioSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading storage sizes: $e');
      if (mounted) setState(() => _isLoading = false);
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

  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    bool requireTextInput = false,
    String? textInputHint,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    if (confirm1 != true) return false;
    if (!requireTextInput) return true;
    if (!mounted) return false;

    // Second confirmation with text input
    final word = textInputHint ?? l10n.storageDeleteKeyword;
    final controller = TextEditingController();
    final confirm2 = await showDialog<bool>(
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
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.storageConfirmUpper),
          ),
        ],
      ),
    );

    return confirm2 == true;
  }

  Future<void> _handleClearDatabase() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearDatabaseTitle,
      content: l10n.storageClearDatabaseBody,
      confirmText: l10n.storageClearDatabaseAction,
      confirmColor: AppTokens.danger,
      requireTextInput: true,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearDatabase();
      if (mounted) {
        final storage = ref.read(storageServiceProvider);
        await storage.setSetupComplete(false);
        ref.read(setupProvider.notifier).setComplete(false);
        exit(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearDatabaseError('$e'));
      }
    }
  }

  Future<void> _handleRepairLibrary() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageRepairTitle,
      content: l10n.storageRepairBody,
      confirmText: l10n.storageRepair,
      confirmColor: AppTokens.success,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isClearing = true);

    try {
      final report = await LibraryRepairService.instance.repairLibrary();
      ref.invalidate(songsProvider);
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, report.summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageRepairError('$e'));
      }
    }
  }

  Future<void> _handleClearCovers() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearCoversTitle,
      content: l10n.storageClearCoversBody,
      confirmText: l10n.storageClearCoversAction,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearCoversCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearCoversSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearCoversError('$e'));
      }
    }
  }

  Future<void> _handleClearBackups() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearBackupsTitle,
      content: l10n.storageClearBackupsBody,
      confirmText: l10n.storageClearBackupsAction,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearBackups();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearBackupsSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearBackupsError('$e'));
      }
    }
  }

  Future<void> _handleClearLibraryCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearLibraryTitle,
      content: l10n.storageClearLibraryBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearLibraryCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearLibrarySuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearLibraryError('$e'));
      }
    }
  }

  Future<void> _handleClearSearchIndex() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearSearchTitle,
      content: l10n.storageClearSearchBody,
      confirmText: l10n.storageClearSearchAction,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearSearchIndex();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearSearchSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearSearchError('$e'));
      }
    }
  }

  Future<void> _handleClearWaveformCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearWaveformTitle,
      content: l10n.storageClearWaveformBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearWaveformCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearWaveformSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearWaveformError('$e'));
      }
    }
  }

  Future<void> _handleClearBeatMapCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearBeatTitle,
      content: l10n.storageClearBeatBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearBeatMapCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearBeatSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearBeatError('$e'));
      }
    }
  }

  Future<void> _handleClearColorCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearColorTitle,
      content: l10n.storageClearColorBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearColorCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearColorSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearColorError('$e'));
      }
    }
  }

  Future<void> _handleClearLyricsCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearLyricsTitle,
      content: l10n.storageClearLyricsBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearLyricsCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearLyricsSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearLyricsError('$e'));
      }
    }
  }

  Future<void> _handleClearBlurredCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearBlurredTitle,
      content: l10n.storageClearBlurredBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearBlurredCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearBlurredSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearBlurredError('$e'));
      }
    }
  }

  Future<void> _handleClearOnlineAudioCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearOnlineAudioTitle,
      content: l10n.storageClearOnlineAudioBody,
      confirmText: l10n.storageClearCache,
      confirmColor: AppTokens.warning,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isClearing = true);

    try {
      await StorageAnalysisService.instance.clearOnlineAudioCache();
      await _loadSizes();
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearOnlineAudioSuccess);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearOnlineAudioError('$e'));
      }
    }
  }

  Future<void> _handleDangerousClear() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirmationDialog(
      title: l10n.storageClearAllTitle,
      content: l10n.storageClearAllBody,
      confirmText: l10n.storageClearAllAction,
      confirmColor: AppTokens.danger,
      requireTextInput: true,
    );

    if (!confirmed || !mounted) return;

    if (mounted) {
      setState(() => _isClearing = true);
    }

    try {
      await StorageAnalysisService.instance.clearAllUserData();
      if (mounted) exit(0);
    } catch (e) {
      if (mounted) {
        setState(() => _isClearing = false);
        appSnack(context, l10n.storageClearAllError('$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.storageManageTitle),
      body: _isLoading || _isClearing
          ? const Center(child: CircularProgressIndicator())
          : WideContentCenter(
              maxWidth: WideLayout.maxNarrowWidth,
              child: RefreshIndicator(
                onRefresh: _loadSizes,
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
                      isDestructive: true,
                    ),
                    _buildStorageCard(
                      title: l10n.storageCoverCacheTitle,
                      subtitle: l10n.storageCoverCacheSubtitle,
                      size: _coversSize,
                      icon: AppIcons.image,
                      color: AppTokens.info,
                      onClear: _coversSize > 0 ? _handleClearCovers : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageBackupsTitle,
                      subtitle: l10n.storageBackupsSubtitle,
                      size: _backupsSize,
                      icon: AppIcons.cloudUpload,
                      color: AppTokens.warning,
                      onClear: _backupsSize > 0 ? _handleClearBackups : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageLibraryCacheTitle,
                      subtitle: l10n.storageLibraryCacheSubtitle,
                      size: _libraryCacheSize,
                      icon: AppIcons.library,
                      color: AppTokens.success,
                      onClear: _libraryCacheSize > 0
                          ? _handleClearLibraryCache
                          : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageSearchIndexTitle,
                      subtitle: l10n.storageSearchIndexSubtitle,
                      size: _searchIndexSize,
                      icon: AppIcons.search,
                      color: AppTokens.success,
                      onClear:
                          _searchIndexSize > 0 ? _handleClearSearchIndex : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageWaveformCacheTitle,
                      subtitle: l10n.storageWaveformCacheSubtitle,
                      size: _waveformCacheSize,
                      icon: AppIcons.waves,
                      color: AppTokens.info,
                      onClear: _waveformCacheSize > 0
                          ? _handleClearWaveformCache
                          : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageBeatAnalysisTitle,
                      subtitle: l10n.storageBeatAnalysisSubtitle,
                      size: _beatMapCacheSize,
                      icon: AppIcons.graphicEq,
                      color: AppTokens.success,
                      onClear: _beatMapCacheSize > 0
                          ? _handleClearBeatMapCache
                          : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageColorCacheTitle,
                      subtitle: l10n.storageColorCacheSubtitle,
                      size: _colorCacheSize,
                      icon: AppIcons.palette,
                      color: AppTokens.danger,
                      onClear:
                          _colorCacheSize > 0 ? _handleClearColorCache : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageLyricsCacheTitle,
                      subtitle: l10n.storageLyricsCacheSubtitle,
                      size: _lyricsCacheSize,
                      icon: AppIcons.lyrics,
                      color: AppTokens.info,
                      onClear:
                          _lyricsCacheSize > 0 ? _handleClearLyricsCache : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageOnlineAudioTitle,
                      subtitle: l10n.storageOnlineAudioSubtitle,
                      size: _onlineAudioCacheSize,
                      icon: AppIcons.download,
                      color: AppTokens.info,
                      onClear: _onlineAudioCacheSize > 0
                          ? _handleClearOnlineAudioCache
                          : null,
                    ),
                    _buildStorageCard(
                      title: l10n.storageBlurredCacheTitle,
                      subtitle: l10n.storageBlurredCacheSubtitle,
                      size: _blurredCacheSize,
                      icon: AppIcons.blur,
                      color: AppTokens.info,
                      onClear: _blurredCacheSize > 0
                          ? _handleClearBlurredCache
                          : null,
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
  /// after moving devices comes here to clear something, and repairing the
  /// links is both what they actually want and the non-destructive option.
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

  Widget _buildStorageCard({
    required String title,
    required String subtitle,
    required int size,
    required AppIconData icon,
    required Color color,
    VoidCallback? onClear,
    bool isDestructive = false,
  }) {
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _formatSize(l10n, size),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (onClear != null) ...[
              const SizedBox(height: AppTokens.s4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onClear,
                  icon: const AppIcon(AppIcons.delete),
                  label: Text(l10n.actionClear),
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
