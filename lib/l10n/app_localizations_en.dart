// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow system language';

  @override
  String get languageNativeName => 'English';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPageLibrarySubtitle => 'Folders, filters, scanning';

  @override
  String get settingsPagePlaybackTitle => 'Playback';

  @override
  String get settingsPagePlaybackSubtitle => 'Transitions, fades, audio';

  @override
  String get settingsPageLyricsTitle => 'Lyrics';

  @override
  String get settingsPageLyricsSubtitle => 'Word sync, translation, sidebar';

  @override
  String get settingsPageAppearanceTitle => 'Appearance';

  @override
  String get settingsPageAppearanceSubtitle => 'Now playing, motion, app icon';

  @override
  String get settingsPageHomeNavigationTitle => 'Home & Navigation';

  @override
  String get settingsPageHomeNavigationSubtitle =>
      'Home sections, lists, quick actions';

  @override
  String get settingsPageSyncTitle => 'Sync';

  @override
  String get settingsPageSyncSubtitle => 'Encrypted cross-device sync';

  @override
  String get settingsPageBackupRestoreTitle => 'Backup & Restore';

  @override
  String get settingsPageBackupRestoreSubtitle =>
      'Export, import, automatic backups';

  @override
  String get settingsPageStorageTitle => 'Storage';

  @override
  String get settingsPageStorageSubtitle => 'Disk usage, indexes, caches';

  @override
  String get settingsPageAboutTitle => 'About';

  @override
  String get settingsPageAboutSubtitle => 'Version, updates, release notes';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionDone => 'Done';

  @override
  String get actionChange => 'Change';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionHide => 'Hide';

  @override
  String get actionDeletePermanently => 'Delete Permanently';

  @override
  String get actionBack => 'Back';

  @override
  String get actionClose => 'Close';

  @override
  String get playlistNewTitle => 'New Playlist';

  @override
  String get playlistNameHint => 'Playlist Name';

  @override
  String playlistCreated(Object name) {
    return 'Created playlist \"$name\"';
  }

  @override
  String songFavoriteRemoved(Object title) {
    return 'Removed $title from favorites';
  }

  @override
  String songFavoriteAdded(Object title) {
    return 'Added $title to favorites';
  }

  @override
  String songWillSuggestMore(Object title) {
    return 'Will suggest $title more often';
  }

  @override
  String songWillSuggestLess(Object title) {
    return 'Will suggest $title less often';
  }

  @override
  String songAddedToNextUp(Object title) {
    return 'Added to Next Up: $title';
  }

  @override
  String songShareText(Object artist, Object title) {
    return '$title by $artist';
  }

  @override
  String songAddedToPlaylist(Object name) {
    return 'Added to $name';
  }

  @override
  String songRemovedFromPlaylist(Object title) {
    return 'Removed $title from playlist';
  }

  @override
  String songMovedTo(Object path, Object title) {
    return 'Moved $title to $path';
  }

  @override
  String songMoveError(Object error) {
    return 'Error moving song: $error';
  }

  @override
  String songRemovedFromLibrary(Object title) {
    return 'Removed $title from library';
  }

  @override
  String get songDeleteTitle => 'Delete Song';

  @override
  String songDeleteConfirm(Object title) {
    return 'Are you sure you want to permanently delete \'\'$title\'\' from your device? This cannot be undone.';
  }

  @override
  String songDeleted(Object title) {
    return 'Deleted $title';
  }

  @override
  String songDeleteError(Object error) {
    return 'Error deleting file: $error';
  }

  @override
  String get coverSearching =>
      'Searching Last.fm, Deezer and iTunes for cover art...';

  @override
  String get coverNoneFound => 'No missing cover art found online';

  @override
  String coverUpdated(Object source, Object title) {
    return 'Updated cover art for \"$title\" ($source)';
  }

  @override
  String get coverDownloadFailed => 'Failed to download cover art';

  @override
  String coverFetchError(Object error) {
    return 'Error fetching cover: $error';
  }

  @override
  String get metaResultsTitle => 'Metadata Fetch Results';

  @override
  String get metaFetchingTitle => 'Fetching Missing Metadata';

  @override
  String get metaStatUpdated => 'Updated';

  @override
  String get metaStatNotFound => 'Not Found';

  @override
  String get metaStatSkipped => 'Skipped';

  @override
  String get metaUndoAll => 'Undo All';

  @override
  String get metaUndoSong => 'Undo this song';

  @override
  String metaRevertedCount(int count) {
    return 'Reverted metadata changes for $count track(s)';
  }

  @override
  String metaViaSource(Object source) {
    return 'via $source';
  }

  @override
  String metaMoreItems(int count) {
    return '... and $count more';
  }

  @override
  String get metaCouldNotFind => 'Could Not Find';

  @override
  String get metaUnknownArtist => 'Unknown Artist';

  @override
  String metaAllHaveMetadata(int count) {
    return 'All $count tracks already have metadata';
  }

  @override
  String get metaNoMissingMetadata => 'No tracks with missing metadata found';

  @override
  String metaSearchingBatch(int batch) {
    return 'Searching batch $batch...';
  }

  @override
  String metaCancelledSummary(int updated, int notFound) {
    return 'Metadata fetch cancelled ($updated updated, $notFound not found)';
  }

  @override
  String get songMenuTitle => 'Song Options';

  @override
  String get songMenuPlaybackHint => 'Queue, playlist, and share actions';

  @override
  String get songMenuLibraryHint => 'Move song and edit metadata';

  @override
  String get songMenuPersonalize => 'Personalize';

  @override
  String get songMenuPersonalizeHint => 'Favorite and recommendation settings';

  @override
  String get songMenuDanger => 'Danger Zone';

  @override
  String get songMenuDangerHint => 'Remove from playlist or delete song';

  @override
  String get songMenuPlayNext => 'Play Next';

  @override
  String get songMenuPlayNextHint =>
      'Add song to play immediately after current track';

  @override
  String get songMenuPlayNextDuplicate => 'Play Next (Allow Duplicate)';

  @override
  String get songMenuPlayNextDuplicateHint =>
      'Add again even if already in queue';

  @override
  String get songMenuAddToPlaylist => 'Add to Playlist';

  @override
  String get songMenuAddToPlaylistHint =>
      'Quick add to your most recent playlist';

  @override
  String get songMenuAddToNewPlaylist => 'Add to New Playlist';

  @override
  String get songMenuAddToNewPlaylistHint =>
      'Create a playlist and add this song';

  @override
  String get songMenuShare => 'Share';

  @override
  String get songMenuShareHint => 'Share the audio file externally';

  @override
  String get songMenuFetchCover => 'Fetch Missing Cover';

  @override
  String get songMenuFetchCoverHint =>
      'Try searching Last.fm, Deezer and iTunes for cover art';

  @override
  String get songMenuFetchMetadata => 'Fetch Missing Metadata';

  @override
  String get songMenuFetchMetadataHint =>
      'Search online for title, artist, album and cover';

  @override
  String get songMenuMoveToFolder => 'Move to Folder';

  @override
  String get songMenuMoveToFolderHint => 'Move this file to another folder';

  @override
  String get songMenuManagePlaylists => 'Manage Playlists';

  @override
  String get songMenuManagePlaylistsHint => 'Add or remove from playlists';

  @override
  String get songMenuEditMetadata => 'Edit Metadata';

  @override
  String get songMenuEditMetadataHint => 'Open metadata editor';

  @override
  String get songMenuRemoveFavorite => 'Remove from Favorites';

  @override
  String get songMenuAddFavorite => 'Add to Favorites';

  @override
  String get songMenuFavoritesHint => 'Tune your favorite songs list';

  @override
  String get songMenuSuggestMore => 'Suggest More';

  @override
  String get songMenuSuggestLess => 'Suggest Less';

  @override
  String get songMenuSuggestHint =>
      'Adjust how often this song appears in suggestions';

  @override
  String get songMenuRemoveFromPlaylist => 'Remove from Current Playlist';

  @override
  String get songMenuRemoveFromPlaylistHint =>
      'Keep file, remove playlist mapping';

  @override
  String get songMenuRemoveFromLibrary => 'Remove from Library';

  @override
  String get songMenuRemoveFromLibraryHint =>
      'Keep file but hide from the library';

  @override
  String get songMenuDeleteHint => 'Delete the file from the device';

  @override
  String get bulkSelected => 'selected';

  @override
  String get bulkSelectAll => 'Select all';

  @override
  String get bulkFavorite => 'Favorite';

  @override
  String get bulkUnfavorite => 'Unfavorite';

  @override
  String bulkRemovedFromFavorites(int count) {
    return 'Removed $count songs from favorites';
  }

  @override
  String bulkAddedToFavorites(int count) {
    return 'Added $count songs to favorites';
  }

  @override
  String get bulkPlaylist => 'Playlist';

  @override
  String bulkAddedToPlaylist(int count, Object name) {
    return 'Added $count songs to $name';
  }

  @override
  String bulkSongsCount(int count) {
    return '$count songs';
  }

  @override
  String get bulkMetadata => 'Metadata';

  @override
  String get bulkHideTitle => 'Hide Songs';

  @override
  String bulkHideMessage(int count) {
    return 'Hide $count selected songs from library?';
  }

  @override
  String get bulkDeleteTitle => 'Delete Files';

  @override
  String bulkDeleteMessage(int count) {
    return 'Permanently delete $count files from storage? This cannot be undone.';
  }

  @override
  String bulkAddedToQueue(int count) {
    return 'Added $count songs to queue';
  }

  @override
  String get bulkMove => 'Move';

  @override
  String bulkMovedTo(int count, Object path) {
    return 'Moved $count songs to $path';
  }

  @override
  String bulkMoveError(Object error) {
    return 'Error moving songs: $error';
  }

  @override
  String bulkWillSuggestMore(int count) {
    return 'Will suggest $count songs more';
  }

  @override
  String bulkWillSuggestLess(int count) {
    return 'Will suggest $count songs less';
  }

  @override
  String get queueTabUpNext => 'Up Next';

  @override
  String get queueTabHistory => 'History';

  @override
  String get queueActionMoveToTop => 'Move to top';

  @override
  String get queueActionRemove => 'Remove';

  @override
  String get queueActionSongOptions => 'Song options…';

  @override
  String get queueClearDialogTitle => 'Clear Queue?';

  @override
  String get queueClearDialogMessage =>
      'This will remove all upcoming songs from the current queue.';

  @override
  String get queueClearAll => 'Clear All';

  @override
  String get queueSectionPlayed => 'Played';

  @override
  String get queueSectionNowPlaying => 'Now playing';

  @override
  String get queueSectionUpNext => 'Up next';

  @override
  String get queueSwipeAddToTop => 'Add to top';

  @override
  String get queueShuffleUpcomingTooltip => 'Shuffle upcoming';

  @override
  String get queueClearUpcomingTooltip => 'Clear upcoming';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String queueRemainingSuffix(String remaining) {
    return '  ·  $remaining';
  }

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get queueRemoveFromQueueTooltip => 'Remove from queue';

  @override
  String queueRemovedTitle(String title) {
    return 'Removed $title';
  }

  @override
  String get queueUndo => 'Undo';

  @override
  String get historyClearDialogTitle => 'Clear History?';

  @override
  String get historyClearDialogMessage =>
      'This will delete every saved queue snapshot.';

  @override
  String historyRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restored $count tracks',
      one: 'Restored 1 track',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadError => 'Could not load history';

  @override
  String get historyEmptyTitle => 'No past queues';

  @override
  String get historyEmptyMessage =>
      'Queues you play get saved here automatically.';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved queues',
      one: '1 saved queue',
    );
    return '$_temp0';
  }

  @override
  String get historyClearAllTrailing => 'Clear all';

  @override
  String get historyDayToday => 'Today';

  @override
  String get historyDayYesterday => 'Yesterday';

  @override
  String get historyDayThisWeek => 'This week';

  @override
  String get historyDayThisMonth => 'This month';

  @override
  String get historyDayEarlier => 'Earlier';

  @override
  String get snapshotShuffledQueue => 'Shuffled queue';

  @override
  String get snapshotSavedQueue => 'Saved queue';

  @override
  String get snapshotEmptyTracks =>
      'None of these tracks are still in your library.';

  @override
  String snapshotMoreHidden(int count) {
    return '+$count more';
  }

  @override
  String snapshotMissingCount(int count) {
    return '$count missing from library';
  }

  @override
  String get queueMetaSeparator => ' · ';

  @override
  String get songListShuffle => 'Shuffle';

  @override
  String get songListPlay => 'Play';

  @override
  String get songListPause => 'Pause';

  @override
  String get songListResume => 'Resume';

  @override
  String get songListFetchArtistCover => 'Fetch Artist Cover Online';

  @override
  String get songListFetchAlbumCover => 'Fetch Album Cover Online';

  @override
  String get songListFetchCover => 'Fetch Cover Online';

  @override
  String get songListPlaylistOptions => 'Playlist Options';

  @override
  String get songListSelectSongsToMerge => 'Select Songs to Merge';

  @override
  String songListMergedSongs(int count) {
    return 'Merged $count songs';
  }

  @override
  String songListMergeError(Object error) {
    return 'Error: $error';
  }

  @override
  String get songListMergeSongs => 'Merge Songs';

  @override
  String get songListEmpty => 'No songs in this list';

  @override
  String get actionRename => 'Rename';

  @override
  String get songListRenamePlaylist => 'Rename Playlist';

  @override
  String get songListDeletePlaylist => 'Delete Playlist';

  @override
  String songListDeletePlaylistConfirm(Object title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String songListSearchingArtwork(Object name) {
    return 'Searching online for $name artwork...';
  }

  @override
  String songListSelectArtwork(Object name) {
    return 'Select Artwork for $name';
  }

  @override
  String get songListUseSongCoverGrid => 'Use Song Cover Grid';

  @override
  String get songListRemoveCustomArtwork => 'Remove custom artwork';

  @override
  String get songListChooseCustomImage => 'Choose Custom Image';

  @override
  String get songListSelectFromDevice => 'Select image from device storage';

  @override
  String songListArtworkFrom(Object source) {
    return 'Artwork from $source';
  }

  @override
  String get songListNoOnlineArtwork => 'No online artwork options found';

  @override
  String get songListResetArtwork => 'Reset to song cover grid';

  @override
  String songListArtworkUpdated(Object name) {
    return 'Updated artwork for $name';
  }

  @override
  String get songListDownloadingArtwork => 'Downloading artwork...';

  @override
  String get songListArtworkDownloadFailed => 'Failed to download artwork';

  @override
  String get gradientDetailAlbums => 'Albums';

  @override
  String get gradientDetailSongs => 'Songs';

  @override
  String get gradientDetailShowAll => 'Show all';

  @override
  String gradientDetailAlbumCount(int count) {
    return '$count albums';
  }

  @override
  String get syncPlayStats => 'Play stats';

  @override
  String get syncPlayStatsHint => 'Listening history and play counts';

  @override
  String get syncFavoritesHint => 'Favorite songs';

  @override
  String get syncSuggestLess => 'Suggest less';

  @override
  String get syncSuggestLessHint => 'Songs you asked to see less of';

  @override
  String get syncHiddenSongs => 'Hidden songs';

  @override
  String get syncPlaylistsHint => 'All playlists';

  @override
  String get syncMergedSongs => 'Merged songs';

  @override
  String get syncMergedSongsHint => 'Merged song groups';

  @override
  String get syncAppSettings => 'App settings';

  @override
  String get syncAppSettingsHint => 'Theme, playback, and UI preferences';

  @override
  String get syncArtistArt => 'Artist art';

  @override
  String get syncArtistArtHint => 'Online artist cover choices';

  @override
  String get syncAlbumArt => 'Album art';

  @override
  String get syncAlbumArtHint => 'Online album cover choices';

  @override
  String get syncQueueHistory => 'Queue history';

  @override
  String get syncQueueHistoryHint => 'Recently played queues';

  @override
  String get syncCurrentQueue => 'Current queue';

  @override
  String get syncCurrentQueueHint =>
      'Uploaded automatically; downloaded only when you sync manually';

  @override
  String get syncPreferCloudQueue => 'Prefer cloud queue';

  @override
  String get syncPreferCloudQueueHint =>
      'On: Sync now replaces this device\'s queue with the cloud queue. Off: this device\'s queue is kept and uploaded.';

  @override
  String get syncPrivacy => 'Privacy';

  @override
  String get syncEncryptedTitle => 'End-to-end encrypted';

  @override
  String get syncEncryptedBody =>
      'Your data is encrypted on this device before upload. The server only stores ciphertext and cannot read your library, history, or settings.';

  @override
  String get syncRecoveryKeyTitle => 'Recovery key';

  @override
  String get syncRecoveryKeyBody =>
      'If you forget your password, only your recovery key can restore access. Nobody else can.';

  @override
  String get syncAccount => 'Account';

  @override
  String get syncSignedIn => 'Signed in';

  @override
  String get syncConnected => 'Connected';

  @override
  String get syncLogOut => 'Log out';

  @override
  String get syncLogOutBody =>
      'Sync stops on this device. Local and cloud data are both kept.';

  @override
  String get syncLogOutAndChange => 'Log out and change';

  @override
  String get syncCloud => 'Cloud';

  @override
  String get syncLastSynced => 'Last synced';

  @override
  String get syncNever => 'Never';

  @override
  String syncUsedOfQuota(Object used, Object quota) {
    return '$used of $quota used';
  }

  @override
  String get syncJustNow => 'Just now';

  @override
  String syncMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String syncHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String syncDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get syncAutoSync => 'Auto sync';

  @override
  String get syncAutoSyncHint => 'Sync in the background while the app is open';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncMergeDeviceHint => 'Merge this device with the cloud';

  @override
  String syncLastError(Object error) {
    return 'Last error: $error';
  }

  @override
  String get syncWhatGetsSynced => 'What gets synced';

  @override
  String get syncDeviceStatsAttribution => 'Device Stats Attribution';

  @override
  String get syncThisDevice => 'This Device';

  @override
  String get syncOtherDevices => 'Other Devices';

  @override
  String get syncTotalLibraryStats => 'Total Library Stats';

  @override
  String syncPlays(int count) {
    return '$count plays';
  }

  @override
  String get syncDangerZone => 'Danger zone';

  @override
  String get syncOverwriteCloudTile => 'Overwrite cloud with this device';

  @override
  String get syncOverwriteCloudTileHint =>
      'Replace all cloud data with what is on this device';

  @override
  String get syncReplaceDeviceTile => 'Replace this device with cloud';

  @override
  String get syncReplaceDeviceTileHint =>
      'Erase synced data on this device and use the cloud copy';

  @override
  String get syncChangePassword => 'Change password';

  @override
  String get syncNewRecoveryKey => 'New recovery key';

  @override
  String get syncNewRecoveryKeyHint => 'The old recovery key stops working';

  @override
  String get syncChangeServer => 'Change server';

  @override
  String get syncChangeServerHint => 'Requires logging out first';

  @override
  String get syncChangeServerBody =>
      'You will be logged out of the current server first. Local data is kept.';

  @override
  String get syncDeleteCloudAccount => 'Delete cloud account';

  @override
  String get syncDeleteCloudAccountHint =>
      'Removes cloud data permanently. Local data is kept';

  @override
  String get syncDeleteCloudAccountBody =>
      'Your cloud account and all encrypted data on the server are deleted permanently. Data on this device is kept.';

  @override
  String get syncOverwriteCloud => 'Overwrite cloud';

  @override
  String get syncOverwriteCloudBody =>
      'All data in the cloud will be replaced by this device. Other devices will be asked to choose how to continue. This device keeps its data.';

  @override
  String get syncOverwriteCloudCheckbox =>
      'I understand the cloud data will be lost';

  @override
  String get syncOverwrite => 'Overwrite';

  @override
  String get syncReplaceDevice => 'Replace this device';

  @override
  String get syncReplaceDeviceBody =>
      'Synced data on this device (stats, favorites, playlists, and so on) will be erased and replaced by the cloud copy. Music files are not touched.';

  @override
  String get syncReplaceDeviceCheckbox =>
      'I understand local synced data will be lost';

  @override
  String get syncReplace => 'Replace';

  @override
  String get syncCurrentPassword => 'Current password';

  @override
  String get syncNewPassword => 'New password';

  @override
  String get syncPassword => 'Password';

  @override
  String get syncPasswordChanged => 'Password changed';

  @override
  String get syncGenerate => 'Generate';

  @override
  String get appearanceGroupNowPlaying => 'Now Playing';

  @override
  String get appearanceVisualizerTitle => 'Audio Visualizer';

  @override
  String get appearanceVisualizerSubtitle =>
      'Bars over the artwork while playing — synced follows the song, bass on the left';

  @override
  String get appearanceVisualizerClassic => 'Classic';

  @override
  String get appearanceVisualizerSynced => 'Synced';

  @override
  String get appearanceProgressBarTitle => 'Progress Bar Style';

  @override
  String get appearanceProgressBasicSubtitle => 'Simple line progress bar';

  @override
  String get appearanceProgressWaveformSubtitle => 'Static audio waveform';

  @override
  String get appearanceProgressReactiveSubtitle =>
      'Sound-reactive dynamic waveform with live spectrum & beat response';

  @override
  String get appearanceProgressStandard => 'Standard';

  @override
  String get appearanceProgressWaveform => 'Waveform';

  @override
  String get appearanceProgressSoundReactive => 'Sound Reactive';

  @override
  String get appearanceHapticsTitle => 'Waveform Scrubbing Haptics';

  @override
  String get appearanceHapticsSubtitle =>
      'Haptic feedback for each bar while seeking';

  @override
  String get appearanceCoverSizingTitle => 'Player Cover Sizing';

  @override
  String get appearanceCoverSizingSubtitle =>
      'Auto-fit or preserve source aspect ratio';

  @override
  String get appearanceCoverAutoFit => 'Auto Fit';

  @override
  String get appearanceCoverSourceSize => 'Source Size';

  @override
  String get appearanceImmersiveTitle => 'Immersive design';

  @override
  String get appearanceImmersiveSubtitle =>
      'Full-bleed player cover and gradient detail screens';

  @override
  String get appearancePlayerSwipeTitle => 'Swipe changes pane';

  @override
  String get appearancePlayerSwipeSubtitle =>
      'Left and right swipes move between lyrics, player and queue. Turn off to switch tracks instead.';

  @override
  String get appearanceGroupPlayerMotion => 'Player motion';

  @override
  String get appearanceBeatCoverTitle => 'Beat-reactive cover';

  @override
  String get appearanceBeatCoverUnavailable =>
      'Unavailable while immersive design is on';

  @override
  String get appearanceBeatCoverSubtitle => 'Album art pulses with the beat';

  @override
  String get appearanceCoverIntensityTitle => 'Cover intensity';

  @override
  String get appearanceCoverIntensitySubtitle =>
      'How strongly the cover reacts';

  @override
  String get appearanceSpinArtworkTitle => 'Spin artwork while playing';

  @override
  String get appearanceSpinArtworkSubtitle =>
      'Artwork turns slowly in the minimized bottom bar while a song plays';

  @override
  String get appearanceParticlesTitle => 'Beat-reactive particles';

  @override
  String get appearanceParticlesSubtitle =>
      'Floating particles that drift and breathe with the music';

  @override
  String get appearanceParticleDensityTitle => 'Particle density';

  @override
  String get appearanceParticleDensitySubtitle =>
      'How many particles and how lively';

  @override
  String get appearanceBeatOffsetTitle => 'Beat sync offset';

  @override
  String get appearanceBeatOffsetNone =>
      'No offset — raise it if the pulse feels early';

  @override
  String appearanceBeatOffsetValue(int ms) {
    return '$ms ms';
  }

  @override
  String appearanceBeatOffsetBluetooth(int ms) {
    return '$ms ms (raise for Bluetooth)';
  }

  @override
  String get appearanceCalibrateTitle => 'Calibrate beat sync';

  @override
  String get appearanceCalibrateSubtitle =>
      'Line up particles with a click track by ear';

  @override
  String get appearanceAppIcon => 'App icon';

  @override
  String get appearanceIntensityMin => 'Min';

  @override
  String get appearanceIntensitySubtle => 'Subtle';

  @override
  String get appearanceIntensityBalanced => 'Balanced';

  @override
  String get appearanceIntensityBold => 'Bold';

  @override
  String get appearanceIntensityMax => 'Max';

  @override
  String get appearanceIntensityCustom => 'Custom';

  @override
  String get backupExportAppData => 'Export App Data';

  @override
  String get backupExportAppDataSubtitle =>
      'Backup your stats, favorites, and playlists';

  @override
  String backupExportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get backupImportAppData => 'Import App Data';

  @override
  String get backupImportAppDataSubtitle =>
      'Restore data from a backup (replaces all)';

  @override
  String get backupManageBackups => 'Manage Backups';

  @override
  String get backupManageBackupsSubtitle =>
      'Create, restore, and manage app backups';

  @override
  String get backupAutomaticBackups => 'Automatic Backups';

  @override
  String get backupAutoBackup => 'Auto Backup';

  @override
  String get backupAutoBackupSubtitle => 'How often a backup is taken';

  @override
  String get backupAutoBackupContent => 'Auto Backup Content';

  @override
  String get backupAutoBackupContentSubtitle =>
      'What data is included in automatic backups';

  @override
  String get backupAutoBackupContentDialogSubtitle =>
      'Select content for automatic backups';

  @override
  String get backupSave => 'Save';

  @override
  String get backupAutoDeleteOld => 'Auto-Delete Old Backups';

  @override
  String get backupAutoDeleteOldSubtitle => 'Discard backups older than this';

  @override
  String get backupFrequencyDisabled => 'Disabled';

  @override
  String get backupFrequencyEvery24Hours => 'Every 24 hours';

  @override
  String get backupFrequencyEvery48Hours => 'Every 48 hours';

  @override
  String get backupFrequencyEvery3Days => 'Every 3 days';

  @override
  String get backupFrequencyEvery7Days => 'Every 7 days';

  @override
  String backupDeleteAfterDays(int count) {
    return '$count days';
  }

  @override
  String get backupExportOptionsTitle => 'Export Options';

  @override
  String get backupExportSelectContent => 'Select content to export:';

  @override
  String get backupContentUserStats => 'User Stats';

  @override
  String get backupContentUserStatsSubtitle =>
      'Play counts, sessions, fun stats';

  @override
  String get backupContentUserData => 'User Data';

  @override
  String get backupContentUserDataSubtitle => 'Favorites, hidden, playlists';

  @override
  String get backupContentUserSettings => 'User Settings';

  @override
  String get backupContentUserSettingsSubtitle =>
      'Theme, sort order, preferences';

  @override
  String get backupContentCoverCacheSubtitle => 'Album artwork images';

  @override
  String get backupContentLibraryCacheSubtitle => 'Cached song metadata';

  @override
  String get backupContentSearchIndexSubtitle => 'Indexed search data';

  @override
  String get backupContentWaveformCacheSubtitle => 'Audio waveform data';

  @override
  String get backupContentColorCacheSubtitle => 'Album color themes';

  @override
  String get backupContentLyricsCacheSubtitle => 'Stored lyrics data';

  @override
  String get backupCancelUpper => 'CANCEL';

  @override
  String get backupExportUpper => 'EXPORT';

  @override
  String get backupContinueUpper => 'CONTINUE';

  @override
  String get backupImportDataTitle => 'Import Data';

  @override
  String get backupImportWarning =>
      'This will replace ALL existing data with the imported data.\n\nYour current stats, favorites, playlists, and settings will be overwritten.\n\nThis action cannot be undone.';

  @override
  String get backupImportingLabel => 'Importing…';

  @override
  String get backupImportingTitle => 'Importing data';

  @override
  String get backupImportSuccess => 'Import successful!';

  @override
  String backupImportFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get metadataCoverUpdated => 'Cover updated successfully';

  @override
  String metadataPickImageError(Object error) {
    return 'Error picking image: $error';
  }

  @override
  String get metadataRemoveCoverTitle => 'Remove Cover';

  @override
  String get metadataRemoveCoverBody =>
      'Are you sure you want to remove the cover art?';

  @override
  String get metadataRemoveUpper => 'REMOVE';

  @override
  String get metadataCoverRemoved => 'Cover removed';

  @override
  String metadataRemoveCoverError(Object error) {
    return 'Error removing cover: $error';
  }

  @override
  String get metadataFixResultTitle => 'Fix Thumbnail Result';

  @override
  String get metadataFixReviewBody => 'Review the changes below:';

  @override
  String get metadataFixOriginal => 'Original';

  @override
  String get metadataFixNew => 'New';

  @override
  String metadataFixNewOption(int n) {
    return 'New (Option $n)';
  }

  @override
  String get metadataFixSeeAlternatives => 'See Alternatives';

  @override
  String get metadataFixApply => 'Apply';

  @override
  String get metadataFixSuccess => 'Thumbnail fixed successfully';

  @override
  String metadataFixError(Object error) {
    return 'Error fixing thumbnail: $error';
  }

  @override
  String get metadataFixThumbnail => 'Fix Thumbnail';

  @override
  String get metadataFixHelpBody =>
      'This tool automatically improves your album art by:\n\n1. Detecting and removing black bars/borders (common in YouTube thumbnails)\n2. Cropping the image to a perfect square (1:1 ratio)\n\nBest used for converting 16:9 thumbnails into proper album covers.';

  @override
  String get metadataGotIt => 'Got it';

  @override
  String get metadataExportCover => 'Export Cover';

  @override
  String get metadataExport => 'Export';

  @override
  String metadataExportSuccess(Object uri) {
    return 'Cover exported to $uri';
  }

  @override
  String metadataExportError(Object error) {
    return 'Error exporting cover: $error';
  }

  @override
  String get metadataReplaceSong => 'Replace Song';

  @override
  String get metadataReplaceHelpBody =>
      'Swaps this song\'\'s file for another copy of the same song (better rip, lossless, clean encode).\n\nPlay history, favourites, playlists and library date move to the new file. Its metadata is re-read from the file, and anything it lacks shows as unknown.\n\nThe new file must be outside your library folders and have a different filename.';

  @override
  String metadataReplaced(Object filename) {
    return 'Replaced with $filename';
  }

  @override
  String metadataReplaceError(Object error) {
    return 'Could not replace the file: $error';
  }

  @override
  String metadataReplaceFilesBody(Object oldName, Object newName) {
    return '$oldName\nreplaced by $newName';
  }

  @override
  String get metadataReplaceOriginalQuestion =>
      'What should happen to the original?';

  @override
  String get metadataReplaceRejectNoFile => 'No file was selected.';

  @override
  String get metadataReplaceRejectUnsupported =>
      'That file is not an audio or video format this library can read.';

  @override
  String get metadataReplaceRejectSameFilename =>
      'The replacement needs a different filename. Changing only the extension is enough.';

  @override
  String get metadataReplaceRejectInsideLibrary =>
      'That file is inside one of your library folders. Pick a copy from somewhere outside your library.';

  @override
  String metadataReplaceRejectDestinationExists(String filename) {
    return 'A file named \"$filename\" already sits next to the original.';
  }

  @override
  String metadataReplaceRejectLibraryHasName(String filename) {
    return 'Your library already has a song named \"$filename\".';
  }

  @override
  String get metadataKeepHideUpper => 'KEEP, HIDE IT';

  @override
  String get metadataDeleteItUpper => 'DELETE IT';

  @override
  String get metadataSaved => 'Metadata updated successfully';

  @override
  String metadataSaveError(Object error) {
    return 'Error saving metadata: $error';
  }

  @override
  String get metadataNoOnlineCover => 'No online cover art found';

  @override
  String get metadataSelectCoverTitle => 'Select Cover Art';

  @override
  String metadataResultTitleArtist(Object title, Object artist) {
    return '$title - $artist';
  }

  @override
  String metadataSourceLabel(Object source) {
    return 'Source: $source';
  }

  @override
  String metadataCoverUpdatedFrom(Object source) {
    return 'Cover updated from $source';
  }

  @override
  String get metadataNoOnlineMatch => 'No matching metadata found online';

  @override
  String get metadataSelectMatchTitle => 'Select Online Match';

  @override
  String metadataResultDetail(Object artist, Object album, Object source) {
    return '$artist · $album ($source)';
  }

  @override
  String metadataLoadedFrom(Object source) {
    return 'Metadata & cover loaded from $source';
  }

  @override
  String metadataFetchError(Object error) {
    return 'Error fetching metadata: $error';
  }

  @override
  String get metadataSectionCover => 'Cover Art';

  @override
  String get metadataChangeCover => 'Change Cover';

  @override
  String get metadataWhatDoesThisDo => 'What does this do?';

  @override
  String get metadataSectionFile => 'File Information';

  @override
  String get metadataFilenameLabel => 'Filename (without extension)';

  @override
  String get metadataFilenameHelper =>
      'Renaming the file will update it locally.';

  @override
  String get metadataSectionSong => 'Song Metadata';

  @override
  String get metadataFetchOnline => 'Fetch Online';

  @override
  String get metadataTitleLabel => 'Title';

  @override
  String get metadataArtistLabel => 'Artist';

  @override
  String get metadataAlbumLabel => 'Album';

  @override
  String get metadataSectionExtra => 'Additional Content';

  @override
  String get metadataEditLyrics => 'Edit Lyrics';

  @override
  String get metadataEditLyricsSubtitle => 'View or edit embedded lyrics';

  @override
  String get metadataSaveUpper => 'SAVE';

  @override
  String metadataLyricsLoadError(Object error) {
    return 'Error loading lyrics: $error';
  }

  @override
  String metadataLyricsSaveError(Object error) {
    return 'Error saving lyrics: $error';
  }

  @override
  String get metadataLyricsLoaded => 'Lyrics loaded — press SAVE to apply';

  @override
  String get metadataSearchOnline => 'Search online';

  @override
  String get metadataLyricsHint =>
      'Lyrics are embedded in the audio file. You can use [mm:ss.xx] timestamps for synced lyrics.';

  @override
  String get metadataLyricsFieldHint => 'Enter lyrics here...';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAvatarFallback => 'U';

  @override
  String get profileDefaultName => 'User';

  @override
  String profileAppVersion(String version) {
    return 'wispie v$version';
  }

  @override
  String get profileHidden => 'Hidden';

  @override
  String get profileSuggestLess => 'Suggest-less';

  @override
  String get profileShuffleSection => 'Shuffle Personality';

  @override
  String get profileSmart => 'Smart';

  @override
  String get profileSmartSubtitle =>
      'Learns your taste, trends and context. Recommended';

  @override
  String get profileDefault => 'Default';

  @override
  String get profileDefaultSubtitle => 'Balanced mix with anti-repeat';

  @override
  String get profileExplorer => 'Explorer';

  @override
  String get profileExplorerSubtitle => 'Prioritizes new & rare songs';

  @override
  String get profileConsistent => 'Consistent';

  @override
  String get profileConsistentSubtitle => 'Favorites heavy';

  @override
  String get profileCustomSubtitle => 'Configure your own shuffle';

  @override
  String get profileChangeName => 'Change Display Name';

  @override
  String get profileNewNameHint => 'New name';

  @override
  String get profileUpdate => 'Update';

  @override
  String get profileNameUpdated => 'Name updated';

  @override
  String profileCurrentName(String name) {
    return 'Current: $name';
  }

  @override
  String get profilePersonalitySaved => 'Personality saved';

  @override
  String get profileAppliesNextQueue => 'Applies to the next queue';

  @override
  String get profileConfigureCustomShuffle => 'Configure Custom Shuffle';

  @override
  String get profileConfigureCustomShuffleSubtitle =>
      'Adjust shuffle behavior settings';

  @override
  String get profileThemeStorage => 'Theme & storage';

  @override
  String get profileFamiliar => 'Familiar';

  @override
  String get profileDiscover => 'Discover';

  @override
  String get profileFamiliarToDiscover => 'Familiar to Discover';

  @override
  String get profileLegacyCaption =>
      'Legacy: fixed behaviour, kept for compatibility';

  @override
  String get storageManageTitle => 'Manage Storage';

  @override
  String get storageRepairCardTitle => 'Repair Library Links';

  @override
  String get storageRepairCardBody =>
      'Missing album art after a restore or a new phone? This re-links artwork and file paths.';

  @override
  String get storageRepair => 'Repair';

  @override
  String get storageRepairTitle => 'Repair Library Links?';

  @override
  String get storageRepairBody =>
      'This re-links cached album art and file paths to where they actually are on this device.\n\nTracks whose files are no longer here will be removed from the library. Favourites, playlists and play counts are kept, and reattach automatically if those files come back.';

  @override
  String storageRepairError(Object error) {
    return 'Error repairing library: $error';
  }

  @override
  String get storageDatabaseTitle => 'Database';

  @override
  String get storageDatabaseSubtitle => 'User data, statistics, and settings';

  @override
  String get storageCoverCacheTitle => 'Cover Cache';

  @override
  String get storageCoverCacheSubtitle => 'Cached song album art';

  @override
  String get storageBackupsTitle => 'Backups';

  @override
  String get storageBackupsSubtitle => 'Local backup files';

  @override
  String get storageLibraryCacheTitle => 'Library Cache';

  @override
  String get storageLibraryCacheSubtitle => 'Cached song library data';

  @override
  String get storageSearchIndexTitle => 'Search Index';

  @override
  String get storageSearchIndexSubtitle => 'Search index for fast queries';

  @override
  String get storageWaveformCacheTitle => 'Waveform Cache';

  @override
  String get storageWaveformCacheSubtitle =>
      'Cached song waveforms for visualizers';

  @override
  String get storageBeatAnalysisTitle => 'Beat Analysis';

  @override
  String get storageBeatAnalysisSubtitle =>
      'Cached beat maps for the reactive player';

  @override
  String get storageColorCacheTitle => 'Color Cache';

  @override
  String get storageColorCacheSubtitle => 'Cached theme colors from album art';

  @override
  String get storageLyricsCacheTitle => 'Lyrics Cache';

  @override
  String get storageLyricsCacheSubtitle =>
      'Cached lyrics availability and text';

  @override
  String get storageBlurredCacheTitle => 'Blurred Cache';

  @override
  String get storageBlurredCacheSubtitle => 'Pre-generated blurred backgrounds';

  @override
  String get storageClearCache => 'Clear Cache';

  @override
  String get storageClearDatabaseTitle => 'Clear Database?';

  @override
  String get storageClearDatabaseBody =>
      'This will permanently delete all your user data, including:\n\n• All playlists\n• Favorites and hidden songs\n• Playback statistics\n• App settings and preferences\n\nThe app will reset. This action cannot be undone.';

  @override
  String get storageClearDatabaseAction => 'Clear Database';

  @override
  String storageClearDatabaseError(Object error) {
    return 'Error clearing database: $error';
  }

  @override
  String get storageClearCoversTitle => 'Clear Cover Cache?';

  @override
  String get storageClearCoversBody =>
      'This will delete all cached album artwork.\n\nThe covers will be re-extracted from your music files the next time you browse your library.';

  @override
  String get storageClearCoversAction => 'Clear Covers';

  @override
  String get storageClearCoversSuccess => 'Cover cache cleared successfully';

  @override
  String storageClearCoversError(Object error) {
    return 'Error clearing covers: $error';
  }

  @override
  String get storageClearBackupsTitle => 'Clear Backups?';

  @override
  String get storageClearBackupsBody =>
      'This will delete all local backup files.\n\nMake sure you have exported any important backups before proceeding.';

  @override
  String get storageClearBackupsAction => 'Clear Backups';

  @override
  String get storageClearBackupsSuccess => 'Backups cleared successfully';

  @override
  String storageClearBackupsError(Object error) {
    return 'Error clearing backups: $error';
  }

  @override
  String get storageClearLibraryTitle => 'Clear Library Cache?';

  @override
  String get storageClearLibraryBody =>
      'This will clear the library cache.\n\nYour music library will be rescanned the next time you open the app.';

  @override
  String get storageClearLibrarySuccess => 'Library cache cleared successfully';

  @override
  String storageClearLibraryError(Object error) {
    return 'Error clearing library cache: $error';
  }

  @override
  String get storageClearSearchTitle => 'Clear Search Index?';

  @override
  String get storageClearSearchBody =>
      'This will delete the search index.\n\nThe search index will be rebuilt automatically when you rescan your library.';

  @override
  String get storageClearSearchAction => 'Clear Index';

  @override
  String get storageClearSearchSuccess => 'Search index cleared successfully';

  @override
  String storageClearSearchError(Object error) {
    return 'Error clearing search index: $error';
  }

  @override
  String get storageClearWaveformTitle => 'Clear Waveform Cache?';

  @override
  String get storageClearWaveformBody =>
      'This will delete all cached song waveforms.\n\nWaveforms will be regenerated the next time you view song details.';

  @override
  String get storageClearWaveformSuccess =>
      'Waveform cache cleared successfully';

  @override
  String storageClearWaveformError(Object error) {
    return 'Error clearing waveform cache: $error';
  }

  @override
  String get storageClearBeatTitle => 'Clear Beat Analysis?';

  @override
  String get storageClearBeatBody =>
      'This will delete the cached beat maps used by the beat-reactive player.\n\nThey are rebuilt automatically the next time each song plays.';

  @override
  String get storageClearBeatSuccess =>
      'Beat analysis cache cleared successfully';

  @override
  String storageClearBeatError(Object error) {
    return 'Error clearing beat analysis cache: $error';
  }

  @override
  String get storageClearColorTitle => 'Clear Color Cache?';

  @override
  String get storageClearColorBody =>
      'This will delete all cached theme colors.\n\nColors will be re-extracted from album art the next time songs are played.';

  @override
  String get storageClearColorSuccess => 'Color cache cleared successfully';

  @override
  String storageClearColorError(Object error) {
    return 'Error clearing color cache: $error';
  }

  @override
  String get storageClearLyricsTitle => 'Clear Lyrics Cache?';

  @override
  String get storageClearLyricsBody =>
      'This will remove cached lyrics lookups.\n\nLyrics will be re-read from song metadata when needed.';

  @override
  String get storageClearLyricsSuccess => 'Lyrics cache cleared successfully';

  @override
  String storageClearLyricsError(Object error) {
    return 'Error clearing lyrics cache: $error';
  }

  @override
  String get storageClearBlurredTitle => 'Clear Blurred Background Cache?';

  @override
  String get storageClearBlurredBody =>
      'This will delete all pre-generated blurred backgrounds.\n\nThey will be re-generated the next time you trigger a rebuild in the Indexer.';

  @override
  String get storageClearBlurredSuccess =>
      'Blurred background cache cleared successfully';

  @override
  String storageClearBlurredError(Object error) {
    return 'Error clearing blurred cache: $error';
  }

  @override
  String get storageClearAllTitle => 'Clear All App Data?';

  @override
  String get storageClearAllBody =>
      'This action is dangerous and cannot be undone.\n\nIt will permanently delete:\n• All your preferences and settings\n• Playback statistics and history\n• Cached song covers\n• All local backups\n• Library cache\n• Search index\n• Waveform cache\n• Lyrics cache\n\nThe app will reset.';

  @override
  String get storageClearAllAction => 'Clear Everything';

  @override
  String storageClearAllError(Object error) {
    return 'Error clearing data: $error';
  }

  @override
  String get storageClearAllTile => 'Clear All User Data';

  @override
  String get storageClearAllTileSubtitle =>
      'Permanently delete all data and reset app';

  @override
  String get storageFinalConfirmTitle => 'Final Confirmation';

  @override
  String storageConfirmTypePrompt(Object word) {
    return 'To confirm, type \"$word\" below:';
  }

  @override
  String get storageDeleteKeyword => 'DELETE';

  @override
  String get storageConfirmUpper => 'CONFIRM';

  @override
  String get storageTypeExactly => 'Please type the confirmation text exactly.';

  @override
  String storageSizeBytes(Object value) {
    return '$value B';
  }

  @override
  String storageSizeKb(Object value) {
    return '$value KB';
  }

  @override
  String storageSizeMb(Object value) {
    return '$value MB';
  }

  @override
  String storageSizeGb(Object value) {
    return '$value GB';
  }

  @override
  String get settingsSearchIndexerSubtitle => 'Rebuild indexes and caches';

  @override
  String get settingsSearchMusicFoldersTitle => 'Music Folders';

  @override
  String get settingsSearchMusicFoldersSubtitle =>
      'Manage music library folders';

  @override
  String get settingsSearchRescanTitle => 'Re-scan Library Now';

  @override
  String get settingsSearchRescanSubtitle =>
      'Manually refresh all songs from disk';

  @override
  String get settingsSearchIncludeVideosTitle => 'Include Videos';

  @override
  String get settingsSearchIncludeVideosSubtitle =>
      'Show video files in your song library';

  @override
  String get settingsSearchMinFileSizeTitle => 'Minimum File Size';

  @override
  String get settingsSearchMinFileSizeSubtitle =>
      'Ignore files smaller than this';

  @override
  String get settingsSearchMinDurationTitle => 'Minimum Duration';

  @override
  String get settingsSearchMinDurationSubtitle =>
      'Ignore tracks shorter than this';

  @override
  String get settingsSearchManageFoldersTitle => 'Manage music folders';

  @override
  String get settingsSearchManageFoldersSubtitle =>
      'Add, remove and rescan individual folders';

  @override
  String get settingsSearchPullToRefreshTitle => 'Pull to Refresh';

  @override
  String get settingsSearchPullToRefreshSubtitle =>
      'Swipe down to refresh the library';

  @override
  String get settingsSearchAutoPauseMuteTitle => 'Auto-Pause on Mute';

  @override
  String get settingsSearchAutoPauseMuteSubtitle =>
      'Pause playback when volume reaches 0';

  @override
  String get settingsSearchAutoResumeUnmuteTitle => 'Auto-Resume on Unmute';

  @override
  String get settingsSearchAutoResumeUnmuteSubtitle =>
      'Resume playback when volume is restored';

  @override
  String get settingsSearchGapTitle => 'Gap / Delay';

  @override
  String get settingsSearchGapSubtitle => 'Silence between tracks';

  @override
  String get settingsSearchFadeOutTitle => 'Fade Out';

  @override
  String get settingsSearchFadeOutSubtitle => 'Fade the outgoing track';

  @override
  String get settingsSearchFadeInTitle => 'Fade In';

  @override
  String get settingsSearchFadeInSubtitle => 'Fade the incoming track';

  @override
  String get settingsSearchFadePlayTitle => 'Fade on Play';

  @override
  String get settingsSearchFadePlaySubtitle =>
      'Ease the volume up when playback starts';

  @override
  String get settingsSearchFadePauseTitle => 'Fade on Pause';

  @override
  String get settingsSearchFadePauseSubtitle =>
      'Ease the volume down when playback stops';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Language to translate lyrics into';

  @override
  String get settingsSearchTranslationModeSubtitle =>
      'Show subtext below lyrics or replace base lyrics';

  @override
  String get settingsSearchVisualizerSubtitle =>
      'Off, classic bars, or bars synced to the song';

  @override
  String get settingsSearchLanguageSubtitle => 'Choose the app language';

  @override
  String get settingsSearchProgressBarSubtitle =>
      'Standard, waveform, or sound-reactive progress bar';

  @override
  String get settingsSearchSongDurationTitle => 'Show Song Duration';

  @override
  String get settingsSearchSongDurationSubtitle =>
      'Display duration in song lists';

  @override
  String get settingsSearchAutoHideBarsTitle => 'Auto-Hide Bars';

  @override
  String get settingsSearchAutoHideBarsSubtitle =>
      'Header and bottom dock hide on downward scroll';

  @override
  String get settingsSearchAppIconSubtitle => 'Choose which icon wispie uses';

  @override
  String get settingsSearchBeatCoverSubtitle =>
      'Album art pulses with the beat (classic player only)';

  @override
  String get settingsSearchSpinArtworkSubtitle =>
      'Artwork turns in the minimized bottom bar while a song plays';

  @override
  String get settingsSearchCoverIntensitySubtitle =>
      'How strongly the album art reacts to the beat';

  @override
  String get settingsSearchParticleDensitySubtitle =>
      'How many particles and how lively they are';

  @override
  String get settingsSearchBeatOffsetSubtitle =>
      'Compensate for Bluetooth output latency';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Show quick pick recommendations';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Show recently played queues';

  @override
  String get settingsSearchForYouSubtitle => 'Show recommended playlists';

  @override
  String get settingsSearchQuickActionsSubtitle =>
      'Customize long-press actions';

  @override
  String get settingsSearchReorderQuickActionsTitle => 'Reorder quick actions';

  @override
  String get settingsSearchReorderQuickActionsSubtitle =>
      'Choose and order the long-press actions on a song';

  @override
  String get settingsSearchBulkRenameTitle => 'Bulk Rename Files';

  @override
  String get settingsSearchBulkRenameSubtitle =>
      'Rename the whole library from a format';

  @override
  String get settingsSearchManageStorageSubtitle =>
      'Disk usage and data management';

  @override
  String get settingsSearchBackupsSubtitle =>
      'Browse, restore and delete saved backups';

  @override
  String get settingsSearchStorageUsageSubtitle =>
      'Disk usage by covers, waveforms, lyrics and caches';

  @override
  String get settingsCrumbStorage => 'Settings › Storage';

  @override
  String get settingsCrumbLibrary => 'Settings › Library';

  @override
  String get settingsCrumbLibraryFilters => 'Settings › Library › Filters';

  @override
  String get settingsCrumbLibraryFolders =>
      'Settings › Library › Music Folders';

  @override
  String get settingsCrumbLibraryMaintenance =>
      'Settings › Library › Maintenance';

  @override
  String get settingsCrumbPlaybackAudio => 'Settings › Playback › Audio';

  @override
  String get settingsCrumbPlaybackTransitions =>
      'Settings › Playback › Transitions';

  @override
  String get settingsCrumbPlaybackPlayPause =>
      'Settings › Playback › Play / Pause';

  @override
  String get settingsCrumbLyricsTiming =>
      'Settings › Lyrics › Display & Timing';

  @override
  String get settingsCrumbLyricsTranslation =>
      'Settings › Lyrics › Translation';

  @override
  String get settingsCrumbAppearanceLanguage =>
      'Settings › Appearance › Language';

  @override
  String get settingsCrumbAppearanceNowPlaying =>
      'Settings › Appearance › Now Playing';

  @override
  String get settingsCrumbAppearanceAppIcon =>
      'Settings › Appearance › App icon';

  @override
  String get settingsCrumbAppearanceMotion =>
      'Settings › Appearance › Player motion';

  @override
  String get settingsCrumbAppearanceLists =>
      'Settings › Appearance › Lists & Navigation';

  @override
  String get settingsCrumbHomeLists =>
      'Settings › Home & Navigation › Lists & Navigation';

  @override
  String get settingsCrumbHomeScreen =>
      'Settings › Home & Navigation › Home screen';

  @override
  String get settingsCrumbBackup => 'Settings › Backup & Restore';

  @override
  String get settingsCrumbAutoBackups =>
      'Settings › Backup & Restore › Automatic Backups';

  @override
  String get settingsCrumbManageBackups =>
      'Settings › Data Management › Manage Backups';

  @override
  String get settingsCrumbManageStorage =>
      'Settings › Data Management › Manage Storage';

  @override
  String get settingsCrumbProfileShuffle => 'Profile › Shuffle';

  @override
  String get settingsKwLibrary => 'scan,folders,filters,songs';

  @override
  String get settingsKwPlayback => 'audio,sound,transitions';

  @override
  String get settingsKwLyrics => 'lyrics,translate,karaoke,subtitles';

  @override
  String get settingsKwHome => 'home,quick picks,gestures,bars,layout';

  @override
  String get settingsKwStorage => 'disk,space,cache,indexer,cleanup';

  @override
  String get settingsKwAppearance => 'theme,colour,color,display,look';

  @override
  String get settingsKwSync => 'cloud,account,devices,encrypted';

  @override
  String get settingsKwBackup => 'backup,restore,export,import,data';

  @override
  String get settingsKwIndexer => 'index,rebuild,cache,reindex';

  @override
  String get settingsKwAbout => 'version,update,changelog,release';

  @override
  String get settingsKwFolders => 'directory,path,add folder,sources';

  @override
  String get settingsKwRescan => 'refresh,reload,sync';

  @override
  String get settingsKwVideos => 'video,mp4,clips';

  @override
  String get settingsKwMinFileSize => 'size,skip,small,filter';

  @override
  String get settingsKwMinDuration => 'length,short,skip,filter,interlude';

  @override
  String get settingsKwManageFolders => 'folder,directory,storage,sd card';

  @override
  String get settingsKwPullToRefresh => 'swipe,gesture,reload';

  @override
  String get settingsKwMute => 'volume,silent,mute';

  @override
  String get settingsKwUnmute => 'volume,unmute,continue';

  @override
  String get settingsKwGap => 'pause,silence,between,transition';

  @override
  String get settingsKwCrossfade => 'crossfade,gapless,transition,blend';

  @override
  String get settingsKwFadePlay => 'ramp,volume,start';

  @override
  String get settingsKwFadePause => 'ramp,volume,stop';

  @override
  String get settingsKwRichSync => 'lyrics,richsync,karaoke,word,sync';

  @override
  String get settingsKwSidebar => 'sidebar,panel,desktop,queue,lyrics';

  @override
  String get settingsKwPlayerSwipe =>
      'swipe,gesture,panes,lyrics,queue,skip,track';

  @override
  String get settingsKwKeepAwake => 'sleep,wakelock,display,lyrics';

  @override
  String get settingsKwAutoTranslate =>
      'translate,translation,language,lyrics,auto';

  @override
  String get settingsKwTargetLang =>
      'translate,language,spanish,english,japanese';

  @override
  String get settingsKwTranslationMode =>
      'translate,mode,subtext,replace,display';

  @override
  String get settingsKwVisualizer => 'wave,animation,spectrum,bars,sync,bass';

  @override
  String get settingsKwLanguage => 'language,locale,translation,english';

  @override
  String get settingsKwProgressBar => 'seek,progress,wave,reactive,spectrum';

  @override
  String get settingsKwHaptics => 'vibrate,haptic,feedback,waveform,scrub,seek';

  @override
  String get settingsKwSongDuration => 'length,time,lists';

  @override
  String get settingsKwAutoHide => 'navigation,dock,header,scroll,hide';

  @override
  String get settingsKwCoverSizing => 'artwork,album art,aspect,crop';

  @override
  String get settingsKwImmersive =>
      'immersive,full bleed,player,detail,gradient,cover,design';

  @override
  String get settingsKwAppIcon => 'icon,logo,launcher,dock,classic,new';

  @override
  String get settingsKwBeatCover => 'pulse,beat,artwork,motion';

  @override
  String get settingsKwSpinArtwork => 'rotate,turn,spin,artwork,dock,mini';

  @override
  String get settingsKwBeatParticles => 'particles,motes,beat,motion';

  @override
  String get settingsKwCoverIntensity =>
      'cover,album,pulse,subtle,balanced,bold';

  @override
  String get settingsKwParticleDensity =>
      'particles,motes,density,subtle,balanced,bold';

  @override
  String get settingsKwBeatOffset => 'bluetooth,latency,delay,sync,early';

  @override
  String get settingsKwCalibrate => 'calibrate,sync,latency,offset,test,click';

  @override
  String get settingsKwQuickPicks => 'home,recommendations,suggestions';

  @override
  String get settingsKwRecentQueues => 'home,history,queue';

  @override
  String get settingsKwForYou => 'home,mixes,recommendations';

  @override
  String get settingsKwQuickActions => 'long press,menu,shortcuts';

  @override
  String get settingsKwReorderQuickActions => 'long press,order,menu,shortcuts';

  @override
  String get settingsKwExport => 'backup,save,export';

  @override
  String get settingsKwImport => 'restore,load,import';

  @override
  String get settingsKwManageBackups => 'backup,restore,delete';

  @override
  String get settingsKwBulkRename =>
      'rename,filenames,batch,bulk,format,naming';

  @override
  String get settingsKwManageStorage => 'disk,space,cache,cleanup';

  @override
  String get settingsKwBackups => 'backup,restore,archive';

  @override
  String get settingsKwStorageUsage => 'disk,space,clear cache,usage';

  @override
  String get settingsKwAutoBackup => 'schedule,frequency,automatic';

  @override
  String get settingsKwAutoBackupContent => 'contents,categories,automatic';

  @override
  String get settingsKwAutoDelete => 'prune,cleanup,retention,old';

  @override
  String get settingsKwShuffle => 'shuffle,personality,weights,random,explorer';

  @override
  String get setupUnableToAccessFolder => 'Unable to access selected folder';

  @override
  String get setupStoragePermissionRequired =>
      'Storage permission is required to scan your music library.';

  @override
  String get setupEnterDisplayName => 'Please enter a display name';

  @override
  String setupSetupError(String error) {
    return 'Setup error: $error';
  }

  @override
  String get setupIntroTagline => 'Your music stays on your device.';

  @override
  String get setupGetStarted => 'Get started';

  @override
  String get setupPreviousStep => 'Previous step';

  @override
  String get setupSettingThingsUp => 'Setting things up';

  @override
  String get setupStartListening => 'Start listening';

  @override
  String get setupContinue => 'Continue';

  @override
  String get setupNameTitle => 'What should we call you?';

  @override
  String get setupNameSubtitle =>
      'wispie uses your name to greet you and to sign your listening history. Nothing leaves this device either way.';

  @override
  String get setupNameHint => 'Your name';

  @override
  String setupGreeting(String name) {
    return 'Nice to meet you, $name.';
  }

  @override
  String get setupAppearanceTitle => 'Make it look the way you like.';

  @override
  String get setupAppearanceSubtitle =>
      'Everything on this page also lives in Settings, so you can change it whenever you want.';

  @override
  String get setupImmersiveSubtitle =>
      'A full-bleed cover player and gradient detail screens.';

  @override
  String get setupVisualizerSubtitle =>
      'Bars over the artwork while you listen. Synced follows the song rather than a random pattern.';

  @override
  String get setupBeatCoverSubtitle => 'The album art breathes on every beat.';

  @override
  String get setupParticlesSubtitle =>
      'Motes drift across the player, and each beat carries them further instead of just blinking them.';

  @override
  String get setupProgressBarTitle => 'Progress bar';

  @override
  String get setupProgressBarSubtitle =>
      'Draw the song itself as a waveform instead of a plain line. Sound reactive makes it move as it plays.';

  @override
  String get setupFoldersTitle => 'Where is your music?';

  @override
  String get setupFoldersSubtitle =>
      'Point wispie at the folders your songs live in. It only reads them, and you can add as many as you like.';

  @override
  String get setupStoragePermissionTitle => 'Storage permission';

  @override
  String get setupStoragePermissionSubtitle =>
      'wispie needs it to find audio files on this device.';

  @override
  String get setupOpenSystemSettings => 'Open system settings';

  @override
  String get setupGrantPermission => 'Grant permission';

  @override
  String get setupNoFoldersTitle => 'No folders yet';

  @override
  String get setupNoFoldersSubtitle => 'Add the one that holds your songs.';

  @override
  String get setupRemoveFolderTooltip => 'Remove folder';

  @override
  String get setupAddFolder => 'Add a folder';

  @override
  String get setupSummaryMusicFolders => 'Music folders';

  @override
  String get setupReadyTitle => 'You are all set.';

  @override
  String setupReadyTitleNamed(String name) {
    return 'You are all set, $name.';
  }

  @override
  String get setupReadySubtitle =>
      'Here is what we set up. You can change any of it later from Settings.';

  @override
  String get setupOn => 'On';

  @override
  String get setupOff => 'Off';

  @override
  String backupLoadError(Object error) {
    return 'Error loading backups: $error';
  }

  @override
  String backupCreated(Object name) {
    return 'Backup created: $name';
  }

  @override
  String backupCreateFailed(Object error) {
    return 'Failed to create backup: $error';
  }

  @override
  String backupValidateFailed(Object error) {
    return 'Failed to validate backup: $error';
  }

  @override
  String get backupReplaceTitle => 'DANGER: Full Data Replace';

  @override
  String backupReplaceConfirm(Object name) {
    return 'Are you absolutely sure you want to restore from $name?';
  }

  @override
  String get backupReplaceWarning =>
      'WARNING: This will COMPLETELY REPLACE all your current data:';

  @override
  String get backupReplaceItemStats =>
      '• All your current statistics and play history';

  @override
  String get backupReplaceItemFavorites => '• All your favorites and playlists';

  @override
  String get backupReplaceItemHidden =>
      '• All your hidden songs and preferences';

  @override
  String get backupReplaceItemSettings =>
      '• All your current settings and state';

  @override
  String get backupReplaceItemLibrary => '• Your scanned song library';

  @override
  String get backupReplaceRekeyNote =>
      'Album art and file paths are re-linked to this device automatically after the restore. Tracks in the backup whose files are not on this device are removed from the library.';

  @override
  String get backupReplaceIrreversible =>
      'YOUR CURRENT DATA WILL BE PERMANENTLY LOST!';

  @override
  String get backupReplaceNoUndo => 'There is NO way to undo this action.';

  @override
  String get backupReplaceConfirmAction => 'YES, REPLACE EVERYTHING';

  @override
  String get backupRestoringLabel => 'Restoring data…';

  @override
  String get backupRestoreSuccess => 'All data replaced successfully!';

  @override
  String backupRestoreFailed(Object error) {
    return 'Failed to restore backup: $error';
  }

  @override
  String get backupDeleteTitle => 'Delete Backup';

  @override
  String backupDeleteConfirm(Object name) {
    return 'Are you sure you want to delete $name?';
  }

  @override
  String get backupDeleteUpper => 'DELETE';

  @override
  String get backupDeleted => 'Backup deleted';

  @override
  String backupDeleteFailed(Object error) {
    return 'Failed to delete backup: $error';
  }

  @override
  String backupExportedTo(Object path) {
    return 'Backup exported to: $path';
  }

  @override
  String get backupNoOlderBackup => 'No older backup to compare with.';

  @override
  String get backupComparing => 'Comparing backups...';

  @override
  String backupComparisonTitle(int number) {
    return 'Comparison with #$number';
  }

  @override
  String get backupDiffStatsRows => 'Stats Rows';

  @override
  String get backupDiffSize => 'Size';

  @override
  String get backupDiffDataAdded => 'Data Added';

  @override
  String get backupCloseUpper => 'CLOSE';

  @override
  String backupCompareError(Object error) {
    return 'Error comparing backups: $error';
  }

  @override
  String get backupNoChange => 'No change';

  @override
  String get backupManagementTitle => 'Backup Management';

  @override
  String get backupCreating => 'Creating...';

  @override
  String get backupCreateAction => 'Create Backup';

  @override
  String get backupEmptyTitle => 'No backups yet';

  @override
  String get backupEmptySubtitle =>
      'Create your first backup to protect your data';

  @override
  String backupSizeLabel(Object size) {
    return 'Size: $size';
  }

  @override
  String get backupActionRestore => 'Restore';

  @override
  String get backupActionCompare => 'Compare';

  @override
  String get backupRestartTitle => 'Restart Required';

  @override
  String get backupRestartMessage =>
      'Backup restore has been completed successfully.\n\nThe app needs to restart to apply all changes properly.';

  @override
  String get backupRestartNow => 'Restart Now';

  @override
  String get backupSelectContentSubtitle => 'Select content to backup';

  @override
  String get backupContentArtistArtCache => 'Artist Art Cache';

  @override
  String get backupContentAlbumArtCache => 'Album Art Cache';

  @override
  String get backupContentDescUserStats => 'Play history, stats, merged groups';

  @override
  String get backupContentDescUserData => 'Favorites, playlists, preferences';

  @override
  String get backupContentDescUserSettings =>
      'Theme, sort order, app preferences';

  @override
  String get backupContentDescCoverCache => 'Cached album artwork';

  @override
  String get backupContentDescLibraryCache => 'Cached metadata';

  @override
  String get backupContentDescSearchIndex => 'Search database';

  @override
  String get backupContentDescWaveformCache => 'Waveform data';

  @override
  String get backupContentDescColorCache => 'Color palettes';

  @override
  String get backupContentDescLyricsCache => 'Cached lyrics';

  @override
  String get backupContentDescArtistArtCache => 'Cached artist images';

  @override
  String get backupContentDescAlbumArtCache => 'Cached album images';

  @override
  String get backupRestoringDataTitle => 'Restoring data';

  @override
  String get importSelectTitle => 'Select Data to Restore';

  @override
  String get importSectionCache => 'Cache';

  @override
  String get importOptionsTitle => 'Restore Options';

  @override
  String get importReplaceDatabases => 'Replace Databases';

  @override
  String get importReplaceDatabasesSubtitle =>
      'Clear existing data before restoring';

  @override
  String get syncEnterPassword => 'Enter your password';

  @override
  String syncAuthUnexpectedError(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get syncUsernameTaken => 'That username is already taken';

  @override
  String get syncModeRecover => 'Recover';

  @override
  String get syncUsername => 'Username';

  @override
  String get syncEncryptionWarning =>
      'Your data is end-to-end encrypted. If you lose both your password and recovery key, it cannot be recovered.';

  @override
  String get syncSecuringAccount => 'Securing your account...';

  @override
  String get syncCreateAccount => 'Create account';

  @override
  String get syncLogIn => 'Log in';

  @override
  String get syncRecoverAccount => 'Recover account';

  @override
  String get syncHideAdvanced => 'Hide advanced';

  @override
  String get syncAdvanced => 'Advanced';

  @override
  String get syncRecoveryKeySaved => 'Recovery key saved';

  @override
  String get syncCouldNotSaveFile => 'Could not save file';

  @override
  String get syncRecoveryKeyRevealTitle => 'Your recovery key';

  @override
  String get syncRecoveryKeyRevealBody =>
      'This is the only way to regain access if you forget your password. It is shown once. Store it somewhere safe.';

  @override
  String get syncCopied => 'Copied';

  @override
  String get syncCopy => 'Copy';

  @override
  String get syncSaveToFile => 'Save to file';

  @override
  String get syncRecoveryKeySavedCheckbox => 'I saved my recovery key';

  @override
  String get syncUploadTitle => 'Upload your library data';

  @override
  String get syncSetupDeviceTitle => 'Set up this device';

  @override
  String get syncFreshAccountBody =>
      'Auto-sync turns on after your data is uploaded once.';

  @override
  String get syncChooseDeviceBody =>
      'Choose how this device joins your cloud data. Auto-sync turns on after this step.';

  @override
  String get syncEverythingNow => 'Sync everything now';

  @override
  String get syncMergeWithCloud => 'Merge this device with cloud';

  @override
  String get syncSetupNewDevice => 'Set up as new device';

  @override
  String get syncMergeExplanation =>
      'Merging keeps both sides. Setting up as a new device erases this device\'s synced data first and is safer if this device already holds an older copy of the same history.';

  @override
  String get syncCloudReplacedTitle => 'Cloud data was replaced';

  @override
  String get syncCloudReplacedBody =>
      'Another device overwrote the cloud. Sync is paused on this device until you choose.';

  @override
  String get syncMergeIntoCloud => 'Merge this device into the new cloud data';

  @override
  String get syncPhaseSigningIn => 'Signing in...';

  @override
  String get syncPhaseCheckingCloud => 'Checking cloud...';

  @override
  String get syncPhaseDownloadingBackup => 'Downloading backup...';

  @override
  String get syncPhaseApplyingBackup => 'Applying backup...';

  @override
  String get syncPhaseDownloadingChanges => 'Downloading changes...';

  @override
  String get syncPhaseMerging => 'Merging...';

  @override
  String get syncPhasePreparingUpload => 'Preparing upload...';

  @override
  String get syncPhaseEncrypting => 'Encrypting...';

  @override
  String get syncPhaseUploading => 'Uploading...';

  @override
  String get syncPhaseFinishing => 'Finishing up...';

  @override
  String get syncPhaseError => 'Sync failed';

  @override
  String get syncSyncing => 'Syncing...';

  @override
  String syncServerInfo(String name, String version) {
    return '$name - API v$version';
  }

  @override
  String syncServerInfoClosed(String name, String version) {
    return '$name - API v$version - registration closed';
  }

  @override
  String get syncServerUnreachable => 'Could not reach the server';

  @override
  String get syncInsecureHttpWarning =>
      'Plain http: only use on a trusted private network';

  @override
  String get syncServerUrl => 'Server URL';

  @override
  String get syncChecking => 'Checking...';

  @override
  String get syncCheckServer => 'Check server';

  @override
  String get syncResetDefault => 'Reset to default';

  @override
  String get autoBackupRunningTitle => 'Backing Up';

  @override
  String get autoBackupRunningSubtitle => 'Creating backup...';

  @override
  String get autoBackupCompleteTitle => 'Auto-Backup Complete';

  @override
  String get autoBackupSaved => 'Backup saved';

  @override
  String get autoBackupFailedTitle => 'Auto-Backup Failed';

  @override
  String get autoBackupPermissionTitle => 'Permission Required';

  @override
  String get autoBackupPermissionSubtitle => 'Auto-backup needs storage access';

  @override
  String get autoBackupGrant => 'Grant';

  @override
  String get downgradeTitle => 'Older version detected';

  @override
  String downgradeMessage(String previousVersion, String currentVersion) {
    return 'wispie was last opened on $previousVersion, but this is $currentVersion. Your data may have been changed by a newer version and could break or be lost on this one.';
  }

  @override
  String get downgradeQuit => 'Quit';

  @override
  String get downgradeRiskIt => 'Risk it';

  @override
  String get indexerSettingsGroupTitle => 'Indexer Settings';

  @override
  String get indexerPreventDuplicatesTitle => 'Prevent Duplicate Tracks';

  @override
  String get indexerPreventDuplicatesSubtitle =>
      'Hide songs with the same filename across folders';

  @override
  String get indexerExtractFeaturedTitle => 'Extract Featured Artists';

  @override
  String get indexerExtractFeaturedSubtitle =>
      'Move \"ft./feat.\" artists from title to artist field';

  @override
  String get indexerDatabaseOpsGroupTitle => 'Database Operations';

  @override
  String get indexerWarnRestart =>
      'This operation requires an app restart to apply changes.';

  @override
  String get indexerCoverSearchGroupTitle => 'Cover & Search';

  @override
  String get indexerWarnRepairLinks =>
      'Tracks whose files are no longer on this device will be removed from the library. Favourites, playlists and play counts are kept and reattach if the files come back.';

  @override
  String get indexerWarnSearchRestart =>
      'You may need to restart the app for search index changes to fully apply.';

  @override
  String get indexerContentCachesGroupTitle => 'Content Caches';

  @override
  String get indexerRecommendationsGroupTitle => 'Recommendations';

  @override
  String get indexerTitle => 'Indexer';

  @override
  String indexerArtistsAlbumsProgress(String artists, String albums) {
    return 'Artists $artists · Albums $albums...';
  }

  @override
  String indexerProcessing(String progress) {
    return 'Processing $progress...';
  }

  @override
  String get indexerUnknownError => 'Unknown error';

  @override
  String get indexerCompleted => 'Completed';

  @override
  String indexerCached(int processed, int total) {
    return '$processed/$total cached';
  }

  @override
  String indexerCachedFailed(int processed, int total, int failed) {
    return '$processed/$total cached ($failed failed)';
  }

  @override
  String get indexerReadyToRebuild => 'Ready to rebuild';

  @override
  String indexerArtistsOnly(String progress) {
    return 'Artists $progress';
  }

  @override
  String indexerAlbumsOnly(String progress) {
    return 'Albums $progress';
  }

  @override
  String indexerFailedItemsQuestion(int failed) {
    return 'This cache has $failed failed items. What would you like to do?';
  }

  @override
  String indexerViewFailed(int failed) {
    return 'View $failed Failed';
  }

  @override
  String get indexerRetryFailed => 'Retry Failed';

  @override
  String get indexerForceRebuild => 'Force Rebuild';

  @override
  String indexerAlreadyCompleteQuestion(int processed, int total) {
    return 'This cache is already complete ($processed/$total). Do you want to force rebuild it?';
  }

  @override
  String get indexerDoIt => 'Do It';

  @override
  String indexerOptimizing(String name) {
    return 'Optimizing $name...';
  }

  @override
  String get indexerDoNotClose => 'Please do not close the app';

  @override
  String get indexerRestartRequiredMessage =>
      'The operation has been completed successfully.\n\nThe app needs to restart to apply all changes properly.';

  @override
  String indexerFailedItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Failed Items',
      one: '1 Failed Item',
    );
    return '$_temp0';
  }

  @override
  String get indexerCouldNotProcess =>
      'The following items could not be processed:';

  @override
  String indexerWarningsTitle(String name) {
    return '$name Warnings';
  }

  @override
  String get indexerOk => 'OK';

  @override
  String get indexerJustMissing => 'Just Missing';

  @override
  String get indexerForceAll => 'Force All';

  @override
  String get beatSyncTitle => 'Beat sync';

  @override
  String get beatPlayToCalibrate => 'Play a song to calibrate.';

  @override
  String get beatAnalyzing => 'Analyzing beats...';

  @override
  String get beatNoClearBeat => 'No clear beat in this track.';

  @override
  String get beatDragInstruction =>
      'Drag until the particle bursts land on the clicks.';

  @override
  String beatOffsetMs(int value) {
    return '$value ms';
  }

  @override
  String get beatResetToZero => 'Reset to 0 ms';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryFoldersTab => 'Folders';

  @override
  String get libraryNoMusicFolderTitle => 'No music folder yet';

  @override
  String get libraryNoMusicFolderMessage =>
      'Select a music folder in Home to fill this out.';

  @override
  String get libraryFolderErrorTitle => 'Could not find your music folder';

  @override
  String get libraryLoadErrorTitle => 'Could not load library';

  @override
  String get libraryOpenFolderErrorTitle => 'Could not open folder';

  @override
  String get libraryNoMatchesTitle => 'No matches';

  @override
  String libraryNoMatchesMessage(String query) {
    return 'Nothing in your library matches \"$query\".';
  }

  @override
  String libraryFolderNoMatchesMessage(String query) {
    return 'Nothing in this folder matches \"$query\".';
  }

  @override
  String libraryCollectionNoMatchesMessage(String query) {
    return 'Nothing here matches \"$query\".';
  }

  @override
  String get libraryFavorites => 'Favorites';

  @override
  String libraryMergedGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String get libraryCreateMergeGroupTooltip => 'Create new merge group';

  @override
  String get libraryDeletePlaylist => 'Delete playlist';

  @override
  String get libraryPlaylistOptions => 'Playlist options';

  @override
  String get libraryFolderOptions => 'Folder options';

  @override
  String get libraryFilterAllHint => 'Filter folders, playlists, songs...';

  @override
  String get libraryFilterSongsHint => 'Filter folders, songs...';

  @override
  String get libraryFilterCollectionsHint => 'Filter artists, albums...';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'All';

  @override
  String get libraryShuffleFolderTooltip => 'Shuffle folder';

  @override
  String get libraryNoArtistsTitle => 'No artists yet';

  @override
  String get libraryNoAlbumsTitle => 'No albums yet';

  @override
  String get libraryScanToFillMessage =>
      'Scan a music folder to fill this out.';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionShuffleAll => 'Shuffle all';

  @override
  String get actionSeeAll => 'See All';

  @override
  String homeQueueCardSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$date · $_temp0';
  }

  @override
  String homePlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return 'Playing $_temp0';
  }

  @override
  String get homeOpenPlayer => 'Open Player';

  @override
  String get homePlayNow => 'Play Now';

  @override
  String homePlayAfterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks will play after the current song',
      one: '1 track will play after the current song',
    );
    return '$_temp0';
  }

  @override
  String get homePlayAfterCurrent => 'Play After Current Song';

  @override
  String get homeSaveToNewPlaylist => 'Save to new playlist';

  @override
  String get homeUnpin => 'Unpin';

  @override
  String get homePinRecommendation => 'Pin recommendation';

  @override
  String get homeRenameRecommendation => 'Rename recommendation';

  @override
  String get homeRenameRecommendationTitle => 'Rename Recommendation';

  @override
  String get homeRemoveRecommendation => 'Remove recommendation';

  @override
  String get homeRemoveRecommendationTitle => 'Remove recommendation?';

  @override
  String homeRemoveRecommendationMessage(String title) {
    return 'Are you sure you want to remove \"$title\"?';
  }

  @override
  String get homeErrorTitle => 'Something went wrong';

  @override
  String get homeTryAgain => 'Try Again';

  @override
  String get homeNoSongsTitle => 'No songs found';

  @override
  String get homeNoSongsMessage =>
      'Select your music folder to start listening offline.';

  @override
  String get homeSelectFolder => 'Select Music Folder';

  @override
  String get homeQuickPicks => 'Quick Picks';

  @override
  String get homeDailyDiscover => 'Daily Discover';

  @override
  String get homeRecentQueues => 'Recent Queues';

  @override
  String get homeForYou => 'For You';

  @override
  String get mergedTitle => 'Merged Songs';

  @override
  String get mergedCreateGroupTooltip => 'Create merge group';

  @override
  String mergedGroupsTab(int count) {
    return 'Groups ($count)';
  }

  @override
  String mergedAutoFindTab(int count) {
    return 'Auto-Find ($count)';
  }

  @override
  String mergedCreatedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Merged $count songs',
      one: 'Merged 1 song',
    );
    return '$_temp0';
  }

  @override
  String get mergedEmptyTitle => 'No merged songs yet';

  @override
  String get mergedEmptyBody =>
      'Group different versions of the same song (remixes, live versions, acoustics) so they share one spot during shuffle.';

  @override
  String get mergedCreateGroupButton => 'Create Merge Group';

  @override
  String mergedPrioritySet(String title) {
    return '\"$title\" set as priority song';
  }

  @override
  String get mergedPriorityCleared => 'Priority cleared';

  @override
  String get mergedNoCandidatesTitle => 'No candidate songs found';

  @override
  String get mergedNoCandidatesBody =>
      'No unmerged song variants (remixes, live versions, acoustics) were detected in your library.';

  @override
  String mergedFoundGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found $count potential groups to merge',
      one: 'Found 1 potential group to merge',
    );
    return '$_temp0';
  }

  @override
  String get mergedMergeAll => 'Merge All';

  @override
  String get mergedMergeAllTitle => 'Merge All Suggestions';

  @override
  String mergedMergeAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create $count merge groups for detected song variants?',
      one: 'Create 1 merge group for detected song variants?',
    );
    return '$_temp0';
  }

  @override
  String mergedCreatedGroupsSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Created $count merge groups',
      one: 'Created 1 merge group',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeTitle => 'Unmerge Song';

  @override
  String mergedUnmergeConfirm(String title) {
    return 'Remove \"$title\" from this merge group?';
  }

  @override
  String get mergedUnmergeAction => 'Unmerge';

  @override
  String mergedUnmergedSnack(String title) {
    return '\"$title\" unmerged';
  }

  @override
  String get mergedDeleteGroupTitle => 'Delete Merge Group';

  @override
  String get mergedDeleteGroupConfirm => 'Unmerge all songs in this group?';

  @override
  String get mergedUnmergeAllAction => 'Unmerge All';

  @override
  String get mergedGroupDeleted => 'Merge group deleted';

  @override
  String get mergedGroupLabel => 'Merge Group';

  @override
  String mergedVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versions',
      one: '1 version',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeAllTooltip => 'Unmerge all';

  @override
  String get mergedPriorityBadge => 'Priority';

  @override
  String get mergedPrioritySongTooltip => 'Priority song for shuffle';

  @override
  String get mergedSetPriorityTooltip => 'Set as priority song';

  @override
  String get mergedUnmergeSongTooltip => 'Unmerge song';

  @override
  String mergedSelectedCount(int selected, int total) {
    return '$selected/$total selected';
  }

  @override
  String get mergedMergeAction => 'Merge';

  @override
  String get sleepTimerTitle => 'Sleep Timer';

  @override
  String get sleepTimerModeLabel => 'Timer Mode';

  @override
  String get sleepTimerDurationLabel => 'Duration';

  @override
  String get sleepTimerMinSuffix => 'min';

  @override
  String get sleepTimerTracksLabel => 'Number of Tracks';

  @override
  String get sleepTimerLoopTitle => 'Loop Current Song';

  @override
  String get sleepTimerLoopSubtitle => 'Repeat the current song for a set time';

  @override
  String get sleepTimerPlayForTimeTitle => 'Play for Time';

  @override
  String get sleepTimerPlayForTimeSubtitle => 'Stop after a specified duration';

  @override
  String get sleepTimerStopAfterCurrentTitle => 'Stop After Current';

  @override
  String get sleepTimerStopAfterCurrentSubtitle =>
      'Stop when the current song ends';

  @override
  String get sleepTimerStopAfterTracksTitle => 'Stop After Tracks';

  @override
  String get sleepTimerStopAfterTracksSubtitle =>
      'Stop after playing X more songs';

  @override
  String get sleepTimerNoSong => 'No song is currently playing';

  @override
  String get sleepTimerCurrentSongLabel => 'Current song';

  @override
  String get sleepTimerLetFinishTitle => 'Let current song finish';

  @override
  String get sleepTimerLetFinishSubtitle =>
      'Wait for the current song to end before stopping';

  @override
  String get sleepTimerStopImmediatelySubtitle =>
      'Stop immediately when timer expires';

  @override
  String get sleepTimerStart => 'Start Timer';

  @override
  String get sleepTimerCancelActive => 'Cancel Active Timer';

  @override
  String get sleepTimerCancelled => 'Sleep timer cancelled';

  @override
  String get sleepTimerFinished => 'Sleep timer finished';

  @override
  String sleepTimerLoopingFor(int minutes) {
    return 'Looping current song for $minutes minutes';
  }

  @override
  String sleepTimerStopIn(int minutes) {
    return 'Music will stop in $minutes minutes';
  }

  @override
  String get sleepTimerStopAfterCurrent => 'Will stop after current song ends';

  @override
  String sleepTimerStopAfterTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Will stop after $count more songs',
      one: 'Will stop after 1 more song',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String get settingsValueNone => 'None';

  @override
  String settingsDurationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String settingsDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String settingsDurationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String get settingsGroupLookAndFeel => 'Look & Feel';

  @override
  String get settingsGroupData => 'Data';

  @override
  String get settingsGroupApp => 'App';

  @override
  String get settingsGroupFilters => 'Filters';

  @override
  String get settingsGroupMaintenance => 'Maintenance';

  @override
  String get settingsScanningLibrary => 'Scanning library…';

  @override
  String settingsResultsFor(String query) {
    return 'Results for \"$query\"';
  }

  @override
  String get settingsNoResultsTitle => 'No settings found';

  @override
  String settingsNoResultsMessage(String query) {
    return 'Nothing matches \"$query\".';
  }

  @override
  String get homeSettingsGroupLists => 'Lists & Navigation';

  @override
  String get homeSettingsAutoHideBarsSubtitle =>
      'Header and bottom dock hide on downward scroll, restore on upward scroll';

  @override
  String get homeSettingsGroupHome => 'Home screen';

  @override
  String get playbackGroupTransitions => 'Transitions';

  @override
  String get playbackGroupPlayPause => 'Play / Pause';

  @override
  String get playbackGroupAudio => 'Audio';

  @override
  String get playbackGapOff => 'Gap / Delay (off)';

  @override
  String get playbackFadeOutOff => 'Fade Out (off)';

  @override
  String get playbackFadeInOff => 'Fade In (off)';

  @override
  String playbackSecondsValue(String seconds) {
    return '${seconds}s';
  }

  @override
  String get playbackValueOneSecond => '1.0 s';

  @override
  String playbackValueMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get bulkRenameTokenCurrentName => 'Current name';

  @override
  String get bulkRenameTokenNumber => 'Number';

  @override
  String get bulkRenameTokenYear => 'Year';

  @override
  String bulkRenameAnalyzeError(String error) {
    return 'Could not analyze the library: $error';
  }

  @override
  String bulkRenameRenameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rename $count songs',
      one: 'Rename 1 song',
    );
    return '$_temp0';
  }

  @override
  String get bulkRenameConfirmMessage =>
      'Files are renamed in place. Play stats, playlists and cached artwork move across with them, and the database is kept in step as each file lands.';

  @override
  String get bulkRenameNothingLeft => 'Nothing left to rename';

  @override
  String get bulkRenamePhaseStarting => 'Starting';

  @override
  String get bulkRenameTitle => 'Bulk Rename';

  @override
  String get bulkRenameFormatArtistTitle => 'Artist - Title';

  @override
  String get bulkRenameFormatArtistAlbumTitle => 'Artist - Album - Title';

  @override
  String get bulkRenameCustomSubtitle => 'Your own arrangement';

  @override
  String get bulkRenameSectionFormat => 'FORMAT';

  @override
  String get bulkRenameSectionArrange => 'ARRANGE';

  @override
  String get bulkRenameSectionPreview => 'PREVIEW';

  @override
  String get bulkRenameEmptySegments =>
      'Add a field below to start building a name.';

  @override
  String get bulkRenameLiteralHint => 'Text, e.g. \" - \"';

  @override
  String get bulkRenameTextChip => 'Text';

  @override
  String get bulkRenameAnalyzing => 'Analyzing library';

  @override
  String bulkRenameCountToRename(int count) {
    return '$count to rename';
  }

  @override
  String bulkRenameSkippedCount(int count) {
    return '$count skipped';
  }

  @override
  String bulkRenameAndMore(int count) {
    return 'and $count more';
  }

  @override
  String bulkRenameChecking(int done, int total) {
    return 'Checking names — $done of $total';
  }

  @override
  String get bulkRenameStop => 'Stop';

  @override
  String get bulkRenameStopping => 'Stopping...';

  @override
  String get bulkRenamePleaseWait => 'Please wait';

  @override
  String bulkRenameProgressCount(int done, int total) {
    return '$done of $total';
  }

  @override
  String bulkRenameStopped(int count) {
    return 'Stopped after $count songs. Their stats and cached artwork moved across; the rest were left alone.';
  }

  @override
  String bulkRenameStoppedFailed(int count, int failed) {
    return 'Stopped after $count songs, $failed could not be renamed.';
  }

  @override
  String bulkRenameCompleted(int count) {
    return 'Renamed $count songs. Stats and cached artwork moved across.';
  }

  @override
  String bulkRenameCompletedFailed(int count, int failed) {
    return 'Renamed $count songs, $failed could not be renamed.';
  }

  @override
  String get bulkRenameFinishedTitle => 'Rename finished';

  @override
  String get bulkRenameSkipNoTitleText => 'No title text left after cleanup';

  @override
  String get bulkRenameSkipAlreadyNamed => 'Already named this';

  @override
  String bulkRenameSkipSameNameAs(String filename) {
    return 'Same name as \"$filename\" in this folder';
  }

  @override
  String get bulkRenameSkipAnotherSelected =>
      'Another selected song has that name';

  @override
  String get bulkRenameSkipFileExists =>
      'A file with that name is already here';

  @override
  String get shuffleResetDone => 'Settings reset to defaults';

  @override
  String get shuffleSaved => 'Settings saved';

  @override
  String get shuffleUnsavedTitle => 'Unsaved Changes';

  @override
  String get shuffleUnsavedMessage => 'Do you want to save your changes?';

  @override
  String get shuffleDiscard => 'Discard';

  @override
  String get shuffleTitle => 'Custom Shuffle Settings';

  @override
  String get shuffleReset => 'Reset';

  @override
  String get shuffleNextQueueNote => 'Changes will apply to next queue';

  @override
  String get shuffleBasicSettings => 'Basic Settings';

  @override
  String get shuffleAvoidSongsTitle => 'Avoid Repeating Songs';

  @override
  String get shuffleAvoidSongsSubtitle =>
      'Reduce chance of playing recently played songs';

  @override
  String get shuffleAvoidArtistsTitle => 'Avoid Repeating Artists';

  @override
  String get shuffleAvoidArtistsSubtitle =>
      'Reduce chance of playing same artist consecutively';

  @override
  String get shuffleAvoidAlbumsTitle => 'Avoid Repeating Albums';

  @override
  String get shuffleAvoidAlbumsSubtitle =>
      'Reduce chance of playing same album consecutively';

  @override
  String get shuffleAdvancedTitle => 'Advanced Settings';

  @override
  String get shuffleAdvancedSubtitle => 'Fine-tune individual weight values';

  @override
  String get shuffleWeightValuesTitle => 'Weight Values (-99 to +99)';

  @override
  String get shuffleWeightValuesHint =>
      '0 = neutral, negative = penalty, positive = boost';

  @override
  String get shuffleWeightLeastPlayed => 'Least Played Songs';

  @override
  String get shuffleWeightMostPlayed => 'Most Played Songs';

  @override
  String get shuffleWeightSuggestLess => 'Suggest Less Songs';

  @override
  String get shuffleWeightPlaylistSongs => 'Songs in Playlists';

  @override
  String get lyricsGroupDisplayTiming => 'Display & Timing';

  @override
  String get lyricsSimulateWordSyncTitle => 'Simulate Word Sync';

  @override
  String get lyricsSimulateWordSyncSubtitle =>
      'Generate word-level timing from line-synced lyrics using prosodic estimation';

  @override
  String get lyricsDesktopSidebarTitle => 'Lyrics & Queue Sidebar';

  @override
  String get lyricsDesktopSidebarSubtitle =>
      'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden';

  @override
  String get lyricsKeepScreenAwakeTitle => 'Keep Screen Awake on Lyrics';

  @override
  String get lyricsKeepScreenAwakeSubtitle =>
      'Prevent sleep while the lyrics pane is open';

  @override
  String get lyricsGroupTranslation => 'Translation';

  @override
  String get lyricsAutoTranslateTitle => 'Auto-Translate Lyrics';

  @override
  String get lyricsAutoTranslateSubtitle =>
      'Automatically translate lyrics using selected target language';

  @override
  String get lyricsTargetLanguageTitle => 'Target Language';

  @override
  String get lyricsTranslationDisplayTitle => 'Translation Display';

  @override
  String get lyricsTranslationModeReplaceSubtitle => 'Replace base lyrics';

  @override
  String get lyricsTranslationModeSubtextSubtitle =>
      'Show subtext below lyrics';

  @override
  String get lyricsModeSubtext => 'Subtext below';

  @override
  String get lyricsModeReplace => 'Replace base';

  @override
  String get lyricsTranslateTitle => 'Translate lyrics';

  @override
  String get lyricsDisplayMode => 'Display mode';

  @override
  String get lyricsModeSubtextDescription => 'Show translation under lyrics';

  @override
  String get lyricsModeReplaceDescription => 'Replace original lyrics entirely';

  @override
  String get lyricsAutoTranslateAllTitle => 'Auto-translate all songs';

  @override
  String get lyricsAutoTranslateAllSubtitle =>
      'Automatically translate lyrics using selected language';

  @override
  String get lyricsTargetLanguageLabel => 'Target language';

  @override
  String get lyricsSearchLanguageHint => 'Search language...';

  @override
  String get lyricsClearCache => 'Clear cache';

  @override
  String get lyricsTranslateNow => 'Translate now';

  @override
  String get lyricsFindTitle => 'Find lyrics';

  @override
  String get lyricsNoResults =>
      'No lyrics found. Try a different title or artist, or check your connection.';

  @override
  String get lyricsInstrumentalWarning =>
      'Marked as instrumental. Applying this clears any lyrics stored on the file.';

  @override
  String get lyricsApplyUpper => 'APPLY';

  @override
  String get lyricsPlainText => 'Plain text';

  @override
  String get lyricsUnknownLength => 'Unknown length';

  @override
  String lyricsDurationExactMatch(String duration) {
    return '$duration · exact match';
  }

  @override
  String get lyricsBadgeWordSync => 'WORD SYNC';

  @override
  String get lyricsBadgeLineSync => 'LINE SYNC';

  @override
  String get lyricsBadgeInstrumental => 'INSTRUMENTAL';

  @override
  String get lyricsBadgePlain => 'PLAIN';

  @override
  String get lyricsSaved => 'Lyrics saved';

  @override
  String lyricsSaveError(Object error) {
    return 'Could not save lyrics: $error';
  }

  @override
  String get lyricsTranslationCleared => 'Cached translation cleared';

  @override
  String get lyricsAlreadyTranslated => 'Lyrics are already in target language';

  @override
  String get lyricsTranslated => 'Lyrics translated';

  @override
  String get lyricsTranslateError => 'Could not translate lyrics';

  @override
  String lyricsTranslationFailed(Object error) {
    return 'Translation failed: $error';
  }

  @override
  String get lyricsHideTimingTooltip => 'Hide lyric timing';

  @override
  String get lyricsAdjustTimingTooltip =>
      'Adjust lyric timing — hold for precision controls';

  @override
  String get lyricsFindOnline => 'Find lyrics online';

  @override
  String get lyricsEmptyTitle => 'No lyrics';

  @override
  String get lyricsEmptySubtitle => 'This track has no embedded lyrics.';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageGerman => 'German';

  @override
  String get languageItalian => 'Italian';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageDutch => 'Dutch';

  @override
  String get languagePolish => 'Polish';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageVietnamese => 'Vietnamese';

  @override
  String get languageUkrainian => 'Ukrainian';

  @override
  String get languageSwedish => 'Swedish';

  @override
  String get languageIndonesian => 'Indonesian';

  @override
  String get languageThai => 'Thai';

  @override
  String get languageCzech => 'Czech';

  @override
  String get languageGreek => 'Greek';

  @override
  String get languageHungarian => 'Hungarian';

  @override
  String get languageRomanian => 'Romanian';

  @override
  String get languageDanish => 'Danish';

  @override
  String get languageFinnish => 'Finnish';

  @override
  String get languageNorwegian => 'Norwegian';

  @override
  String get selectSongsTitle => 'Select Songs';

  @override
  String get selectSongsWhatIsMerging => 'What is merging?';

  @override
  String get selectSongsMergedExplanation =>
      'Merged songs are different versions of the same song:';

  @override
  String get selectSongsBulletVersions =>
      'Like remixes, live versions, or different quality versions';

  @override
  String get selectSongsBulletFavorites =>
      'Favorites and \"suggest less\" are independent per song';

  @override
  String get selectSongsBulletStats =>
      'Your play counts and stats remain unchanged';

  @override
  String get selectSongsBulletPriority =>
      'Select a priority song (⭐) to prioritize it during shuffle';

  @override
  String get selectSongsSearchHint => 'Search songs...';

  @override
  String selectSongsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get selectSongsReadyToMerge => 'Ready to merge';

  @override
  String get selectSongsPrioritySongTooltip => 'Priority song';

  @override
  String get selectSongsSetPriorityTooltip => 'Set as priority';

  @override
  String get selectSongsPriorityBadge => 'PRIORITY';

  @override
  String selectSongsMinSelection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Select at least $count songs',
      one: 'Select at least 1 song',
    );
    return '$_temp0';
  }

  @override
  String selectSongsMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Merge $count Songs',
      one: 'Merge 1 Song',
    );
    return '$_temp0';
  }

  @override
  String selectSongsSelectAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Select $count Songs',
      one: 'Select 1 Song',
    );
    return '$_temp0';
  }

  @override
  String get foldersAddedSnack => 'Music folder added';

  @override
  String get foldersRemovedSnack => 'Music folder removed';

  @override
  String get foldersSubtitle => 'Select folders containing your music files';

  @override
  String get foldersEmptyTitle => 'No folders added yet';

  @override
  String get foldersEmptyMessage => 'Add a folder to build your library.';

  @override
  String get foldersAddButton => 'Add Folder';

  @override
  String get foldersAllFilesGrantedTitle => 'All files access granted';

  @override
  String get foldersAllFilesGrantedSubtitle =>
      'wispie can read music in every folder you add.';

  @override
  String get foldersAllFilesMissingTitle => 'All files access is off';

  @override
  String get foldersAllFilesMissingSubtitle =>
      'Allow it so wispie can find music in folders outside the default media library.';

  @override
  String get foldersAllFilesAllowButton => 'Allow all files access';

  @override
  String get foldersShortcutInternalStorage => 'Internal Storage';

  @override
  String get foldersShortcutMusic => 'Music';

  @override
  String get foldersShortcutDownload => 'Download';

  @override
  String get foldersShortcutStorageRoot => 'Storage Root';

  @override
  String get foldersShortcutDownloads => 'Downloads';

  @override
  String get foldersShortcutDocuments => 'Documents';

  @override
  String get foldersDoesNotExist => 'Folder does not exist';

  @override
  String get foldersPermissionError =>
      'Permission denied or error reading folder';

  @override
  String get foldersNewFolderTitle => 'New Folder';

  @override
  String get foldersFolderNameLabel => 'Folder Name';

  @override
  String get foldersFolderNameHint => 'Enter folder name';

  @override
  String foldersCreateError(String error) {
    return 'Error creating folder: $error';
  }

  @override
  String get foldersGoUp => '.. (Go up)';

  @override
  String get foldersGoBack => '.. (Go back)';

  @override
  String get foldersNoSubfolders =>
      'No subfolders found.\nSelect this folder if it contains your music.';

  @override
  String get foldersSelectThisFolder => 'Select This Folder';

  @override
  String get foldersSelectDestination => 'Select Destination Folder';

  @override
  String get foldersEmptyFolder => 'Empty folder. You can select it below.';

  @override
  String foldersSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get foldersRoot => 'Root';

  @override
  String get foldersMoveFolder => 'Move Folder';

  @override
  String foldersMovedTo(String name, String path) {
    return 'Moved $name to $path';
  }

  @override
  String foldersMoveError(String error) {
    return 'Error moving folder: $error';
  }

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsSearchHint => 'Search playlists...';

  @override
  String get playlistsCreate => 'Create Playlist';

  @override
  String get playlistsNoMatches => 'No matching playlists found';

  @override
  String playlistsCreatedOn(String date) {
    return 'Created $date';
  }

  @override
  String get playlistsCreatedToday => 'today';

  @override
  String get playlistsCreatedYesterday => 'yesterday';

  @override
  String playlistsDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String playlistsWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks ago',
      one: '1 week ago',
    );
    return '$_temp0';
  }

  @override
  String get playlistsEmptyTitle => 'No playlists yet';

  @override
  String get playlistsEmptyMessage =>
      'Create your first playlist to get started';

  @override
  String get playlistsNameHint => 'Enter playlist name';

  @override
  String get statsTitle => 'Listening';

  @override
  String get statsLoadErrorTitle => 'Couldn\'t load your stats';

  @override
  String get statsReadingHistory => 'Reading your listening history';

  @override
  String get statsEmptyTitle => 'No listening history yet';

  @override
  String get statsEmptyMessage =>
      'Play something and your listening habits will show up here.';

  @override
  String get statsSectionOverTime => 'Over time';

  @override
  String get statsSectionWhen => 'When you listen';

  @override
  String get statsSectionTop => 'Your top';

  @override
  String get statsSectionTaste => 'Taste';

  @override
  String get statsByHour => 'BY HOUR';

  @override
  String get statsByWeekday => 'BY WEEKDAY';

  @override
  String get statsNoListening => 'No listening recorded';

  @override
  String statsAcrossPlays(String time, String plays) {
    return '$time across $plays';
  }

  @override
  String get statsLibraryExplored => 'Library explored';

  @override
  String get statsPlaysFavourites => 'Plays that were favourites';

  @override
  String get statsPlaysSkipped => 'Plays skipped';

  @override
  String get statsAvgPlay => 'AVERAGE PLAY';

  @override
  String get statsOnActiveDay => 'ON AN ACTIVE DAY';

  @override
  String get statsPlaysPerActiveDay => 'PLAYS PER ACTIVE DAY';

  @override
  String get statsFirstListen => 'FIRST LISTEN';

  @override
  String statsShareOf(String share, String count) {
    return '$share of $count';
  }

  @override
  String get statsTopArtists => 'TOP ARTISTS';

  @override
  String get statsTopAlbums => 'TOP ALBUMS';

  @override
  String get statsTopTracks => 'TOP TRACKS';

  @override
  String get statsTimeListened => 'TIME LISTENED';

  @override
  String statsRangeWithDays(String range, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days with music on',
      one: '1 day with music on',
    );
    return '$range · $_temp0';
  }

  @override
  String get statsPlays => 'PLAYS';

  @override
  String get statsSkips => 'SKIPS';

  @override
  String get statsTracks => 'TRACKS';

  @override
  String get statsStreak => 'STREAK';

  @override
  String statsStreakBest(int count) {
    return 'best $count';
  }

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active days',
      one: '1 active day',
    );
    return '$_temp0';
  }

  @override
  String statsSummary(String duration, String plays, String days) {
    return '$duration · $plays · $days';
  }

  @override
  String get statsEmptyHint => 'Play something to start your history';

  @override
  String get statsLoadError => 'Could not load your stats';

  @override
  String statsDurationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String statsDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get statsSameAsBefore => 'same as before';

  @override
  String statsHourTickAm(int hour) {
    return '${hour}a';
  }

  @override
  String statsHourTickPm(int hour) {
    return '${hour}p';
  }

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get sessionDetailTitle => 'Session Details';

  @override
  String sessionStartedAt(String time) {
    return 'Started at $time';
  }

  @override
  String get sessionSongSingular => 'Song';

  @override
  String get sessionSongsPlayed => 'Songs Played';

  @override
  String get sessionNoSongs => 'No songs recorded';

  @override
  String get sessionRepeatNow => 'Repeat Queue Now';

  @override
  String get sessionNoSongsAvailable => 'No songs available to play';

  @override
  String sessionAfterCurrentSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs will play after the current song',
      one: '1 song will play after the current song',
    );
    return '$_temp0';
  }

  @override
  String sessionPlayingSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Playing $count songs from this session',
      one: 'Playing 1 song from this session',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryTitle => 'Session History';

  @override
  String get sessionLoadFailed => 'Failed to load sessions';

  @override
  String get sessionEmptyTitle => 'No Sessions Yet';

  @override
  String get sessionEmptyMessage =>
      'Start listening to build your session history';

  @override
  String get playHistoryTitle => 'Song History';

  @override
  String get playHistoryEmptyTitle => 'No play history yet';

  @override
  String get playHistoryEmptyMessage =>
      'Start listening to build your history.';

  @override
  String get playHistoryListen => 'Listen';

  @override
  String get playHistorySkip => 'Skip';

  @override
  String playHistorySummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
    );
    return '$_temp0 · $duration';
  }

  @override
  String playHistoryDate(String month, int day, int year) {
    return '$month $day, $year';
  }

  @override
  String get monthShortJan => 'Jan';

  @override
  String get monthShortFeb => 'Feb';

  @override
  String get monthShortMar => 'Mar';

  @override
  String get monthShortApr => 'Apr';

  @override
  String get monthShortMay => 'May';

  @override
  String get monthShortJun => 'Jun';

  @override
  String get monthShortJul => 'Jul';

  @override
  String get monthShortAug => 'Aug';

  @override
  String get monthShortSep => 'Sep';

  @override
  String get monthShortOct => 'Oct';

  @override
  String get monthShortNov => 'Nov';

  @override
  String get monthShortDec => 'Dec';

  @override
  String get searchFieldHint => 'Search songs, artists, albums...';

  @override
  String get onlineTab => 'Online';

  @override
  String get onlineSearchHint => 'Search tracks on Audius';

  @override
  String get onlineSearchPrompt => 'Search Audius for tracks';

  @override
  String get onlineLoading => 'Searching Audius...';

  @override
  String get onlineNoResults => 'No tracks found';

  @override
  String get onlineError => 'Could not load from Audius.';

  @override
  String get onlineErrorNetwork =>
      'Could not reach Audius. Check your connection.';

  @override
  String onlineErrorAuth(int status) {
    return 'Audius rejected the API key (HTTP $status).';
  }

  @override
  String get onlineErrorRateLimited =>
      'Audius is rate limiting requests. Wait a moment and try again.';

  @override
  String onlineErrorServer(int status) {
    return 'Audius is temporarily unavailable (HTTP $status).';
  }

  @override
  String get onlineErrorResponse => 'Audius returned an unexpected response.';

  @override
  String get onlineAddToQueue => 'Add to queue';

  @override
  String onlineSongQueued(String title) {
    return 'Added $title to the queue';
  }

  @override
  String get onlineUnavailable => 'Unavailable on Audius';

  @override
  String get onlineAddToPlaylist => 'Add to playlist';

  @override
  String get searchEmptyTitle => 'Search your music collection';

  @override
  String get searchEmptyMessage => 'Find songs, artists, albums, and lyrics.';

  @override
  String get searchFailed => 'Could not search';

  @override
  String searchNoResults(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String get searchNoResultsHint =>
      'Try different keywords or check your filters.';

  @override
  String searchArtistsSection(int count) {
    return 'Artists ($count)';
  }

  @override
  String searchAlbumsSection(int count) {
    return 'Albums ($count)';
  }

  @override
  String searchSongsSection(int count) {
    return 'Songs ($count)';
  }

  @override
  String searchAlbumSubtitle(String artist, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$artist · $_temp0';
  }

  @override
  String get quickActionSuggestMore => 'Suggest more often';

  @override
  String get quickActionSuggestLess => 'Suggest less often';

  @override
  String get quickActionGoToAlbum => 'Go to album';

  @override
  String get quickActionGoToArtist => 'Go to artist';

  @override
  String get aboutChecking => 'Checking for updates…';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Update available: $version';
  }

  @override
  String get aboutUpToDate => 'You are up to date';

  @override
  String get aboutCheckForUpdates => 'Check for updates';

  @override
  String get aboutCheckingSubtitle => 'wispie is checking GitHub Releases.';

  @override
  String get aboutUpdateAvailableSubtitle =>
      'A newer version is available on GitHub.';

  @override
  String aboutLatestRelease(String version) {
    return 'Latest release: $version';
  }

  @override
  String get aboutTapToCheck => 'Tap below to check manually.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutUnknown => 'Unknown';

  @override
  String get aboutCheckNow => 'Check now';

  @override
  String get aboutViewRelease => 'View release';

  @override
  String get aboutDebugGroup => 'Debug';

  @override
  String get aboutPersistWrites => 'Persist writes';

  @override
  String get aboutPersistWritesSubtitle =>
      'Debug builds keep changes in a throwaway copy by default. Applies on next launch.';

  @override
  String get appIconMoreSoon => 'More icons coming soon';

  @override
  String get appIconDesktopNote =>
      'Desktop launchers and file managers keep the default icon; the window and Dock icon follow your choice.';

  @override
  String get storageSettingsDiskGroup => 'Disk';

  @override
  String get storageSettingsIndexesGroup => 'Indexes & Caches';

  @override
  String get shellNavHome => 'Home';

  @override
  String get shellSearchTooltip => 'Search (Ctrl+K)';

  @override
  String get shellShowSidebar => 'Show sidebar';

  @override
  String get shellHideSidebar => 'Hide sidebar';

  @override
  String get shellNothingUpNext => 'Nothing up next';

  @override
  String get shellNextInQueue => 'Next in queue';

  @override
  String get shellPlayNext => 'Play next';

  @override
  String get playerNothingPlaying => 'Nothing playing';

  @override
  String get playerPanePlayer => 'Player';

  @override
  String get playerPaneQueue => 'Queue';

  @override
  String get playerCloseEsc => 'Close (Esc)';

  @override
  String get playerSongOptions => 'Song options';

  @override
  String get playerShowArtwork => 'Show artwork';

  @override
  String get playerShowVideo => 'Show video';

  @override
  String get drawerQueueHistory => 'Queue History';

  @override
  String get drawerTools => 'Tools';

  @override
  String get nowPlayingBarShuffleTooltip => 'Shuffle (hold for a new shuffle)';

  @override
  String get shuffleButtonAfterSong => 'Shuffle after current song';

  @override
  String get shuffleButtonAfterQueue => 'Shuffle after current queue';

  @override
  String shuffleButtonScanningTooltip(String percentage) {
    return 'Scanning library ($percentage%)';
  }

  @override
  String shuffleButtonScanningSemantics(String percentage) {
    return 'Scanning library $percentage percent complete';
  }

  @override
  String shuffleButtonScanningMessage(String percentage) {
    return 'Scanning library: $percentage%';
  }

  @override
  String heartMenuRemoveFromPlaylist(String name) {
    return 'Remove from $name';
  }

  @override
  String heartMenuRemovedFromPlaylist(String name) {
    return 'Removed from $name';
  }

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortTitleAZ => 'Title (A-Z)';

  @override
  String get sortDateAdded => 'Date Added';

  @override
  String get sortSongDateOldNew => 'Song Date (Old - New)';

  @override
  String get sortSongDateNewOld => 'Song Date (New - Old)';

  @override
  String get sortMostPlayed => 'Most Played';

  @override
  String get sortRecentlyPlayed => 'Recently Played';

  @override
  String get sortRecommended => 'Recommended';

  @override
  String get searchFilterArtists => 'Artists';

  @override
  String get playlistDialogAddTo => 'Add to...';

  @override
  String get playlistDialogBulkAddTo => 'Bulk Add to...';

  @override
  String get playlistDialogUpdatedSelections => 'Updated selections';

  @override
  String get albumCardAllSongs => 'All songs';

  @override
  String dangerDialogTypeToConfirm(String text) {
    return 'Type \"$text\" to confirm';
  }

  @override
  String dangerDialogCountdown(String label, int seconds) {
    return '$label ($seconds)';
  }

  @override
  String get appDialogConfirm => 'Confirm';

  @override
  String get appDialogEnterName => 'Enter name...';

  @override
  String get transportRepeatOff => 'Repeat off';

  @override
  String get transportRepeatAll => 'Repeat all';

  @override
  String get transportRepeatOne => 'Repeat one';

  @override
  String durationSongsWithTotal(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0 • $duration';
  }

  @override
  String waveformDeltaMinutes(String minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String waveformDeltaSeconds(String value) {
    return '${value}s';
  }

  @override
  String get waveformDeltaZero => '0s';

  @override
  String lyricsMatchContains(String line) {
    return 'contains \"$line\"';
  }

  @override
  String get lyricsMatchPrefix => 'contains \"';

  @override
  String get lyricsMatchAvailable => 'Lyrics available';

  @override
  String get lyricsResumeSync => 'Resume Sync';

  @override
  String get lyricsTimingTitle => 'Lyric timing';

  @override
  String get lyricsTimingLater => 'Later';

  @override
  String get lyricsTimingSyncToLine => 'Sync to this line';

  @override
  String get lyricsTimingReset => 'Reset timing';

  @override
  String lyricsTimingSnapped(String value) {
    return 'Snapped to $value';
  }

  @override
  String get lyricsTimingRangeLabel => 'Range (up to 60 s either way)';

  @override
  String get lyricsTimingFineLabel => 'Fine (5 s either side, 0.01 s steps)';

  @override
  String get lyricsTimingResetTooltip => 'Double-tap to reset to 0.00';

  @override
  String get quickActionsTitle => 'Quick Actions';

  @override
  String get quickActionsResetDone => 'Reset to defaults';

  @override
  String quickActionsEnabledHeader(int count) {
    return 'ENABLED ($count)';
  }

  @override
  String quickActionsDisabledHeader(int count) {
    return 'DISABLED ($count)';
  }

  @override
  String get quickActionsGoToAlbum => 'Go to Album';

  @override
  String get quickActionsGoToArtist => 'Go to Artist';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String get updateCurrentLabel => 'Current';

  @override
  String get updateAvailableBody =>
      'A newer version of wispie is ready to download.';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateWhatsNew => 'What\'s new?';

  @override
  String get externalOpenAddToLibrary => 'Add to library';

  @override
  String get externalOpenDismiss => 'Dismiss';

  @override
  String get wideTrackTime => 'Time';

  @override
  String get floatingDockNext => 'Next';

  @override
  String get barSeekLabel => 'Seek';

  @override
  String get indexerOpOptimizeDatabasesTitle => 'Optimize Databases';

  @override
  String get indexerOpOptimizeDatabasesDesc =>
      'Clean and optimize all app databases';

  @override
  String get indexerOpRepairLinksTitle => 'Repair Library Links';

  @override
  String get indexerOpRepairLinksDesc =>
      'Re-link album art and file paths after a restore or new device';

  @override
  String get indexerOpMatchIdentityTitle => 'Match Songs by Audio';

  @override
  String get indexerOpMatchIdentityDesc =>
      'Fingerprint every file so renamed songs keep their favourites, playlists and stats, and match across synced devices';

  @override
  String get indexerOpCoverCacheTitle => 'Rebuild Cover Caches';

  @override
  String get indexerOpCoverCacheDesc =>
      'Extract and cache embedded album artwork';

  @override
  String get indexerOpSearchIndexTitle => 'Rebuild Search Indexes';

  @override
  String get indexerOpSearchIndexDesc =>
      'Rebuild the search index for all songs';

  @override
  String get indexerOpLyricsCacheTitle => 'Rebuild Lyrics Cache';

  @override
  String get indexerOpLyricsCacheDesc =>
      'Extract and cache lyrics for all songs';

  @override
  String get indexerOpWaveformCacheTitle => 'Rebuild Waveform Cache';

  @override
  String get indexerOpWaveformCacheDesc =>
      'Generate waveform data for all songs';

  @override
  String get indexerOpColorCacheTitle => 'Rebuild App Theme on Cover Cache';

  @override
  String get indexerOpColorCacheDesc => 'Extract color themes from all covers';

  @override
  String get indexerOpBlurredCacheTitle => 'Rebuild Blurred Background Cache';

  @override
  String get indexerOpBlurredCacheDesc =>
      'Pre-generate optimized blurred backgrounds';

  @override
  String get indexerOpRecommendationsTitle => 'Rebuild Recommendations';

  @override
  String get indexerOpRecommendationsDesc =>
      'Force rebuild all recommendation playlists';

  @override
  String get indexerOpArtistAlbumArtTitle => 'Fetch Artist & Album Covers';

  @override
  String get indexerOpArtistAlbumArtDesc =>
      'Fetch missing artist and album covers online, biggest collections first';

  @override
  String get indexerCounting => 'Counting...';

  @override
  String get indexerWorking => 'Working...';

  @override
  String get indexerStopping => 'Stopping...';

  @override
  String indexerProgressPercent(int percent) {
    return 'Processing $percent%';
  }

  @override
  String indexerProgressFailed(int done, int total, int failed) {
    return 'Processing $done/$total ($failed failed)';
  }

  @override
  String indexerStoppedAt(int done, int total) {
    return 'Stopped at $done/$total';
  }

  @override
  String indexerFinished(int processed, int failed) {
    return 'Done: $processed processed, $failed failed';
  }

  @override
  String get indexerNothingToDo => 'Nothing to do, already up to date';

  @override
  String get indexerErrorBusy => 'Already running in the background';

  @override
  String get indexerErrorOffline =>
      'Went offline, the rest resumes automatically';

  @override
  String get indexerStop => 'Stop';
}
