import 'package:flutter/widgets.dart';

import '../../domain/models/settings_entry.dart';
import '../../l10n/app_localizations.dart';
import '../tokens/app_icons.dart';
import 'about_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'backup_management_screen.dart';
import 'custom_shuffle_settings_screen.dart';
import 'backup_settings_screen.dart';
import 'folder_management_screen.dart';
import 'home_settings_screen.dart';
import 'indexer_screen.dart';
import 'lyrics_settings_screen.dart';
import 'storage_settings_screen.dart';
import 'playback_settings_screen.dart';
import 'quick_actions_settings_screen.dart';
import 'settings_screen.dart';
import 'sync_settings_screen.dart';
import 'storage_management_screen.dart';

/// A registry entry that also knows how to draw itself and where to go.
class SettingsDestination extends SettingsEntry {
  final AppIconData icon;

  /// Builds the screen this entry lives on, with the row already flagged for
  /// highlighting where the page supports it.
  final Widget Function() open;

  const SettingsDestination({
    required this.icon,
    required this.open,
    required super.title,
    required super.breadcrumb,
    super.anchorId,
    super.subtitle,
    super.keywords,
  });
}

/// Every setting the search can reach, in the current language.
///
/// This is hand-maintained: Dart can't enumerate widget trees, so a row and its
/// entry are two edits. `test/settings_search_test.dart` guards the join by
/// checking that each [SettingsEntry.anchorId] here really appears as a
/// `searchId:` in a settings screen — a row renamed or removed without its
/// entry fails the suite rather than silently going missing from search.
List<String> _kw(String csv) => csv.split(',');

List<SettingsDestination> buildSettingsRegistry(AppLocalizations l) {
  return [
    // ------------------------------------------------------------------ pages
    SettingsDestination(
      icon: AppIcons.library,
      title: l.libraryTitle,
      subtitle: l.settingsPageLibrarySubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwLibrary),
      open: () => const LibrarySettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.playCircle,
      title: l.settingsPagePlaybackTitle,
      subtitle: l.settingsPagePlaybackSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwPlayback),
      open: () => const PlaybackSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.subtitles,
      title: l.settingsPageLyricsTitle,
      subtitle: l.settingsPageLyricsSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwLyrics),
      open: () => const LyricsSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.home,
      title: l.settingsPageHomeNavigationTitle,
      subtitle: l.settingsPageHomeNavigationSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwHome),
      open: () => const HomeSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.storage,
      title: l.settingsPageStorageTitle,
      subtitle: l.settingsPageStorageSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwStorage),
      open: () => const StorageSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.palette,
      title: l.settingsPageAppearanceTitle,
      subtitle: l.settingsPageAppearanceSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwAppearance),
      open: () => const AppearanceSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.cloudUpload,
      title: l.settingsPageSyncTitle,
      subtitle: l.settingsPageSyncSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwSync),
      open: () => const SyncSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.storage,
      title: l.settingsPageBackupRestoreTitle,
      subtitle: l.settingsPageBackupRestoreSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwBackup),
      open: () => const BackupSettingsScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.dataObject,
      title: l.indexerTitle,
      subtitle: l.settingsSearchIndexerSubtitle,
      breadcrumb: l.settingsCrumbStorage,
      keywords: _kw(l.settingsKwIndexer),
      open: () => const IndexerScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.info,
      title: l.settingsPageAboutTitle,
      subtitle: l.settingsPageAboutSubtitle,
      breadcrumb: l.settingsTitle,
      keywords: _kw(l.settingsKwAbout),
      open: () => const AboutSettingsScreen(),
    ),

    // ---------------------------------------------------------------- library
    SettingsDestination(
      anchorId: 'library.folders',
      icon: AppIcons.folder,
      title: l.settingsSearchMusicFoldersTitle,
      subtitle: l.settingsSearchMusicFoldersSubtitle,
      breadcrumb: l.settingsCrumbLibrary,
      keywords: _kw(l.settingsKwFolders),
      open: () => const LibrarySettingsScreen(highlightId: 'library.folders'),
    ),
    SettingsDestination(
      anchorId: 'library.rescan',
      icon: AppIcons.refresh,
      title: l.settingsSearchRescanTitle,
      subtitle: l.settingsSearchRescanSubtitle,
      breadcrumb: l.settingsCrumbLibrary,
      keywords: _kw(l.settingsKwRescan),
      open: () => const LibrarySettingsScreen(highlightId: 'library.rescan'),
    ),
    SettingsDestination(
      anchorId: 'library.include_videos',
      icon: AppIcons.videoLibrary,
      title: l.settingsSearchIncludeVideosTitle,
      subtitle: l.settingsSearchIncludeVideosSubtitle,
      breadcrumb: l.settingsCrumbLibraryFilters,
      keywords: _kw(l.settingsKwVideos),
      open: () =>
          const LibrarySettingsScreen(highlightId: 'library.include_videos'),
    ),
    SettingsDestination(
      anchorId: 'library.min_file_size',
      icon: AppIcons.dataUsage,
      title: l.settingsSearchMinFileSizeTitle,
      subtitle: l.settingsSearchMinFileSizeSubtitle,
      breadcrumb: l.settingsCrumbLibraryFilters,
      keywords: _kw(l.settingsKwMinFileSize),
      open: () =>
          const LibrarySettingsScreen(highlightId: 'library.min_file_size'),
    ),
    SettingsDestination(
      anchorId: 'library.min_duration',
      icon: AppIcons.timer,
      title: l.settingsSearchMinDurationTitle,
      subtitle: l.settingsSearchMinDurationSubtitle,
      breadcrumb: l.settingsCrumbLibraryFilters,
      keywords: _kw(l.settingsKwMinDuration),
      open: () =>
          const LibrarySettingsScreen(highlightId: 'library.min_duration'),
    ),
    SettingsDestination(
      icon: AppIcons.folder,
      title: l.settingsSearchManageFoldersTitle,
      subtitle: l.settingsSearchManageFoldersSubtitle,
      breadcrumb: l.settingsCrumbLibraryFolders,
      keywords: _kw(l.settingsKwManageFolders),
      open: () => const FolderManagementScreen(),
    ),

    // --------------------------------------------------------------- playback
    SettingsDestination(
      anchorId: 'playback.auto_pause_mute',
      icon: AppIcons.volumeOff,
      title: l.settingsSearchAutoPauseMuteTitle,
      subtitle: l.settingsSearchAutoPauseMuteSubtitle,
      breadcrumb: l.settingsCrumbPlaybackAudio,
      keywords: _kw(l.settingsKwMute),
      open: () =>
          const PlaybackSettingsScreen(highlightId: 'playback.auto_pause_mute'),
    ),
    SettingsDestination(
      anchorId: 'playback.auto_resume_unmute',
      icon: AppIcons.volumeUp,
      title: l.settingsSearchAutoResumeUnmuteTitle,
      subtitle: l.settingsSearchAutoResumeUnmuteSubtitle,
      breadcrumb: l.settingsCrumbPlaybackAudio,
      keywords: _kw(l.settingsKwUnmute),
      open: () => const PlaybackSettingsScreen(
        highlightId: 'playback.auto_resume_unmute',
      ),
    ),
    SettingsDestination(
      anchorId: 'lyrics.rich_sync',
      icon: AppIcons.autoAwesome,
      title: l.lyricsSimulateWordSyncTitle,
      subtitle: l.lyricsSimulateWordSyncSubtitle,
      breadcrumb: l.settingsCrumbLyricsTiming,
      keywords: _kw(l.settingsKwRichSync),
      open: () => const LyricsSettingsScreen(highlightId: 'lyrics.rich_sync'),
    ),
    SettingsDestination(
      anchorId: 'lyrics.desktop_sidebar',
      icon: AppIcons.queue,
      title: l.lyricsDesktopSidebarTitle,
      subtitle: l.lyricsDesktopSidebarSubtitle,
      breadcrumb: l.settingsCrumbLyricsTiming,
      keywords: _kw(l.settingsKwSidebar),
      open: () =>
          const LyricsSettingsScreen(highlightId: 'lyrics.desktop_sidebar'),
    ),
    SettingsDestination(
      anchorId: 'lyrics.keep_screen_awake',
      icon: AppIcons.screenLock,
      title: l.lyricsKeepScreenAwakeTitle,
      subtitle: l.lyricsKeepScreenAwakeSubtitle,
      breadcrumb: l.settingsCrumbLyricsTiming,
      keywords: _kw(l.settingsKwKeepAwake),
      open: () =>
          const LyricsSettingsScreen(highlightId: 'lyrics.keep_screen_awake'),
    ),
    SettingsDestination(
      anchorId: 'lyrics.auto_translate',
      icon: AppIcons.translate,
      title: l.lyricsAutoTranslateTitle,
      subtitle: l.lyricsAutoTranslateSubtitle,
      breadcrumb: l.settingsCrumbLyricsTranslation,
      keywords: _kw(l.settingsKwAutoTranslate),
      open: () =>
          const LyricsSettingsScreen(highlightId: 'lyrics.auto_translate'),
    ),
    SettingsDestination(
      anchorId: 'lyrics.target_lang',
      icon: AppIcons.translate,
      title: l.lyricsTargetLanguageTitle,
      subtitle: l.settingsSearchTargetLangSubtitle,
      breadcrumb: l.settingsCrumbLyricsTranslation,
      keywords: _kw(l.settingsKwTargetLang),
      open: () => const LyricsSettingsScreen(highlightId: 'lyrics.target_lang'),
    ),
    SettingsDestination(
      anchorId: 'lyrics.translation_mode',
      icon: AppIcons.subtitles,
      title: l.lyricsTranslationDisplayTitle,
      subtitle: l.settingsSearchTranslationModeSubtitle,
      breadcrumb: l.settingsCrumbLyricsTranslation,
      keywords: _kw(l.settingsKwTranslationMode),
      open: () =>
          const LyricsSettingsScreen(highlightId: 'lyrics.translation_mode'),
    ),
    SettingsDestination(
      anchorId: 'playback.gap',
      icon: AppIcons.hourglass,
      title: l.settingsSearchGapTitle,
      subtitle: l.settingsSearchGapSubtitle,
      breadcrumb: l.settingsCrumbPlaybackTransitions,
      keywords: _kw(l.settingsKwGap),
      open: () => const PlaybackSettingsScreen(highlightId: 'playback.gap'),
    ),
    SettingsDestination(
      anchorId: 'playback.fade_out',
      icon: AppIcons.volumeDown,
      title: l.settingsSearchFadeOutTitle,
      subtitle: l.settingsSearchFadeOutSubtitle,
      breadcrumb: l.settingsCrumbPlaybackTransitions,
      keywords: _kw(l.settingsKwCrossfade),
      open: () =>
          const PlaybackSettingsScreen(highlightId: 'playback.fade_out'),
    ),
    SettingsDestination(
      anchorId: 'playback.fade_in',
      icon: AppIcons.volumeUp,
      title: l.settingsSearchFadeInTitle,
      subtitle: l.settingsSearchFadeInSubtitle,
      breadcrumb: l.settingsCrumbPlaybackTransitions,
      keywords: _kw(l.settingsKwCrossfade),
      open: () => const PlaybackSettingsScreen(highlightId: 'playback.fade_in'),
    ),
    SettingsDestination(
      anchorId: 'playback.fade_play',
      icon: AppIcons.play,
      title: l.settingsSearchFadePlayTitle,
      subtitle: l.settingsSearchFadePlaySubtitle,
      breadcrumb: l.settingsCrumbPlaybackPlayPause,
      keywords: _kw(l.settingsKwFadePlay),
      open: () =>
          const PlaybackSettingsScreen(highlightId: 'playback.fade_play'),
    ),
    SettingsDestination(
      anchorId: 'playback.fade_pause',
      icon: AppIcons.pause,
      title: l.settingsSearchFadePauseTitle,
      subtitle: l.settingsSearchFadePauseSubtitle,
      breadcrumb: l.settingsCrumbPlaybackPlayPause,
      keywords: _kw(l.settingsKwFadePause),
      open: () =>
          const PlaybackSettingsScreen(highlightId: 'playback.fade_pause'),
    ),

    // ------------------------------------------------------------- appearance
    SettingsDestination(
      anchorId: 'appearance.visualizer',
      icon: AppIcons.waves,
      title: l.appearanceVisualizerTitle,
      subtitle: l.settingsSearchVisualizerSubtitle,
      breadcrumb: l.settingsCrumbAppearanceNowPlaying,
      keywords: _kw(l.settingsKwVisualizer),
      open: () =>
          const AppearanceSettingsScreen(highlightId: 'appearance.visualizer'),
    ),
    SettingsDestination(
      anchorId: 'appearance.language',
      icon: AppIcons.translate,
      title: l.settingsLanguageTitle,
      subtitle: l.settingsSearchLanguageSubtitle,
      breadcrumb: l.settingsCrumbAppearanceLanguage,
      keywords: _kw(l.settingsKwLanguage),
      open: () =>
          const AppearanceSettingsScreen(highlightId: 'appearance.language'),
    ),
    SettingsDestination(
      anchorId: 'appearance.waveform',
      icon: AppIcons.graphicEq,
      title: l.appearanceProgressBarTitle,
      subtitle: l.settingsSearchProgressBarSubtitle,
      breadcrumb: l.settingsCrumbAppearanceNowPlaying,
      keywords: _kw(l.settingsKwProgressBar),
      open: () =>
          const AppearanceSettingsScreen(highlightId: 'appearance.waveform'),
    ),
    SettingsDestination(
      anchorId: 'appearance.waveform_haptics',
      icon: AppIcons.touchApp,
      title: l.appearanceHapticsTitle,
      subtitle: l.appearanceHapticsSubtitle,
      breadcrumb: l.settingsCrumbAppearanceNowPlaying,
      keywords: _kw(l.settingsKwHaptics),
      open: () => const AppearanceSettingsScreen(
          highlightId: 'appearance.waveform_haptics'),
    ),
    SettingsDestination(
      anchorId: 'appearance.song_duration',
      icon: AppIcons.timer,
      title: l.settingsSearchSongDurationTitle,
      subtitle: l.settingsSearchSongDurationSubtitle,
      breadcrumb: l.settingsCrumbHomeLists,
      keywords: _kw(l.settingsKwSongDuration),
      open: () =>
          const HomeSettingsScreen(highlightId: 'appearance.song_duration'),
    ),
    SettingsDestination(
      anchorId: 'appearance.auto_hide_bars',
      icon: AppIcons.swapVert,
      title: l.settingsSearchAutoHideBarsTitle,
      subtitle: l.settingsSearchAutoHideBarsSubtitle,
      breadcrumb: l.settingsCrumbHomeLists,
      keywords: _kw(l.settingsKwAutoHide),
      open: () =>
          const HomeSettingsScreen(highlightId: 'appearance.auto_hide_bars'),
    ),
    SettingsDestination(
      anchorId: 'appearance.cover_sizing',
      icon: AppIcons.photoSize,
      title: l.appearanceCoverSizingTitle,
      subtitle: l.appearanceCoverSizingSubtitle,
      breadcrumb: l.settingsCrumbAppearanceNowPlaying,
      keywords: _kw(l.settingsKwCoverSizing),
      open: () => const AppearanceSettingsScreen(
          highlightId: 'appearance.cover_sizing'),
    ),
    SettingsDestination(
      anchorId: 'appearance.full_bleed_design',
      icon: AppIcons.autoAwesome,
      title: l.appearanceImmersiveTitle,
      subtitle: l.appearanceImmersiveSubtitle,
      breadcrumb: l.settingsCrumbAppearanceNowPlaying,
      keywords: _kw(l.settingsKwImmersive),
      open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.full_bleed_design',
      ),
    ),
    SettingsDestination(
      anchorId: 'appearance.app_icon',
      icon: AppIcons.album,
      title: l.appearanceAppIcon,
      subtitle: l.settingsSearchAppIconSubtitle,
      breadcrumb: l.settingsCrumbAppearanceAppIcon,
      keywords: _kw(l.settingsKwAppIcon),
      open: () =>
          const AppearanceSettingsScreen(highlightId: 'appearance.app_icon'),
    ),
    SettingsDestination(
      anchorId: 'appearance.beat_cover',
      icon: AppIcons.album,
      title: l.appearanceBeatCoverTitle,
      subtitle: l.settingsSearchBeatCoverSubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwBeatCover),
      open: () =>
          const AppearanceSettingsScreen(highlightId: 'appearance.beat_cover'),
    ),
    SettingsDestination(
      anchorId: 'appearance.spin_artwork',
      icon: AppIcons.album,
      title: l.appearanceSpinArtworkTitle,
      subtitle: l.settingsSearchSpinArtworkSubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwSpinArtwork),
      open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.spin_artwork',
      ),
    ),
    SettingsDestination(
      anchorId: 'appearance.beat_particles',
      icon: AppIcons.autoAwesome,
      title: l.appearanceParticlesTitle,
      subtitle: l.appearanceParticlesSubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwBeatParticles),
      open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.beat_particles',
      ),
    ),
    SettingsDestination(
      anchorId: 'appearance.cover_intensity',
      icon: AppIcons.album,
      title: l.appearanceCoverIntensityTitle,
      subtitle: l.settingsSearchCoverIntensitySubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwCoverIntensity),
      open: () => const AppearanceSettingsScreen(
          highlightId: 'appearance.cover_intensity'),
    ),
    SettingsDestination(
      anchorId: 'appearance.particle_intensity',
      icon: AppIcons.autoAwesome,
      title: l.appearanceParticleDensityTitle,
      subtitle: l.settingsSearchParticleDensitySubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwParticleDensity),
      open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.particle_intensity',
      ),
    ),
    SettingsDestination(
      anchorId: 'appearance.beat_offset',
      icon: AppIcons.syncAlt,
      title: l.appearanceBeatOffsetTitle,
      subtitle: l.settingsSearchBeatOffsetSubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwBeatOffset),
      open: () =>
          const AppearanceSettingsScreen(highlightId: 'appearance.beat_offset'),
    ),
    SettingsDestination(
      anchorId: 'appearance.beat_calibrate',
      icon: AppIcons.syncAlt,
      title: l.appearanceCalibrateTitle,
      subtitle: l.appearanceCalibrateSubtitle,
      breadcrumb: l.settingsCrumbAppearanceMotion,
      keywords: _kw(l.settingsKwCalibrate),
      open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.beat_calibrate',
      ),
    ),
    SettingsDestination(
      anchorId: 'appearance.quick_picks',
      icon: AppIcons.autoAwesome,
      title: l.homeQuickPicks,
      subtitle: l.settingsSearchQuickPicksSubtitle,
      breadcrumb: l.settingsCrumbHomeScreen,
      keywords: _kw(l.settingsKwQuickPicks),
      open: () =>
          const HomeSettingsScreen(highlightId: 'appearance.quick_picks'),
    ),
    SettingsDestination(
      anchorId: 'appearance.recent_queues',
      icon: AppIcons.clock,
      title: l.homeRecentQueues,
      subtitle: l.settingsSearchRecentQueuesSubtitle,
      breadcrumb: l.settingsCrumbHomeScreen,
      keywords: _kw(l.settingsKwRecentQueues),
      open: () =>
          const HomeSettingsScreen(highlightId: 'appearance.recent_queues'),
    ),
    SettingsDestination(
      anchorId: 'appearance.for_you',
      icon: AppIcons.explore,
      title: l.homeForYou,
      subtitle: l.settingsSearchForYouSubtitle,
      breadcrumb: l.settingsCrumbHomeScreen,
      keywords: _kw(l.settingsKwForYou),
      open: () => const HomeSettingsScreen(highlightId: 'appearance.for_you'),
    ),
    SettingsDestination(
      anchorId: 'appearance.quick_actions',
      icon: AppIcons.flashOn,
      title: l.quickActionsTitle,
      subtitle: l.settingsSearchQuickActionsSubtitle,
      breadcrumb: l.settingsCrumbHomeLists,
      keywords: _kw(l.settingsKwQuickActions),
      open: () =>
          const HomeSettingsScreen(highlightId: 'appearance.quick_actions'),
    ),
    SettingsDestination(
      icon: AppIcons.flashOn,
      title: l.settingsSearchReorderQuickActionsTitle,
      subtitle: l.settingsSearchReorderQuickActionsSubtitle,
      breadcrumb: l.settingsCrumbAppearanceLists,
      keywords: _kw(l.settingsKwReorderQuickActions),
      open: () => const QuickActionsSettingsScreen(),
    ),

    // ------------------------------------------------------------------- data
    SettingsDestination(
      anchorId: 'data.export',
      icon: AppIcons.upload,
      title: l.backupExportAppData,
      subtitle: l.backupExportAppDataSubtitle,
      breadcrumb: l.settingsCrumbBackup,
      keywords: _kw(l.settingsKwExport),
      open: () => const BackupSettingsScreen(highlightId: 'data.export'),
    ),
    SettingsDestination(
      anchorId: 'data.import',
      icon: AppIcons.download,
      title: l.backupImportAppData,
      subtitle: l.backupImportAppDataSubtitle,
      breadcrumb: l.settingsCrumbBackup,
      keywords: _kw(l.settingsKwImport),
      open: () => const BackupSettingsScreen(highlightId: 'data.import'),
    ),
    SettingsDestination(
      anchorId: 'data.backups',
      icon: AppIcons.cloudUpload,
      title: l.backupManageBackups,
      subtitle: l.backupManageBackupsSubtitle,
      breadcrumb: l.settingsCrumbBackup,
      keywords: _kw(l.settingsKwManageBackups),
      open: () => const BackupSettingsScreen(highlightId: 'data.backups'),
    ),
    SettingsDestination(
      anchorId: 'data.bulk_rename',
      icon: AppIcons.edit,
      title: l.settingsSearchBulkRenameTitle,
      subtitle: l.settingsSearchBulkRenameSubtitle,
      breadcrumb: l.settingsCrumbLibraryMaintenance,
      keywords: _kw(l.settingsKwBulkRename),
      open: () => const LibrarySettingsScreen(
        highlightId: 'data.bulk_rename',
      ),
    ),
    SettingsDestination(
      anchorId: 'data.storage',
      icon: AppIcons.storage,
      title: l.storageManageTitle,
      subtitle: l.settingsSearchManageStorageSubtitle,
      breadcrumb: l.settingsCrumbStorage,
      keywords: _kw(l.settingsKwManageStorage),
      open: () => const StorageSettingsScreen(highlightId: 'data.storage'),
    ),
    SettingsDestination(
      icon: AppIcons.cloudUpload,
      title: l.storageBackupsTitle,
      subtitle: l.settingsSearchBackupsSubtitle,
      breadcrumb: l.settingsCrumbManageBackups,
      keywords: _kw(l.settingsKwBackups),
      open: () => const BackupManagementScreen(),
    ),
    SettingsDestination(
      icon: AppIcons.storage,
      title: l.settingsPageStorageTitle,
      subtitle: l.settingsSearchStorageUsageSubtitle,
      breadcrumb: l.settingsCrumbManageStorage,
      keywords: _kw(l.settingsKwStorageUsage),
      open: () => const StorageManagementScreen(),
    ),

    // ------------------------------------------------------ automatic backups
    SettingsDestination(
      anchorId: 'data.auto_backup',
      icon: AppIcons.cloudUpload,
      title: l.backupAutoBackup,
      subtitle: l.backupAutoBackupSubtitle,
      breadcrumb: l.settingsCrumbAutoBackups,
      keywords: _kw(l.settingsKwAutoBackup),
      open: () => const BackupSettingsScreen(highlightId: 'data.auto_backup'),
    ),
    SettingsDestination(
      anchorId: 'data.auto_backup_content',
      icon: AppIcons.tune,
      title: l.backupAutoBackupContent,
      subtitle: l.backupAutoBackupContentSubtitle,
      breadcrumb: l.settingsCrumbAutoBackups,
      keywords: _kw(l.settingsKwAutoBackupContent),
      open: () =>
          const BackupSettingsScreen(highlightId: 'data.auto_backup_content'),
    ),
    SettingsDestination(
      anchorId: 'data.auto_delete_backups',
      icon: AppIcons.delete,
      title: l.backupAutoDeleteOld,
      subtitle: l.backupAutoDeleteOldSubtitle,
      breadcrumb: l.settingsCrumbAutoBackups,
      keywords: _kw(l.settingsKwAutoDelete),
      open: () =>
          const BackupSettingsScreen(highlightId: 'data.auto_delete_backups'),
    ),
    SettingsDestination(
      anchorId: 'library.pull_to_refresh',
      icon: AppIcons.touchApp,
      title: l.settingsSearchPullToRefreshTitle,
      subtitle: l.settingsSearchPullToRefreshSubtitle,
      breadcrumb: l.settingsCrumbLibrary,
      keywords: _kw(l.settingsKwPullToRefresh),
      open: () =>
          const LibrarySettingsScreen(highlightId: 'library.pull_to_refresh'),
    ),

    // ---------------------------------------------------------------- shuffle
    SettingsDestination(
      icon: AppIcons.tune,
      title: l.profileConfigureCustomShuffle,
      subtitle: l.profileConfigureCustomShuffleSubtitle,
      breadcrumb: l.settingsCrumbProfileShuffle,
      keywords: _kw(l.settingsKwShuffle),
      open: () => const CustomShuffleSettingsScreen(),
    ),
  ];
}
