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

  /// No description provided for @metadataReplaceRejectNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file was selected.'**
  String get metadataReplaceRejectNoFile;

  /// No description provided for @metadataReplaceRejectUnsupported.
  ///
  /// In en, this message translates to:
  /// **'That file is not an audio or video format this library can read.'**
  String get metadataReplaceRejectUnsupported;

  /// No description provided for @metadataReplaceRejectSameFilename.
  ///
  /// In en, this message translates to:
  /// **'The replacement needs a different filename. Changing only the extension is enough.'**
  String get metadataReplaceRejectSameFilename;

  /// No description provided for @metadataReplaceRejectInsideLibrary.
  ///
  /// In en, this message translates to:
  /// **'That file is inside one of your library folders. Pick a copy from somewhere outside your library.'**
  String get metadataReplaceRejectInsideLibrary;

  /// No description provided for @metadataReplaceRejectDestinationExists.
  ///
  /// In en, this message translates to:
  /// **'A file named \"{filename}\" already sits next to the original.'**
  String metadataReplaceRejectDestinationExists(String filename);

  /// No description provided for @metadataReplaceRejectLibraryHasName.
  ///
  /// In en, this message translates to:
  /// **'Your library already has a song named \"{filename}\".'**
  String metadataReplaceRejectLibraryHasName(String filename);

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

  /// No description provided for @setupUnableToAccessFolder.
  ///
  /// In en, this message translates to:
  /// **'Unable to access selected folder'**
  String get setupUnableToAccessFolder;

  /// No description provided for @setupFolderAdded.
  ///
  /// In en, this message translates to:
  /// **'Music folder added'**
  String get setupFolderAdded;

  /// No description provided for @setupFolderRemoved.
  ///
  /// In en, this message translates to:
  /// **'Music folder removed'**
  String get setupFolderRemoved;

  /// No description provided for @setupStoragePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to scan your music library.'**
  String get setupStoragePermissionRequired;

  /// No description provided for @setupEnterDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a display name'**
  String get setupEnterDisplayName;

  /// No description provided for @setupSetupError.
  ///
  /// In en, this message translates to:
  /// **'Setup error: {error}'**
  String setupSetupError(String error);

  /// No description provided for @setupIntroTagline.
  ///
  /// In en, this message translates to:
  /// **'Your music stays on your device.'**
  String get setupIntroTagline;

  /// No description provided for @setupGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get setupGetStarted;

  /// No description provided for @setupPreviousStep.
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get setupPreviousStep;

  /// No description provided for @setupSettingThingsUp.
  ///
  /// In en, this message translates to:
  /// **'Setting things up'**
  String get setupSettingThingsUp;

  /// No description provided for @setupStartListening.
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get setupStartListening;

  /// No description provided for @setupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// No description provided for @setupNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get setupNameTitle;

  /// No description provided for @setupNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'wispie uses your name to greet you and to sign your listening history. Nothing leaves this device either way.'**
  String get setupNameSubtitle;

  /// No description provided for @setupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get setupNameHint;

  /// No description provided for @setupGreeting.
  ///
  /// In en, this message translates to:
  /// **'Nice to meet you, {name}.'**
  String setupGreeting(String name);

  /// No description provided for @setupAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Make it look the way you like.'**
  String get setupAppearanceTitle;

  /// No description provided for @setupAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything on this page also lives in Settings, so you can change it whenever you want.'**
  String get setupAppearanceSubtitle;

  /// No description provided for @setupImmersiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A full-bleed cover player and gradient detail screens.'**
  String get setupImmersiveSubtitle;

  /// No description provided for @setupVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bars over the artwork while you listen. Synced follows the song rather than a random pattern.'**
  String get setupVisualizerSubtitle;

  /// No description provided for @setupBeatCoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The album art breathes on every beat.'**
  String get setupBeatCoverSubtitle;

  /// No description provided for @setupParticlesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Motes drift across the player, and each beat carries them further instead of just blinking them.'**
  String get setupParticlesSubtitle;

  /// No description provided for @setupProgressBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress bar'**
  String get setupProgressBarTitle;

  /// No description provided for @setupProgressBarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Draw the song itself as a waveform instead of a plain line. Sound reactive makes it move as it plays.'**
  String get setupProgressBarSubtitle;

  /// No description provided for @setupFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'Where is your music?'**
  String get setupFoldersTitle;

  /// No description provided for @setupFoldersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Point wispie at the folders your songs live in. It only reads them, and you can add as many as you like.'**
  String get setupFoldersSubtitle;

  /// No description provided for @setupStoragePermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage permission'**
  String get setupStoragePermissionTitle;

  /// No description provided for @setupStoragePermissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'wispie needs it to find audio files on this device.'**
  String get setupStoragePermissionSubtitle;

  /// No description provided for @setupOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get setupOpenSystemSettings;

  /// No description provided for @setupGrantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get setupGrantPermission;

  /// No description provided for @setupNoFoldersTitle.
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get setupNoFoldersTitle;

  /// No description provided for @setupNoFoldersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add the one that holds your songs.'**
  String get setupNoFoldersSubtitle;

  /// No description provided for @setupRemoveFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get setupRemoveFolderTooltip;

  /// No description provided for @setupAddFolder.
  ///
  /// In en, this message translates to:
  /// **'Add a folder'**
  String get setupAddFolder;

  /// No description provided for @setupSummaryMusicFolders.
  ///
  /// In en, this message translates to:
  /// **'Music folders'**
  String get setupSummaryMusicFolders;

  /// No description provided for @setupReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'You are all set.'**
  String get setupReadyTitle;

  /// No description provided for @setupReadyTitleNamed.
  ///
  /// In en, this message translates to:
  /// **'You are all set, {name}.'**
  String setupReadyTitleNamed(String name);

  /// No description provided for @setupReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here is what we set up. You can change any of it later from Settings.'**
  String get setupReadySubtitle;

  /// No description provided for @setupOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get setupOn;

  /// No description provided for @setupOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get setupOff;

  /// No description provided for @backupLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading backups: {error}'**
  String backupLoadError(Object error);

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created: {name}'**
  String backupCreated(Object name);

  /// No description provided for @backupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create backup: {error}'**
  String backupCreateFailed(Object error);

  /// No description provided for @backupValidateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to validate backup: {error}'**
  String backupValidateFailed(Object error);

  /// No description provided for @backupReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'DANGER: Full Data Replace'**
  String get backupReplaceTitle;

  /// No description provided for @backupReplaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure you want to restore from {name}?'**
  String backupReplaceConfirm(Object name);

  /// No description provided for @backupReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'WARNING: This will COMPLETELY REPLACE all your current data:'**
  String get backupReplaceWarning;

  /// No description provided for @backupReplaceItemStats.
  ///
  /// In en, this message translates to:
  /// **'• All your current statistics and play history'**
  String get backupReplaceItemStats;

  /// No description provided for @backupReplaceItemFavorites.
  ///
  /// In en, this message translates to:
  /// **'• All your favorites and playlists'**
  String get backupReplaceItemFavorites;

  /// No description provided for @backupReplaceItemHidden.
  ///
  /// In en, this message translates to:
  /// **'• All your hidden songs and preferences'**
  String get backupReplaceItemHidden;

  /// No description provided for @backupReplaceItemSettings.
  ///
  /// In en, this message translates to:
  /// **'• All your current settings and state'**
  String get backupReplaceItemSettings;

  /// No description provided for @backupReplaceItemLibrary.
  ///
  /// In en, this message translates to:
  /// **'• Your scanned song library'**
  String get backupReplaceItemLibrary;

  /// No description provided for @backupReplaceRekeyNote.
  ///
  /// In en, this message translates to:
  /// **'Album art and file paths are re-linked to this device automatically after the restore. Tracks in the backup whose files are not on this device are removed from the library.'**
  String get backupReplaceRekeyNote;

  /// No description provided for @backupReplaceIrreversible.
  ///
  /// In en, this message translates to:
  /// **'YOUR CURRENT DATA WILL BE PERMANENTLY LOST!'**
  String get backupReplaceIrreversible;

  /// No description provided for @backupReplaceNoUndo.
  ///
  /// In en, this message translates to:
  /// **'There is NO way to undo this action.'**
  String get backupReplaceNoUndo;

  /// No description provided for @backupReplaceConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'YES, REPLACE EVERYTHING'**
  String get backupReplaceConfirmAction;

  /// No description provided for @backupRestoringLabel.
  ///
  /// In en, this message translates to:
  /// **'Restoring data…'**
  String get backupRestoringLabel;

  /// No description provided for @backupRestoreSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data replaced successfully!'**
  String get backupRestoreSuccess;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore backup: {error}'**
  String backupRestoreFailed(Object error);

  /// No description provided for @backupDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Backup'**
  String get backupDeleteTitle;

  /// No description provided for @backupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String backupDeleteConfirm(Object name);

  /// No description provided for @backupDeleteUpper.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get backupDeleteUpper;

  /// No description provided for @backupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Backup deleted'**
  String get backupDeleted;

  /// No description provided for @backupDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete backup: {error}'**
  String backupDeleteFailed(Object error);

  /// No description provided for @backupExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Backup exported to: {path}'**
  String backupExportedTo(Object path);

  /// No description provided for @backupNoOlderBackup.
  ///
  /// In en, this message translates to:
  /// **'No older backup to compare with.'**
  String get backupNoOlderBackup;

  /// No description provided for @backupComparing.
  ///
  /// In en, this message translates to:
  /// **'Comparing backups...'**
  String get backupComparing;

  /// No description provided for @backupComparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Comparison with #{number}'**
  String backupComparisonTitle(int number);

  /// No description provided for @backupDiffSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get backupDiffSongs;

  /// No description provided for @backupDiffStatsRows.
  ///
  /// In en, this message translates to:
  /// **'Stats Rows'**
  String get backupDiffStatsRows;

  /// No description provided for @backupDiffSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get backupDiffSize;

  /// No description provided for @backupDiffDataAdded.
  ///
  /// In en, this message translates to:
  /// **'Data Added'**
  String get backupDiffDataAdded;

  /// No description provided for @backupCloseUpper.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get backupCloseUpper;

  /// No description provided for @backupCompareError.
  ///
  /// In en, this message translates to:
  /// **'Error comparing backups: {error}'**
  String backupCompareError(Object error);

  /// No description provided for @backupNoChange.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get backupNoChange;

  /// No description provided for @backupManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup Management'**
  String get backupManagementTitle;

  /// No description provided for @backupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get backupCreating;

  /// No description provided for @backupCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get backupCreateAction;

  /// No description provided for @backupEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupEmptyTitle;

  /// No description provided for @backupEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first backup to protect your data'**
  String get backupEmptySubtitle;

  /// No description provided for @backupSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String backupSizeLabel(Object size);

  /// No description provided for @backupActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupActionRestore;

  /// No description provided for @backupActionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupActionExport;

  /// No description provided for @backupActionCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get backupActionCompare;

  /// No description provided for @backupRestartTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get backupRestartTitle;

  /// No description provided for @backupRestartMessage.
  ///
  /// In en, this message translates to:
  /// **'Backup restore has been completed successfully.\n\nThe app needs to restart to apply all changes properly.'**
  String get backupRestartMessage;

  /// No description provided for @backupRestartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get backupRestartNow;

  /// No description provided for @backupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get backupDialogTitle;

  /// No description provided for @backupSelectContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select content to backup'**
  String get backupSelectContentSubtitle;

  /// No description provided for @backupContentArtistArtCache.
  ///
  /// In en, this message translates to:
  /// **'Artist Art Cache'**
  String get backupContentArtistArtCache;

  /// No description provided for @backupContentAlbumArtCache.
  ///
  /// In en, this message translates to:
  /// **'Album Art Cache'**
  String get backupContentAlbumArtCache;

  /// No description provided for @backupContentDescUserStats.
  ///
  /// In en, this message translates to:
  /// **'Play history, stats, merged groups'**
  String get backupContentDescUserStats;

  /// No description provided for @backupContentDescUserData.
  ///
  /// In en, this message translates to:
  /// **'Favorites, playlists, preferences'**
  String get backupContentDescUserData;

  /// No description provided for @backupContentDescUserSettings.
  ///
  /// In en, this message translates to:
  /// **'Theme, sort order, app preferences'**
  String get backupContentDescUserSettings;

  /// No description provided for @backupContentDescCoverCache.
  ///
  /// In en, this message translates to:
  /// **'Cached album artwork'**
  String get backupContentDescCoverCache;

  /// No description provided for @backupContentDescLibraryCache.
  ///
  /// In en, this message translates to:
  /// **'Cached metadata'**
  String get backupContentDescLibraryCache;

  /// No description provided for @backupContentDescSearchIndex.
  ///
  /// In en, this message translates to:
  /// **'Search database'**
  String get backupContentDescSearchIndex;

  /// No description provided for @backupContentDescWaveformCache.
  ///
  /// In en, this message translates to:
  /// **'Waveform data'**
  String get backupContentDescWaveformCache;

  /// No description provided for @backupContentDescColorCache.
  ///
  /// In en, this message translates to:
  /// **'Color palettes'**
  String get backupContentDescColorCache;

  /// No description provided for @backupContentDescLyricsCache.
  ///
  /// In en, this message translates to:
  /// **'Cached lyrics'**
  String get backupContentDescLyricsCache;

  /// No description provided for @backupContentDescArtistArtCache.
  ///
  /// In en, this message translates to:
  /// **'Cached artist images'**
  String get backupContentDescArtistArtCache;

  /// No description provided for @backupContentDescAlbumArtCache.
  ///
  /// In en, this message translates to:
  /// **'Cached album images'**
  String get backupContentDescAlbumArtCache;

  /// No description provided for @backupRestoringDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Restoring data'**
  String get backupRestoringDataTitle;

  /// No description provided for @importSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Data to Restore'**
  String get importSelectTitle;

  /// No description provided for @importSectionDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get importSectionDatabase;

  /// No description provided for @importSectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get importSectionStorage;

  /// No description provided for @importSectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get importSectionSettings;

  /// No description provided for @importSectionCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get importSectionCache;

  /// No description provided for @importOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Options'**
  String get importOptionsTitle;

  /// No description provided for @importReplaceDatabases.
  ///
  /// In en, this message translates to:
  /// **'Replace Databases'**
  String get importReplaceDatabases;

  /// No description provided for @importReplaceDatabasesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear existing data before restoring'**
  String get importReplaceDatabasesSubtitle;

  /// No description provided for @importRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get importRestoreAction;

  /// No description provided for @importSelectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get importSelectAll;

  /// No description provided for @importSelectNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get importSelectNone;

  /// No description provided for @syncEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get syncEnterPassword;

  /// No description provided for @syncAuthUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String syncAuthUnexpectedError(String error);

  /// No description provided for @syncUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken'**
  String get syncUsernameTaken;

  /// No description provided for @syncModeLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get syncModeLogIn;

  /// No description provided for @syncModeRecover.
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get syncModeRecover;

  /// No description provided for @syncUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get syncUsername;

  /// No description provided for @syncEncryptionWarning.
  ///
  /// In en, this message translates to:
  /// **'Your data is end-to-end encrypted. If you lose both your password and recovery key, it cannot be recovered.'**
  String get syncEncryptionWarning;

  /// No description provided for @syncSecuringAccount.
  ///
  /// In en, this message translates to:
  /// **'Securing your account...'**
  String get syncSecuringAccount;

  /// No description provided for @syncCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get syncCreateAccount;

  /// No description provided for @syncLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get syncLogIn;

  /// No description provided for @syncRecoverAccount.
  ///
  /// In en, this message translates to:
  /// **'Recover account'**
  String get syncRecoverAccount;

  /// No description provided for @syncHideAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Hide advanced'**
  String get syncHideAdvanced;

  /// No description provided for @syncAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get syncAdvanced;

  /// No description provided for @syncRecoveryKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Recovery key saved'**
  String get syncRecoveryKeySaved;

  /// No description provided for @syncCouldNotSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Could not save file'**
  String get syncCouldNotSaveFile;

  /// No description provided for @syncRecoveryKeyRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Your recovery key'**
  String get syncRecoveryKeyRevealTitle;

  /// No description provided for @syncRecoveryKeyRevealBody.
  ///
  /// In en, this message translates to:
  /// **'This is the only way to regain access if you forget your password. It is shown once. Store it somewhere safe.'**
  String get syncRecoveryKeyRevealBody;

  /// No description provided for @syncCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get syncCopied;

  /// No description provided for @syncCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get syncCopy;

  /// No description provided for @syncSaveToFile.
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get syncSaveToFile;

  /// No description provided for @syncRecoveryKeySavedCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I saved my recovery key'**
  String get syncRecoveryKeySavedCheckbox;

  /// No description provided for @syncContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get syncContinue;

  /// No description provided for @syncUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your library data'**
  String get syncUploadTitle;

  /// No description provided for @syncSetupDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up this device'**
  String get syncSetupDeviceTitle;

  /// No description provided for @syncFreshAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Auto-sync turns on after your data is uploaded once.'**
  String get syncFreshAccountBody;

  /// No description provided for @syncChooseDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how this device joins your cloud data. Auto-sync turns on after this step.'**
  String get syncChooseDeviceBody;

  /// No description provided for @syncEverythingNow.
  ///
  /// In en, this message translates to:
  /// **'Sync everything now'**
  String get syncEverythingNow;

  /// No description provided for @syncMergeWithCloud.
  ///
  /// In en, this message translates to:
  /// **'Merge this device with cloud'**
  String get syncMergeWithCloud;

  /// No description provided for @syncSetupNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Set up as new device'**
  String get syncSetupNewDevice;

  /// No description provided for @syncMergeExplanation.
  ///
  /// In en, this message translates to:
  /// **'Merging keeps both sides. Setting up as a new device erases this device\'s synced data first and is safer if this device already holds an older copy of the same history.'**
  String get syncMergeExplanation;

  /// No description provided for @syncCloudReplacedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud data was replaced'**
  String get syncCloudReplacedTitle;

  /// No description provided for @syncCloudReplacedBody.
  ///
  /// In en, this message translates to:
  /// **'Another device overwrote the cloud. Sync is paused on this device until you choose.'**
  String get syncCloudReplacedBody;

  /// No description provided for @syncMergeIntoCloud.
  ///
  /// In en, this message translates to:
  /// **'Merge this device into the new cloud data'**
  String get syncMergeIntoCloud;

  /// No description provided for @syncPhaseSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get syncPhaseSigningIn;

  /// No description provided for @syncPhaseCheckingCloud.
  ///
  /// In en, this message translates to:
  /// **'Checking cloud...'**
  String get syncPhaseCheckingCloud;

  /// No description provided for @syncPhaseDownloadingBackup.
  ///
  /// In en, this message translates to:
  /// **'Downloading backup...'**
  String get syncPhaseDownloadingBackup;

  /// No description provided for @syncPhaseApplyingBackup.
  ///
  /// In en, this message translates to:
  /// **'Applying backup...'**
  String get syncPhaseApplyingBackup;

  /// No description provided for @syncPhaseDownloadingChanges.
  ///
  /// In en, this message translates to:
  /// **'Downloading changes...'**
  String get syncPhaseDownloadingChanges;

  /// No description provided for @syncPhaseMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging...'**
  String get syncPhaseMerging;

  /// No description provided for @syncPhasePreparingUpload.
  ///
  /// In en, this message translates to:
  /// **'Preparing upload...'**
  String get syncPhasePreparingUpload;

  /// No description provided for @syncPhaseEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting...'**
  String get syncPhaseEncrypting;

  /// No description provided for @syncPhaseUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get syncPhaseUploading;

  /// No description provided for @syncPhaseFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing up...'**
  String get syncPhaseFinishing;

  /// No description provided for @syncPhaseError.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncPhaseError;

  /// No description provided for @syncSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncSyncing;

  /// No description provided for @syncServerInfo.
  ///
  /// In en, this message translates to:
  /// **'{name} - API v{version}'**
  String syncServerInfo(String name, String version);

  /// No description provided for @syncServerInfoClosed.
  ///
  /// In en, this message translates to:
  /// **'{name} - API v{version} - registration closed'**
  String syncServerInfoClosed(String name, String version);

  /// No description provided for @syncServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server'**
  String get syncServerUnreachable;

  /// No description provided for @syncInsecureHttpWarning.
  ///
  /// In en, this message translates to:
  /// **'Plain http: only use on a trusted private network'**
  String get syncInsecureHttpWarning;

  /// No description provided for @syncServerUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get syncServerUrl;

  /// No description provided for @syncChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get syncChecking;

  /// No description provided for @syncCheckServer.
  ///
  /// In en, this message translates to:
  /// **'Check server'**
  String get syncCheckServer;

  /// No description provided for @syncResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get syncResetDefault;

  /// No description provided for @autoBackupRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'Backing Up'**
  String get autoBackupRunningTitle;

  /// No description provided for @autoBackupRunningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Creating backup...'**
  String get autoBackupRunningSubtitle;

  /// No description provided for @autoBackupCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Backup Complete'**
  String get autoBackupCompleteTitle;

  /// No description provided for @autoBackupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get autoBackupSaved;

  /// No description provided for @autoBackupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Backup Failed'**
  String get autoBackupFailedTitle;

  /// No description provided for @autoBackupUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get autoBackupUnknownError;

  /// No description provided for @autoBackupPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get autoBackupPermissionTitle;

  /// No description provided for @autoBackupPermissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup needs storage access'**
  String get autoBackupPermissionSubtitle;

  /// No description provided for @autoBackupGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get autoBackupGrant;

  /// No description provided for @downgradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Older version detected'**
  String get downgradeTitle;

  /// No description provided for @downgradeMessage.
  ///
  /// In en, this message translates to:
  /// **'wispie was last opened on {previousVersion}, but this is {currentVersion}. Your data may have been changed by a newer version and could break or be lost on this one.'**
  String downgradeMessage(String previousVersion, String currentVersion);

  /// No description provided for @downgradeQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get downgradeQuit;

  /// No description provided for @downgradeRiskIt.
  ///
  /// In en, this message translates to:
  /// **'Risk it'**
  String get downgradeRiskIt;

  /// No description provided for @downgradeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get downgradeUpdate;

  /// No description provided for @indexerSettingsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Indexer Settings'**
  String get indexerSettingsGroupTitle;

  /// No description provided for @indexerPreventDuplicatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prevent Duplicate Tracks'**
  String get indexerPreventDuplicatesTitle;

  /// No description provided for @indexerPreventDuplicatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide songs with the same filename across folders'**
  String get indexerPreventDuplicatesSubtitle;

  /// No description provided for @indexerExtractFeaturedTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract Featured Artists'**
  String get indexerExtractFeaturedTitle;

  /// No description provided for @indexerExtractFeaturedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Move \"ft./feat.\" artists from title to artist field'**
  String get indexerExtractFeaturedSubtitle;

  /// No description provided for @indexerDatabaseOpsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Database Operations'**
  String get indexerDatabaseOpsGroupTitle;

  /// No description provided for @indexerWarnRestart.
  ///
  /// In en, this message translates to:
  /// **'This operation requires an app restart to apply changes.'**
  String get indexerWarnRestart;

  /// No description provided for @indexerCoverSearchGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cover & Search'**
  String get indexerCoverSearchGroupTitle;

  /// No description provided for @indexerWarnRepairLinks.
  ///
  /// In en, this message translates to:
  /// **'Tracks whose files are no longer on this device will be removed from the library. Favourites, playlists and play counts are kept and reattach if the files come back.'**
  String get indexerWarnRepairLinks;

  /// No description provided for @indexerWarnSearchRestart.
  ///
  /// In en, this message translates to:
  /// **'You may need to restart the app for search index changes to fully apply.'**
  String get indexerWarnSearchRestart;

  /// No description provided for @indexerContentCachesGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Caches'**
  String get indexerContentCachesGroupTitle;

  /// No description provided for @indexerRecommendationsGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get indexerRecommendationsGroupTitle;

  /// No description provided for @indexerTitle.
  ///
  /// In en, this message translates to:
  /// **'Indexer'**
  String get indexerTitle;

  /// No description provided for @indexerArtistsAlbumsProgress.
  ///
  /// In en, this message translates to:
  /// **'Artists {artists} · Albums {albums}...'**
  String indexerArtistsAlbumsProgress(String artists, String albums);

  /// No description provided for @indexerProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing {progress}...'**
  String indexerProcessing(String progress);

  /// No description provided for @indexerError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String indexerError(String error);

  /// No description provided for @indexerUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get indexerUnknownError;

  /// No description provided for @indexerCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get indexerCompleted;

  /// No description provided for @indexerCached.
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} cached'**
  String indexerCached(int processed, int total);

  /// No description provided for @indexerCachedFailed.
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} cached ({failed} failed)'**
  String indexerCachedFailed(int processed, int total, int failed);

  /// No description provided for @indexerReadyToRebuild.
  ///
  /// In en, this message translates to:
  /// **'Ready to rebuild'**
  String get indexerReadyToRebuild;

  /// No description provided for @indexerArtistsOnly.
  ///
  /// In en, this message translates to:
  /// **'Artists {progress}'**
  String indexerArtistsOnly(String progress);

  /// No description provided for @indexerAlbumsOnly.
  ///
  /// In en, this message translates to:
  /// **'Albums {progress}'**
  String indexerAlbumsOnly(String progress);

  /// No description provided for @indexerFailedItemsQuestion.
  ///
  /// In en, this message translates to:
  /// **'This cache has {failed} failed items. What would you like to do?'**
  String indexerFailedItemsQuestion(int failed);

  /// No description provided for @indexerViewFailed.
  ///
  /// In en, this message translates to:
  /// **'View {failed} Failed'**
  String indexerViewFailed(int failed);

  /// No description provided for @indexerRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry Failed'**
  String get indexerRetryFailed;

  /// No description provided for @indexerForceRebuild.
  ///
  /// In en, this message translates to:
  /// **'Force Rebuild'**
  String get indexerForceRebuild;

  /// No description provided for @indexerAlreadyCompleteQuestion.
  ///
  /// In en, this message translates to:
  /// **'This cache is already complete ({processed}/{total}). Do you want to force rebuild it?'**
  String indexerAlreadyCompleteQuestion(int processed, int total);

  /// No description provided for @indexerDoIt.
  ///
  /// In en, this message translates to:
  /// **'Do It'**
  String get indexerDoIt;

  /// No description provided for @indexerOptimizing.
  ///
  /// In en, this message translates to:
  /// **'Optimizing {name}...'**
  String indexerOptimizing(String name);

  /// No description provided for @indexerDoNotClose.
  ///
  /// In en, this message translates to:
  /// **'Please do not close the app'**
  String get indexerDoNotClose;

  /// No description provided for @indexerRestartRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get indexerRestartRequiredTitle;

  /// No description provided for @indexerRestartRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'The operation has been completed successfully.\n\nThe app needs to restart to apply all changes properly.'**
  String get indexerRestartRequiredMessage;

  /// No description provided for @indexerRestartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get indexerRestartNow;

  /// No description provided for @indexerFailedItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Failed Item} other{{count} Failed Items}}'**
  String indexerFailedItemsTitle(int count);

  /// No description provided for @indexerCouldNotProcess.
  ///
  /// In en, this message translates to:
  /// **'The following items could not be processed:'**
  String get indexerCouldNotProcess;

  /// No description provided for @indexerWarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} Warnings'**
  String indexerWarningsTitle(String name);

  /// No description provided for @indexerMoreItems.
  ///
  /// In en, this message translates to:
  /// **'... and {count} more'**
  String indexerMoreItems(int count);

  /// No description provided for @indexerOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get indexerOk;

  /// No description provided for @indexerJustMissing.
  ///
  /// In en, this message translates to:
  /// **'Just Missing'**
  String get indexerJustMissing;

  /// No description provided for @indexerForceAll.
  ///
  /// In en, this message translates to:
  /// **'Force All'**
  String get indexerForceAll;

  /// No description provided for @beatSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Beat sync'**
  String get beatSyncTitle;

  /// No description provided for @beatPlayToCalibrate.
  ///
  /// In en, this message translates to:
  /// **'Play a song to calibrate.'**
  String get beatPlayToCalibrate;

  /// No description provided for @beatAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing beats...'**
  String get beatAnalyzing;

  /// No description provided for @beatNoClearBeat.
  ///
  /// In en, this message translates to:
  /// **'No clear beat in this track.'**
  String get beatNoClearBeat;

  /// No description provided for @beatDragInstruction.
  ///
  /// In en, this message translates to:
  /// **'Drag until the particle bursts land on the clicks.'**
  String get beatDragInstruction;

  /// No description provided for @beatOffsetMs.
  ///
  /// In en, this message translates to:
  /// **'{value} ms'**
  String beatOffsetMs(int value);

  /// No description provided for @beatResetToZero.
  ///
  /// In en, this message translates to:
  /// **'Reset to 0 ms'**
  String get beatResetToZero;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @libraryFoldersTab.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryFoldersTab;

  /// No description provided for @libraryArtistsTab.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryArtistsTab;

  /// No description provided for @libraryAlbumsTab.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryAlbumsTab;

  /// No description provided for @libraryNoMusicFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'No music folder yet'**
  String get libraryNoMusicFolderTitle;

  /// No description provided for @libraryNoMusicFolderMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a music folder in Home to fill this out.'**
  String get libraryNoMusicFolderMessage;

  /// No description provided for @libraryFolderErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not find your music folder'**
  String get libraryFolderErrorTitle;

  /// No description provided for @libraryLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load library'**
  String get libraryLoadErrorTitle;

  /// No description provided for @libraryOpenFolderErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not open folder'**
  String get libraryOpenFolderErrorTitle;

  /// No description provided for @libraryNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get libraryNoMatchesTitle;

  /// No description provided for @libraryNoMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your library matches \"{query}\".'**
  String libraryNoMatchesMessage(String query);

  /// No description provided for @libraryFolderNoMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this folder matches \"{query}\".'**
  String libraryFolderNoMatchesMessage(String query);

  /// No description provided for @libraryCollectionNoMatchesMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing here matches \"{query}\".'**
  String libraryCollectionNoMatchesMessage(String query);

  /// No description provided for @libraryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libraryFavorites;

  /// No description provided for @libraryMergedSongs.
  ///
  /// In en, this message translates to:
  /// **'Merged Songs'**
  String get libraryMergedSongs;

  /// No description provided for @libraryMergedGroupsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 group} other{{count} groups}}'**
  String libraryMergedGroupsCount(int count);

  /// No description provided for @libraryCreateMergeGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create new merge group'**
  String get libraryCreateMergeGroupTooltip;

  /// No description provided for @librarySelectSongsToMerge.
  ///
  /// In en, this message translates to:
  /// **'Select Songs to Merge'**
  String get librarySelectSongsToMerge;

  /// No description provided for @libraryMergedCount.
  ///
  /// In en, this message translates to:
  /// **'Merged {count} songs'**
  String libraryMergedCount(int count);

  /// No description provided for @libraryDeletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get libraryDeletePlaylist;

  /// No description provided for @libraryPlaylistOptions.
  ///
  /// In en, this message translates to:
  /// **'Playlist options'**
  String get libraryPlaylistOptions;

  /// No description provided for @libraryFolderOptions.
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get libraryFolderOptions;

  /// No description provided for @libraryFilterAllHint.
  ///
  /// In en, this message translates to:
  /// **'Filter folders, playlists, songs...'**
  String get libraryFilterAllHint;

  /// No description provided for @libraryFilterSongsHint.
  ///
  /// In en, this message translates to:
  /// **'Filter folders, songs...'**
  String get libraryFilterSongsHint;

  /// No description provided for @libraryFilterCollectionsHint.
  ///
  /// In en, this message translates to:
  /// **'Filter artists, albums...'**
  String get libraryFilterCollectionsHint;

  /// No description provided for @libraryTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String libraryTrackCount(int count);

  /// No description provided for @libraryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryAll;

  /// No description provided for @libraryShuffleFolderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Shuffle folder'**
  String get libraryShuffleFolderTooltip;

  /// No description provided for @libraryNoArtistsTitle.
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get libraryNoArtistsTitle;

  /// No description provided for @libraryNoAlbumsTitle.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get libraryNoAlbumsTitle;

  /// No description provided for @libraryScanToFillMessage.
  ///
  /// In en, this message translates to:
  /// **'Scan a music folder to fill this out.'**
  String get libraryScanToFillMessage;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionShuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle all'**
  String get actionShuffleAll;

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get actionSeeAll;

  /// No description provided for @homeFolderAccessError.
  ///
  /// In en, this message translates to:
  /// **'Unable to access selected folder'**
  String get homeFolderAccessError;

  /// No description provided for @homeQueueCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count, plural, =1{1 track} other{{count} tracks}}'**
  String homeQueueCardSubtitle(String date, int count);

  /// No description provided for @homeTrackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String homeTrackCount(int count);

  /// No description provided for @homePlayingCount.
  ///
  /// In en, this message translates to:
  /// **'Playing {count, plural, =1{1 track} other{{count} tracks}}'**
  String homePlayingCount(int count);

  /// No description provided for @homeOpenPlayer.
  ///
  /// In en, this message translates to:
  /// **'Open Player'**
  String get homeOpenPlayer;

  /// No description provided for @homePlayNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get homePlayNow;

  /// No description provided for @homePlayAfterCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track will play after the current song} other{{count} tracks will play after the current song}}'**
  String homePlayAfterCount(int count);

  /// No description provided for @homePlayAfterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Play After Current Song'**
  String get homePlayAfterCurrent;

  /// No description provided for @homeSaveToNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Save to new playlist'**
  String get homeSaveToNewPlaylist;

  /// No description provided for @homeUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get homeUnpin;

  /// No description provided for @homePinRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Pin recommendation'**
  String get homePinRecommendation;

  /// No description provided for @homeRenameRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Rename recommendation'**
  String get homeRenameRecommendation;

  /// No description provided for @homeRenameRecommendationTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Recommendation'**
  String get homeRenameRecommendationTitle;

  /// No description provided for @homeRemoveRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Remove recommendation'**
  String get homeRemoveRecommendation;

  /// No description provided for @homeRemoveRecommendationTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove recommendation?'**
  String get homeRemoveRecommendationTitle;

  /// No description provided for @homeRemoveRecommendationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{title}\"?'**
  String homeRemoveRecommendationMessage(String title);

  /// No description provided for @homeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get homeRemove;

  /// No description provided for @homeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get homeErrorTitle;

  /// No description provided for @homeTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get homeTryAgain;

  /// No description provided for @homeNoSongsTitle.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get homeNoSongsTitle;

  /// No description provided for @homeNoSongsMessage.
  ///
  /// In en, this message translates to:
  /// **'Select your music folder to start listening offline.'**
  String get homeNoSongsMessage;

  /// No description provided for @homeSelectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Music Folder'**
  String get homeSelectFolder;

  /// No description provided for @homeQuickPicks.
  ///
  /// In en, this message translates to:
  /// **'Quick Picks'**
  String get homeQuickPicks;

  /// No description provided for @homeRecentQueues.
  ///
  /// In en, this message translates to:
  /// **'Recent Queues'**
  String get homeRecentQueues;

  /// No description provided for @homeForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get homeForYou;

  /// No description provided for @mergedLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String mergedLoadError(String error);

  /// No description provided for @mergedTitle.
  ///
  /// In en, this message translates to:
  /// **'Merged Songs'**
  String get mergedTitle;

  /// No description provided for @mergedCreateGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create merge group'**
  String get mergedCreateGroupTooltip;

  /// No description provided for @mergedGroupsTab.
  ///
  /// In en, this message translates to:
  /// **'Groups ({count})'**
  String mergedGroupsTab(int count);

  /// No description provided for @mergedAutoFindTab.
  ///
  /// In en, this message translates to:
  /// **'Auto-Find ({count})'**
  String mergedAutoFindTab(int count);

  /// No description provided for @mergedSelectSongsTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Songs to Merge'**
  String get mergedSelectSongsTitle;

  /// No description provided for @mergedCreatedSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Merged 1 song} other{Merged {count} songs}}'**
  String mergedCreatedSnack(int count);

  /// No description provided for @mergedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No merged songs yet'**
  String get mergedEmptyTitle;

  /// No description provided for @mergedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Group different versions of the same song (remixes, live versions, acoustics) so they share one spot during shuffle.'**
  String get mergedEmptyBody;

  /// No description provided for @mergedCreateGroupButton.
  ///
  /// In en, this message translates to:
  /// **'Create Merge Group'**
  String get mergedCreateGroupButton;

  /// No description provided for @mergedPrioritySet.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" set as priority song'**
  String mergedPrioritySet(String title);

  /// No description provided for @mergedPriorityCleared.
  ///
  /// In en, this message translates to:
  /// **'Priority cleared'**
  String get mergedPriorityCleared;

  /// No description provided for @mergedNoCandidatesTitle.
  ///
  /// In en, this message translates to:
  /// **'No candidate songs found'**
  String get mergedNoCandidatesTitle;

  /// No description provided for @mergedNoCandidatesBody.
  ///
  /// In en, this message translates to:
  /// **'No unmerged song variants (remixes, live versions, acoustics) were detected in your library.'**
  String get mergedNoCandidatesBody;

  /// No description provided for @mergedFoundGroups.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found 1 potential group to merge} other{Found {count} potential groups to merge}}'**
  String mergedFoundGroups(int count);

  /// No description provided for @mergedMergeAll.
  ///
  /// In en, this message translates to:
  /// **'Merge All'**
  String get mergedMergeAll;

  /// No description provided for @mergedMergeAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge All Suggestions'**
  String get mergedMergeAllTitle;

  /// No description provided for @mergedMergeAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Create 1 merge group for detected song variants?} other{Create {count} merge groups for detected song variants?}}'**
  String mergedMergeAllConfirm(int count);

  /// No description provided for @mergedCreatedGroupsSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Created 1 merge group} other{Created {count} merge groups}}'**
  String mergedCreatedGroupsSnack(int count);

  /// No description provided for @mergedUnmergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmerge Song'**
  String get mergedUnmergeTitle;

  /// No description provided for @mergedUnmergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from this merge group?'**
  String mergedUnmergeConfirm(String title);

  /// No description provided for @mergedUnmergeAction.
  ///
  /// In en, this message translates to:
  /// **'Unmerge'**
  String get mergedUnmergeAction;

  /// No description provided for @mergedUnmergedSnack.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" unmerged'**
  String mergedUnmergedSnack(String title);

  /// No description provided for @mergedDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Merge Group'**
  String get mergedDeleteGroupTitle;

  /// No description provided for @mergedDeleteGroupConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unmerge all songs in this group?'**
  String get mergedDeleteGroupConfirm;

  /// No description provided for @mergedUnmergeAllAction.
  ///
  /// In en, this message translates to:
  /// **'Unmerge All'**
  String get mergedUnmergeAllAction;

  /// No description provided for @mergedGroupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Merge group deleted'**
  String get mergedGroupDeleted;

  /// No description provided for @mergedGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Merge Group'**
  String get mergedGroupLabel;

  /// No description provided for @mergedVersionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 version} other{{count} versions}}'**
  String mergedVersionsCount(int count);

  /// No description provided for @mergedUnmergeAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmerge all'**
  String get mergedUnmergeAllTooltip;

  /// No description provided for @mergedPriorityBadge.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get mergedPriorityBadge;

  /// No description provided for @mergedPrioritySongTooltip.
  ///
  /// In en, this message translates to:
  /// **'Priority song for shuffle'**
  String get mergedPrioritySongTooltip;

  /// No description provided for @mergedSetPriorityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set as priority song'**
  String get mergedSetPriorityTooltip;

  /// No description provided for @mergedUnmergeSongTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmerge song'**
  String get mergedUnmergeSongTooltip;

  /// No description provided for @mergedSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} selected'**
  String mergedSelectedCount(int selected, int total);

  /// No description provided for @mergedMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergedMergeAction;

  /// No description provided for @sleepTimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimerTitle;

  /// No description provided for @sleepTimerModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Timer Mode'**
  String get sleepTimerModeLabel;

  /// No description provided for @sleepTimerDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sleepTimerDurationLabel;

  /// No description provided for @sleepTimerMinutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sleepTimerMinutesValue(int minutes);

  /// No description provided for @sleepTimerMinSuffix.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get sleepTimerMinSuffix;

  /// No description provided for @sleepTimerTracksLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of Tracks'**
  String get sleepTimerTracksLabel;

  /// No description provided for @sleepTimerTracksValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String sleepTimerTracksValue(int count);

  /// No description provided for @sleepTimerLoopTitle.
  ///
  /// In en, this message translates to:
  /// **'Loop Current Song'**
  String get sleepTimerLoopTitle;

  /// No description provided for @sleepTimerLoopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Repeat the current song for a set time'**
  String get sleepTimerLoopSubtitle;

  /// No description provided for @sleepTimerPlayForTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Play for Time'**
  String get sleepTimerPlayForTimeTitle;

  /// No description provided for @sleepTimerPlayForTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop after a specified duration'**
  String get sleepTimerPlayForTimeSubtitle;

  /// No description provided for @sleepTimerStopAfterCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop After Current'**
  String get sleepTimerStopAfterCurrentTitle;

  /// No description provided for @sleepTimerStopAfterCurrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop when the current song ends'**
  String get sleepTimerStopAfterCurrentSubtitle;

  /// No description provided for @sleepTimerStopAfterTracksTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop After Tracks'**
  String get sleepTimerStopAfterTracksTitle;

  /// No description provided for @sleepTimerStopAfterTracksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop after playing X more songs'**
  String get sleepTimerStopAfterTracksSubtitle;

  /// No description provided for @sleepTimerNoSong.
  ///
  /// In en, this message translates to:
  /// **'No song is currently playing'**
  String get sleepTimerNoSong;

  /// No description provided for @sleepTimerCurrentSongLabel.
  ///
  /// In en, this message translates to:
  /// **'Current song'**
  String get sleepTimerCurrentSongLabel;

  /// No description provided for @sleepTimerLetFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Let current song finish'**
  String get sleepTimerLetFinishTitle;

  /// No description provided for @sleepTimerLetFinishSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current song to end before stopping'**
  String get sleepTimerLetFinishSubtitle;

  /// No description provided for @sleepTimerStopImmediatelySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stop immediately when timer expires'**
  String get sleepTimerStopImmediatelySubtitle;

  /// No description provided for @sleepTimerStart.
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get sleepTimerStart;

  /// No description provided for @sleepTimerCancelActive.
  ///
  /// In en, this message translates to:
  /// **'Cancel Active Timer'**
  String get sleepTimerCancelActive;

  /// No description provided for @sleepTimerCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer cancelled'**
  String get sleepTimerCancelled;

  /// No description provided for @sleepTimerFinished.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer finished'**
  String get sleepTimerFinished;

  /// No description provided for @sleepTimerLoopingFor.
  ///
  /// In en, this message translates to:
  /// **'Looping current song for {minutes} minutes'**
  String sleepTimerLoopingFor(int minutes);

  /// No description provided for @sleepTimerStopIn.
  ///
  /// In en, this message translates to:
  /// **'Music will stop in {minutes} minutes'**
  String sleepTimerStopIn(int minutes);

  /// No description provided for @sleepTimerStopAfterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Will stop after current song ends'**
  String get sleepTimerStopAfterCurrent;

  /// No description provided for @sleepTimerStopAfterTracks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Will stop after 1 more song} other{Will stop after {count} more songs}}'**
  String sleepTimerStopAfterTracks(int count);

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// No description provided for @settingsValueNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsValueNone;

  /// No description provided for @settingsDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String settingsDurationSeconds(int seconds);

  /// No description provided for @settingsDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String settingsDurationMinutes(int minutes);

  /// No description provided for @settingsDurationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String settingsDurationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @settingsGroupListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get settingsGroupListening;

  /// No description provided for @settingsGroupLookAndFeel.
  ///
  /// In en, this message translates to:
  /// **'Look & Feel'**
  String get settingsGroupLookAndFeel;

  /// No description provided for @settingsGroupData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsGroupData;

  /// No description provided for @settingsGroupApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsGroupApp;

  /// No description provided for @settingsGroupLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsGroupLibrary;

  /// No description provided for @settingsGroupFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get settingsGroupFilters;

  /// No description provided for @settingsGroupMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsGroupMaintenance;

  /// No description provided for @settingsScanningLibrary.
  ///
  /// In en, this message translates to:
  /// **'Scanning library…'**
  String get settingsScanningLibrary;

  /// No description provided for @settingsResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String settingsResultsFor(String query);

  /// No description provided for @settingsNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No settings found'**
  String get settingsNoResultsTitle;

  /// No description provided for @settingsNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
  String settingsNoResultsMessage(String query);

  /// No description provided for @homeSettingsGroupLists.
  ///
  /// In en, this message translates to:
  /// **'Lists & Navigation'**
  String get homeSettingsGroupLists;

  /// No description provided for @homeSettingsAutoHideBarsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Header and bottom dock hide on downward scroll, restore on upward scroll'**
  String get homeSettingsAutoHideBarsSubtitle;

  /// No description provided for @homeSettingsGroupHome.
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get homeSettingsGroupHome;

  /// No description provided for @playbackGroupTransitions.
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get playbackGroupTransitions;

  /// No description provided for @playbackGroupPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get playbackGroupPlayPause;

  /// No description provided for @playbackGroupAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playbackGroupAudio;

  /// No description provided for @playbackGapOff.
  ///
  /// In en, this message translates to:
  /// **'Gap / Delay (off)'**
  String get playbackGapOff;

  /// No description provided for @playbackFadeOutOff.
  ///
  /// In en, this message translates to:
  /// **'Fade Out (off)'**
  String get playbackFadeOutOff;

  /// No description provided for @playbackFadeInOff.
  ///
  /// In en, this message translates to:
  /// **'Fade In (off)'**
  String get playbackFadeInOff;

  /// No description provided for @playbackSecondsValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String playbackSecondsValue(String seconds);

  /// No description provided for @playbackValueOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playbackValueOff;

  /// No description provided for @playbackValueOneSecond.
  ///
  /// In en, this message translates to:
  /// **'1.0 s'**
  String get playbackValueOneSecond;

  /// No description provided for @playbackValueMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'{milliseconds} ms'**
  String playbackValueMilliseconds(int milliseconds);

  /// No description provided for @bulkRenameTokenCurrentName.
  ///
  /// In en, this message translates to:
  /// **'Current name'**
  String get bulkRenameTokenCurrentName;

  /// No description provided for @bulkRenameTokenNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get bulkRenameTokenNumber;

  /// No description provided for @bulkRenameTokenYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get bulkRenameTokenYear;

  /// No description provided for @bulkRenameAnalyzeError.
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the library: {error}'**
  String bulkRenameAnalyzeError(String error);

  /// No description provided for @bulkRenameRenameCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rename 1 song} other{Rename {count} songs}}'**
  String bulkRenameRenameCount(int count);

  /// Confirmation body for a bulk rename
  ///
  /// In en, this message translates to:
  /// **'Files are renamed in place. Play stats, playlists and cached artwork move across with them, and the database is kept in step as each file lands.'**
  String get bulkRenameConfirmMessage;

  /// No description provided for @bulkRenameNothingLeft.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to rename'**
  String get bulkRenameNothingLeft;

  /// No description provided for @bulkRenamePhaseStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get bulkRenamePhaseStarting;

  /// No description provided for @bulkRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk Rename'**
  String get bulkRenameTitle;

  /// No description provided for @bulkRenameFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get bulkRenameFormatTitle;

  /// No description provided for @bulkRenameFormatArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist - Title'**
  String get bulkRenameFormatArtistTitle;

  /// No description provided for @bulkRenameFormatArtistAlbumTitle.
  ///
  /// In en, this message translates to:
  /// **'Artist - Album - Title'**
  String get bulkRenameFormatArtistAlbumTitle;

  /// No description provided for @bulkRenameFormatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get bulkRenameFormatCustom;

  /// No description provided for @bulkRenameCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own arrangement'**
  String get bulkRenameCustomSubtitle;

  /// No description provided for @bulkRenameSectionFormat.
  ///
  /// In en, this message translates to:
  /// **'FORMAT'**
  String get bulkRenameSectionFormat;

  /// No description provided for @bulkRenameSectionArrange.
  ///
  /// In en, this message translates to:
  /// **'ARRANGE'**
  String get bulkRenameSectionArrange;

  /// No description provided for @bulkRenameSectionPreview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get bulkRenameSectionPreview;

  /// No description provided for @bulkRenameEmptySegments.
  ///
  /// In en, this message translates to:
  /// **'Add a field below to start building a name.'**
  String get bulkRenameEmptySegments;

  /// No description provided for @bulkRenameRemoveToken.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get bulkRenameRemoveToken;

  /// No description provided for @bulkRenameLiteralHint.
  ///
  /// In en, this message translates to:
  /// **'Text, e.g. \" - \"'**
  String get bulkRenameLiteralHint;

  /// No description provided for @bulkRenameTextChip.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get bulkRenameTextChip;

  /// No description provided for @bulkRenameAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing library'**
  String get bulkRenameAnalyzing;

  /// No description provided for @bulkRenameCountToRename.
  ///
  /// In en, this message translates to:
  /// **'{count} to rename'**
  String bulkRenameCountToRename(int count);

  /// No description provided for @bulkRenameSkippedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String bulkRenameSkippedCount(int count);

  /// No description provided for @bulkRenameAndMore.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String bulkRenameAndMore(int count);

  /// No description provided for @bulkRenameChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking names — {done} of {total}'**
  String bulkRenameChecking(int done, int total);

  /// No description provided for @bulkRenameStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get bulkRenameStop;

  /// No description provided for @bulkRenameStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get bulkRenameStopping;

  /// No description provided for @bulkRenamePleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get bulkRenamePleaseWait;

  /// No description provided for @bulkRenameProgressCount.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String bulkRenameProgressCount(int done, int total);

  /// No description provided for @bulkRenameStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {count} songs. Their stats and cached artwork moved across; the rest were left alone.'**
  String bulkRenameStopped(int count);

  /// No description provided for @bulkRenameStoppedFailed.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {count} songs, {failed} could not be renamed.'**
  String bulkRenameStoppedFailed(int count, int failed);

  /// No description provided for @bulkRenameCompleted.
  ///
  /// In en, this message translates to:
  /// **'Renamed {count} songs. Stats and cached artwork moved across.'**
  String bulkRenameCompleted(int count);

  /// No description provided for @bulkRenameCompletedFailed.
  ///
  /// In en, this message translates to:
  /// **'Renamed {count} songs, {failed} could not be renamed.'**
  String bulkRenameCompletedFailed(int count, int failed);

  /// No description provided for @bulkRenameFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename finished'**
  String get bulkRenameFinishedTitle;

  /// No description provided for @bulkRenameSkipNoTitleText.
  ///
  /// In en, this message translates to:
  /// **'No title text left after cleanup'**
  String get bulkRenameSkipNoTitleText;

  /// No description provided for @bulkRenameSkipAlreadyNamed.
  ///
  /// In en, this message translates to:
  /// **'Already named this'**
  String get bulkRenameSkipAlreadyNamed;

  /// No description provided for @bulkRenameSkipSameNameAs.
  ///
  /// In en, this message translates to:
  /// **'Same name as \"{filename}\" in this folder'**
  String bulkRenameSkipSameNameAs(String filename);

  /// No description provided for @bulkRenameSkipAnotherSelected.
  ///
  /// In en, this message translates to:
  /// **'Another selected song has that name'**
  String get bulkRenameSkipAnotherSelected;

  /// No description provided for @bulkRenameSkipFileExists.
  ///
  /// In en, this message translates to:
  /// **'A file with that name is already here'**
  String get bulkRenameSkipFileExists;

  /// No description provided for @shuffleResetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get shuffleResetDone;

  /// No description provided for @shuffleSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get shuffleSaved;

  /// No description provided for @shuffleUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get shuffleUnsavedTitle;

  /// No description provided for @shuffleUnsavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save your changes?'**
  String get shuffleUnsavedMessage;

  /// No description provided for @shuffleDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get shuffleDiscard;

  /// No description provided for @shuffleSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shuffleSave;

  /// No description provided for @shuffleTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Shuffle Settings'**
  String get shuffleTitle;

  /// No description provided for @shuffleReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get shuffleReset;

  /// No description provided for @shuffleNextQueueNote.
  ///
  /// In en, this message translates to:
  /// **'Changes will apply to next queue'**
  String get shuffleNextQueueNote;

  /// No description provided for @shuffleBasicSettings.
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get shuffleBasicSettings;

  /// No description provided for @shuffleAvoidSongsTitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid Repeating Songs'**
  String get shuffleAvoidSongsTitle;

  /// No description provided for @shuffleAvoidSongsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce chance of playing recently played songs'**
  String get shuffleAvoidSongsSubtitle;

  /// No description provided for @shuffleAvoidArtistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid Repeating Artists'**
  String get shuffleAvoidArtistsTitle;

  /// No description provided for @shuffleAvoidArtistsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce chance of playing same artist consecutively'**
  String get shuffleAvoidArtistsSubtitle;

  /// No description provided for @shuffleAvoidAlbumsTitle.
  ///
  /// In en, this message translates to:
  /// **'Avoid Repeating Albums'**
  String get shuffleAvoidAlbumsTitle;

  /// No description provided for @shuffleAvoidAlbumsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce chance of playing same album consecutively'**
  String get shuffleAvoidAlbumsSubtitle;

  /// No description provided for @shuffleAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get shuffleAdvancedTitle;

  /// No description provided for @shuffleAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune individual weight values'**
  String get shuffleAdvancedSubtitle;

  /// No description provided for @shuffleWeightValuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Weight Values (-99 to +99)'**
  String get shuffleWeightValuesTitle;

  /// No description provided for @shuffleWeightValuesHint.
  ///
  /// In en, this message translates to:
  /// **'0 = neutral, negative = penalty, positive = boost'**
  String get shuffleWeightValuesHint;

  /// No description provided for @shuffleWeightLeastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Least Played Songs'**
  String get shuffleWeightLeastPlayed;

  /// No description provided for @shuffleWeightMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played Songs'**
  String get shuffleWeightMostPlayed;

  /// No description provided for @shuffleWeightFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get shuffleWeightFavorites;

  /// No description provided for @shuffleWeightSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Suggest Less Songs'**
  String get shuffleWeightSuggestLess;

  /// No description provided for @shuffleWeightPlaylistSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs in Playlists'**
  String get shuffleWeightPlaylistSongs;

  /// No description provided for @lyricsGroupDisplayTiming.
  ///
  /// In en, this message translates to:
  /// **'Display & Timing'**
  String get lyricsGroupDisplayTiming;

  /// No description provided for @lyricsSimulateWordSyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Simulate Word Sync'**
  String get lyricsSimulateWordSyncTitle;

  /// No description provided for @lyricsSimulateWordSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate word-level timing from line-synced lyrics using prosodic estimation'**
  String get lyricsSimulateWordSyncSubtitle;

  /// No description provided for @lyricsDesktopSidebarTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics & Queue Sidebar'**
  String get lyricsDesktopSidebarTitle;

  /// No description provided for @lyricsDesktopSidebarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden'**
  String get lyricsDesktopSidebarSubtitle;

  /// No description provided for @lyricsKeepScreenAwakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Screen Awake on Lyrics'**
  String get lyricsKeepScreenAwakeTitle;

  /// No description provided for @lyricsKeepScreenAwakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Prevent sleep while the lyrics pane is open'**
  String get lyricsKeepScreenAwakeSubtitle;

  /// No description provided for @lyricsGroupTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get lyricsGroupTranslation;

  /// No description provided for @lyricsAutoTranslateTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-Translate Lyrics'**
  String get lyricsAutoTranslateTitle;

  /// No description provided for @lyricsAutoTranslateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate lyrics using selected target language'**
  String get lyricsAutoTranslateSubtitle;

  /// No description provided for @lyricsTargetLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get lyricsTargetLanguageTitle;

  /// No description provided for @lyricsTranslationDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Translation Display'**
  String get lyricsTranslationDisplayTitle;

  /// No description provided for @lyricsTranslationModeReplaceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace base lyrics'**
  String get lyricsTranslationModeReplaceSubtitle;

  /// No description provided for @lyricsTranslationModeSubtextSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show subtext below lyrics'**
  String get lyricsTranslationModeSubtextSubtitle;

  /// Translation display mode: translation shown under each line
  ///
  /// In en, this message translates to:
  /// **'Subtext below'**
  String get lyricsModeSubtext;

  /// Translation display mode: translation replaces the original line
  ///
  /// In en, this message translates to:
  /// **'Replace base'**
  String get lyricsModeReplace;

  /// No description provided for @lyricsTranslateTitle.
  ///
  /// In en, this message translates to:
  /// **'Translate lyrics'**
  String get lyricsTranslateTitle;

  /// No description provided for @lyricsDisplayMode.
  ///
  /// In en, this message translates to:
  /// **'Display mode'**
  String get lyricsDisplayMode;

  /// No description provided for @lyricsModeSubtextDescription.
  ///
  /// In en, this message translates to:
  /// **'Show translation under lyrics'**
  String get lyricsModeSubtextDescription;

  /// No description provided for @lyricsModeReplaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Replace original lyrics entirely'**
  String get lyricsModeReplaceDescription;

  /// No description provided for @lyricsAutoTranslateAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-translate all songs'**
  String get lyricsAutoTranslateAllTitle;

  /// No description provided for @lyricsAutoTranslateAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically translate lyrics using selected language'**
  String get lyricsAutoTranslateAllSubtitle;

  /// No description provided for @lyricsTargetLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get lyricsTargetLanguageLabel;

  /// No description provided for @lyricsSearchLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Search language...'**
  String get lyricsSearchLanguageHint;

  /// No description provided for @lyricsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get lyricsClearCache;

  /// No description provided for @lyricsTranslateNow.
  ///
  /// In en, this message translates to:
  /// **'Translate now'**
  String get lyricsTranslateNow;

  /// No description provided for @lyricsFindTitle.
  ///
  /// In en, this message translates to:
  /// **'Find lyrics'**
  String get lyricsFindTitle;

  /// No description provided for @lyricsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found. Try a different title or artist, or check your connection.'**
  String get lyricsNoResults;

  /// No description provided for @lyricsInstrumentalWarning.
  ///
  /// In en, this message translates to:
  /// **'Marked as instrumental. Applying this clears any lyrics stored on the file.'**
  String get lyricsInstrumentalWarning;

  /// No description provided for @lyricsApplyUpper.
  ///
  /// In en, this message translates to:
  /// **'APPLY'**
  String get lyricsApplyUpper;

  /// No description provided for @lyricsPlainText.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get lyricsPlainText;

  /// No description provided for @lyricsUnknownLength.
  ///
  /// In en, this message translates to:
  /// **'Unknown length'**
  String get lyricsUnknownLength;

  /// No description provided for @lyricsDurationExactMatch.
  ///
  /// In en, this message translates to:
  /// **'{duration} · exact match'**
  String lyricsDurationExactMatch(String duration);

  /// No description provided for @lyricsBadgeWordSync.
  ///
  /// In en, this message translates to:
  /// **'WORD SYNC'**
  String get lyricsBadgeWordSync;

  /// No description provided for @lyricsBadgeLineSync.
  ///
  /// In en, this message translates to:
  /// **'LINE SYNC'**
  String get lyricsBadgeLineSync;

  /// No description provided for @lyricsBadgeInstrumental.
  ///
  /// In en, this message translates to:
  /// **'INSTRUMENTAL'**
  String get lyricsBadgeInstrumental;

  /// No description provided for @lyricsBadgePlain.
  ///
  /// In en, this message translates to:
  /// **'PLAIN'**
  String get lyricsBadgePlain;

  /// No description provided for @lyricsSaved.
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved'**
  String get lyricsSaved;

  /// No description provided for @lyricsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save lyrics: {error}'**
  String lyricsSaveError(Object error);

  /// No description provided for @lyricsTranslationCleared.
  ///
  /// In en, this message translates to:
  /// **'Cached translation cleared'**
  String get lyricsTranslationCleared;

  /// No description provided for @lyricsAlreadyTranslated.
  ///
  /// In en, this message translates to:
  /// **'Lyrics are already in target language'**
  String get lyricsAlreadyTranslated;

  /// No description provided for @lyricsTranslated.
  ///
  /// In en, this message translates to:
  /// **'Lyrics translated'**
  String get lyricsTranslated;

  /// No description provided for @lyricsTranslateError.
  ///
  /// In en, this message translates to:
  /// **'Could not translate lyrics'**
  String get lyricsTranslateError;

  /// No description provided for @lyricsTranslationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation failed: {error}'**
  String lyricsTranslationFailed(Object error);

  /// No description provided for @lyricsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lyricsRetry;

  /// No description provided for @lyricsHideTimingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide lyric timing'**
  String get lyricsHideTimingTooltip;

  /// No description provided for @lyricsAdjustTimingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Adjust lyric timing — hold for precision controls'**
  String get lyricsAdjustTimingTooltip;

  /// No description provided for @lyricsFindOnline.
  ///
  /// In en, this message translates to:
  /// **'Find lyrics online'**
  String get lyricsFindOnline;

  /// No description provided for @lyricsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get lyricsEmptyTitle;

  /// No description provided for @lyricsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This track has no embedded lyrics.'**
  String get lyricsEmptySubtitle;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageDutch.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageDutch;

  /// No description provided for @languagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get languagePolish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// No description provided for @languageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageSwedish;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// No description provided for @languageCzech.
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get languageCzech;

  /// No description provided for @languageGreek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageGreek;

  /// No description provided for @languageHungarian.
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get languageHungarian;

  /// No description provided for @languageRomanian.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get languageRomanian;

  /// No description provided for @languageDanish.
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get languageDanish;

  /// No description provided for @languageFinnish.
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get languageFinnish;

  /// No description provided for @languageNorwegian.
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get languageNorwegian;

  /// No description provided for @selectSongsTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Songs'**
  String get selectSongsTitle;

  /// No description provided for @selectSongsWhatIsMerging.
  ///
  /// In en, this message translates to:
  /// **'What is merging?'**
  String get selectSongsWhatIsMerging;

  /// No description provided for @selectSongsMergedExplanation.
  ///
  /// In en, this message translates to:
  /// **'Merged songs are different versions of the same song:'**
  String get selectSongsMergedExplanation;

  /// No description provided for @selectSongsBulletVersions.
  ///
  /// In en, this message translates to:
  /// **'Like remixes, live versions, or different quality versions'**
  String get selectSongsBulletVersions;

  /// No description provided for @selectSongsBulletFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites and \"suggest less\" are independent per song'**
  String get selectSongsBulletFavorites;

  /// No description provided for @selectSongsBulletStats.
  ///
  /// In en, this message translates to:
  /// **'Your play counts and stats remain unchanged'**
  String get selectSongsBulletStats;

  /// No description provided for @selectSongsBulletPriority.
  ///
  /// In en, this message translates to:
  /// **'Select a priority song (⭐) to prioritize it during shuffle'**
  String get selectSongsBulletPriority;

  /// No description provided for @selectSongsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs...'**
  String get selectSongsSearchHint;

  /// No description provided for @selectSongsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectSongsSelectedCount(int count);

  /// No description provided for @selectSongsReadyToMerge.
  ///
  /// In en, this message translates to:
  /// **'Ready to merge'**
  String get selectSongsReadyToMerge;

  /// No description provided for @selectSongsPrioritySongTooltip.
  ///
  /// In en, this message translates to:
  /// **'Priority song'**
  String get selectSongsPrioritySongTooltip;

  /// No description provided for @selectSongsSetPriorityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Set as priority'**
  String get selectSongsSetPriorityTooltip;

  /// No description provided for @selectSongsPriorityBadge.
  ///
  /// In en, this message translates to:
  /// **'PRIORITY'**
  String get selectSongsPriorityBadge;

  /// No description provided for @selectSongsMinSelection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Select at least 1 song} other{Select at least {count} songs}}'**
  String selectSongsMinSelection(int count);

  /// No description provided for @selectSongsMergeAction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Merge 1 Song} other{Merge {count} Songs}}'**
  String selectSongsMergeAction(int count);

  /// No description provided for @selectSongsSelectAction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Select 1 Song} other{Select {count} Songs}}'**
  String selectSongsSelectAction(int count);

  /// No description provided for @foldersAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Music folder added'**
  String get foldersAddedSnack;

  /// No description provided for @foldersRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Music folder removed'**
  String get foldersRemovedSnack;

  /// No description provided for @foldersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select folders containing your music files'**
  String get foldersSubtitle;

  /// No description provided for @foldersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No folders added yet'**
  String get foldersEmptyTitle;

  /// No description provided for @foldersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a folder to build your library.'**
  String get foldersEmptyMessage;

  /// No description provided for @foldersAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get foldersAddButton;

  /// No description provided for @foldersShortcutInternalStorage.
  ///
  /// In en, this message translates to:
  /// **'Internal Storage'**
  String get foldersShortcutInternalStorage;

  /// No description provided for @foldersShortcutMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get foldersShortcutMusic;

  /// No description provided for @foldersShortcutDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get foldersShortcutDownload;

  /// No description provided for @foldersShortcutStorageRoot.
  ///
  /// In en, this message translates to:
  /// **'Storage Root'**
  String get foldersShortcutStorageRoot;

  /// No description provided for @foldersShortcutHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get foldersShortcutHome;

  /// No description provided for @foldersShortcutDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get foldersShortcutDownloads;

  /// No description provided for @foldersShortcutDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get foldersShortcutDocuments;

  /// No description provided for @foldersDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Folder does not exist'**
  String get foldersDoesNotExist;

  /// No description provided for @foldersPermissionError.
  ///
  /// In en, this message translates to:
  /// **'Permission denied or error reading folder'**
  String get foldersPermissionError;

  /// No description provided for @foldersNewFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get foldersNewFolderTitle;

  /// No description provided for @foldersFolderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get foldersFolderNameLabel;

  /// No description provided for @foldersFolderNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter folder name'**
  String get foldersFolderNameHint;

  /// No description provided for @foldersCreateError.
  ///
  /// In en, this message translates to:
  /// **'Error creating folder: {error}'**
  String foldersCreateError(String error);

  /// No description provided for @foldersGoUp.
  ///
  /// In en, this message translates to:
  /// **'.. (Go up)'**
  String get foldersGoUp;

  /// No description provided for @foldersGoBack.
  ///
  /// In en, this message translates to:
  /// **'.. (Go back)'**
  String get foldersGoBack;

  /// No description provided for @foldersNoSubfolders.
  ///
  /// In en, this message translates to:
  /// **'No subfolders found.\nSelect this folder if it contains your music.'**
  String get foldersNoSubfolders;

  /// No description provided for @foldersSelectThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Select This Folder'**
  String get foldersSelectThisFolder;

  /// No description provided for @foldersSelectDestination.
  ///
  /// In en, this message translates to:
  /// **'Select Destination Folder'**
  String get foldersSelectDestination;

  /// No description provided for @foldersEmptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder. You can select it below.'**
  String get foldersEmptyFolder;

  /// No description provided for @foldersSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String foldersSelected(String name);

  /// No description provided for @foldersRoot.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get foldersRoot;

  /// No description provided for @foldersError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String foldersError(String error);

  /// No description provided for @foldersMoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Move Folder'**
  String get foldersMoveFolder;

  /// No description provided for @foldersMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved {name} to {path}'**
  String foldersMovedTo(String name, String path);

  /// No description provided for @foldersMoveError.
  ///
  /// In en, this message translates to:
  /// **'Error moving folder: {error}'**
  String foldersMoveError(String error);

  /// No description provided for @playlistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// No description provided for @playlistsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search playlists...'**
  String get playlistsSearchHint;

  /// No description provided for @playlistsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get playlistsCreate;

  /// No description provided for @playlistsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching playlists found'**
  String get playlistsNoMatches;

  /// No description provided for @playlistsCreatedOn.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String playlistsCreatedOn(String date);

  /// No description provided for @playlistsCreatedToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get playlistsCreatedToday;

  /// No description provided for @playlistsCreatedYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get playlistsCreatedYesterday;

  /// No description provided for @playlistsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String playlistsDaysAgo(int count);

  /// No description provided for @playlistsWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week ago} other{{count} weeks ago}}'**
  String playlistsWeeksAgo(int count);

  /// No description provided for @playlistsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String playlistsLoadError(String error);

  /// No description provided for @playlistsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistsEmptyTitle;

  /// No description provided for @playlistsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create your first playlist to get started'**
  String get playlistsEmptyMessage;

  /// No description provided for @playlistsNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistsNameTitle;

  /// No description provided for @playlistsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter playlist name'**
  String get playlistsNameHint;

  /// No description provided for @playlistsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get playlistsRenameTitle;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get statsTitle;

  /// No description provided for @statsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your stats'**
  String get statsLoadErrorTitle;

  /// No description provided for @statsReadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Reading your listening history'**
  String get statsReadingHistory;

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No listening history yet'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Play something and your listening habits will show up here.'**
  String get statsEmptyMessage;

  /// No description provided for @statsSectionOverTime.
  ///
  /// In en, this message translates to:
  /// **'Over time'**
  String get statsSectionOverTime;

  /// No description provided for @statsSectionWhen.
  ///
  /// In en, this message translates to:
  /// **'When you listen'**
  String get statsSectionWhen;

  /// No description provided for @statsSectionTop.
  ///
  /// In en, this message translates to:
  /// **'Your top'**
  String get statsSectionTop;

  /// No description provided for @statsSectionTaste.
  ///
  /// In en, this message translates to:
  /// **'Taste'**
  String get statsSectionTaste;

  /// No description provided for @statsByHour.
  ///
  /// In en, this message translates to:
  /// **'BY HOUR'**
  String get statsByHour;

  /// No description provided for @statsByWeekday.
  ///
  /// In en, this message translates to:
  /// **'BY WEEKDAY'**
  String get statsByWeekday;

  /// No description provided for @statsNoListening.
  ///
  /// In en, this message translates to:
  /// **'No listening recorded'**
  String get statsNoListening;

  /// No description provided for @statsAcrossPlays.
  ///
  /// In en, this message translates to:
  /// **'{time} across {plays}'**
  String statsAcrossPlays(String time, String plays);

  /// No description provided for @statsLibraryExplored.
  ///
  /// In en, this message translates to:
  /// **'Library explored'**
  String get statsLibraryExplored;

  /// No description provided for @statsPlaysFavourites.
  ///
  /// In en, this message translates to:
  /// **'Plays that were favourites'**
  String get statsPlaysFavourites;

  /// No description provided for @statsPlaysSkipped.
  ///
  /// In en, this message translates to:
  /// **'Plays skipped'**
  String get statsPlaysSkipped;

  /// No description provided for @statsAvgPlay.
  ///
  /// In en, this message translates to:
  /// **'AVERAGE PLAY'**
  String get statsAvgPlay;

  /// No description provided for @statsOnActiveDay.
  ///
  /// In en, this message translates to:
  /// **'ON AN ACTIVE DAY'**
  String get statsOnActiveDay;

  /// No description provided for @statsPlaysPerActiveDay.
  ///
  /// In en, this message translates to:
  /// **'PLAYS PER ACTIVE DAY'**
  String get statsPlaysPerActiveDay;

  /// No description provided for @statsFirstListen.
  ///
  /// In en, this message translates to:
  /// **'FIRST LISTEN'**
  String get statsFirstListen;

  /// No description provided for @statsShareOf.
  ///
  /// In en, this message translates to:
  /// **'{share} of {count}'**
  String statsShareOf(String share, String count);

  /// No description provided for @statsTopArtists.
  ///
  /// In en, this message translates to:
  /// **'TOP ARTISTS'**
  String get statsTopArtists;

  /// No description provided for @statsTopAlbums.
  ///
  /// In en, this message translates to:
  /// **'TOP ALBUMS'**
  String get statsTopAlbums;

  /// No description provided for @statsTopTracks.
  ///
  /// In en, this message translates to:
  /// **'TOP TRACKS'**
  String get statsTopTracks;

  /// No description provided for @statsTimeListened.
  ///
  /// In en, this message translates to:
  /// **'TIME LISTENED'**
  String get statsTimeListened;

  /// No description provided for @statsRangeWithDays.
  ///
  /// In en, this message translates to:
  /// **'{range} · {count, plural, =1{1 day with music on} other{{count} days with music on}}'**
  String statsRangeWithDays(String range, int count);

  /// No description provided for @statsPlays.
  ///
  /// In en, this message translates to:
  /// **'PLAYS'**
  String get statsPlays;

  /// No description provided for @statsSkips.
  ///
  /// In en, this message translates to:
  /// **'SKIPS'**
  String get statsSkips;

  /// No description provided for @statsTracks.
  ///
  /// In en, this message translates to:
  /// **'TRACKS'**
  String get statsTracks;

  /// No description provided for @statsStreak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get statsStreak;

  /// No description provided for @statsStreakBest.
  ///
  /// In en, this message translates to:
  /// **'best {count}'**
  String statsStreakBest(int count);

  /// No description provided for @statsPlaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String statsPlaysCount(int count);

  /// No description provided for @statsActiveDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active day} other{{count} active days}}'**
  String statsActiveDays(int count);

  /// No description provided for @statsSummary.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {plays} · {days}'**
  String statsSummary(String duration, String plays, String days);

  /// No description provided for @statsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Play something to start your history'**
  String get statsEmptyHint;

  /// No description provided for @statsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your stats'**
  String get statsLoadError;

  /// No description provided for @statsDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String statsDurationSeconds(int seconds);

  /// No description provided for @statsDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String statsDurationMinutes(int minutes);

  /// No description provided for @statsDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String statsDurationHours(int hours);

  /// No description provided for @statsDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String statsDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @statsSameAsBefore.
  ///
  /// In en, this message translates to:
  /// **'same as before'**
  String get statsSameAsBefore;

  /// No description provided for @statsHourTickAm.
  ///
  /// In en, this message translates to:
  /// **'{hour}a'**
  String statsHourTickAm(int hour);

  /// No description provided for @statsHourTickPm.
  ///
  /// In en, this message translates to:
  /// **'{hour}p'**
  String statsHourTickPm(int hour);

  /// Generic retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Generic refresh tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// App bar title on a past listening session
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get sessionDetailTitle;

  /// No description provided for @sessionStartedAt.
  ///
  /// In en, this message translates to:
  /// **'Started at {time}'**
  String sessionStartedAt(String time);

  /// Stat label when a session has one song
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get sessionSongSingular;

  /// Stat label when a session has several songs
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get sessionSongPlural;

  /// Header above the songs in a session
  ///
  /// In en, this message translates to:
  /// **'Songs Played'**
  String get sessionSongsPlayed;

  /// Empty state inside a session with no events
  ///
  /// In en, this message translates to:
  /// **'No songs recorded'**
  String get sessionNoSongs;

  /// Button that replays a session's queue immediately
  ///
  /// In en, this message translates to:
  /// **'Repeat Queue Now'**
  String get sessionRepeatNow;

  /// Button that queues a session after the current song
  ///
  /// In en, this message translates to:
  /// **'Play After Current Song'**
  String get sessionPlayAfterCurrent;

  /// Snackbar when a session cannot be replayed
  ///
  /// In en, this message translates to:
  /// **'No songs available to play'**
  String get sessionNoSongsAvailable;

  /// No description provided for @sessionAfterCurrentSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song will play after the current song} other{{count} songs will play after the current song}}'**
  String sessionAfterCurrentSnack(int count);

  /// No description provided for @sessionPlayingSnack.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Playing 1 song from this session} other{Playing {count} songs from this session}}'**
  String sessionPlayingSnack(int count);

  /// No description provided for @sessionDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String sessionDurationMinutes(int minutes, int seconds);

  /// No description provided for @sessionDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String sessionDurationSeconds(int seconds);

  /// App bar title for the session history list
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get sessionHistoryTitle;

  /// Error state on the session history screen
  ///
  /// In en, this message translates to:
  /// **'Failed to load sessions'**
  String get sessionLoadFailed;

  /// Empty state title on session history
  ///
  /// In en, this message translates to:
  /// **'No Sessions Yet'**
  String get sessionEmptyTitle;

  /// Empty state body on session history
  ///
  /// In en, this message translates to:
  /// **'Start listening to build your session history'**
  String get sessionEmptyMessage;

  /// Song count on a session card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String sessionSongCount(int count);

  /// App bar title for the play/skip event list
  ///
  /// In en, this message translates to:
  /// **'Song History'**
  String get playHistoryTitle;

  /// Empty state title for play history
  ///
  /// In en, this message translates to:
  /// **'No play history yet'**
  String get playHistoryEmptyTitle;

  /// Empty state body for play history
  ///
  /// In en, this message translates to:
  /// **'Start listening to build your history.'**
  String get playHistoryEmptyMessage;

  /// Legend and row label for a completed play
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get playHistoryListen;

  /// Legend and row label for a skipped play
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get playHistorySkip;

  /// Daily summary in the play history header
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}} · {duration}'**
  String playHistorySummary(int count, String duration);

  /// No description provided for @playHistoryDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String playHistoryDurationHours(int hours, int minutes);

  /// No description provided for @playHistoryDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String playHistoryDurationMinutes(int minutes);

  /// Fallback title when a play event has no filename
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get playHistoryUnknownSong;

  /// No description provided for @playHistoryDate.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String playHistoryDate(String month, int day, int year);

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthShortJan;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthShortFeb;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthShortMar;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthShortApr;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthShortMay;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthShortJun;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthShortJul;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthShortAug;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthShortSep;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthShortOct;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthShortNov;

  /// Short month name
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthShortDec;

  /// Placeholder inside the search field
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums...'**
  String get searchFieldHint;

  /// Search screen empty state before typing
  ///
  /// In en, this message translates to:
  /// **'Search your music collection'**
  String get searchEmptyTitle;

  /// Search screen empty state body
  ///
  /// In en, this message translates to:
  /// **'Find songs, artists, albums, and lyrics.'**
  String get searchEmptyMessage;

  /// Search error state title
  ///
  /// In en, this message translates to:
  /// **'Could not search'**
  String get searchFailed;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String searchNoResults(String query);

  /// Body under the no-results title
  ///
  /// In en, this message translates to:
  /// **'Try different keywords or check your filters.'**
  String get searchNoResultsHint;

  /// No description provided for @searchArtistsSection.
  ///
  /// In en, this message translates to:
  /// **'Artists ({count})'**
  String searchArtistsSection(int count);

  /// No description provided for @searchAlbumsSection.
  ///
  /// In en, this message translates to:
  /// **'Albums ({count})'**
  String searchAlbumsSection(int count);

  /// No description provided for @searchSongsSection.
  ///
  /// In en, this message translates to:
  /// **'Songs ({count})'**
  String searchSongsSection(int count);

  /// Track count under an artist or album hit
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String searchTrackCount(int count);

  /// No description provided for @searchAlbumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{artist} · {count, plural, =1{1 track} other{{count} tracks}}'**
  String searchAlbumSubtitle(String artist, int count);

  /// Song count on an artist or album search result
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String searchSongCount(int count);

  /// Tooltip on the suggest-less quick action when the song is already limited
  ///
  /// In en, this message translates to:
  /// **'Suggest more often'**
  String get quickActionSuggestMore;

  /// Tooltip on the suggest-less quick action
  ///
  /// In en, this message translates to:
  /// **'Suggest less often'**
  String get quickActionSuggestLess;

  /// Tooltip on the go-to-album quick action
  ///
  /// In en, this message translates to:
  /// **'Go to album'**
  String get quickActionGoToAlbum;

  /// Tooltip on the go-to-artist quick action
  ///
  /// In en, this message translates to:
  /// **'Go to artist'**
  String get quickActionGoToArtist;

  /// No description provided for @aboutChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get aboutChecking;

  /// No description provided for @aboutUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String aboutUpdateAvailable(String version);

  /// No description provided for @aboutUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get aboutUpToDate;

  /// No description provided for @aboutCheckForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get aboutCheckForUpdates;

  /// No description provided for @aboutCheckingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'wispie is checking GitHub Releases.'**
  String get aboutCheckingSubtitle;

  /// No description provided for @aboutUpdateAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A newer version is available on GitHub.'**
  String get aboutUpdateAvailableSubtitle;

  /// No description provided for @aboutLatestRelease.
  ///
  /// In en, this message translates to:
  /// **'Latest release: {version}'**
  String aboutLatestRelease(String version);

  /// No description provided for @aboutTapToCheck.
  ///
  /// In en, this message translates to:
  /// **'Tap below to check manually.'**
  String get aboutTapToCheck;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get aboutUnknown;

  /// No description provided for @aboutCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get aboutCheckNow;

  /// No description provided for @aboutViewRelease.
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get aboutViewRelease;

  /// No description provided for @aboutDebugGroup.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get aboutDebugGroup;

  /// No description provided for @aboutPersistWrites.
  ///
  /// In en, this message translates to:
  /// **'Persist writes'**
  String get aboutPersistWrites;

  /// No description provided for @aboutPersistWritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Debug builds keep changes in a throwaway copy by default. Applies on next launch.'**
  String get aboutPersistWritesSubtitle;

  /// No description provided for @appIconMoreSoon.
  ///
  /// In en, this message translates to:
  /// **'More icons coming soon'**
  String get appIconMoreSoon;

  /// No description provided for @appIconDesktopNote.
  ///
  /// In en, this message translates to:
  /// **'Desktop launchers and file managers keep the default icon; the window and Dock icon follow your choice.'**
  String get appIconDesktopNote;

  /// No description provided for @storageSettingsDiskGroup.
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get storageSettingsDiskGroup;

  /// No description provided for @storageSettingsIndexesGroup.
  ///
  /// In en, this message translates to:
  /// **'Indexes & Caches'**
  String get storageSettingsIndexesGroup;

  /// No description provided for @shellNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellNavHome;

  /// No description provided for @shellNavLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get shellNavLibrary;

  /// No description provided for @shellNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellNavProfile;

  /// No description provided for @shellSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search (Ctrl+K)'**
  String get shellSearchTooltip;

  /// No description provided for @shellShowSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar'**
  String get shellShowSidebar;

  /// No description provided for @shellHideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar'**
  String get shellHideSidebar;

  /// No description provided for @shellNothingUpNext.
  ///
  /// In en, this message translates to:
  /// **'Nothing up next'**
  String get shellNothingUpNext;

  /// No description provided for @shellNextInQueue.
  ///
  /// In en, this message translates to:
  /// **'Next in queue'**
  String get shellNextInQueue;

  /// No description provided for @shellPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get shellPlayNext;

  /// No description provided for @playerNothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get playerNothingPlaying;

  /// No description provided for @playerPaneLyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get playerPaneLyrics;

  /// No description provided for @playerPanePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerPanePlayer;

  /// No description provided for @playerPaneQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerPaneQueue;

  /// No description provided for @playerCloseEsc.
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get playerCloseEsc;

  /// No description provided for @playerSongOptions.
  ///
  /// In en, this message translates to:
  /// **'Song options'**
  String get playerSongOptions;

  /// No description provided for @playerShowArtwork.
  ///
  /// In en, this message translates to:
  /// **'Show artwork'**
  String get playerShowArtwork;

  /// No description provided for @playerShowVideo.
  ///
  /// In en, this message translates to:
  /// **'Show video'**
  String get playerShowVideo;

  /// No description provided for @drawerQueueHistory.
  ///
  /// In en, this message translates to:
  /// **'Queue History'**
  String get drawerQueueHistory;

  /// No description provided for @drawerTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get drawerTools;

  /// No description provided for @nowPlayingBarShuffleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Shuffle (hold for a new shuffle)'**
  String get nowPlayingBarShuffleTooltip;

  /// No description provided for @shuffleButtonAfterSong.
  ///
  /// In en, this message translates to:
  /// **'Shuffle after current song'**
  String get shuffleButtonAfterSong;

  /// No description provided for @shuffleButtonAfterQueue.
  ///
  /// In en, this message translates to:
  /// **'Shuffle after current queue'**
  String get shuffleButtonAfterQueue;

  /// No description provided for @shuffleButtonScanningTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scanning library ({percentage}%)'**
  String shuffleButtonScanningTooltip(String percentage);

  /// No description provided for @shuffleButtonScanningSemantics.
  ///
  /// In en, this message translates to:
  /// **'Scanning library {percentage} percent complete'**
  String shuffleButtonScanningSemantics(String percentage);

  /// No description provided for @shuffleButtonScanningMessage.
  ///
  /// In en, this message translates to:
  /// **'Scanning library: {percentage}%'**
  String shuffleButtonScanningMessage(String percentage);

  /// No description provided for @heartMenuRemoveFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from {name}'**
  String heartMenuRemoveFromPlaylist(String name);

  /// No description provided for @heartMenuRemovedFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Removed from {name}'**
  String heartMenuRemovedFromPlaylist(String name);

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortTitleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get sortTitleAZ;

  /// No description provided for @sortDateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get sortDateAdded;

  /// No description provided for @sortSongDateOldNew.
  ///
  /// In en, this message translates to:
  /// **'Song Date (Old - New)'**
  String get sortSongDateOldNew;

  /// No description provided for @sortSongDateNewOld.
  ///
  /// In en, this message translates to:
  /// **'Song Date (New - Old)'**
  String get sortSongDateNewOld;

  /// No description provided for @sortMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get sortMostPlayed;

  /// No description provided for @sortRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get sortRecentlyPlayed;

  /// No description provided for @sortRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sortRecommended;

  /// No description provided for @searchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchFilterAll;

  /// No description provided for @searchFilterArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchFilterArtists;

  /// No description provided for @playlistDialogAddTo.
  ///
  /// In en, this message translates to:
  /// **'Add to...'**
  String get playlistDialogAddTo;

  /// No description provided for @playlistDialogBulkAddTo.
  ///
  /// In en, this message translates to:
  /// **'Bulk Add to...'**
  String get playlistDialogBulkAddTo;

  /// No description provided for @playlistDialogUpdatedSelections.
  ///
  /// In en, this message translates to:
  /// **'Updated selections'**
  String get playlistDialogUpdatedSelections;

  /// No description provided for @albumCardAllSongs.
  ///
  /// In en, this message translates to:
  /// **'All songs'**
  String get albumCardAllSongs;

  /// No description provided for @dangerDialogTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type \"{text}\" to confirm'**
  String dangerDialogTypeToConfirm(String text);

  /// No description provided for @dangerDialogCountdown.
  ///
  /// In en, this message translates to:
  /// **'{label} ({seconds})'**
  String dangerDialogCountdown(String label, int seconds);

  /// No description provided for @appDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get appDialogConfirm;

  /// No description provided for @appDialogEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name...'**
  String get appDialogEnterName;

  /// No description provided for @transportRepeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get transportRepeatOff;

  /// No description provided for @transportRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get transportRepeatAll;

  /// No description provided for @transportRepeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get transportRepeatOne;

  /// No description provided for @durationSongsWithTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} • {duration}'**
  String durationSongsWithTotal(int count, String duration);

  /// No description provided for @waveformDeltaSeconds.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String waveformDeltaSeconds(String value);

  /// No description provided for @waveformDeltaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String waveformDeltaMinutes(String minutes, String seconds);

  /// No description provided for @waveformDeltaZero.
  ///
  /// In en, this message translates to:
  /// **'0s'**
  String get waveformDeltaZero;

  /// No description provided for @lyricsMatchContains.
  ///
  /// In en, this message translates to:
  /// **'contains \"{line}\"'**
  String lyricsMatchContains(String line);

  /// No description provided for @lyricsMatchPrefix.
  ///
  /// In en, this message translates to:
  /// **'contains \"'**
  String get lyricsMatchPrefix;

  /// No description provided for @lyricsMatchAvailable.
  ///
  /// In en, this message translates to:
  /// **'Lyrics available'**
  String get lyricsMatchAvailable;

  /// No description provided for @lyricsResumeSync.
  ///
  /// In en, this message translates to:
  /// **'Resume Sync'**
  String get lyricsResumeSync;

  /// No description provided for @lyricsTimingTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyric timing'**
  String get lyricsTimingTitle;

  /// No description provided for @lyricsTimingEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get lyricsTimingEarlier;

  /// No description provided for @lyricsTimingLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get lyricsTimingLater;

  /// No description provided for @lyricsTimingSyncToLine.
  ///
  /// In en, this message translates to:
  /// **'Sync to this line'**
  String get lyricsTimingSyncToLine;

  /// No description provided for @lyricsTimingReset.
  ///
  /// In en, this message translates to:
  /// **'Reset timing'**
  String get lyricsTimingReset;

  /// No description provided for @lyricsTimingSnapped.
  ///
  /// In en, this message translates to:
  /// **'Snapped to {value}'**
  String lyricsTimingSnapped(String value);

  /// No description provided for @lyricsTimingResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to reset to 0.00'**
  String get lyricsTimingResetTooltip;

  /// No description provided for @nowPlayingShowArtwork.
  ///
  /// In en, this message translates to:
  /// **'Show artwork'**
  String get nowPlayingShowArtwork;

  /// No description provided for @nowPlayingShowVideo.
  ///
  /// In en, this message translates to:
  /// **'Show video'**
  String get nowPlayingShowVideo;

  /// No description provided for @quickActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActionsTitle;

  /// No description provided for @quickActionsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get quickActionsReset;

  /// No description provided for @quickActionsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get quickActionsResetDone;

  /// No description provided for @quickActionsEnabledHeader.
  ///
  /// In en, this message translates to:
  /// **'ENABLED ({count})'**
  String quickActionsEnabledHeader(int count);

  /// No description provided for @quickActionsDisabledHeader.
  ///
  /// In en, this message translates to:
  /// **'DISABLED ({count})'**
  String quickActionsDisabledHeader(int count);

  /// No description provided for @quickActionsPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get quickActionsPlayNext;

  /// No description provided for @quickActionsGoToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get quickActionsGoToAlbum;

  /// No description provided for @quickActionsGoToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get quickActionsGoToArtist;

  /// No description provided for @quickActionsMoveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to Folder'**
  String get quickActionsMoveToFolder;

  /// No description provided for @quickActionsAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get quickActionsAddToPlaylist;

  /// No description provided for @quickActionsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get quickActionsShare;

  /// No description provided for @quickActionsAddToNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to New Playlist'**
  String get quickActionsAddToNewPlaylist;

  /// No description provided for @quickActionsEditMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get quickActionsEditMetadata;

  /// No description provided for @quickActionsFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get quickActionsFavorite;

  /// No description provided for @quickActionsSuggestLess.
  ///
  /// In en, this message translates to:
  /// **'Suggest Less'**
  String get quickActionsSuggestLess;

  /// No description provided for @quickActionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get quickActionsDelete;

  /// No description provided for @quickActionsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get quickActionsHide;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailableTitle;

  /// No description provided for @updateCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get updateCurrentLabel;

  /// No description provided for @updateNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get updateNewLabel;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A newer version of wispie is ready to download.'**
  String get updateAvailableBody;

  /// No description provided for @updateSkipVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkipVersion;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @updateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'s new?'**
  String get updateWhatsNew;

  /// No description provided for @externalOpenAddToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get externalOpenAddToLibrary;

  /// No description provided for @externalOpenDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get externalOpenDismiss;

  /// No description provided for @wideTrackTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get wideTrackTime;

  /// No description provided for @floatingDockPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get floatingDockPlay;

  /// No description provided for @floatingDockPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get floatingDockPause;

  /// No description provided for @floatingDockNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get floatingDockNext;

  /// No description provided for @barSeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Seek'**
  String get barSeekLabel;
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
