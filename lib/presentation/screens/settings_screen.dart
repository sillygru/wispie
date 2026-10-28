import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../components/app_feedback.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../components/app_surface.dart';
import '../components/app_icon.dart';
import '../motion/motion.dart';
import '../tokens/app_tokens.dart';
import '../../domain/services/settings_search_service.dart';
import 'settings_registry.dart';
import '../routes/app_page_route.dart';
import 'batch_replace_screen.dart';
import 'bulk_rename_screen.dart';
import 'folder_management_screen.dart';
import '../../providers/providers.dart';
import 'playback_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'backup_settings_screen.dart';
import 'about_settings_screen.dart';
import 'home_settings_screen.dart';
import 'lyrics_settings_screen.dart';
import 'online_settings_screen.dart';
import 'storage_settings_screen.dart';
import 'sync_settings_screen.dart';
import '../tokens/app_icons.dart';
import '../utils/wide_layout.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _search = SettingsSearchService();

  final TextEditingController _controller = TextEditingController();
  String _query = '';

  /// Wide-only master-detail selection. Narrow windows keep the push stack.
  int _selected = 0;
  String? _detailHighlight;

  static const _pages = [
    _Page(AppIcons.library, 'Library', 'Folders, filters, scanning'),
    _Page(AppIcons.playCircle, 'Playback', 'Transitions, fades, audio'),
    _Page(AppIcons.subtitles, 'Lyrics', 'Word sync, translation, sidebar'),
    _Page(AppIcons.palette, 'Appearance', 'Now playing, motion, app icon'),
    _Page(AppIcons.home, 'Home & Navigation',
        'Home sections, lists, quick actions'),
    _Page(AppIcons.musicNote, 'Online', 'YouTube catalogue and account'),
    _Page(AppIcons.cloudUpload, 'Sync', 'Encrypted cross-device sync'),
    _Page(AppIcons.upload, 'Backup & Restore',
        'Export, import, automatic backups'),
    _Page(AppIcons.storage, 'Storage', 'Disk usage, indexes, caches'),
    _Page(AppIcons.info, 'About', 'Version, updates, release notes'),
  ];

  static (String, String) _localizedPage(AppLocalizations l, int i) =>
      switch (i) {
        0 => (l.libraryTitle, l.settingsPageLibrarySubtitle),
        1 => (l.settingsPagePlaybackTitle, l.settingsPagePlaybackSubtitle),
        2 => (l.settingsPageLyricsTitle, l.settingsPageLyricsSubtitle),
        3 => (l.settingsPageAppearanceTitle, l.settingsPageAppearanceSubtitle),
        4 => (
            l.settingsPageHomeNavigationTitle,
            l.settingsPageHomeNavigationSubtitle
          ),
        5 => (l.settingsPageOnlineTitle, l.settingsPageOnlineSubtitle),
        6 => (l.settingsPageSyncTitle, l.settingsPageSyncSubtitle),
        7 => (
            l.settingsPageBackupRestoreTitle,
            l.settingsPageBackupRestoreSubtitle
          ),
        8 => (l.settingsPageStorageTitle, l.settingsPageStorageSubtitle),
        _ => (l.settingsPageAboutTitle, l.settingsPageAboutSubtitle),
      };

  static final _categoryTitles = [for (final p in _pages) p.title];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _categoryIndexForTitle(String title) {
    final index = _categoryTitles.indexOf(title);
    return index < 0 ? 0 : index;
  }

  void _selectDestination(SettingsDestination entry) {
    // Pages carry breadcrumb 'Settings' and their own title; rows carry
    // 'Settings › <Category>'.
    final breadcrumb = entry.breadcrumb;
    final categoryTitle = breadcrumb == 'Settings'
        ? entry.title
        : breadcrumb.split('›').last.trim();
    setState(() {
      _selected = _categoryIndexForTitle(categoryTitle);
      _detailHighlight = entry.anchorId;
      _controller.clear();
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final isWide = WideLayout.isWide(context);
    return AmbientScaffold(
      appBar: AppTopBar(
        title: AppLocalizations.of(context).settingsTitle,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.s4,
              0,
              AppTokens.s4,
              AppTokens.s3,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 480 : double.infinity,
                ),
                child: AppSurface(
                  depth: AppDepth.well,
                  borderRadius: AppTokens.brPill,
                  padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.search,
                        size: AppTokens.iconSm,
                        color: AppTokens.fgTertiary,
                      ),
                      const SizedBox(width: AppTokens.s3),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: context.l10n.settingsSearchHint,
                            hintStyle: AppTokens.rowSubtitle(context),
                          ),
                          style: AppTokens.rowTitle(context),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        IconButton(
                          icon: const AppIcon(AppIcons.close,
                              size: AppTokens.iconSm),
                          tooltip: context.l10n.actionClear,
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: isWide
          ? _buildMasterDetail(context, searching: searching)
          : WideContentCenter(
              maxWidth: WideLayout.maxNarrowWidth,
              child: searching ? _buildResults(context) : _buildGroups(context),
            ),
    );
  }

  /// Desktop arrangement: category list on the left, selected page inline on
  /// the right. Detail pages are the same screen widgets the phone pushes,
  /// rendered content-only via [embedded], so mobile behaviour is untouched.
  /// Search stays in the split: results replace the right pane, not the row.
  Widget _buildMasterDetail(BuildContext context, {bool searching = false}) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      for (var i = 0; i < _pages.length; i++)
        (_pages[i].icon, _localizedPage(l10n, i).$1, _localizedPage(l10n, i).$2)
    ];
    return WideContentCenter(
      maxWidth: WideLayout.maxContentWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: ListView.builder(
              physics: const MotionScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s4,
                AppTokens.s2,
                AppTokens.s2,
                AppTokens.scrollBottomInset,
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AppListRow(
                  dense: true,
                  leading: AppRowIcon(icon: entry.$1, size: 40),
                  title: entry.$2,
                  subtitle: entry.$3,
                  isActive: index == _selected && !searching,
                  onTap: () => setState(() {
                    _selected = index;
                    _detailHighlight = null;
                    _controller.clear();
                    _query = '';
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: AppTokens.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.s2,
                    AppTokens.s2,
                    AppTokens.s4,
                    AppTokens.s1,
                  ),
                  child: Text(
                    searching
                        ? context.l10n.settingsResultsFor(_query.trim())
                        : entries[_selected].$2,
                    style:
                        AppTokens.screenTitle(context).copyWith(fontSize: 22),
                  ),
                ),
                Expanded(
                  child: searching
                      ? _buildResults(context)
                      : IndexedStack(
                          index: _selected,
                          children: [
                            for (final (i, build)
                                in <(int, Widget Function(String?))>[
                              (
                                0,
                                (h) => LibrarySettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                1,
                                (h) => PlaybackSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                2,
                                (h) => LyricsSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                3,
                                (h) => AppearanceSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                4,
                                (h) => HomeSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                5,
                                (h) => OnlineSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                6,
                                (_) => const SyncSettingsScreen(embedded: true)
                              ),
                              (
                                7,
                                (h) => BackupSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                8,
                                (h) => StorageSettingsScreen(
                                    highlightId: h, embedded: true)
                              ),
                              (
                                9,
                                (_) => const AboutSettingsScreen(embedded: true)
                              ),
                            ])
                              KeyedSubtree(
                                key: ValueKey(
                                    'settings-detail-$i-$_detailHighlight'),
                                child: build(
                                    _selected == i ? _detailHighlight : null),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Flat, breadcrumbed results — the categories are what search exists to
  /// skip, so they don't come back as headers here.
  Widget _buildResults(BuildContext context) {
    final results = _search.search(
      buildSettingsRegistry(AppLocalizations.of(context)),
      _query,
    );

    if (results.isEmpty) {
      return AppEmptyState(
        icon: AppIcons.search,
        title: context.l10n.settingsNoResultsTitle,
        message: context.l10n.settingsNoResultsMessage(_query.trim()),
      );
    }

    return ListView(
      physics: const MotionScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s2,
        AppTokens.s4,
        AppTokens.scrollBottomInset,
      ),
      children: [
        AppSurfaceGroup(
          children: [
            for (final entry in results)
              AppSettingsTile(
                icon: entry.icon,
                title: entry.title,
                // The breadcrumb replaces the subtitle: from a result you need
                // to know *where* it lives more than what it does.
                subtitle: entry.breadcrumb,
                onTap: () {
                  // On wide windows search jumps inside the split view
                  // instead of pushing another full screen.
                  if (WideLayout.isWide(context)) {
                    _selectDestination(entry);
                  } else {
                    context.pushApp(entry.open());
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroups(BuildContext context) {
    final l10n = context.l10n;
    Widget tile(int i, Widget Function() open) => AppSettingsTile(
          icon: _pages[i].icon,
          title: _localizedPage(l10n, i).$1,
          subtitle: _localizedPage(l10n, i).$2,
          onTap: () => context.pushApp(open()),
        );

    return AppSettingsList(children: [
      AppSettingsGroup(
        label: l10n.statsTitle,
        children: [
          tile(1, () => const PlaybackSettingsScreen()),
          tile(2, () => const LyricsSettingsScreen()),
        ],
      ),
      AppSettingsGroup(
        label: l10n.libraryTitle,
        children: [
          tile(0, () => const LibrarySettingsScreen()),
        ],
      ),
      AppSettingsGroup(
        label: l10n.settingsGroupLookAndFeel,
        children: [
          tile(3, () => const AppearanceSettingsScreen()),
          tile(4, () => const HomeSettingsScreen()),
        ],
      ),
      AppSettingsGroup(
        label: l10n.settingsGroupData,
        children: [
          tile(5, () => const OnlineSettingsScreen()),
          tile(6, () => const SyncSettingsScreen()),
          tile(7, () => const BackupSettingsScreen()),
          tile(8, () => const StorageSettingsScreen()),
        ],
      ),
      AppSettingsGroup(
        label: l10n.settingsGroupApp,
        children: [
          tile(9, () => const AboutSettingsScreen()),
        ],
      ),
    ]);
  }
}

class _Page {
  final AppIconData icon;
  final String title;
  final String subtitle;
  const _Page(this.icon, this.title, this.subtitle);
}

class LibrarySettingsScreen extends ConsumerWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for embedding in the wide
  /// master-detail pane (no scaffold or top bar).
  final bool embedded;

  const LibrarySettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  // Discrete steps for file size slider (in bytes)
  static const List<int> _fileSizeSteps = [
    0,
    10240,
    51200,
    102400,
    204800,
    512000,
    1048576,
    2097152,
    5242880,
    10485760,
    26214400,
    52428800,
    104857600,
  ];

  // Discrete steps for track duration slider (in milliseconds)
  static const List<int> _durationSteps = [
    0,
    5000,
    10000,
    15000,
    20000,
    30000,
    45000,
    60000,
    120000,
    300000,
  ];

  static int _nearestFileSizeIndex(int bytes) {
    int best = 0;
    int bestDiff = (bytes - _fileSizeSteps[0]).abs();
    for (int i = 1; i < _fileSizeSteps.length; i++) {
      final diff = (bytes - _fileSizeSteps[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  static int _nearestDurationIndex(int ms) {
    int best = 0;
    int bestDiff = (ms - _durationSteps[0]).abs();
    for (int i = 1; i < _durationSteps.length; i++) {
      final diff = (ms - _durationSteps[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  static String _formatFileSize(AppLocalizations l10n, int bytes) {
    if (bytes == 0) return l10n.settingsValueNone;
    if (bytes < 1024) return l10n.storageSizeBytes(bytes);
    if (bytes < 1048576) {
      final kb = bytes / 1024;
      return l10n.storageSizeKb(kb == kb.truncateToDouble()
          ? '${kb.toInt()}'
          : kb.toStringAsFixed(2));
    }
    final mb = bytes / 1048576;
    return l10n.storageSizeMb(
        mb == mb.truncateToDouble() ? '${mb.toInt()}' : mb.toStringAsFixed(1));
  }

  static String _formatDuration(AppLocalizations l10n, int ms) {
    if (ms == 0) return l10n.settingsValueNone;
    if (ms < 60000) {
      return l10n.settingsDurationSeconds((ms / 1000).round());
    }
    final min = ms ~/ 60000;
    final sec = (ms % 60000) ~/ 1000;
    return sec == 0
        ? l10n.settingsDurationMinutes(min)
        : l10n.settingsDurationMinutesSeconds(min, sec);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final content = AppSettingsList(
      highlightId: highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.libraryTitle,
          icon: AppIcons.library,
          children: [
            AppSettingsTile(
              icon: AppIcons.folder,
              searchId: 'library.folders',
              title: l10n.settingsSearchMusicFoldersTitle,
              subtitle: l10n.settingsSearchMusicFoldersSubtitle,
              onTap: () => context.pushApp(const FolderManagementScreen()),
            ),
            AppSettingsTile(
              icon: AppIcons.refresh,
              searchId: 'library.rescan',
              title: l10n.settingsSearchRescanTitle,
              subtitle: l10n.settingsSearchRescanSubtitle,
              onTap: () => appSnack(context, l10n.settingsScanningLibrary),
            ),
            if (!WideLayout.isWide(context))
              StatefulBuilder(
                builder: (context, setState) => FutureBuilder<bool>(
                  future: ref
                      .read(storageServiceProvider)
                      .getPullToRefreshEnabled(),
                  builder: (context, snapshot) => AppSettingsSwitch(
                    icon: AppIcons.touchApp,
                    searchId: 'library.pull_to_refresh',
                    title: l10n.settingsSearchPullToRefreshTitle,
                    subtitle: l10n.settingsSearchPullToRefreshSubtitle,
                    value: snapshot.data ?? true,
                    onChanged: (val) async {
                      await ref
                          .read(storageServiceProvider)
                          .setPullToRefreshEnabled(val);
                      setState(() {});
                    },
                  ),
                ),
              ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.settingsGroupFilters,
          icon: AppIcons.filterList,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.videoLibrary,
              searchId: 'library.include_videos',
              title: l10n.settingsSearchIncludeVideosTitle,
              subtitle: l10n.settingsSearchIncludeVideosSubtitle,
              value: settings.includeVideos,
              onChanged: notifier.setIncludeVideos,
            ),
            AppSettingsSlider(
              icon: AppIcons.dataUsage,
              searchId: 'library.min_file_size',
              title: l10n.settingsSearchMinFileSizeTitle,
              valueLabel: _formatFileSize(l10n, settings.minimumFileSizeBytes),
              value: _nearestFileSizeIndex(settings.minimumFileSizeBytes)
                  .toDouble(),
              min: 0,
              max: (_fileSizeSteps.length - 1).toDouble(),
              divisions: _fileSizeSteps.length - 1,
              onChanged: (val) =>
                  notifier.setMinimumFileSizeBytes(_fileSizeSteps[val.round()]),
            ),
            AppSettingsSlider(
              icon: AppIcons.timer,
              searchId: 'library.min_duration',
              title: l10n.settingsSearchMinDurationTitle,
              valueLabel:
                  _formatDuration(l10n, settings.minimumTrackDurationMs),
              value: _nearestDurationIndex(settings.minimumTrackDurationMs)
                  .toDouble(),
              min: 0,
              max: (_durationSteps.length - 1).toDouble(),
              divisions: _durationSteps.length - 1,
              onChanged: (val) => notifier
                  .setMinimumTrackDurationMs(_durationSteps[val.round()]),
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.settingsGroupMaintenance,
          icon: AppIcons.edit,
          children: [
            AppSettingsTile(
              searchId: 'data.bulk_rename',
              icon: AppIcons.edit,
              title: l10n.settingsSearchBulkRenameTitle,
              subtitle: l10n.settingsSearchBulkRenameSubtitle,
              onTap: () => context.pushApp(const BulkRenameScreen()),
            ),
            AppSettingsTile(
              searchId: 'data.batch_replace',
              icon: AppIcons.swapHoriz,
              title: l10n.settingsSearchBatchReplaceTitle,
              subtitle: l10n.settingsSearchBatchReplaceSubtitle,
              onTap: () => context.pushApp(const BatchReplaceScreen()),
            ),
          ],
        ),
      ],
    );
    if (embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.libraryTitle),
      body: content,
    );
  }
}
