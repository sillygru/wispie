// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsLanguageGroup => 'Language';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPageLibraryTitle => 'Library';

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
  String get songMenuPlayback => 'Playback';

  @override
  String get songMenuPlaybackHint => 'Queue, playlist, and share actions';

  @override
  String get songMenuLibrary => 'Library';

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
  String get bulkShare => 'Share';

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
  String get queueActionPlay => 'Play';

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
  String snapshotTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

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
  String get syncFavorites => 'Favorites';

  @override
  String get syncFavoritesHint => 'Favorite songs';

  @override
  String get syncSuggestLess => 'Suggest less';

  @override
  String get syncSuggestLessHint => 'Songs you asked to see less of';

  @override
  String get syncHiddenSongs => 'Hidden songs';

  @override
  String get syncPlaylists => 'Playlists';

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
  String get appearanceVisualizerOff => 'Off';

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
  String get backupDeleteNever => 'Never';

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
  String get backupContentCoverCache => 'Cover Cache';

  @override
  String get backupContentCoverCacheSubtitle => 'Album artwork images';

  @override
  String get backupContentLibraryCache => 'Library Cache';

  @override
  String get backupContentLibraryCacheSubtitle => 'Cached song metadata';

  @override
  String get backupContentSearchIndex => 'Search Index';

  @override
  String get backupContentSearchIndexSubtitle => 'Indexed search data';

  @override
  String get backupContentWaveformCache => 'Waveform Cache';

  @override
  String get backupContentWaveformCacheSubtitle => 'Audio waveform data';

  @override
  String get backupContentColorCache => 'Color Cache';

  @override
  String get backupContentColorCacheSubtitle => 'Album color themes';

  @override
  String get backupContentLyricsCache => 'Lyrics Cache';

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
  String get metadataLyricsSaved => 'Lyrics saved';

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
  String get storageClear => 'Clear';

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
  String get settingsSearchIndexerTitle => 'Indexer';

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
  String get settingsSearchRichSyncTitle => 'Simulate Word Sync';

  @override
  String get settingsSearchRichSyncSubtitle =>
      'Generate word-level timing from line-synced lyrics using prosodic estimation';

  @override
  String get settingsSearchSidebarTitle => 'Lyrics & Queue Sidebar';

  @override
  String get settingsSearchSidebarSubtitle =>
      'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden';

  @override
  String get settingsSearchKeepAwakeTitle => 'Keep Screen Awake on Lyrics';

  @override
  String get settingsSearchKeepAwakeSubtitle =>
      'Prevent sleep while the lyrics pane is open';

  @override
  String get settingsSearchAutoTranslateTitle => 'Auto-Translate Lyrics';

  @override
  String get settingsSearchAutoTranslateSubtitle =>
      'Automatically translate lyrics using selected target language';

  @override
  String get settingsSearchTargetLangTitle => 'Target Language';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Language to translate lyrics into';

  @override
  String get settingsSearchTranslationModeTitle => 'Translation Display';

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
  String get settingsSearchQuickPicksTitle => 'Quick Picks';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Show quick pick recommendations';

  @override
  String get settingsSearchRecentQueuesTitle => 'Recent Queues';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Show recently played queues';

  @override
  String get settingsSearchForYouTitle => 'For You';

  @override
  String get settingsSearchForYouSubtitle => 'Show recommended playlists';

  @override
  String get settingsSearchQuickActionsTitle => 'Quick Actions';

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
}
