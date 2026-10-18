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

  /// Language label shared by the language picker row/sheet and the settings group header
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Settings label shared by the settings hub, profile entries, app drawer, and restore dialog section
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Subtitle for the Library settings page entry
  ///
  /// In en, this message translates to:
  /// **'Folders, filters, scanning'**
  String get settingsPageLibrarySubtitle;

  /// Playback title shared by the settings hub entry, the Playback screen app bar, and the song menu section
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPagePlaybackTitle;

  /// Subtitle for the Playback settings page entry
  ///
  /// In en, this message translates to:
  /// **'Transitions, fades, audio'**
  String get settingsPagePlaybackSubtitle;

  /// Lyrics title shared by the settings hub entry, the Lyrics screen, search filter chips, and the player pane tab
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get settingsPageLyricsTitle;

  /// Subtitle for the Lyrics settings page entry
  ///
  /// In en, this message translates to:
  /// **'Word sync, translation, sidebar'**
  String get settingsPageLyricsSubtitle;

  /// Appearance title shared by the settings hub entry and the Appearance screen app bar
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsPageAppearanceTitle;

  /// Subtitle for the Appearance settings page entry
  ///
  /// In en, this message translates to:
  /// **'Now playing, motion, app icon'**
  String get settingsPageAppearanceSubtitle;

  /// Title of the Home and Navigation settings page
  ///
  /// In en, this message translates to:
  /// **'Home & Navigation'**
  String get settingsPageHomeNavigationTitle;

  /// Subtitle for the Home and Navigation settings page entry
  ///
  /// In en, this message translates to:
  /// **'Home sections, lists, quick actions'**
  String get settingsPageHomeNavigationSubtitle;

  /// Title of the Sync settings page
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get settingsPageSyncTitle;

  /// Subtitle for the Sync settings page entry
  ///
  /// In en, this message translates to:
  /// **'Encrypted cross-device sync'**
  String get settingsPageSyncSubtitle;

  /// Title of the Backup and Restore settings page
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsPageBackupRestoreTitle;

  /// Subtitle for the Backup and Restore settings page entry
  ///
  /// In en, this message translates to:
  /// **'Export, import, automatic backups'**
  String get settingsPageBackupRestoreSubtitle;

  /// Storage title shared by the settings hub entries and the restore dialog section
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsPageStorageTitle;

  /// Subtitle for the Storage settings page entry
  ///
  /// In en, this message translates to:
  /// **'Disk usage, indexes, caches'**
  String get settingsPageStorageSubtitle;

  /// Title of the About settings page
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsPageAboutTitle;

  /// Subtitle for the About settings page entry
  ///
  /// In en, this message translates to:
  /// **'Version, updates, release notes'**
  String get settingsPageAboutSubtitle;

  /// Label for cancel button in dialogs and sheets
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Label for create button in playlist and dialog actions
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// Label for done or confirm button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Label for change action such as password
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// Delete label shared by song menus, bulk selection, quick actions, and destructive dialogs
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Hide label shared by bulk selection and quick actions
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get actionHide;

  /// Label for permanent delete confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete Permanently'**
  String get actionDeletePermanently;

  /// Tooltip and label for back navigation
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Label and tooltip for close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Title of the new playlist creation dialog
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get playlistNewTitle;

  /// Hint text for playlist name fields across the app
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistNameHint;

  /// Snackbar shown after a playlist is created
  ///
  /// In en, this message translates to:
  /// **'Created playlist \"{name}\"'**
  String playlistCreated(Object name);

  /// Snackbar shown after removing a song from favorites
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from favorites'**
  String songFavoriteRemoved(Object title);

  /// Snackbar shown after adding a song to favorites
  ///
  /// In en, this message translates to:
  /// **'Added {title} to favorites'**
  String songFavoriteAdded(Object title);

  /// Snackbar shown after marking a song to be suggested more
  ///
  /// In en, this message translates to:
  /// **'Will suggest {title} more often'**
  String songWillSuggestMore(Object title);

  /// Snackbar shown after marking a song to be suggested less
  ///
  /// In en, this message translates to:
  /// **'Will suggest {title} less often'**
  String songWillSuggestLess(Object title);

  /// Snackbar shown after adding a song to the Next Up queue
  ///
  /// In en, this message translates to:
  /// **'Added to Next Up: {title}'**
  String songAddedToNextUp(Object title);

  /// Text shared externally for a song as title by artist
  ///
  /// In en, this message translates to:
  /// **'{title} by {artist}'**
  String songShareText(Object artist, Object title);

  /// Snackbar shown after adding a song to a playlist
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String songAddedToPlaylist(Object name);

  /// Snackbar shown after removing a song from a playlist
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from playlist'**
  String songRemovedFromPlaylist(Object title);

  /// Snackbar shown after moving a song file to a folder
  ///
  /// In en, this message translates to:
  /// **'Moved {title} to {path}'**
  String songMovedTo(Object path, Object title);

  /// Snackbar shown when moving a song file fails
  ///
  /// In en, this message translates to:
  /// **'Error moving song: {error}'**
  String songMoveError(Object error);

  /// Snackbar shown after removing a song from the library
  ///
  /// In en, this message translates to:
  /// **'Removed {title} from library'**
  String songRemovedFromLibrary(Object title);

  /// Title of the delete song confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Song'**
  String get songDeleteTitle;

  /// Body of the delete song confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete \'\'{title}\'\' from your device? This cannot be undone.'**
  String songDeleteConfirm(Object title);

  /// Snackbar shown after a song file is deleted
  ///
  /// In en, this message translates to:
  /// **'Deleted {title}'**
  String songDeleted(Object title);

  /// Snackbar shown when deleting a song file fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting file: {error}'**
  String songDeleteError(Object error);

  /// Snackbar shown while searching online for cover art
  ///
  /// In en, this message translates to:
  /// **'Searching Last.fm, Deezer and iTunes for cover art...'**
  String get coverSearching;

  /// Snackbar shown when no cover art is found online
  ///
  /// In en, this message translates to:
  /// **'No missing cover art found online'**
  String get coverNoneFound;

  /// Snackbar shown after cover art is updated
  ///
  /// In en, this message translates to:
  /// **'Updated cover art for \"{title}\" ({source})'**
  String coverUpdated(Object source, Object title);

  /// Snackbar shown when cover art download fails
  ///
  /// In en, this message translates to:
  /// **'Failed to download cover art'**
  String get coverDownloadFailed;

  /// Snackbar shown when fetching cover art errors
  ///
  /// In en, this message translates to:
  /// **'Error fetching cover: {error}'**
  String coverFetchError(Object error);

  /// Title of the metadata fetch results panel
  ///
  /// In en, this message translates to:
  /// **'Metadata Fetch Results'**
  String get metaResultsTitle;

  /// Title shown while fetching missing metadata
  ///
  /// In en, this message translates to:
  /// **'Fetching Missing Metadata'**
  String get metaFetchingTitle;

  /// Stat label for tracks whose metadata was updated
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get metaStatUpdated;

  /// Stat label for tracks whose metadata was not found
  ///
  /// In en, this message translates to:
  /// **'Not Found'**
  String get metaStatNotFound;

  /// Stat label for tracks skipped during metadata fetch
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get metaStatSkipped;

  /// Button label to undo all metadata changes
  ///
  /// In en, this message translates to:
  /// **'Undo All'**
  String get metaUndoAll;

  /// Tooltip to undo metadata changes for one song
  ///
  /// In en, this message translates to:
  /// **'Undo this song'**
  String get metaUndoSong;

  /// Snackbar shown after reverting metadata changes for tracks
  ///
  /// In en, this message translates to:
  /// **'Reverted metadata changes for {count} track(s)'**
  String metaRevertedCount(int count);

  /// Label showing the source of fetched metadata
  ///
  /// In en, this message translates to:
  /// **'via {source}'**
  String metaViaSource(Object source);

  /// Ellipsis-overflow label shared by metadata results and indexer warnings
  ///
  /// In en, this message translates to:
  /// **'... and {count} more'**
  String metaMoreItems(int count);

  /// Heading for tracks whose metadata could not be found
  ///
  /// In en, this message translates to:
  /// **'Could Not Find'**
  String get metaCouldNotFind;

  /// Fallback artist name when unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get metaUnknownArtist;

  /// Message when all tracks already have metadata
  ///
  /// In en, this message translates to:
  /// **'All {count} tracks already have metadata'**
  String metaAllHaveMetadata(int count);

  /// Message when no tracks with missing metadata found
  ///
  /// In en, this message translates to:
  /// **'No tracks with missing metadata found'**
  String get metaNoMissingMetadata;

  /// Progress text while searching a batch of tracks
  ///
  /// In en, this message translates to:
  /// **'Searching batch {batch}...'**
  String metaSearchingBatch(int batch);

  /// Summary shown when metadata fetch is cancelled
  ///
  /// In en, this message translates to:
  /// **'Metadata fetch cancelled ({updated} updated, {notFound} not found)'**
  String metaCancelledSummary(int updated, int notFound);

  /// Title and barrier label of the song options menu sheet
  ///
  /// In en, this message translates to:
  /// **'Song Options'**
  String get songMenuTitle;

  /// Subtitle hint for the playback section
  ///
  /// In en, this message translates to:
  /// **'Queue, playlist, and share actions'**
  String get songMenuPlaybackHint;

  /// Subtitle hint for the library section
  ///
  /// In en, this message translates to:
  /// **'Move song and edit metadata'**
  String get songMenuLibraryHint;

  /// Section title for personalize actions in song menu
  ///
  /// In en, this message translates to:
  /// **'Personalize'**
  String get songMenuPersonalize;

  /// Subtitle hint for the personalize section
  ///
  /// In en, this message translates to:
  /// **'Favorite and recommendation settings'**
  String get songMenuPersonalizeHint;

  /// Section title for destructive actions in song menu
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get songMenuDanger;

  /// Subtitle hint for the danger section
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist or delete song'**
  String get songMenuDangerHint;

  /// Play Next label shared by the song menu, bulk selection, quick action bar, and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get songMenuPlayNext;

  /// Hint for play next action
  ///
  /// In en, this message translates to:
  /// **'Add song to play immediately after current track'**
  String get songMenuPlayNextHint;

  /// Action label to play next allowing duplicate
  ///
  /// In en, this message translates to:
  /// **'Play Next (Allow Duplicate)'**
  String get songMenuPlayNextDuplicate;

  /// Hint for allow duplicate play next
  ///
  /// In en, this message translates to:
  /// **'Add again even if already in queue'**
  String get songMenuPlayNextDuplicateHint;

  /// Add to Playlist label shared by the song menu, heart menu, quick action bar, and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get songMenuAddToPlaylist;

  /// Hint for quick add to recent playlist
  ///
  /// In en, this message translates to:
  /// **'Quick add to your most recent playlist'**
  String get songMenuAddToPlaylistHint;

  /// Add to New Playlist label shared by the song menu, heart menu, quick action bar, and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Add to New Playlist'**
  String get songMenuAddToNewPlaylist;

  /// Hint for create and add action
  ///
  /// In en, this message translates to:
  /// **'Create a playlist and add this song'**
  String get songMenuAddToNewPlaylistHint;

  /// Share label shared by the song menu, bulk selection bar, and quick actions
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get songMenuShare;

  /// Hint for share action
  ///
  /// In en, this message translates to:
  /// **'Share the audio file externally'**
  String get songMenuShareHint;

  /// Action label to fetch missing cover art
  ///
  /// In en, this message translates to:
  /// **'Fetch Missing Cover'**
  String get songMenuFetchCover;

  /// Hint for fetch cover action
  ///
  /// In en, this message translates to:
  /// **'Try searching Last.fm, Deezer and iTunes for cover art'**
  String get songMenuFetchCoverHint;

  /// Action label to fetch missing metadata
  ///
  /// In en, this message translates to:
  /// **'Fetch Missing Metadata'**
  String get songMenuFetchMetadata;

  /// Hint for fetch metadata action
  ///
  /// In en, this message translates to:
  /// **'Search online for title, artist, album and cover'**
  String get songMenuFetchMetadataHint;

  /// Move to Folder label shared by the song menu, quick action bar, and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Move to Folder'**
  String get songMenuMoveToFolder;

  /// Hint for move to folder action
  ///
  /// In en, this message translates to:
  /// **'Move this file to another folder'**
  String get songMenuMoveToFolderHint;

  /// Action label to manage playlists for a song
  ///
  /// In en, this message translates to:
  /// **'Manage Playlists'**
  String get songMenuManagePlaylists;

  /// Hint for manage playlists action
  ///
  /// In en, this message translates to:
  /// **'Add or remove from playlists'**
  String get songMenuManagePlaylistsHint;

  /// Edit Metadata label shared by the song menu, quick action bar, and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get songMenuEditMetadata;

  /// Hint for edit metadata action
  ///
  /// In en, this message translates to:
  /// **'Open metadata editor'**
  String get songMenuEditMetadataHint;

  /// Action label to remove from favorites
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get songMenuRemoveFavorite;

  /// Action label to add to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get songMenuAddFavorite;

  /// Hint for favorites toggle action
  ///
  /// In en, this message translates to:
  /// **'Tune your favorite songs list'**
  String get songMenuFavoritesHint;

  /// Action label to suggest the song more often again
  ///
  /// In en, this message translates to:
  /// **'Suggest More'**
  String get songMenuSuggestMore;

  /// Suggest Less label shared by the song menu, heart menu, bulk selection, and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Suggest Less'**
  String get songMenuSuggestLess;

  /// Hint for the suggest more/less toggle action
  ///
  /// In en, this message translates to:
  /// **'Adjust how often this song appears in suggestions'**
  String get songMenuSuggestHint;

  /// Action label to remove song from current playlist
  ///
  /// In en, this message translates to:
  /// **'Remove from Current Playlist'**
  String get songMenuRemoveFromPlaylist;

  /// Hint for removing song from current playlist
  ///
  /// In en, this message translates to:
  /// **'Keep file, remove playlist mapping'**
  String get songMenuRemoveFromPlaylistHint;

  /// Action label to hide song from library
  ///
  /// In en, this message translates to:
  /// **'Remove from Library'**
  String get songMenuRemoveFromLibrary;

  /// Hint for removing song from library
  ///
  /// In en, this message translates to:
  /// **'Keep file but hide from the library'**
  String get songMenuRemoveFromLibraryHint;

  /// Hint for permanent delete action
  ///
  /// In en, this message translates to:
  /// **'Delete the file from the device'**
  String get songMenuDeleteHint;

  /// Suffix appended to selected count in bulk selection bar
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get bulkSelected;

  /// Label for select all button in bulk selection bar
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get bulkSelectAll;

  /// Favorite label shared by bulk selection and quick actions
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get bulkFavorite;

  /// Label for unfavorite toggle button in bulk selection bar
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get bulkUnfavorite;

  /// Snackbar shown after removing songs from favorites in bulk
  ///
  /// In en, this message translates to:
  /// **'Removed {count} songs from favorites'**
  String bulkRemovedFromFavorites(int count);

  /// Snackbar shown after adding songs to favorites in bulk
  ///
  /// In en, this message translates to:
  /// **'Added {count} songs to favorites'**
  String bulkAddedToFavorites(int count);

  /// Label for playlist button in bulk selection bar
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get bulkPlaylist;

  /// Snackbar shown after adding songs to a playlist in bulk
  ///
  /// In en, this message translates to:
  /// **'Added {count} songs to {name}'**
  String bulkAddedToPlaylist(int count, Object name);

  /// Text showing song count when sharing multiple
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String bulkSongsCount(int count);

  /// Label for metadata edit button in bulk selection bar
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get bulkMetadata;

  /// Title of confirm dialog for hiding songs in bulk
  ///
  /// In en, this message translates to:
  /// **'Hide Songs'**
  String get bulkHideTitle;

  /// Body of confirm dialog for hiding songs in bulk
  ///
  /// In en, this message translates to:
  /// **'Hide {count} selected songs from library?'**
  String bulkHideMessage(int count);

  /// Title of confirm dialog for deleting songs in bulk
  ///
  /// In en, this message translates to:
  /// **'Delete Files'**
  String get bulkDeleteTitle;

  /// Body of confirm dialog for deleting songs in bulk
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {count} files from storage? This cannot be undone.'**
  String bulkDeleteMessage(int count);

  /// Snackbar shown after adding songs to queue in bulk
  ///
  /// In en, this message translates to:
  /// **'Added {count} songs to queue'**
  String bulkAddedToQueue(int count);

  /// Label for move to folder button in bulk selection bar
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get bulkMove;

  /// Snackbar shown after moving songs to a folder in bulk
  ///
  /// In en, this message translates to:
  /// **'Moved {count} songs to {path}'**
  String bulkMovedTo(int count, Object path);

  /// Snackbar shown when moving songs fails in bulk
  ///
  /// In en, this message translates to:
  /// **'Error moving songs: {error}'**
  String bulkMoveError(Object error);

  /// Snackbar shown after toggling suggest more in bulk
  ///
  /// In en, this message translates to:
  /// **'Will suggest {count} songs more'**
  String bulkWillSuggestMore(int count);

  /// Snackbar shown after toggling suggest less in bulk
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

  /// Queue row action: move track to the top of upcoming
  ///
  /// In en, this message translates to:
  /// **'Move to top'**
  String get queueActionMoveToTop;

  /// Remove label shared by queue rows, bulk rename token chips, and the home recommendation dialog
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

  /// Song count shared by the queue summary, playlist selector, search results, and session cards
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

  /// Earlier label shared by queue history day groups and the lyric timing slider
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get historyDayEarlier;

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

  /// Play label shared by the song list header, queue row menu, and floating dock
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get songListPlay;

  /// Pause label shared by song lists, the now playing bar, the floating dock, and calibration
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

  /// Pick-songs-to-merge title shared by the library, gradient detail, and merged songs screens
  ///
  /// In en, this message translates to:
  /// **'Select Songs to Merge'**
  String get songListSelectSongsToMerge;

  /// Snackbar shared after songs are merged from the song list, gradient detail, or library
  ///
  /// In en, this message translates to:
  /// **'Merged {count} songs'**
  String songListMergedSongs(int count);

  /// Generic "Error: {error}" text shared by merge, indexer, merged-library, folder, and playlist load failures
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

  /// Rename Playlist title shared by the song list and playlists screens
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

  /// Albums label shared by artist detail sections, search filters, and the library albums tab
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get gradientDetailAlbums;

  /// Songs label shared by detail sections, search filters, backup diff rows, and session stats
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

  /// Title of sync category toggle for play stats
  ///
  /// In en, this message translates to:
  /// **'Play stats'**
  String get syncPlayStats;

  /// Subtitle hint for play stats sync category
  ///
  /// In en, this message translates to:
  /// **'Listening history and play counts'**
  String get syncPlayStatsHint;

  /// Subtitle hint for favorites sync category
  ///
  /// In en, this message translates to:
  /// **'Favorite songs'**
  String get syncFavoritesHint;

  /// Title of sync category toggle for suggest-less songs
  ///
  /// In en, this message translates to:
  /// **'Suggest less'**
  String get syncSuggestLess;

  /// Subtitle hint for suggest-less sync category
  ///
  /// In en, this message translates to:
  /// **'Songs you asked to see less of'**
  String get syncSuggestLessHint;

  /// Title and subtitle of sync category toggle for hidden songs
  ///
  /// In en, this message translates to:
  /// **'Hidden songs'**
  String get syncHiddenSongs;

  /// Subtitle hint for playlists sync category
  ///
  /// In en, this message translates to:
  /// **'All playlists'**
  String get syncPlaylistsHint;

  /// Title of sync category toggle for merged songs
  ///
  /// In en, this message translates to:
  /// **'Merged songs'**
  String get syncMergedSongs;

  /// Subtitle hint for merged songs sync category
  ///
  /// In en, this message translates to:
  /// **'Merged song groups'**
  String get syncMergedSongsHint;

  /// Title of sync category toggle for app settings
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get syncAppSettings;

  /// Subtitle hint for app settings sync category
  ///
  /// In en, this message translates to:
  /// **'Theme, playback, and UI preferences'**
  String get syncAppSettingsHint;

  /// Title of sync category toggle for artist art
  ///
  /// In en, this message translates to:
  /// **'Artist art'**
  String get syncArtistArt;

  /// Subtitle hint for artist art sync category
  ///
  /// In en, this message translates to:
  /// **'Online artist cover choices'**
  String get syncArtistArtHint;

  /// Title of sync category toggle for album art
  ///
  /// In en, this message translates to:
  /// **'Album art'**
  String get syncAlbumArt;

  /// Subtitle hint for album art sync category
  ///
  /// In en, this message translates to:
  /// **'Online album cover choices'**
  String get syncAlbumArtHint;

  /// Group header for privacy info in sync settings
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get syncPrivacy;

  /// Title of end-to-end encryption info tile
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get syncEncryptedTitle;

  /// Body of end-to-end encryption info tile
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted on this device before upload. The server only stores ciphertext and cannot read your library, history, or settings.'**
  String get syncEncryptedBody;

  /// Title of recovery key info tile
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get syncRecoveryKeyTitle;

  /// Body of recovery key info tile
  ///
  /// In en, this message translates to:
  /// **'If you forget your password, only your recovery key can restore access. Nobody else can.'**
  String get syncRecoveryKeyBody;

  /// Group header for account section in sync settings
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get syncAccount;

  /// Fallback title when username missing in account tile
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get syncSignedIn;

  /// Fallback subtitle when server URL missing in account tile
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get syncConnected;

  /// Label for log out button in sync settings
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get syncLogOut;

  /// Body of log out confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Sync stops on this device. Local and cloud data are both kept.'**
  String get syncLogOutBody;

  /// Label for confirm button to log out and change server
  ///
  /// In en, this message translates to:
  /// **'Log out and change'**
  String get syncLogOutAndChange;

  /// Group header for cloud status section
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get syncCloud;

  /// Label for last synced timestamp row
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get syncLastSynced;

  /// Never label shared by the sync status and the auto-delete-backups option
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncNever;

  /// Label showing used vs total cloud quota
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota} used'**
  String syncUsedOfQuota(Object used, Object quota);

  /// Relative time label for just now
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get syncJustNow;

  /// Relative time label for minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String syncMinutesAgo(int count);

  /// Relative time label for hours ago
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String syncHoursAgo(int count);

  /// Relative time label for days ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String syncDaysAgo(int count);

  /// Title of auto sync toggle
  ///
  /// In en, this message translates to:
  /// **'Auto sync'**
  String get syncAutoSync;

  /// Subtitle hint for auto sync toggle
  ///
  /// In en, this message translates to:
  /// **'Sync in the background while the app is open'**
  String get syncAutoSyncHint;

  /// Label for sync now tile
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// Subtitle for sync now tile when no error
  ///
  /// In en, this message translates to:
  /// **'Merge this device with the cloud'**
  String get syncMergeDeviceHint;

  /// Subtitle for sync now tile showing last error
  ///
  /// In en, this message translates to:
  /// **'Last error: {error}'**
  String syncLastError(Object error);

  /// Group header for sync categories section
  ///
  /// In en, this message translates to:
  /// **'What gets synced'**
  String get syncWhatGetsSynced;

  /// Group header for device stats attribution section
  ///
  /// In en, this message translates to:
  /// **'Device Stats Attribution'**
  String get syncDeviceStatsAttribution;

  /// Label for this device's play count
  ///
  /// In en, this message translates to:
  /// **'This Device'**
  String get syncThisDevice;

  /// Label for other devices' play count
  ///
  /// In en, this message translates to:
  /// **'Other Devices'**
  String get syncOtherDevices;

  /// Label for total library play count
  ///
  /// In en, this message translates to:
  /// **'Total Library Stats'**
  String get syncTotalLibraryStats;

  /// Label showing play count with number
  ///
  /// In en, this message translates to:
  /// **'{count} plays'**
  String syncPlays(int count);

  /// Group header for danger zone section
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get syncDangerZone;

  /// Title of overwrite cloud tile
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud with this device'**
  String get syncOverwriteCloudTile;

  /// Subtitle hint for overwrite cloud tile
  ///
  /// In en, this message translates to:
  /// **'Replace all cloud data with what is on this device'**
  String get syncOverwriteCloudTileHint;

  /// Title of replace device tile
  ///
  /// In en, this message translates to:
  /// **'Replace this device with cloud'**
  String get syncReplaceDeviceTile;

  /// Subtitle hint for replace device tile
  ///
  /// In en, this message translates to:
  /// **'Erase synced data on this device and use the cloud copy'**
  String get syncReplaceDeviceTileHint;

  /// Title of change password tile
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get syncChangePassword;

  /// Title of new recovery key tile
  ///
  /// In en, this message translates to:
  /// **'New recovery key'**
  String get syncNewRecoveryKey;

  /// Subtitle hint for new recovery key tile
  ///
  /// In en, this message translates to:
  /// **'The old recovery key stops working'**
  String get syncNewRecoveryKeyHint;

  /// Title of change server tile
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get syncChangeServer;

  /// Subtitle hint for change server tile
  ///
  /// In en, this message translates to:
  /// **'Requires logging out first'**
  String get syncChangeServerHint;

  /// Body of change server confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'You will be logged out of the current server first. Local data is kept.'**
  String get syncChangeServerBody;

  /// Title of delete cloud account tile
  ///
  /// In en, this message translates to:
  /// **'Delete cloud account'**
  String get syncDeleteCloudAccount;

  /// Subtitle hint for delete cloud account tile
  ///
  /// In en, this message translates to:
  /// **'Removes cloud data permanently. Local data is kept'**
  String get syncDeleteCloudAccountHint;

  /// Body of delete cloud account confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Your cloud account and all encrypted data on the server are deleted permanently. Data on this device is kept.'**
  String get syncDeleteCloudAccountBody;

  /// Title of overwrite cloud confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Overwrite cloud'**
  String get syncOverwriteCloud;

  /// Body of overwrite cloud confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'All data in the cloud will be replaced by this device. Other devices will be asked to choose how to continue. This device keeps its data.'**
  String get syncOverwriteCloudBody;

  /// Checkbox label in overwrite cloud dialog
  ///
  /// In en, this message translates to:
  /// **'I understand the cloud data will be lost'**
  String get syncOverwriteCloudCheckbox;

  /// Confirm button label in overwrite cloud dialog
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get syncOverwrite;

  /// Title of replace device confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Replace this device'**
  String get syncReplaceDevice;

  /// Body of replace device confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Synced data on this device (stats, favorites, playlists, and so on) will be erased and replaced by the cloud copy. Music files are not touched.'**
  String get syncReplaceDeviceBody;

  /// Checkbox label in replace device dialog
  ///
  /// In en, this message translates to:
  /// **'I understand local synced data will be lost'**
  String get syncReplaceDeviceCheckbox;

  /// Confirm button label in replace device dialog
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get syncReplace;

  /// Label for current password field
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get syncCurrentPassword;

  /// Label for new password field
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get syncNewPassword;

  /// Label for the password input field in sync onboarding and confirmation dialogs
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get syncPassword;

  /// Snackbar shown after the sync account password is changed
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get syncPasswordChanged;

  /// Button label to generate a new sync recovery key
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get syncGenerate;

  /// Group header label for Now Playing appearance options
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get appearanceGroupNowPlaying;

  /// Title for the audio visualizer style setting
  ///
  /// In en, this message translates to:
  /// **'Audio Visualizer'**
  String get appearanceVisualizerTitle;

  /// Subtitle describing the audio visualizer options
  ///
  /// In en, this message translates to:
  /// **'Bars over the artwork while playing — synced follows the song, bass on the left'**
  String get appearanceVisualizerSubtitle;

  /// Option label for the classic visualizer mode
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get appearanceVisualizerClassic;

  /// Option label for the synced visualizer mode
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get appearanceVisualizerSynced;

  /// Title for the progress bar style setting
  ///
  /// In en, this message translates to:
  /// **'Progress Bar Style'**
  String get appearanceProgressBarTitle;

  /// Subtitle shown when the basic progress bar is selected
  ///
  /// In en, this message translates to:
  /// **'Simple line progress bar'**
  String get appearanceProgressBasicSubtitle;

  /// Subtitle shown when the waveform progress bar is selected
  ///
  /// In en, this message translates to:
  /// **'Static audio waveform'**
  String get appearanceProgressWaveformSubtitle;

  /// Subtitle shown when the sound-reactive progress bar is selected
  ///
  /// In en, this message translates to:
  /// **'Sound-reactive dynamic waveform with live spectrum & beat response'**
  String get appearanceProgressReactiveSubtitle;

  /// Option label for the standard (basic) progress bar
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get appearanceProgressStandard;

  /// Option label for the waveform progress bar
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get appearanceProgressWaveform;

  /// Option label for the sound-reactive progress bar
  ///
  /// In en, this message translates to:
  /// **'Sound Reactive'**
  String get appearanceProgressSoundReactive;

  /// Title for the waveform scrubbing haptics toggle
  ///
  /// In en, this message translates to:
  /// **'Waveform Scrubbing Haptics'**
  String get appearanceHapticsTitle;

  /// Subtitle for the waveform scrubbing haptics toggle
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback for each bar while seeking'**
  String get appearanceHapticsSubtitle;

  /// Title for the player cover sizing setting
  ///
  /// In en, this message translates to:
  /// **'Player Cover Sizing'**
  String get appearanceCoverSizingTitle;

  /// Subtitle for the player cover sizing setting
  ///
  /// In en, this message translates to:
  /// **'Auto-fit or preserve source aspect ratio'**
  String get appearanceCoverSizingSubtitle;

  /// Option label for auto-fit cover sizing
  ///
  /// In en, this message translates to:
  /// **'Auto Fit'**
  String get appearanceCoverAutoFit;

  /// Option label for source-size cover sizing
  ///
  /// In en, this message translates to:
  /// **'Source Size'**
  String get appearanceCoverSourceSize;

  /// Title for the immersive full-bleed design toggle
  ///
  /// In en, this message translates to:
  /// **'Immersive design'**
  String get appearanceImmersiveTitle;

  /// Subtitle for the immersive full-bleed design toggle
  ///
  /// In en, this message translates to:
  /// **'Full-bleed player cover and gradient detail screens'**
  String get appearanceImmersiveSubtitle;

  /// Group header label for player motion settings
  ///
  /// In en, this message translates to:
  /// **'Player motion'**
  String get appearanceGroupPlayerMotion;

  /// Title for the beat-reactive cover toggle
  ///
  /// In en, this message translates to:
  /// **'Beat-reactive cover'**
  String get appearanceBeatCoverTitle;

  /// Subtitle shown when beat-reactive cover is unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable while immersive design is on'**
  String get appearanceBeatCoverUnavailable;

  /// Subtitle for the beat-reactive cover toggle
  ///
  /// In en, this message translates to:
  /// **'Album art pulses with the beat'**
  String get appearanceBeatCoverSubtitle;

  /// Title for the cover reaction intensity setting
  ///
  /// In en, this message translates to:
  /// **'Cover intensity'**
  String get appearanceCoverIntensityTitle;

  /// Subtitle for the cover reaction intensity setting
  ///
  /// In en, this message translates to:
  /// **'How strongly the cover reacts'**
  String get appearanceCoverIntensitySubtitle;

  /// Title for the spin artwork while playing toggle
  ///
  /// In en, this message translates to:
  /// **'Spin artwork while playing'**
  String get appearanceSpinArtworkTitle;

  /// Subtitle for the spin artwork while playing toggle
  ///
  /// In en, this message translates to:
  /// **'Artwork turns slowly in the minimized bottom bar while a song plays'**
  String get appearanceSpinArtworkSubtitle;

  /// Title for the beat-reactive particles toggle
  ///
  /// In en, this message translates to:
  /// **'Beat-reactive particles'**
  String get appearanceParticlesTitle;

  /// Subtitle for the beat-reactive particles toggle
  ///
  /// In en, this message translates to:
  /// **'Floating particles that drift and breathe with the music'**
  String get appearanceParticlesSubtitle;

  /// Title for the particle density setting
  ///
  /// In en, this message translates to:
  /// **'Particle density'**
  String get appearanceParticleDensityTitle;

  /// Subtitle for the particle density setting
  ///
  /// In en, this message translates to:
  /// **'How many particles and how lively'**
  String get appearanceParticleDensitySubtitle;

  /// Title for the beat sync offset setting
  ///
  /// In en, this message translates to:
  /// **'Beat sync offset'**
  String get appearanceBeatOffsetTitle;

  /// Subtitle shown when no beat sync offset is set
  ///
  /// In en, this message translates to:
  /// **'No offset — raise it if the pulse feels early'**
  String get appearanceBeatOffsetNone;

  /// Label showing the beat sync offset in milliseconds
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String appearanceBeatOffsetValue(int ms);

  /// Label showing the beat sync offset in ms with a Bluetooth hint
  ///
  /// In en, this message translates to:
  /// **'{ms} ms (raise for Bluetooth)'**
  String appearanceBeatOffsetBluetooth(int ms);

  /// Title for the beat sync calibration entry
  ///
  /// In en, this message translates to:
  /// **'Calibrate beat sync'**
  String get appearanceCalibrateTitle;

  /// Subtitle for the beat sync calibration entry
  ///
  /// In en, this message translates to:
  /// **'Line up particles with a click track by ear'**
  String get appearanceCalibrateSubtitle;

  /// Title and group label for the app icon setting
  ///
  /// In en, this message translates to:
  /// **'App icon'**
  String get appearanceAppIcon;

  /// Label for the minimum intensity level
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get appearanceIntensityMin;

  /// Label for the subtle intensity level
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get appearanceIntensitySubtle;

  /// Label for the balanced intensity level
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get appearanceIntensityBalanced;

  /// Label for the bold intensity level
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get appearanceIntensityBold;

  /// Label for the maximum intensity level
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get appearanceIntensityMax;

  /// Custom label shared by the intensity options and the bulk rename format preset
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get appearanceIntensityCustom;

  /// Title for the export app data action
  ///
  /// In en, this message translates to:
  /// **'Export App Data'**
  String get backupExportAppData;

  /// Subtitle for the export app data action
  ///
  /// In en, this message translates to:
  /// **'Backup your stats, favorites, and playlists'**
  String get backupExportAppDataSubtitle;

  /// Snackbar shown when an app data export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String backupExportFailed(Object error);

  /// Title for the import app data action
  ///
  /// In en, this message translates to:
  /// **'Import App Data'**
  String get backupImportAppData;

  /// Subtitle for the import app data action
  ///
  /// In en, this message translates to:
  /// **'Restore data from a backup (replaces all)'**
  String get backupImportAppDataSubtitle;

  /// Title for the manage backups action
  ///
  /// In en, this message translates to:
  /// **'Manage Backups'**
  String get backupManageBackups;

  /// Subtitle for the manage backups action
  ///
  /// In en, this message translates to:
  /// **'Create, restore, and manage app backups'**
  String get backupManageBackupsSubtitle;

  /// Group header label for automatic backups
  ///
  /// In en, this message translates to:
  /// **'Automatic Backups'**
  String get backupAutomaticBackups;

  /// Title for the automatic backup frequency setting
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get backupAutoBackup;

  /// Subtitle for the automatic backup frequency setting
  ///
  /// In en, this message translates to:
  /// **'How often a backup is taken'**
  String get backupAutoBackupSubtitle;

  /// Title for the automatic backup content setting
  ///
  /// In en, this message translates to:
  /// **'Auto Backup Content'**
  String get backupAutoBackupContent;

  /// Subtitle for the automatic backup content setting
  ///
  /// In en, this message translates to:
  /// **'What data is included in automatic backups'**
  String get backupAutoBackupContentSubtitle;

  /// Subtitle in the automatic backup content dialog
  ///
  /// In en, this message translates to:
  /// **'Select content for automatic backups'**
  String get backupAutoBackupContentDialogSubtitle;

  /// Save label shared by the backup options dialog, backup settings, and the default app dialog confirm
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get backupSave;

  /// Title for the auto-delete old backups setting
  ///
  /// In en, this message translates to:
  /// **'Auto-Delete Old Backups'**
  String get backupAutoDeleteOld;

  /// Subtitle for the auto-delete old backups setting
  ///
  /// In en, this message translates to:
  /// **'Discard backups older than this'**
  String get backupAutoDeleteOldSubtitle;

  /// Option label for disabled backup frequency
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get backupFrequencyDisabled;

  /// Option label for every 24 hours backup frequency
  ///
  /// In en, this message translates to:
  /// **'Every 24 hours'**
  String get backupFrequencyEvery24Hours;

  /// Option label for every 48 hours backup frequency
  ///
  /// In en, this message translates to:
  /// **'Every 48 hours'**
  String get backupFrequencyEvery48Hours;

  /// Option label for every 3 days backup frequency
  ///
  /// In en, this message translates to:
  /// **'Every 3 days'**
  String get backupFrequencyEvery3Days;

  /// Option label for every 7 days backup frequency
  ///
  /// In en, this message translates to:
  /// **'Every 7 days'**
  String get backupFrequencyEvery7Days;

  /// Option label for deleting backups after N days
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String backupDeleteAfterDays(int count);

  /// Title of the export options dialog
  ///
  /// In en, this message translates to:
  /// **'Export Options'**
  String get backupExportOptionsTitle;

  /// Instruction label in the export options dialog
  ///
  /// In en, this message translates to:
  /// **'Select content to export:'**
  String get backupExportSelectContent;

  /// Checkbox title for including user stats in a backup
  ///
  /// In en, this message translates to:
  /// **'User Stats'**
  String get backupContentUserStats;

  /// Subtitle for including user stats in a backup
  ///
  /// In en, this message translates to:
  /// **'Play counts, sessions, fun stats'**
  String get backupContentUserStatsSubtitle;

  /// Checkbox title for including user data in a backup
  ///
  /// In en, this message translates to:
  /// **'User Data'**
  String get backupContentUserData;

  /// Subtitle for including user data in a backup
  ///
  /// In en, this message translates to:
  /// **'Favorites, hidden, playlists'**
  String get backupContentUserDataSubtitle;

  /// Checkbox title for including user settings in a backup
  ///
  /// In en, this message translates to:
  /// **'User Settings'**
  String get backupContentUserSettings;

  /// Subtitle for including user settings in a backup
  ///
  /// In en, this message translates to:
  /// **'Theme, sort order, preferences'**
  String get backupContentUserSettingsSubtitle;

  /// Subtitle for including cover cache in a backup
  ///
  /// In en, this message translates to:
  /// **'Album artwork images'**
  String get backupContentCoverCacheSubtitle;

  /// Subtitle for including library cache in a backup
  ///
  /// In en, this message translates to:
  /// **'Cached song metadata'**
  String get backupContentLibraryCacheSubtitle;

  /// Subtitle for including search index in a backup
  ///
  /// In en, this message translates to:
  /// **'Indexed search data'**
  String get backupContentSearchIndexSubtitle;

  /// Subtitle for including waveform cache in a backup
  ///
  /// In en, this message translates to:
  /// **'Audio waveform data'**
  String get backupContentWaveformCacheSubtitle;

  /// Subtitle for including color cache in a backup
  ///
  /// In en, this message translates to:
  /// **'Album color themes'**
  String get backupContentColorCacheSubtitle;

  /// Subtitle for including lyrics cache in a backup
  ///
  /// In en, this message translates to:
  /// **'Stored lyrics data'**
  String get backupContentLyricsCacheSubtitle;

  /// Uppercase label for the cancel button in dialogs
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get backupCancelUpper;

  /// Uppercase label for the export button in export dialog
  ///
  /// In en, this message translates to:
  /// **'EXPORT'**
  String get backupExportUpper;

  /// Uppercase label for the continue button in import confirmation
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get backupContinueUpper;

  /// Title of the import data confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get backupImportDataTitle;

  /// Warning text shown before importing data
  ///
  /// In en, this message translates to:
  /// **'This will replace ALL existing data with the imported data.\n\nYour current stats, favorites, playlists, and settings will be overwritten.\n\nThis action cannot be undone.'**
  String get backupImportWarning;

  /// Progress label shown while importing data
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get backupImportingLabel;

  /// Title of the importing data progress dialog
  ///
  /// In en, this message translates to:
  /// **'Importing data'**
  String get backupImportingTitle;

  /// Snackbar shown after a successful data import
  ///
  /// In en, this message translates to:
  /// **'Import successful!'**
  String get backupImportSuccess;

  /// Snackbar shown when importing backup data fails
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String backupImportFailed(Object error);

  /// Snackbar shown after updating a song's cover art
  ///
  /// In en, this message translates to:
  /// **'Cover updated successfully'**
  String get metadataCoverUpdated;

  /// Snackbar shown when picking a cover image fails
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String metadataPickImageError(Object error);

  /// Title of the remove cover art confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get metadataRemoveCoverTitle;

  /// Body of the remove cover art confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove the cover art?'**
  String get metadataRemoveCoverBody;

  /// Destructive confirm button for removing cover art
  ///
  /// In en, this message translates to:
  /// **'REMOVE'**
  String get metadataRemoveUpper;

  /// Snackbar shown after removing a song's cover art
  ///
  /// In en, this message translates to:
  /// **'Cover removed'**
  String get metadataCoverRemoved;

  /// Snackbar shown when removing cover art fails
  ///
  /// In en, this message translates to:
  /// **'Error removing cover: {error}'**
  String metadataRemoveCoverError(Object error);

  /// Title of the fix thumbnail result dialog
  ///
  /// In en, this message translates to:
  /// **'Fix Thumbnail Result'**
  String get metadataFixResultTitle;

  /// Body text above the original and new thumbnail comparison
  ///
  /// In en, this message translates to:
  /// **'Review the changes below:'**
  String get metadataFixReviewBody;

  /// Label for the original thumbnail in the fix dialog
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get metadataFixOriginal;

  /// New label shared by the thumbnail fix dialog and the update dialog
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get metadataFixNew;

  /// Label for a selected alternative fixed thumbnail option
  ///
  /// In en, this message translates to:
  /// **'New (Option {n})'**
  String metadataFixNewOption(int n);

  /// Button label to reveal alternative fixed thumbnails
  ///
  /// In en, this message translates to:
  /// **'See Alternatives'**
  String get metadataFixSeeAlternatives;

  /// Button label to apply the selected change (thumbnail or personality)
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get metadataFixApply;

  /// Snackbar shown after fixing a thumbnail
  ///
  /// In en, this message translates to:
  /// **'Thumbnail fixed successfully'**
  String get metadataFixSuccess;

  /// Snackbar shown when fixing a thumbnail fails
  ///
  /// In en, this message translates to:
  /// **'Error fixing thumbnail: {error}'**
  String metadataFixError(Object error);

  /// Button label to fix a song's thumbnail
  ///
  /// In en, this message translates to:
  /// **'Fix Thumbnail'**
  String get metadataFixThumbnail;

  /// Help text explaining the thumbnail fix tool
  ///
  /// In en, this message translates to:
  /// **'This tool automatically improves your album art by:\n\n1. Detecting and removing black bars/borders (common in YouTube thumbnails)\n2. Cropping the image to a perfect square (1:1 ratio)\n\nBest used for converting 16:9 thumbnails into proper album covers.'**
  String get metadataFixHelpBody;

  /// Button label to dismiss a help dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get metadataGotIt;

  /// Title of the cover export file picker dialog
  ///
  /// In en, this message translates to:
  /// **'Export Cover'**
  String get metadataExportCover;

  /// Export label shared by the metadata editor and the backup management actions
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get metadataExport;

  /// Snackbar shown after exporting cover art
  ///
  /// In en, this message translates to:
  /// **'Cover exported to {uri}'**
  String metadataExportSuccess(Object uri);

  /// Snackbar shown when exporting cover art fails
  ///
  /// In en, this message translates to:
  /// **'Error exporting cover: {error}'**
  String metadataExportError(Object error);

  /// Title and action label to replace a song's file
  ///
  /// In en, this message translates to:
  /// **'Replace Song'**
  String get metadataReplaceSong;

  /// Help text explaining song file replacement
  ///
  /// In en, this message translates to:
  /// **'Swaps this song\'\'s file for another copy of the same song (better rip, lossless, clean encode).\n\nPlay history, favourites, playlists and library date move to the new file. Its metadata is re-read from the file, and anything it lacks shows as unknown.\n\nThe new file must be outside your library folders and have a different filename.'**
  String get metadataReplaceHelpBody;

  /// Snackbar shown after replacing a song's file
  ///
  /// In en, this message translates to:
  /// **'Replaced with {filename}'**
  String metadataReplaced(Object filename);

  /// Snackbar shown when replacing a song's file fails
  ///
  /// In en, this message translates to:
  /// **'Could not replace the file: {error}'**
  String metadataReplaceError(Object error);

  /// Body text showing old and new filenames in the replace dialog
  ///
  /// In en, this message translates to:
  /// **'{oldName}\nreplaced by {newName}'**
  String metadataReplaceFilesBody(Object oldName, Object newName);

  /// Question asking what to do with the original file
  ///
  /// In en, this message translates to:
  /// **'What should happen to the original?'**
  String get metadataReplaceOriginalQuestion;

  /// Validation message when no replacement file is selected
  ///
  /// In en, this message translates to:
  /// **'No file was selected.'**
  String get metadataReplaceRejectNoFile;

  /// Validation message when the replacement file format is unsupported
  ///
  /// In en, this message translates to:
  /// **'That file is not an audio or video format this library can read.'**
  String get metadataReplaceRejectUnsupported;

  /// Validation message when the replacement has the same filename
  ///
  /// In en, this message translates to:
  /// **'The replacement needs a different filename. Changing only the extension is enough.'**
  String get metadataReplaceRejectSameFilename;

  /// Validation message when the replacement file is inside library folders
  ///
  /// In en, this message translates to:
  /// **'That file is inside one of your library folders. Pick a copy from somewhere outside your library.'**
  String get metadataReplaceRejectInsideLibrary;

  /// Validation message when a file with the new name already exists beside the original
  ///
  /// In en, this message translates to:
  /// **'A file named \"{filename}\" already sits next to the original.'**
  String metadataReplaceRejectDestinationExists(String filename);

  /// Validation message when the library already has a song with the new name
  ///
  /// In en, this message translates to:
  /// **'Your library already has a song named \"{filename}\".'**
  String metadataReplaceRejectLibraryHasName(String filename);

  /// Button label to keep and hide the original file
  ///
  /// In en, this message translates to:
  /// **'KEEP, HIDE IT'**
  String get metadataKeepHideUpper;

  /// Button label to delete the original file
  ///
  /// In en, this message translates to:
  /// **'DELETE IT'**
  String get metadataDeleteItUpper;

  /// Snackbar shown after saving metadata
  ///
  /// In en, this message translates to:
  /// **'Metadata updated successfully'**
  String get metadataSaved;

  /// Snackbar shown when saving metadata fails
  ///
  /// In en, this message translates to:
  /// **'Error saving metadata: {error}'**
  String metadataSaveError(Object error);

  /// Snackbar shown when no online cover art is found
  ///
  /// In en, this message translates to:
  /// **'No online cover art found'**
  String get metadataNoOnlineCover;

  /// Title of the online cover art picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select Cover Art'**
  String get metadataSelectCoverTitle;

  /// Title line showing title and artist for an online cover result
  ///
  /// In en, this message translates to:
  /// **'{title} - {artist}'**
  String metadataResultTitleArtist(Object title, Object artist);

  /// Label showing the source of an online cover result
  ///
  /// In en, this message translates to:
  /// **'Source: {source}'**
  String metadataSourceLabel(Object source);

  /// Snackbar shown after applying an online cover
  ///
  /// In en, this message translates to:
  /// **'Cover updated from {source}'**
  String metadataCoverUpdatedFrom(Object source);

  /// Snackbar shown when no online metadata match is found
  ///
  /// In en, this message translates to:
  /// **'No matching metadata found online'**
  String get metadataNoOnlineMatch;

  /// Title of the online metadata match picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select Online Match'**
  String get metadataSelectMatchTitle;

  /// Subtitle showing artist, album and source for an online match
  ///
  /// In en, this message translates to:
  /// **'{artist} · {album} ({source})'**
  String metadataResultDetail(Object artist, Object album, Object source);

  /// Snackbar shown after loading metadata from an online source
  ///
  /// In en, this message translates to:
  /// **'Metadata & cover loaded from {source}'**
  String metadataLoadedFrom(Object source);

  /// Snackbar shown when fetching online metadata fails
  ///
  /// In en, this message translates to:
  /// **'Error fetching metadata: {error}'**
  String metadataFetchError(Object error);

  /// Section header for cover art in the metadata editor
  ///
  /// In en, this message translates to:
  /// **'Cover Art'**
  String get metadataSectionCover;

  /// Button label to pick a local cover image
  ///
  /// In en, this message translates to:
  /// **'Change Cover'**
  String get metadataChangeCover;

  /// Tooltip for the help button on thumbnail fix and replace actions
  ///
  /// In en, this message translates to:
  /// **'What does this do?'**
  String get metadataWhatDoesThisDo;

  /// Section header for file information in the metadata editor
  ///
  /// In en, this message translates to:
  /// **'File Information'**
  String get metadataSectionFile;

  /// Label for the filename field
  ///
  /// In en, this message translates to:
  /// **'Filename (without extension)'**
  String get metadataFilenameLabel;

  /// Helper text under the filename field
  ///
  /// In en, this message translates to:
  /// **'Renaming the file will update it locally.'**
  String get metadataFilenameHelper;

  /// Section header for song metadata fields
  ///
  /// In en, this message translates to:
  /// **'Song Metadata'**
  String get metadataSectionSong;

  /// Button label to fetch metadata online
  ///
  /// In en, this message translates to:
  /// **'Fetch Online'**
  String get metadataFetchOnline;

  /// Title label shared by metadata fields, the lyrics search sheet, the wide track table, and bulk rename
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get metadataTitleLabel;

  /// Label for the artist field
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get metadataArtistLabel;

  /// Label for the album field
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get metadataAlbumLabel;

  /// Section header for additional content such as lyrics
  ///
  /// In en, this message translates to:
  /// **'Additional Content'**
  String get metadataSectionExtra;

  /// Title and action to edit a song's lyrics
  ///
  /// In en, this message translates to:
  /// **'Edit Lyrics'**
  String get metadataEditLyrics;

  /// Subtitle for the edit lyrics entry
  ///
  /// In en, this message translates to:
  /// **'View or edit embedded lyrics'**
  String get metadataEditLyricsSubtitle;

  /// Button label to save metadata or lyrics
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get metadataSaveUpper;

  /// Snackbar shown when loading lyrics fails
  ///
  /// In en, this message translates to:
  /// **'Error loading lyrics: {error}'**
  String metadataLyricsLoadError(Object error);

  /// Snackbar shown when saving lyrics fails
  ///
  /// In en, this message translates to:
  /// **'Error saving lyrics: {error}'**
  String metadataLyricsSaveError(Object error);

  /// Snackbar shown after loading lyrics from an online search
  ///
  /// In en, this message translates to:
  /// **'Lyrics loaded — press SAVE to apply'**
  String get metadataLyricsLoaded;

  /// Tooltip for the online lyrics search button
  ///
  /// In en, this message translates to:
  /// **'Search online'**
  String get metadataSearchOnline;

  /// Hint text explaining embedded lyrics and timestamps
  ///
  /// In en, this message translates to:
  /// **'Lyrics are embedded in the audio file. You can use [mm:ss.xx] timestamps for synced lyrics.'**
  String get metadataLyricsHint;

  /// Placeholder for the lyrics text field
  ///
  /// In en, this message translates to:
  /// **'Enter lyrics here...'**
  String get metadataLyricsFieldHint;

  /// Profile label shared by the profile screen and the bottom navigation tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Single-letter avatar shown when no username is set
  ///
  /// In en, this message translates to:
  /// **'U'**
  String get profileAvatarFallback;

  /// Default display name when no username is set
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileDefaultName;

  /// Label showing the app version on the profile screen
  ///
  /// In en, this message translates to:
  /// **'wispie v{version}'**
  String profileAppVersion(String version);

  /// Stat label for the hidden songs count
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get profileHidden;

  /// Stat label for the suggest-less songs count
  ///
  /// In en, this message translates to:
  /// **'Suggest-less'**
  String get profileSuggestLess;

  /// Section header for shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Shuffle Personality'**
  String get profileShuffleSection;

  /// Shuffle personality option: Smart
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get profileSmart;

  /// Subtitle for the Smart shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Learns your taste, trends and context. Recommended'**
  String get profileSmartSubtitle;

  /// Shuffle personality option: Default
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get profileDefault;

  /// Subtitle for the Default shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Balanced mix with anti-repeat'**
  String get profileDefaultSubtitle;

  /// Shuffle personality option: Explorer
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get profileExplorer;

  /// Subtitle for the Explorer shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Prioritizes new & rare songs'**
  String get profileExplorerSubtitle;

  /// Shuffle personality option: Consistent
  ///
  /// In en, this message translates to:
  /// **'Consistent'**
  String get profileConsistent;

  /// Subtitle for the Consistent shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Favorites heavy'**
  String get profileConsistentSubtitle;

  /// Subtitle for the Custom shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Configure your own shuffle'**
  String get profileCustomSubtitle;

  /// Title of the change display name dialog
  ///
  /// In en, this message translates to:
  /// **'Change Display Name'**
  String get profileChangeName;

  /// Hint text for the new name field
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get profileNewNameHint;

  /// Update label shared by the profile name dialog and the downgrade warning
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get profileUpdate;

  /// Snackbar shown after updating the display name
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get profileNameUpdated;

  /// Subtitle showing the current display name
  ///
  /// In en, this message translates to:
  /// **'Current: {name}'**
  String profileCurrentName(String name);

  /// Snackbar shown after saving the shuffle personality
  ///
  /// In en, this message translates to:
  /// **'Personality saved'**
  String get profilePersonalitySaved;

  /// Note that the personality applies to the next queue
  ///
  /// In en, this message translates to:
  /// **'Applies to the next queue'**
  String get profileAppliesNextQueue;

  /// Row title to configure custom shuffle
  ///
  /// In en, this message translates to:
  /// **'Configure Custom Shuffle'**
  String get profileConfigureCustomShuffle;

  /// Subtitle for the custom shuffle configuration row
  ///
  /// In en, this message translates to:
  /// **'Adjust shuffle behavior settings'**
  String get profileConfigureCustomShuffleSubtitle;

  /// Subtitle for the settings entry on the profile screen
  ///
  /// In en, this message translates to:
  /// **'Theme & storage'**
  String get profileThemeStorage;

  /// Label for the low discovery level
  ///
  /// In en, this message translates to:
  /// **'Familiar'**
  String get profileFamiliar;

  /// Label for the high discovery level
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get profileDiscover;

  /// Title for the discovery level slider
  ///
  /// In en, this message translates to:
  /// **'Familiar to Discover'**
  String get profileFamiliarToDiscover;

  /// Caption shown under the Legacy shuffle personality option in the profile screen
  ///
  /// In en, this message translates to:
  /// **'Legacy: fixed behaviour, kept for compatibility'**
  String get profileLegacyCaption;

  /// Title of the Manage Storage screen and its settings entry
  ///
  /// In en, this message translates to:
  /// **'Manage Storage'**
  String get storageManageTitle;

  /// Title of the repair library links card on the storage management screen
  ///
  /// In en, this message translates to:
  /// **'Repair Library Links'**
  String get storageRepairCardTitle;

  /// Body of the repair library links card on the storage management screen
  ///
  /// In en, this message translates to:
  /// **'Missing album art after a restore or a new phone? This re-links artwork and file paths.'**
  String get storageRepairCardBody;

  /// Confirm button label for the repair library links dialog
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get storageRepair;

  /// Title of the repair library links confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Repair Library Links?'**
  String get storageRepairTitle;

  /// Body of the repair library links confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This re-links cached album art and file paths to where they actually are on this device.\n\nTracks whose files are no longer here will be removed from the library. Favourites, playlists and play counts are kept, and reattach automatically if those files come back.'**
  String get storageRepairBody;

  /// Snackbar shown when repairing library links fails
  ///
  /// In en, this message translates to:
  /// **'Error repairing library: {error}'**
  String storageRepairError(Object error);

  /// Database label shared by the storage usage list and the restore dialog section
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get storageDatabaseTitle;

  /// Subtitle for the Database row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'User data, statistics, and settings'**
  String get storageDatabaseSubtitle;

  /// Cover Cache label shared by the storage usage list, backup options, and backup settings
  ///
  /// In en, this message translates to:
  /// **'Cover Cache'**
  String get storageCoverCacheTitle;

  /// Subtitle for the Cover Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Cached song album art'**
  String get storageCoverCacheSubtitle;

  /// Title for the Backups row in the storage usage list and settings
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get storageBackupsTitle;

  /// Subtitle for the Backups row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Local backup files'**
  String get storageBackupsSubtitle;

  /// Library Cache label shared by the storage usage list, backup options, and backup settings
  ///
  /// In en, this message translates to:
  /// **'Library Cache'**
  String get storageLibraryCacheTitle;

  /// Subtitle for the Library Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Cached song library data'**
  String get storageLibraryCacheSubtitle;

  /// Search Index label shared by the storage usage list, backup options, and backup settings
  ///
  /// In en, this message translates to:
  /// **'Search Index'**
  String get storageSearchIndexTitle;

  /// Subtitle for the Search Index row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Search index for fast queries'**
  String get storageSearchIndexSubtitle;

  /// Waveform Cache label shared by the storage usage list, backup options, and backup settings
  ///
  /// In en, this message translates to:
  /// **'Waveform Cache'**
  String get storageWaveformCacheTitle;

  /// Subtitle for the Waveform Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Cached song waveforms for visualizers'**
  String get storageWaveformCacheSubtitle;

  /// Title for the Beat Analysis row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Beat Analysis'**
  String get storageBeatAnalysisTitle;

  /// Subtitle for the Beat Analysis row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Cached beat maps for the reactive player'**
  String get storageBeatAnalysisSubtitle;

  /// Color Cache label shared by the storage usage list, backup options, and backup settings
  ///
  /// In en, this message translates to:
  /// **'Color Cache'**
  String get storageColorCacheTitle;

  /// Subtitle for the Color Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Cached theme colors from album art'**
  String get storageColorCacheSubtitle;

  /// Lyrics Cache label shared by the storage usage list, backup options, and backup settings
  ///
  /// In en, this message translates to:
  /// **'Lyrics Cache'**
  String get storageLyricsCacheTitle;

  /// Subtitle for the Lyrics Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Cached lyrics availability and text'**
  String get storageLyricsCacheSubtitle;

  /// Title for the Blurred Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Blurred Cache'**
  String get storageBlurredCacheTitle;

  /// Subtitle for the Blurred Cache row in the storage usage list
  ///
  /// In en, this message translates to:
  /// **'Pre-generated blurred backgrounds'**
  String get storageBlurredCacheSubtitle;

  /// Confirm button label for clearing a cache (library, waveform, beat, etc.)
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get storageClearCache;

  /// Title of the clear database confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Database?'**
  String get storageClearDatabaseTitle;

  /// Body of the clear database confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your user data, including:\n\n• All playlists\n• Favorites and hidden songs\n• Playback statistics\n• App settings and preferences\n\nThe app will reset. This action cannot be undone.'**
  String get storageClearDatabaseBody;

  /// Confirm button label for clearing the database
  ///
  /// In en, this message translates to:
  /// **'Clear Database'**
  String get storageClearDatabaseAction;

  /// Snackbar shown when clearing the database fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing database: {error}'**
  String storageClearDatabaseError(Object error);

  /// Title of the clear cover cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Cover Cache?'**
  String get storageClearCoversTitle;

  /// Body of the clear cover cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached album artwork.\n\nThe covers will be re-extracted from your music files the next time you browse your library.'**
  String get storageClearCoversBody;

  /// Confirm button label for clearing the cover cache
  ///
  /// In en, this message translates to:
  /// **'Clear Covers'**
  String get storageClearCoversAction;

  /// Snackbar shown when the cover cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Cover cache cleared successfully'**
  String get storageClearCoversSuccess;

  /// Snackbar shown when clearing the cover cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing covers: {error}'**
  String storageClearCoversError(Object error);

  /// Title of the clear backups confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Backups?'**
  String get storageClearBackupsTitle;

  /// Body of the clear backups confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete all local backup files.\n\nMake sure you have exported any important backups before proceeding.'**
  String get storageClearBackupsBody;

  /// Confirm button label for clearing backups
  ///
  /// In en, this message translates to:
  /// **'Clear Backups'**
  String get storageClearBackupsAction;

  /// Snackbar shown when backups are cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Backups cleared successfully'**
  String get storageClearBackupsSuccess;

  /// Snackbar shown when clearing backups fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing backups: {error}'**
  String storageClearBackupsError(Object error);

  /// Title of the clear library cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Library Cache?'**
  String get storageClearLibraryTitle;

  /// Body of the clear library cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will clear the library cache.\n\nYour music library will be rescanned the next time you open the app.'**
  String get storageClearLibraryBody;

  /// Snackbar shown when the library cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Library cache cleared successfully'**
  String get storageClearLibrarySuccess;

  /// Snackbar shown when clearing the library cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing library cache: {error}'**
  String storageClearLibraryError(Object error);

  /// Title of the clear search index confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Search Index?'**
  String get storageClearSearchTitle;

  /// Body of the clear search index confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete the search index.\n\nThe search index will be rebuilt automatically when you rescan your library.'**
  String get storageClearSearchBody;

  /// Confirm button label for clearing the search index
  ///
  /// In en, this message translates to:
  /// **'Clear Index'**
  String get storageClearSearchAction;

  /// Snackbar shown when the search index is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Search index cleared successfully'**
  String get storageClearSearchSuccess;

  /// Snackbar shown when clearing the search index fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing search index: {error}'**
  String storageClearSearchError(Object error);

  /// Title of the clear waveform cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Waveform Cache?'**
  String get storageClearWaveformTitle;

  /// Body of the clear waveform cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached song waveforms.\n\nWaveforms will be regenerated the next time you view song details.'**
  String get storageClearWaveformBody;

  /// Snackbar shown when the waveform cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Waveform cache cleared successfully'**
  String get storageClearWaveformSuccess;

  /// Snackbar shown when clearing the waveform cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing waveform cache: {error}'**
  String storageClearWaveformError(Object error);

  /// Title of the clear beat analysis confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Beat Analysis?'**
  String get storageClearBeatTitle;

  /// Body of the clear beat analysis confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete the cached beat maps used by the beat-reactive player.\n\nThey are rebuilt automatically the next time each song plays.'**
  String get storageClearBeatBody;

  /// Snackbar shown when beat analysis cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Beat analysis cache cleared successfully'**
  String get storageClearBeatSuccess;

  /// Snackbar shown when clearing beat analysis cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing beat analysis cache: {error}'**
  String storageClearBeatError(Object error);

  /// Title of the clear color cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Color Cache?'**
  String get storageClearColorTitle;

  /// Body of the clear color cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete all cached theme colors.\n\nColors will be re-extracted from album art the next time songs are played.'**
  String get storageClearColorBody;

  /// Snackbar shown when the color cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Color cache cleared successfully'**
  String get storageClearColorSuccess;

  /// Snackbar shown when clearing the color cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing color cache: {error}'**
  String storageClearColorError(Object error);

  /// Title of the clear lyrics cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Lyrics Cache?'**
  String get storageClearLyricsTitle;

  /// Body of the clear lyrics cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will remove cached lyrics lookups.\n\nLyrics will be re-read from song metadata when needed.'**
  String get storageClearLyricsBody;

  /// Snackbar shown when the lyrics cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Lyrics cache cleared successfully'**
  String get storageClearLyricsSuccess;

  /// Snackbar shown when clearing the lyrics cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing lyrics cache: {error}'**
  String storageClearLyricsError(Object error);

  /// Title of the clear blurred cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear Blurred Background Cache?'**
  String get storageClearBlurredTitle;

  /// Body of the clear blurred cache confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This will delete all pre-generated blurred backgrounds.\n\nThey will be re-generated the next time you trigger a rebuild in the Indexer.'**
  String get storageClearBlurredBody;

  /// Snackbar shown when the blurred cache is cleared successfully
  ///
  /// In en, this message translates to:
  /// **'Blurred background cache cleared successfully'**
  String get storageClearBlurredSuccess;

  /// Snackbar shown when clearing the blurred cache fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing blurred cache: {error}'**
  String storageClearBlurredError(Object error);

  /// Title of the clear all app data confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Clear All App Data?'**
  String get storageClearAllTitle;

  /// Body of the clear all app data confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This action is dangerous and cannot be undone.\n\nIt will permanently delete:\n• All your preferences and settings\n• Playback statistics and history\n• Cached song covers\n• All local backups\n• Library cache\n• Search index\n• Waveform cache\n• Lyrics cache\n\nThe app will reset.'**
  String get storageClearAllBody;

  /// Confirm button label for clearing all app data
  ///
  /// In en, this message translates to:
  /// **'Clear Everything'**
  String get storageClearAllAction;

  /// Snackbar shown when clearing all app data fails
  ///
  /// In en, this message translates to:
  /// **'Error clearing data: {error}'**
  String storageClearAllError(Object error);

  /// Title row for the clear all user data tile
  ///
  /// In en, this message translates to:
  /// **'Clear All User Data'**
  String get storageClearAllTile;

  /// Subtitle row for the clear all user data tile
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all data and reset app'**
  String get storageClearAllTileSubtitle;

  /// Title of the final confirmation dialog for destructive clears
  ///
  /// In en, this message translates to:
  /// **'Final Confirmation'**
  String get storageFinalConfirmTitle;

  /// Prompt instructing the user to type the confirmation keyword
  ///
  /// In en, this message translates to:
  /// **'To confirm, type \"{word}\" below:'**
  String storageConfirmTypePrompt(Object word);

  /// Keyword the user must type to confirm a destructive clear (DELETE)
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get storageDeleteKeyword;

  /// Confirm button label in the final confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'CONFIRM'**
  String get storageConfirmUpper;

  /// Error message when the typed confirmation text does not match
  ///
  /// In en, this message translates to:
  /// **'Please type the confirmation text exactly.'**
  String get storageTypeExactly;

  /// Formatted byte size string (bytes)
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String storageSizeBytes(Object value);

  /// Formatted kilobyte size string
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String storageSizeKb(Object value);

  /// Formatted megabyte size string
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String storageSizeMb(Object value);

  /// Formatted gigabyte size string
  ///
  /// In en, this message translates to:
  /// **'{value} GB'**
  String storageSizeGb(Object value);

  /// Subtitle for the Indexer settings entry
  ///
  /// In en, this message translates to:
  /// **'Rebuild indexes and caches'**
  String get settingsSearchIndexerSubtitle;

  /// Title for the Music Folders settings entry and screen
  ///
  /// In en, this message translates to:
  /// **'Music Folders'**
  String get settingsSearchMusicFoldersTitle;

  /// Subtitle for the Music Folders settings entry
  ///
  /// In en, this message translates to:
  /// **'Manage music library folders'**
  String get settingsSearchMusicFoldersSubtitle;

  /// Title for the Re-scan Library settings entry
  ///
  /// In en, this message translates to:
  /// **'Re-scan Library Now'**
  String get settingsSearchRescanTitle;

  /// Subtitle for the Re-scan Library settings entry
  ///
  /// In en, this message translates to:
  /// **'Manually refresh all songs from disk'**
  String get settingsSearchRescanSubtitle;

  /// Title for the Include Videos settings switch
  ///
  /// In en, this message translates to:
  /// **'Include Videos'**
  String get settingsSearchIncludeVideosTitle;

  /// Subtitle for the Include Videos settings switch
  ///
  /// In en, this message translates to:
  /// **'Show video files in your song library'**
  String get settingsSearchIncludeVideosSubtitle;

  /// Title for the Minimum File Size settings slider
  ///
  /// In en, this message translates to:
  /// **'Minimum File Size'**
  String get settingsSearchMinFileSizeTitle;

  /// Subtitle for the Minimum File Size settings slider
  ///
  /// In en, this message translates to:
  /// **'Ignore files smaller than this'**
  String get settingsSearchMinFileSizeSubtitle;

  /// Title for the Minimum Duration settings slider
  ///
  /// In en, this message translates to:
  /// **'Minimum Duration'**
  String get settingsSearchMinDurationTitle;

  /// Subtitle for the Minimum Duration settings slider
  ///
  /// In en, this message translates to:
  /// **'Ignore tracks shorter than this'**
  String get settingsSearchMinDurationSubtitle;

  /// Search-result title for the Manage music folders entry
  ///
  /// In en, this message translates to:
  /// **'Manage music folders'**
  String get settingsSearchManageFoldersTitle;

  /// Search-result subtitle for the Manage music folders entry
  ///
  /// In en, this message translates to:
  /// **'Add, remove and rescan individual folders'**
  String get settingsSearchManageFoldersSubtitle;

  /// Title of the Pull to Refresh switch row in Library settings
  ///
  /// In en, this message translates to:
  /// **'Pull to Refresh'**
  String get settingsSearchPullToRefreshTitle;

  /// Subtitle of the Pull to Refresh switch row in Library settings
  ///
  /// In en, this message translates to:
  /// **'Swipe down to refresh the library'**
  String get settingsSearchPullToRefreshSubtitle;

  /// Title of the Auto-Pause on Mute switch row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Auto-Pause on Mute'**
  String get settingsSearchAutoPauseMuteTitle;

  /// Subtitle of the Auto-Pause on Mute switch row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Pause playback when volume reaches 0'**
  String get settingsSearchAutoPauseMuteSubtitle;

  /// Title of the Auto-Resume on Unmute switch row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Auto-Resume on Unmute'**
  String get settingsSearchAutoResumeUnmuteTitle;

  /// Subtitle of the Auto-Resume on Unmute switch row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Resume playback when volume is restored'**
  String get settingsSearchAutoResumeUnmuteSubtitle;

  /// Title of the Gap / Delay slider row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Gap / Delay'**
  String get settingsSearchGapTitle;

  /// Search-result subtitle for the Gap / Delay setting
  ///
  /// In en, this message translates to:
  /// **'Silence between tracks'**
  String get settingsSearchGapSubtitle;

  /// Title of the Fade Out slider row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Fade Out'**
  String get settingsSearchFadeOutTitle;

  /// Search-result subtitle for the Fade Out setting
  ///
  /// In en, this message translates to:
  /// **'Fade the outgoing track'**
  String get settingsSearchFadeOutSubtitle;

  /// Title of the Fade In slider row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Fade In'**
  String get settingsSearchFadeInTitle;

  /// Search-result subtitle for the Fade In setting
  ///
  /// In en, this message translates to:
  /// **'Fade the incoming track'**
  String get settingsSearchFadeInSubtitle;

  /// Title of the Fade on Play row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Fade on Play'**
  String get settingsSearchFadePlayTitle;

  /// Search-result subtitle for the Fade on Play setting
  ///
  /// In en, this message translates to:
  /// **'Ease the volume up when playback starts'**
  String get settingsSearchFadePlaySubtitle;

  /// Title of the Fade on Pause row in Playback settings
  ///
  /// In en, this message translates to:
  /// **'Fade on Pause'**
  String get settingsSearchFadePauseTitle;

  /// Search-result subtitle for the Fade on Pause setting
  ///
  /// In en, this message translates to:
  /// **'Ease the volume down when playback stops'**
  String get settingsSearchFadePauseSubtitle;

  /// Search-result subtitle for the Target Language setting
  ///
  /// In en, this message translates to:
  /// **'Language to translate lyrics into'**
  String get settingsSearchTargetLangSubtitle;

  /// Search-result subtitle for the Translation Display setting
  ///
  /// In en, this message translates to:
  /// **'Show subtext below lyrics or replace base lyrics'**
  String get settingsSearchTranslationModeSubtitle;

  /// Search-result subtitle for the Visualizer setting
  ///
  /// In en, this message translates to:
  /// **'Off, classic bars, or bars synced to the song'**
  String get settingsSearchVisualizerSubtitle;

  /// Search-result subtitle for the app Language setting
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get settingsSearchLanguageSubtitle;

  /// Search-result subtitle for the progress bar style setting
  ///
  /// In en, this message translates to:
  /// **'Standard, waveform, or sound-reactive progress bar'**
  String get settingsSearchProgressBarSubtitle;

  /// Title of the Show Song Duration switch row in Home settings
  ///
  /// In en, this message translates to:
  /// **'Show Song Duration'**
  String get settingsSearchSongDurationTitle;

  /// Subtitle of the Show Song Duration switch row in Home settings
  ///
  /// In en, this message translates to:
  /// **'Display duration in song lists'**
  String get settingsSearchSongDurationSubtitle;

  /// Title of the Auto-Hide Bars switch row in Home settings
  ///
  /// In en, this message translates to:
  /// **'Auto-Hide Bars'**
  String get settingsSearchAutoHideBarsTitle;

  /// Search-result subtitle for the Auto-Hide Bars setting
  ///
  /// In en, this message translates to:
  /// **'Header and bottom dock hide on downward scroll'**
  String get settingsSearchAutoHideBarsSubtitle;

  /// Search-result subtitle for the App Icon setting
  ///
  /// In en, this message translates to:
  /// **'Choose which icon wispie uses'**
  String get settingsSearchAppIconSubtitle;

  /// Search-result subtitle for the Beat Cover setting
  ///
  /// In en, this message translates to:
  /// **'Album art pulses with the beat (classic player only)'**
  String get settingsSearchBeatCoverSubtitle;

  /// Search-result subtitle for the Spin Artwork setting
  ///
  /// In en, this message translates to:
  /// **'Artwork turns in the minimized bottom bar while a song plays'**
  String get settingsSearchSpinArtworkSubtitle;

  /// Search-result subtitle for the Cover Intensity setting
  ///
  /// In en, this message translates to:
  /// **'How strongly the album art reacts to the beat'**
  String get settingsSearchCoverIntensitySubtitle;

  /// Search-result subtitle for the Particle Density setting
  ///
  /// In en, this message translates to:
  /// **'How many particles and how lively they are'**
  String get settingsSearchParticleDensitySubtitle;

  /// Search-result subtitle for the Beat Offset setting
  ///
  /// In en, this message translates to:
  /// **'Compensate for Bluetooth output latency'**
  String get settingsSearchBeatOffsetSubtitle;

  /// Subtitle of the Quick Picks home section toggle row
  ///
  /// In en, this message translates to:
  /// **'Show quick pick recommendations'**
  String get settingsSearchQuickPicksSubtitle;

  /// Subtitle of the Recent Queues home section toggle row
  ///
  /// In en, this message translates to:
  /// **'Show recently played queues'**
  String get settingsSearchRecentQueuesSubtitle;

  /// Subtitle of the For You home section toggle row
  ///
  /// In en, this message translates to:
  /// **'Show recommended playlists'**
  String get settingsSearchForYouSubtitle;

  /// Subtitle of the Quick Actions customization row in Home settings
  ///
  /// In en, this message translates to:
  /// **'Customize long-press actions'**
  String get settingsSearchQuickActionsSubtitle;

  /// Search-result title for the Reorder quick actions entry
  ///
  /// In en, this message translates to:
  /// **'Reorder quick actions'**
  String get settingsSearchReorderQuickActionsTitle;

  /// Search-result subtitle for the Reorder quick actions entry
  ///
  /// In en, this message translates to:
  /// **'Choose and order the long-press actions on a song'**
  String get settingsSearchReorderQuickActionsSubtitle;

  /// Title of the Bulk Rename Files row in Library settings
  ///
  /// In en, this message translates to:
  /// **'Bulk Rename Files'**
  String get settingsSearchBulkRenameTitle;

  /// Subtitle of the Bulk Rename Files row in Library settings
  ///
  /// In en, this message translates to:
  /// **'Rename the whole library from a format'**
  String get settingsSearchBulkRenameSubtitle;

  /// Subtitle of the Manage Storage row in Storage settings
  ///
  /// In en, this message translates to:
  /// **'Disk usage and data management'**
  String get settingsSearchManageStorageSubtitle;

  /// Search-result subtitle for the Manage Backups entry
  ///
  /// In en, this message translates to:
  /// **'Browse, restore and delete saved backups'**
  String get settingsSearchBackupsSubtitle;

  /// Search-result subtitle for the Storage Usage entry
  ///
  /// In en, this message translates to:
  /// **'Disk usage by covers, waveforms, lyrics and caches'**
  String get settingsSearchStorageUsageSubtitle;

  /// Breadcrumb path shown under settings search results for the Storage section
  ///
  /// In en, this message translates to:
  /// **'Settings › Storage'**
  String get settingsCrumbStorage;

  /// Breadcrumb path shown under settings search results for the Library section
  ///
  /// In en, this message translates to:
  /// **'Settings › Library'**
  String get settingsCrumbLibrary;

  /// Breadcrumb path shown under settings search results for Library filters
  ///
  /// In en, this message translates to:
  /// **'Settings › Library › Filters'**
  String get settingsCrumbLibraryFilters;

  /// Breadcrumb path shown under settings search results for Music Folders
  ///
  /// In en, this message translates to:
  /// **'Settings › Library › Music Folders'**
  String get settingsCrumbLibraryFolders;

  /// Breadcrumb path shown under settings search results for Library maintenance
  ///
  /// In en, this message translates to:
  /// **'Settings › Library › Maintenance'**
  String get settingsCrumbLibraryMaintenance;

  /// Breadcrumb path shown under settings search results for Playback audio
  ///
  /// In en, this message translates to:
  /// **'Settings › Playback › Audio'**
  String get settingsCrumbPlaybackAudio;

  /// Breadcrumb path shown under settings search results for Playback transitions
  ///
  /// In en, this message translates to:
  /// **'Settings › Playback › Transitions'**
  String get settingsCrumbPlaybackTransitions;

  /// Breadcrumb path shown under settings search results for Playback play and pause
  ///
  /// In en, this message translates to:
  /// **'Settings › Playback › Play / Pause'**
  String get settingsCrumbPlaybackPlayPause;

  /// Breadcrumb path shown under settings search results for Lyrics display and timing
  ///
  /// In en, this message translates to:
  /// **'Settings › Lyrics › Display & Timing'**
  String get settingsCrumbLyricsTiming;

  /// Breadcrumb path shown under settings search results for Lyrics translation
  ///
  /// In en, this message translates to:
  /// **'Settings › Lyrics › Translation'**
  String get settingsCrumbLyricsTranslation;

  /// Breadcrumb path shown under settings search results for Appearance language
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Language'**
  String get settingsCrumbAppearanceLanguage;

  /// Breadcrumb path shown under settings search results for Appearance now playing
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Now Playing'**
  String get settingsCrumbAppearanceNowPlaying;

  /// Breadcrumb path shown under settings search results for Appearance app icon
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › App icon'**
  String get settingsCrumbAppearanceAppIcon;

  /// Breadcrumb path shown under settings search results for Appearance player motion
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Player motion'**
  String get settingsCrumbAppearanceMotion;

  /// Breadcrumb path shown under settings search results for Appearance lists and navigation
  ///
  /// In en, this message translates to:
  /// **'Settings › Appearance › Lists & Navigation'**
  String get settingsCrumbAppearanceLists;

  /// Breadcrumb path shown under settings search results for Home lists and navigation
  ///
  /// In en, this message translates to:
  /// **'Settings › Home & Navigation › Lists & Navigation'**
  String get settingsCrumbHomeLists;

  /// Breadcrumb path shown under settings search results for the Home screen
  ///
  /// In en, this message translates to:
  /// **'Settings › Home & Navigation › Home screen'**
  String get settingsCrumbHomeScreen;

  /// Breadcrumb path shown under settings search results for Backup and Restore
  ///
  /// In en, this message translates to:
  /// **'Settings › Backup & Restore'**
  String get settingsCrumbBackup;

  /// Breadcrumb path shown under settings search results for Automatic Backups
  ///
  /// In en, this message translates to:
  /// **'Settings › Backup & Restore › Automatic Backups'**
  String get settingsCrumbAutoBackups;

  /// Breadcrumb path shown under settings search results for Manage Backups
  ///
  /// In en, this message translates to:
  /// **'Settings › Data Management › Manage Backups'**
  String get settingsCrumbManageBackups;

  /// Breadcrumb path shown under settings search results for Manage Storage
  ///
  /// In en, this message translates to:
  /// **'Settings › Data Management › Manage Storage'**
  String get settingsCrumbManageStorage;

  /// Breadcrumb path shown under settings search results for Profile shuffle
  ///
  /// In en, this message translates to:
  /// **'Profile › Shuffle'**
  String get settingsCrumbProfileShuffle;

  /// Comma-separated extra search keywords for the Library settings page
  ///
  /// In en, this message translates to:
  /// **'scan,folders,filters,songs'**
  String get settingsKwLibrary;

  /// Comma-separated extra search keywords for the Playback settings page
  ///
  /// In en, this message translates to:
  /// **'audio,sound,transitions'**
  String get settingsKwPlayback;

  /// Comma-separated extra search keywords for the Lyrics settings page
  ///
  /// In en, this message translates to:
  /// **'lyrics,translate,karaoke,subtitles'**
  String get settingsKwLyrics;

  /// Comma-separated extra search keywords for the Home and Navigation settings page
  ///
  /// In en, this message translates to:
  /// **'home,quick picks,gestures,bars,layout'**
  String get settingsKwHome;

  /// Comma-separated extra search keywords for the Storage settings page
  ///
  /// In en, this message translates to:
  /// **'disk,space,cache,indexer,cleanup'**
  String get settingsKwStorage;

  /// Comma-separated extra search keywords for the Appearance settings page
  ///
  /// In en, this message translates to:
  /// **'theme,colour,color,display,look'**
  String get settingsKwAppearance;

  /// Comma-separated extra search keywords for the Sync settings page
  ///
  /// In en, this message translates to:
  /// **'cloud,account,devices,encrypted'**
  String get settingsKwSync;

  /// Comma-separated extra search keywords for the Backup and Restore settings page
  ///
  /// In en, this message translates to:
  /// **'backup,restore,export,import,data'**
  String get settingsKwBackup;

  /// Comma-separated extra search keywords for the Indexer page
  ///
  /// In en, this message translates to:
  /// **'index,rebuild,cache,reindex'**
  String get settingsKwIndexer;

  /// Comma-separated extra search keywords for the About settings page
  ///
  /// In en, this message translates to:
  /// **'version,update,changelog,release'**
  String get settingsKwAbout;

  /// Comma-separated extra search keywords for the Music Folders row
  ///
  /// In en, this message translates to:
  /// **'directory,path,add folder,sources'**
  String get settingsKwFolders;

  /// Comma-separated extra search keywords for the Rescan row
  ///
  /// In en, this message translates to:
  /// **'refresh,reload,sync'**
  String get settingsKwRescan;

  /// Comma-separated extra search keywords for the Include Videos row
  ///
  /// In en, this message translates to:
  /// **'video,mp4,clips'**
  String get settingsKwVideos;

  /// Comma-separated extra search keywords for the Minimum File Size row
  ///
  /// In en, this message translates to:
  /// **'size,skip,small,filter'**
  String get settingsKwMinFileSize;

  /// Comma-separated extra search keywords for the Minimum Duration row
  ///
  /// In en, this message translates to:
  /// **'length,short,skip,filter,interlude'**
  String get settingsKwMinDuration;

  /// Comma-separated extra search keywords for the Manage music folders entry
  ///
  /// In en, this message translates to:
  /// **'folder,directory,storage,sd card'**
  String get settingsKwManageFolders;

  /// Comma-separated extra search keywords for the Pull to Refresh row
  ///
  /// In en, this message translates to:
  /// **'swipe,gesture,reload'**
  String get settingsKwPullToRefresh;

  /// Comma-separated extra search keywords for the Auto-Pause on Mute row
  ///
  /// In en, this message translates to:
  /// **'volume,silent,mute'**
  String get settingsKwMute;

  /// Comma-separated extra search keywords for the Auto-Resume on Unmute row
  ///
  /// In en, this message translates to:
  /// **'volume,unmute,continue'**
  String get settingsKwUnmute;

  /// Comma-separated extra search keywords for the Gap / Delay row
  ///
  /// In en, this message translates to:
  /// **'pause,silence,between,transition'**
  String get settingsKwGap;

  /// Comma-separated search keywords for the Fade In and Fade Out settings entries
  ///
  /// In en, this message translates to:
  /// **'crossfade,gapless,transition,blend'**
  String get settingsKwCrossfade;

  /// Comma-separated search keywords for the Fade on Play setting
  ///
  /// In en, this message translates to:
  /// **'ramp,volume,start'**
  String get settingsKwFadePlay;

  /// Comma-separated search keywords for the Fade on Pause setting
  ///
  /// In en, this message translates to:
  /// **'ramp,volume,stop'**
  String get settingsKwFadePause;

  /// Comma-separated search keywords for the Simulate Word Sync setting
  ///
  /// In en, this message translates to:
  /// **'lyrics,richsync,karaoke,word,sync'**
  String get settingsKwRichSync;

  /// Comma-separated search keywords for the Lyrics and Queue Sidebar setting
  ///
  /// In en, this message translates to:
  /// **'sidebar,panel,desktop,queue,lyrics'**
  String get settingsKwSidebar;

  /// Comma-separated search keywords for the Keep Screen Awake on Lyrics setting
  ///
  /// In en, this message translates to:
  /// **'sleep,wakelock,display,lyrics'**
  String get settingsKwKeepAwake;

  /// Comma-separated search keywords for the Auto-Translate Lyrics setting
  ///
  /// In en, this message translates to:
  /// **'translate,translation,language,lyrics,auto'**
  String get settingsKwAutoTranslate;

  /// Comma-separated search keywords for the Target Language setting
  ///
  /// In en, this message translates to:
  /// **'translate,language,spanish,english,japanese'**
  String get settingsKwTargetLang;

  /// Comma-separated search keywords for the Translation Display setting
  ///
  /// In en, this message translates to:
  /// **'translate,mode,subtext,replace,display'**
  String get settingsKwTranslationMode;

  /// Comma-separated search keywords for the Audio Visualizer setting
  ///
  /// In en, this message translates to:
  /// **'wave,animation,spectrum,bars,sync,bass'**
  String get settingsKwVisualizer;

  /// Comma-separated search keywords for the Language setting
  ///
  /// In en, this message translates to:
  /// **'language,locale,translation,english'**
  String get settingsKwLanguage;

  /// Comma-separated search keywords for the Progress Bar Style setting
  ///
  /// In en, this message translates to:
  /// **'seek,progress,wave,reactive,spectrum'**
  String get settingsKwProgressBar;

  /// Comma-separated search keywords for the Waveform Scrubbing Haptics setting
  ///
  /// In en, this message translates to:
  /// **'vibrate,haptic,feedback,waveform,scrub,seek'**
  String get settingsKwHaptics;

  /// Comma-separated search keywords for the Show Song Duration setting
  ///
  /// In en, this message translates to:
  /// **'length,time,lists'**
  String get settingsKwSongDuration;

  /// Comma-separated search keywords for the Auto-Hide Bars setting
  ///
  /// In en, this message translates to:
  /// **'navigation,dock,header,scroll,hide'**
  String get settingsKwAutoHide;

  /// Comma-separated search keywords for the Player Cover Sizing setting
  ///
  /// In en, this message translates to:
  /// **'artwork,album art,aspect,crop'**
  String get settingsKwCoverSizing;

  /// Comma-separated search keywords for the Immersive Design setting
  ///
  /// In en, this message translates to:
  /// **'immersive,full bleed,player,detail,gradient,cover,design'**
  String get settingsKwImmersive;

  /// Comma-separated search keywords for the App Icon setting
  ///
  /// In en, this message translates to:
  /// **'icon,logo,launcher,dock,classic,new'**
  String get settingsKwAppIcon;

  /// Comma-separated search keywords for the Beat-Reactive Cover setting
  ///
  /// In en, this message translates to:
  /// **'pulse,beat,artwork,motion'**
  String get settingsKwBeatCover;

  /// Comma-separated search keywords for the Spin Artwork While Playing setting
  ///
  /// In en, this message translates to:
  /// **'rotate,turn,spin,artwork,dock,mini'**
  String get settingsKwSpinArtwork;

  /// Comma-separated search keywords for the Beat-Reactive Particles setting
  ///
  /// In en, this message translates to:
  /// **'particles,motes,beat,motion'**
  String get settingsKwBeatParticles;

  /// Comma-separated search keywords for the Cover Intensity setting
  ///
  /// In en, this message translates to:
  /// **'cover,album,pulse,subtle,balanced,bold'**
  String get settingsKwCoverIntensity;

  /// Comma-separated search keywords for the Particle Density setting
  ///
  /// In en, this message translates to:
  /// **'particles,motes,density,subtle,balanced,bold'**
  String get settingsKwParticleDensity;

  /// Comma-separated search keywords for the Beat Sync Offset setting
  ///
  /// In en, this message translates to:
  /// **'bluetooth,latency,delay,sync,early'**
  String get settingsKwBeatOffset;

  /// Comma-separated search keywords for the Calibrate Beat Sync setting
  ///
  /// In en, this message translates to:
  /// **'calibrate,sync,latency,offset,test,click'**
  String get settingsKwCalibrate;

  /// Comma-separated search keywords for the Quick Picks setting
  ///
  /// In en, this message translates to:
  /// **'home,recommendations,suggestions'**
  String get settingsKwQuickPicks;

  /// Comma-separated search keywords for the Recent Queues setting
  ///
  /// In en, this message translates to:
  /// **'home,history,queue'**
  String get settingsKwRecentQueues;

  /// Comma-separated search keywords for the For You setting
  ///
  /// In en, this message translates to:
  /// **'home,mixes,recommendations'**
  String get settingsKwForYou;

  /// Comma-separated search keywords for the Quick Actions setting
  ///
  /// In en, this message translates to:
  /// **'long press,menu,shortcuts'**
  String get settingsKwQuickActions;

  /// Comma-separated search keywords for the Reorder Quick Actions setting
  ///
  /// In en, this message translates to:
  /// **'long press,order,menu,shortcuts'**
  String get settingsKwReorderQuickActions;

  /// Comma-separated search keywords for the Export App Data setting
  ///
  /// In en, this message translates to:
  /// **'backup,save,export'**
  String get settingsKwExport;

  /// Comma-separated search keywords for the Import App Data setting
  ///
  /// In en, this message translates to:
  /// **'restore,load,import'**
  String get settingsKwImport;

  /// Comma-separated search keywords for the Manage Backups setting
  ///
  /// In en, this message translates to:
  /// **'backup,restore,delete'**
  String get settingsKwManageBackups;

  /// Comma-separated search keywords for the Bulk Rename Files setting
  ///
  /// In en, this message translates to:
  /// **'rename,filenames,batch,bulk,format,naming'**
  String get settingsKwBulkRename;

  /// Comma-separated search keywords for the Manage Storage setting
  ///
  /// In en, this message translates to:
  /// **'disk,space,cache,cleanup'**
  String get settingsKwManageStorage;

  /// Comma-separated search keywords for the Backups setting
  ///
  /// In en, this message translates to:
  /// **'backup,restore,archive'**
  String get settingsKwBackups;

  /// Comma-separated search keywords for the Storage settings page
  ///
  /// In en, this message translates to:
  /// **'disk,space,clear cache,usage'**
  String get settingsKwStorageUsage;

  /// Comma-separated search keywords for the Auto Backup setting
  ///
  /// In en, this message translates to:
  /// **'schedule,frequency,automatic'**
  String get settingsKwAutoBackup;

  /// Comma-separated search keywords for the Auto Backup Content setting
  ///
  /// In en, this message translates to:
  /// **'contents,categories,automatic'**
  String get settingsKwAutoBackupContent;

  /// Comma-separated search keywords for the Auto-Delete Old Backups setting
  ///
  /// In en, this message translates to:
  /// **'prune,cleanup,retention,old'**
  String get settingsKwAutoDelete;

  /// Comma-separated search keywords for the Configure Custom Shuffle setting
  ///
  /// In en, this message translates to:
  /// **'shuffle,personality,weights,random,explorer'**
  String get settingsKwShuffle;

  /// Folder access error shared by setup, folder management, and home
  ///
  /// In en, this message translates to:
  /// **'Unable to access selected folder'**
  String get setupUnableToAccessFolder;

  /// Snackbar shown when storage permission is required to scan the library
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to scan your music library.'**
  String get setupStoragePermissionRequired;

  /// Snackbar prompting the user to enter a display name
  ///
  /// In en, this message translates to:
  /// **'Please enter a display name'**
  String get setupEnterDisplayName;

  /// Snackbar shown when setup fails, including the error message
  ///
  /// In en, this message translates to:
  /// **'Setup error: {error}'**
  String setupSetupError(String error);

  /// Tagline shown on the intro screen of first-run setup
  ///
  /// In en, this message translates to:
  /// **'Your music stays on your device.'**
  String get setupIntroTagline;

  /// Label for the Get Started button on the setup intro screen
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get setupGetStarted;

  /// Tooltip for the previous step button in setup
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get setupPreviousStep;

  /// Label shown while setup is finishing
  ///
  /// In en, this message translates to:
  /// **'Setting things up'**
  String get setupSettingThingsUp;

  /// Label for the button that starts listening after setup completes
  ///
  /// In en, this message translates to:
  /// **'Start listening'**
  String get setupStartListening;

  /// Continue label shared by setup and the sync recovery-key flow
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// Title of the name step in first-run setup
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get setupNameTitle;

  /// Subtitle of the name step in first-run setup
  ///
  /// In en, this message translates to:
  /// **'wispie uses your name to greet you and to sign your listening history. Nothing leaves this device either way.'**
  String get setupNameSubtitle;

  /// Hint text in the name input field during setup
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get setupNameHint;

  /// Greeting shown after the user enters a name during setup
  ///
  /// In en, this message translates to:
  /// **'Nice to meet you, {name}.'**
  String setupGreeting(String name);

  /// Title of the appearance step in first-run setup
  ///
  /// In en, this message translates to:
  /// **'Make it look the way you like.'**
  String get setupAppearanceTitle;

  /// Subtitle of the appearance step in first-run setup
  ///
  /// In en, this message translates to:
  /// **'Everything on this page also lives in Settings, so you can change it whenever you want.'**
  String get setupAppearanceSubtitle;

  /// Subtitle for the immersive design toggle in setup appearance step
  ///
  /// In en, this message translates to:
  /// **'A full-bleed cover player and gradient detail screens.'**
  String get setupImmersiveSubtitle;

  /// Subtitle for the audio visualizer toggle in setup appearance step
  ///
  /// In en, this message translates to:
  /// **'Bars over the artwork while you listen. Synced follows the song rather than a random pattern.'**
  String get setupVisualizerSubtitle;

  /// Subtitle for the beat-reactive cover toggle in setup appearance step
  ///
  /// In en, this message translates to:
  /// **'The album art breathes on every beat.'**
  String get setupBeatCoverSubtitle;

  /// Subtitle for the beat-reactive particles toggle in setup appearance step
  ///
  /// In en, this message translates to:
  /// **'Motes drift across the player, and each beat carries them further instead of just blinking them.'**
  String get setupParticlesSubtitle;

  /// Title for the progress bar style option in setup appearance step
  ///
  /// In en, this message translates to:
  /// **'Progress bar'**
  String get setupProgressBarTitle;

  /// Subtitle for the progress bar style option in setup appearance step
  ///
  /// In en, this message translates to:
  /// **'Draw the song itself as a waveform instead of a plain line. Sound reactive makes it move as it plays.'**
  String get setupProgressBarSubtitle;

  /// Title of the music folders step in first-run setup
  ///
  /// In en, this message translates to:
  /// **'Where is your music?'**
  String get setupFoldersTitle;

  /// Subtitle of the music folders step in first-run setup
  ///
  /// In en, this message translates to:
  /// **'Point wispie at the folders your songs live in. It only reads them, and you can add as many as you like.'**
  String get setupFoldersSubtitle;

  /// Title for the storage permission card in setup
  ///
  /// In en, this message translates to:
  /// **'Storage permission'**
  String get setupStoragePermissionTitle;

  /// Subtitle for the storage permission card in setup
  ///
  /// In en, this message translates to:
  /// **'wispie needs it to find audio files on this device.'**
  String get setupStoragePermissionSubtitle;

  /// Label for the button opening system settings to grant permission
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get setupOpenSystemSettings;

  /// Label for the button granting storage permission
  ///
  /// In en, this message translates to:
  /// **'Grant permission'**
  String get setupGrantPermission;

  /// Title shown when no music folders have been added in setup
  ///
  /// In en, this message translates to:
  /// **'No folders yet'**
  String get setupNoFoldersTitle;

  /// Subtitle shown when no music folders have been added in setup
  ///
  /// In en, this message translates to:
  /// **'Add the one that holds your songs.'**
  String get setupNoFoldersSubtitle;

  /// Tooltip for the remove folder button in setup and folder management
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get setupRemoveFolderTooltip;

  /// Label for the add folder button in setup
  ///
  /// In en, this message translates to:
  /// **'Add a folder'**
  String get setupAddFolder;

  /// Label for the music folders count in the setup summary
  ///
  /// In en, this message translates to:
  /// **'Music folders'**
  String get setupSummaryMusicFolders;

  /// Title of the ready and summary step in setup
  ///
  /// In en, this message translates to:
  /// **'You are all set.'**
  String get setupReadyTitle;

  /// Title of the ready step personalized with the user's name
  ///
  /// In en, this message translates to:
  /// **'You are all set, {name}.'**
  String setupReadyTitleNamed(String name);

  /// Subtitle of the ready step in setup
  ///
  /// In en, this message translates to:
  /// **'Here is what we set up. You can change any of it later from Settings.'**
  String get setupReadySubtitle;

  /// On toggle label used in setup
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get setupOn;

  /// Off label shared by setup toggles, visualizer options, and playback value readouts
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get setupOff;

  /// Snackbar shown when loading backups fails, including the error
  ///
  /// In en, this message translates to:
  /// **'Error loading backups: {error}'**
  String backupLoadError(Object error);

  /// Snackbar shown after a backup is created, including its filename
  ///
  /// In en, this message translates to:
  /// **'Backup created: {name}'**
  String backupCreated(Object name);

  /// Snackbar shown when backup creation fails, including the error
  ///
  /// In en, this message translates to:
  /// **'Failed to create backup: {error}'**
  String backupCreateFailed(Object error);

  /// Snackbar shown when backup validation fails, including the error
  ///
  /// In en, this message translates to:
  /// **'Failed to validate backup: {error}'**
  String backupValidateFailed(Object error);

  /// Title of the full data replace confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'DANGER: Full Data Replace'**
  String get backupReplaceTitle;

  /// Confirmation prompt naming the backup being restored
  ///
  /// In en, this message translates to:
  /// **'Are you absolutely sure you want to restore from {name}?'**
  String backupReplaceConfirm(Object name);

  /// Warning heading listing the data that will be replaced
  ///
  /// In en, this message translates to:
  /// **'WARNING: This will COMPLETELY REPLACE all your current data:'**
  String get backupReplaceWarning;

  /// Bullet listing statistics and play history to be replaced
  ///
  /// In en, this message translates to:
  /// **'• All your current statistics and play history'**
  String get backupReplaceItemStats;

  /// Bullet listing favorites and playlists to be replaced
  ///
  /// In en, this message translates to:
  /// **'• All your favorites and playlists'**
  String get backupReplaceItemFavorites;

  /// Bullet listing hidden songs and preferences to be replaced
  ///
  /// In en, this message translates to:
  /// **'• All your hidden songs and preferences'**
  String get backupReplaceItemHidden;

  /// Bullet listing settings and state to be replaced
  ///
  /// In en, this message translates to:
  /// **'• All your current settings and state'**
  String get backupReplaceItemSettings;

  /// Bullet listing the scanned song library to be replaced
  ///
  /// In en, this message translates to:
  /// **'• Your scanned song library'**
  String get backupReplaceItemLibrary;

  /// Note about re-linking album art and file paths after restore
  ///
  /// In en, this message translates to:
  /// **'Album art and file paths are re-linked to this device automatically after the restore. Tracks in the backup whose files are not on this device are removed from the library.'**
  String get backupReplaceRekeyNote;

  /// Warning that current data will be permanently lost
  ///
  /// In en, this message translates to:
  /// **'YOUR CURRENT DATA WILL BE PERMANENTLY LOST!'**
  String get backupReplaceIrreversible;

  /// Warning that the replace action cannot be undone
  ///
  /// In en, this message translates to:
  /// **'There is NO way to undo this action.'**
  String get backupReplaceNoUndo;

  /// Label for the confirm replace everything button
  ///
  /// In en, this message translates to:
  /// **'YES, REPLACE EVERYTHING'**
  String get backupReplaceConfirmAction;

  /// Label shown while restoring a backup
  ///
  /// In en, this message translates to:
  /// **'Restoring data…'**
  String get backupRestoringLabel;

  /// Snackbar shown after a successful backup restore
  ///
  /// In en, this message translates to:
  /// **'All data replaced successfully!'**
  String get backupRestoreSuccess;

  /// Snackbar shown when backup restore fails, including the error
  ///
  /// In en, this message translates to:
  /// **'Failed to restore backup: {error}'**
  String backupRestoreFailed(Object error);

  /// Title of the dialog confirming deletion of a backup
  ///
  /// In en, this message translates to:
  /// **'Delete Backup'**
  String get backupDeleteTitle;

  /// Confirmation message asking whether to delete a named backup
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String backupDeleteConfirm(Object name);

  /// Uppercase label for the delete button in the delete-backup dialog
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get backupDeleteUpper;

  /// Snackbar message shown after a backup is deleted
  ///
  /// In en, this message translates to:
  /// **'Backup deleted'**
  String get backupDeleted;

  /// Snackbar message shown when deleting a backup fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete backup: {error}'**
  String backupDeleteFailed(Object error);

  /// Snackbar message showing the path a backup was exported to
  ///
  /// In en, this message translates to:
  /// **'Backup exported to: {path}'**
  String backupExportedTo(Object path);

  /// Snackbar shown when there is no older backup to compare against
  ///
  /// In en, this message translates to:
  /// **'No older backup to compare with.'**
  String get backupNoOlderBackup;

  /// Loading label shown while comparing two backups
  ///
  /// In en, this message translates to:
  /// **'Comparing backups...'**
  String get backupComparing;

  /// Title of the backup comparison dialog referencing the older backup number
  ///
  /// In en, this message translates to:
  /// **'Comparison with #{number}'**
  String backupComparisonTitle(int number);

  /// Row label for stats rows difference in backup comparison
  ///
  /// In en, this message translates to:
  /// **'Stats Rows'**
  String get backupDiffStatsRows;

  /// Row label for size difference in backup comparison
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get backupDiffSize;

  /// Title for the data-added row in backup comparison
  ///
  /// In en, this message translates to:
  /// **'Data Added'**
  String get backupDiffDataAdded;

  /// Uppercase label for the close button in the backup comparison dialog
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get backupCloseUpper;

  /// Snackbar shown when comparing backups fails
  ///
  /// In en, this message translates to:
  /// **'Error comparing backups: {error}'**
  String backupCompareError(Object error);

  /// Text shown when a compared value is unchanged
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get backupNoChange;

  /// Title of the backup management screen
  ///
  /// In en, this message translates to:
  /// **'Backup Management'**
  String get backupManagementTitle;

  /// Button label shown while a backup is being created
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get backupCreating;

  /// Create Backup label shared by the backup management button and the create-backup dialog title
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get backupCreateAction;

  /// Title shown when no backups exist yet
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupEmptyTitle;

  /// Subtitle shown when no backups exist yet
  ///
  /// In en, this message translates to:
  /// **'Create your first backup to protect your data'**
  String get backupEmptySubtitle;

  /// Label showing a backup's file size
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String backupSizeLabel(Object size);

  /// Restore label shared by backup management and the restore dialog
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupActionRestore;

  /// Action label to compare a backup with the previous one
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get backupActionCompare;

  /// Restart Required title shared by backup restore and indexer restart dialogs
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get backupRestartTitle;

  /// Message explaining a restart is needed after backup restore
  ///
  /// In en, this message translates to:
  /// **'Backup restore has been completed successfully.\n\nThe app needs to restart to apply all changes properly.'**
  String get backupRestartMessage;

  /// Restart Now label shared by backup restore and indexer restart dialogs
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get backupRestartNow;

  /// Subtitle of the create-backup options dialog
  ///
  /// In en, this message translates to:
  /// **'Select content to backup'**
  String get backupSelectContentSubtitle;

  /// Display name for the artist art cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Artist Art Cache'**
  String get backupContentArtistArtCache;

  /// Display name for the album art cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Album Art Cache'**
  String get backupContentAlbumArtCache;

  /// Description for the user stats backup content type
  ///
  /// In en, this message translates to:
  /// **'Play history, stats, merged groups'**
  String get backupContentDescUserStats;

  /// Description for the user data backup content type
  ///
  /// In en, this message translates to:
  /// **'Favorites, playlists, preferences'**
  String get backupContentDescUserData;

  /// Description for the user settings backup content type
  ///
  /// In en, this message translates to:
  /// **'Theme, sort order, app preferences'**
  String get backupContentDescUserSettings;

  /// Description for the cover cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Cached album artwork'**
  String get backupContentDescCoverCache;

  /// Description for the library cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Cached metadata'**
  String get backupContentDescLibraryCache;

  /// Description for the search index backup content type
  ///
  /// In en, this message translates to:
  /// **'Search database'**
  String get backupContentDescSearchIndex;

  /// Description for the waveform cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Waveform data'**
  String get backupContentDescWaveformCache;

  /// Description for the color cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Color palettes'**
  String get backupContentDescColorCache;

  /// Description for the lyrics cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Cached lyrics'**
  String get backupContentDescLyricsCache;

  /// Description for the artist art cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Cached artist images'**
  String get backupContentDescArtistArtCache;

  /// Description for the album art cache backup content type
  ///
  /// In en, this message translates to:
  /// **'Cached album images'**
  String get backupContentDescAlbumArtCache;

  /// Default title of the restore/import progress dialog
  ///
  /// In en, this message translates to:
  /// **'Restoring data'**
  String get backupRestoringDataTitle;

  /// Title of the select-data-to-restore dialog
  ///
  /// In en, this message translates to:
  /// **'Select Data to Restore'**
  String get importSelectTitle;

  /// Section header for cache categories in the restore dialog
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get importSectionCache;

  /// Title of the restore options section
  ///
  /// In en, this message translates to:
  /// **'Restore Options'**
  String get importOptionsTitle;

  /// Checkbox label to replace existing databases before restoring
  ///
  /// In en, this message translates to:
  /// **'Replace Databases'**
  String get importReplaceDatabases;

  /// Subtitle explaining the replace-databases restore option
  ///
  /// In en, this message translates to:
  /// **'Clear existing data before restoring'**
  String get importReplaceDatabasesSubtitle;

  /// Validation message when the password field is empty
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get syncEnterPassword;

  /// Error message when an unexpected authentication error occurs
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String syncAuthUnexpectedError(String error);

  /// Error shown when the chosen username is already taken
  ///
  /// In en, this message translates to:
  /// **'That username is already taken'**
  String get syncUsernameTaken;

  /// Segmented control label for recover mode
  ///
  /// In en, this message translates to:
  /// **'Recover'**
  String get syncModeRecover;

  /// Label for the username text field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get syncUsername;

  /// Warning about end-to-end encryption and key recovery
  ///
  /// In en, this message translates to:
  /// **'Your data is end-to-end encrypted. If you lose both your password and recovery key, it cannot be recovered.'**
  String get syncEncryptionWarning;

  /// Button label shown while securing the account
  ///
  /// In en, this message translates to:
  /// **'Securing your account...'**
  String get syncSecuringAccount;

  /// Button label to create a sync account
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get syncCreateAccount;

  /// Log in label shared by the sync mode segmented control and the log in button
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get syncLogIn;

  /// Button label to recover a sync account
  ///
  /// In en, this message translates to:
  /// **'Recover account'**
  String get syncRecoverAccount;

  /// Button label to hide advanced server settings
  ///
  /// In en, this message translates to:
  /// **'Hide advanced'**
  String get syncHideAdvanced;

  /// Button label to show advanced server settings
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get syncAdvanced;

  /// Snackbar shown after saving the recovery key to a file
  ///
  /// In en, this message translates to:
  /// **'Recovery key saved'**
  String get syncRecoveryKeySaved;

  /// Snackbar shown when saving the recovery key file fails
  ///
  /// In en, this message translates to:
  /// **'Could not save file'**
  String get syncCouldNotSaveFile;

  /// Title of the recovery key reveal card
  ///
  /// In en, this message translates to:
  /// **'Your recovery key'**
  String get syncRecoveryKeyRevealTitle;

  /// Body explaining the recovery key is shown only once
  ///
  /// In en, this message translates to:
  /// **'This is the only way to regain access if you forget your password. It is shown once. Store it somewhere safe.'**
  String get syncRecoveryKeyRevealBody;

  /// Snackbar shown after copying the recovery key
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get syncCopied;

  /// Button label to copy the recovery key
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get syncCopy;

  /// Button label to save the recovery key to a file
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get syncSaveToFile;

  /// Checkbox label confirming the recovery key was saved
  ///
  /// In en, this message translates to:
  /// **'I saved my recovery key'**
  String get syncRecoveryKeySavedCheckbox;

  /// Title when a fresh account uploads library data
  ///
  /// In en, this message translates to:
  /// **'Upload your library data'**
  String get syncUploadTitle;

  /// Title when setting up a device for an existing account
  ///
  /// In en, this message translates to:
  /// **'Set up this device'**
  String get syncSetupDeviceTitle;

  /// Body text for the fresh account upload step
  ///
  /// In en, this message translates to:
  /// **'Auto-sync turns on after your data is uploaded once.'**
  String get syncFreshAccountBody;

  /// Body text for choosing how a device joins cloud data
  ///
  /// In en, this message translates to:
  /// **'Choose how this device joins your cloud data. Auto-sync turns on after this step.'**
  String get syncChooseDeviceBody;

  /// Button to sync all data immediately
  ///
  /// In en, this message translates to:
  /// **'Sync everything now'**
  String get syncEverythingNow;

  /// Button to merge this device with cloud data
  ///
  /// In en, this message translates to:
  /// **'Merge this device with cloud'**
  String get syncMergeWithCloud;

  /// Button to set up this device as new
  ///
  /// In en, this message translates to:
  /// **'Set up as new device'**
  String get syncSetupNewDevice;

  /// Explanation of merging versus setting up as a new device
  ///
  /// In en, this message translates to:
  /// **'Merging keeps both sides. Setting up as a new device erases this device\'s synced data first and is safer if this device already holds an older copy of the same history.'**
  String get syncMergeExplanation;

  /// Title shown when cloud data was replaced by another device
  ///
  /// In en, this message translates to:
  /// **'Cloud data was replaced'**
  String get syncCloudReplacedTitle;

  /// Body explaining sync is paused after cloud replacement
  ///
  /// In en, this message translates to:
  /// **'Another device overwrote the cloud. Sync is paused on this device until you choose.'**
  String get syncCloudReplacedBody;

  /// Button to merge this device into the new cloud data
  ///
  /// In en, this message translates to:
  /// **'Merge this device into the new cloud data'**
  String get syncMergeIntoCloud;

  /// Progress label while signing in
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get syncPhaseSigningIn;

  /// Progress label while checking cloud state
  ///
  /// In en, this message translates to:
  /// **'Checking cloud...'**
  String get syncPhaseCheckingCloud;

  /// Progress label while downloading a backup
  ///
  /// In en, this message translates to:
  /// **'Downloading backup...'**
  String get syncPhaseDownloadingBackup;

  /// Progress label while applying a downloaded backup
  ///
  /// In en, this message translates to:
  /// **'Applying backup...'**
  String get syncPhaseApplyingBackup;

  /// Progress label while downloading changes
  ///
  /// In en, this message translates to:
  /// **'Downloading changes...'**
  String get syncPhaseDownloadingChanges;

  /// Progress label while merging data
  ///
  /// In en, this message translates to:
  /// **'Merging...'**
  String get syncPhaseMerging;

  /// Progress label while preparing an upload
  ///
  /// In en, this message translates to:
  /// **'Preparing upload...'**
  String get syncPhasePreparingUpload;

  /// Progress label while encrypting data
  ///
  /// In en, this message translates to:
  /// **'Encrypting...'**
  String get syncPhaseEncrypting;

  /// Progress label while uploading data
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get syncPhaseUploading;

  /// Progress label while finishing sync
  ///
  /// In en, this message translates to:
  /// **'Finishing up...'**
  String get syncPhaseFinishing;

  /// Progress label shown when sync fails
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncPhaseError;

  /// Fallback progress label when no progress details are available
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncSyncing;

  /// Server info line shown when a reachable sync server allows registration
  ///
  /// In en, this message translates to:
  /// **'{name} - API v{version}'**
  String syncServerInfo(String name, String version);

  /// Server info line shown when sync server registration is closed
  ///
  /// In en, this message translates to:
  /// **'{name} - API v{version} - registration closed'**
  String syncServerInfoClosed(String name, String version);

  /// Error message when a sync server cannot be reached
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server'**
  String get syncServerUnreachable;

  /// Warning shown when sync server URL uses plain HTTP
  ///
  /// In en, this message translates to:
  /// **'Plain http: only use on a trusted private network'**
  String get syncInsecureHttpWarning;

  /// Label for the sync server URL text field
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get syncServerUrl;

  /// Button label while checking a sync server
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get syncChecking;

  /// Button to check the sync server connection
  ///
  /// In en, this message translates to:
  /// **'Check server'**
  String get syncCheckServer;

  /// Button to reset the sync server URL to default
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get syncResetDefault;

  /// Title of the auto-backup in-progress notification
  ///
  /// In en, this message translates to:
  /// **'Backing Up'**
  String get autoBackupRunningTitle;

  /// Subtitle while auto-backup is creating a backup
  ///
  /// In en, this message translates to:
  /// **'Creating backup...'**
  String get autoBackupRunningSubtitle;

  /// Title of the auto-backup success notification
  ///
  /// In en, this message translates to:
  /// **'Auto-Backup Complete'**
  String get autoBackupCompleteTitle;

  /// Fallback subtitle when backup filename is unavailable
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get autoBackupSaved;

  /// Title of the auto-backup failure notification
  ///
  /// In en, this message translates to:
  /// **'Auto-Backup Failed'**
  String get autoBackupFailedTitle;

  /// Title of the auto-backup storage permission prompt
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get autoBackupPermissionTitle;

  /// Subtitle of the auto-backup storage permission prompt
  ///
  /// In en, this message translates to:
  /// **'Auto-backup needs storage access'**
  String get autoBackupPermissionSubtitle;

  /// Button to grant storage permission for auto-backup
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get autoBackupGrant;

  /// Title of the downgrade warning dialog
  ///
  /// In en, this message translates to:
  /// **'Older version detected'**
  String get downgradeTitle;

  /// Warning that data may break when running an older app version
  ///
  /// In en, this message translates to:
  /// **'wispie was last opened on {previousVersion}, but this is {currentVersion}. Your data may have been changed by a newer version and could break or be lost on this one.'**
  String downgradeMessage(String previousVersion, String currentVersion);

  /// Button to quit the app in the downgrade warning
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get downgradeQuit;

  /// Button to proceed despite downgrade risk
  ///
  /// In en, this message translates to:
  /// **'Risk it'**
  String get downgradeRiskIt;

  /// Group header for indexer settings
  ///
  /// In en, this message translates to:
  /// **'Indexer Settings'**
  String get indexerSettingsGroupTitle;

  /// Setting title to hide duplicate tracks across folders
  ///
  /// In en, this message translates to:
  /// **'Prevent Duplicate Tracks'**
  String get indexerPreventDuplicatesTitle;

  /// Subtitle explaining duplicate hiding by filename
  ///
  /// In en, this message translates to:
  /// **'Hide songs with the same filename across folders'**
  String get indexerPreventDuplicatesSubtitle;

  /// Setting title to extract featured artists from titles
  ///
  /// In en, this message translates to:
  /// **'Extract Featured Artists'**
  String get indexerExtractFeaturedTitle;

  /// Subtitle explaining moving ft/feat artists to artist field
  ///
  /// In en, this message translates to:
  /// **'Move \"ft./feat.\" artists from title to artist field'**
  String get indexerExtractFeaturedSubtitle;

  /// Group header for database operations
  ///
  /// In en, this message translates to:
  /// **'Database Operations'**
  String get indexerDatabaseOpsGroupTitle;

  /// Warning that an operation requires an app restart
  ///
  /// In en, this message translates to:
  /// **'This operation requires an app restart to apply changes.'**
  String get indexerWarnRestart;

  /// Group header for cover and search settings
  ///
  /// In en, this message translates to:
  /// **'Cover & Search'**
  String get indexerCoverSearchGroupTitle;

  /// Warning that missing files are removed but user data retained
  ///
  /// In en, this message translates to:
  /// **'Tracks whose files are no longer on this device will be removed from the library. Favourites, playlists and play counts are kept and reattach if the files come back.'**
  String get indexerWarnRepairLinks;

  /// Warning that search index changes may need a restart
  ///
  /// In en, this message translates to:
  /// **'You may need to restart the app for search index changes to fully apply.'**
  String get indexerWarnSearchRestart;

  /// Group header for content caches
  ///
  /// In en, this message translates to:
  /// **'Content Caches'**
  String get indexerContentCachesGroupTitle;

  /// Group header for recommendations
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get indexerRecommendationsGroupTitle;

  /// Indexer label shared by the Indexer screen app bar and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Indexer'**
  String get indexerTitle;

  /// Progress subtitle showing artists and albums counts
  ///
  /// In en, this message translates to:
  /// **'Artists {artists} · Albums {albums}...'**
  String indexerArtistsAlbumsProgress(String artists, String albums);

  /// Progress subtitle while processing
  ///
  /// In en, this message translates to:
  /// **'Processing {progress}...'**
  String indexerProcessing(String progress);

  /// Unknown error text shared by the indexer and auto-backup notifications
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get indexerUnknownError;

  /// Status text when an operation completes
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get indexerCompleted;

  /// Cache progress count as processed over total
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} cached'**
  String indexerCached(int processed, int total);

  /// Cache progress count including failed count
  ///
  /// In en, this message translates to:
  /// **'{processed}/{total} cached ({failed} failed)'**
  String indexerCachedFailed(int processed, int total, int failed);

  /// Status text when a cache is ready to rebuild
  ///
  /// In en, this message translates to:
  /// **'Ready to rebuild'**
  String get indexerReadyToRebuild;

  /// Progress text for the artists-only cache
  ///
  /// In en, this message translates to:
  /// **'Artists {progress}'**
  String indexerArtistsOnly(String progress);

  /// Progress text for the albums-only cache
  ///
  /// In en, this message translates to:
  /// **'Albums {progress}'**
  String indexerAlbumsOnly(String progress);

  /// Question shown when a cache has failed items
  ///
  /// In en, this message translates to:
  /// **'This cache has {failed} failed items. What would you like to do?'**
  String indexerFailedItemsQuestion(int failed);

  /// Button to view the count of failed items
  ///
  /// In en, this message translates to:
  /// **'View {failed} Failed'**
  String indexerViewFailed(int failed);

  /// Button to retry failed items
  ///
  /// In en, this message translates to:
  /// **'Retry Failed'**
  String get indexerRetryFailed;

  /// Button to force rebuild a cache
  ///
  /// In en, this message translates to:
  /// **'Force Rebuild'**
  String get indexerForceRebuild;

  /// Confirmation when a cache is already complete
  ///
  /// In en, this message translates to:
  /// **'This cache is already complete ({processed}/{total}). Do you want to force rebuild it?'**
  String indexerAlreadyCompleteQuestion(int processed, int total);

  /// Button to confirm an action in a dialog
  ///
  /// In en, this message translates to:
  /// **'Do It'**
  String get indexerDoIt;

  /// Status while optimizing a cache
  ///
  /// In en, this message translates to:
  /// **'Optimizing {name}...'**
  String indexerOptimizing(String name);

  /// Warning not to close the app during operation
  ///
  /// In en, this message translates to:
  /// **'Please do not close the app'**
  String get indexerDoNotClose;

  /// Message that operation completed and restart is needed
  ///
  /// In en, this message translates to:
  /// **'The operation has been completed successfully.\n\nThe app needs to restart to apply all changes properly.'**
  String get indexerRestartRequiredMessage;

  /// Title for the failed items dialog
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Failed Item} other{{count} Failed Items}}'**
  String indexerFailedItemsTitle(int count);

  /// Message listing items that could not be processed
  ///
  /// In en, this message translates to:
  /// **'The following items could not be processed:'**
  String get indexerCouldNotProcess;

  /// Title for the warnings dialog named by operation
  ///
  /// In en, this message translates to:
  /// **'{name} Warnings'**
  String indexerWarningsTitle(String name);

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get indexerOk;

  /// Choice to process only missing items
  ///
  /// In en, this message translates to:
  /// **'Just Missing'**
  String get indexerJustMissing;

  /// Choice to force process all items
  ///
  /// In en, this message translates to:
  /// **'Force All'**
  String get indexerForceAll;

  /// App bar title for the beat sync calibration screen
  ///
  /// In en, this message translates to:
  /// **'Beat sync'**
  String get beatSyncTitle;

  /// Message prompting to play a song to calibrate beat
  ///
  /// In en, this message translates to:
  /// **'Play a song to calibrate.'**
  String get beatPlayToCalibrate;

  /// Message while analyzing beats
  ///
  /// In en, this message translates to:
  /// **'Analyzing beats...'**
  String get beatAnalyzing;

  /// Message when a track has no clear beat
  ///
  /// In en, this message translates to:
  /// **'No clear beat in this track.'**
  String get beatNoClearBeat;

  /// Instruction to drag until particle bursts land on clicks
  ///
  /// In en, this message translates to:
  /// **'Drag until the particle bursts land on the clicks.'**
  String get beatDragInstruction;

  /// Display of the beat offset in milliseconds
  ///
  /// In en, this message translates to:
  /// **'{value} ms'**
  String beatOffsetMs(int value);

  /// Button to reset the beat offset to zero
  ///
  /// In en, this message translates to:
  /// **'Reset to 0 ms'**
  String get beatResetToZero;

  /// Library label shared by the screen title, breadcrumb, nav tab, settings page, settings group, and song menu section
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// Tab label for the folders view
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get libraryFoldersTab;

  /// Empty state title when no music folder is selected
  ///
  /// In en, this message translates to:
  /// **'No music folder yet'**
  String get libraryNoMusicFolderTitle;

  /// Empty state message prompting to select a folder in Home
  ///
  /// In en, this message translates to:
  /// **'Select a music folder in Home to fill this out.'**
  String get libraryNoMusicFolderMessage;

  /// Error title when the music folder cannot be found
  ///
  /// In en, this message translates to:
  /// **'Could not find your music folder'**
  String get libraryFolderErrorTitle;

  /// Error title when the library fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load library'**
  String get libraryLoadErrorTitle;

  /// Error title when a folder cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open folder'**
  String get libraryOpenFolderErrorTitle;

  /// Empty state title when a filter has no matches
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get libraryNoMatchesTitle;

  /// Empty message when no library items match the query
  ///
  /// In en, this message translates to:
  /// **'Nothing in your library matches \"{query}\".'**
  String libraryNoMatchesMessage(String query);

  /// Empty message when no items in a folder match the query
  ///
  /// In en, this message translates to:
  /// **'Nothing in this folder matches \"{query}\".'**
  String libraryFolderNoMatchesMessage(String query);

  /// Empty message when no items in a collection match the query
  ///
  /// In en, this message translates to:
  /// **'Nothing here matches \"{query}\".'**
  String libraryCollectionNoMatchesMessage(String query);

  /// Favorites label shared by the library collection, the sync category, and the shuffle weight
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libraryFavorites;

  /// Subtitle showing the number of merged groups
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 group} other{{count} groups}}'**
  String libraryMergedGroupsCount(int count);

  /// Tooltip to create a new merge group
  ///
  /// In en, this message translates to:
  /// **'Create new merge group'**
  String get libraryCreateMergeGroupTooltip;

  /// Action label to delete a playlist
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get libraryDeletePlaylist;

  /// Tooltip for playlist options
  ///
  /// In en, this message translates to:
  /// **'Playlist options'**
  String get libraryPlaylistOptions;

  /// Tooltip for folder options
  ///
  /// In en, this message translates to:
  /// **'Folder options'**
  String get libraryFolderOptions;

  /// Placeholder for the library filter input in all view
  ///
  /// In en, this message translates to:
  /// **'Filter folders, playlists, songs...'**
  String get libraryFilterAllHint;

  /// Placeholder for the library filter input in songs view
  ///
  /// In en, this message translates to:
  /// **'Filter folders, songs...'**
  String get libraryFilterSongsHint;

  /// Placeholder for the library filter input in collections view
  ///
  /// In en, this message translates to:
  /// **'Filter artists, albums...'**
  String get libraryFilterCollectionsHint;

  /// Track count shared by folder rows, home, search results, saved queues, and the sleep timer
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String libraryTrackCount(int count);

  /// Label for the All collection or folder, also used by search filters, folder selection, and the restore dialog
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryAll;

  /// Tooltip to shuffle a folder
  ///
  /// In en, this message translates to:
  /// **'Shuffle folder'**
  String get libraryShuffleFolderTooltip;

  /// Empty state title when there are no artists
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get libraryNoArtistsTitle;

  /// Empty state title when there are no albums
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get libraryNoAlbumsTitle;

  /// Empty-state message on library artists/albums view prompting to scan a music folder
  ///
  /// In en, this message translates to:
  /// **'Scan a music folder to fill this out.'**
  String get libraryScanToFillMessage;

  /// Clear label shared by settings, storage rows, select songs, and library filters
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// Label for search action in navigation, home, and lyrics search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Tooltip for shuffle-all action on home and library
  ///
  /// In en, this message translates to:
  /// **'Shuffle all'**
  String get actionShuffleAll;

  /// Action label to open the full recent queues list
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get actionSeeAll;

  /// Subtitle on recent queue cards showing date and track count
  ///
  /// In en, this message translates to:
  /// **'{date} · {count, plural, =1{1 track} other{{count} tracks}}'**
  String homeQueueCardSubtitle(String date, int count);

  /// Snackbar message after replacing the queue with selected tracks
  ///
  /// In en, this message translates to:
  /// **'Playing {count, plural, =1{1 track} other{{count} tracks}}'**
  String homePlayingCount(int count);

  /// Action label to open the player from the queue apply snackbar
  ///
  /// In en, this message translates to:
  /// **'Open Player'**
  String get homeOpenPlayer;

  /// Button label to play selected songs immediately
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get homePlayNow;

  /// Snackbar message when a queue replacement is pending
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track will play after the current song} other{{count} tracks will play after the current song}}'**
  String homePlayAfterCount(int count);

  /// Play After Current Song label shared by the home queue sheet and session detail
  ///
  /// In en, this message translates to:
  /// **'Play After Current Song'**
  String get homePlayAfterCurrent;

  /// Sheet action to save a recommendation as a new playlist
  ///
  /// In en, this message translates to:
  /// **'Save to new playlist'**
  String get homeSaveToNewPlaylist;

  /// Sheet action to unpin a recommendation
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get homeUnpin;

  /// Sheet action to pin a recommendation
  ///
  /// In en, this message translates to:
  /// **'Pin recommendation'**
  String get homePinRecommendation;

  /// Sheet action to rename a recommendation
  ///
  /// In en, this message translates to:
  /// **'Rename recommendation'**
  String get homeRenameRecommendation;

  /// Dialog title for renaming a recommendation
  ///
  /// In en, this message translates to:
  /// **'Rename Recommendation'**
  String get homeRenameRecommendationTitle;

  /// Sheet action to remove a recommendation
  ///
  /// In en, this message translates to:
  /// **'Remove recommendation'**
  String get homeRemoveRecommendation;

  /// Dialog title confirming removal of a recommendation
  ///
  /// In en, this message translates to:
  /// **'Remove recommendation?'**
  String get homeRemoveRecommendationTitle;

  /// Confirmation message naming the recommendation to remove
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \"{title}\"?'**
  String homeRemoveRecommendationMessage(String title);

  /// Title for the home error empty state
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get homeErrorTitle;

  /// Action button to retry loading after a home error
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get homeTryAgain;

  /// Title for the empty library state on home
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get homeNoSongsTitle;

  /// Message prompting to select a music folder when no songs exist
  ///
  /// In en, this message translates to:
  /// **'Select your music folder to start listening offline.'**
  String get homeNoSongsMessage;

  /// Action button to select a music folder
  ///
  /// In en, this message translates to:
  /// **'Select Music Folder'**
  String get homeSelectFolder;

  /// Quick Picks label shared by the home section header and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Quick Picks'**
  String get homeQuickPicks;

  /// Recent Queues label shared by the home section header and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Recent Queues'**
  String get homeRecentQueues;

  /// For You label shared by the home section header and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get homeForYou;

  /// Merged Songs label shared by the library collection and the merged songs screen
  ///
  /// In en, this message translates to:
  /// **'Merged Songs'**
  String get mergedTitle;

  /// Tooltip for the create merge group button
  ///
  /// In en, this message translates to:
  /// **'Create merge group'**
  String get mergedCreateGroupTooltip;

  /// Tab label showing the count of merge groups
  ///
  /// In en, this message translates to:
  /// **'Groups ({count})'**
  String mergedGroupsTab(int count);

  /// Tab label showing the count of auto-detected candidate groups
  ///
  /// In en, this message translates to:
  /// **'Auto-Find ({count})'**
  String mergedAutoFindTab(int count);

  /// Snackbar shown after merging selected songs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Merged 1 song} other{Merged {count} songs}}'**
  String mergedCreatedSnack(int count);

  /// Empty state title when no merged songs exist
  ///
  /// In en, this message translates to:
  /// **'No merged songs yet'**
  String get mergedEmptyTitle;

  /// Empty state body explaining merge groups
  ///
  /// In en, this message translates to:
  /// **'Group different versions of the same song (remixes, live versions, acoustics) so they share one spot during shuffle.'**
  String get mergedEmptyBody;

  /// Button to create a merge group
  ///
  /// In en, this message translates to:
  /// **'Create Merge Group'**
  String get mergedCreateGroupButton;

  /// Snackbar when a song is set as priority in a group
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" set as priority song'**
  String mergedPrioritySet(String title);

  /// Snackbar when priority is cleared
  ///
  /// In en, this message translates to:
  /// **'Priority cleared'**
  String get mergedPriorityCleared;

  /// Empty state title when no candidate variants are found
  ///
  /// In en, this message translates to:
  /// **'No candidate songs found'**
  String get mergedNoCandidatesTitle;

  /// Empty state body when no candidate variants are found
  ///
  /// In en, this message translates to:
  /// **'No unmerged song variants (remixes, live versions, acoustics) were detected in your library.'**
  String get mergedNoCandidatesBody;

  /// Label showing the number of potential merge groups found
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found 1 potential group to merge} other{Found {count} potential groups to merge}}'**
  String mergedFoundGroups(int count);

  /// Button label to merge all suggested groups
  ///
  /// In en, this message translates to:
  /// **'Merge All'**
  String get mergedMergeAll;

  /// Dialog title for merging all suggestions
  ///
  /// In en, this message translates to:
  /// **'Merge All Suggestions'**
  String get mergedMergeAllTitle;

  /// Confirmation message for merging all suggested groups
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Create 1 merge group for detected song variants?} other{Create {count} merge groups for detected song variants?}}'**
  String mergedMergeAllConfirm(int count);

  /// Snackbar shown after creating merge groups from suggestions
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Created 1 merge group} other{Created {count} merge groups}}'**
  String mergedCreatedGroupsSnack(int count);

  /// Dialog title for unmerging a song
  ///
  /// In en, this message translates to:
  /// **'Unmerge Song'**
  String get mergedUnmergeTitle;

  /// Confirmation message for unmerging a song
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from this merge group?'**
  String mergedUnmergeConfirm(String title);

  /// Button label to unmerge a song
  ///
  /// In en, this message translates to:
  /// **'Unmerge'**
  String get mergedUnmergeAction;

  /// Snackbar shown after unmerging a song
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" unmerged'**
  String mergedUnmergedSnack(String title);

  /// Dialog title for deleting a merge group
  ///
  /// In en, this message translates to:
  /// **'Delete Merge Group'**
  String get mergedDeleteGroupTitle;

  /// Confirmation message for deleting a merge group
  ///
  /// In en, this message translates to:
  /// **'Unmerge all songs in this group?'**
  String get mergedDeleteGroupConfirm;

  /// Button label to unmerge all songs in a group
  ///
  /// In en, this message translates to:
  /// **'Unmerge All'**
  String get mergedUnmergeAllAction;

  /// Snackbar shown after deleting a merge group
  ///
  /// In en, this message translates to:
  /// **'Merge group deleted'**
  String get mergedGroupDeleted;

  /// Label for a merge group
  ///
  /// In en, this message translates to:
  /// **'Merge Group'**
  String get mergedGroupLabel;

  /// Count label of versions in a merge group
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 version} other{{count} versions}}'**
  String mergedVersionsCount(int count);

  /// Tooltip for the unmerge all action
  ///
  /// In en, this message translates to:
  /// **'Unmerge all'**
  String get mergedUnmergeAllTooltip;

  /// Badge label for the priority song
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get mergedPriorityBadge;

  /// Tooltip explaining the priority song for shuffle
  ///
  /// In en, this message translates to:
  /// **'Priority song for shuffle'**
  String get mergedPrioritySongTooltip;

  /// Tooltip to set a song as priority
  ///
  /// In en, this message translates to:
  /// **'Set as priority song'**
  String get mergedSetPriorityTooltip;

  /// Tooltip to unmerge a song
  ///
  /// In en, this message translates to:
  /// **'Unmerge song'**
  String get mergedUnmergeSongTooltip;

  /// Selection count label in the merge dialog
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total} selected'**
  String mergedSelectedCount(int selected, int total);

  /// Button label to merge selected songs
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get mergedMergeAction;

  /// Title of the sleep timer screen and menu entry
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimerTitle;

  /// Label for the timer mode selector
  ///
  /// In en, this message translates to:
  /// **'Timer Mode'**
  String get sleepTimerModeLabel;

  /// Label for the duration selector
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sleepTimerDurationLabel;

  /// Suffix for minutes
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get sleepTimerMinSuffix;

  /// Label for the number of tracks selector
  ///
  /// In en, this message translates to:
  /// **'Number of Tracks'**
  String get sleepTimerTracksLabel;

  /// Option title to loop the current song for a set time
  ///
  /// In en, this message translates to:
  /// **'Loop Current Song'**
  String get sleepTimerLoopTitle;

  /// Subtitle explaining the loop current song option
  ///
  /// In en, this message translates to:
  /// **'Repeat the current song for a set time'**
  String get sleepTimerLoopSubtitle;

  /// Option title to play for a duration then stop
  ///
  /// In en, this message translates to:
  /// **'Play for Time'**
  String get sleepTimerPlayForTimeTitle;

  /// Subtitle explaining the play for time option
  ///
  /// In en, this message translates to:
  /// **'Stop after a specified duration'**
  String get sleepTimerPlayForTimeSubtitle;

  /// Option title to stop after the current song
  ///
  /// In en, this message translates to:
  /// **'Stop After Current'**
  String get sleepTimerStopAfterCurrentTitle;

  /// Subtitle explaining the stop after current option
  ///
  /// In en, this message translates to:
  /// **'Stop when the current song ends'**
  String get sleepTimerStopAfterCurrentSubtitle;

  /// Option title to stop after X tracks
  ///
  /// In en, this message translates to:
  /// **'Stop After Tracks'**
  String get sleepTimerStopAfterTracksTitle;

  /// Subtitle explaining the stop after tracks option
  ///
  /// In en, this message translates to:
  /// **'Stop after playing X more songs'**
  String get sleepTimerStopAfterTracksSubtitle;

  /// Message when no song is playing for the sleep timer
  ///
  /// In en, this message translates to:
  /// **'No song is currently playing'**
  String get sleepTimerNoSong;

  /// Label for the current song in the sleep timer
  ///
  /// In en, this message translates to:
  /// **'Current song'**
  String get sleepTimerCurrentSongLabel;

  /// Option to let the current song finish before stopping
  ///
  /// In en, this message translates to:
  /// **'Let current song finish'**
  String get sleepTimerLetFinishTitle;

  /// Subtitle for the let current song finish option
  ///
  /// In en, this message translates to:
  /// **'Wait for the current song to end before stopping'**
  String get sleepTimerLetFinishSubtitle;

  /// Subtitle for the stop immediately option
  ///
  /// In en, this message translates to:
  /// **'Stop immediately when timer expires'**
  String get sleepTimerStopImmediatelySubtitle;

  /// Button to start the sleep timer
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get sleepTimerStart;

  /// Button to cancel the active sleep timer
  ///
  /// In en, this message translates to:
  /// **'Cancel Active Timer'**
  String get sleepTimerCancelActive;

  /// Snackbar when the sleep timer is cancelled
  ///
  /// In en, this message translates to:
  /// **'Sleep timer cancelled'**
  String get sleepTimerCancelled;

  /// Snackbar when the sleep timer finishes
  ///
  /// In en, this message translates to:
  /// **'Sleep timer finished'**
  String get sleepTimerFinished;

  /// Status text while looping the current song
  ///
  /// In en, this message translates to:
  /// **'Looping current song for {minutes} minutes'**
  String sleepTimerLoopingFor(int minutes);

  /// Status text showing time until stop
  ///
  /// In en, this message translates to:
  /// **'Music will stop in {minutes} minutes'**
  String sleepTimerStopIn(int minutes);

  /// Status text for stop after current song
  ///
  /// In en, this message translates to:
  /// **'Will stop after current song ends'**
  String get sleepTimerStopAfterCurrent;

  /// Status text for stop after tracks
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Will stop after 1 more song} other{Will stop after {count} more songs}}'**
  String sleepTimerStopAfterTracks(int count);

  /// Placeholder text for the settings search field
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearchHint;

  /// None label shared by settings value readouts and the restore dialog
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get settingsValueNone;

  /// Formatted duration in seconds
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String settingsDurationSeconds(int seconds);

  /// Duration in minutes shared by settings value readouts and the sleep timer
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String settingsDurationMinutes(int minutes);

  /// Duration in minutes and seconds shared by settings, session detail, and the waveform scrub delta
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String settingsDurationMinutesSeconds(int minutes, int seconds);

  /// Group header label for the Look & Feel section of the settings hub
  ///
  /// In en, this message translates to:
  /// **'Look & Feel'**
  String get settingsGroupLookAndFeel;

  /// Group header label for the Data section of the settings hub
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsGroupData;

  /// Group header label for the App section in the settings hub and app drawer
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsGroupApp;

  /// Group header label for the Filters section on the Library settings page
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get settingsGroupFilters;

  /// Group header label for the Maintenance section on the Library settings page
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get settingsGroupMaintenance;

  /// Snackbar message shown while rescanning the music library
  ///
  /// In en, this message translates to:
  /// **'Scanning library…'**
  String get settingsScanningLibrary;

  /// Title shown above settings search results for a query
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String settingsResultsFor(String query);

  /// Empty-state title when settings search finds no matches
  ///
  /// In en, this message translates to:
  /// **'No settings found'**
  String get settingsNoResultsTitle;

  /// Empty-state message when settings search finds no matches
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
  String settingsNoResultsMessage(String query);

  /// Group header label for the Lists & Navigation section of Home settings
  ///
  /// In en, this message translates to:
  /// **'Lists & Navigation'**
  String get homeSettingsGroupLists;

  /// Subtitle for the auto-hide header and bottom dock toggle on scroll
  ///
  /// In en, this message translates to:
  /// **'Header and bottom dock hide on downward scroll, restore on upward scroll'**
  String get homeSettingsAutoHideBarsSubtitle;

  /// Group header label for the Home screen section of Home settings
  ///
  /// In en, this message translates to:
  /// **'Home screen'**
  String get homeSettingsGroupHome;

  /// Group header label for the Transitions section of Playback settings
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get playbackGroupTransitions;

  /// Group header label for the Play / Pause section of Playback settings
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get playbackGroupPlayPause;

  /// Group header label for the Audio section of Playback settings
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playbackGroupAudio;

  /// Title for the gap slider when fade mode is active and gap is disabled
  ///
  /// In en, this message translates to:
  /// **'Gap / Delay (off)'**
  String get playbackGapOff;

  /// Title for the fade-out slider when gap mode is active and fade is disabled
  ///
  /// In en, this message translates to:
  /// **'Fade Out (off)'**
  String get playbackFadeOutOff;

  /// Title for the fade-in slider when gap mode is active and fade is disabled
  ///
  /// In en, this message translates to:
  /// **'Fade In (off)'**
  String get playbackFadeInOff;

  /// Value label in seconds for playback gap and fade sliders
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String playbackSecondsValue(String seconds);

  /// Value label for a fade duration of one second or more
  ///
  /// In en, this message translates to:
  /// **'1.0 s'**
  String get playbackValueOneSecond;

  /// Value label in milliseconds for sub-second fade durations
  ///
  /// In en, this message translates to:
  /// **'{milliseconds} ms'**
  String playbackValueMilliseconds(int milliseconds);

  /// Chip label for the current filename token in the bulk rename format builder
  ///
  /// In en, this message translates to:
  /// **'Current name'**
  String get bulkRenameTokenCurrentName;

  /// Chip label for the track number token in the bulk rename format builder
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get bulkRenameTokenNumber;

  /// Chip label for the year token in the bulk rename format builder
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get bulkRenameTokenYear;

  /// Error message when library analysis fails during bulk rename
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the library: {error}'**
  String bulkRenameAnalyzeError(String error);

  /// Button title showing the number of songs to rename
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rename 1 song} other{Rename {count} songs}}'**
  String bulkRenameRenameCount(int count);

  /// Confirmation body for a bulk rename
  ///
  /// In en, this message translates to:
  /// **'Files are renamed in place. Play stats, playlists and cached artwork move across with them, and the database is kept in step as each file lands.'**
  String get bulkRenameConfirmMessage;

  /// Snackbar shown when no songs remain to rename
  ///
  /// In en, this message translates to:
  /// **'Nothing left to rename'**
  String get bulkRenameNothingLeft;

  /// Phase label while bulk rename is starting
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get bulkRenamePhaseStarting;

  /// App bar title for the Bulk Rename screen
  ///
  /// In en, this message translates to:
  /// **'Bulk Rename'**
  String get bulkRenameTitle;

  /// Format preset option using artist and title
  ///
  /// In en, this message translates to:
  /// **'Artist - Title'**
  String get bulkRenameFormatArtistTitle;

  /// Format preset option using artist, album, and title
  ///
  /// In en, this message translates to:
  /// **'Artist - Album - Title'**
  String get bulkRenameFormatArtistAlbumTitle;

  /// Subtitle for the custom format option
  ///
  /// In en, this message translates to:
  /// **'Your own arrangement'**
  String get bulkRenameCustomSubtitle;

  /// Section header for format presets in bulk rename
  ///
  /// In en, this message translates to:
  /// **'FORMAT'**
  String get bulkRenameSectionFormat;

  /// Section header for arranging rename tokens
  ///
  /// In en, this message translates to:
  /// **'ARRANGE'**
  String get bulkRenameSectionArrange;

  /// Section header for the rename preview list
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get bulkRenameSectionPreview;

  /// Placeholder shown when no tokens are added in the arrange section
  ///
  /// In en, this message translates to:
  /// **'Add a field below to start building a name.'**
  String get bulkRenameEmptySegments;

  /// Hint text for the literal text input in bulk rename
  ///
  /// In en, this message translates to:
  /// **'Text, e.g. \" - \"'**
  String get bulkRenameLiteralHint;

  /// Chip label for a literal text token
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get bulkRenameTextChip;

  /// Status text while analyzing the library for bulk rename
  ///
  /// In en, this message translates to:
  /// **'Analyzing library'**
  String get bulkRenameAnalyzing;

  /// Count of songs to rename in the preview
  ///
  /// In en, this message translates to:
  /// **'{count} to rename'**
  String bulkRenameCountToRename(int count);

  /// Count of skipped songs in the preview
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String bulkRenameSkippedCount(int count);

  /// Overflow indicator for hidden preview items
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String bulkRenameAndMore(int count);

  /// Progress text while checking candidate names
  ///
  /// In en, this message translates to:
  /// **'Checking names — {done} of {total}'**
  String bulkRenameChecking(int done, int total);

  /// Button label to stop the rename operation
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get bulkRenameStop;

  /// Status text while the rename operation is stopping
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get bulkRenameStopping;

  /// Status text while finalizing the rename operation
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get bulkRenamePleaseWait;

  /// Progress count of completed songs out of total
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String bulkRenameProgressCount(int done, int total);

  /// Completion message when rename is stopped early
  ///
  /// In en, this message translates to:
  /// **'Stopped after {count} songs. Their stats and cached artwork moved across; the rest were left alone.'**
  String bulkRenameStopped(int count);

  /// Completion message when stopped early with failures
  ///
  /// In en, this message translates to:
  /// **'Stopped after {count} songs, {failed} could not be renamed.'**
  String bulkRenameStoppedFailed(int count, int failed);

  /// Completion message when rename finishes successfully
  ///
  /// In en, this message translates to:
  /// **'Renamed {count} songs. Stats and cached artwork moved across.'**
  String bulkRenameCompleted(int count);

  /// Completion message when rename finishes with failures
  ///
  /// In en, this message translates to:
  /// **'Renamed {count} songs, {failed} could not be renamed.'**
  String bulkRenameCompletedFailed(int count, int failed);

  /// Dialog title shown when rename finishes
  ///
  /// In en, this message translates to:
  /// **'Rename finished'**
  String get bulkRenameFinishedTitle;

  /// Skip reason: no title text remains after cleanup
  ///
  /// In en, this message translates to:
  /// **'No title text left after cleanup'**
  String get bulkRenameSkipNoTitleText;

  /// Skip reason: song is already named this way
  ///
  /// In en, this message translates to:
  /// **'Already named this'**
  String get bulkRenameSkipAlreadyNamed;

  /// Skip reason: same name as another file in the folder
  ///
  /// In en, this message translates to:
  /// **'Same name as \"{filename}\" in this folder'**
  String bulkRenameSkipSameNameAs(String filename);

  /// Skip reason: another selected song already uses that name
  ///
  /// In en, this message translates to:
  /// **'Another selected song has that name'**
  String get bulkRenameSkipAnotherSelected;

  /// Skip reason: a file with that name already exists
  ///
  /// In en, this message translates to:
  /// **'A file with that name is already here'**
  String get bulkRenameSkipFileExists;

  /// Snackbar shown after resetting shuffle settings to defaults
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get shuffleResetDone;

  /// Snackbar shown after saving shuffle settings
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get shuffleSaved;

  /// Dialog title for unsaved shuffle settings changes
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get shuffleUnsavedTitle;

  /// Dialog message asking whether to save unsaved shuffle changes
  ///
  /// In en, this message translates to:
  /// **'Do you want to save your changes?'**
  String get shuffleUnsavedMessage;

  /// Button to discard unsaved shuffle changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get shuffleDiscard;

  /// App bar title for Custom Shuffle Settings
  ///
  /// In en, this message translates to:
  /// **'Custom Shuffle Settings'**
  String get shuffleTitle;

  /// Reset label shared by shuffle settings and quick actions settings
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get shuffleReset;

  /// Note that shuffle changes apply to the next queue
  ///
  /// In en, this message translates to:
  /// **'Changes will apply to next queue'**
  String get shuffleNextQueueNote;

  /// Section title for basic shuffle settings
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get shuffleBasicSettings;

  /// Toggle title to avoid repeating songs
  ///
  /// In en, this message translates to:
  /// **'Avoid Repeating Songs'**
  String get shuffleAvoidSongsTitle;

  /// Subtitle explaining reduced chance of recently played songs
  ///
  /// In en, this message translates to:
  /// **'Reduce chance of playing recently played songs'**
  String get shuffleAvoidSongsSubtitle;

  /// Toggle title to avoid repeating artists
  ///
  /// In en, this message translates to:
  /// **'Avoid Repeating Artists'**
  String get shuffleAvoidArtistsTitle;

  /// Subtitle explaining reduced chance of the same artist consecutively
  ///
  /// In en, this message translates to:
  /// **'Reduce chance of playing same artist consecutively'**
  String get shuffleAvoidArtistsSubtitle;

  /// Toggle title to avoid repeating albums
  ///
  /// In en, this message translates to:
  /// **'Avoid Repeating Albums'**
  String get shuffleAvoidAlbumsTitle;

  /// Subtitle explaining reduced chance of the same album consecutively
  ///
  /// In en, this message translates to:
  /// **'Reduce chance of playing same album consecutively'**
  String get shuffleAvoidAlbumsSubtitle;

  /// Section title for advanced shuffle settings
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get shuffleAdvancedTitle;

  /// Subtitle for fine-tuning individual weight values
  ///
  /// In en, this message translates to:
  /// **'Fine-tune individual weight values'**
  String get shuffleAdvancedSubtitle;

  /// Title for the shuffle weight values range
  ///
  /// In en, this message translates to:
  /// **'Weight Values (-99 to +99)'**
  String get shuffleWeightValuesTitle;

  /// Hint explaining weight value meaning
  ///
  /// In en, this message translates to:
  /// **'0 = neutral, negative = penalty, positive = boost'**
  String get shuffleWeightValuesHint;

  /// Label for the least played songs weight
  ///
  /// In en, this message translates to:
  /// **'Least Played Songs'**
  String get shuffleWeightLeastPlayed;

  /// Label for the most played songs weight
  ///
  /// In en, this message translates to:
  /// **'Most Played Songs'**
  String get shuffleWeightMostPlayed;

  /// Label for the suggest less songs weight
  ///
  /// In en, this message translates to:
  /// **'Suggest Less Songs'**
  String get shuffleWeightSuggestLess;

  /// Label for the playlist songs weight
  ///
  /// In en, this message translates to:
  /// **'Songs in Playlists'**
  String get shuffleWeightPlaylistSongs;

  /// Group header label for the Display & Timing section of Lyrics settings
  ///
  /// In en, this message translates to:
  /// **'Display & Timing'**
  String get lyricsGroupDisplayTiming;

  /// Simulate Word Sync title shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Simulate Word Sync'**
  String get lyricsSimulateWordSyncTitle;

  /// Simulate Word Sync subtitle shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Generate word-level timing from line-synced lyrics using prosodic estimation'**
  String get lyricsSimulateWordSyncSubtitle;

  /// Lyrics and Queue Sidebar title shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Lyrics & Queue Sidebar'**
  String get lyricsDesktopSidebarTitle;

  /// Lyrics and Queue Sidebar subtitle shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden'**
  String get lyricsDesktopSidebarSubtitle;

  /// Keep Screen Awake on Lyrics title shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Keep Screen Awake on Lyrics'**
  String get lyricsKeepScreenAwakeTitle;

  /// Keep Screen Awake on Lyrics subtitle shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Prevent sleep while the lyrics pane is open'**
  String get lyricsKeepScreenAwakeSubtitle;

  /// Group header label for the Translation section of Lyrics settings
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get lyricsGroupTranslation;

  /// Auto-Translate Lyrics title shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Auto-Translate Lyrics'**
  String get lyricsAutoTranslateTitle;

  /// Auto-Translate Lyrics subtitle shared by the lyrics settings toggle and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Automatically translate lyrics using selected target language'**
  String get lyricsAutoTranslateSubtitle;

  /// Target Language title shared by the lyrics settings row and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Target Language'**
  String get lyricsTargetLanguageTitle;

  /// Translation Display title shared by the lyrics settings row and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Translation Display'**
  String get lyricsTranslationDisplayTitle;

  /// Subtitle option to replace base lyrics with translation
  ///
  /// In en, this message translates to:
  /// **'Replace base lyrics'**
  String get lyricsTranslationModeReplaceSubtitle;

  /// Subtitle of the lyrics translation display row when subtext mode is active
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

  /// Title of the lyrics translation sheet and tooltip for the translate button
  ///
  /// In en, this message translates to:
  /// **'Translate lyrics'**
  String get lyricsTranslateTitle;

  /// Label for the translation display mode selector in the lyrics translation sheet
  ///
  /// In en, this message translates to:
  /// **'Display mode'**
  String get lyricsDisplayMode;

  /// Subtitle for the subtext translation display mode tile
  ///
  /// In en, this message translates to:
  /// **'Show translation under lyrics'**
  String get lyricsModeSubtextDescription;

  /// Subtitle for the replace translation display mode tile
  ///
  /// In en, this message translates to:
  /// **'Replace original lyrics entirely'**
  String get lyricsModeReplaceDescription;

  /// Title of the auto-translate all songs toggle in the lyrics translation sheet
  ///
  /// In en, this message translates to:
  /// **'Auto-translate all songs'**
  String get lyricsAutoTranslateAllTitle;

  /// Subtitle of the auto-translate all songs toggle
  ///
  /// In en, this message translates to:
  /// **'Automatically translate lyrics using selected language'**
  String get lyricsAutoTranslateAllSubtitle;

  /// Label above the target language picker in the lyrics translation sheet
  ///
  /// In en, this message translates to:
  /// **'Target language'**
  String get lyricsTargetLanguageLabel;

  /// Placeholder hint for the language search field in the lyrics translation sheet
  ///
  /// In en, this message translates to:
  /// **'Search language...'**
  String get lyricsSearchLanguageHint;

  /// Label for the button that clears the cached translation
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get lyricsClearCache;

  /// Label for the button that translates lyrics immediately
  ///
  /// In en, this message translates to:
  /// **'Translate now'**
  String get lyricsTranslateNow;

  /// Title of the lyrics search sheet for finding lyrics online
  ///
  /// In en, this message translates to:
  /// **'Find lyrics'**
  String get lyricsFindTitle;

  /// Message shown when an online lyrics search returns no results
  ///
  /// In en, this message translates to:
  /// **'No lyrics found. Try a different title or artist, or check your connection.'**
  String get lyricsNoResults;

  /// Warning shown when applying an instrumental lyrics result
  ///
  /// In en, this message translates to:
  /// **'Marked as instrumental. Applying this clears any lyrics stored on the file.'**
  String get lyricsInstrumentalWarning;

  /// Label for the apply button in the lyrics search preview dialog
  ///
  /// In en, this message translates to:
  /// **'APPLY'**
  String get lyricsApplyUpper;

  /// Label for plain unsynced lyrics in search results
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get lyricsPlainText;

  /// Duration label shown when a remote lyrics result has no duration
  ///
  /// In en, this message translates to:
  /// **'Unknown length'**
  String get lyricsUnknownLength;

  /// Duration label for a lyrics result whose length matches exactly
  ///
  /// In en, this message translates to:
  /// **'{duration} · exact match'**
  String lyricsDurationExactMatch(String duration);

  /// Badge shown when lyrics have word-level timing
  ///
  /// In en, this message translates to:
  /// **'WORD SYNC'**
  String get lyricsBadgeWordSync;

  /// Badge shown when lyrics have line-level timing
  ///
  /// In en, this message translates to:
  /// **'LINE SYNC'**
  String get lyricsBadgeLineSync;

  /// Badge shown for instrumental tracks in lyrics search results
  ///
  /// In en, this message translates to:
  /// **'INSTRUMENTAL'**
  String get lyricsBadgeInstrumental;

  /// Badge shown for plain unsynced lyrics
  ///
  /// In en, this message translates to:
  /// **'PLAIN'**
  String get lyricsBadgePlain;

  /// Lyrics saved snackbar shared by the lyrics pane and the metadata editor
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved'**
  String get lyricsSaved;

  /// Snackbar shown when saving lyrics fails
  ///
  /// In en, this message translates to:
  /// **'Could not save lyrics: {error}'**
  String lyricsSaveError(Object error);

  /// Snackbar shown after clearing a cached translation
  ///
  /// In en, this message translates to:
  /// **'Cached translation cleared'**
  String get lyricsTranslationCleared;

  /// Snackbar shown when lyrics are already in the target language
  ///
  /// In en, this message translates to:
  /// **'Lyrics are already in target language'**
  String get lyricsAlreadyTranslated;

  /// Snackbar shown after successful translation
  ///
  /// In en, this message translates to:
  /// **'Lyrics translated'**
  String get lyricsTranslated;

  /// Snackbar shown when translation fails
  ///
  /// In en, this message translates to:
  /// **'Could not translate lyrics'**
  String get lyricsTranslateError;

  /// Snackbar shown with error details when translation fails
  ///
  /// In en, this message translates to:
  /// **'Translation failed: {error}'**
  String lyricsTranslationFailed(Object error);

  /// Tooltip for hiding the lyric timing controls
  ///
  /// In en, this message translates to:
  /// **'Hide lyric timing'**
  String get lyricsHideTimingTooltip;

  /// Tooltip for adjusting lyric timing offset
  ///
  /// In en, this message translates to:
  /// **'Adjust lyric timing — hold for precision controls'**
  String get lyricsAdjustTimingTooltip;

  /// Tooltip and label to open the online lyrics finder
  ///
  /// In en, this message translates to:
  /// **'Find lyrics online'**
  String get lyricsFindOnline;

  /// Empty state title when a track has no lyrics
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get lyricsEmptyTitle;

  /// Empty state subtitle when a track has no lyrics
  ///
  /// In en, this message translates to:
  /// **'This track has no embedded lyrics.'**
  String get lyricsEmptySubtitle;

  /// Display name for Spanish in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// Display name for English in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Display name for French in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// Display name for German in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// Display name for Italian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// Display name for Japanese in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// Display name for Chinese in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// Display name for Korean in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// Display name for Portuguese in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// Display name for Russian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// Display name for Hindi in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// Display name for Arabic in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// Display name for Dutch in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageDutch;

  /// Display name for Polish in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get languagePolish;

  /// Display name for Turkish in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// Display name for Vietnamese in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// Display name for Ukrainian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get languageUkrainian;

  /// Display name for Swedish in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get languageSwedish;

  /// Display name for Indonesian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// Display name for Thai in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get languageThai;

  /// Display name for Czech in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Czech'**
  String get languageCzech;

  /// Display name for Greek in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageGreek;

  /// Display name for Hungarian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get languageHungarian;

  /// Display name for Romanian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get languageRomanian;

  /// Display name for Danish in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Danish'**
  String get languageDanish;

  /// Display name for Finnish in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Finnish'**
  String get languageFinnish;

  /// Display name for Norwegian in the lyrics translation language picker
  ///
  /// In en, this message translates to:
  /// **'Norwegian'**
  String get languageNorwegian;

  /// Title of the song selection screen used for merging or selecting
  ///
  /// In en, this message translates to:
  /// **'Select Songs'**
  String get selectSongsTitle;

  /// Heading of the merge explanation card
  ///
  /// In en, this message translates to:
  /// **'What is merging?'**
  String get selectSongsWhatIsMerging;

  /// Explanation text describing merged songs
  ///
  /// In en, this message translates to:
  /// **'Merged songs are different versions of the same song:'**
  String get selectSongsMergedExplanation;

  /// Bullet: merged groups can include different versions
  ///
  /// In en, this message translates to:
  /// **'Like remixes, live versions, or different quality versions'**
  String get selectSongsBulletVersions;

  /// Bullet: favorites and suggest-less stay per song
  ///
  /// In en, this message translates to:
  /// **'Favorites and \"suggest less\" are independent per song'**
  String get selectSongsBulletFavorites;

  /// Bullet: play counts and stats remain unchanged
  ///
  /// In en, this message translates to:
  /// **'Your play counts and stats remain unchanged'**
  String get selectSongsBulletStats;

  /// Bullet: priority song is preferred during shuffle
  ///
  /// In en, this message translates to:
  /// **'Select a priority song (⭐) to prioritize it during shuffle'**
  String get selectSongsBulletPriority;

  /// Placeholder hint for the song search field
  ///
  /// In en, this message translates to:
  /// **'Search songs...'**
  String get selectSongsSearchHint;

  /// Label showing number of selected songs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectSongsSelectedCount(int count);

  /// Status label shown when enough songs are selected to merge
  ///
  /// In en, this message translates to:
  /// **'Ready to merge'**
  String get selectSongsReadyToMerge;

  /// Tooltip for the priority song indicator
  ///
  /// In en, this message translates to:
  /// **'Priority song'**
  String get selectSongsPrioritySongTooltip;

  /// Tooltip to set a song as priority
  ///
  /// In en, this message translates to:
  /// **'Set as priority'**
  String get selectSongsSetPriorityTooltip;

  /// Badge shown on the priority song in a merge group
  ///
  /// In en, this message translates to:
  /// **'PRIORITY'**
  String get selectSongsPriorityBadge;

  /// Hint shown when fewer than the minimum songs are selected
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Select at least 1 song} other{Select at least {count} songs}}'**
  String selectSongsMinSelection(int count);

  /// Button label to merge selected songs
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Merge 1 Song} other{Merge {count} Songs}}'**
  String selectSongsMergeAction(int count);

  /// Button label to confirm song selection
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Select 1 Song} other{Select {count} Songs}}'**
  String selectSongsSelectAction(int count);

  /// Music folder added snackbar shared by folder management and setup
  ///
  /// In en, this message translates to:
  /// **'Music folder added'**
  String get foldersAddedSnack;

  /// Music folder removed snackbar shared by folder management and setup
  ///
  /// In en, this message translates to:
  /// **'Music folder removed'**
  String get foldersRemovedSnack;

  /// Subtitle explaining the music folders list
  ///
  /// In en, this message translates to:
  /// **'Select folders containing your music files'**
  String get foldersSubtitle;

  /// Empty state title when no music folders exist
  ///
  /// In en, this message translates to:
  /// **'No folders added yet'**
  String get foldersEmptyTitle;

  /// Empty state message prompting to add a folder
  ///
  /// In en, this message translates to:
  /// **'Add a folder to build your library.'**
  String get foldersEmptyMessage;

  /// Label for the add folder button
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get foldersAddButton;

  /// Shortcut label for internal storage in the folder picker
  ///
  /// In en, this message translates to:
  /// **'Internal Storage'**
  String get foldersShortcutInternalStorage;

  /// Shortcut label for the Music folder
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get foldersShortcutMusic;

  /// Download label shared by the folder picker shortcut and the update dialog button
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get foldersShortcutDownload;

  /// Shortcut label for the storage root
  ///
  /// In en, this message translates to:
  /// **'Storage Root'**
  String get foldersShortcutStorageRoot;

  /// Shortcut label for the Downloads folder
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get foldersShortcutDownloads;

  /// Shortcut label for the Documents folder
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get foldersShortcutDocuments;

  /// Error shown when a selected folder does not exist
  ///
  /// In en, this message translates to:
  /// **'Folder does not exist'**
  String get foldersDoesNotExist;

  /// Error shown when reading a folder fails due to permissions
  ///
  /// In en, this message translates to:
  /// **'Permission denied or error reading folder'**
  String get foldersPermissionError;

  /// Title of the new folder creation dialog
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get foldersNewFolderTitle;

  /// Label for the folder name input field
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get foldersFolderNameLabel;

  /// Placeholder hint for the folder name input
  ///
  /// In en, this message translates to:
  /// **'Enter folder name'**
  String get foldersFolderNameHint;

  /// Snackbar shown when creating a folder fails
  ///
  /// In en, this message translates to:
  /// **'Error creating folder: {error}'**
  String foldersCreateError(String error);

  /// Row label to navigate to the parent folder
  ///
  /// In en, this message translates to:
  /// **'.. (Go up)'**
  String get foldersGoUp;

  /// Row label to go back in the folder picker
  ///
  /// In en, this message translates to:
  /// **'.. (Go back)'**
  String get foldersGoBack;

  /// Message shown when a folder has no subfolders
  ///
  /// In en, this message translates to:
  /// **'No subfolders found.\nSelect this folder if it contains your music.'**
  String get foldersNoSubfolders;

  /// Button label to select the currently browsed folder in the folder picker
  ///
  /// In en, this message translates to:
  /// **'Select This Folder'**
  String get foldersSelectThisFolder;

  /// Title of the folder picker dialog for choosing a destination folder
  ///
  /// In en, this message translates to:
  /// **'Select Destination Folder'**
  String get foldersSelectDestination;

  /// Message shown when the browsed folder has no subfolders
  ///
  /// In en, this message translates to:
  /// **'Empty folder. You can select it below.'**
  String get foldersEmptyFolder;

  /// Label showing the currently selected folder path in the folder picker
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String foldersSelected(String name);

  /// Label for the root (top-level) folder in the folder picker
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get foldersRoot;

  /// Action label to move a folder to another location
  ///
  /// In en, this message translates to:
  /// **'Move Folder'**
  String get foldersMoveFolder;

  /// Snackbar shown after a folder is moved successfully
  ///
  /// In en, this message translates to:
  /// **'Moved {name} to {path}'**
  String foldersMovedTo(String name, String path);

  /// Snackbar shown when moving a folder fails
  ///
  /// In en, this message translates to:
  /// **'Error moving folder: {error}'**
  String foldersMoveError(String error);

  /// Playlists label shared by the screen, app drawer, and sync category toggle
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistsTitle;

  /// Hint text in the playlists search field
  ///
  /// In en, this message translates to:
  /// **'Search playlists...'**
  String get playlistsSearchHint;

  /// Action label to create a new playlist
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get playlistsCreate;

  /// Message shown when playlist search has no matches
  ///
  /// In en, this message translates to:
  /// **'No matching playlists found'**
  String get playlistsNoMatches;

  /// Label showing the date a playlist was created
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String playlistsCreatedOn(String date);

  /// Relative creation date label for a playlist created today
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get playlistsCreatedToday;

  /// Relative creation date label for a playlist created yesterday
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get playlistsCreatedYesterday;

  /// Relative creation date label for a playlist created days ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String playlistsDaysAgo(int count);

  /// Relative creation date label for a playlist created weeks ago
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week ago} other{{count} weeks ago}}'**
  String playlistsWeeksAgo(int count);

  /// Empty-state title when the user has no playlists
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistsEmptyTitle;

  /// Empty-state message prompting to create a first playlist
  ///
  /// In en, this message translates to:
  /// **'Create your first playlist to get started'**
  String get playlistsEmptyMessage;

  /// Hint text for the playlist name input field
  ///
  /// In en, this message translates to:
  /// **'Enter playlist name'**
  String get playlistsNameHint;

  /// Listening label shared by the stats screen, insights rows, app drawer, and the settings group header
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get statsTitle;

  /// Empty-state title shown when stats fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your stats'**
  String get statsLoadErrorTitle;

  /// Loading message while reading listening history
  ///
  /// In en, this message translates to:
  /// **'Reading your listening history'**
  String get statsReadingHistory;

  /// Empty-state title when there is no listening history
  ///
  /// In en, this message translates to:
  /// **'No listening history yet'**
  String get statsEmptyTitle;

  /// Empty-state message prompting the user to play something
  ///
  /// In en, this message translates to:
  /// **'Play something and your listening habits will show up here.'**
  String get statsEmptyMessage;

  /// Section header for the listening-over-time charts
  ///
  /// In en, this message translates to:
  /// **'Over time'**
  String get statsSectionOverTime;

  /// Section header for the when-you-listen charts
  ///
  /// In en, this message translates to:
  /// **'When you listen'**
  String get statsSectionWhen;

  /// Section header for the top artists, albums, and tracks
  ///
  /// In en, this message translates to:
  /// **'Your top'**
  String get statsSectionTop;

  /// Section header for the taste and ratio metrics
  ///
  /// In en, this message translates to:
  /// **'Taste'**
  String get statsSectionTaste;

  /// Card title for the listening-by-hour histogram
  ///
  /// In en, this message translates to:
  /// **'BY HOUR'**
  String get statsByHour;

  /// Card title for the listening-by-weekday histogram
  ///
  /// In en, this message translates to:
  /// **'BY WEEKDAY'**
  String get statsByWeekday;

  /// Readout shown when no listening is recorded for a bucket
  ///
  /// In en, this message translates to:
  /// **'No listening recorded'**
  String get statsNoListening;

  /// Readout combining listened time and play count for a time bucket
  ///
  /// In en, this message translates to:
  /// **'{time} across {plays}'**
  String statsAcrossPlays(String time, String plays);

  /// Label for the share of library tracks ever played
  ///
  /// In en, this message translates to:
  /// **'Library explored'**
  String get statsLibraryExplored;

  /// Label for the share of plays that were of favourited tracks
  ///
  /// In en, this message translates to:
  /// **'Plays that were favourites'**
  String get statsPlaysFavourites;

  /// Label for the share of plays that were skipped
  ///
  /// In en, this message translates to:
  /// **'Plays skipped'**
  String get statsPlaysSkipped;

  /// Label for the average duration of a play
  ///
  /// In en, this message translates to:
  /// **'AVERAGE PLAY'**
  String get statsAvgPlay;

  /// Label for total listening time on an active day
  ///
  /// In en, this message translates to:
  /// **'ON AN ACTIVE DAY'**
  String get statsOnActiveDay;

  /// Label for average plays per active day
  ///
  /// In en, this message translates to:
  /// **'PLAYS PER ACTIVE DAY'**
  String get statsPlaysPerActiveDay;

  /// Label for the date of the first recorded listen
  ///
  /// In en, this message translates to:
  /// **'FIRST LISTEN'**
  String get statsFirstListen;

  /// Label combining a share percentage with a total count
  ///
  /// In en, this message translates to:
  /// **'{share} of {count}'**
  String statsShareOf(String share, String count);

  /// Section label for the most-played artists list
  ///
  /// In en, this message translates to:
  /// **'TOP ARTISTS'**
  String get statsTopArtists;

  /// Section label for the most-played albums list
  ///
  /// In en, this message translates to:
  /// **'TOP ALBUMS'**
  String get statsTopAlbums;

  /// Section label for the most-played tracks list
  ///
  /// In en, this message translates to:
  /// **'TOP TRACKS'**
  String get statsTopTracks;

  /// Hero label for total time listened
  ///
  /// In en, this message translates to:
  /// **'TIME LISTENED'**
  String get statsTimeListened;

  /// Subtitle showing the date range and number of active days
  ///
  /// In en, this message translates to:
  /// **'{range} · {count, plural, =1{1 day with music on} other{{count} days with music on}}'**
  String statsRangeWithDays(String range, int count);

  /// Metric label for total plays
  ///
  /// In en, this message translates to:
  /// **'PLAYS'**
  String get statsPlays;

  /// Metric label for total skips
  ///
  /// In en, this message translates to:
  /// **'SKIPS'**
  String get statsSkips;

  /// Metric label for unique tracks played
  ///
  /// In en, this message translates to:
  /// **'TRACKS'**
  String get statsTracks;

  /// Metric label for the current listening streak
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get statsStreak;

  /// Caption showing the longest streak under the current streak
  ///
  /// In en, this message translates to:
  /// **'best {count}'**
  String statsStreakBest(int count);

  /// Play count label used in stats readouts and lists
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 play} other{{count} plays}}'**
  String statsPlaysCount(int count);

  /// Active days count label used in the stats summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active day} other{{count} active days}}'**
  String statsActiveDays(int count);

  /// Compact summary line of listening stats on the profile row
  ///
  /// In en, this message translates to:
  /// **'{duration} · {plays} · {days}'**
  String statsSummary(String duration, String plays, String days);

  /// Hint shown on the profile row when stats are empty
  ///
  /// In en, this message translates to:
  /// **'Play something to start your history'**
  String get statsEmptyHint;

  /// Error message shown when stats fail to load in the profile row
  ///
  /// In en, this message translates to:
  /// **'Could not load your stats'**
  String get statsLoadError;

  /// Duration in minutes shared by stats and play history
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String statsDurationMinutes(int minutes);

  /// Duration format for whole hours
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String statsDurationHours(int hours);

  /// Duration in hours and minutes shared by stats and play history
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String statsDurationHoursMinutes(int hours, int minutes);

  /// Trend badge text when listening time is unchanged from prior window
  ///
  /// In en, this message translates to:
  /// **'same as before'**
  String get statsSameAsBefore;

  /// Hour axis tick label for AM hours
  ///
  /// In en, this message translates to:
  /// **'{hour}a'**
  String statsHourTickAm(int hour);

  /// Hour axis tick label for PM hours
  ///
  /// In en, this message translates to:
  /// **'{hour}p'**
  String statsHourTickPm(int hour);

  /// Retry label shared by session history and the lyrics pane
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

  /// Label showing the start time of a listening session
  ///
  /// In en, this message translates to:
  /// **'Started at {time}'**
  String sessionStartedAt(String time);

  /// Stat label when a session has one song
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get sessionSongSingular;

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

  /// Snackbar when a session cannot be replayed
  ///
  /// In en, this message translates to:
  /// **'No songs available to play'**
  String get sessionNoSongsAvailable;

  /// Snackbar shown when session songs are queued after the current song
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song will play after the current song} other{{count} songs will play after the current song}}'**
  String sessionAfterCurrentSnack(int count);

  /// Snackbar shown when playing songs from a session
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Playing 1 song from this session} other{Playing {count} songs from this session}}'**
  String sessionPlayingSnack(int count);

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

  /// Date header format for a play history day
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

  /// Empty-state title when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String searchNoResults(String query);

  /// Body under the no-results title
  ///
  /// In en, this message translates to:
  /// **'Try different keywords or check your filters.'**
  String get searchNoResultsHint;

  /// Section header for artist search results with count
  ///
  /// In en, this message translates to:
  /// **'Artists ({count})'**
  String searchArtistsSection(int count);

  /// Section header for album search results with count
  ///
  /// In en, this message translates to:
  /// **'Albums ({count})'**
  String searchAlbumsSection(int count);

  /// Section header for song search results with count
  ///
  /// In en, this message translates to:
  /// **'Songs ({count})'**
  String searchSongsSection(int count);

  /// Subtitle for an album result showing artist and track count
  ///
  /// In en, this message translates to:
  /// **'{artist} · {count, plural, =1{1 track} other{{count} tracks}}'**
  String searchAlbumSubtitle(String artist, int count);

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

  /// Status title while checking for updates
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get aboutChecking;

  /// Status title when an update is available
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String aboutUpdateAvailable(String version);

  /// Status title when the app is up to date
  ///
  /// In en, this message translates to:
  /// **'You are up to date'**
  String get aboutUpToDate;

  /// Status title prompting to check for updates
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get aboutCheckForUpdates;

  /// Subtitle while checking for updates
  ///
  /// In en, this message translates to:
  /// **'wispie is checking GitHub Releases.'**
  String get aboutCheckingSubtitle;

  /// Subtitle when an update is available
  ///
  /// In en, this message translates to:
  /// **'A newer version is available on GitHub.'**
  String get aboutUpdateAvailableSubtitle;

  /// Subtitle showing the latest release version
  ///
  /// In en, this message translates to:
  /// **'Latest release: {version}'**
  String aboutLatestRelease(String version);

  /// Subtitle prompting to check manually
  ///
  /// In en, this message translates to:
  /// **'Tap below to check manually.'**
  String get aboutTapToCheck;

  /// Label showing the current app version
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Unknown label shared by the about screen and play history
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get aboutUnknown;

  /// Button label to check for updates now
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get aboutCheckNow;

  /// Button label to view the release page
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get aboutViewRelease;

  /// Group header for debug options
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get aboutDebugGroup;

  /// Title of the debug toggle to persist writes
  ///
  /// In en, this message translates to:
  /// **'Persist writes'**
  String get aboutPersistWrites;

  /// Subtitle explaining the persist writes debug toggle
  ///
  /// In en, this message translates to:
  /// **'Debug builds keep changes in a throwaway copy by default. Applies on next launch.'**
  String get aboutPersistWritesSubtitle;

  /// Message that more app icons are coming soon
  ///
  /// In en, this message translates to:
  /// **'More icons coming soon'**
  String get appIconMoreSoon;

  /// Note about desktop app icon behaviour
  ///
  /// In en, this message translates to:
  /// **'Desktop launchers and file managers keep the default icon; the window and Dock icon follow your choice.'**
  String get appIconDesktopNote;

  /// Group header for disk storage settings
  ///
  /// In en, this message translates to:
  /// **'Disk'**
  String get storageSettingsDiskGroup;

  /// Group header for indexes and caches settings
  ///
  /// In en, this message translates to:
  /// **'Indexes & Caches'**
  String get storageSettingsIndexesGroup;

  /// Home label shared by the bottom navigation tab and the folder picker shortcut
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellNavHome;

  /// Tooltip for the search button in the wide navigation rail
  ///
  /// In en, this message translates to:
  /// **'Search (Ctrl+K)'**
  String get shellSearchTooltip;

  /// Tooltip and message for the button that shows the side panel
  ///
  /// In en, this message translates to:
  /// **'Show sidebar'**
  String get shellShowSidebar;

  /// Tooltip for the button that hides the side panel
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar'**
  String get shellHideSidebar;

  /// Text shown in the queue panel when nothing is up next
  ///
  /// In en, this message translates to:
  /// **'Nothing up next'**
  String get shellNothingUpNext;

  /// Label for the next track shown in the queue panel
  ///
  /// In en, this message translates to:
  /// **'Next in queue'**
  String get shellNextInQueue;

  /// Tooltip for the play-next button on a queue item
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get shellPlayNext;

  /// Text shown in the player when no song is playing
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get playerNothingPlaying;

  /// Label for the Player pane tab in the player
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerPanePlayer;

  /// Label for the Queue pane tab in the player
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerPaneQueue;

  /// Tooltip for the close button in the player (Esc)
  ///
  /// In en, this message translates to:
  /// **'Close (Esc)'**
  String get playerCloseEsc;

  /// Tooltip for the song options menu in the player
  ///
  /// In en, this message translates to:
  /// **'Song options'**
  String get playerSongOptions;

  /// Show artwork label shared by the full-bleed player and the now playing bar
  ///
  /// In en, this message translates to:
  /// **'Show artwork'**
  String get playerShowArtwork;

  /// Show video label shared by the full-bleed player and the now playing bar
  ///
  /// In en, this message translates to:
  /// **'Show video'**
  String get playerShowVideo;

  /// Label for the Queue History entry in the app drawer
  ///
  /// In en, this message translates to:
  /// **'Queue History'**
  String get drawerQueueHistory;

  /// Section header for Tools in the app drawer
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get drawerTools;

  /// Tooltip for the shuffle button in the now playing bar
  ///
  /// In en, this message translates to:
  /// **'Shuffle (hold for a new shuffle)'**
  String get nowPlayingBarShuffleTooltip;

  /// Menu item to shuffle after the current song
  ///
  /// In en, this message translates to:
  /// **'Shuffle after current song'**
  String get shuffleButtonAfterSong;

  /// Menu item to shuffle after the current queue
  ///
  /// In en, this message translates to:
  /// **'Shuffle after current queue'**
  String get shuffleButtonAfterQueue;

  /// Tooltip while scanning the library for shuffle (percentage)
  ///
  /// In en, this message translates to:
  /// **'Scanning library ({percentage}%)'**
  String shuffleButtonScanningTooltip(String percentage);

  /// Semantics label while scanning the library for shuffle
  ///
  /// In en, this message translates to:
  /// **'Scanning library {percentage} percent complete'**
  String shuffleButtonScanningSemantics(String percentage);

  /// Snackbar message while scanning the library for shuffle
  ///
  /// In en, this message translates to:
  /// **'Scanning library: {percentage}%'**
  String shuffleButtonScanningMessage(String percentage);

  /// Menu item to remove a song from a playlist (with playlist name)
  ///
  /// In en, this message translates to:
  /// **'Remove from {name}'**
  String heartMenuRemoveFromPlaylist(String name);

  /// Snackbar shown after removing a song from a playlist
  ///
  /// In en, this message translates to:
  /// **'Removed from {name}'**
  String heartMenuRemovedFromPlaylist(String name);

  /// Tooltip for the sort menu button
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// Sort option: title A to Z
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get sortTitleAZ;

  /// Sort option: date added
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get sortDateAdded;

  /// Sort option: song date oldest to newest
  ///
  /// In en, this message translates to:
  /// **'Song Date (Old - New)'**
  String get sortSongDateOldNew;

  /// Sort option: song date newest to oldest
  ///
  /// In en, this message translates to:
  /// **'Song Date (New - Old)'**
  String get sortSongDateNewOld;

  /// Sort option: most played
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get sortMostPlayed;

  /// Sort option: recently played
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get sortRecentlyPlayed;

  /// Sort option: recommended
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sortRecommended;

  /// Artists label shared by search filter chips and the library artists tab
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get searchFilterArtists;

  /// Title of the playlist selector dialog for a single song
  ///
  /// In en, this message translates to:
  /// **'Add to...'**
  String get playlistDialogAddTo;

  /// Title of the playlist selector dialog for multiple songs
  ///
  /// In en, this message translates to:
  /// **'Bulk Add to...'**
  String get playlistDialogBulkAddTo;

  /// Snackbar shown after updating playlist selections
  ///
  /// In en, this message translates to:
  /// **'Updated selections'**
  String get playlistDialogUpdatedSelections;

  /// Title of the 'All songs' album card in the album selector
  ///
  /// In en, this message translates to:
  /// **'All songs'**
  String get albumCardAllSongs;

  /// Label prompting the user to type text to confirm a destructive action
  ///
  /// In en, this message translates to:
  /// **'Type \"{text}\" to confirm'**
  String dangerDialogTypeToConfirm(String text);

  /// Label showing countdown on the confirm button of a danger dialog
  ///
  /// In en, this message translates to:
  /// **'{label} ({seconds})'**
  String dangerDialogCountdown(String label, int seconds);

  /// Default label for the confirm button in app dialogs
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get appDialogConfirm;

  /// Placeholder hint for a name input in app dialogs
  ///
  /// In en, this message translates to:
  /// **'Enter name...'**
  String get appDialogEnterName;

  /// Tooltip and state label for repeat off
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get transportRepeatOff;

  /// Tooltip and state label for repeat all
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get transportRepeatAll;

  /// Tooltip and state label for repeat one
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get transportRepeatOne;

  /// Text showing song count and total duration
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}} • {duration}'**
  String durationSongsWithTotal(int count, String duration);

  /// Label for scrub delta in minutes and seconds on the waveform
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String waveformDeltaMinutes(String minutes, String seconds);

  /// Label for scrub delta in seconds on the waveform
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String waveformDeltaSeconds(String value);

  /// Label for zero scrub delta on the waveform
  ///
  /// In en, this message translates to:
  /// **'0s'**
  String get waveformDeltaZero;

  /// Text showing a lyric line contains the search query
  ///
  /// In en, this message translates to:
  /// **'contains \"{line}\"'**
  String lyricsMatchContains(String line);

  /// Prefix text before the matched lyric line
  ///
  /// In en, this message translates to:
  /// **'contains \"'**
  String get lyricsMatchPrefix;

  /// Tooltip indicating lyrics are available
  ///
  /// In en, this message translates to:
  /// **'Lyrics available'**
  String get lyricsMatchAvailable;

  /// Label for the button to resume lyric sync
  ///
  /// In en, this message translates to:
  /// **'Resume Sync'**
  String get lyricsResumeSync;

  /// Title of the lyric timing sheet
  ///
  /// In en, this message translates to:
  /// **'Lyric timing'**
  String get lyricsTimingTitle;

  /// Label for the later side of the timing slider
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get lyricsTimingLater;

  /// Button label to sync timing to the current line
  ///
  /// In en, this message translates to:
  /// **'Sync to this line'**
  String get lyricsTimingSyncToLine;

  /// Button label to reset lyric timing
  ///
  /// In en, this message translates to:
  /// **'Reset timing'**
  String get lyricsTimingReset;

  /// Snackbar shown after snapping timing to a line
  ///
  /// In en, this message translates to:
  /// **'Snapped to {value}'**
  String lyricsTimingSnapped(String value);

  /// Tooltip for double-tap to reset timing to zero
  ///
  /// In en, this message translates to:
  /// **'Double-tap to reset to 0.00'**
  String get lyricsTimingResetTooltip;

  /// Quick Actions label shared by the quick actions settings screen and the settings search entry
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActionsTitle;

  /// Snackbar shown after resetting quick actions to defaults
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get quickActionsResetDone;

  /// Header for the enabled quick actions section (with count)
  ///
  /// In en, this message translates to:
  /// **'ENABLED ({count})'**
  String quickActionsEnabledHeader(int count);

  /// Header for the disabled quick actions section (with count)
  ///
  /// In en, this message translates to:
  /// **'DISABLED ({count})'**
  String quickActionsDisabledHeader(int count);

  /// Label for the Go to Album quick action
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get quickActionsGoToAlbum;

  /// Label for the Go to Artist quick action
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get quickActionsGoToArtist;

  /// Title of the update available dialog
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailableTitle;

  /// Label for the current version in the update dialog
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get updateCurrentLabel;

  /// Body text of the update available dialog
  ///
  /// In en, this message translates to:
  /// **'A newer version of wispie is ready to download.'**
  String get updateAvailableBody;

  /// Button label to skip the current update version
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkipVersion;

  /// Link label to view what's new in the update
  ///
  /// In en, this message translates to:
  /// **'What\'s new?'**
  String get updateWhatsNew;

  /// Button label to add an externally opened file to the library
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get externalOpenAddToLibrary;

  /// Tooltip for dismissing the external open banner
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get externalOpenDismiss;

  /// Column header for track time in the wide track table
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get wideTrackTime;

  /// Tooltip for next in the floating dock
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get floatingDockNext;

  /// Semantics label for the seek bar
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
