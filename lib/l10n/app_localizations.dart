import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Appearance settings page title
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsLanguageGroup.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageGroup;

  /// Row and sheet title for the app language picker
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsPageLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsPageLibraryTitle;

  /// No description provided for @settingsPageLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Folders, filters, scanning'**
  String get settingsPageLibrarySubtitle;

  /// No description provided for @settingsPagePlaybackTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPagePlaybackTitle;

  /// No description provided for @settingsPagePlaybackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transitions, fades, audio'**
  String get settingsPagePlaybackSubtitle;

  /// No description provided for @settingsPageLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get settingsPageLyricsTitle;

  /// No description provided for @settingsPageLyricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Word sync, translation, sidebar'**
  String get settingsPageLyricsSubtitle;

  /// No description provided for @settingsPageAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsPageAppearanceTitle;

  /// No description provided for @settingsPageAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Now playing, motion, app icon'**
  String get settingsPageAppearanceSubtitle;

  /// No description provided for @settingsPageHomeNavigationTitle.
  ///
  /// In en, this message translates to:
  /// **'Home & Navigation'**
  String get settingsPageHomeNavigationTitle;

  /// No description provided for @settingsPageHomeNavigationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Home sections, lists, quick actions'**
  String get settingsPageHomeNavigationSubtitle;

  /// No description provided for @settingsPageSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsPageSyncTitle;

  /// No description provided for @settingsPageSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted cross-device sync'**
  String get settingsPageSyncSubtitle;

  /// No description provided for @settingsPageBackupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsPageBackupRestoreTitle;

  /// No description provided for @settingsPageBackupRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export, import, automatic backups'**
  String get settingsPageBackupRestoreSubtitle;

  /// No description provided for @settingsPageStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsPageStorageTitle;

  /// No description provided for @settingsPageStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disk usage, indexes, caches'**
  String get settingsPageStorageSubtitle;

  /// No description provided for @settingsPageAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsPageAboutTitle;

  /// No description provided for @settingsPageAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, updates, release notes'**
  String get settingsPageAboutSubtitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get actionHide;

  /// No description provided for @actionDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get actionDeletePermanently;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @playlistNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get playlistNewTitle;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistNameHint;

  /// No description provided for @playlistCreated.
  ///
  /// In en, this message translates to:
  /// **'Created playlist \"{name}\"'**
  String playlistCreated(Object name);

  /// No description provided for @songFavoriteRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from favorites'**
  String songFavoriteRemoved(Object title);

  /// No description provided for @songFavoriteAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {title} to favorites'**
  String songFavoriteAdded(Object title);

  /// No description provided for @songWillSuggestMore.
  ///
  /// In en, this message translates to:
  /// **'Will suggest {title} more often'**
  String songWillSuggestMore(Object title);

  /// No description provided for @songWillSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Will suggest {title} less often'**
  String songWillSuggestLess(Object title);

  /// No description provided for @songAddedToNextUp.
  ///
  /// In en, this message translates to:
  /// **'Added to Next Up: {title}'**
  String songAddedToNextUp(Object title);

  /// No description provided for @songShareText.
  ///
  /// In en, this message translates to:
  /// **'{title} by {artist}'**
  String songShareText(Object artist, Object title);

  /// No description provided for @songAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String songAddedToPlaylist(Object name);

  /// No description provided for @songRemovedFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from playlist'**
  String songRemovedFromPlaylist(Object title);

  /// No description provided for @songMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved {title} to {path}'**
  String songMovedTo(Object path, Object title);

  /// No description provided for @songMoveError.
  ///
  /// In en, this message translates to:
  /// **'Error moving song: {error}'**
  String songMoveError(Object error);

  /// No description provided for @songRemovedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from library'**
  String songRemovedFromLibrary(Object title);

  /// No description provided for @songDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get songDeleteTitle;

  /// No description provided for @songDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete \'\'{title}\'\' from your device? This cannot be undone.'**
  String songDeleteConfirm(Object title);

  /// No description provided for @songDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {title}'**
  String songDeleted(Object title);

  /// No description provided for @songDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Error deleting file: {error}'**
  String songDeleteError(Object error);

  /// No description provided for @coverSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching Last.fm, Deezer and iTunes for cover art...'**
  String get coverSearching;

  /// No description provided for @coverNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No missing cover art found online'**
  String get coverNoneFound;

  /// No description provided for @coverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated cover art for \"{title}\" ({source})'**
  String coverUpdated(Object source, Object title);

  /// No description provided for @coverDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download cover art'**
  String get coverDownloadFailed;

  /// No description provided for @coverFetchError.
  ///
  /// In en, this message translates to:
  /// **'Error fetching cover: {error}'**
  String coverFetchError(Object error);

  /// No description provided for @metaResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata Fetch Results'**
  String get metaResultsTitle;

  /// No description provided for @metaFetchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Fetching Missing Metadata'**
  String get metaFetchingTitle;

  /// No description provided for @metaStatUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get metaStatUpdated;

  /// No description provided for @metaStatNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not Found'**
  String get metaStatNotFound;

  /// No description provided for @metaStatSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get metaStatSkipped;

  /// No description provided for @metaUndoAll.
  ///
  /// In en, this message translates to:
  /// **'Undo All'**
  String get metaUndoAll;

  /// No description provided for @metaUndoSong.
  ///
  /// In en, this message translates to:
  /// **'Undo this song'**
  String get metaUndoSong;

  /// No description provided for @metaRevertedCount.
  ///
  /// In en, this message translates to:
  /// **'Reverted metadata changes for {count} track(s)'**
  String metaRevertedCount(int count);

  /// No description provided for @metaViaSource.
  ///
  /// In en, this message translates to:
  /// **'via {source}'**
  String metaViaSource(Object source);

  /// No description provided for @metaMoreItems.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more'**
  String metaMoreItems(int count);

  /// No description provided for @metaCouldNotFind.
  ///
  /// In en, this message translates to:
  /// **'Could Not Find'**
  String get metaCouldNotFind;

  /// No description provided for @metaUnknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get metaUnknownArtist;

  /// No description provided for @metaAllHaveMetadata.
  ///
  /// In en, this message translates to:
  /// **'All {count} tracks already have metadata'**
  String metaAllHaveMetadata(int count);

  /// No description provided for @metaNoMissingMetadata.
  ///
  /// In en, this message translates to:
  /// **'No tracks with missing metadata found'**
  String get metaNoMissingMetadata;

  /// No description provided for @metaSearchingBatch.
  ///
  /// In en, this message translates to:
  /// **'Searching batch {batch}...'**
  String metaSearchingBatch(int batch);

  /// No description provided for @metaCancelledSummary.
  ///
  /// In en, this message translates to:
  /// **'Metadata fetch cancelled ({updated} updated, {notFound} not found)'**
  String metaCancelledSummary(int updated, int notFound);

  /// No description provided for @songMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Song Options'**
  String get songMenuTitle;

  /// No description provided for @songMenuPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get songMenuPlayback;

  /// No description provided for @songMenuPlaybackHint.
  ///
  /// In en, this message translates to:
  /// **'Queue, playlist, and share actions'**
  String get songMenuPlaybackHint;

  /// No description provided for @songMenuLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get songMenuLibrary;

  /// No description provided for @songMenuLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Move song and edit metadata'**
  String get songMenuLibraryHint;

  /// No description provided for @songMenuPersonalize.
  ///
  /// In en, this message translates to:
  /// **'Personalize'**
  String get songMenuPersonalize;

  /// No description provided for @songMenuPersonalizeHint.
  ///
  /// In en, this message translates to:
  /// **'Favorite and recommendation settings'**
  String get songMenuPersonalizeHint;

  /// No description provided for @songMenuDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get songMenuDanger;

  /// No description provided for @songMenuDangerHint.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist or delete song'**
  String get songMenuDangerHint;

  /// No description provided for @songMenuPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get songMenuPlayNext;

  /// No description provided for @songMenuPlayNextHint.
  ///
  /// In en, this message translates to:
  /// **'Add song to play immediately after current track'**
  String get songMenuPlayNextHint;

  /// No description provided for @songMenuPlayNextDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Play Next (Allow Duplicate)'**
  String get songMenuPlayNextDuplicate;

  /// No description provided for @songMenuPlayNextDuplicateHint.
  ///
  /// In en, this message translates to:
  /// **'Add again even if already in queue'**
  String get songMenuPlayNextDuplicateHint;

  /// No description provided for @songMenuAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get songMenuAddToPlaylist;

  /// No description provided for @songMenuAddToPlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Quick add to your most recent playlist'**
  String get songMenuAddToPlaylistHint;

  /// No description provided for @songMenuAddToNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to New Playlist'**
  String get songMenuAddToNewPlaylist;

  /// No description provided for @songMenuAddToNewPlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist and add this song'**
  String get songMenuAddToNewPlaylistHint;

  /// No description provided for @songMenuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get songMenuShare;

  /// No description provided for @songMenuShareHint.
  ///
  /// In en, this message translates to:
  /// **'Share the audio file externally'**
  String get songMenuShareHint;

  /// No description provided for @songMenuFetchCover.
  ///
  /// In en, this message translates to:
  /// **'Fetch Missing Cover'**
  String get songMenuFetchCover;

  /// No description provided for @songMenuFetchCoverHint.
  ///
  /// In en, this message translates to:
  /// **'Try searching Last.fm, Deezer and iTunes for cover art'**
  String get songMenuFetchCoverHint;

  /// No description provided for @songMenuFetchMetadata.
  ///
  /// In en, this message translates to:
  /// **'Fetch Missing Metadata'**
  String get songMenuFetchMetadata;

  /// No description provided for @songMenuFetchMetadataHint.
  ///
  /// In en, this message translates to:
  /// **'Search online for title, artist, album and cover'**
  String get songMenuFetchMetadataHint;

  /// No description provided for @songMenuMoveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to Folder'**
  String get songMenuMoveToFolder;

  /// No description provided for @songMenuMoveToFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Move this file to another folder'**
  String get songMenuMoveToFolderHint;

  /// No description provided for @songMenuManagePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Manage Playlists'**
  String get songMenuManagePlaylists;

  /// No description provided for @songMenuManagePlaylistsHint.
  ///
  /// In en, this message translates to:
  /// **'Add or remove from playlists'**
  String get songMenuManagePlaylistsHint;

  /// No description provided for @songMenuEditMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get songMenuEditMetadata;

  /// No description provided for @songMenuEditMetadataHint.
  ///
  /// In en, this message translates to:
  /// **'Open metadata editor'**
  String get songMenuEditMetadataHint;

  /// No description provided for @songMenuRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get songMenuRemoveFavorite;

  /// No description provided for @songMenuAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get songMenuAddFavorite;

  /// No description provided for @songMenuFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tune your favorite songs list'**
  String get songMenuFavoritesHint;

  /// No description provided for @songMenuSuggestMore.
  ///
  /// In en, this message translates to:
  /// **'Suggest More'**
  String get songMenuSuggestMore;

  /// No description provided for @songMenuSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Suggest Less'**
  String get songMenuSuggestLess;

  /// No description provided for @songMenuSuggestHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust how often this song appears in suggestions'**
  String get songMenuSuggestHint;

  /// No description provided for @songMenuRemoveFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from Current Playlist'**
  String get songMenuRemoveFromPlaylist;

  /// No description provided for @songMenuRemoveFromPlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'Keep file, remove playlist mapping'**
  String get songMenuRemoveFromPlaylistHint;

  /// No description provided for @songMenuRemoveFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from Library'**
  String get songMenuRemoveFromLibrary;

  /// No description provided for @songMenuRemoveFromLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Keep file but hide from the library'**
  String get songMenuRemoveFromLibraryHint;

  /// No description provided for @songMenuDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete the file from the device'**
  String get songMenuDeleteHint;

  /// No description provided for @bulkSelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get bulkSelected;

  /// No description provided for @bulkSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get bulkSelectAll;

  /// No description provided for @bulkFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get bulkFavorite;

  /// No description provided for @bulkUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get bulkUnfavorite;

  /// No description provided for @bulkRemovedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} songs from favorites'**
  String bulkRemovedFromFavorites(int count);

  /// No description provided for @bulkAddedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added {count} songs to favorites'**
  String bulkAddedToFavorites(int count);

  /// No description provided for @bulkPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get bulkPlaylist;

  /// No description provided for @bulkAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added {count} songs to {name}'**
  String bulkAddedToPlaylist(int count, Object name);

  /// No description provided for @bulkShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get bulkShare;

  /// No description provided for @bulkSongsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String bulkSongsCount(int count);

  /// No description provided for @bulkMetadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get bulkMetadata;

  /// No description provided for @bulkHideTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide Songs'**
  String get bulkHideTitle;

  /// No description provided for @bulkHideMessage.
  ///
  /// In en, this message translates to:
  /// **'Hide {count} selected songs from library?'**
  String bulkHideMessage(int count);

  /// No description provided for @bulkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get bulkDeleteTitle;

  /// No description provided for @bulkDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {count} files from storage? This cannot be undone.'**
  String bulkDeleteMessage(int count);

  /// No description provided for @bulkAddedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added {count} songs to queue'**
  String bulkAddedToQueue(int count);

  /// No description provided for @bulkMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get bulkMove;

  /// No description provided for @bulkMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} songs to {path}'**
  String bulkMovedTo(int count, Object path);

  /// No description provided for @bulkMoveError.
  ///
  /// In en, this message translates to:
  /// **'Error moving songs: {error}'**
  String bulkMoveError(Object error);

  /// No description provided for @bulkWillSuggestMore.
  ///
  /// In en, this message translates to:
  /// **'Will suggest {count} songs more'**
  String bulkWillSuggestMore(int count);

  /// No description provided for @bulkWillSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Will suggest {count} songs less'**
  String bulkWillSuggestLess(int count);

  /// Queue pane segment for upcoming tracks
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get queueTabUpNext;

  /// Queue pane segment for saved queues
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get queueTabHistory;

  /// Queue row menu: play this track now
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get queueActionPlay;

  /// Queue row action: move track to the top of upcoming
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get queueActionMoveToTop;

  /// Queue row action: remove track from the queue
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get queueActionRemove;

  /// Queue row menu: open the full song options sheet
  ///
  /// In en, this message translates to:
  /// **'Song options…'**
  String get queueActionSongOptions;

  /// Title of the dialog confirming upcoming queue clear
  ///
  /// In en, this message translates to:
  /// **'Clear Queue?'**
  String get queueClearDialogTitle;

  /// Body of the clear queue confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will remove all upcoming songs from the current queue.'**
  String get queueClearDialogMessage;

  /// Destructive confirm button for clearing the queue or history
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get queueClearAll;

  /// Section header for tracks already played in the queue
  ///
  /// In en, this message translates to:
  /// **'Played'**
  String get queueSectionPlayed;

  /// Section header for the current track
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get queueSectionNowPlaying;

  /// Section header for upcoming tracks
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get queueSectionUpNext;

  /// Swipe action label: move track to the top of upcoming
  ///
  /// In en, this message translates to:
  /// **'Add to top'**
  String get queueSwipeAddToTop;

  /// Tooltip for the button that reshuffles upcoming tracks
  ///
  /// In en, this message translates to:
  /// **'Shuffle upcoming'**
  String get queueShuffleUpcomingTooltip;

  /// Tooltip for the button that clears upcoming tracks
  ///
  /// In en, this message translates to:
  /// **'Clear upcoming'**
  String get queueClearUpcomingTooltip;

  /// Upcoming track count in the queue summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String queueSongCount(int count);

  /// Appended after the song count with the remaining duration
  ///
  /// In en, this message translates to:
  /// **'  ·  {remaining}'**
  String queueRemainingSuffix(String remaining);

  /// Empty state when there are no tracks in the queue
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// Tooltip for the remove button on an upcoming row
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get queueRemoveFromQueueTooltip;

  /// Snackbar shown after removing a track; undo follows
  ///
  /// In en, this message translates to:
  /// **'Removed {title}'**
  String queueRemovedTitle(String title);

  /// Button that restores a just-removed track
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get queueUndo;

  /// Title of the dialog confirming deletion of all saved queues
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get historyClearDialogTitle;

  /// Body of the clear history confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete every saved queue snapshot.'**
  String get historyClearDialogMessage;

  /// Snackbar shown after restoring a saved queue
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Restored 1 track} other{Restored {count} tracks}}'**
  String historyRestoredCount(int count);

  /// Error state when saved queues fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load history'**
  String get historyLoadError;

  /// Empty state title for the history tab
  ///
  /// In en, this message translates to:
  /// **'No past queues'**
  String get historyEmptyTitle;

  /// Empty state body for the history tab
  ///
  /// In en, this message translates to:
  /// **'Queues you play get saved here automatically.'**
  String get historyEmptyMessage;

  /// Header count of saved queues in history
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved queue} other{{count} saved queues}}'**
  String historySavedCount(int count);

  /// Trailing action on the history section header
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get historyClearAllTrailing;

  /// Date group header for queues saved today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyDayToday;

  /// Date group header for queues saved yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get historyDayYesterday;

  /// Date group header for queues saved within the last week
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get historyDayThisWeek;

  /// Date group header for queues saved within the last month
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get historyDayThisMonth;

  /// Date group header for queues saved longer ago
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get historyDayEarlier;

  /// Track count on a saved queue card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String snapshotTrackCount(int count);

  /// Fallback name for a saved queue that came from shuffle
  ///
  /// In en, this message translates to:
  /// **'Shuffled queue'**
  String get snapshotShuffledQueue;

  /// Fallback name for a saved queue
  ///
  /// In en, this message translates to:
  /// **'Saved queue'**
  String get snapshotSavedQueue;

  /// Shown when none of a saved queue's tracks exist anymore
  ///
  /// In en, this message translates to:
  /// **'None of these tracks are still in your library.'**
  String get snapshotEmptyTracks;

  /// Count of tracks not shown in an expanded saved queue
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String snapshotMoreHidden(int count);

  /// Count of saved-queue tracks no longer in the library
  ///
  /// In en, this message translates to:
  /// **'{count} missing from library'**
  String snapshotMissingCount(int count);

  /// Separator between metadata items on a single line
  ///
  /// In en, this message translates to:
  /// **' · '**
  String get queueMetaSeparator;

  /// Shuffle-and-play button on the song list header
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get songListShuffle;

  /// Play button on the song list header when nothing from this list is playing
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get songListPlay;

  /// Play button label while this list is playing
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get songListPause;

  /// Play button label when this list is the current queue but paused
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get songListResume;

  /// Tooltip for the cover fetch button on an artist page
  ///
  /// In en, this message translates to:
  /// **'Fetch Artist Cover Online'**
  String get songListFetchArtistCover;

  /// Tooltip for the cover fetch button on an album page
  ///
  /// In en, this message translates to:
  /// **'Fetch Album Cover Online'**
  String get songListFetchAlbumCover;

  /// Tooltip for the cover fetch button on a playlist or other list
  ///
  /// In en, this message translates to:
  /// **'Fetch Cover Online'**
  String get songListFetchCover;

  /// Tooltip for the playlist overflow menu button
  ///
  /// In en, this message translates to:
  /// **'Playlist Options'**
  String get songListPlaylistOptions;

  /// Title of the picker used to choose songs to merge
  ///
  /// In en, this message translates to:
  /// **'Select Songs to Merge'**
  String get songListSelectSongsToMerge;

  /// Snackbar after songs are merged into one group
  ///
  /// In en, this message translates to:
  /// **'Merged {count} songs'**
  String songListMergedSongs(int count);

  /// Snackbar when merging songs fails
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String songListMergeError(Object error);

  /// Tooltip for the merge songs button
  ///
  /// In en, this message translates to:
  /// **'Merge Songs'**
  String get songListMergeSongs;

  /// Empty state when a list has no songs
  ///
  /// In en, this message translates to:
  /// **'No songs in this list'**
  String get songListEmpty;

  /// Generic rename action label
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// Title of the rename playlist prompt
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get songListRenamePlaylist;

  /// Title of the delete playlist confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get songListDeletePlaylist;

  /// Body of the delete playlist confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?'**
  String songListDeletePlaylistConfirm(Object title);

  /// Snackbar while searching online artwork for an artist or album
  ///
  /// In en, this message translates to:
  /// **'Searching online for {name} artwork...'**
  String songListSearchingArtwork(Object name);

  /// Title of the artwork picker for an artist or album
  ///
  /// In en, this message translates to:
  /// **'Select Artwork for {name}'**
  String songListSelectArtwork(Object name);

  /// Artwork picker option to revert to the generated cover grid
  ///
  /// In en, this message translates to:
  /// **'Use Song Cover Grid'**
  String get songListUseSongCoverGrid;

  /// Subtitle of the revert-to-grid artwork option
  ///
  /// In en, this message translates to:
  /// **'Remove custom artwork'**
  String get songListRemoveCustomArtwork;

  /// Artwork picker option to pick a local image
  ///
  /// In en, this message translates to:
  /// **'Choose Custom Image'**
  String get songListChooseCustomImage;

  /// Subtitle of the choose custom image option
  ///
  /// In en, this message translates to:
  /// **'Select image from device storage'**
  String get songListSelectFromDevice;

  /// Artwork picker tile title naming the online source
  ///
  /// In en, this message translates to:
  /// **'Artwork from {source}'**
  String songListArtworkFrom(Object source);

  /// Artwork picker message when no online results exist
  ///
  /// In en, this message translates to:
  /// **'No online artwork options found'**
  String get songListNoOnlineArtwork;

  /// Snackbar after reverting to the song cover grid
  ///
  /// In en, this message translates to:
  /// **'Reset to song cover grid'**
  String get songListResetArtwork;

  /// Snackbar after artwork is updated for an artist or album
  ///
  /// In en, this message translates to:
  /// **'Updated artwork for {name}'**
  String songListArtworkUpdated(Object name);

  /// Snackbar while downloading chosen artwork
  ///
  /// In en, this message translates to:
  /// **'Downloading artwork...'**
  String get songListDownloadingArtwork;

  /// Snackbar when downloading chosen artwork fails
  ///
  /// In en, this message translates to:
  /// **'Failed to download artwork'**
  String get songListArtworkDownloadFailed;

  /// Section header above the album cards on an artist page
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get gradientDetailAlbums;

  /// Section header above the song list on a detail page
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get gradientDetailSongs;

  /// Chip that clears the album filter on an artist page
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get gradientDetailShowAll;

  /// Album count shown under the stats on an artist page
  ///
  /// In en, this message translates to:
  /// **'{count} albums'**
  String gradientDetailAlbumCount(int count);

  /// No description provided for @syncPlayStats.
  ///
  /// In en, this message translates to:
  /// **'Play stats'**
  String get syncPlayStats;

  /// No description provided for @syncPlayStatsHint.
  ///
  /// In en, this message translates to:
  /// **'Listening history and play counts'**
  String get syncPlayStatsHint;

  /// No description provided for @syncFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get syncFavorites;

  /// No description provided for @syncFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Favorite songs'**
  String get syncFavoritesHint;

  /// No description provided for @syncSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Suggest less'**
  String get syncSuggestLess;

  /// No description provided for @syncSuggestLessHint.
  ///
  /// In en, this message translates to:
  /// **'Songs you asked to see less of'**
  String get syncSuggestLessHint;

  /// No description provided for @syncHiddenSongs.
  ///
  /// In en, this message translates to:
  /// **'Hidden songs'**
  String get syncHiddenSongs;

  /// No description provided for @syncPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get syncPlaylists;

  /// No description provided for @syncPlaylistsHint.
  ///
  /// In en, this message translates to:
  /// **'All playlists'**
  String get syncPlaylistsHint;

  /// No description provided for @syncMergedSongs.
  ///
  /// In en, this message translates to:
  /// **'Merged songs'**
  String get syncMergedSongs;

  /// No description provided for @syncMergedSongsHint.
  ///
  /// In en, this message translates to:
  /// **'Merged song groups'**
  String get syncMergedSongsHint;

  /// No description provided for @syncAppSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get syncAppSettings;

  /// No description provided for @syncAppSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Theme, playback, and UI preferences'**
  String get syncAppSettingsHint;

  /// No description provided for @syncArtistArt.
  ///
  /// In en, this message translates to:
  /// **'Artist art'**
  String get syncArtistArt;

  /// No description provided for @syncArtistArtHint.
  ///
  /// In en, this message translates to:
  /// **'Online artist cover choices'**
  String get syncArtistArtHint;

  /// No description provided for @syncAlbumArt.
  ///
  /// In en, this message translates to:
  /// **'Album art'**
  String get syncAlbumArt;

  /// No description provided for @syncAlbumArtHint.
  ///
  /// In en, this message translates to:
  /// **'Online album cover choices'**
  String get syncAlbumArtHint;

  /// No description provided for @syncPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get syncPrivacy;

  /// No description provided for @syncEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get syncEncryptedTitle;

  /// No description provided for @syncEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted on this device before upload. The server only stores ciphertext and cannot read your library, history, or settings.'**
  String get syncEncryptedBody;

  /// No description provided for @syncRecoveryKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get syncRecoveryKeyTitle;

  /// No description provided for @syncRecoveryKeyBody.
  ///
  /// In en, this message translates to:
  /// **'If you forget your password, only your recovery key can restore access. Nobody else can.'**
  String get syncRecoveryKeyBody;

  /// No description provided for @syncAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get syncAccount;

  /// No description provided for @syncSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get syncSignedIn;

  /// No description provided for @syncConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get syncConnected;

  /// No description provided for @syncLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get syncLogOut;

  /// No description provided for @syncLogOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sync stops on this device. Local and cloud data are both kept.'**
  String get syncLogOutBody;

  /// No description provided for @syncLogOutAndChange.
  ///
  /// In en, this message translates to:
  /// **'Log out and change'**
  String get syncLogOutAndChange;

  /// No description provided for @syncCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get syncCloud;

  /// No description provided for @syncLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get syncLastSynced;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncNever;

  /// No description provided for @syncUsedOfQuota.
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota} used'**
  String syncUsedOfQuota(Object used, Object quota);

  /// No description provided for @syncJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get syncJustNow;

  /// No description provided for @syncMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String syncMinutesAgo(int count);

  /// No description provided for @syncHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String syncHoursAgo(int count);

  /// No description provided for @syncDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String syncDaysAgo(int count);

  /// No description provided for @syncAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto sync'**
  String get syncAutoSync;

  /// No description provided for @syncAutoSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Sync in the background while the app is open'**
  String get syncAutoSyncHint;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncMergeDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Merge this device with the cloud'**
  String get syncMergeDeviceHint;

  /// No description provided for @syncLastError.
  ///
  /// In en, this message translates to:
  /// **'Last error: {error}'**
  String syncLastError(Object error);

  /// No description provided for @syncWhatGetsSynced.
  ///
  /// In en, this message translates to:
  /// **'What gets synced'**
  String get syncWhatGetsSynced;

  /// No description provided for @syncDeviceStatsAttribution.
  ///
  /// In en, this message translates to:
  /// **'Device Stats Attribution'**
  String get syncDeviceStatsAttribution;

  /// No description provided for @syncThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This Device'**
  String get syncThisDevice;

  /// No description provided for @syncOtherDevices.
  ///
  /// In en, this message translates to:
  /// **'Other Devices'**
  String get syncOtherDevices;

  /// No description provided for @syncTotalLibraryStats.
  ///
  /// In en, this message translates to:
  /// **'Total Library Stats'**
  String get syncTotalLibraryStats;

  /// No description provided for @syncPlays.
  ///
  /// In en, this message translates to:
  /// **'{count} plays'**
  String syncPlays(int count);

  /// No description provided for @syncDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get syncDangerZone;

  /// No description provided for @syncOverwriteCloudTile.
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud with this device'**
  String get syncOverwriteCloudTile;

  /// No description provided for @syncOverwriteCloudTileHint.
  ///
  /// In en, this message translates to:
  /// **'Replace all cloud data with what is on this device'**
  String get syncOverwriteCloudTileHint;

  /// No description provided for @syncReplaceDeviceTile.
  ///
  /// In en, this message translates to:
  /// **'Replace this device with cloud'**
  String get syncReplaceDeviceTile;

  /// No description provided for @syncReplaceDeviceTileHint.
  ///
  /// In en, this message translates to:
  /// **'Erase synced data on this device and use the cloud copy'**
  String get syncReplaceDeviceTileHint;

  /// No description provided for @syncChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get syncChangePassword;

  /// No description provided for @syncNewRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'New recovery key'**
  String get syncNewRecoveryKey;

  /// No description provided for @syncNewRecoveryKeyHint.
  ///
  /// In en, this message translates to:
  /// **'The old recovery key stops working'**
  String get syncNewRecoveryKeyHint;

  /// No description provided for @syncChangeServer.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get syncChangeServer;

  /// No description provided for @syncChangeServerHint.
  ///
  /// In en, this message translates to:
  /// **'Requires logging out first'**
  String get syncChangeServerHint;

  /// No description provided for @syncChangeServerBody.
  ///
  /// In en, this message translates to:
  /// **'You will be logged out of the current server first. Local data is kept.'**
  String get syncChangeServerBody;

  /// No description provided for @syncDeleteCloudAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud account'**
  String get syncDeleteCloudAccount;

  /// No description provided for @syncDeleteCloudAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Removes cloud data permanently. Local data is kept'**
  String get syncDeleteCloudAccountHint;

  /// No description provided for @syncDeleteCloudAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your cloud account and all encrypted data on the server are deleted permanently. Data on this device is kept.'**
  String get syncDeleteCloudAccountBody;

  /// No description provided for @syncOverwriteCloud.
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud'**
  String get syncOverwriteCloud;

  /// No description provided for @syncOverwriteCloudBody.
  ///
  /// In en, this message translates to:
  /// **'All data in the cloud will be replaced by this device. Other devices will be asked to choose how to continue. This device keeps its data.'**
  String get syncOverwriteCloudBody;

  /// No description provided for @syncOverwriteCloudCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I understand the cloud data will be lost'**
  String get syncOverwriteCloudCheckbox;

  /// No description provided for @syncOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get syncOverwrite;

  /// No description provided for @syncReplaceDevice.
  ///
  /// In en, this message translates to:
  /// **'Replace this device'**
  String get syncReplaceDevice;

  /// No description provided for @syncReplaceDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Synced data on this device (stats, favorites, playlists, and so on) will be erased and replaced by the cloud copy. Music files are not touched.'**
  String get syncReplaceDeviceBody;

  /// No description provided for @syncReplaceDeviceCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I understand local synced data will be lost'**
  String get syncReplaceDeviceCheckbox;

  /// No description provided for @syncReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get syncReplace;

  /// No description provided for @syncCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get syncCurrentPassword;

  /// No description provided for @syncNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get syncNewPassword;

  /// No description provided for @syncPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get syncPassword;

  /// No description provided for @syncPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get syncPasswordChanged;

  /// No description provided for @syncGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get syncGenerate;

  /// No description provided for @appearanceGroupNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get appearanceGroupNowPlaying;

  /// No description provided for @appearanceVisualizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Visualizer'**
  String get appearanceVisualizerTitle;

  /// No description provided for @appearanceVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bars over the artwork while playing — synced follows the song, bass on the left'**
  String get appearanceVisualizerSubtitle;

  /// No description provided for @appearanceVisualizerOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get appearanceVisualizerOff;

  /// No description provided for @appearanceVisualizerClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get appearanceVisualizerClassic;

  /// No description provided for @appearanceVisualizerSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get appearanceVisualizerSynced;

  /// No description provided for @appearanceProgressBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress Bar Style'**
  String get appearanceProgressBarTitle;

  /// No description provided for @appearanceProgressBasicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Simple line progress bar'**
  String get appearanceProgressBasicSubtitle;

  /// No description provided for @appearanceProgressWaveformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Static audio waveform'**
  String get appearanceProgressWaveformSubtitle;

  /// No description provided for @appearanceProgressReactiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sound-reactive dynamic waveform with live spectrum & beat response'**
  String get appearanceProgressReactiveSubtitle;

  /// No description provided for @appearanceProgressStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get appearanceProgressStandard;

  /// No description provided for @appearanceProgressWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get appearanceProgressWaveform;

  /// No description provided for @appearanceProgressSoundReactive.
  ///
  /// In en, this message translates to:
  /// **'Sound Reactive'**
  String get appearanceProgressSoundReactive;

  /// No description provided for @appearanceHapticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Waveform Scrubbing Haptics'**
  String get appearanceHapticsTitle;

  /// No description provided for @appearanceHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback for each bar while seeking'**
  String get appearanceHapticsSubtitle;

  /// No description provided for @appearanceCoverSizingTitle.
  ///
  /// In en, this message translates to:
  /// **'Player Cover Sizing'**
  String get appearanceCoverSizingTitle;

  /// No description provided for @appearanceCoverSizingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-fit or preserve source aspect ratio'**
  String get appearanceCoverSizingSubtitle;

  /// No description provided for @appearanceCoverAutoFit.
  ///
  /// In en, this message translates to:
  /// **'Auto Fit'**
  String get appearanceCoverAutoFit;

  /// No description provided for @appearanceCoverSourceSize.
  ///
  /// In en, this message translates to:
  /// **'Source Size'**
  String get appearanceCoverSourceSize;

  /// No description provided for @appearanceImmersiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Immersive design'**
  String get appearanceImmersiveTitle;

  /// No description provided for @appearanceImmersiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full-bleed player cover and gradient detail screens'**
  String get appearanceImmersiveSubtitle;

  /// No description provided for @appearanceGroupPlayerMotion.
  ///
  /// In en, this message translates to:
  /// **'Player motion'**
  String get appearanceGroupPlayerMotion;

  /// No description provided for @appearanceBeatCoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Beat-reactive cover'**
  String get appearanceBeatCoverTitle;

  /// No description provided for @appearanceBeatCoverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable while immersive design is on'**
  String get appearanceBeatCoverUnavailable;

  /// No description provided for @appearanceBeatCoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Album art pulses with the beat'**
  String get appearanceBeatCoverSubtitle;

  /// No description provided for @appearanceCoverIntensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Cover intensity'**
  String get appearanceCoverIntensityTitle;

  /// No description provided for @appearanceCoverIntensitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How strongly the cover reacts'**
  String get appearanceCoverIntensitySubtitle;

  /// No description provided for @appearanceSpinArtworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Spin artwork while playing'**
  String get appearanceSpinArtworkTitle;

  /// No description provided for @appearanceSpinArtworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Artwork turns slowly in the minimized bottom bar while a song plays'**
  String get appearanceSpinArtworkSubtitle;

  /// No description provided for @appearanceParticlesTitle.
  ///
  /// In en, this message translates to:
  /// **'Beat-reactive particles'**
  String get appearanceParticlesTitle;

  /// No description provided for @appearanceParticlesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Floating particles that drift and breathe with the music'**
  String get appearanceParticlesSubtitle;

  /// No description provided for @appearanceParticleDensityTitle.
  ///
  /// In en, this message translates to:
  /// **'Particle density'**
  String get appearanceParticleDensityTitle;

  /// No description provided for @appearanceParticleDensitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many particles and how lively'**
  String get appearanceParticleDensitySubtitle;

  /// No description provided for @appearanceBeatOffsetTitle.
  ///
  /// In en, this message translates to:
  /// **'Beat sync offset'**
  String get appearanceBeatOffsetTitle;

  /// No description provided for @appearanceBeatOffsetNone.
  ///
  /// In en, this message translates to:
  /// **'No offset — raise it if the pulse feels early'**
  String get appearanceBeatOffsetNone;

  /// No description provided for @appearanceBeatOffsetValue.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String appearanceBeatOffsetValue(int ms);

  /// No description provided for @appearanceBeatOffsetBluetooth.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms (raise for Bluetooth)'**
  String appearanceBeatOffsetBluetooth(int ms);

  /// No description provided for @appearanceCalibrateTitle.
  ///
  /// In en, this message translates to:
  /// **'Calibrate beat sync'**
  String get appearanceCalibrateTitle;

  /// No description provided for @appearanceCalibrateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Line up particles with a click track by ear'**
  String get appearanceCalibrateSubtitle;

  /// No description provided for @appearanceAppIcon.
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get appearanceAppIcon;

  /// No description provided for @appearanceIntensityMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get appearanceIntensityMin;

  /// No description provided for @appearanceIntensitySubtle.
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get appearanceIntensitySubtle;

  /// No description provided for @appearanceIntensityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get appearanceIntensityBalanced;

  /// No description provided for @appearanceIntensityBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get appearanceIntensityBold;

  /// No description provided for @appearanceIntensityMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get appearanceIntensityMax;

  /// No description provided for @appearanceIntensityCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get appearanceIntensityCustom;

  /// No description provided for @backupExportAppData.
  ///
  /// In en, this message translates to:
  /// **'Export App Data'**
  String get backupExportAppData;

  /// No description provided for @backupExportAppDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup your stats, favorites, and playlists'**
  String get backupExportAppDataSubtitle;

  /// No description provided for @backupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String backupExportFailed(Object error);

  /// No description provided for @backupImportAppData.
  ///
  /// In en, this message translates to:
  /// **'Import App Data'**
  String get backupImportAppData;

  /// No description provided for @backupImportAppDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore data from a backup (replaces all)'**
  String get backupImportAppDataSubtitle;

  /// No description provided for @backupManageBackups.
  ///
  /// In en, this message translates to:
  /// **'Manage Backups'**
  String get backupManageBackups;

  /// No description provided for @backupManageBackupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, restore, and manage app backups'**
  String get backupManageBackupsSubtitle;

  /// No description provided for @backupAutomaticBackups.
  ///
  /// In en, this message translates to:
  /// **'Automatic Backups'**
  String get backupAutomaticBackups;

  /// No description provided for @backupAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get backupAutoBackup;

  /// No description provided for @backupAutoBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often a backup is taken'**
  String get backupAutoBackupSubtitle;

  /// No description provided for @backupAutoBackupContent.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup Content'**
  String get backupAutoBackupContent;

  /// No description provided for @backupAutoBackupContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What data is included in automatic backups'**
  String get backupAutoBackupContentSubtitle;

  /// No description provided for @backupAutoBackupContentDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select content for automatic backups'**
  String get backupAutoBackupContentDialogSubtitle;

  /// No description provided for @backupSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get backupSave;

  /// No description provided for @backupAutoDeleteOld.
  ///
  /// In en, this message translates to:
  /// **'Auto-Delete Old Backups'**
  String get backupAutoDeleteOld;

  /// No description provided for @backupAutoDeleteOldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discard backups older than this'**
  String get backupAutoDeleteOldSubtitle;

  /// No description provided for @backupFrequencyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get backupFrequencyDisabled;

  /// No description provided for @backupFrequencyEvery24Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 24 hours'**
  String get backupFrequencyEvery24Hours;

  /// No description provided for @backupFrequencyEvery48Hours.
  ///
  /// In en, this message translates to:
  /// **'Every 48 hours'**
  String get backupFrequencyEvery48Hours;

  /// No description provided for @backupFrequencyEvery3Days.
  ///
  /// In en, this message translates to:
  /// **'Every 3 days'**
  String get backupFrequencyEvery3Days;

  /// No description provided for @backupFrequencyEvery7Days.
  ///
  /// In en, this message translates to:
  /// **'Every 7 days'**
  String get backupFrequencyEvery7Days;

  /// No description provided for @backupDeleteNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get backupDeleteNever;

  /// No description provided for @backupDeleteAfterDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String backupDeleteAfterDays(int count);

  /// No description provided for @backupExportOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Options'**
  String get backupExportOptionsTitle;

  /// No description provided for @backupExportSelectContent.
  ///
  /// In en, this message translates to:
  /// **'Select content to export:'**
  String get backupExportSelectContent;

  /// No description provided for @backupContentUserStats.
  ///
  /// In en, this message translates to:
  /// **'User Stats'**
  String get backupContentUserStats;

  /// No description provided for @backupContentUserStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play counts, sessions, fun stats'**
  String get backupContentUserStatsSubtitle;

  /// No description provided for @backupContentUserData.
  ///
  /// In en, this message translates to:
  /// **'User Data'**
  String get backupContentUserData;

  /// No description provided for @backupContentUserDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites, hidden, playlists'**
  String get backupContentUserDataSubtitle;

  /// No description provided for @backupContentUserSettings.
  ///
  /// In en, this message translates to:
  /// **'User Settings'**
  String get backupContentUserSettings;

  /// No description provided for @backupContentUserSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, sort order, preferences'**
  String get backupContentUserSettingsSubtitle;

  /// No description provided for @backupContentCoverCache.
  ///
  /// In en, this message translates to:
  /// **'Cover Cache'**
  String get backupContentCoverCache;

  /// No description provided for @backupContentCoverCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Album artwork images'**
  String get backupContentCoverCacheSubtitle;

  /// No description provided for @backupContentLibraryCache.
  ///
  /// In en, this message translates to:
  /// **'Library Cache'**
  String get backupContentLibraryCache;

  /// No description provided for @backupContentLibraryCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached song metadata'**
  String get backupContentLibraryCacheSubtitle;

  /// No description provided for @backupContentSearchIndex.
  ///
  /// In en, this message translates to:
  /// **'Search Index'**
  String get backupContentSearchIndex;

  /// No description provided for @backupContentSearchIndexSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Indexed search data'**
  String get backupContentSearchIndexSubtitle;

  /// No description provided for @backupContentWaveformCache.
  ///
  /// In en, this message translates to:
  /// **'Waveform Cache'**
  String get backupContentWaveformCache;

  /// No description provided for @backupContentWaveformCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Audio waveform data'**
  String get backupContentWaveformCacheSubtitle;

  /// No description provided for @backupContentColorCache.
  ///
  /// In en, this message translates to:
  /// **'Color Cache'**
  String get backupContentColorCache;

  /// No description provided for @backupContentColorCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Album color themes'**
  String get backupContentColorCacheSubtitle;

  /// No description provided for @backupContentLyricsCache.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Cache'**
  String get backupContentLyricsCache;

  /// No description provided for @backupContentLyricsCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stored lyrics data'**
  String get backupContentLyricsCacheSubtitle;

  /// No description provided for @backupCancelUpper.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get backupCancelUpper;

  /// No description provided for @backupExportUpper.
  ///
  /// In en, this message translates to:
  /// **'EXPORT'**
  String get backupExportUpper;

  /// No description provided for @backupContinueUpper.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get backupContinueUpper;

  /// No description provided for @backupImportDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get backupImportDataTitle;

  /// No description provided for @backupImportWarning.
  ///
  /// In en, this message translates to:
  /// **'This will replace ALL existing data with the imported data.\n\nYour current stats, favorites, playlists, and settings will be overwritten.\n\nThis action cannot be undone.'**
  String get backupImportWarning;

  /// No description provided for @backupImportingLabel.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get backupImportingLabel;

  /// No description provided for @backupImportingTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing data'**
  String get backupImportingTitle;

  /// No description provided for @backupImportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful!'**
  String get backupImportSuccess;

  /// No description provided for @backupImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String backupImportFailed(Object error);

  /// No description provided for @metadataCoverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cover updated successfully'**
  String get metadataCoverUpdated;

  /// No description provided for @metadataPickImageError.
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String metadataPickImageError(Object error);

  /// No description provided for @metadataRemoveCoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get metadataRemoveCoverTitle;

  /// No description provided for @metadataRemoveCoverBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove the cover art?'**
  String get metadataRemoveCoverBody;

  /// No description provided for @metadataRemoveUpper.
  ///
  /// In en, this message translates to:
  /// **'REMOVE'**
  String get metadataRemoveUpper;

  /// No description provided for @metadataCoverRemoved.
  ///
  /// In en, this message translates to:
  /// **'Cover removed'**
  String get metadataCoverRemoved;

  /// No description provided for @metadataRemoveCoverError.
  ///
  /// In en, this message translates to:
  /// **'Error removing cover: {error}'**
  String metadataRemoveCoverError(Object error);

  /// No description provided for @metadataFixResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix Thumbnail Result'**
  String get metadataFixResultTitle;

  /// No description provided for @metadataFixReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Review the changes below:'**
  String get metadataFixReviewBody;

  /// No description provided for @metadataFixOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get metadataFixOriginal;

  /// No description provided for @metadataFixNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get metadataFixNew;

  /// No description provided for @metadataFixNewOption.
  ///
  /// In en, this message translates to:
  /// **'New (Option {n})'**
  String metadataFixNewOption(int n);

  /// No description provided for @metadataFixSeeAlternatives.
  ///
  /// In en, this message translates to:
  /// **'See Alternatives'**
  String get metadataFixSeeAlternatives;

  /// No description provided for @metadataFixApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get metadataFixApply;

  /// No description provided for @metadataFixSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail fixed successfully'**
  String get metadataFixSuccess;

  /// No description provided for @metadataFixError.
  ///
  /// In en, this message translates to:
  /// **'Error fixing thumbnail: {error}'**
  String metadataFixError(Object error);

  /// No description provided for @metadataFixThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Fix Thumbnail'**
  String get metadataFixThumbnail;

  /// No description provided for @metadataFixHelpBody.
  ///
  /// In en, this message translates to:
  /// **'This tool automatically improves your album art by:\n\n1. Detecting and removing black bars/borders (common in YouTube thumbnails)\n2. Cropping the image to a perfect square (1:1 ratio)\n\nBest used for converting 16:9 thumbnails into proper album covers.'**
  String get metadataFixHelpBody;

  /// No description provided for @metadataGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get metadataGotIt;

  /// No description provided for @metadataExportCover.
  ///
  /// In en, this message translates to:
  /// **'Export Cover'**
  String get metadataExportCover;

  /// No description provided for @metadataExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get metadataExport;

  /// No description provided for @metadataExportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cover exported to {uri}'**
  String metadataExportSuccess(Object uri);

  /// No description provided for @metadataExportError.
  ///
  /// In en, this message translates to:
  /// **'Error exporting cover: {error}'**
  String metadataExportError(Object error);

  /// No description provided for @metadataReplaceSong.
  ///
  /// In en, this message translates to:
  /// **'Replace Song'**
  String get metadataReplaceSong;

  /// No description provided for @metadataReplaceHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Swaps this song\'\'s file for another copy of the same song (better rip, lossless, clean encode).\n\nPlay history, favourites, playlists and library date move to the new file. Its metadata is re-read from the file, and anything it lacks shows as unknown.\n\nThe new file must be outside your library folders and have a different filename.'**
  String get metadataReplaceHelpBody;

  /// No description provided for @metadataReplaced.
  ///
  /// In en, this message translates to:
  /// **'Replaced with {filename}'**
  String metadataReplaced(Object filename);

  /// No description provided for @metadataReplaceError.
  ///
  /// In en, this message translates to:
  /// **'Could not replace the file: {error}'**
  String metadataReplaceError(Object error);

  /// No description provided for @metadataReplaceFilesBody.
  ///
  /// In en, this message translates to:
  /// **'{oldName}\nreplaced by {newName}'**
  String metadataReplaceFilesBody(Object oldName, Object newName);

  /// No description provided for @metadataReplaceOriginalQuestion.
  ///
  /// In en, this message translates to:
  /// **'What should happen to the original?'**
  String get metadataReplaceOriginalQuestion;

  /// No description provided for @metadataKeepHideUpper.
  ///
  /// In en, this message translates to:
  /// **'KEEP, HIDE IT'**
  String get metadataKeepHideUpper;

  /// No description provided for @metadataDeleteItUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE IT'**
  String get metadataDeleteItUpper;

  /// No description provided for @metadataSaved.
  ///
  /// In en, this message translates to:
  /// **'Metadata updated successfully'**
  String get metadataSaved;

  /// No description provided for @metadataSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving metadata: {error}'**
  String metadataSaveError(Object error);

  /// No description provided for @metadataNoOnlineCover.
  ///
  /// In en, this message translates to:
  /// **'No online cover art found'**
  String get metadataNoOnlineCover;

  /// No description provided for @metadataSelectCoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Cover Art'**
  String get metadataSelectCoverTitle;

  /// No description provided for @metadataResultTitleArtist.
  ///
  /// In en, this message translates to:
  /// **'{title} - {artist}'**
  String metadataResultTitleArtist(Object title, Object artist);

  /// No description provided for @metadataSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String metadataSourceLabel(Object source);

  /// No description provided for @metadataCoverUpdatedFrom.
  ///
  /// In en, this message translates to:
  /// **'Cover updated from {source}'**
  String metadataCoverUpdatedFrom(Object source);

  /// No description provided for @metadataNoOnlineMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching metadata found online'**
  String get metadataNoOnlineMatch;

  /// No description provided for @metadataSelectMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Online Match'**
  String get metadataSelectMatchTitle;

  /// No description provided for @metadataResultDetail.
  ///
  /// In en, this message translates to:
  /// **'{artist} · {album} ({source})'**
  String metadataResultDetail(Object artist, Object album, Object source);

  /// No description provided for @metadataLoadedFrom.
  ///
  /// In en, this message translates to:
  /// **'Metadata & cover loaded from {source}'**
  String metadataLoadedFrom(Object source);

  /// No description provided for @metadataFetchError.
  ///
  /// In en, this message translates to:
  /// **'Error fetching metadata: {error}'**
  String metadataFetchError(Object error);

  /// No description provided for @metadataSectionCover.
  ///
  /// In en, this message translates to:
  /// **'Cover Art'**
  String get metadataSectionCover;

  /// No description provided for @metadataChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Change Cover'**
  String get metadataChangeCover;

  /// No description provided for @metadataWhatDoesThisDo.
  ///
  /// In en, this message translates to:
  /// **'What does this do?'**
  String get metadataWhatDoesThisDo;

  /// No description provided for @metadataSectionFile.
  ///
  /// In en, this message translates to:
  /// **'File Information'**
  String get metadataSectionFile;

  /// No description provided for @metadataFilenameLabel.
  ///
  /// In en, this message translates to:
  /// **'Filename (without extension)'**
  String get metadataFilenameLabel;

  /// No description provided for @metadataFilenameHelper.
  ///
  /// In en, this message translates to:
  /// **'Renaming the file will update it locally.'**
  String get metadataFilenameHelper;

  /// No description provided for @metadataSectionSong.
  ///
  /// In en, this message translates to:
  /// **'Song Metadata'**
  String get metadataSectionSong;

  /// No description provided for @metadataFetchOnline.
  ///
  /// In en, this message translates to:
  /// **'Fetch Online'**
  String get metadataFetchOnline;

  /// No description provided for @metadataTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get metadataTitleLabel;

  /// No description provided for @metadataArtistLabel.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get metadataArtistLabel;

  /// No description provided for @metadataAlbumLabel.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get metadataAlbumLabel;

  /// No description provided for @metadataSectionExtra.
  ///
  /// In en, this message translates to:
  /// **'Additional Content'**
  String get metadataSectionExtra;

  /// No description provided for @metadataEditLyrics.
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics'**
  String get metadataEditLyrics;

  /// No description provided for @metadataEditLyricsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View or edit embedded lyrics'**
  String get metadataEditLyricsSubtitle;

  /// No description provided for @metadataSaveUpper.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get metadataSaveUpper;

  /// No description provided for @metadataLyricsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading lyrics: {error}'**
  String metadataLyricsLoadError(Object error);

  /// No description provided for @metadataLyricsSaved.
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved'**
  String get metadataLyricsSaved;

  /// No description provided for @metadataLyricsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Error saving lyrics: {error}'**
  String metadataLyricsSaveError(Object error);

  /// No description provided for @metadataLyricsLoaded.
  ///
  /// In en, this message translates to:
  /// **'Lyrics loaded — press SAVE to apply'**
  String get metadataLyricsLoaded;

  /// No description provided for @metadataSearchOnline.
  ///
  /// In en, this message translates to:
  /// **'Search online'**
  String get metadataSearchOnline;

  /// No description provided for @metadataLyricsHint.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are embedded in the audio file. You can use [mm:ss.xx] timestamps for synced lyrics.'**
  String get metadataLyricsHint;

  /// No description provided for @metadataLyricsFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Enter lyrics here...'**
  String get metadataLyricsFieldHint;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Single-letter avatar shown when no username is set
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get profileAvatarFallback;

  /// No description provided for @profileDefaultName.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileDefaultName;

  /// No description provided for @profileAppVersion.
  ///
  /// In en, this message translates to:
  /// **'wispie v{version}'**
  String profileAppVersion(String version);

  /// No description provided for @profileHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get profileHidden;

  /// No description provided for @profileSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Suggest-less'**
  String get profileSuggestLess;

  /// No description provided for @profileShuffleSection.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Personality'**
  String get profileShuffleSection;

  /// No description provided for @profileSmart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get profileSmart;

  /// No description provided for @profileSmartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learns your taste, trends and context. Recommended'**
  String get profileSmartSubtitle;

  /// No description provided for @profileDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get profileDefault;

  /// No description provided for @profileDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balanced mix with anti-repeat'**
  String get profileDefaultSubtitle;

  /// No description provided for @profileExplorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get profileExplorer;

  /// No description provided for @profileExplorerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prioritizes new & rare songs'**
  String get profileExplorerSubtitle;

  /// No description provided for @profileConsistent.
  ///
  /// In en, this message translates to:
  /// **'Consistent'**
  String get profileConsistent;

  /// No description provided for @profileConsistentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites heavy'**
  String get profileConsistentSubtitle;

  /// No description provided for @profileCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure your own shuffle'**
  String get profileCustomSubtitle;

  /// No description provided for @profileChangeName.
  ///
  /// In en, this message translates to:
  /// **'Change Display Name'**
  String get profileChangeName;

  /// No description provided for @profileNewNameHint.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get profileNewNameHint;

  /// No description provided for @profileUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get profileUpdate;

  /// No description provided for @profileNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get profileNameUpdated;

  /// No description provided for @profileCurrentName.
  ///
  /// In en, this message translates to:
  /// **'Current: {name}'**
  String profileCurrentName(String name);

  /// No description provided for @profilePersonalitySaved.
  ///
  /// In en, this message translates to:
  /// **'Personality saved'**
  String get profilePersonalitySaved;

  /// No description provided for @profileAppliesNextQueue.
  ///
  /// In en, this message translates to:
  /// **'Applies to the next queue'**
  String get profileAppliesNextQueue;

  /// No description provided for @profileConfigureCustomShuffle.
  ///
  /// In en, this message translates to:
  /// **'Configure Custom Shuffle'**
  String get profileConfigureCustomShuffle;

  /// No description provided for @profileConfigureCustomShuffleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust shuffle behavior settings'**
  String get profileConfigureCustomShuffleSubtitle;

  /// No description provided for @profileThemeStorage.
  ///
  /// In en, this message translates to:
  /// **'Theme & storage'**
  String get profileThemeStorage;

  /// No description provided for @profileFamiliar.
  ///
  /// In en, this message translates to:
  /// **'Familiar'**
  String get profileFamiliar;

  /// No description provided for @profileDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get profileDiscover;

  /// No description provided for @profileFamiliarToDiscover.
  ///
  /// In en, this message translates to:
  /// **'Familiar to Discover'**
  String get profileFamiliarToDiscover;

  /// No description provided for @profileLegacyCaption.
  ///
  /// In en, this message translates to:
  /// **'Legacy: fixed behaviour, kept for compatibility'**
  String get profileLegacyCaption;

  /// No description provided for @storageManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Storage'**
  String get storageManageTitle;

  /// No description provided for @storageRepairCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Repair Library Links'**
  String get storageRepairCardTitle;

  /// No description provided for @storageRepairCardBody.
  ///
  /// In en, this message translates to:
  /// **'Missing album art after a restore or a new phone? This re-links artwork and file paths.'**
  String get storageRepairCardBody;

  /// No description provided for @storageRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get storageRepair;

  /// No description provided for @storageRepairTitle.
  ///
  /// In en, this message translates to:
  /// **'Repair Library Links?'**
  String get storageRepairTitle;

  /// No description provided for @storageRepairBody.
  ///
  /// In en, this message translates to:
  /// **'This re-links cached album art and file paths to where they actually are on this device.\n\nTracks whose files are no longer here will be removed from the library. Favourites, playlists and play counts are kept, and reattach automatically if those files come back.'**
  String get storageRepairBody;

  /// No description provided for @storageRepairError.
  ///
  /// In en, this message translates to:
  /// **'Error repairing library: {error}'**
  String storageRepairError(Object error);

  /// No description provided for @storageDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get storageDatabaseTitle;

  /// No description provided for @storageDatabaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'User data, statistics, and settings'**
  String get storageDatabaseSubtitle;

  /// No description provided for @storageCoverCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Cover Cache'**
  String get storageCoverCacheTitle;

  /// No description provided for @storageCoverCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached song album art'**
  String get storageCoverCacheSubtitle;

  /// No description provided for @storageBackupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get storageBackupsTitle;

  /// No description provided for @storageBackupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local backup files'**
  String get storageBackupsSubtitle;

  /// No description provided for @storageLibraryCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Library Cache'**
  String get storageLibraryCacheTitle;

  /// No description provided for @storageLibraryCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached song library data'**
  String get storageLibraryCacheSubtitle;

  /// No description provided for @storageSearchIndexTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Index'**
  String get storageSearchIndexTitle;

  /// No description provided for @storageSearchIndexSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search index for fast queries'**
  String get storageSearchIndexSubtitle;

  /// No description provided for @storageWaveformCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Waveform Cache'**
  String get storageWaveformCacheTitle;

  /// No description provided for @storageWaveformCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached song waveforms for visualizers'**
  String get storageWaveformCacheSubtitle;

  /// No description provided for @storageBeatAnalysisTitle.
  ///
  /// In en, this message translates to:
  /// **'Beat Analysis'**
  String get storageBeatAnalysisTitle;

  /// No description provided for @storageBeatAnalysisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached beat maps for the reactive player'**
  String get storageBeatAnalysisSubtitle;

  /// No description provided for @storageColorCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Cache'**
  String get storageColorCacheTitle;

  /// No description provided for @storageColorCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached theme colors from album art'**
  String get storageColorCacheSubtitle;

  /// No description provided for @storageLyricsCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Cache'**
  String get storageLyricsCacheTitle;

  /// No description provided for @storageLyricsCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached lyrics availability and text'**
  String get storageLyricsCacheSubtitle;

  /// No description provided for @storageBlurredCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Blurred Cache'**
  String get storageBlurredCacheTitle;

  /// No description provided for @storageBlurredCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-generated blurred backgrounds'**
  String get storageBlurredCacheSubtitle;

  /// No description provided for @storageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get storageClear;

  /// No description provided for @storageClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get storageClearCache;

  /// No description provided for @storageClearDatabaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Database?'**
  String get storageClearDatabaseTitle;

  /// No description provided for @storageClearDatabaseBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your user data, including:\n\n• All playlists\n• Favorites and hidden songs\n• Playback statistics\n• App settings and preferences\n\nThe app will reset. This action cannot be undone.'**
  String get storageClearDatabaseBody;

  /// No description provided for @storageClearDatabaseAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Database'**
  String get storageClearDatabaseAction;

  /// No description provided for @storageClearDatabaseError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing database: {error}'**
  String storageClearDatabaseError(Object error);

  /// No description provided for @storageClearCoversTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cover Cache?'**
  String get storageClearCoversTitle;

  /// No description provided for @storageClearCoversBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached album artwork.\n\nThe covers will be re-extracted from your music files the next time you browse your library.'**
  String get storageClearCoversBody;

  /// No description provided for @storageClearCoversAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Covers'**
  String get storageClearCoversAction;

  /// No description provided for @storageClearCoversSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cover cache cleared successfully'**
  String get storageClearCoversSuccess;

  /// No description provided for @storageClearCoversError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing covers: {error}'**
  String storageClearCoversError(Object error);

  /// No description provided for @storageClearBackupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Backups?'**
  String get storageClearBackupsTitle;

  /// No description provided for @storageClearBackupsBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete all local backup files.\n\nMake sure you have exported any important backups before proceeding.'**
  String get storageClearBackupsBody;

  /// No description provided for @storageClearBackupsAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Backups'**
  String get storageClearBackupsAction;

  /// No description provided for @storageClearBackupsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backups cleared successfully'**
  String get storageClearBackupsSuccess;

  /// No description provided for @storageClearBackupsError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing backups: {error}'**
  String storageClearBackupsError(Object error);

  /// No description provided for @storageClearLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Library Cache?'**
  String get storageClearLibraryTitle;

  /// No description provided for @storageClearLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear the library cache.\n\nYour music library will be rescanned the next time you open the app.'**
  String get storageClearLibraryBody;

  /// No description provided for @storageClearLibrarySuccess.
  ///
  /// In en, this message translates to:
  /// **'Library cache cleared successfully'**
  String get storageClearLibrarySuccess;

  /// No description provided for @storageClearLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing library cache: {error}'**
  String storageClearLibraryError(Object error);

  /// No description provided for @storageClearSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Search Index?'**
  String get storageClearSearchTitle;

  /// No description provided for @storageClearSearchBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete the search index.\n\nThe search index will be rebuilt automatically when you rescan your library.'**
  String get storageClearSearchBody;

  /// No description provided for @storageClearSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Index'**
  String get storageClearSearchAction;

  /// No description provided for @storageClearSearchSuccess.
  ///
  /// In en, this message translates to:
  /// **'Search index cleared successfully'**
  String get storageClearSearchSuccess;

  /// No description provided for @storageClearSearchError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing search index: {error}'**
  String storageClearSearchError(Object error);

  /// No description provided for @storageClearWaveformTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Waveform Cache?'**
  String get storageClearWaveformTitle;

  /// No description provided for @storageClearWaveformBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached song waveforms.\n\nWaveforms will be regenerated the next time you view song details.'**
  String get storageClearWaveformBody;

  /// No description provided for @storageClearWaveformSuccess.
  ///
  /// In en, this message translates to:
  /// **'Waveform cache cleared successfully'**
  String get storageClearWaveformSuccess;

  /// No description provided for @storageClearWaveformError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing waveform cache: {error}'**
  String storageClearWaveformError(Object error);

  /// No description provided for @storageClearBeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Beat Analysis?'**
  String get storageClearBeatTitle;

  /// No description provided for @storageClearBeatBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete the cached beat maps used by the beat-reactive player.\n\nThey are rebuilt automatically the next time each song plays.'**
  String get storageClearBeatBody;

  /// No description provided for @storageClearBeatSuccess.
  ///
  /// In en, this message translates to:
  /// **'Beat analysis cache cleared successfully'**
  String get storageClearBeatSuccess;

  /// No description provided for @storageClearBeatError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing beat analysis cache: {error}'**
  String storageClearBeatError(Object error);

  /// No description provided for @storageClearColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Color Cache?'**
  String get storageClearColorTitle;

  /// No description provided for @storageClearColorBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached theme colors.\n\nColors will be re-extracted from album art the next time songs are played.'**
  String get storageClearColorBody;

  /// No description provided for @storageClearColorSuccess.
  ///
  /// In en, this message translates to:
  /// **'Color cache cleared successfully'**
  String get storageClearColorSuccess;

  /// No description provided for @storageClearColorError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing color cache: {error}'**
  String storageClearColorError(Object error);

  /// No description provided for @storageClearLyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Lyrics Cache?'**
  String get storageClearLyricsTitle;

  /// No description provided for @storageClearLyricsBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove cached lyrics lookups.\n\nLyrics will be re-read from song metadata when needed.'**
  String get storageClearLyricsBody;

  /// No description provided for @storageClearLyricsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Lyrics cache cleared successfully'**
  String get storageClearLyricsSuccess;

  /// No description provided for @storageClearLyricsError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing lyrics cache: {error}'**
  String storageClearLyricsError(Object error);

  /// No description provided for @storageClearBlurredTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Blurred Background Cache?'**
  String get storageClearBlurredTitle;

  /// No description provided for @storageClearBlurredBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete all pre-generated blurred backgrounds.\n\nThey will be re-generated the next time you trigger a rebuild in the Indexer.'**
  String get storageClearBlurredBody;

  /// No description provided for @storageClearBlurredSuccess.
  ///
  /// In en, this message translates to:
  /// **'Blurred background cache cleared successfully'**
  String get storageClearBlurredSuccess;

  /// No description provided for @storageClearBlurredError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing blurred cache: {error}'**
  String storageClearBlurredError(Object error);

  /// No description provided for @storageClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All App Data?'**
  String get storageClearAllTitle;

  /// No description provided for @storageClearAllBody.
  ///
  /// In en, this message translates to:
  /// **'This action is dangerous and cannot be undone.\n\nIt will permanently delete:\n• All your preferences and settings\n• Playback statistics and history\n• Cached song covers\n• All local backups\n• Library cache\n• Search index\n• Waveform cache\n• Lyrics cache\n\nThe app will reset.'**
  String get storageClearAllBody;

  /// No description provided for @storageClearAllAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Everything'**
  String get storageClearAllAction;

  /// No description provided for @storageClearAllError.
  ///
  /// In en, this message translates to:
  /// **'Error clearing data: {error}'**
  String storageClearAllError(Object error);

  /// No description provided for @storageClearAllTile.
  ///
  /// In en, this message translates to:
  /// **'Clear All User Data'**
  String get storageClearAllTile;

  /// No description provided for @storageClearAllTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all data and reset app'**
  String get storageClearAllTileSubtitle;

  /// No description provided for @storageFinalConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Final Confirmation'**
  String get storageFinalConfirmTitle;

  /// No description provided for @storageConfirmTypePrompt.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type \"{word}\" below:'**
  String storageConfirmTypePrompt(Object word);

  /// No description provided for @storageDeleteKeyword.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get storageDeleteKeyword;

  /// No description provided for @storageConfirmUpper.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get storageConfirmUpper;

  /// No description provided for @storageTypeExactly.
  ///
  /// In en, this message translates to:
  /// **'Please type the confirmation text exactly.'**
  String get storageTypeExactly;

  /// No description provided for @storageSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String storageSizeBytes(Object value);

  /// No description provided for @storageSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String storageSizeKb(Object value);

  /// No description provided for @storageSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String storageSizeMb(Object value);

  /// No description provided for @storageSizeGb.
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String storageSizeGb(Object value);

  /// No description provided for @settingsSearchIndexerTitle.
  ///
  /// In en, this message translates to:
  /// **'Indexer'**
  String get settingsSearchIndexerTitle;

  /// No description provided for @settingsSearchIndexerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rebuild indexes and caches'**
  String get settingsSearchIndexerSubtitle;

  /// No description provided for @settingsSearchMusicFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Music Folders'**
  String get settingsSearchMusicFoldersTitle;

  /// No description provided for @settingsSearchMusicFoldersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage music library folders'**
  String get settingsSearchMusicFoldersSubtitle;

  /// No description provided for @settingsSearchRescanTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-scan Library Now'**
  String get settingsSearchRescanTitle;

  /// No description provided for @settingsSearchRescanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manually refresh all songs from disk'**
  String get settingsSearchRescanSubtitle;

  /// No description provided for @settingsSearchIncludeVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'Include Videos'**
  String get settingsSearchIncludeVideosTitle;

  /// No description provided for @settingsSearchIncludeVideosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show video files in your song library'**
  String get settingsSearchIncludeVideosSubtitle;

  /// No description provided for @settingsSearchMinFileSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Minimum File Size'**
  String get settingsSearchMinFileSizeTitle;

  /// No description provided for @settingsSearchMinFileSizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore files smaller than this'**
  String get settingsSearchMinFileSizeSubtitle;

  /// No description provided for @settingsSearchMinDurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Minimum Duration'**
  String get settingsSearchMinDurationTitle;

  /// No description provided for @settingsSearchMinDurationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore tracks shorter than this'**
  String get settingsSearchMinDurationSubtitle;

  /// No description provided for @settingsSearchManageFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage music folders'**
  String get settingsSearchManageFoldersTitle;

  /// No description provided for @settingsSearchManageFoldersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, remove and rescan individual folders'**
  String get settingsSearchManageFoldersSubtitle;

  /// No description provided for @settingsSearchPullToRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull to Refresh'**
  String get settingsSearchPullToRefreshTitle;

  /// No description provided for @settingsSearchPullToRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Swipe down to refresh the library'**
  String get settingsSearchPullToRefreshSubtitle;

  /// No description provided for @settingsSearchAutoPauseMuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Pause on Mute'**
  String get settingsSearchAutoPauseMuteTitle;

  /// No description provided for @settingsSearchAutoPauseMuteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause playback when volume reaches 0'**
  String get settingsSearchAutoPauseMuteSubtitle;

  /// No description provided for @settingsSearchAutoResumeUnmuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Resume on Unmute'**
  String get settingsSearchAutoResumeUnmuteTitle;

  /// No description provided for @settingsSearchAutoResumeUnmuteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resume playback when volume is restored'**
  String get settingsSearchAutoResumeUnmuteSubtitle;

  /// No description provided for @settingsSearchGapTitle.
  ///
  /// In en, this message translates to:
  /// **'Gap / Delay'**
  String get settingsSearchGapTitle;

  /// No description provided for @settingsSearchGapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Silence between tracks'**
  String get settingsSearchGapSubtitle;

  /// No description provided for @settingsSearchFadeOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Fade Out'**
  String get settingsSearchFadeOutTitle;

  /// No description provided for @settingsSearchFadeOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fade the outgoing track'**
  String get settingsSearchFadeOutSubtitle;

  /// No description provided for @settingsSearchFadeInTitle.
  ///
  /// In en, this message translates to:
  /// **'Fade In'**
  String get settingsSearchFadeInTitle;

  /// No description provided for @settingsSearchFadeInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fade the incoming track'**
  String get settingsSearchFadeInSubtitle;

  /// No description provided for @settingsSearchFadePlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Fade on Play'**
  String get settingsSearchFadePlayTitle;

  /// No description provided for @settingsSearchFadePlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ease the volume up when playback starts'**
  String get settingsSearchFadePlaySubtitle;

  /// No description provided for @settingsSearchFadePauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Fade on Pause'**
  String get settingsSearchFadePauseTitle;

  /// No description provided for @settingsSearchFadePauseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ease the volume down when playback stops'**
  String get settingsSearchFadePauseSubtitle;

  /// No description provided for @settingsSearchRichSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate Word Sync'**
  String get settingsSearchRichSyncTitle;

  /// No description provided for @settingsSearchRichSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate word-level timing from line-synced lyrics using prosodic estimation'**
  String get settingsSearchRichSyncSubtitle;

  /// No description provided for @settingsSearchSidebarTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics & Queue Sidebar'**
  String get settingsSearchSidebarTitle;

  /// No description provided for @settingsSearchSidebarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden'**
  String get settingsSearchSidebarSubtitle;

  /// No description provided for @settingsSearchKeepAwakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Screen Awake on Lyrics'**
  String get settingsSearchKeepAwakeTitle;

  /// No description provided for @settingsSearchKeepAwakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevent sleep while the lyrics pane is open'**
  String get settingsSearchKeepAwakeSubtitle;

  /// No description provided for @settingsSearchAutoTranslateTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Translate Lyrics'**
  String get settingsSearchAutoTranslateTitle;

  /// No description provided for @settingsSearchAutoTranslateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate lyrics using selected target language'**
  String get settingsSearchAutoTranslateSubtitle;

  /// No description provided for @settingsSearchTargetLangTitle.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get settingsSearchTargetLangTitle;

  /// No description provided for @settingsSearchTargetLangSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language to translate lyrics into'**
  String get settingsSearchTargetLangSubtitle;

  /// No description provided for @settingsSearchTranslationModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Translation Display'**
  String get settingsSearchTranslationModeTitle;

  /// No description provided for @settingsSearchTranslationModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show subtext below lyrics or replace base lyrics'**
  String get settingsSearchTranslationModeSubtitle;

  /// No description provided for @settingsSearchVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off, classic bars, or bars synced to the song'**
  String get settingsSearchVisualizerSubtitle;

  /// No description provided for @settingsSearchLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get settingsSearchLanguageSubtitle;

  /// No description provided for @settingsSearchProgressBarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard, waveform, or sound-reactive progress bar'**
  String get settingsSearchProgressBarSubtitle;

  /// No description provided for @settingsSearchSongDurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Song Duration'**
  String get settingsSearchSongDurationTitle;

  /// No description provided for @settingsSearchSongDurationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display duration in song lists'**
  String get settingsSearchSongDurationSubtitle;

  /// No description provided for @settingsSearchAutoHideBarsTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Hide Bars'**
  String get settingsSearchAutoHideBarsTitle;

  /// No description provided for @settingsSearchAutoHideBarsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Header and bottom dock hide on downward scroll'**
  String get settingsSearchAutoHideBarsSubtitle;

  /// No description provided for @settingsSearchAppIconSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which icon wispie uses'**
  String get settingsSearchAppIconSubtitle;

  /// No description provided for @settingsSearchBeatCoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Album art pulses with the beat (classic player only)'**
  String get settingsSearchBeatCoverSubtitle;

  /// No description provided for @settingsSearchSpinArtworkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Artwork turns in the minimized bottom bar while a song plays'**
  String get settingsSearchSpinArtworkSubtitle;

  /// No description provided for @settingsSearchCoverIntensitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How strongly the album art reacts to the beat'**
  String get settingsSearchCoverIntensitySubtitle;

  /// No description provided for @settingsSearchParticleDensitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How many particles and how lively they are'**
  String get settingsSearchParticleDensitySubtitle;

  /// No description provided for @settingsSearchBeatOffsetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compensate for Bluetooth output latency'**
  String get settingsSearchBeatOffsetSubtitle;

  /// No description provided for @settingsSearchQuickPicksTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Picks'**
  String get settingsSearchQuickPicksTitle;

  /// No description provided for @settingsSearchQuickPicksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show quick pick recommendations'**
  String get settingsSearchQuickPicksSubtitle;

  /// No description provided for @settingsSearchRecentQueuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Queues'**
  String get settingsSearchRecentQueuesTitle;

  /// No description provided for @settingsSearchRecentQueuesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show recently played queues'**
  String get settingsSearchRecentQueuesSubtitle;

  /// No description provided for @settingsSearchForYouTitle.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get settingsSearchForYouTitle;

  /// No description provided for @settingsSearchForYouSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show recommended playlists'**
  String get settingsSearchForYouSubtitle;

  /// No description provided for @settingsSearchQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get settingsSearchQuickActionsTitle;

  /// No description provided for @settingsSearchQuickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize long-press actions'**
  String get settingsSearchQuickActionsSubtitle;

  /// No description provided for @settingsSearchReorderQuickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder quick actions'**
  String get settingsSearchReorderQuickActionsTitle;

  /// No description provided for @settingsSearchReorderQuickActionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose and order the long-press actions on a song'**
  String get settingsSearchReorderQuickActionsSubtitle;

  /// No description provided for @settingsSearchBulkRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Rename Files'**
  String get settingsSearchBulkRenameTitle;

  /// No description provided for @settingsSearchBulkRenameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rename the whole library from a format'**
  String get settingsSearchBulkRenameSubtitle;

  /// No description provided for @settingsSearchManageStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disk usage and data management'**
  String get settingsSearchManageStorageSubtitle;

  /// No description provided for @settingsSearchBackupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse, restore and delete saved backups'**
  String get settingsSearchBackupsSubtitle;

  /// No description provided for @settingsSearchStorageUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disk usage by covers, waveforms, lyrics and caches'**
  String get settingsSearchStorageUsageSubtitle;

  /// No description provided for @settingsCrumbStorage.
  ///
  /// In en, this message translates to:
  /// **'Settings › Storage'**
  String get settingsCrumbStorage;

  /// No description provided for @settingsCrumbLibrary.
  ///
  /// In en, this message translates to:
  /// **'Settings › Library'**
  String get settingsCrumbLibrary;

  /// No description provided for @settingsCrumbLibraryFilters.
  ///
  /// In en, this message translates to:
  /// **'Settings › Library › Filters'**
  String get settingsCrumbLibraryFilters;

  /// No description provided for @settingsCrumbLibraryFolders.
  ///
  /// In en, this message translates to:
  /// **'Settings › Library › Music Folders'**
  String get settingsCrumbLibraryFolders;

  /// No description provided for @settingsCrumbLibraryMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Settings › Library › Maintenance'**
  String get settingsCrumbLibraryMaintenance;

  /// No description provided for @settingsCrumbPlaybackAudio.
  ///
  /// In en, this message translates to:
  /// **'Settings › Playback › Audio'**
  String get settingsCrumbPlaybackAudio;

  /// No description provided for @settingsCrumbPlaybackTransitions.
  ///
  /// In en, this message translates to:
  /// **'Settings › Playback › Transitions'**
  String get settingsCrumbPlaybackTransitions;

  /// No description provided for @settingsCrumbPlaybackPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Settings › Playback › Play / Pause'**
  String get settingsCrumbPlaybackPlayPause;

  /// No description provided for @settingsCrumbLyricsTiming.
  ///
  /// In en, this message translates to:
  /// **'Settings › Lyrics › Display & Timing'**
  String get settingsCrumbLyricsTiming;

  /// No description provided for @settingsCrumbLyricsTranslation.
  ///
  /// In en, this message translates to:
  /// **'Settings › Lyrics › Translation'**
  String get settingsCrumbLyricsTranslation;

  /// No description provided for @settingsCrumbAppearanceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Language'**
  String get settingsCrumbAppearanceLanguage;

  /// No description provided for @settingsCrumbAppearanceNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Now Playing'**
  String get settingsCrumbAppearanceNowPlaying;

  /// No description provided for @settingsCrumbAppearanceAppIcon.
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › App icon'**
  String get settingsCrumbAppearanceAppIcon;

  /// No description provided for @settingsCrumbAppearanceMotion.
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Player motion'**
  String get settingsCrumbAppearanceMotion;

  /// No description provided for @settingsCrumbAppearanceLists.
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Lists & Navigation'**
  String get settingsCrumbAppearanceLists;

  /// No description provided for @settingsCrumbHomeLists.
  ///
  /// In en, this message translates to:
  /// **'Settings › Home & Navigation › Lists & Navigation'**
  String get settingsCrumbHomeLists;

  /// No description provided for @settingsCrumbHomeScreen.
  ///
  /// In en, this message translates to:
  /// **'Settings › Home & Navigation › Home screen'**
  String get settingsCrumbHomeScreen;

  /// No description provided for @settingsCrumbBackup.
  ///
  /// In en, this message translates to:
  /// **'Settings › Backup & Restore'**
  String get settingsCrumbBackup;

  /// No description provided for @settingsCrumbAutoBackups.
  ///
  /// In en, this message translates to:
  /// **'Settings › Backup & Restore › Automatic Backups'**
  String get settingsCrumbAutoBackups;

  /// No description provided for @settingsCrumbManageBackups.
  ///
  /// In en, this message translates to:
  /// **'Settings › Data Management › Manage Backups'**
  String get settingsCrumbManageBackups;

  /// No description provided for @settingsCrumbManageStorage.
  ///
  /// In en, this message translates to:
  /// **'Settings › Data Management › Manage Storage'**
  String get settingsCrumbManageStorage;

  /// No description provided for @settingsCrumbProfileShuffle.
  ///
  /// In en, this message translates to:
  /// **'Profile › Shuffle'**
  String get settingsCrumbProfileShuffle;

  /// No description provided for @settingsKwLibrary.
  ///
  /// In en, this message translates to:
  /// **'scan,folders,filters,songs'**
  String get settingsKwLibrary;

  /// No description provided for @settingsKwPlayback.
  ///
  /// In en, this message translates to:
  /// **'audio,sound,transitions'**
  String get settingsKwPlayback;

  /// No description provided for @settingsKwLyrics.
  ///
  /// In en, this message translates to:
  /// **'lyrics,translate,karaoke,subtitles'**
  String get settingsKwLyrics;

  /// No description provided for @settingsKwHome.
  ///
  /// In en, this message translates to:
  /// **'home,quick picks,gestures,bars,layout'**
  String get settingsKwHome;

  /// No description provided for @settingsKwStorage.
  ///
  /// In en, this message translates to:
  /// **'disk,space,cache,indexer,cleanup'**
  String get settingsKwStorage;

  /// No description provided for @settingsKwAppearance.
  ///
  /// In en, this message translates to:
  /// **'theme,colour,color,display,look'**
  String get settingsKwAppearance;

  /// No description provided for @settingsKwSync.
  ///
  /// In en, this message translates to:
  /// **'cloud,account,devices,encrypted'**
  String get settingsKwSync;

  /// No description provided for @settingsKwBackup.
  ///
  /// In en, this message translates to:
  /// **'backup,restore,export,import,data'**
  String get settingsKwBackup;

  /// No description provided for @settingsKwIndexer.
  ///
  /// In en, this message translates to:
  /// **'index,rebuild,cache,reindex'**
  String get settingsKwIndexer;

  /// No description provided for @settingsKwAbout.
  ///
  /// In en, this message translates to:
  /// **'version,update,changelog,release'**
  String get settingsKwAbout;

  /// No description provided for @settingsKwFolders.
  ///
  /// In en, this message translates to:
  /// **'directory,path,add folder,sources'**
  String get settingsKwFolders;

  /// No description provided for @settingsKwRescan.
  ///
  /// In en, this message translates to:
  /// **'refresh,reload,sync'**
  String get settingsKwRescan;

  /// No description provided for @settingsKwVideos.
  ///
  /// In en, this message translates to:
  /// **'video,mp4,clips'**
  String get settingsKwVideos;

  /// No description provided for @settingsKwMinFileSize.
  ///
  /// In en, this message translates to:
  /// **'size,skip,small,filter'**
  String get settingsKwMinFileSize;

  /// No description provided for @settingsKwMinDuration.
  ///
  /// In en, this message translates to:
  /// **'length,short,skip,filter,interlude'**
  String get settingsKwMinDuration;

  /// No description provided for @settingsKwManageFolders.
  ///
  /// In en, this message translates to:
  /// **'folder,directory,storage,sd card'**
  String get settingsKwManageFolders;

  /// No description provided for @settingsKwPullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'swipe,gesture,reload'**
  String get settingsKwPullToRefresh;

  /// No description provided for @settingsKwMute.
  ///
  /// In en, this message translates to:
  /// **'volume,silent,mute'**
  String get settingsKwMute;

  /// No description provided for @settingsKwUnmute.
  ///
  /// In en, this message translates to:
  /// **'volume,unmute,continue'**
  String get settingsKwUnmute;

  /// No description provided for @settingsKwGap.
  ///
  /// In en, this message translates to:
  /// **'pause,silence,between,transition'**
  String get settingsKwGap;

  /// No description provided for @settingsKwCrossfade.
  ///
  /// In en, this message translates to:
  /// **'crossfade,gapless,transition,blend'**
  String get settingsKwCrossfade;

  /// No description provided for @settingsKwFadePlay.
  ///
  /// In en, this message translates to:
  /// **'ramp,volume,start'**
  String get settingsKwFadePlay;

  /// No description provided for @settingsKwFadePause.
  ///
  /// In en, this message translates to:
  /// **'ramp,volume,stop'**
  String get settingsKwFadePause;

  /// No description provided for @settingsKwRichSync.
  ///
  /// In en, this message translates to:
  /// **'lyrics,richsync,karaoke,word,sync'**
  String get settingsKwRichSync;

  /// No description provided for @settingsKwSidebar.
  ///
  /// In en, this message translates to:
  /// **'sidebar,panel,desktop,queue,lyrics'**
  String get settingsKwSidebar;

  /// No description provided for @settingsKwKeepAwake.
  ///
  /// In en, this message translates to:
  /// **'sleep,wakelock,display,lyrics'**
  String get settingsKwKeepAwake;

  /// No description provided for @settingsKwAutoTranslate.
  ///
  /// In en, this message translates to:
  /// **'translate,translation,language,lyrics,auto'**
  String get settingsKwAutoTranslate;

  /// No description provided for @settingsKwTargetLang.
  ///
  /// In en, this message translates to:
  /// **'translate,language,spanish,english,japanese'**
  String get settingsKwTargetLang;

  /// No description provided for @settingsKwTranslationMode.
  ///
  /// In en, this message translates to:
  /// **'translate,mode,subtext,replace,display'**
  String get settingsKwTranslationMode;

  /// No description provided for @settingsKwVisualizer.
  ///
  /// In en, this message translates to:
  /// **'wave,animation,spectrum,bars,sync,bass'**
  String get settingsKwVisualizer;

  /// No description provided for @settingsKwLanguage.
  ///
  /// In en, this message translates to:
  /// **'language,locale,translation,english'**
  String get settingsKwLanguage;

  /// No description provided for @settingsKwProgressBar.
  ///
  /// In en, this message translates to:
  /// **'seek,progress,wave,reactive,spectrum'**
  String get settingsKwProgressBar;

  /// No description provided for @settingsKwHaptics.
  ///
  /// In en, this message translates to:
  /// **'vibrate,haptic,feedback,waveform,scrub,seek'**
  String get settingsKwHaptics;

  /// No description provided for @settingsKwSongDuration.
  ///
  /// In en, this message translates to:
  /// **'length,time,lists'**
  String get settingsKwSongDuration;

  /// No description provided for @settingsKwAutoHide.
  ///
  /// In en, this message translates to:
  /// **'navigation,dock,header,scroll,hide'**
  String get settingsKwAutoHide;

  /// No description provided for @settingsKwCoverSizing.
  ///
  /// In en, this message translates to:
  /// **'artwork,album art,aspect,crop'**
  String get settingsKwCoverSizing;

  /// No description provided for @settingsKwImmersive.
  ///
  /// In en, this message translates to:
  /// **'immersive,full bleed,player,detail,gradient,cover,design'**
  String get settingsKwImmersive;

  /// No description provided for @settingsKwAppIcon.
  ///
  /// In en, this message translates to:
  /// **'icon,logo,launcher,dock,classic,new'**
  String get settingsKwAppIcon;

  /// No description provided for @settingsKwBeatCover.
  ///
  /// In en, this message translates to:
  /// **'pulse,beat,artwork,motion'**
  String get settingsKwBeatCover;

  /// No description provided for @settingsKwSpinArtwork.
  ///
  /// In en, this message translates to:
  /// **'rotate,turn,spin,artwork,dock,mini'**
  String get settingsKwSpinArtwork;

  /// No description provided for @settingsKwBeatParticles.
  ///
  /// In en, this message translates to:
  /// **'particles,motes,beat,motion'**
  String get settingsKwBeatParticles;

  /// No description provided for @settingsKwCoverIntensity.
  ///
  /// In en, this message translates to:
  /// **'cover,album,pulse,subtle,balanced,bold'**
  String get settingsKwCoverIntensity;

  /// No description provided for @settingsKwParticleDensity.
  ///
  /// In en, this message translates to:
  /// **'particles,motes,density,subtle,balanced,bold'**
  String get settingsKwParticleDensity;

  /// No description provided for @settingsKwBeatOffset.
  ///
  /// In en, this message translates to:
  /// **'bluetooth,latency,delay,sync,early'**
  String get settingsKwBeatOffset;

  /// No description provided for @settingsKwCalibrate.
  ///
  /// In en, this message translates to:
  /// **'calibrate,sync,latency,offset,test,click'**
  String get settingsKwCalibrate;

  /// No description provided for @settingsKwQuickPicks.
  ///
  /// In en, this message translates to:
  /// **'home,recommendations,suggestions'**
  String get settingsKwQuickPicks;

  /// No description provided for @settingsKwRecentQueues.
  ///
  /// In en, this message translates to:
  /// **'home,history,queue'**
  String get settingsKwRecentQueues;

  /// No description provided for @settingsKwForYou.
  ///
  /// In en, this message translates to:
  /// **'home,mixes,recommendations'**
  String get settingsKwForYou;

  /// No description provided for @settingsKwQuickActions.
  ///
  /// In en, this message translates to:
  /// **'long press,menu,shortcuts'**
  String get settingsKwQuickActions;

  /// No description provided for @settingsKwReorderQuickActions.
  ///
  /// In en, this message translates to:
  /// **'long press,order,menu,shortcuts'**
  String get settingsKwReorderQuickActions;

  /// No description provided for @settingsKwExport.
  ///
  /// In en, this message translates to:
  /// **'backup,save,export'**
  String get settingsKwExport;

  /// No description provided for @settingsKwImport.
  ///
  /// In en, this message translates to:
  /// **'restore,load,import'**
  String get settingsKwImport;

  /// No description provided for @settingsKwManageBackups.
  ///
  /// In en, this message translates to:
  /// **'backup,restore,delete'**
  String get settingsKwManageBackups;

  /// No description provided for @settingsKwBulkRename.
  ///
  /// In en, this message translates to:
  /// **'rename,filenames,batch,bulk,format,naming'**
  String get settingsKwBulkRename;

  /// No description provided for @settingsKwManageStorage.
  ///
  /// In en, this message translates to:
  /// **'disk,space,cache,cleanup'**
  String get settingsKwManageStorage;

  /// No description provided for @settingsKwBackups.
  ///
  /// In en, this message translates to:
  /// **'backup,restore,archive'**
  String get settingsKwBackups;

  /// No description provided for @settingsKwStorageUsage.
  ///
  /// In en, this message translates to:
  /// **'disk,space,clear cache,usage'**
  String get settingsKwStorageUsage;

  /// No description provided for @settingsKwAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'schedule,frequency,automatic'**
  String get settingsKwAutoBackup;

  /// No description provided for @settingsKwAutoBackupContent.
  ///
  /// In en, this message translates to:
  /// **'contents,categories,automatic'**
  String get settingsKwAutoBackupContent;

  /// No description provided for @settingsKwAutoDelete.
  ///
  /// In en, this message translates to:
  /// **'prune,cleanup,retention,old'**
  String get settingsKwAutoDelete;

  /// No description provided for @settingsKwShuffle.
  ///
  /// In en, this message translates to:
  /// **'shuffle,personality,weights,random,explorer'**
  String get settingsKwShuffle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
