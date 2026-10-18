import 'package:flutter/widgets.dart';

import '../../domain/models/settings_entry.dart';
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

/// Every setting the search can reach.
///
/// This is hand-maintained: Dart can't enumerate widget trees, so a row and its
/// entry are two edits. `test/settings_search_test.dart` guards the join by
/// checking that each [SettingsEntry.anchorId] here really appears as a
/// `searchId:` in a settings screen — a row renamed or removed without its
/// entry fails the suite rather than silently going missing from search.
final List<SettingsDestination> settingsRegistry = [
  // ------------------------------------------------------------------ pages
  SettingsDestination(
    icon: AppIcons.library,
    title: 'Library',
    subtitle: 'Folders, filters, scanning',
    breadcrumb: 'Settings',
    keywords: const ['scan', 'folders', 'filters', 'songs'],
    open: () => const LibrarySettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.playCircle,
    title: 'Playback',
    subtitle: 'Transitions, fades, audio',
    breadcrumb: 'Settings',
    keywords: const ['audio', 'sound', 'transitions'],
    open: () => const PlaybackSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.subtitles,
    title: 'Lyrics',
    subtitle: 'Word sync, translation, sidebar',
    breadcrumb: 'Settings',
    keywords: const ['lyrics', 'translate', 'karaoke', 'subtitles'],
    open: () => const LyricsSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.home,
    title: 'Home & Navigation',
    subtitle: 'Home sections, lists, quick actions',
    breadcrumb: 'Settings',
    keywords: const ['home', 'quick picks', 'gestures', 'bars', 'layout'],
    open: () => const HomeSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.storage,
    title: 'Storage',
    subtitle: 'Disk usage, indexes, caches',
    breadcrumb: 'Settings',
    keywords: const ['disk', 'space', 'cache', 'indexer', 'cleanup'],
    open: () => const StorageSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.palette,
    title: 'Appearance',
    subtitle: 'Now playing, motion, app icon',
    breadcrumb: 'Settings',
    keywords: const ['theme', 'colour', 'color', 'display', 'look'],
    open: () => const AppearanceSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.cloudUpload,
    title: 'Sync',
    subtitle: 'Encrypted cross-device sync',
    breadcrumb: 'Settings',
    keywords: const ['cloud', 'account', 'devices', 'encrypted'],
    open: () => const SyncSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.storage,
    title: 'Backup & Restore',
    subtitle: 'Export, import, automatic backups',
    breadcrumb: 'Settings',
    keywords: const ['backup', 'restore', 'export', 'import', 'data'],
    open: () => const BackupSettingsScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.dataObject,
    title: 'Indexer',
    subtitle: 'Rebuild indexes and caches',
    breadcrumb: 'Settings › Storage',
    keywords: const ['index', 'rebuild', 'cache', 'reindex'],
    open: () => const IndexerScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.info,
    title: 'About',
    subtitle: 'Version, updates, release notes',
    breadcrumb: 'Settings',
    keywords: const ['version', 'update', 'changelog', 'release'],
    open: () => const AboutSettingsScreen(),
  ),

  // ---------------------------------------------------------------- library
  SettingsDestination(
    anchorId: 'library.folders',
    icon: AppIcons.folder,
    title: 'Music Folders',
    subtitle: 'Manage music library folders',
    breadcrumb: 'Settings › Library',
    keywords: const ['directory', 'path', 'add folder', 'sources'],
    open: () => const LibrarySettingsScreen(highlightId: 'library.folders'),
  ),
  SettingsDestination(
    anchorId: 'library.rescan',
    icon: AppIcons.refresh,
    title: 'Re-scan Library Now',
    subtitle: 'Manually refresh all songs from disk',
    breadcrumb: 'Settings › Library',
    keywords: const ['refresh', 'reload', 'sync'],
    open: () => const LibrarySettingsScreen(highlightId: 'library.rescan'),
  ),
  SettingsDestination(
    anchorId: 'library.include_videos',
    icon: AppIcons.videoLibrary,
    title: 'Include Videos',
    subtitle: 'Show video files in your song library',
    breadcrumb: 'Settings › Library › Filters',
    keywords: const ['video', 'mp4', 'clips'],
    open: () =>
        const LibrarySettingsScreen(highlightId: 'library.include_videos'),
  ),
  SettingsDestination(
    anchorId: 'library.min_file_size',
    icon: AppIcons.dataUsage,
    title: 'Minimum File Size',
    subtitle: 'Ignore files smaller than this',
    breadcrumb: 'Settings › Library › Filters',
    keywords: const ['size', 'skip', 'small', 'filter'],
    open: () =>
        const LibrarySettingsScreen(highlightId: 'library.min_file_size'),
  ),
  SettingsDestination(
    anchorId: 'library.min_duration',
    icon: AppIcons.timer,
    title: 'Minimum Duration',
    subtitle: 'Ignore tracks shorter than this',
    breadcrumb: 'Settings › Library › Filters',
    keywords: const ['length', 'short', 'skip', 'filter', 'interlude'],
    open: () =>
        const LibrarySettingsScreen(highlightId: 'library.min_duration'),
  ),
  SettingsDestination(
    icon: AppIcons.folder,
    title: 'Manage music folders',
    subtitle: 'Add, remove and rescan individual folders',
    breadcrumb: 'Settings › Library › Music Folders',
    keywords: const ['folder', 'directory', 'storage', 'sd card'],
    open: () => const FolderManagementScreen(),
  ),

  // --------------------------------------------------------------- playback
  SettingsDestination(
    anchorId: 'playback.auto_pause_mute',
    icon: AppIcons.volumeOff,
    title: 'Auto-Pause on Mute',
    subtitle: 'Pause playback when volume reaches 0',
    breadcrumb: 'Settings › Playback › Audio',
    keywords: const ['volume', 'silent', 'mute'],
    open: () =>
        const PlaybackSettingsScreen(highlightId: 'playback.auto_pause_mute'),
  ),
  SettingsDestination(
    anchorId: 'playback.auto_resume_unmute',
    icon: AppIcons.volumeUp,
    title: 'Auto-Resume on Unmute',
    subtitle: 'Resume playback when volume is restored',
    breadcrumb: 'Settings › Playback › Audio',
    keywords: const ['volume', 'unmute', 'continue'],
    open: () => const PlaybackSettingsScreen(
      highlightId: 'playback.auto_resume_unmute',
    ),
  ),
  SettingsDestination(
    anchorId: 'lyrics.rich_sync',
    icon: AppIcons.autoAwesome,
    title: 'Simulate Word Sync',
    subtitle:
        'Generate word-level timing from line-synced lyrics using prosodic estimation',
    breadcrumb: 'Settings › Lyrics › Display & Timing',
    keywords: const ['lyrics', 'richsync', 'karaoke', 'word', 'sync'],
    open: () => const LyricsSettingsScreen(highlightId: 'lyrics.rich_sync'),
  ),
  SettingsDestination(
    anchorId: 'lyrics.desktop_sidebar',
    icon: AppIcons.queue,
    title: 'Lyrics & Queue Sidebar',
    subtitle:
        'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden',
    breadcrumb: 'Settings › Lyrics › Display & Timing',
    keywords: const ['sidebar', 'panel', 'desktop', 'queue', 'lyrics'],
    open: () =>
        const LyricsSettingsScreen(highlightId: 'lyrics.desktop_sidebar'),
  ),
  SettingsDestination(
    anchorId: 'lyrics.keep_screen_awake',
    icon: AppIcons.screenLock,
    title: 'Keep Screen Awake on Lyrics',
    subtitle: 'Prevent sleep while the lyrics pane is open',
    breadcrumb: 'Settings › Lyrics › Display & Timing',
    keywords: const ['sleep', 'wakelock', 'display', 'lyrics'],
    open: () =>
        const LyricsSettingsScreen(highlightId: 'lyrics.keep_screen_awake'),
  ),
  SettingsDestination(
    anchorId: 'lyrics.auto_translate',
    icon: AppIcons.translate,
    title: 'Auto-Translate Lyrics',
    subtitle: 'Automatically translate lyrics using selected target language',
    breadcrumb: 'Settings › Lyrics › Translation',
    keywords: const ['translate', 'translation', 'language', 'lyrics', 'auto'],
    open: () =>
        const LyricsSettingsScreen(highlightId: 'lyrics.auto_translate'),
  ),
  SettingsDestination(
    anchorId: 'lyrics.target_lang',
    icon: AppIcons.translate,
    title: 'Target Language',
    subtitle: 'Language to translate lyrics into',
    breadcrumb: 'Settings › Lyrics › Translation',
    keywords: const ['translate', 'language', 'spanish', 'english', 'japanese'],
    open: () => const LyricsSettingsScreen(highlightId: 'lyrics.target_lang'),
  ),
  SettingsDestination(
    anchorId: 'lyrics.translation_mode',
    icon: AppIcons.subtitles,
    title: 'Translation Display',
    subtitle: 'Show subtext below lyrics or replace base lyrics',
    breadcrumb: 'Settings › Lyrics › Translation',
    keywords: const ['translate', 'mode', 'subtext', 'replace', 'display'],
    open: () =>
        const LyricsSettingsScreen(highlightId: 'lyrics.translation_mode'),
  ),
  SettingsDestination(
    anchorId: 'playback.gap',
    icon: AppIcons.hourglass,
    title: 'Gap / Delay',
    subtitle: 'Silence between tracks',
    breadcrumb: 'Settings › Playback › Transitions',
    keywords: const ['pause', 'silence', 'between', 'transition'],
    open: () => const PlaybackSettingsScreen(highlightId: 'playback.gap'),
  ),
  SettingsDestination(
    anchorId: 'playback.fade_out',
    icon: AppIcons.volumeDown,
    title: 'Fade Out',
    subtitle: 'Fade the outgoing track',
    breadcrumb: 'Settings › Playback › Transitions',
    keywords: const ['crossfade', 'gapless', 'transition', 'blend'],
    open: () => const PlaybackSettingsScreen(highlightId: 'playback.fade_out'),
  ),
  SettingsDestination(
    anchorId: 'playback.fade_in',
    icon: AppIcons.volumeUp,
    title: 'Fade In',
    subtitle: 'Fade the incoming track',
    breadcrumb: 'Settings › Playback › Transitions',
    keywords: const ['crossfade', 'gapless', 'transition', 'blend'],
    open: () => const PlaybackSettingsScreen(highlightId: 'playback.fade_in'),
  ),
  SettingsDestination(
    anchorId: 'playback.fade_play',
    icon: AppIcons.play,
    title: 'Fade on Play',
    subtitle: 'Ease the volume up when playback starts',
    breadcrumb: 'Settings › Playback › Play / Pause',
    keywords: const ['ramp', 'volume', 'start'],
    open: () => const PlaybackSettingsScreen(highlightId: 'playback.fade_play'),
  ),
  SettingsDestination(
    anchorId: 'playback.fade_pause',
    icon: AppIcons.pause,
    title: 'Fade on Pause',
    subtitle: 'Ease the volume down when playback stops',
    breadcrumb: 'Settings › Playback › Play / Pause',
    keywords: const ['ramp', 'volume', 'stop'],
    open: () =>
        const PlaybackSettingsScreen(highlightId: 'playback.fade_pause'),
  ),

  // ------------------------------------------------------------- appearance
  SettingsDestination(
    anchorId: 'appearance.visualizer',
    icon: AppIcons.waves,
    title: 'Audio Visualizer',
    subtitle: 'Off, classic bars, or bars synced to the song',
    breadcrumb: 'Settings › Appearance › Now Playing',
    keywords: const ['wave', 'animation', 'spectrum', 'bars', 'sync', 'bass'],
    open: () =>
        const AppearanceSettingsScreen(highlightId: 'appearance.visualizer'),
  ),
  SettingsDestination(
    anchorId: 'appearance.waveform',
    icon: AppIcons.graphicEq,
    title: 'Progress Bar Style',
    subtitle: 'Standard, waveform, or sound-reactive progress bar',
    breadcrumb: 'Settings › Appearance › Now Playing',
    keywords: const ['seek', 'progress', 'wave', 'reactive', 'spectrum'],
    open: () =>
        const AppearanceSettingsScreen(highlightId: 'appearance.waveform'),
  ),
  SettingsDestination(
    anchorId: 'appearance.waveform_haptics',
    icon: AppIcons.touchApp,
    title: 'Waveform Scrubbing Haptics',
    subtitle: 'Haptic feedback for each bar while seeking',
    breadcrumb: 'Settings › Appearance › Now Playing',
    keywords: const [
      'vibrate',
      'haptic',
      'feedback',
      'waveform',
      'scrub',
      'seek'
    ],
    open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.waveform_haptics'),
  ),
  SettingsDestination(
    anchorId: 'appearance.song_duration',
    icon: AppIcons.timer,
    title: 'Show Song Duration',
    subtitle: 'Display duration in song lists',
    breadcrumb: 'Settings › Home & Navigation › Lists & Navigation',
    keywords: const ['length', 'time', 'lists'],
    open: () =>
        const HomeSettingsScreen(highlightId: 'appearance.song_duration'),
  ),
  SettingsDestination(
    anchorId: 'appearance.auto_hide_bars',
    icon: AppIcons.swapVert,
    title: 'Auto-Hide Bars',
    subtitle: 'Header and bottom dock hide on downward scroll',
    breadcrumb: 'Settings › Home & Navigation › Lists & Navigation',
    keywords: const ['navigation', 'dock', 'header', 'scroll', 'hide'],
    open: () =>
        const HomeSettingsScreen(highlightId: 'appearance.auto_hide_bars'),
  ),
  SettingsDestination(
    anchorId: 'appearance.cover_sizing',
    icon: AppIcons.photoSize,
    title: 'Player Cover Sizing',
    subtitle: 'Auto-fit or preserve source aspect ratio',
    breadcrumb: 'Settings › Appearance › Now Playing',
    keywords: const ['artwork', 'album art', 'aspect', 'crop'],
    open: () =>
        const AppearanceSettingsScreen(highlightId: 'appearance.cover_sizing'),
  ),
  SettingsDestination(
    anchorId: 'appearance.full_bleed_design',
    icon: AppIcons.autoAwesome,
    title: 'Immersive design',
    subtitle: 'Full-bleed player cover and gradient detail screens',
    breadcrumb: 'Settings › Appearance › Now Playing',
    keywords: const [
      'immersive',
      'full bleed',
      'player',
      'detail',
      'gradient',
      'cover',
      'design'
    ],
    open: () => const AppearanceSettingsScreen(
      highlightId: 'appearance.full_bleed_design',
    ),
  ),
  SettingsDestination(
    anchorId: 'appearance.app_icon',
    icon: AppIcons.album,
    title: 'App icon',
    subtitle: 'Choose which icon wispie uses',
    breadcrumb: 'Settings › Appearance › App icon',
    keywords: const ['icon', 'logo', 'launcher', 'dock', 'classic', 'new'],
    open: () =>
        const AppearanceSettingsScreen(highlightId: 'appearance.app_icon'),
  ),
  SettingsDestination(
    anchorId: 'appearance.beat_cover',
    icon: AppIcons.album,
    title: 'Beat-reactive cover',
    subtitle: 'Album art pulses with the beat (classic player only)',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const ['pulse', 'beat', 'artwork', 'motion'],
    open: () =>
        const AppearanceSettingsScreen(highlightId: 'appearance.beat_cover'),
  ),
  SettingsDestination(
    anchorId: 'appearance.spin_artwork',
    icon: AppIcons.album,
    title: 'Spin artwork while playing',
    subtitle: 'Artwork turns in the minimized bottom bar while a song plays',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const ['rotate', 'turn', 'spin', 'artwork', 'dock', 'mini'],
    open: () => const AppearanceSettingsScreen(
      highlightId: 'appearance.spin_artwork',
    ),
  ),
  SettingsDestination(
    anchorId: 'appearance.beat_particles',
    icon: AppIcons.autoAwesome,
    title: 'Beat-reactive particles',
    subtitle: 'Floating particles that drift and breathe with the music',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const ['particles', 'motes', 'beat', 'motion'],
    open: () => const AppearanceSettingsScreen(
      highlightId: 'appearance.beat_particles',
    ),
  ),
  SettingsDestination(
    anchorId: 'appearance.cover_intensity',
    icon: AppIcons.album,
    title: 'Cover intensity',
    subtitle: 'How strongly the album art reacts to the beat',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const ['cover', 'album', 'pulse', 'subtle', 'balanced', 'bold'],
    open: () => const AppearanceSettingsScreen(
        highlightId: 'appearance.cover_intensity'),
  ),
  SettingsDestination(
    anchorId: 'appearance.particle_intensity',
    icon: AppIcons.autoAwesome,
    title: 'Particle density',
    subtitle: 'How many particles and how lively they are',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const [
      'particles',
      'motes',
      'density',
      'subtle',
      'balanced',
      'bold'
    ],
    open: () => const AppearanceSettingsScreen(
      highlightId: 'appearance.particle_intensity',
    ),
  ),
  SettingsDestination(
    anchorId: 'appearance.beat_offset',
    icon: AppIcons.syncAlt,
    title: 'Beat sync offset',
    subtitle: 'Compensate for Bluetooth output latency',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const ['bluetooth', 'latency', 'delay', 'sync', 'early'],
    open: () =>
        const AppearanceSettingsScreen(highlightId: 'appearance.beat_offset'),
  ),
  SettingsDestination(
    anchorId: 'appearance.beat_calibrate',
    icon: AppIcons.syncAlt,
    title: 'Calibrate beat sync',
    subtitle: 'Line up particles with a click track by ear',
    breadcrumb: 'Settings › Appearance › Player motion',
    keywords: const ['calibrate', 'sync', 'latency', 'offset', 'test', 'click'],
    open: () => const AppearanceSettingsScreen(
      highlightId: 'appearance.beat_calibrate',
    ),
  ),
  SettingsDestination(
    anchorId: 'appearance.quick_picks',
    icon: AppIcons.autoAwesome,
    title: 'Quick Picks',
    subtitle: 'Show quick pick recommendations',
    breadcrumb: 'Settings › Home & Navigation › Home screen',
    keywords: const ['home', 'recommendations', 'suggestions'],
    open: () => const HomeSettingsScreen(highlightId: 'appearance.quick_picks'),
  ),
  SettingsDestination(
    anchorId: 'appearance.recent_queues',
    icon: AppIcons.clock,
    title: 'Recent Queues',
    subtitle: 'Show recently played queues',
    breadcrumb: 'Settings › Home & Navigation › Home screen',
    keywords: const ['home', 'history', 'queue'],
    open: () =>
        const HomeSettingsScreen(highlightId: 'appearance.recent_queues'),
  ),
  SettingsDestination(
    anchorId: 'appearance.for_you',
    icon: AppIcons.explore,
    title: 'For You',
    subtitle: 'Show recommended playlists',
    breadcrumb: 'Settings › Home & Navigation › Home screen',
    keywords: const ['home', 'mixes', 'recommendations'],
    open: () => const HomeSettingsScreen(highlightId: 'appearance.for_you'),
  ),
  SettingsDestination(
    anchorId: 'appearance.quick_actions',
    icon: AppIcons.flashOn,
    title: 'Quick Actions',
    subtitle: 'Customize long-press actions',
    breadcrumb: 'Settings › Home & Navigation › Lists & Navigation',
    keywords: const ['long press', 'menu', 'shortcuts'],
    open: () =>
        const HomeSettingsScreen(highlightId: 'appearance.quick_actions'),
  ),
  SettingsDestination(
    icon: AppIcons.flashOn,
    title: 'Reorder quick actions',
    subtitle: 'Choose and order the long-press actions on a song',
    breadcrumb: 'Settings › Appearance › Lists & Navigation',
    keywords: const ['long press', 'order', 'menu', 'shortcuts'],
    open: () => const QuickActionsSettingsScreen(),
  ),

  // ------------------------------------------------------------------- data
  SettingsDestination(
    anchorId: 'data.export',
    icon: AppIcons.upload,
    title: 'Export App Data',
    subtitle: 'Backup your stats, favorites, and playlists',
    breadcrumb: 'Settings › Backup & Restore',
    keywords: const ['backup', 'save', 'export'],
    open: () => const BackupSettingsScreen(highlightId: 'data.export'),
  ),
  SettingsDestination(
    anchorId: 'data.import',
    icon: AppIcons.download,
    title: 'Import App Data',
    subtitle: 'Restore data from a backup (replaces all)',
    breadcrumb: 'Settings › Backup & Restore',
    keywords: const ['restore', 'load', 'import'],
    open: () => const BackupSettingsScreen(highlightId: 'data.import'),
  ),
  SettingsDestination(
    anchorId: 'data.backups',
    icon: AppIcons.cloudUpload,
    title: 'Manage Backups',
    subtitle: 'Create, restore, and manage app backups',
    breadcrumb: 'Settings › Backup & Restore',
    keywords: const ['backup', 'restore', 'delete'],
    open: () => const BackupSettingsScreen(highlightId: 'data.backups'),
  ),
  SettingsDestination(
    anchorId: 'data.bulk_rename',
    icon: AppIcons.edit,
    title: 'Bulk Rename Files',
    subtitle: 'Rename the whole library from a format',
    breadcrumb: 'Settings › Library › Maintenance',
    keywords: const [
      'rename',
      'filenames',
      'batch',
      'bulk',
      'format',
      'naming'
    ],
    open: () => const LibrarySettingsScreen(
      highlightId: 'data.bulk_rename',
    ),
  ),
  SettingsDestination(
    anchorId: 'data.storage',
    icon: AppIcons.storage,
    title: 'Manage Storage',
    subtitle: 'Disk usage and data management',
    breadcrumb: 'Settings › Storage',
    keywords: const ['disk', 'space', 'cache', 'cleanup'],
    open: () => const StorageSettingsScreen(highlightId: 'data.storage'),
  ),
  SettingsDestination(
    icon: AppIcons.cloudUpload,
    title: 'Backups',
    subtitle: 'Browse, restore and delete saved backups',
    breadcrumb: 'Settings › Data Management › Manage Backups',
    keywords: const ['backup', 'restore', 'archive'],
    open: () => const BackupManagementScreen(),
  ),
  SettingsDestination(
    icon: AppIcons.storage,
    title: 'Storage',
    subtitle: 'Disk usage by covers, waveforms, lyrics and caches',
    breadcrumb: 'Settings › Data Management › Manage Storage',
    keywords: const ['disk', 'space', 'clear cache', 'usage'],
    open: () => const StorageManagementScreen(),
  ),

  // ------------------------------------------------------ automatic backups
  SettingsDestination(
    anchorId: 'data.auto_backup',
    icon: AppIcons.cloudUpload,
    title: 'Auto Backup',
    subtitle: 'How often a backup is taken',
    breadcrumb: 'Settings › Backup & Restore › Automatic Backups',
    keywords: const ['schedule', 'frequency', 'automatic'],
    open: () => const BackupSettingsScreen(highlightId: 'data.auto_backup'),
  ),
  SettingsDestination(
    anchorId: 'data.auto_backup_content',
    icon: AppIcons.tune,
    title: 'Auto Backup Content',
    subtitle: 'What data is included in automatic backups',
    breadcrumb: 'Settings › Backup & Restore › Automatic Backups',
    keywords: const ['contents', 'categories', 'automatic'],
    open: () =>
        const BackupSettingsScreen(highlightId: 'data.auto_backup_content'),
  ),
  SettingsDestination(
    anchorId: 'data.auto_delete_backups',
    icon: AppIcons.delete,
    title: 'Auto-Delete Old Backups',
    subtitle: 'Discard backups older than this',
    breadcrumb: 'Settings › Backup & Restore › Automatic Backups',
    keywords: const ['prune', 'cleanup', 'retention', 'old'],
    open: () =>
        const BackupSettingsScreen(highlightId: 'data.auto_delete_backups'),
  ),
  SettingsDestination(
    anchorId: 'library.pull_to_refresh',
    icon: AppIcons.touchApp,
    title: 'Pull to Refresh',
    subtitle: 'Swipe down to refresh the library',
    breadcrumb: 'Settings › Library',
    keywords: const ['swipe', 'gesture', 'reload'],
    open: () =>
        const LibrarySettingsScreen(highlightId: 'library.pull_to_refresh'),
  ),

  // ---------------------------------------------------------------- shuffle
  SettingsDestination(
    icon: AppIcons.tune,
    title: 'Configure Custom Shuffle',
    subtitle: 'Adjust shuffle behavior settings',
    breadcrumb: 'Profile › Shuffle',
    keywords: const [
      'shuffle',
      'personality',
      'weights',
      'random',
      'explorer',
    ],
    open: () => const CustomShuffleSettingsScreen(),
  ),
];
