// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemsprache verwenden';

  @override
  String get languageNativeName => 'Deutsch';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsPageLibrarySubtitle => 'Ordner, Filter, Scans';

  @override
  String get settingsPagePlaybackTitle => 'Wiedergabe';

  @override
  String get settingsPagePlaybackSubtitle => 'Übergänge, Überblendungen, Audio';

  @override
  String get settingsPageLyricsTitle => 'Liedtexte';

  @override
  String get settingsPageLyricsSubtitle =>
      'Wortsynchronisierung, Übersetzung, Seitenleiste';

  @override
  String get settingsPageAppearanceTitle => 'Darstellung';

  @override
  String get settingsPageAppearanceSubtitle =>
      'Aktuelle Wiedergabe, Bewegung, App-Symbol';

  @override
  String get settingsPageHomeNavigationTitle => 'Startseite und Navigation';

  @override
  String get settingsPageHomeNavigationSubtitle =>
      'Startseitenbereiche, Listen, Schnellaktionen';

  @override
  String get settingsPageOnlineTitle => 'Online';

  @override
  String get settingsPageOnlineSubtitle => 'YouTube-Katalog und Konto';

  @override
  String get onlineSettingsGroup => 'YouTube';

  @override
  String get settingsYoutubeEnabledTitle => 'YouTube';

  @override
  String get settingsYoutubeEnabledSubtitle =>
      'YouTube-Tab anzeigen und Musik von YouTube abspielen. Wenn du dies deaktivierst, wird der Tab vollständig entfernt.';

  @override
  String get settingsYoutubeAccountSubtitle =>
      'Melde dich an, um deine Playlists zu importieren';

  @override
  String get settingsKwOnline => 'youtube,online,streaming,konto,importieren';

  @override
  String get settingsPageSyncTitle => 'Synchronisierung';

  @override
  String get settingsPageSyncSubtitle =>
      'Verschlüsselte Synchronisierung zwischen Geräten';

  @override
  String get settingsPageBackupRestoreTitle =>
      'Sicherung und Wiederherstellung';

  @override
  String get settingsPageBackupRestoreSubtitle =>
      'Export, Import, automatische Sicherungen';

  @override
  String get settingsPageStorageTitle => 'Speicher';

  @override
  String get settingsPageStorageSubtitle => 'Speicherplatz, Indizes, Caches';

  @override
  String get settingsPageAboutTitle => 'Über';

  @override
  String get settingsPageAboutSubtitle => 'Version, Updates, Versionshinweise';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionCreate => 'Erstellen';

  @override
  String get actionDone => 'Fertig';

  @override
  String get actionChange => 'Ändern';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionHide => 'Ausblenden';

  @override
  String get actionDeletePermanently => 'Endgültig löschen';

  @override
  String get actionBack => 'Zurück';

  @override
  String get actionClose => 'Schließen';

  @override
  String get playlistNewTitle => 'Neue Playlist';

  @override
  String get playlistNameHint => 'Playlistname';

  @override
  String playlistCreated(Object name) {
    return 'Playlist „$name“ erstellt';
  }

  @override
  String songFavoriteRemoved(Object title) {
    return '„$title“ aus den Favoriten entfernt';
  }

  @override
  String songFavoriteAdded(Object title) {
    return '„$title“ zu den Favoriten hinzugefügt';
  }

  @override
  String songWillSuggestMore(Object title) {
    return '„$title“ wird häufiger vorgeschlagen';
  }

  @override
  String songWillSuggestLess(Object title) {
    return '„$title“ wird seltener vorgeschlagen';
  }

  @override
  String songAddedToNextUp(Object title) {
    return 'Zu Als Nächstes hinzugefügt: $title';
  }

  @override
  String songShareText(Object artist, Object title) {
    return '$title von $artist';
  }

  @override
  String songAddedToPlaylist(Object name) {
    return 'Zu $name hinzugefügt';
  }

  @override
  String songRemovedFromPlaylist(Object title) {
    return '„$title“ aus der Playlist entfernt';
  }

  @override
  String songMovedTo(Object path, Object title) {
    return '„$title“ nach $path verschoben';
  }

  @override
  String songMoveError(Object error) {
    return 'Fehler beim Verschieben des Songs: $error';
  }

  @override
  String songRemovedFromLibrary(Object title) {
    return '„$title“ aus der Bibliothek entfernt';
  }

  @override
  String get songDeleteTitle => 'Song löschen';

  @override
  String songDeleteConfirm(Object title) {
    return 'Möchtest du „$title“ wirklich endgültig von deinem Gerät löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String songDeleted(Object title) {
    return '„$title“ gelöscht';
  }

  @override
  String songDeleteError(Object error) {
    return 'Fehler beim Löschen der Datei: $error';
  }

  @override
  String get coverSearching =>
      'Suche bei Last.fm, Deezer und iTunes nach Coverbildern …';

  @override
  String get coverNoneFound =>
      'Online wurden keine fehlenden Coverbilder gefunden';

  @override
  String coverUpdated(Object source, Object title) {
    return 'Coverbild für „$title“ aktualisiert ($source)';
  }

  @override
  String get coverDownloadFailed =>
      'Coverbild konnte nicht heruntergeladen werden';

  @override
  String coverFetchError(Object error) {
    return 'Fehler beim Abrufen des Covers: $error';
  }

  @override
  String get metaResultsTitle => 'Ergebnisse des Metadatenabrufs';

  @override
  String get metaFetchingTitle => 'Fehlende Metadaten werden abgerufen';

  @override
  String get metaStatUpdated => 'Aktualisiert';

  @override
  String get metaStatNotFound => 'Nicht gefunden';

  @override
  String get metaStatSkipped => 'Übersprungen';

  @override
  String get metaUndoAll => 'Alles rückgängig machen';

  @override
  String get metaUndoSong => 'Änderung für diesen Song rückgängig machen';

  @override
  String metaRevertedCount(int count) {
    return 'Metadatenänderungen für $count Titel rückgängig gemacht';
  }

  @override
  String metaViaSource(Object source) {
    return 'über $source';
  }

  @override
  String metaMoreItems(int count) {
    return '… und $count weitere';
  }

  @override
  String get metaCouldNotFind => 'Nicht gefunden';

  @override
  String get metaUnknownArtist => 'Unbekannter Interpret';

  @override
  String metaAllHaveMetadata(int count) {
    return 'Alle $count Titel haben bereits Metadaten';
  }

  @override
  String get metaNoMissingMetadata =>
      'Keine Titel mit fehlenden Metadaten gefunden';

  @override
  String metaSearchingBatch(int batch) {
    return 'Suche in Stapel $batch …';
  }

  @override
  String metaCancelledSummary(int updated, int notFound) {
    return 'Metadatenabruf abgebrochen ($updated aktualisiert, $notFound nicht gefunden)';
  }

  @override
  String get songMenuTitle => 'Songoptionen';

  @override
  String get songMenuPlaybackHint => 'Warteschlange, Playlist und Teilen';

  @override
  String get songMenuLibraryHint => 'Song verschieben und Metadaten bearbeiten';

  @override
  String get songMenuPersonalize => 'Personalisieren';

  @override
  String get songMenuPersonalizeHint =>
      'Favoriten- und Empfehlungseinstellungen';

  @override
  String get songMenuDanger => 'Gefahrenbereich';

  @override
  String get songMenuDangerHint => 'Aus Playlist entfernen oder Song löschen';

  @override
  String get songMenuPlayNext => 'Als Nächstes abspielen';

  @override
  String get songMenuPlayNextHint =>
      'Song direkt nach dem aktuellen Titel abspielen';

  @override
  String get songMenuAddToPlaylist => 'Zur Playlist hinzufügen';

  @override
  String get songMenuAddToPlaylistHint =>
      'Schnell zur zuletzt verwendeten Playlist hinzufügen';

  @override
  String get songMenuAddToNewPlaylist => 'Zu neuer Playlist hinzufügen';

  @override
  String get songMenuAddToNewPlaylistHint =>
      'Playlist erstellen und diesen Song hinzufügen';

  @override
  String get songMenuShare => 'Teilen';

  @override
  String get songMenuShareHint => 'Audiodatei mit anderen Apps teilen';

  @override
  String get songMenuFetchCover => 'Fehlendes Cover suchen';

  @override
  String get songMenuFetchCoverHint =>
      'Bei Last.fm, Deezer und iTunes nach einem Coverbild suchen';

  @override
  String get songMenuFetchMetadata => 'Fehlende Metadaten abrufen';

  @override
  String get songMenuFetchMetadataHint =>
      'Online nach Titel, Interpret, Album und Cover suchen';

  @override
  String get songMenuMoveToFolder => 'In Ordner verschieben';

  @override
  String get songMenuMoveToFolderHint =>
      'Diese Datei in einen anderen Ordner verschieben';

  @override
  String get songMenuManagePlaylists => 'Playlists verwalten';

  @override
  String get songMenuManagePlaylistsHint =>
      'Zu Playlists hinzufügen oder daraus entfernen';

  @override
  String get songMenuEditMetadata => 'Metadaten bearbeiten';

  @override
  String get songMenuEditMetadataHint => 'Metadateneditor öffnen';

  @override
  String get songMenuRemoveFavorite => 'Aus Favoriten entfernen';

  @override
  String get songMenuAddFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get songMenuFavoritesHint => 'Favoritenliste anpassen';

  @override
  String get songMenuSuggestMore => 'Häufiger vorschlagen';

  @override
  String get songMenuSuggestLess => 'Seltener vorschlagen';

  @override
  String get songMenuSuggestHint =>
      'Wie oft dieser Song vorgeschlagen wird, anpassen';

  @override
  String get songMenuRemoveFromPlaylist => 'Aus aktueller Playlist entfernen';

  @override
  String get songMenuRemoveFromPlaylistHint =>
      'Datei behalten, Playlist-Zuordnung entfernen';

  @override
  String get songMenuRemoveFromLibrary => 'Aus Bibliothek entfernen';

  @override
  String get songMenuRemoveFromLibraryHint =>
      'Datei behalten, aber in der Bibliothek ausblenden';

  @override
  String get songMenuDeleteHint => 'Datei vom Gerät löschen';

  @override
  String get bulkSelected => 'ausgewählt';

  @override
  String get bulkSelectAll => 'Alle auswählen';

  @override
  String get bulkFavorite => 'Zu Favoriten hinzufügen';

  @override
  String get bulkUnfavorite => 'Aus Favoriten entfernen';

  @override
  String bulkRemovedFromFavorites(int count) {
    return '$count Songs aus den Favoriten entfernt';
  }

  @override
  String bulkAddedToFavorites(int count) {
    return '$count Songs zu den Favoriten hinzugefügt';
  }

  @override
  String get bulkPlaylist => 'Wiedergabeliste';

  @override
  String bulkAddedToPlaylist(int count, Object name) {
    return '$count Songs zu $name hinzugefügt';
  }

  @override
  String bulkSongsCount(int count) {
    return '$count Songs';
  }

  @override
  String get bulkMetadata => 'Metadaten';

  @override
  String get bulkHideTitle => 'Songs ausblenden';

  @override
  String bulkHideMessage(int count) {
    return '$count ausgewählte Songs aus der Bibliothek ausblenden?';
  }

  @override
  String get bulkDeleteTitle => 'Dateien löschen';

  @override
  String bulkDeleteMessage(int count) {
    return '$count Dateien endgültig aus dem Speicher löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String bulkAddedToQueue(int count) {
    return '$count Songs zur Warteschlange hinzugefügt';
  }

  @override
  String get bulkMove => 'Verschieben';

  @override
  String bulkMovedTo(int count, Object path) {
    return '$count Songs nach $path verschoben';
  }

  @override
  String bulkMoveError(Object error) {
    return 'Fehler beim Verschieben der Songs: $error';
  }

  @override
  String bulkWillSuggestMore(int count) {
    return '$count Songs werden häufiger vorgeschlagen';
  }

  @override
  String bulkWillSuggestLess(int count) {
    return '$count Songs werden seltener vorgeschlagen';
  }

  @override
  String get queueTabUpNext => 'Als Nächstes';

  @override
  String get queueTabHistory => 'Verlauf';

  @override
  String get queueActionMoveToTop => 'Nach oben verschieben';

  @override
  String get queueActionRemove => 'Entfernen';

  @override
  String get queueActionSongOptions => 'Songoptionen …';

  @override
  String get queueClearDialogTitle => 'Warteschlange leeren?';

  @override
  String get queueClearDialogMessage =>
      'Dadurch werden alle kommenden Songs aus der aktuellen Warteschlange entfernt.';

  @override
  String get queueClearAll => 'Alle entfernen';

  @override
  String get queueSectionPlayed => 'Abgespielt';

  @override
  String get queueSectionNowPlaying => 'Wird gerade abgespielt';

  @override
  String get queueSectionUpNext => 'Als Nächstes';

  @override
  String get queueSwipeAddToTop => 'Ganz oben hinzufügen';

  @override
  String get queueShuffleUpcomingTooltip => 'Kommende Songs mischen';

  @override
  String get queueClearUpcomingTooltip => 'Kommende Songs entfernen';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$_temp0';
  }

  @override
  String queueRemainingSuffix(String remaining) {
    return '  ·  $remaining';
  }

  @override
  String get queueEmpty => 'Warteschlange ist leer';

  @override
  String get queueRemoveFromQueueTooltip => 'Aus Warteschlange entfernen';

  @override
  String get queueRemovedLabel => 'Aus Warteschlange entfernt';

  @override
  String get queueUndo => 'Rückgängig';

  @override
  String get historyClearDialogTitle => 'Verlauf leeren?';

  @override
  String get historyClearDialogMessage =>
      'Dadurch werden alle gespeicherten Warteschlangen-Snapshots gelöscht.';

  @override
  String historyRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel wiederhergestellt',
      one: '1 Titel wiederhergestellt',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadError => 'Verlauf konnte nicht geladen werden';

  @override
  String get historyEmptyTitle => 'Keine früheren Warteschlangen';

  @override
  String get historyEmptyMessage =>
      'Abgespielte Warteschlangen werden hier automatisch gespeichert.';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gespeicherte Warteschlangen',
      one: '1 gespeicherte Warteschlange',
    );
    return '$_temp0';
  }

  @override
  String get historyClearAllTrailing => 'Alles löschen';

  @override
  String get historyDayToday => 'Heute';

  @override
  String get historyDayYesterday => 'Gestern';

  @override
  String get historyDayThisWeek => 'Diese Woche';

  @override
  String get historyDayThisMonth => 'Diesen Monat';

  @override
  String get historyDayEarlier => 'Früher';

  @override
  String get snapshotShuffledQueue => 'Gemischte Warteschlange';

  @override
  String get snapshotSavedQueue => 'Gespeicherte Warteschlange';

  @override
  String get snapshotEmptyTracks =>
      'Keiner dieser Titel ist noch in deiner Bibliothek.';

  @override
  String snapshotMoreHidden(int count) {
    return '+$count weitere';
  }

  @override
  String snapshotMissingCount(int count) {
    return '$count nicht in der Bibliothek';
  }

  @override
  String get queueMetaSeparator => ' · ';

  @override
  String get songListShuffle => 'Zufällige Wiedergabe';

  @override
  String get songListPlay => 'Abspielen';

  @override
  String get songListPause => 'Pausieren';

  @override
  String get songListResume => 'Fortsetzen';

  @override
  String get songListFetchArtistCover => 'Interpretencover online abrufen';

  @override
  String get songListFetchAlbumCover => 'Albumcover online abrufen';

  @override
  String get songListFetchCover => 'Cover online abrufen';

  @override
  String get songListPlaylistOptions => 'Playlistoptionen';

  @override
  String get songListSelectSongsToMerge => 'Songs zum Zusammenführen auswählen';

  @override
  String songListMergedSongs(int count) {
    return '$count Songs zusammengeführt';
  }

  @override
  String songListMergeError(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get songListMergeSongs => 'Songs zusammenführen';

  @override
  String get songListEmpty => 'Keine Songs in dieser Liste';

  @override
  String get actionRename => 'Umbenennen';

  @override
  String get songListRenamePlaylist => 'Playlist umbenennen';

  @override
  String get songListDeletePlaylist => 'Playlist löschen';

  @override
  String songListDeletePlaylistConfirm(Object title) {
    return 'Möchtest du „$title“ wirklich löschen?';
  }

  @override
  String songListSearchingArtwork(Object name) {
    return 'Suche online nach Coverbildern für $name …';
  }

  @override
  String songListSelectArtwork(Object name) {
    return 'Coverbild für $name auswählen';
  }

  @override
  String get songListUseSongCoverGrid => 'Song-Coverraster verwenden';

  @override
  String get songListRemoveCustomArtwork =>
      'Benutzerdefiniertes Coverbild entfernen';

  @override
  String get songListChooseCustomImage => 'Eigenes Bild auswählen';

  @override
  String get songListSelectFromDevice =>
      'Bild aus dem Gerätespeicher auswählen';

  @override
  String songListArtworkFrom(Object source) {
    return 'Coverbild von $source';
  }

  @override
  String get songListNoOnlineArtwork => 'Keine Online-Coverbilder gefunden';

  @override
  String get songListResetArtwork => 'Auf Song-Coverraster zurücksetzen';

  @override
  String songListArtworkUpdated(Object name) {
    return 'Coverbild für $name aktualisiert';
  }

  @override
  String get songListDownloadingArtwork => 'Coverbild wird heruntergeladen …';

  @override
  String get songListArtworkDownloadFailed =>
      'Coverbild konnte nicht heruntergeladen werden';

  @override
  String get gradientDetailAlbums => 'Alben';

  @override
  String get gradientDetailSongs => 'Titel';

  @override
  String get gradientDetailShowAll => 'Alle anzeigen';

  @override
  String gradientDetailAlbumCount(int count) {
    return '$count Alben';
  }

  @override
  String get syncPlayStats => 'Wiedergabestatistiken';

  @override
  String get syncPlayStatsHint =>
      'Wiedergabeverlauf und Anzahl der Wiedergaben';

  @override
  String get syncFavoritesHint => 'Lieblingssongs';

  @override
  String get syncSuggestLess => 'Seltener vorschlagen';

  @override
  String get syncSuggestLessHint =>
      'Songs, die seltener vorgeschlagen werden sollen';

  @override
  String get syncHiddenSongs => 'Ausgeblendete Songs';

  @override
  String get syncPlaylistsHint => 'Alle Playlists';

  @override
  String get syncMergedSongs => 'Zusammengeführte Songs';

  @override
  String get syncMergedSongsHint => 'Gruppen zusammengeführter Songs';

  @override
  String get syncAppSettings => 'App-Einstellungen';

  @override
  String get syncAppSettingsHint => 'Design, Wiedergabe und Benutzeroberfläche';

  @override
  String get syncArtistArt => 'Interpretencover';

  @override
  String get syncArtistArtHint => 'Online ausgewählte Interpretencover';

  @override
  String get syncAlbumArt => 'Albumcover';

  @override
  String get syncAlbumArtHint => 'Online ausgewählte Albumcover';

  @override
  String get syncQueueHistory => 'Warteschlangenverlauf';

  @override
  String get syncQueueHistoryHint => 'Kürzlich abgespielte Warteschlangen';

  @override
  String get syncCurrentQueue => 'Aktuelle Warteschlange';

  @override
  String get syncCurrentQueueHint =>
      'Wird automatisch hochgeladen und nur bei manueller Synchronisierung heruntergeladen';

  @override
  String get syncPreferCloudQueue => 'Cloud-Warteschlange bevorzugen';

  @override
  String get syncPreferCloudQueueHint =>
      'Ein: „Jetzt synchronisieren“ ersetzt die Warteschlange auf diesem Gerät durch die Cloud-Warteschlange. Aus: Die Warteschlange auf diesem Gerät bleibt erhalten und wird hochgeladen.';

  @override
  String get syncPrivacy => 'Datenschutz';

  @override
  String get syncEncryptedTitle => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get syncEncryptedBody =>
      'Deine Daten werden auf diesem Gerät vor dem Hochladen verschlüsselt. Der Server speichert nur verschlüsselte Daten und kann weder deine Bibliothek noch deinen Verlauf oder deine Einstellungen lesen.';

  @override
  String get syncRecoveryKeyTitle => 'Wiederherstellungsschlüssel';

  @override
  String get syncRecoveryKeyBody =>
      'Wenn du dein Passwort vergisst, kannst nur du mit deinem Wiederherstellungsschlüssel den Zugriff wiederherstellen.';

  @override
  String get syncAccount => 'Konto';

  @override
  String get syncSignedIn => 'Angemeldet';

  @override
  String get syncConnected => 'Verbunden';

  @override
  String get syncLogOut => 'Abmelden';

  @override
  String get syncLogOutBody =>
      'Die Synchronisierung auf diesem Gerät wird beendet. Die lokalen und die Cloud-Daten bleiben erhalten.';

  @override
  String get syncLogOutAndChange => 'Abmelden und ändern';

  @override
  String get syncCloud => 'Cloud-Speicher';

  @override
  String get syncLastSynced => 'Zuletzt synchronisiert';

  @override
  String get syncNever => 'Nie';

  @override
  String syncUsedOfQuota(Object used, Object quota) {
    return '$used von $quota verwendet';
  }

  @override
  String get syncJustNow => 'Gerade eben';

  @override
  String syncMinutesAgo(int count) {
    return 'vor $count Min.';
  }

  @override
  String syncHoursAgo(int count) {
    return 'vor $count Std.';
  }

  @override
  String syncDaysAgo(int count) {
    return 'vor $count Tagen';
  }

  @override
  String get syncAutoSync => 'Automatisch synchronisieren';

  @override
  String get syncAutoSyncHint =>
      'Im Hintergrund synchronisieren, während die App geöffnet ist';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncMergeDeviceHint => 'Dieses Gerät mit der Cloud zusammenführen';

  @override
  String syncLastError(Object error) {
    return 'Letzter Fehler: $error';
  }

  @override
  String get syncWhatGetsSynced => 'Synchronisierte Daten';

  @override
  String get syncDeviceStatsAttribution => 'Zuordnung der Gerätestatistiken';

  @override
  String get syncThisDevice => 'Dieses Gerät';

  @override
  String get syncOtherDevices => 'Andere Geräte';

  @override
  String get syncTotalLibraryStats => 'Gesamtstatistik der Bibliothek';

  @override
  String syncPlays(int count) {
    return '$count Wiedergaben';
  }

  @override
  String get syncDangerZone => 'Gefahrenbereich';

  @override
  String get syncOverwriteCloudTile => 'Cloud mit diesem Gerät überschreiben';

  @override
  String get syncOverwriteCloudTileHint =>
      'Alle Cloud-Daten durch die Daten auf diesem Gerät ersetzen';

  @override
  String get syncReplaceDeviceTile => 'Dieses Gerät durch Cloud-Daten ersetzen';

  @override
  String get syncReplaceDeviceTileHint =>
      'Synchronisierte Daten auf diesem Gerät löschen und die Cloud-Kopie verwenden';

  @override
  String get syncChangePassword => 'Passwort ändern';

  @override
  String get syncNewRecoveryKey => 'Neuer Wiederherstellungsschlüssel';

  @override
  String get syncNewRecoveryKeyHint =>
      'Der alte Wiederherstellungsschlüssel funktioniert danach nicht mehr';

  @override
  String get syncChangeServer => 'Server wechseln';

  @override
  String get syncChangeServerHint => 'Zuerst abmelden';

  @override
  String get syncChangeServerBody =>
      'Du wirst zuerst vom aktuellen Server abgemeldet. Die lokalen Daten bleiben erhalten.';

  @override
  String get syncDeleteCloudAccount => 'Cloud-Konto löschen';

  @override
  String get syncDeleteCloudAccountHint =>
      'Löscht die Cloud-Daten endgültig. Lokale Daten bleiben erhalten.';

  @override
  String get syncDeleteCloudAccountBody =>
      'Dein Cloud-Konto und alle verschlüsselten Daten auf dem Server werden endgültig gelöscht. Die Daten auf diesem Gerät bleiben erhalten.';

  @override
  String get syncOverwriteCloud => 'Cloud überschreiben';

  @override
  String get syncOverwriteCloudBody =>
      'Alle Cloud-Daten werden durch die Daten auf diesem Gerät ersetzt. Auf anderen Geräten wird gefragt, wie fortgefahren werden soll. Die Daten auf diesem Gerät bleiben erhalten.';

  @override
  String get syncOverwriteCloudCheckbox =>
      'Ich verstehe, dass die Cloud-Daten verloren gehen';

  @override
  String get syncOverwrite => 'Überschreiben';

  @override
  String get syncReplaceDevice => 'Dieses Gerät ersetzen';

  @override
  String get syncReplaceDeviceBody =>
      'Synchronisierte Daten auf diesem Gerät (Statistiken, Favoriten, Playlists usw.) werden gelöscht und durch die Cloud-Kopie ersetzt. Musikdateien bleiben unangetastet.';

  @override
  String get syncReplaceDeviceCheckbox =>
      'Ich verstehe, dass lokal synchronisierte Daten verloren gehen';

  @override
  String get syncReplace => 'Ersetzen';

  @override
  String get syncCurrentPassword => 'Aktuelles Passwort';

  @override
  String get syncNewPassword => 'Neues Passwort';

  @override
  String get syncPassword => 'Passwort';

  @override
  String get syncPasswordChanged => 'Passwort geändert';

  @override
  String get syncGenerate => 'Generieren';

  @override
  String get appearanceGroupNowPlaying => 'Aktuelle Wiedergabe';

  @override
  String get appearanceVisualizerTitle => 'Audio-Visualizer';

  @override
  String get appearanceVisualizerSubtitle =>
      'Balken über dem Cover während der Wiedergabe — synchronisiert folgt der Musik, Bässe links';

  @override
  String get appearanceVisualizerClassic => 'Klassisch';

  @override
  String get appearanceVisualizerSynced => 'Synchronisiert';

  @override
  String get appearanceProgressBarTitle => 'Stil der Fortschrittsanzeige';

  @override
  String get appearanceProgressBasicSubtitle => 'Einfache Fortschrittslinie';

  @override
  String get appearanceProgressWaveformSubtitle => 'Statische Audiowellenform';

  @override
  String get appearanceProgressReactiveSubtitle =>
      'Dynamische, klangabhängige Wellenform mit Live-Spektrum und Beat-Reaktion';

  @override
  String get appearanceProgressStandard => 'Standard';

  @override
  String get appearanceProgressWaveform => 'Wellenform';

  @override
  String get appearanceProgressSoundReactive => 'Klangreaktiv';

  @override
  String get appearanceHapticsTitle =>
      'Haptisches Feedback beim Suchen in der Wellenform';

  @override
  String get appearanceHapticsSubtitle =>
      'Haptisches Feedback für jeden Balken beim Suchen';

  @override
  String get appearanceCoverSizingTitle => 'Größe des Player-Covers';

  @override
  String get appearanceCoverSizingSubtitle =>
      'Automatisch anpassen oder Seitenverhältnis der Quelle beibehalten';

  @override
  String get appearanceCoverAutoFit => 'Automatisch anpassen';

  @override
  String get appearanceCoverSourceSize => 'Originalgröße';

  @override
  String get appearanceImmersiveTitle => 'Immersives Design';

  @override
  String get appearanceImmersiveSubtitle =>
      'Cover im Vollbild und Detailseiten mit Farbverlauf';

  @override
  String get appearancePlayerSwipeTitle => 'Wischen wechselt Bereich';

  @override
  String get appearancePlayerSwipeSubtitle =>
      'Wische nach links oder rechts, um zwischen Liedtexten, Player und Warteschlange zu wechseln. Deaktiviere dies, um stattdessen Songs zu wechseln.';

  @override
  String get appearanceGroupPlayerMotion => 'Player-Bewegung';

  @override
  String get appearanceBeatCoverTitle => 'Beatreaktives Cover';

  @override
  String get appearanceBeatCoverUnavailable =>
      'Bei aktiviertem immersivem Design nicht verfügbar';

  @override
  String get appearanceBeatCoverSubtitle => 'Das Albumcover pulsiert im Takt';

  @override
  String get appearanceCoverIntensityTitle => 'Cover-Intensität';

  @override
  String get appearanceCoverIntensitySubtitle => 'Stärke der Cover-Reaktion';

  @override
  String get appearanceSpinArtworkTitle =>
      'Cover während der Wiedergabe drehen';

  @override
  String get appearanceSpinArtworkSubtitle =>
      'Das Cover dreht sich langsam in der minimierten Leiste am unteren Rand, während ein Song läuft';

  @override
  String get appearanceParticlesTitle => 'Beatreaktive Partikel';

  @override
  String get appearanceParticlesSubtitle =>
      'Schwebende Partikel, die im Takt der Musik treiben und pulsieren';

  @override
  String get appearanceParticleDensityTitle => 'Partikeldichte';

  @override
  String get appearanceParticleDensitySubtitle =>
      'Anzahl und Lebhaftigkeit der Partikel';

  @override
  String get appearanceBeatOffsetTitle => 'Beat-Synchronisierungsversatz';

  @override
  String get appearanceBeatOffsetNone =>
      'Kein Versatz — erhöhe den Wert, wenn der Puls zu früh kommt';

  @override
  String appearanceBeatOffsetValue(int ms) {
    return '$ms ms';
  }

  @override
  String appearanceBeatOffsetBluetooth(int ms) {
    return '$ms ms (für Bluetooth erhöhen)';
  }

  @override
  String get appearanceCalibrateTitle => 'Beat-Synchronisierung kalibrieren';

  @override
  String get appearanceCalibrateSubtitle =>
      'Partikel nach Gehör an einen Klicktrack anpassen';

  @override
  String get appearanceAppIcon => 'App-Symbol';

  @override
  String get appearanceIntensityMin => 'Minimal';

  @override
  String get appearanceIntensitySubtle => 'Dezent';

  @override
  String get appearanceIntensityBalanced => 'Ausgewogen';

  @override
  String get appearanceIntensityBold => 'Kräftig';

  @override
  String get appearanceIntensityMax => 'Maximal';

  @override
  String get appearanceIntensityCustom => 'Benutzerdefiniert';

  @override
  String get backupExportAppData => 'App-Daten exportieren';

  @override
  String get backupExportAppDataSubtitle =>
      'Statistiken, Favoriten und Playlists sichern';

  @override
  String backupExportFailed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get backupImportAppData => 'App-Daten importieren';

  @override
  String get backupImportAppDataSubtitle =>
      'Daten aus einer Sicherung wiederherstellen (ersetzt alle vorhandenen Daten)';

  @override
  String get backupManageBackups => 'Sicherungen verwalten';

  @override
  String get backupManageBackupsSubtitle =>
      'App-Datensicherungen erstellen, wiederherstellen und verwalten';

  @override
  String get backupAutomaticBackups => 'Automatische Sicherungen';

  @override
  String get backupAutoBackup => 'Automatische Sicherung';

  @override
  String get backupAutoBackupSubtitle => 'Häufigkeit der Sicherung';

  @override
  String get backupAutoBackupContent => 'Inhalt automatischer Sicherungen';

  @override
  String get backupAutoBackupContentSubtitle =>
      'Welche Daten in automatische Sicherungen aufgenommen werden';

  @override
  String get backupAutoBackupContentDialogSubtitle =>
      'Inhalte für automatische Sicherungen auswählen';

  @override
  String get backupSave => 'Speichern';

  @override
  String get backupAutoDeleteOld => 'Alte Sicherungen automatisch löschen';

  @override
  String get backupAutoDeleteOldSubtitle =>
      'Sicherungen löschen, die älter sind als';

  @override
  String get backupFrequencyDisabled => 'Deaktiviert';

  @override
  String get backupFrequencyEvery24Hours => 'Alle 24 Stunden';

  @override
  String get backupFrequencyEvery48Hours => 'Alle 48 Stunden';

  @override
  String get backupFrequencyEvery3Days => 'Alle 3 Tage';

  @override
  String get backupFrequencyEvery7Days => 'Alle 7 Tage';

  @override
  String backupDeleteAfterDays(int count) {
    return '$count Tage';
  }

  @override
  String get backupExportOptionsTitle => 'Exportoptionen';

  @override
  String get backupExportSelectContent => 'Zu exportierende Inhalte auswählen:';

  @override
  String get backupContentUserStats => 'Nutzerstatistiken';

  @override
  String get backupContentUserStatsSubtitle =>
      'Wiedergabezahlen, Sitzungen und weitere Statistiken';

  @override
  String get backupContentUserData => 'Nutzerdaten';

  @override
  String get backupContentUserDataSubtitle =>
      'Favoriten, ausgeblendete Songs, Playlists';

  @override
  String get backupContentUserSettings => 'Nutzereinstellungen';

  @override
  String get backupContentUserSettingsSubtitle =>
      'Design, Sortierung und Einstellungen';

  @override
  String get backupContentCoverCacheSubtitle => 'Albumcoverbilder';

  @override
  String get backupContentLibraryCacheSubtitle =>
      'Zwischengespeicherte Songmetadaten';

  @override
  String get backupContentSearchIndexSubtitle => 'Indizierte Suchdaten';

  @override
  String get backupContentWaveformCacheSubtitle =>
      'Audiodaten der Wellenformen';

  @override
  String get backupContentColorCacheSubtitle => 'Album-Farbdesigns';

  @override
  String get backupContentLyricsCacheSubtitle => 'Gespeicherte Liedtexte';

  @override
  String get backupCancelUpper => 'ABBRECHEN';

  @override
  String get backupExportUpper => 'EXPORTIEREN';

  @override
  String get backupContinueUpper => 'WEITER';

  @override
  String get backupImportDataTitle => 'Daten importieren';

  @override
  String get backupImportWarning =>
      'Dadurch werden ALLE vorhandenen Daten durch die importierten Daten ersetzt.\n\nDeine aktuellen Statistiken, Favoriten, Playlists und Einstellungen werden überschrieben.\n\nDies kann nicht rückgängig gemacht werden.';

  @override
  String get backupImportingLabel => 'Wird importiert …';

  @override
  String get backupImportingTitle => 'Daten werden importiert';

  @override
  String get backupImportSuccess => 'Import erfolgreich!';

  @override
  String backupImportFailed(Object error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get metadataCoverUpdated => 'Cover erfolgreich aktualisiert';

  @override
  String metadataPickImageError(Object error) {
    return 'Fehler beim Auswählen des Bildes: $error';
  }

  @override
  String get metadataRemoveCoverTitle => 'Cover entfernen';

  @override
  String get metadataRemoveCoverBody =>
      'Möchtest du das Coverbild wirklich entfernen?';

  @override
  String get metadataRemoveUpper => 'ENTFERNEN';

  @override
  String get metadataCoverRemoved => 'Cover entfernt';

  @override
  String metadataRemoveCoverError(Object error) {
    return 'Fehler beim Entfernen des Covers: $error';
  }

  @override
  String get metadataFixResultTitle => 'Ergebnis der Thumbnail-Korrektur';

  @override
  String get metadataFixReviewBody => 'Änderungen unten überprüfen:';

  @override
  String get metadataFixOriginal => 'Originalversion';

  @override
  String get metadataFixNew => 'Neu';

  @override
  String metadataFixNewOption(int n) {
    return 'Neu (Option $n)';
  }

  @override
  String get metadataFixSeeAlternatives => 'Alternativen anzeigen';

  @override
  String get metadataFixApply => 'Anwenden';

  @override
  String get metadataFixSuccess => 'Thumbnail erfolgreich korrigiert';

  @override
  String metadataFixError(Object error) {
    return 'Fehler beim Korrigieren des Thumbnails: $error';
  }

  @override
  String get metadataFixThumbnail => 'Thumbnail korrigieren';

  @override
  String get metadataFixHelpBody =>
      'Dieses Werkzeug verbessert dein Albumcover automatisch:\n\n1. Schwarze Balken und Ränder erkennen und entfernen (häufig bei YouTube-Thumbnails)\n2. Bild quadratisch zuschneiden (Seitenverhältnis 1:1)\n\nIdeal, um 16:9-Thumbnails in passende Albumcover umzuwandeln.';

  @override
  String get metadataGotIt => 'Verstanden';

  @override
  String get metadataExportCover => 'Cover exportieren';

  @override
  String get metadataExport => 'Exportieren';

  @override
  String metadataExportSuccess(Object uri) {
    return 'Cover exportiert nach $uri';
  }

  @override
  String metadataExportError(Object error) {
    return 'Fehler beim Exportieren des Covers: $error';
  }

  @override
  String get metadataReplaceSong => 'Song ersetzen';

  @override
  String get metadataReplaceHelpBody =>
      'Ersetzt die Datei dieses Songs durch eine andere Kopie desselben Songs (besserer Rip, verlustfrei, saubere Kodierung).\n\nWiedergabeverlauf, Favoriten, Playlists und das Datum in der Bibliothek werden auf die neue Datei übertragen. Ihre Metadaten werden erneut aus der Datei gelesen; fehlende Angaben werden als unbekannt angezeigt.\n\nDie neue Datei muss außerhalb deiner Bibliotheksordner liegen und einen anderen Dateinamen haben.';

  @override
  String metadataReplaced(Object filename) {
    return 'Ersetzt durch $filename';
  }

  @override
  String metadataReplaceError(Object error) {
    return 'Datei konnte nicht ersetzt werden: $error';
  }

  @override
  String metadataReplaceFilesBody(Object oldName, Object newName) {
    return '$oldName\nwird ersetzt durch $newName';
  }

  @override
  String get metadataReplaceOriginalQuestion =>
      'Was soll mit dem Original geschehen?';

  @override
  String get metadataReplaceRejectNoFile => 'Es wurde keine Datei ausgewählt.';

  @override
  String get metadataReplaceRejectUnsupported =>
      'Dieses Audio- oder Videoformat kann von der Bibliothek nicht gelesen werden.';

  @override
  String get metadataReplaceRejectSameFilename =>
      'Der Ersatz benötigt einen anderen Dateinamen. Nur die Dateiendung zu ändern reicht nicht.';

  @override
  String get metadataReplaceRejectInsideLibrary =>
      'Diese Datei befindet sich in einem deiner Bibliotheksordner. Wähle eine Kopie außerhalb deiner Bibliothek.';

  @override
  String metadataReplaceRejectDestinationExists(String filename) {
    return 'Eine Datei namens „$filename“ befindet sich bereits neben dem Original.';
  }

  @override
  String metadataReplaceRejectLibraryHasName(String filename) {
    return 'Deine Bibliothek enthält bereits einen Song namens „$filename“.';
  }

  @override
  String get metadataKeepHideUpper => 'BEHALTEN UND AUSBLENDEN';

  @override
  String get metadataDeleteItUpper => 'LÖSCHEN';

  @override
  String get metadataSaved => 'Metadaten erfolgreich aktualisiert';

  @override
  String metadataSaveError(Object error) {
    return 'Fehler beim Speichern der Metadaten: $error';
  }

  @override
  String get metadataNoOnlineCover => 'Kein Online-Coverbild gefunden';

  @override
  String get metadataSelectCoverTitle => 'Coverbild auswählen';

  @override
  String metadataResultTitleArtist(Object title, Object artist) {
    return '$title – $artist';
  }

  @override
  String metadataSourceLabel(Object source) {
    return 'Quelle: $source';
  }

  @override
  String metadataCoverUpdatedFrom(Object source) {
    return 'Cover aktualisiert von $source';
  }

  @override
  String get metadataNoOnlineMatch =>
      'Keine passenden Metadaten online gefunden';

  @override
  String get metadataSelectMatchTitle => 'Online-Treffer auswählen';

  @override
  String metadataResultDetail(Object artist, Object album, Object source) {
    return '$artist · $album ($source)';
  }

  @override
  String metadataLoadedFrom(Object source) {
    return 'Metadaten und Cover von $source geladen';
  }

  @override
  String metadataFetchError(Object error) {
    return 'Fehler beim Abrufen der Metadaten: $error';
  }

  @override
  String get metadataSectionCover => 'Coverbild';

  @override
  String get metadataChangeCover => 'Cover ändern';

  @override
  String get metadataWhatDoesThisDo => 'Was bewirkt das?';

  @override
  String get metadataSectionFile => 'Dateiinformationen';

  @override
  String get metadataFilenameLabel => 'Dateiname (ohne Erweiterung)';

  @override
  String get metadataFilenameHelper =>
      'Durch das Umbenennen der Datei wird sie lokal aktualisiert.';

  @override
  String get metadataSectionSong => 'Songmetadaten';

  @override
  String get metadataFetchOnline => 'Online abrufen';

  @override
  String get metadataTitleLabel => 'Titel';

  @override
  String get metadataArtistLabel => 'Interpret';

  @override
  String get metadataAlbumLabel => 'Album';

  @override
  String get metadataSectionExtra => 'Zusätzliche Inhalte';

  @override
  String get metadataEditLyrics => 'Liedtext bearbeiten';

  @override
  String get metadataEditLyricsSubtitle =>
      'Eingebetteten Liedtext anzeigen oder bearbeiten';

  @override
  String get metadataSaveUpper => 'SPEICHERN';

  @override
  String metadataLyricsLoadError(Object error) {
    return 'Fehler beim Laden des Liedtexts: $error';
  }

  @override
  String metadataLyricsSaveError(Object error) {
    return 'Fehler beim Speichern des Liedtexts: $error';
  }

  @override
  String get metadataLyricsLoaded =>
      'Liedtext geladen — zum Anwenden auf SPEICHERN drücken';

  @override
  String get metadataSearchOnline => 'Online suchen';

  @override
  String get metadataLyricsHint =>
      'Der Liedtext ist in der Audiodatei eingebettet. Für synchronisierte Liedtexte kannst du Zeitmarken wie [mm:ss.xx] verwenden.';

  @override
  String get metadataLyricsFieldHint => 'Liedtext hier eingeben …';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileAvatarFallback => 'N';

  @override
  String get profileDefaultName => 'Nutzer';

  @override
  String get appName => 'wispie';

  @override
  String profileAppVersion(String version) {
    return 'wispie v$version';
  }

  @override
  String get profileHidden => 'Ausgeblendet';

  @override
  String get profileSuggestLess => 'Seltener vorschlagen';

  @override
  String get profileShuffleSection => 'Zufällige Wiedergabe';

  @override
  String get profileSmart => 'Intelligente Zufallswiedergabe';

  @override
  String get profileSmartSubtitle =>
      'Lernt deinen Geschmack, Trends und Kontext kennen';

  @override
  String get profileChangeName => 'Anzeigenamen ändern';

  @override
  String get profileNewNameHint => 'Neuer Name';

  @override
  String get profileUpdate => 'Aktualisieren';

  @override
  String get profileNameUpdated => 'Name aktualisiert';

  @override
  String profileCurrentName(String name) {
    return 'Aktuell: $name';
  }

  @override
  String get profileThemeStorage => 'Design und Speicher';

  @override
  String get profileFamiliar => 'Vertraut';

  @override
  String get profileDiscover => 'Entdecken';

  @override
  String get profileFamiliarToDiscover => 'Vertraut bis Entdecken';

  @override
  String get storageManageTitle => 'Speicher verwalten';

  @override
  String get storageRepairCardTitle => 'Bibliotheksverknüpfungen reparieren';

  @override
  String get storageRepairCardBody =>
      'Fehlen Albumcover nach einer Wiederherstellung oder auf einem neuen Smartphone? Hiermit werden Cover und Dateipfade erneut verknüpft.';

  @override
  String get storageRepair => 'Reparieren';

  @override
  String get storageRepairTitle => 'Bibliotheksverknüpfungen reparieren?';

  @override
  String get storageRepairBody =>
      'Hiermit werden zwischengespeicherte Albumcover und Dateipfade mit ihrem tatsächlichen Speicherort auf diesem Gerät verknüpft.\n\nTitel, deren Dateien nicht mehr vorhanden sind, werden aus der Bibliothek entfernt. Favoriten, Playlists und Wiedergabezahlen bleiben erhalten und werden bei Rückkehr der Dateien automatisch wieder verknüpft.';

  @override
  String storageRepairError(Object error) {
    return 'Fehler beim Reparieren der Bibliothek: $error';
  }

  @override
  String get storageDatabaseTitle => 'Datenbank';

  @override
  String get storageDatabaseSubtitle =>
      'Nutzerdaten, Statistiken und Einstellungen';

  @override
  String get storageCoverCacheTitle => 'Covercache';

  @override
  String get storageCoverCacheSubtitle => 'Zwischengespeicherte Songcover';

  @override
  String get storageBackupsTitle => 'Sicherungen';

  @override
  String get storageBackupsSubtitle => 'Lokale Sicherungsdateien';

  @override
  String get storageLibraryCacheTitle => 'Bibliothekscache';

  @override
  String get storageLibraryCacheSubtitle =>
      'Zwischengespeicherte Songbibliotheksdaten';

  @override
  String get storageSearchIndexTitle => 'Suchindex';

  @override
  String get storageSearchIndexSubtitle => 'Suchindex für schnelle Abfragen';

  @override
  String get storageWaveformCacheTitle => 'Wellenformcache';

  @override
  String get storageWaveformCacheSubtitle =>
      'Zwischengespeicherte Songwellenformen für Visualisierungen';

  @override
  String get storageBeatAnalysisTitle => 'Beat-Analyse';

  @override
  String get storageBeatAnalysisSubtitle =>
      'Zwischengespeicherte Beatkarten für den reaktiven Player';

  @override
  String get storageColorCacheTitle => 'Farbcache';

  @override
  String get storageColorCacheSubtitle =>
      'Zwischengespeicherte Designfarben aus Albumcovern';

  @override
  String get storageLyricsCacheTitle => 'Liedtextcache';

  @override
  String get storageLyricsCacheSubtitle =>
      'Zwischengespeicherte Verfügbarkeit und Texte';

  @override
  String get storageOnlineAudioTitle => 'Online-Audiocache';

  @override
  String get storageOnlineAudioSubtitle =>
      'Gestreamte Titel für sofortige Offline-Wiedergabe auf dem Gerät gespeichert';

  @override
  String get storageClearOnlineAudioTitle => 'Online-Audiocache leeren?';

  @override
  String get storageClearOnlineAudioBody =>
      'Heruntergeladene Titel werden erneut aus dem Internet gestreamt. Deine Bibliothek, Playlists und Favoriten bleiben unverändert.';

  @override
  String get storageClearOnlineAudioSuccess => 'Online-Audiocache geleert';

  @override
  String storageClearOnlineAudioError(Object error) {
    return 'Fehler beim Leeren des Online-Audiocaches: $error';
  }

  @override
  String get storageBlurredCacheTitle => 'Weichzeichner-Cache';

  @override
  String get storageBlurredCacheSubtitle =>
      'Vorab erzeugte unscharfe Hintergründe';

  @override
  String get storageClearCache => 'Cache leeren';

  @override
  String get storageClearDatabaseTitle => 'Datenbank leeren?';

  @override
  String get storageClearDatabaseBody =>
      'Dadurch werden alle deine Nutzerdaten endgültig gelöscht, darunter:\n\n• alle Playlists\n• Favoriten und ausgeblendete Songs\n• Wiedergabestatistiken\n• App-Einstellungen und Präferenzen\n\nDie App wird zurückgesetzt. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get storageClearDatabaseAction => 'Datenbank leeren';

  @override
  String storageClearDatabaseError(Object error) {
    return 'Fehler beim Leeren der Datenbank: $error';
  }

  @override
  String get storageClearCoversTitle => 'Covercache leeren?';

  @override
  String get storageClearCoversBody =>
      'Dadurch werden alle zwischengespeicherten Albumcover gelöscht.\n\nDie Cover werden beim nächsten Durchsuchen deiner Bibliothek erneut aus den Musikdateien extrahiert.';

  @override
  String get storageClearCoversAction => 'Cover leeren';

  @override
  String get storageClearCoversSuccess => 'Covercache erfolgreich geleert';

  @override
  String storageClearCoversError(Object error) {
    return 'Fehler beim Leeren der Cover: $error';
  }

  @override
  String get storageClearBackupsTitle => 'Sicherungen löschen?';

  @override
  String get storageClearBackupsBody =>
      'Dadurch werden alle lokalen Sicherungsdateien gelöscht.\n\nExportiere wichtige Sicherungen, bevor du fortfährst.';

  @override
  String get storageClearBackupsAction => 'Sicherungen löschen';

  @override
  String get storageClearBackupsSuccess => 'Sicherungen erfolgreich gelöscht';

  @override
  String storageClearBackupsError(Object error) {
    return 'Fehler beim Löschen der Sicherungen: $error';
  }

  @override
  String get storageClearLibraryTitle => 'Bibliothekscache leeren?';

  @override
  String get storageClearLibraryBody =>
      'Dadurch wird der Bibliothekscache geleert.\n\nDeine Musikbibliothek wird beim nächsten Öffnen der App erneut eingelesen.';

  @override
  String get storageClearLibrarySuccess =>
      'Bibliothekscache erfolgreich geleert';

  @override
  String storageClearLibraryError(Object error) {
    return 'Fehler beim Leeren des Bibliothekscaches: $error';
  }

  @override
  String get storageClearSearchTitle => 'Suchindex leeren?';

  @override
  String get storageClearSearchBody =>
      'Dadurch wird der Suchindex gelöscht.\n\nBeim erneuten Einlesen deiner Bibliothek wird er automatisch neu erstellt.';

  @override
  String get storageClearSearchAction => 'Index leeren';

  @override
  String get storageClearSearchSuccess => 'Suchindex geleert';

  @override
  String storageClearSearchError(Object error) {
    return 'Fehler beim Leeren des Suchindex: $error';
  }

  @override
  String get storageClearWaveformTitle => 'Wellenformcache leeren?';

  @override
  String get storageClearWaveformBody =>
      'Dadurch werden alle zwischengespeicherten Songwellenformen gelöscht.\n\nSie werden beim nächsten Anzeigen der Songdetails neu erstellt.';

  @override
  String get storageClearWaveformSuccess => 'Wellenformcache geleert';

  @override
  String storageClearWaveformError(Object error) {
    return 'Fehler beim Leeren des Wellenformcaches: $error';
  }

  @override
  String get storageClearBeatTitle => 'Beat-Analyse leeren?';

  @override
  String get storageClearBeatBody =>
      'Dadurch werden die zwischengespeicherten Beatkarten des beatreaktiven Players gelöscht.\n\nSie werden automatisch bei der nächsten Wiedergabe jedes Songs neu erstellt.';

  @override
  String get storageClearBeatSuccess => 'Beat-Analysecache geleert';

  @override
  String storageClearBeatError(Object error) {
    return 'Fehler beim Leeren des Beat-Analysecaches: $error';
  }

  @override
  String get storageClearColorTitle => 'Farbcache leeren?';

  @override
  String get storageClearColorBody =>
      'Dadurch werden alle zwischengespeicherten Designfarben gelöscht.\n\nDie Farben werden bei der nächsten Wiedergabe erneut aus den Albumcovern extrahiert.';

  @override
  String get storageClearColorSuccess => 'Farbcache erfolgreich geleert';

  @override
  String storageClearColorError(Object error) {
    return 'Fehler beim Leeren des Farbcaches: $error';
  }

  @override
  String get storageClearLyricsTitle => 'Liedtextcache leeren?';

  @override
  String get storageClearLyricsBody =>
      'Dadurch werden zwischengespeicherte Liedtextabfragen entfernt.\n\nLiedtexte werden bei Bedarf erneut aus den Songmetadaten gelesen.';

  @override
  String get storageClearLyricsSuccess => 'Liedtextcache erfolgreich geleert';

  @override
  String storageClearLyricsError(Object error) {
    return 'Fehler beim Leeren des Liedtextcaches: $error';
  }

  @override
  String get storageClearBlurredTitle =>
      'Cache unscharfer Hintergründe leeren?';

  @override
  String get storageClearBlurredBody =>
      'Dadurch werden alle vorab erstellten unscharfen Hintergründe gelöscht.\n\nSie werden neu erstellt, wenn du im Indexierer einen Neuaufbau startest.';

  @override
  String get storageClearBlurredSuccess =>
      'Cache unscharfer Hintergründe geleert';

  @override
  String storageClearBlurredError(Object error) {
    return 'Fehler beim Leeren des Caches unscharfer Hintergründe: $error';
  }

  @override
  String get storageClearAllTitle => 'Alle App-Daten löschen?';

  @override
  String get storageClearAllBody =>
      'Diese Aktion ist gefährlich und kann nicht rückgängig gemacht werden.\n\nFolgende Daten werden endgültig gelöscht:\n• alle Einstellungen und Präferenzen\n• Wiedergabestatistiken und Verlauf\n• zwischengespeicherte Songcover\n• alle lokalen Sicherungen\n• Bibliothekscache\n• Suchindex\n• Wellenformcache\n• Liedtextcache\n\nDie App wird zurückgesetzt.';

  @override
  String get storageClearAllAction => 'Alles löschen';

  @override
  String storageClearAllError(Object error) {
    return 'Fehler beim Löschen der Daten: $error';
  }

  @override
  String get storageClearAllTile => 'Alle Nutzerdaten löschen';

  @override
  String get storageClearAllTileSubtitle =>
      'Alle Daten endgültig löschen und App zurücksetzen';

  @override
  String get storageFinalConfirmTitle => 'Letzte Bestätigung';

  @override
  String storageConfirmTypePrompt(Object word) {
    return 'Gib zur Bestätigung unten „$word“ ein:';
  }

  @override
  String get storageDeleteKeyword => 'LÖSCHEN';

  @override
  String get storageConfirmUpper => 'BESTÄTIGEN';

  @override
  String get storageTypeExactly => 'Bitte gib den Bestätigungstext genau ein.';

  @override
  String storageSizeBytes(Object value) {
    return '$value Byte';
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
  String get settingsSearchIndexerSubtitle => 'Indizes und Caches neu aufbauen';

  @override
  String get settingsSearchMusicFoldersTitle => 'Musikordner';

  @override
  String get settingsSearchMusicFoldersSubtitle =>
      'Musikbibliotheksordner verwalten';

  @override
  String get settingsSearchRescanTitle => 'Bibliothek jetzt erneut einlesen';

  @override
  String get settingsSearchRescanSubtitle =>
      'Alle Songs manuell von der Festplatte aktualisieren';

  @override
  String get settingsSearchIncludeVideosTitle => 'Videos einschließen';

  @override
  String get settingsSearchIncludeVideosSubtitle =>
      'Videodateien in der Songbibliothek anzeigen';

  @override
  String get settingsSearchMinFileSizeTitle => 'Mindestdateigröße';

  @override
  String get settingsSearchMinFileSizeSubtitle => 'Kleinere Dateien ignorieren';

  @override
  String get settingsSearchMinDurationTitle => 'Mindestdauer';

  @override
  String get settingsSearchMinDurationSubtitle => 'Kürzere Titel ignorieren';

  @override
  String get settingsSearchManageFoldersTitle => 'Musikordner verwalten';

  @override
  String get settingsSearchManageFoldersSubtitle =>
      'Einzelne Ordner hinzufügen, entfernen und erneut einlesen';

  @override
  String get settingsSearchPullToRefreshTitle => 'Zum Aktualisieren ziehen';

  @override
  String get settingsSearchPullToRefreshSubtitle =>
      'Nach unten wischen, um die Bibliothek zu aktualisieren';

  @override
  String get settingsSearchAutoPauseMuteTitle =>
      'Bei Stummschaltung automatisch pausieren';

  @override
  String get settingsSearchAutoPauseMuteSubtitle =>
      'Wiedergabe anhalten, wenn die Lautstärke 0 erreicht';

  @override
  String get settingsSearchAutoResumeUnmuteTitle =>
      'Bei Aufhebung der Stummschaltung fortsetzen';

  @override
  String get settingsSearchAutoResumeUnmuteSubtitle =>
      'Wiedergabe fortsetzen, wenn die Lautstärke wiederhergestellt wird';

  @override
  String get settingsSearchGapTitle => 'Abstand und Verzögerung';

  @override
  String get settingsSearchGapSubtitle => 'Stille zwischen Titeln';

  @override
  String get settingsSearchFadeOutTitle => 'Ausblenden';

  @override
  String get settingsSearchFadeOutSubtitle => 'Aktuellen Titel ausblenden';

  @override
  String get settingsSearchFadeInTitle => 'Einblenden';

  @override
  String get settingsSearchFadeInSubtitle => 'Nächsten Titel einblenden';

  @override
  String get settingsSearchFadePlayTitle => 'Beim Abspielen einblenden';

  @override
  String get settingsSearchFadePlaySubtitle =>
      'Lautstärke beim Start der Wiedergabe langsam erhöhen';

  @override
  String get settingsSearchFadePauseTitle => 'Beim Pausieren ausblenden';

  @override
  String get settingsSearchFadePauseSubtitle =>
      'Lautstärke beim Anhalten der Wiedergabe langsam verringern';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Sprache, in die Liedtexte übersetzt werden';

  @override
  String get settingsSearchTranslationModeSubtitle =>
      'Untertitel unter Liedtexten anzeigen oder ursprünglichen Liedtext ersetzen';

  @override
  String get settingsSearchVisualizerSubtitle =>
      'Aus, klassische Balken oder an den Song angepasste Balken';

  @override
  String get settingsSearchLanguageSubtitle => 'Sprache der App auswählen';

  @override
  String get settingsSearchProgressBarSubtitle =>
      'Standard-, Wellenform- oder klangreaktive Fortschrittsanzeige';

  @override
  String get settingsSearchSongDurationTitle => 'Songdauer anzeigen';

  @override
  String get settingsSearchSongDurationSubtitle =>
      'Dauer in Songlisten anzeigen';

  @override
  String get settingsSearchAutoHideBarsTitle =>
      'Leisten automatisch ausblenden';

  @override
  String get settingsSearchAutoHideBarsSubtitle =>
      'Kopfzeile und Leiste unten beim Abwärtsscrollen ausblenden';

  @override
  String get settingsSearchAppIconSubtitle => 'Symbol für wispie auswählen';

  @override
  String get settingsSearchBeatCoverSubtitle =>
      'Albumcover pulsiert im Takt (nur klassischer Player)';

  @override
  String get settingsSearchSpinArtworkSubtitle =>
      'Cover dreht sich während der Wiedergabe in der minimierten Leiste am unteren Rand';

  @override
  String get settingsSearchCoverIntensitySubtitle =>
      'Stärke der Beatreaktion des Albumcovers';

  @override
  String get settingsSearchParticleDensitySubtitle =>
      'Anzahl und Lebhaftigkeit der Partikel';

  @override
  String get settingsSearchBeatOffsetSubtitle =>
      'Latenz der Bluetooth-Ausgabe ausgleichen';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Schnelle Empfehlungen anzeigen';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Kürzlich abgespielte Warteschlangen anzeigen';

  @override
  String get settingsSearchForYouSubtitle => 'Empfohlene Playlists anzeigen';

  @override
  String get settingsSearchQuickActionsSubtitle =>
      'Aktionen bei langem Drücken anpassen';

  @override
  String get settingsSearchReorderQuickActionsTitle =>
      'Schnellaktionen neu anordnen';

  @override
  String get settingsSearchReorderQuickActionsSubtitle =>
      'Aktionen beim langen Drücken auf einen Song auswählen und sortieren';

  @override
  String get settingsSearchBulkRenameTitle => 'Dateien gesammelt umbenennen';

  @override
  String get settingsSearchBulkRenameSubtitle =>
      'Die gesamte Bibliothek anhand eines Formats umbenennen';

  @override
  String get settingsSearchManageStorageSubtitle =>
      'Speicherplatz und Datenverwaltung';

  @override
  String get settingsSearchBackupsSubtitle =>
      'Gespeicherte Sicherungen durchsuchen, wiederherstellen und löschen';

  @override
  String get settingsSearchStorageUsageSubtitle =>
      'Speicherplatz für Cover, Wellenformen, Liedtexte und Caches';

  @override
  String get settingsCrumbStorage => 'Einstellungen › Speicher';

  @override
  String get settingsCrumbLibrary => 'Einstellungen › Bibliothek';

  @override
  String get settingsCrumbLibraryFilters =>
      'Einstellungen › Bibliothek › Filter';

  @override
  String get settingsCrumbLibraryFolders =>
      'Einstellungen › Bibliothek › Musikordner';

  @override
  String get settingsCrumbLibraryMaintenance =>
      'Einstellungen › Bibliothek › Wartung';

  @override
  String get settingsCrumbPlaybackAudio => 'Einstellungen › Wiedergabe › Audio';

  @override
  String get settingsCrumbPlaybackTransitions =>
      'Einstellungen › Wiedergabe › Übergänge';

  @override
  String get settingsCrumbPlaybackPlayPause =>
      'Einstellungen › Wiedergabe › Abspielen / Pausieren';

  @override
  String get settingsCrumbLyricsTiming =>
      'Einstellungen › Liedtexte › Anzeige und Timing';

  @override
  String get settingsCrumbLyricsTranslation =>
      'Einstellungen › Liedtexte › Übersetzung';

  @override
  String get settingsCrumbAppearanceLanguage =>
      'Einstellungen › Darstellung › Sprache';

  @override
  String get settingsCrumbAppearanceNowPlaying =>
      'Einstellungen › Darstellung › Aktuelle Wiedergabe';

  @override
  String get settingsCrumbAppearanceAppIcon =>
      'Einstellungen › Darstellung › App-Symbol';

  @override
  String get settingsCrumbAppearanceMotion =>
      'Einstellungen › Darstellung › Player-Bewegung';

  @override
  String get settingsCrumbAppearanceLists =>
      'Einstellungen › Darstellung › Listen und Navigation';

  @override
  String get settingsCrumbHomeLists =>
      'Einstellungen › Startseite und Navigation › Listen und Navigation';

  @override
  String get settingsCrumbHomeScreen =>
      'Einstellungen › Startseite und Navigation › Startbildschirm';

  @override
  String get settingsCrumbBackup =>
      'Einstellungen › Sicherung und Wiederherstellung';

  @override
  String get settingsCrumbAutoBackups =>
      'Einstellungen › Sicherung und Wiederherstellung › Automatische Sicherungen';

  @override
  String get settingsCrumbManageBackups =>
      'Einstellungen › Datenverwaltung › Sicherungen verwalten';

  @override
  String get settingsCrumbManageStorage =>
      'Einstellungen › Datenverwaltung › Speicher verwalten';

  @override
  String get settingsKwLibrary => 'scannen,ordner,filter,songs';

  @override
  String get settingsKwPlayback => 'audio,ton,übergänge';

  @override
  String get settingsKwLyrics => 'liedtexte,übersetzen,karaoke,untertitel';

  @override
  String get settingsKwHome =>
      'startseite,schnellauswahl,gesten,leisten,layout';

  @override
  String get settingsKwStorage => 'speicher,platz,cache,indexierer,bereinigung';

  @override
  String get settingsKwAppearance => 'design,farbe,anzeige,aussehen';

  @override
  String get settingsKwSync => 'cloud,konto,geräte,verschlüsselt';

  @override
  String get settingsKwBackup =>
      'sicherung,wiederherstellen,export,import,daten';

  @override
  String get settingsKwIndexer => 'index,neuaufbau,cache,neu indizieren';

  @override
  String get settingsKwAbout =>
      'version,update,änderungsprotokoll,veröffentlichung';

  @override
  String get settingsKwFolders => 'verzeichnis,pfad,ordner hinzufügen,quellen';

  @override
  String get settingsKwRescan => 'aktualisieren,neu laden,synchronisieren';

  @override
  String get settingsKwVideos => 'videos,mp4,clips';

  @override
  String get settingsKwMinFileSize => 'größe,überspringen,klein,filter';

  @override
  String get settingsKwMinDuration =>
      'länge,kurz,überspringen,filter,zwischenstück';

  @override
  String get settingsKwManageFolders => 'ordner,verzeichnis,speicher,sd-karte';

  @override
  String get settingsKwPullToRefresh => 'wischen,geste,neu laden';

  @override
  String get settingsKwMute => 'lautstärke,stumm,stummschalten';

  @override
  String get settingsKwUnmute =>
      'lautstärke,stummschaltung aufheben,fortsetzen';

  @override
  String get settingsKwGap => 'pause,stille,zwischen,übergang';

  @override
  String get settingsKwCrossfade => 'überblenden,nahtlos,übergang,mischen';

  @override
  String get settingsKwFadePlay => 'ansteigen,lautstärke,start';

  @override
  String get settingsKwFadePause => 'absinken,lautstärke,stopp';

  @override
  String get settingsKwRichSync =>
      'liedtexte,richsync,karaoke,wort,synchronisierung';

  @override
  String get settingsKwSidebar =>
      'seitenleiste,bereich,desktop,warteschlange,liedtexte';

  @override
  String get settingsKwPlayerSwipe =>
      'wischen,geste,bereiche,liedtexte,warteschlange,überspringen,titel';

  @override
  String get settingsKwKeepAwake => 'schlaf,wachhalten,anzeige,liedtexte';

  @override
  String get settingsKwAutoTranslate =>
      'übersetzen,übersetzung,sprache,liedtexte,automatisch';

  @override
  String get settingsKwTargetLang =>
      'übersetzen,sprache,spanisch,englisch,japanisch';

  @override
  String get settingsKwTranslationMode =>
      'übersetzen,modus,untertitel,ersetzen,anzeige';

  @override
  String get settingsKwVisualizer =>
      'welle,animation,spektrum,balken,synchronisierung,bass';

  @override
  String get settingsKwLanguage => 'sprache,gebietsschema,übersetzung,englisch';

  @override
  String get settingsKwProgressBar =>
      'suchen,fortschritt,welle,reaktiv,spektrum';

  @override
  String get settingsKwHaptics =>
      'vibrieren,haptisch,feedback,wellenform,suchen,positionieren';

  @override
  String get settingsKwSongDuration => 'länge,zeit,listen';

  @override
  String get settingsKwAutoHide =>
      'navigation,leiste,kopfzeile,scrollen,ausblenden';

  @override
  String get settingsKwCoverSizing =>
      'cover,albumcover,seitenverhältnis,zuschneiden';

  @override
  String get settingsKwImmersive =>
      'immersiv,vollbild,player,details,verlauf,cover,design';

  @override
  String get settingsKwAppIcon => 'symbol,logo,launcher,dock,klassisch,neu';

  @override
  String get settingsKwBeatCover => 'puls,beat,cover,bewegung';

  @override
  String get settingsKwSpinArtwork => 'drehen,rotation,cover,dock,minimiert';

  @override
  String get settingsKwBeatParticles => 'partikel,beat,bewegung';

  @override
  String get settingsKwCoverIntensity =>
      'cover,album,puls,dezent,ausgewogen,kräftig';

  @override
  String get settingsKwParticleDensity =>
      'partikel,dichte,dezent,ausgewogen,kräftig';

  @override
  String get settingsKwBeatOffset =>
      'bluetooth,latenz,verzögerung,synchronisierung,früh';

  @override
  String get settingsKwCalibrate =>
      'kalibrieren,synchronisierung,latenz,versatz,test,klick';

  @override
  String get settingsKwQuickPicks => 'startseite,empfehlungen,vorschläge';

  @override
  String get settingsKwRecentQueues => 'startseite,verlauf,warteschlange';

  @override
  String get settingsKwForYou => 'startseite,mixe,empfehlungen';

  @override
  String get settingsKwQuickActions => 'lang drücken,menü,verknüpfungen';

  @override
  String get settingsKwReorderQuickActions =>
      'lang drücken,reihenfolge,menü,verknüpfungen';

  @override
  String get settingsKwExport => 'sicherung,speichern,export';

  @override
  String get settingsKwImport => 'wiederherstellen,laden,import';

  @override
  String get settingsKwManageBackups => 'sicherung,wiederherstellen,löschen';

  @override
  String get settingsKwBulkRename =>
      'umbenennen,dateinamen,stapel,mehrere,format,benennung';

  @override
  String get settingsKwBatchReplace =>
      'ersetzen,austauschen,verbessern,flac,verlustfrei,stapel,vergleichen,ordner,duplikat';

  @override
  String get settingsKwManageStorage => 'speicher,platz,cache,bereinigung';

  @override
  String get settingsKwBackups => 'sicherung,wiederherstellen,archiv';

  @override
  String get settingsKwStorageUsage => 'speicher,platz,cache leeren,nutzung';

  @override
  String get settingsKwAutoBackup => 'zeitplan,häufigkeit,automatisch';

  @override
  String get settingsKwAutoBackupContent => 'inhalte,kategorien,automatisch';

  @override
  String get settingsKwAutoDelete => 'aufräumen,bereinigung,aufbewahrung,alt';

  @override
  String get setupUnableToAccessFolder =>
      'Auf ausgewählten Ordner kann nicht zugegriffen werden';

  @override
  String get setupStoragePermissionRequired =>
      'Zum Einlesen deiner Musikbibliothek ist eine Speicherberechtigung erforderlich.';

  @override
  String get setupEnterDisplayName => 'Bitte gib einen Anzeigenamen ein';

  @override
  String setupSetupError(String error) {
    return 'Einrichtungsfehler: $error';
  }

  @override
  String get setupIntroTagline => 'Deine Musik bleibt auf deinem Gerät.';

  @override
  String get setupGetStarted => 'Los geht’s';

  @override
  String get setupPreviousStep => 'Vorheriger Schritt';

  @override
  String get setupSettingThingsUp => 'Einrichtung läuft';

  @override
  String get setupStartListening => 'Wiedergabe starten';

  @override
  String get setupContinue => 'Weiter';

  @override
  String get setupNameTitle => 'Wie dürfen wir dich nennen?';

  @override
  String get setupNameSubtitle =>
      'wispie verwendet deinen Namen für die Begrüßung und in deinem Wiedergabeverlauf. In jedem Fall bleiben deine Daten auf diesem Gerät.';

  @override
  String get setupNameHint => 'Dein Name';

  @override
  String setupGreeting(String name) {
    return 'Schön, dich kennenzulernen, $name.';
  }

  @override
  String get setupAppearanceTitle => 'Gestalte die App nach deinem Geschmack.';

  @override
  String get setupAppearanceSubtitle =>
      'Alle Einstellungen auf dieser Seite findest du auch in den Einstellungen und kannst sie jederzeit ändern.';

  @override
  String get setupImmersiveSubtitle =>
      'Ein Player mit vollflächigem Cover und Detailseiten mit Farbverlauf.';

  @override
  String get setupVisualizerSubtitle =>
      'Balken über dem Cover beim Hören. Die synchronisierte Ansicht folgt dem Song statt einem zufälligen Muster.';

  @override
  String get setupBeatCoverSubtitle =>
      'Das Albumcover pulsiert mit jedem Beat.';

  @override
  String get setupParticlesSubtitle =>
      'Partikel treiben über den Player und werden mit jedem Beat weitergetragen, statt nur aufzublinken.';

  @override
  String get setupProgressBarTitle => 'Fortschrittsanzeige';

  @override
  String get setupProgressBarSubtitle =>
      'Zeigt den Song als Wellenform statt als einfache Linie. Die klangreaktive Ansicht bewegt sich während der Wiedergabe.';

  @override
  String get setupFoldersTitle => 'Wo befindet sich deine Musik?';

  @override
  String get setupFoldersSubtitle =>
      'Wähle die Ordner mit deinen Songs aus. wispie liest sie nur ein; du kannst beliebig viele hinzufügen.';

  @override
  String get setupStoragePermissionTitle => 'Speicherberechtigung';

  @override
  String get setupStoragePermissionSubtitle =>
      'wispie benötigt diese Berechtigung, um Audiodateien auf diesem Gerät zu finden.';

  @override
  String get setupOpenSystemSettings => 'Systemeinstellungen öffnen';

  @override
  String get setupGrantPermission => 'Berechtigung erteilen';

  @override
  String get setupNoFoldersTitle => 'Noch keine Ordner';

  @override
  String get setupNoFoldersSubtitle =>
      'Füge den Ordner mit deinen Songs hinzu.';

  @override
  String get setupRemoveFolderTooltip => 'Ordner entfernen';

  @override
  String get setupAddFolder => 'Ordner hinzufügen';

  @override
  String get setupSummaryMusicFolders => 'Musikordner';

  @override
  String get setupReadyTitle => 'Alles ist eingerichtet.';

  @override
  String setupReadyTitleNamed(String name) {
    return 'Alles ist eingerichtet, $name.';
  }

  @override
  String get setupReadySubtitle =>
      'Das haben wir eingerichtet. Du kannst alles später in den Einstellungen ändern.';

  @override
  String get setupOn => 'Ein';

  @override
  String get setupOff => 'Aus';

  @override
  String backupLoadError(Object error) {
    return 'Fehler beim Laden der Sicherungen: $error';
  }

  @override
  String backupCreated(Object name) {
    return 'Sicherung erstellt: $name';
  }

  @override
  String backupCreateFailed(Object error) {
    return 'Sicherung konnte nicht erstellt werden: $error';
  }

  @override
  String backupValidateFailed(Object error) {
    return 'Sicherung konnte nicht überprüft werden: $error';
  }

  @override
  String get backupReplaceTitle => 'GEFAHR: Alle Daten ersetzen';

  @override
  String backupReplaceConfirm(Object name) {
    return 'Möchtest du wirklich die Sicherung $name wiederherstellen?';
  }

  @override
  String get backupReplaceWarning =>
      'WARNUNG: Dadurch werden ALLE aktuellen Daten VOLLSTÄNDIG ERSETZT:';

  @override
  String get backupReplaceItemStats =>
      '• alle aktuellen Statistiken und der Wiedergabeverlauf';

  @override
  String get backupReplaceItemFavorites => '• alle Favoriten und Playlists';

  @override
  String get backupReplaceItemHidden =>
      '• alle ausgeblendeten Songs und Präferenzen';

  @override
  String get backupReplaceItemSettings =>
      '• alle aktuellen Einstellungen und Zustände';

  @override
  String get backupReplaceItemLibrary => '• deine eingelesene Songbibliothek';

  @override
  String get backupReplaceRekeyNote =>
      'Albumcover und Dateipfade werden nach der Wiederherstellung automatisch mit diesem Gerät verknüpft. Titel in der Sicherung, deren Dateien sich nicht auf diesem Gerät befinden, werden aus der Bibliothek entfernt.';

  @override
  String get backupReplaceIrreversible =>
      'DEINE AKTUELLEN DATEN GEHEN ENDGÜLTIG VERLOREN!';

  @override
  String get backupReplaceNoUndo =>
      'DIESE AKTION KANN NICHT RÜCKGÄNGIG GEMACHT WERDEN.';

  @override
  String get backupReplaceConfirmAction => 'JA, ALLES ERSETZEN';

  @override
  String get backupRestoringLabel => 'Daten werden wiederhergestellt …';

  @override
  String get backupRestoreSuccess => 'Alle Daten erfolgreich ersetzt!';

  @override
  String backupRestoreFailed(Object error) {
    return 'Sicherung konnte nicht wiederhergestellt werden: $error';
  }

  @override
  String get backupRestoreReloadingLibrary => 'Bibliothek wird neu geladen …';

  @override
  String get backupRestoreRefreshingPlaylists =>
      'Playlists und Mixe werden aktualisiert …';

  @override
  String get backupDeleteTitle => 'Sicherung löschen';

  @override
  String backupDeleteConfirm(Object name) {
    return 'Möchtest du $name wirklich löschen?';
  }

  @override
  String get backupDeleteUpper => 'LÖSCHEN';

  @override
  String get backupDeleted => 'Sicherung gelöscht';

  @override
  String backupDeleteFailed(Object error) {
    return 'Sicherung konnte nicht gelöscht werden: $error';
  }

  @override
  String backupExportedTo(Object path) {
    return 'Sicherung exportiert nach: $path';
  }

  @override
  String get backupNoOlderBackup =>
      'Keine ältere Sicherung zum Vergleichen vorhanden.';

  @override
  String get backupComparing => 'Sicherungen werden verglichen …';

  @override
  String backupComparisonTitle(int number) {
    return 'Vergleich mit Nr. $number';
  }

  @override
  String get backupDiffStatsRows => 'Statistikzeilen';

  @override
  String get backupDiffSize => 'Größe';

  @override
  String get backupDiffDataAdded => 'Hinzugefügte Daten';

  @override
  String get backupCloseUpper => 'SCHLIESSEN';

  @override
  String backupCompareError(Object error) {
    return 'Fehler beim Vergleichen der Sicherungen: $error';
  }

  @override
  String get backupNoChange => 'Keine Änderung';

  @override
  String get backupManagementTitle => 'Sicherungsverwaltung';

  @override
  String get backupCreating => 'Wird erstellt …';

  @override
  String get backupCreateAction => 'Sicherung erstellen';

  @override
  String get backupEmptyTitle => 'Noch keine Sicherungen';

  @override
  String get backupEmptySubtitle =>
      'Erstelle deine erste Sicherung, um deine Daten zu schützen';

  @override
  String backupSizeLabel(Object size) {
    return 'Größe: $size';
  }

  @override
  String get backupActionRestore => 'Wiederherstellen';

  @override
  String get backupActionCompare => 'Vergleichen';

  @override
  String get backupRestartTitle => 'Neustart erforderlich';

  @override
  String get backupRestartMessage =>
      'Die Sicherung wurde erfolgreich wiederhergestellt.\n\nDie App muss neu gestartet werden, damit alle Änderungen übernommen werden.';

  @override
  String get backupRestartNow => 'Jetzt neu starten';

  @override
  String get backupSelectContentSubtitle => 'Zu sichernde Inhalte auswählen';

  @override
  String get backupContentArtistArtCache => 'Interpretencover-Cache';

  @override
  String get backupContentAlbumArtCache => 'Albumcover-Cache';

  @override
  String get backupContentDescUserStats =>
      'Wiedergabeverlauf, Statistiken, zusammengeführte Gruppen';

  @override
  String get backupContentDescUserData => 'Favoriten, Playlists, Präferenzen';

  @override
  String get backupContentDescUserSettings =>
      'Design, Sortierung, App-Präferenzen';

  @override
  String get backupContentDescCoverCache => 'Zwischengespeicherte Albumcover';

  @override
  String get backupContentDescLibraryCache => 'Zwischengespeicherte Metadaten';

  @override
  String get backupContentDescSearchIndex => 'Suchdatenbank';

  @override
  String get backupContentDescWaveformCache => 'Wellenformdaten';

  @override
  String get backupContentDescColorCache => 'Farbpaletten';

  @override
  String get backupContentDescLyricsCache => 'Zwischengespeicherte Liedtexte';

  @override
  String get backupContentDescArtistArtCache =>
      'Zwischengespeicherte Interpretenbilder';

  @override
  String get backupContentDescAlbumArtCache =>
      'Zwischengespeicherte Albumcoverbilder';

  @override
  String get backupRestoringDataTitle => 'Daten werden wiederhergestellt';

  @override
  String get importSelectTitle => 'Wiederherzustellende Daten auswählen';

  @override
  String get importSectionCache => 'Zwischenspeicher';

  @override
  String get importOptionsTitle => 'Wiederherstellungsoptionen';

  @override
  String get importReplaceDatabases => 'Datenbanken ersetzen';

  @override
  String get importReplaceDatabasesSubtitle =>
      'Vor der Wiederherstellung vorhandene Daten löschen';

  @override
  String get syncEnterPassword => 'Gib dein Passwort ein';

  @override
  String syncAuthUnexpectedError(String error) {
    return 'Es ist ein Fehler aufgetreten: $error';
  }

  @override
  String get syncUsernameTaken => 'Dieser Benutzername ist bereits vergeben';

  @override
  String get syncModeRecover => 'Wiederherstellen';

  @override
  String get syncUsername => 'Benutzername';

  @override
  String get syncEncryptionWarning =>
      'Deine Daten sind Ende-zu-Ende-verschlüsselt. Wenn du sowohl dein Passwort als auch den Wiederherstellungsschlüssel verlierst, können die Daten nicht wiederhergestellt werden.';

  @override
  String get syncSecuringAccount => 'Konto wird geschützt …';

  @override
  String get syncCreateAccount => 'Konto erstellen';

  @override
  String get syncLogIn => 'Anmelden';

  @override
  String get syncRecoverAccount => 'Konto wiederherstellen';

  @override
  String get syncHideAdvanced => 'Erweiterte Optionen ausblenden';

  @override
  String get syncAdvanced => 'Erweitert';

  @override
  String get syncRecoveryKeySaved => 'Wiederherstellungsschlüssel gespeichert';

  @override
  String get syncCouldNotSaveFile => 'Datei konnte nicht gespeichert werden';

  @override
  String get syncRecoveryKeyRevealTitle => 'Dein Wiederherstellungsschlüssel';

  @override
  String get syncRecoveryKeyRevealBody =>
      'Nur damit kannst du den Zugriff wiederherstellen, falls du dein Passwort vergisst. Er wird nur einmal angezeigt. Bewahre ihn an einem sicheren Ort auf.';

  @override
  String get syncCopied => 'Kopiert';

  @override
  String get syncCopy => 'Kopieren';

  @override
  String get syncSaveToFile => 'In Datei speichern';

  @override
  String get syncRecoveryKeySavedCheckbox =>
      'Ich habe meinen Wiederherstellungsschlüssel gespeichert';

  @override
  String get syncUploadTitle => 'Bibliotheksdaten hochladen';

  @override
  String get syncSetupDeviceTitle => 'Dieses Gerät einrichten';

  @override
  String get syncFreshAccountBody =>
      'Die automatische Synchronisierung wird aktiviert, sobald deine Daten einmal hochgeladen wurden.';

  @override
  String get syncChooseDeviceBody =>
      'Wähle, wie dieses Gerät in deine Cloud-Daten aufgenommen werden soll. Die automatische Synchronisierung wird danach aktiviert.';

  @override
  String get syncEverythingNow => 'Jetzt alles synchronisieren';

  @override
  String get syncMergeWithCloud => 'Dieses Gerät mit der Cloud zusammenführen';

  @override
  String get syncSetupNewDevice => 'Als neues Gerät einrichten';

  @override
  String get syncMergeExplanation =>
      'Beim Zusammenführen bleiben beide Seiten erhalten. Bei der Einrichtung als neues Gerät werden zuerst die synchronisierten Daten auf diesem Gerät gelöscht. Das ist sicherer, wenn sich hier bereits eine ältere Kopie desselben Verlaufs befindet.';

  @override
  String get syncCloudReplacedTitle => 'Cloud-Daten wurden ersetzt';

  @override
  String get syncCloudReplacedBody =>
      'Ein anderes Gerät hat die Cloud überschrieben. Die Synchronisierung auf diesem Gerät ist pausiert, bis du eine Auswahl triffst.';

  @override
  String get syncMergeIntoCloud =>
      'Dieses Gerät mit den neuen Cloud-Daten zusammenführen';

  @override
  String get syncPhaseSigningIn => 'Anmeldung läuft …';

  @override
  String get syncPhaseCheckingCloud => 'Cloud wird überprüft …';

  @override
  String get syncPhaseDownloadingBackup => 'Sicherung wird heruntergeladen …';

  @override
  String get syncPhaseApplyingBackup => 'Sicherung wird angewendet …';

  @override
  String get syncPhaseDownloadingChanges =>
      'Änderungen werden heruntergeladen …';

  @override
  String get syncPhaseMerging => 'Daten werden zusammengeführt …';

  @override
  String get syncPhasePreparingUpload => 'Upload wird vorbereitet …';

  @override
  String get syncPhaseEncrypting => 'Verschlüsselung läuft …';

  @override
  String get syncPhaseUploading => 'Upload läuft …';

  @override
  String get syncPhaseFinishing => 'Wird abgeschlossen …';

  @override
  String get syncPhaseError => 'Synchronisierung fehlgeschlagen';

  @override
  String get syncSyncing => 'Wird synchronisiert …';

  @override
  String syncServerInfo(String name, String version) {
    return '$name – API v$version';
  }

  @override
  String syncServerInfoClosed(String name, String version) {
    return '$name – API v$version – Registrierung geschlossen';
  }

  @override
  String get syncServerUnreachable => 'Server nicht erreichbar';

  @override
  String get syncInsecureHttpWarning =>
      'Unverschlüsseltes HTTP: nur in einem vertrauenswürdigen privaten Netzwerk verwenden';

  @override
  String get syncServerUrl => 'Server-URL';

  @override
  String get syncChecking => 'Wird überprüft …';

  @override
  String get syncCheckServer => 'Server überprüfen';

  @override
  String get syncResetDefault => 'Auf Standard zurücksetzen';

  @override
  String get autoBackupRunningTitle => 'Sicherung läuft';

  @override
  String get autoBackupRunningSubtitle => 'Sicherung wird erstellt …';

  @override
  String get autoBackupCompleteTitle => 'Automatische Sicherung abgeschlossen';

  @override
  String get autoBackupSaved => 'Sicherung gespeichert';

  @override
  String get autoBackupFailedTitle => 'Automatische Sicherung fehlgeschlagen';

  @override
  String get autoBackupPermissionTitle => 'Berechtigung erforderlich';

  @override
  String get autoBackupPermissionSubtitle =>
      'Automatische Sicherung benötigt Speicherzugriff';

  @override
  String get autoBackupGrant => 'Erteilen';

  @override
  String get downgradeTitle => 'Ältere Version erkannt';

  @override
  String downgradeMessage(String previousVersion, String currentVersion) {
    return 'wispie wurde zuletzt mit $previousVersion geöffnet, aktuell ist $currentVersion installiert. Deine Daten wurden möglicherweise von einer neueren Version geändert und könnten in dieser Version beschädigt werden oder verloren gehen.';
  }

  @override
  String get downgradeQuit => 'Beenden';

  @override
  String get downgradeRiskIt => 'Trotzdem fortfahren';

  @override
  String get indexerSettingsGroupTitle => 'Indexierereinstellungen';

  @override
  String get indexerPreventDuplicatesTitle => 'Doppelte Titel vermeiden';

  @override
  String get indexerPreventDuplicatesSubtitle =>
      'Songs mit demselben Dateinamen in mehreren Ordnern ausblenden';

  @override
  String get indexerExtractFeaturedTitle => 'Gastinterpreten erkennen';

  @override
  String get indexerExtractFeaturedSubtitle =>
      'Interpretenangaben mit „ft./feat.“ aus dem Titel in das Interpretenfeld verschieben';

  @override
  String get indexerDatabaseOpsGroupTitle => 'Datenbankvorgänge';

  @override
  String get indexerWarnRestart =>
      'Diese Aktion erfordert einen Neustart der App, damit die Änderungen übernommen werden.';

  @override
  String get indexerCoverSearchGroupTitle => 'Cover und Suche';

  @override
  String get indexerWarnRepairLinks =>
      'Titel, deren Dateien sich nicht mehr auf diesem Gerät befinden, werden aus der Bibliothek entfernt. Favoriten, Playlists und Wiedergabezahlen bleiben erhalten und werden bei Rückkehr der Dateien erneut verknüpft.';

  @override
  String get indexerWarnSearchRestart =>
      'Möglicherweise musst du die App neu starten, damit die Änderungen am Suchindex vollständig übernommen werden.';

  @override
  String get indexerContentCachesGroupTitle => 'Inhaltscaches';

  @override
  String get indexerRecommendationsGroupTitle => 'Empfehlungen';

  @override
  String get indexerTitle => 'Indexierer';

  @override
  String indexerArtistsAlbumsProgress(String artists, String albums) {
    return 'Interpreten $artists · Alben $albums …';
  }

  @override
  String indexerProcessing(String progress) {
    return 'Wird verarbeitet $progress …';
  }

  @override
  String get indexerUnknownError => 'Unbekannter Fehler';

  @override
  String get indexerCompleted => 'Abgeschlossen';

  @override
  String indexerCached(int processed, int total) {
    return '$processed/$total zwischengespeichert';
  }

  @override
  String indexerCachedFailed(int processed, int total, int failed) {
    return '$processed/$total zwischengespeichert ($failed fehlgeschlagen)';
  }

  @override
  String get indexerReadyToRebuild => 'Bereit zum Neuaufbau';

  @override
  String indexerArtistsOnly(String progress) {
    return 'Interpreten $progress';
  }

  @override
  String indexerAlbumsOnly(String progress) {
    return 'Alben $progress';
  }

  @override
  String indexerFailedItemsQuestion(int failed) {
    return 'Dieser Cache enthält $failed fehlgeschlagene Einträge. Was möchtest du tun?';
  }

  @override
  String indexerViewFailed(int failed) {
    return '$failed fehlgeschlagene anzeigen';
  }

  @override
  String get indexerRetryFailed => 'Fehlgeschlagene erneut versuchen';

  @override
  String get indexerForceRebuild => 'Neuaufbau erzwingen';

  @override
  String indexerAlreadyCompleteQuestion(int processed, int total) {
    return 'Dieser Cache ist bereits vollständig ($processed/$total). Möchtest du ihn trotzdem neu aufbauen?';
  }

  @override
  String get indexerDoIt => 'Ausführen';

  @override
  String indexerOptimizing(String name) {
    return '$name wird optimiert …';
  }

  @override
  String get indexerDoNotClose => 'Bitte schließe die App nicht';

  @override
  String get indexerRestartRequiredMessage =>
      'Der Vorgang wurde erfolgreich abgeschlossen.\n\nDie App muss neu gestartet werden, damit alle Änderungen übernommen werden.';

  @override
  String indexerFailedItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fehlgeschlagene Einträge',
      one: '1 fehlgeschlagener Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get indexerCouldNotProcess =>
      'Folgende Einträge konnten nicht verarbeitet werden:';

  @override
  String indexerWarningsTitle(String name) {
    return 'Warnungen zu $name';
  }

  @override
  String get indexerOk => 'OK';

  @override
  String get indexerJustMissing => 'Nur fehlende';

  @override
  String get indexerForceAll => 'Alle erzwingen';

  @override
  String get beatSyncTitle => 'Beat-Synchronisierung';

  @override
  String get beatPlayToCalibrate => 'Spiele einen Song zur Kalibrierung ab.';

  @override
  String get beatAnalyzing => 'Beats werden analysiert …';

  @override
  String get beatNoClearBeat =>
      'In diesem Titel ist kein klarer Beat erkennbar.';

  @override
  String get beatDragInstruction =>
      'Ziehe, bis die Partikelexplosionen genau auf den Klicks liegen.';

  @override
  String beatOffsetMs(int value) {
    return '$value ms';
  }

  @override
  String get beatResetToZero => 'Auf 0 ms zurücksetzen';

  @override
  String get libraryTitle => 'Bibliothek';

  @override
  String get libraryFoldersTab => 'Ordner';

  @override
  String get libraryNoMusicFolderTitle => 'Noch kein Musikordner';

  @override
  String get libraryNoMusicFolderMessage =>
      'Wähle auf der Startseite einen Musikordner aus, um diesen Bereich zu füllen.';

  @override
  String get libraryFolderErrorTitle => 'Musikordner nicht gefunden';

  @override
  String get libraryLoadErrorTitle => 'Bibliothek konnte nicht geladen werden';

  @override
  String get libraryOpenFolderErrorTitle =>
      'Ordner konnte nicht geöffnet werden';

  @override
  String get libraryNoMatchesTitle => 'Keine Treffer';

  @override
  String libraryNoMatchesMessage(String query) {
    return 'In deiner Bibliothek gibt es keine Treffer für „$query“.';
  }

  @override
  String libraryFolderNoMatchesMessage(String query) {
    return 'In diesem Ordner gibt es keine Treffer für „$query“.';
  }

  @override
  String libraryCollectionNoMatchesMessage(String query) {
    return 'Hier gibt es keine Treffer für „$query“.';
  }

  @override
  String get libraryFavorites => 'Favoriten';

  @override
  String libraryMergedGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gruppen',
      one: '1 Gruppe',
    );
    return '$_temp0';
  }

  @override
  String get libraryCreateMergeGroupTooltip =>
      'Neue zusammengeführte Gruppe erstellen';

  @override
  String get libraryDeletePlaylist => 'Playlist löschen';

  @override
  String get libraryPlaylistOptions => 'Playlistoptionen';

  @override
  String get libraryFolderOptions => 'Ordneroptionen';

  @override
  String get libraryFilterAllHint => 'Ordner, Playlists, Songs filtern …';

  @override
  String get libraryFilterSongsHint => 'Ordner und Songs filtern …';

  @override
  String get libraryFilterCollectionsHint => 'Interpreten und Alben filtern …';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Alle';

  @override
  String get libraryShuffleFolderTooltip => 'Ordner zufällig abspielen';

  @override
  String get libraryNoArtistsTitle => 'Noch keine Interpreten';

  @override
  String get libraryNoAlbumsTitle => 'Noch keine Alben';

  @override
  String get libraryScanToFillMessage =>
      'Lies einen Musikordner ein, um diesen Bereich zu füllen.';

  @override
  String get actionClear => 'Leeren';

  @override
  String get actionSearch => 'Suchen';

  @override
  String get actionShuffleAll => 'Alle zufällig abspielen';

  @override
  String get actionSeeAll => 'Alle anzeigen';

  @override
  String homeQueueCardSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$date · $_temp0';
  }

  @override
  String homePlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0 wird abgespielt';
  }

  @override
  String get homeOpenPlayer => 'Player öffnen';

  @override
  String get homePlayNow => 'Jetzt abspielen';

  @override
  String homePlayAfterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel werden nach dem aktuellen Song abgespielt',
      one: '1 Titel wird nach dem aktuellen Song abgespielt',
    );
    return '$_temp0';
  }

  @override
  String get homePlayAfterCurrent => 'Nach aktuellem Song abspielen';

  @override
  String get homeSaveToNewPlaylist => 'In neuer Playlist speichern';

  @override
  String get homeUnpin => 'Lösen';

  @override
  String get homePinRecommendation => 'Empfehlung anheften';

  @override
  String get homeRenameRecommendation => 'Empfehlung umbenennen';

  @override
  String get homeRenameRecommendationTitle => 'Empfehlung umbenennen';

  @override
  String get homeRemoveRecommendation => 'Empfehlung entfernen';

  @override
  String get homeRemoveRecommendationTitle => 'Empfehlung entfernen?';

  @override
  String homeRemoveRecommendationMessage(String title) {
    return 'Möchtest du „$title“ wirklich entfernen?';
  }

  @override
  String get homeErrorTitle => 'Es ist ein Fehler aufgetreten';

  @override
  String get homeTryAgain => 'Erneut versuchen';

  @override
  String get homeNoSongsTitle => 'Keine Songs gefunden';

  @override
  String get homeNoSongsMessage =>
      'Wähle deinen Musikordner aus, um offline Musik zu hören.';

  @override
  String get homeSelectFolder => 'Musikordner auswählen';

  @override
  String get homeQuickPicks => 'Schnellauswahl';

  @override
  String get homeRecentQueues => 'Kürzliche Warteschlangen';

  @override
  String get homePlaylists => 'Deine Playlists';

  @override
  String get homeForYou => 'Für dich';

  @override
  String get mergedTitle => 'Zusammengeführte Songs';

  @override
  String get mergedCreateGroupTooltip => 'Gruppe zusammenführen';

  @override
  String mergedGroupsTab(int count) {
    return 'Gruppen ($count)';
  }

  @override
  String mergedAutoFindTab(int count) {
    return 'Automatisch finden ($count)';
  }

  @override
  String mergedCreatedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs zusammengeführt',
      one: '1 Song zusammengeführt',
    );
    return '$_temp0';
  }

  @override
  String get mergedEmptyTitle => 'Noch keine zusammengeführten Songs';

  @override
  String get mergedEmptyBody =>
      'Fasse verschiedene Versionen desselben Songs (Remixe, Liveversionen, Akustikversionen) zusammen, damit beim zufälligen Abspielen nur eine davon ausgewählt wird.';

  @override
  String get mergedCreateGroupButton => 'Gruppe zusammenführen';

  @override
  String mergedPrioritySet(String title) {
    return '„$title“ als bevorzugten Song festgelegt';
  }

  @override
  String get mergedPriorityCleared => 'Bevorzugung aufgehoben';

  @override
  String get mergedNoCandidatesTitle => 'Keine möglichen Songs gefunden';

  @override
  String get mergedNoCandidatesBody =>
      'In deiner Bibliothek wurden keine ungruppierten Songvarianten (Remixe, Liveversionen, Akustikversionen) erkannt.';

  @override
  String mergedFoundGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mögliche Gruppen zum Zusammenführen gefunden',
      one: '1 mögliche Gruppe zum Zusammenführen gefunden',
    );
    return '$_temp0';
  }

  @override
  String get mergedMergeAll => 'Alle zusammenführen';

  @override
  String get mergedMergeAllTitle => 'Alle Vorschläge zusammenführen';

  @override
  String mergedMergeAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gruppen für erkannte Songvarianten erstellen?',
      one: '1 Gruppe für erkannte Songvarianten erstellen?',
    );
    return '$_temp0';
  }

  @override
  String mergedCreatedGroupsSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gruppen zusammengeführt',
      one: '1 Gruppe zusammengeführt',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeTitle => 'Song aus Gruppe lösen';

  @override
  String mergedUnmergeConfirm(String title) {
    return '„$title“ aus dieser Gruppe lösen?';
  }

  @override
  String get mergedUnmergeAction => 'Lösen';

  @override
  String mergedUnmergedSnack(String title) {
    return '„$title“ aus Gruppe gelöst';
  }

  @override
  String get mergedDeleteGroupTitle => 'Gruppe löschen';

  @override
  String get mergedDeleteGroupConfirm => 'Alle Songs dieser Gruppe lösen?';

  @override
  String get mergedUnmergeAllAction => 'Alle lösen';

  @override
  String get mergedGroupDeleted => 'Gruppe gelöscht';

  @override
  String get mergedGroupLabel => 'Zusammengeführte Gruppe';

  @override
  String mergedVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Versionen',
      one: '1 Version',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeAllTooltip => 'Alle lösen';

  @override
  String get mergedPriorityBadge => 'Bevorzugt';

  @override
  String get mergedPrioritySongTooltip =>
      'Bevorzugter Song für zufällige Wiedergabe';

  @override
  String get mergedSetPriorityTooltip => 'Als bevorzugten Song festlegen';

  @override
  String get mergedUnmergeSongTooltip => 'Song aus Gruppe lösen';

  @override
  String mergedSelectedCount(int selected, int total) {
    return '$selected/$total ausgewählt';
  }

  @override
  String get mergedMergeAction => 'Zusammenführen';

  @override
  String get sleepTimerTitle => 'Sleeptimer';

  @override
  String get sleepTimerModeLabel => 'Timer-Modus';

  @override
  String get sleepTimerDurationLabel => 'Dauer';

  @override
  String get sleepTimerMinSuffix => 'Min.';

  @override
  String get sleepTimerTracksLabel => 'Anzahl der Titel';

  @override
  String get sleepTimerLoopTitle => 'Aktuellen Song wiederholen';

  @override
  String get sleepTimerLoopSubtitle =>
      'Aktuellen Song für eine festgelegte Zeit wiederholen';

  @override
  String get sleepTimerPlayForTimeTitle => 'Für bestimmte Zeit abspielen';

  @override
  String get sleepTimerPlayForTimeSubtitle =>
      'Nach einer festgelegten Dauer anhalten';

  @override
  String get sleepTimerStopAfterCurrentTitle => 'Nach aktuellem Titel anhalten';

  @override
  String get sleepTimerStopAfterCurrentSubtitle =>
      'Anhalten, wenn der aktuelle Song endet';

  @override
  String get sleepTimerStopAfterTracksTitle => 'Nach Anzahl der Titel anhalten';

  @override
  String get sleepTimerStopAfterTracksSubtitle =>
      'Nach X weiteren Songs anhalten';

  @override
  String get sleepTimerNoSong => 'Es läuft derzeit kein Song';

  @override
  String get sleepTimerCurrentSongLabel => 'Aktueller Song';

  @override
  String get sleepTimerLetFinishTitle => 'Aktuellen Song zu Ende spielen';

  @override
  String get sleepTimerLetFinishSubtitle =>
      'Vor dem Anhalten warten, bis der aktuelle Song endet';

  @override
  String get sleepTimerStopImmediatelySubtitle =>
      'Nach Ablauf des Timers sofort anhalten';

  @override
  String get sleepTimerStart => 'Timer starten';

  @override
  String get sleepTimerCancelActive => 'Aktiven Timer abbrechen';

  @override
  String get sleepTimerCancelled => 'Sleeptimer abgebrochen';

  @override
  String get sleepTimerFinished => 'Sleeptimer abgelaufen';

  @override
  String sleepTimerLoopingFor(int minutes) {
    return 'Aktueller Song wird $minutes Minuten lang wiederholt';
  }

  @override
  String sleepTimerStopIn(int minutes) {
    return 'Musikwiedergabe endet in $minutes Minuten';
  }

  @override
  String get sleepTimerStopAfterCurrent =>
      'Hält an, wenn der aktuelle Song endet';

  @override
  String sleepTimerStopAfterTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hält nach $count weiteren Songs an',
      one: 'Hält nach 1 weiterem Song an',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchHint => 'Einstellungen durchsuchen';

  @override
  String get settingsValueNone => 'Keine';

  @override
  String settingsDurationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String settingsDurationMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String settingsDurationMinutesSeconds(int minutes, int seconds) {
    return '$minutes Min. $seconds s';
  }

  @override
  String get settingsGroupLookAndFeel => 'Darstellung';

  @override
  String get settingsGroupData => 'Daten';

  @override
  String get settingsGroupApp => 'Anwendung';

  @override
  String get settingsGroupFilters => 'Filter';

  @override
  String get settingsGroupMaintenance => 'Wartung';

  @override
  String get settingsScanningLibrary => 'Bibliothek wird eingelesen …';

  @override
  String settingsResultsFor(String query) {
    return 'Ergebnisse für „$query“';
  }

  @override
  String get settingsNoResultsTitle => 'Keine Einstellungen gefunden';

  @override
  String settingsNoResultsMessage(String query) {
    return 'Keine Treffer für „$query“.';
  }

  @override
  String get homeSettingsGroupLists => 'Listen und Navigation';

  @override
  String get homeSettingsAutoHideBarsSubtitle =>
      'Kopfzeile und Leiste unten beim Abwärtsscrollen ausblenden, beim Aufwärtsscrollen wieder einblenden';

  @override
  String get homeSettingsGroupHome => 'Startbildschirm';

  @override
  String get playbackGroupTransitions => 'Übergänge';

  @override
  String get playbackGroupPlayPause => 'Abspielen / Pausieren';

  @override
  String get playbackGroupAudio => 'Ton';

  @override
  String get playbackGapOff => 'Abstand / Verzögerung (aus)';

  @override
  String get playbackFadeOutOff => 'Ausblenden (aus)';

  @override
  String get playbackFadeInOff => 'Einblenden (aus)';

  @override
  String playbackSecondsValue(String seconds) {
    return '$seconds s';
  }

  @override
  String get playbackValueOneSecond => '1,0 s';

  @override
  String playbackValueMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get bulkRenameTokenCurrentName => 'Aktueller Name';

  @override
  String get bulkRenameTokenNumber => 'Nummer';

  @override
  String get bulkRenameTokenYear => 'Jahr';

  @override
  String bulkRenameAnalyzeError(String error) {
    return 'Bibliothek konnte nicht analysiert werden: $error';
  }

  @override
  String bulkRenameRenameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs umbenennen',
      one: '1 Song umbenennen',
    );
    return '$_temp0';
  }

  @override
  String get bulkRenameConfirmMessage =>
      'Dateien werden am selben Speicherort umbenannt. Wiedergabestatistiken, Playlists und zwischengespeicherte Cover werden übernommen. Die Datenbank wird beim Verschieben jeder Datei aktualisiert.';

  @override
  String get bulkRenameNothingLeft => 'Nichts mehr umzubenennen';

  @override
  String get bulkRenamePhaseStarting => 'Wird gestartet';

  @override
  String get bulkRenameTitle => 'Mehrere Dateien umbenennen';

  @override
  String get bulkRenameFormatArtistTitle => 'Interpret – Titel';

  @override
  String get bulkRenameFormatArtistAlbumTitle => 'Interpret – Album – Titel';

  @override
  String get bulkRenameCustomSubtitle => 'Eigene Anordnung';

  @override
  String get bulkRenameSectionFormat => 'FORMAT';

  @override
  String get bulkRenameSectionArrange => 'ANORDNUNG';

  @override
  String get bulkRenameSectionPreview => 'VORSCHAU';

  @override
  String get bulkRenameEmptySegments =>
      'Füge unten ein Feld hinzu, um einen Namen zusammenzustellen.';

  @override
  String get bulkRenameLiteralHint => 'Text, z. B. „ - “';

  @override
  String get bulkRenameTextChip => 'Text';

  @override
  String get bulkRenameAnalyzing => 'Bibliothek wird analysiert';

  @override
  String bulkRenameCountToRename(int count) {
    return '$count umzubenennen';
  }

  @override
  String bulkRenameSkippedCount(int count) {
    return '$count übersprungen';
  }

  @override
  String bulkRenameAndMore(int count) {
    return 'und $count weitere';
  }

  @override
  String bulkRenameChecking(int done, int total) {
    return 'Namen werden überprüft — $done von $total';
  }

  @override
  String get bulkRenameStop => 'Anhalten';

  @override
  String get bulkRenameStopping => 'Wird angehalten …';

  @override
  String get bulkRenamePleaseWait => 'Bitte warten';

  @override
  String bulkRenameProgressCount(int done, int total) {
    return '$done von $total';
  }

  @override
  String bulkRenameStopped(int count) {
    return 'Nach $count Songs angehalten. Statistiken und zwischengespeicherte Cover wurden übernommen; der Rest bleibt unverändert.';
  }

  @override
  String bulkRenameStoppedFailed(int count, int failed) {
    return 'Nach $count Songs angehalten, $failed konnten nicht umbenannt werden.';
  }

  @override
  String bulkRenameCompleted(int count) {
    return '$count Songs umbenannt. Statistiken und zwischengespeicherte Cover wurden übernommen.';
  }

  @override
  String bulkRenameCompletedFailed(int count, int failed) {
    return '$count Songs umbenannt, $failed konnten nicht umbenannt werden.';
  }

  @override
  String get bulkRenameFinishedTitle => 'Umbenennen abgeschlossen';

  @override
  String get bulkRenameSkipNoTitleText =>
      'Nach der Bereinigung ist kein Titeltext übrig';

  @override
  String get bulkRenameSkipAlreadyNamed => 'Bereits so benannt';

  @override
  String bulkRenameSkipSameNameAs(String filename) {
    return 'Gleicher Name wie „$filename“ in diesem Ordner';
  }

  @override
  String get bulkRenameSkipAnotherSelected =>
      'Ein anderer ausgewählter Song hat bereits diesen Namen';

  @override
  String get bulkRenameSkipFileExists =>
      'Eine Datei mit diesem Namen ist hier bereits vorhanden';

  @override
  String get shuffleResetDone =>
      'Einstellungen auf Standardwerte zurückgesetzt';

  @override
  String get shuffleReset => 'Zurücksetzen';

  @override
  String get lyricsGroupDisplayTiming => 'Anzeige und Timing';

  @override
  String get lyricsSimulateWordSyncTitle => 'Wortsynchronisierung simulieren';

  @override
  String get lyricsSimulateWordSyncSubtitle =>
      'Wortgenaue Zeitmarken aus zeilensynchronisierten Liedtexten anhand prosodischer Schätzungen erzeugen';

  @override
  String get lyricsDesktopSidebarTitle =>
      'Seitenleiste für Liedtexte und Warteschlange';

  @override
  String get lyricsDesktopSidebarSubtitle =>
      'Ausklappgriff beim Darüberfahren anzeigen, um die ausgeblendete Seitenleiste mit Liedtext und Warteschlange wieder zu öffnen';

  @override
  String get lyricsKeepScreenAwakeTitle =>
      'Bildschirm bei Liedtexten eingeschaltet lassen';

  @override
  String get lyricsKeepScreenAwakeSubtitle =>
      'Ruhezustand verhindern, solange der Liedtextbereich geöffnet ist';

  @override
  String get lyricsGroupTranslation => 'Übersetzung';

  @override
  String get lyricsAutoTranslateTitle => 'Liedtexte automatisch übersetzen';

  @override
  String get lyricsAutoTranslateSubtitle =>
      'Liedtexte automatisch in die ausgewählte Zielsprache übersetzen';

  @override
  String get lyricsTargetLanguageTitle => 'Zielsprache';

  @override
  String get lyricsTranslationDisplayTitle => 'Anzeige der Übersetzung';

  @override
  String get lyricsTranslationModeReplaceSubtitle =>
      'Ursprünglichen Liedtext ersetzen';

  @override
  String get lyricsTranslationModeSubtextSubtitle =>
      'Übersetzung unter dem Liedtext anzeigen';

  @override
  String get lyricsModeSubtext => 'Untertitel darunter';

  @override
  String get lyricsModeReplace => 'Original ersetzen';

  @override
  String get lyricsTranslateTitle => 'Liedtexte übersetzen';

  @override
  String get lyricsDisplayMode => 'Anzeigemodus';

  @override
  String get lyricsModeSubtextDescription =>
      'Übersetzung unter dem Liedtext anzeigen';

  @override
  String get lyricsModeReplaceDescription =>
      'Ursprünglichen Liedtext vollständig ersetzen';

  @override
  String get lyricsAutoTranslateAllTitle => 'Alle Songs automatisch übersetzen';

  @override
  String get lyricsAutoTranslateAllSubtitle =>
      'Liedtexte automatisch in die ausgewählte Sprache übersetzen';

  @override
  String get lyricsTargetLanguageLabel => 'Zielsprache';

  @override
  String get lyricsSearchLanguageHint => 'Sprache suchen …';

  @override
  String get lyricsClearCache => 'Cache leeren';

  @override
  String get lyricsTranslateNow => 'Jetzt übersetzen';

  @override
  String get lyricsFindTitle => 'Liedtexte suchen';

  @override
  String get lyricsNoResults =>
      'Keine Liedtexte gefunden. Versuche einen anderen Titel oder Interpreten oder überprüfe deine Internetverbindung.';

  @override
  String lyricsSearchFailed(String error) {
    return 'Liedtextsuche fehlgeschlagen: $error';
  }

  @override
  String get lyricsInstrumentalWarning =>
      'Als Instrumental gekennzeichnet. Beim Anwenden werden alle Liedtexte aus der Datei gelöscht.';

  @override
  String get lyricsApplyUpper => 'ANWENDEN';

  @override
  String get lyricsPlainText => 'Klartext';

  @override
  String get lyricsUnknownLength => 'Unbekannte Länge';

  @override
  String lyricsDurationExactMatch(String duration) {
    return '$duration · genaue Übereinstimmung';
  }

  @override
  String get lyricsBadgeWordSync => 'WORTSYNCHRONISIERT';

  @override
  String get lyricsBadgeLineSync => 'ZEILENSYNCHRONISIERT';

  @override
  String get lyricsBadgeInstrumental => 'INSTRUMENTAL';

  @override
  String get lyricsBadgePlain => 'KLARTEXT';

  @override
  String get lyricsSaved => 'Liedtext gespeichert';

  @override
  String lyricsSaveError(Object error) {
    return 'Liedtext konnte nicht gespeichert werden: $error';
  }

  @override
  String get lyricsTranslationCleared =>
      'Zwischengespeicherte Übersetzung gelöscht';

  @override
  String get lyricsAlreadyTranslated =>
      'Liedtext ist bereits in der Zielsprache';

  @override
  String get lyricsTranslated => 'Liedtext übersetzt';

  @override
  String get lyricsTranslateError => 'Liedtext konnte nicht übersetzt werden';

  @override
  String lyricsTranslationFailed(Object error) {
    return 'Übersetzung fehlgeschlagen: $error';
  }

  @override
  String get lyricsHideTimingTooltip => 'Liedtext-Timing ausblenden';

  @override
  String get lyricsAdjustTimingTooltip =>
      'Liedtext-Timing anpassen — für Präzisionssteuerung gedrückt halten';

  @override
  String get lyricsFindOnline => 'Liedtexte online suchen';

  @override
  String get lyricsEmptyTitle => 'Keine Liedtexte';

  @override
  String get lyricsEmptySubtitle =>
      'Dieser Titel enthält keine eingebetteten Liedtexte.';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageFrench => 'Französisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageItalian => 'Italienisch';

  @override
  String get languageJapanese => 'Japanisch';

  @override
  String get languageChinese => 'Chinesisch';

  @override
  String get languageKorean => 'Koreanisch';

  @override
  String get languagePortuguese => 'Portugiesisch';

  @override
  String get languageRussian => 'Russisch';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageArabic => 'Arabisch';

  @override
  String get languageDutch => 'Niederländisch';

  @override
  String get languagePolish => 'Polnisch';

  @override
  String get languageTurkish => 'Türkisch';

  @override
  String get languageVietnamese => 'Vietnamesisch';

  @override
  String get languageUkrainian => 'Ukrainisch';

  @override
  String get languageSwedish => 'Schwedisch';

  @override
  String get languageIndonesian => 'Indonesisch';

  @override
  String get languageThai => 'Thailändisch';

  @override
  String get languageCzech => 'Tschechisch';

  @override
  String get languageGreek => 'Griechisch';

  @override
  String get languageHungarian => 'Ungarisch';

  @override
  String get languageRomanian => 'Rumänisch';

  @override
  String get languageDanish => 'Dänisch';

  @override
  String get languageFinnish => 'Finnisch';

  @override
  String get languageNorwegian => 'Norwegisch';

  @override
  String get selectSongsTitle => 'Songs auswählen';

  @override
  String get selectSongsWhatIsMerging => 'Was bedeutet Zusammenführen?';

  @override
  String get selectSongsMergedExplanation =>
      'Zusammengeführte Songs sind verschiedene Versionen desselben Songs:';

  @override
  String get selectSongsBulletVersions =>
      'Zum Beispiel Remixe, Liveversionen oder Versionen in unterschiedlicher Qualität';

  @override
  String get selectSongsBulletFavorites =>
      'Favoriten und „seltener vorschlagen“ werden für jeden Song einzeln verwaltet';

  @override
  String get selectSongsBulletStats =>
      'Deine Wiedergabezahlen und Statistiken bleiben unverändert';

  @override
  String get selectSongsBulletPriority =>
      'Wähle einen bevorzugten Song (⭐), der beim zufälligen Abspielen Vorrang hat';

  @override
  String get selectSongsSearchHint => 'Songs suchen …';

  @override
  String selectSongsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählt',
      one: '1 ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get selectSongsReadyToMerge => 'Bereit zum Zusammenführen';

  @override
  String get selectSongsPrioritySongTooltip => 'Bevorzugter Song';

  @override
  String get selectSongsSetPriorityTooltip => 'Als bevorzugt festlegen';

  @override
  String get selectSongsPriorityBadge => 'BEVORZUGT';

  @override
  String selectSongsMinSelection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mindestens $count Songs auswählen',
      one: 'Mindestens 1 Song auswählen',
    );
    return '$_temp0';
  }

  @override
  String selectSongsMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs zusammenführen',
      one: '1 Song zusammenführen',
    );
    return '$_temp0';
  }

  @override
  String selectSongsSelectAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs auswählen',
      one: '1 Song auswählen',
    );
    return '$_temp0';
  }

  @override
  String get foldersAddedSnack => 'Musikordner hinzugefügt';

  @override
  String get foldersRemovedSnack => 'Musikordner entfernt';

  @override
  String get foldersSubtitle => 'Ordner mit deinen Musikdateien auswählen';

  @override
  String get foldersEmptyTitle => 'Noch keine Ordner hinzugefügt';

  @override
  String get foldersEmptyMessage =>
      'Füge einen Ordner hinzu, um deine Bibliothek zu erstellen.';

  @override
  String get foldersAddButton => 'Ordner hinzufügen';

  @override
  String get foldersAllFilesGrantedTitle => 'Zugriff auf alle Dateien erteilt';

  @override
  String get foldersAllFilesGrantedSubtitle =>
      'wispie kann Musik aus allen hinzugefügten Ordnern lesen.';

  @override
  String get foldersAllFilesMissingTitle =>
      'Zugriff auf alle Dateien deaktiviert';

  @override
  String get foldersAllFilesMissingSubtitle =>
      'Erlaube den Zugriff, damit wispie Musik außerhalb der standardmäßigen Medienbibliothek findet.';

  @override
  String get foldersAllFilesAllowButton => 'Zugriff auf alle Dateien erlauben';

  @override
  String get foldersShortcutInternalStorage => 'Interner Speicher';

  @override
  String get foldersShortcutMusic => 'Musik';

  @override
  String get foldersShortcutDownload => 'Herunterladen';

  @override
  String get foldersShortcutStorageRoot => 'Speicherstammverzeichnis';

  @override
  String get foldersShortcutDownloads => 'Downloads';

  @override
  String get foldersShortcutDocuments => 'Dokumente';

  @override
  String get foldersDoesNotExist => 'Ordner existiert nicht';

  @override
  String get foldersPermissionError =>
      'Zugriff verweigert oder Fehler beim Lesen des Ordners';

  @override
  String get foldersNewFolderTitle => 'Neuer Ordner';

  @override
  String get foldersFolderNameLabel => 'Ordnername';

  @override
  String get foldersFolderNameHint => 'Ordnernamen eingeben';

  @override
  String foldersCreateError(String error) {
    return 'Fehler beim Erstellen des Ordners: $error';
  }

  @override
  String get foldersGoUp => '.. (Nach oben)';

  @override
  String get foldersGoBack => '.. (Zurück)';

  @override
  String get foldersNoSubfolders =>
      'Keine Unterordner gefunden.\nWähle diesen Ordner aus, wenn er deine Musik enthält.';

  @override
  String get foldersSelectThisFolder => 'Diesen Ordner auswählen';

  @override
  String get foldersSelectDestination => 'Zielordner auswählen';

  @override
  String get foldersEmptyFolder =>
      'Leerer Ordner. Du kannst ihn unten auswählen.';

  @override
  String foldersSelected(String name) {
    return 'Ausgewählt: $name';
  }

  @override
  String get foldersRoot => 'Stammverzeichnis';

  @override
  String get foldersMoveFolder => 'Ordner verschieben';

  @override
  String foldersMovedTo(String name, String path) {
    return '$name nach $path verschoben';
  }

  @override
  String foldersMoveError(String error) {
    return 'Fehler beim Verschieben des Ordners: $error';
  }

  @override
  String get playlistsTitle => 'Wiedergabelisten';

  @override
  String get playlistsSearchHint => 'Playlists suchen …';

  @override
  String get playlistsCreate => 'Playlist erstellen';

  @override
  String get playlistsNoMatches => 'Keine passenden Playlists gefunden';

  @override
  String playlistsCreatedOn(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get playlistsCreatedToday => 'heute';

  @override
  String get playlistsCreatedYesterday => 'gestern';

  @override
  String playlistsDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Tagen',
      one: 'vor 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String playlistsWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vor $count Wochen',
      one: 'vor 1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get playlistsEmptyTitle => 'Noch keine Playlists';

  @override
  String get playlistsEmptyMessage => 'Erstelle deine erste Playlist';

  @override
  String get playlistsNameHint => 'Playlistnamen eingeben';

  @override
  String get statsTitle => 'Hörverhalten';

  @override
  String get statsLoadErrorTitle => 'Statistiken konnten nicht geladen werden';

  @override
  String get statsReadingHistory => 'Wiedergabeverlauf wird gelesen';

  @override
  String get statsEmptyTitle => 'Noch kein Wiedergabeverlauf';

  @override
  String get statsEmptyMessage =>
      'Spiele etwas ab, um hier dein Hörverhalten zu sehen.';

  @override
  String get statsSectionOverTime => 'Im Zeitverlauf';

  @override
  String get statsSectionWhen => 'Wann du hörst';

  @override
  String get statsSectionTop => 'Deine Favoriten';

  @override
  String get statsSectionTaste => 'Geschmack';

  @override
  String get statsByHour => 'NACH STUNDE';

  @override
  String get statsByWeekday => 'NACH WOCHENTAG';

  @override
  String get statsNoListening => 'Keine Wiedergaben erfasst';

  @override
  String statsAcrossPlays(String time, String plays) {
    return '$time über $plays';
  }

  @override
  String statsDayTotals(String time, String plays) {
    return '$time · $plays';
  }

  @override
  String get statsLibraryExplored => 'Erkundete Bibliothek';

  @override
  String get statsPlaysFavourites => 'Wiedergaben von Favoriten';

  @override
  String get statsPlaysSkipped => 'Übersprungene Wiedergaben';

  @override
  String get statsAvgPlay => 'DURCHSCHNITTLICHE WIEDERGABEDAUER';

  @override
  String get statsOnActiveDay => 'AN EINEM AKTIVEN TAG';

  @override
  String get statsFirstListen => 'ERSTES ANHÖREN';

  @override
  String statsShareOf(String share, String count) {
    return '$share von $count';
  }

  @override
  String get statsTopArtists => 'TOP-INTERPRETEN';

  @override
  String get statsTopAlbums => 'TOP-ALBEN';

  @override
  String get statsTopTracks => 'TOP-TITEL';

  @override
  String get statsTimeListened => 'HÖRZEIT';

  @override
  String statsRangeWithDays(String range, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage mit Musik',
      one: '1 Tag mit Musik',
    );
    return '$range · $_temp0';
  }

  @override
  String get statsPlays => 'WIEDERGABEN';

  @override
  String get statsSkips => 'ÜBERSPRUNGEN';

  @override
  String get statsTracks => 'TITEL';

  @override
  String get statsStreak => 'SERIE';

  @override
  String statsStreakBest(int count) {
    return 'Rekord: $count';
  }

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben',
      one: '1 Wiedergabe',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktive Tage',
      one: '1 aktiver Tag',
    );
    return '$_temp0';
  }

  @override
  String statsSummary(String duration, String plays, String days) {
    return '$duration · $plays · $days';
  }

  @override
  String get statsEmptyHint => 'Spiele etwas ab, um deinen Verlauf zu beginnen';

  @override
  String get statsLoadError => 'Statistiken konnten nicht geladen werden';

  @override
  String statsDurationMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String statsDurationHours(int hours) {
    return '$hours Std.';
  }

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String get statsSameAsBefore => 'wie zuvor';

  @override
  String statsHourTickAm(int hour) {
    return '$hour Uhr';
  }

  @override
  String statsHourTickPm(int hour) {
    return '$hour Uhr';
  }

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get actionRefresh => 'Aktualisieren';

  @override
  String get sessionDetailTitle => 'Sitzungsdetails';

  @override
  String sessionStartedAt(String time) {
    return 'Begonnen um $time';
  }

  @override
  String get sessionSongSingular => 'Titel';

  @override
  String get sessionSongsPlayed => 'Abgespielte Songs';

  @override
  String get sessionNoSongs => 'Keine Songs erfasst';

  @override
  String get sessionRepeatNow => 'Warteschlange jetzt wiederholen';

  @override
  String get sessionNoSongsAvailable => 'Keine abspielbaren Songs verfügbar';

  @override
  String sessionAfterCurrentSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs werden nach dem aktuellen Song abgespielt',
      one: '1 Song wird nach dem aktuellen Song abgespielt',
    );
    return '$_temp0';
  }

  @override
  String sessionPlayingSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs aus dieser Sitzung werden abgespielt',
      one: '1 Song aus dieser Sitzung wird abgespielt',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryTitle => 'Sitzungsverlauf';

  @override
  String get sessionLoadFailed => 'Sitzungen konnten nicht geladen werden';

  @override
  String get sessionEmptyTitle => 'Noch keine Sitzungen';

  @override
  String get sessionEmptyMessage =>
      'Höre Musik, um deinen Sitzungsverlauf aufzubauen';

  @override
  String get playHistoryTitle => 'Songverlauf';

  @override
  String get playHistoryEmptyTitle => 'Noch kein Wiedergabeverlauf';

  @override
  String get playHistoryEmptyMessage =>
      'Höre Musik, um deinen Verlauf aufzubauen.';

  @override
  String get playHistoryListen => 'Anhören';

  @override
  String get playHistorySkip => 'Überspringen';

  @override
  String playHistorySummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wiedergaben',
      one: '1 Wiedergabe',
    );
    return '$_temp0 · $duration';
  }

  @override
  String playHistoryDate(String month, int day, int year) {
    return '$day. $month $year';
  }

  @override
  String get monthShortJan => 'Jan.';

  @override
  String get monthShortFeb => 'Feb.';

  @override
  String get monthShortMar => 'März';

  @override
  String get monthShortApr => 'Apr.';

  @override
  String get monthShortMay => 'Mai';

  @override
  String get monthShortJun => 'Juni';

  @override
  String get monthShortJul => 'Juli';

  @override
  String get monthShortAug => 'Aug.';

  @override
  String get monthShortSep => 'Sept.';

  @override
  String get monthShortOct => 'Okt.';

  @override
  String get monthShortNov => 'Nov.';

  @override
  String get monthShortDec => 'Dez.';

  @override
  String get searchFieldHint => 'Songs, Interpreten, Alben suchen …';

  @override
  String get onlineTab => 'YouTube';

  @override
  String get onlineSearchHint => 'YouTube durchsuchen';

  @override
  String get onlineSearchPrompt => 'Auf YouTube nach Titeln suchen';

  @override
  String get onlineLoading => 'YouTube wird durchsucht …';

  @override
  String get onlineNoResults => 'Keine Titel gefunden';

  @override
  String get onlineArtistNotFound =>
      'Kein YouTube-Interpret mit diesem Namen gefunden.';

  @override
  String get onlineAlbumNotFound =>
      'Kein YouTube-Album mit diesem Namen gefunden.';

  @override
  String get onlineYoutubeError =>
      'Inhalte von YouTube konnten nicht geladen werden.';

  @override
  String get onlineYoutubeErrorNetwork =>
      'YouTube nicht erreichbar. Überprüfe deine Internetverbindung.';

  @override
  String get onlineYoutubeErrorRateLimited =>
      'YouTube begrenzt derzeit Anfragen. Warte kurz und versuche es erneut.';

  @override
  String get onlineYoutubeErrorUnavailable =>
      'Dieses Video ist auf YouTube nicht verfügbar.';

  @override
  String get onlineYoutubeErrorBlocked =>
      'YouTube hat diesen Titel abgelehnt. Versuche ein anderes Ergebnis.';

  @override
  String get onlineYoutubeErrorResponse =>
      'YouTube hat eine unerwartete Antwort zurückgegeben.';

  @override
  String get onlineUnavailable => 'Online nicht verfügbar';

  @override
  String get onlineLibraryAdd => 'Zur Bibliothek hinzufügen';

  @override
  String get onlineLibraryRemove => 'Aus Bibliothek entfernen';

  @override
  String onlineLibraryAdded(String title) {
    return '„$title“ zur Bibliothek hinzugefügt';
  }

  @override
  String onlineLibraryRemoved(String title) {
    return '„$title“ aus der Bibliothek entfernt';
  }

  @override
  String onlineLibraryAddFailed(String title) {
    return '„$title“ konnte nicht in der Bibliothek gespeichert werden';
  }

  @override
  String get songMenuLibrarySaveHint =>
      'Diesen gestreamten Titel in deiner Bibliothek behalten';

  @override
  String get searchEmptyTitle => 'Musiksammlung durchsuchen';

  @override
  String get searchEmptyMessage =>
      'Songs, Interpreten, Alben und Liedtexte finden.';

  @override
  String get searchFailed => 'Suche fehlgeschlagen';

  @override
  String searchNoResults(String query) {
    return 'Keine Ergebnisse für „$query“ gefunden';
  }

  @override
  String get searchNoResultsHint =>
      'Versuche andere Suchbegriffe oder überprüfe deine Filter.';

  @override
  String searchArtistsSection(int count) {
    return 'Interpreten ($count)';
  }

  @override
  String searchAlbumsSection(int count) {
    return 'Alben ($count)';
  }

  @override
  String searchSongsSection(int count) {
    return 'Titel ($count)';
  }

  @override
  String searchAlbumSubtitle(String artist, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$artist · $_temp0';
  }

  @override
  String get quickActionSuggestMore => 'Häufiger vorschlagen';

  @override
  String get quickActionSuggestLess => 'Seltener vorschlagen';

  @override
  String get quickActionGoToAlbum => 'Zum Album';

  @override
  String get quickActionGoToArtist => 'Zum Interpreten';

  @override
  String get aboutChecking => 'Suche nach Updates …';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Update verfügbar: $version';
  }

  @override
  String get aboutUpToDate => 'Du verwendest die aktuelle Version';

  @override
  String get aboutCheckForUpdates => 'Nach Updates suchen';

  @override
  String get aboutCheckingSubtitle => 'wispie prüft GitHub-Releases.';

  @override
  String get aboutUpdateAvailableSubtitle =>
      'Auf GitHub ist eine neuere Version verfügbar.';

  @override
  String aboutLatestRelease(String version) {
    return 'Neueste Version: $version';
  }

  @override
  String get aboutTapToCheck => 'Tippe unten, um manuell zu suchen.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutUnknown => 'Unbekannt';

  @override
  String get aboutCheckNow => 'Jetzt suchen';

  @override
  String get aboutViewRelease => 'Version anzeigen';

  @override
  String get aboutSupportGroup => 'Unterstützung';

  @override
  String get aboutContactTitle => 'Kontakt';

  @override
  String get aboutContactSubtitle => 'Fehler, Ideen oder Sonstiges';

  @override
  String get aboutIssuesTitle => 'Problem melden';

  @override
  String get aboutIssuesSubtitle => 'Öffnet das wispie-Repository auf GitHub';

  @override
  String get aboutLinkFailed => 'Link konnte nicht geöffnet werden';

  @override
  String get aboutDebugGroup => 'Debugging';

  @override
  String get aboutPersistWrites => 'Änderungen speichern';

  @override
  String get aboutPersistWritesSubtitle =>
      'Debug-Builds speichern Änderungen standardmäßig in einer temporären Kopie. Wirksam ab dem nächsten Start.';

  @override
  String get appIconMoreSoon => 'Weitere Symbole folgen';

  @override
  String get appIconDesktopNote =>
      'Desktop-Launcher und Dateimanager behalten das Standardsymbol. Das Fenster- und Dock-Symbol richtet sich nach deiner Auswahl.';

  @override
  String get storageSettingsDiskGroup => 'Speicher';

  @override
  String get storageSettingsIndexesGroup => 'Indizes und Caches';

  @override
  String get shellNavHome => 'Startseite';

  @override
  String get shellSearchTooltip => 'Suchen (Strg+K)';

  @override
  String get shellShowSidebar => 'Seitenleiste anzeigen';

  @override
  String get shellHideSidebar => 'Seitenleiste ausblenden';

  @override
  String get shellNothingUpNext => 'Nichts als Nächstes';

  @override
  String get shellNextInQueue => 'Als Nächstes in der Warteschlange';

  @override
  String get shellPlayNext => 'Als Nächstes abspielen';

  @override
  String get playerNothingPlaying => 'Keine Wiedergabe';

  @override
  String get playerPanePlayer => 'Wiedergabe';

  @override
  String get playerPaneQueue => 'Warteschlange';

  @override
  String get playerCloseEsc => 'Schließen (Esc)';

  @override
  String get playerSongOptions => 'Songoptionen';

  @override
  String get playerShowArtwork => 'Cover anzeigen';

  @override
  String get playerShowVideo => 'Video anzeigen';

  @override
  String get drawerQueueHistory => 'Warteschlangenverlauf';

  @override
  String get drawerTools => 'Werkzeuge';

  @override
  String get nowPlayingBarShuffleTooltip =>
      'Zufällige Wiedergabe (halten für neue Mischung)';

  @override
  String get shuffleButtonAfterSong => 'Nach aktuellem Song mischen';

  @override
  String get shuffleButtonAfterQueue => 'Nach aktueller Warteschlange mischen';

  @override
  String shuffleButtonScanningTooltip(String percentage) {
    return 'Bibliothek wird eingelesen ($percentage %)';
  }

  @override
  String shuffleButtonScanningSemantics(String percentage) {
    return 'Bibliothek wird eingelesen: $percentage Prozent abgeschlossen';
  }

  @override
  String shuffleButtonScanningMessage(String percentage) {
    return 'Bibliothek wird eingelesen: $percentage %';
  }

  @override
  String heartMenuRemoveFromPlaylist(String name) {
    return 'Aus $name entfernen';
  }

  @override
  String heartMenuRemovedFromPlaylist(String name) {
    return 'Aus $name entfernt';
  }

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get sortTitleAZ => 'Titel (A–Z)';

  @override
  String get sortDateAdded => 'Hinzugefügt am';

  @override
  String get sortSongDateOldNew => 'Songdatum (älteste zuerst)';

  @override
  String get sortSongDateNewOld => 'Songdatum (neueste zuerst)';

  @override
  String get sortMostPlayed => 'Am häufigsten abgespielt';

  @override
  String get sortRecentlyPlayed => 'Zuletzt abgespielt';

  @override
  String get sortRecommended => 'Empfohlen';

  @override
  String get searchFilterArtists => 'Interpreten';

  @override
  String get playlistDialogAddTo => 'Hinzufügen zu …';

  @override
  String get playlistDialogBulkAddTo => 'Mehrere hinzufügen zu …';

  @override
  String get playlistDialogUpdatedSelections => 'Auswahl aktualisiert';

  @override
  String get albumCardAllSongs => 'Alle Songs';

  @override
  String dangerDialogTypeToConfirm(String text) {
    return 'Gib zur Bestätigung „$text“ ein';
  }

  @override
  String dangerDialogCountdown(String label, int seconds) {
    return '$label ($seconds)';
  }

  @override
  String get appDialogConfirm => 'Bestätigen';

  @override
  String get appDialogEnterName => 'Namen eingeben …';

  @override
  String get transportRepeatOff => 'Wiederholen aus';

  @override
  String get transportRepeatAll => 'Alles wiederholen';

  @override
  String get transportRepeatOne => 'Einen Titel wiederholen';

  @override
  String durationSongsWithTotal(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$_temp0 • $duration';
  }

  @override
  String waveformDeltaMinutes(String minutes, String seconds) {
    return '$minutes Min. $seconds s';
  }

  @override
  String waveformDeltaSeconds(String value) {
    return '$value s';
  }

  @override
  String get waveformDeltaZero => '0 s';

  @override
  String lyricsMatchContains(String line) {
    return 'enthält „$line“';
  }

  @override
  String get lyricsMatchPrefix => 'enthält „';

  @override
  String get lyricsMatchAvailable => 'Liedtext verfügbar';

  @override
  String get lyricsResumeSync => 'Synchronisierung fortsetzen';

  @override
  String get lyricsTimingTitle => 'Liedtext-Timing';

  @override
  String get lyricsTimingLater => 'Später';

  @override
  String get lyricsTimingSyncToLine => 'Mit dieser Zeile synchronisieren';

  @override
  String get lyricsTimingReset => 'Timing zurücksetzen';

  @override
  String lyricsTimingSnapped(String value) {
    return 'Auf $value eingerastet';
  }

  @override
  String get lyricsTimingRangeLabel =>
      'Bereich (bis zu 60 s in beide Richtungen)';

  @override
  String get lyricsTimingFineLabel =>
      'Feinabstimmung (5 s auf beiden Seiten, in 0,01-s-Schritten)';

  @override
  String get lyricsTimingResetTooltip =>
      'Doppeltippen, um auf 0,00 zurückzusetzen';

  @override
  String get quickActionsTitle => 'Schnellaktionen';

  @override
  String get quickActionsResetDone => 'Auf Standardwerte zurückgesetzt';

  @override
  String quickActionsEnabledHeader(int count) {
    return 'AKTIVIERT ($count)';
  }

  @override
  String quickActionsDisabledHeader(int count) {
    return 'DEAKTIVIERT ($count)';
  }

  @override
  String get quickActionsGoToAlbum => 'Zum Album';

  @override
  String get quickActionsGoToArtist => 'Zum Interpreten';

  @override
  String get updateAvailableTitle => 'Update verfügbar';

  @override
  String get updateCurrentLabel => 'Aktuell';

  @override
  String get updateAvailableBody =>
      'Eine neuere Version von wispie kann heruntergeladen werden.';

  @override
  String get updateSkipVersion => 'Diese Version überspringen';

  @override
  String get updateWhatsNew => 'Was ist neu?';

  @override
  String get externalOpenAddToLibrary => 'Zur Bibliothek hinzufügen';

  @override
  String get externalOpenDismiss => 'Schließen';

  @override
  String get wideTrackTime => 'Zeit';

  @override
  String get floatingDockNext => 'Weiter';

  @override
  String get barSeekLabel => 'Positionieren';

  @override
  String get indexerOpOptimizeDatabasesTitle => 'Datenbanken optimieren';

  @override
  String get indexerOpOptimizeDatabasesDesc =>
      'Alle App-Datenbanken bereinigen und optimieren';

  @override
  String get indexerOpRepairLinksTitle => 'Bibliotheksverknüpfungen reparieren';

  @override
  String get indexerOpRepairLinksDesc =>
      'Albumcover und Dateipfade nach einer Wiederherstellung oder auf einem neuen Gerät erneut verknüpfen';

  @override
  String get indexerOpMatchIdentityTitle =>
      'Songs anhand des Audios abgleichen';

  @override
  String get indexerOpMatchIdentityDesc =>
      'Fingerabdruck aller Dateien erstellen, damit umbenannte Songs ihre Favoriten, Playlists und Statistiken behalten und auf synchronisierten Geräten erkannt werden';

  @override
  String get indexerOpCoverCacheTitle => 'Covercaches neu aufbauen';

  @override
  String get indexerOpCoverCacheDesc =>
      'Eingebettete Albumcover extrahieren und zwischenspeichern';

  @override
  String get indexerOpSearchIndexTitle => 'Suchindizes neu aufbauen';

  @override
  String get indexerOpSearchIndexDesc =>
      'Suchindex für alle Songs neu erstellen';

  @override
  String get indexerOpLyricsCacheTitle => 'Liedtextcache neu aufbauen';

  @override
  String get indexerOpLyricsCacheDesc =>
      'Liedtexte für alle Songs extrahieren und zwischenspeichern';

  @override
  String get indexerOpWaveformCacheTitle => 'Wellenformcache neu aufbauen';

  @override
  String get indexerOpWaveformCacheDesc =>
      'Wellenformdaten für alle Songs erzeugen';

  @override
  String get indexerOpColorCacheTitle =>
      'App-Design aus Covercache neu aufbauen';

  @override
  String get indexerOpColorCacheDesc =>
      'Farbdesigns aus allen Covern extrahieren';

  @override
  String get indexerOpBlurredCacheTitle =>
      'Cache unscharfer Hintergründe neu aufbauen';

  @override
  String get indexerOpBlurredCacheDesc =>
      'Optimierte unscharfe Hintergründe vorab erstellen';

  @override
  String get indexerOpRecommendationsTitle => 'Empfehlungen neu aufbauen';

  @override
  String get indexerOpRecommendationsDesc =>
      'Alle Empfehlungs-Playlists neu erstellen';

  @override
  String get indexerOpArtistAlbumArtTitle =>
      'Interpreten- und Albumcover abrufen';

  @override
  String get indexerOpArtistAlbumArtDesc =>
      'Fehlende Interpreten- und Albumcover online abrufen, beginnend mit den größten Sammlungen';

  @override
  String get indexerCounting => 'Wird gezählt …';

  @override
  String get indexerWorking => 'Wird verarbeitet …';

  @override
  String get indexerStopping => 'Wird angehalten …';

  @override
  String indexerProgressPercent(int percent) {
    return '$percent % werden verarbeitet';
  }

  @override
  String indexerProgressFailed(int done, int total, int failed) {
    return '$done/$total verarbeitet ($failed fehlgeschlagen)';
  }

  @override
  String indexerStoppedAt(int done, int total) {
    return 'Bei $done/$total angehalten';
  }

  @override
  String indexerFinished(int processed, int failed) {
    return 'Fertig: $processed verarbeitet, $failed fehlgeschlagen';
  }

  @override
  String get indexerNothingToDo => 'Nichts zu tun, alles ist bereits aktuell';

  @override
  String get indexerErrorBusy => 'Läuft bereits im Hintergrund';

  @override
  String get indexerErrorOffline =>
      'Verbindung verloren. Der Rest wird automatisch fortgesetzt.';

  @override
  String get indexerStop => 'Anhalten';

  @override
  String get youtubeAccountTitle => 'YouTube-Konto';

  @override
  String get youtubeAccountLoading => 'YouTube-Konto wird geladen …';

  @override
  String get youtubeAccountSignedOutTitle =>
      'Hole deine YouTube-Playlists hierher';

  @override
  String get youtubeAccountSignedOutBody =>
      'Melde dich an, um deine YouTube-Playlists in diese Bibliothek zu importieren. Suche, Wiedergabe, Favoriten und Hörstatistiken funktionieren auch ohne Konto.';

  @override
  String get youtubeAccountSignIn => 'Mit Google anmelden';

  @override
  String get youtubeAccountSignInTryWeb => 'Anmeldung in der App versuchen';

  @override
  String get youtubeAccountSignInHint =>
      'Öffnet die offizielle Google-Anmeldeseite in der App. wispie speichert die YouTube-Sitzung auf diesem Gerät und sieht dein Passwort niemals.';

  @override
  String get youtubeAccountSignInHintManual =>
      'Melde dich in einem Browser bei YouTube an und übertrage dann die Sitzungscookies hierher: Auf der Kontoseite kannst du einen Cookie-Header, einen cookies.txt-Export oder Cookie-JSON importieren. Die Cookies bleiben auf diesem Gerät und sind alles, was wispie benötigt.';

  @override
  String get youtubeAccountWebTitle => 'Google-Anmeldung';

  @override
  String get youtubeAccountWebTrouble =>
      'Probleme bei der Anmeldung? Verwende stattdessen Cookies';

  @override
  String get youtubeAccountWebTroubleAction => 'Cookies verwenden';

  @override
  String get youtubeAccountWebFailed =>
      'Diese Seite konnte nicht geladen werden. Überprüfe deine Verbindung oder verwende Cookies.';

  @override
  String get youtubeAccountWebUnsupported =>
      'Auf dieser Plattform ist kein In-App-Browser verfügbar.';

  @override
  String get youtubeAccountWebBlockedTitle =>
      'Google hat die In-App-Anmeldung blockiert';

  @override
  String get youtubeAccountWebBlockedBody =>
      'Google erlaubt keine Anmeldung innerhalb anderer Apps. Ein hier eingegebenes Passwort wird daher nicht akzeptiert. Melde dich in deinem Browser bei YouTube an und importiere anschließend die Sitzungscookies auf der Kontoseite. Das Ergebnis ist dasselbe und dein Passwort wird nie in wispie eingegeben.';

  @override
  String get youtubeAccountWebPasskeyTitle => 'Google fordert einen Passkey an';

  @override
  String get youtubeAccountWebPasskeyBody =>
      'Ein Passkey kann nicht innerhalb einer anderen App verwendet werden. Dieser Schritt kann daher hier nicht abgeschlossen werden. Melde dich stattdessen mit deinem Passwort an; der restliche Ablauf funktioniert wie gewohnt.';

  @override
  String get youtubeAccountWebPasskeyAction => 'Mein Passwort verwenden';

  @override
  String get youtubeAccountOpenYouTube => 'youtube.com öffnen';

  @override
  String get youtubeSearchSongs => 'Songs';

  @override
  String get youtubeSearchAlbums => 'Alben';

  @override
  String get youtubeSearchPlaylists => 'Wiedergabelisten';

  @override
  String get youtubeSearchArtists => 'Interpreten';

  @override
  String get youtubeArtistSongsTitle => 'Beliebte Songs';

  @override
  String get youtubeArtistAlbumsTitle => 'Alben und Singles';

  @override
  String get youtubeCollectionEmpty => 'Hier gibt es nichts abzuspielen.';

  @override
  String get youtubeAccountSignOut => 'Abmelden';

  @override
  String youtubeAccountSignedInAs(String name) {
    return 'Angemeldet als $name';
  }

  @override
  String get youtubeAccountSessionExpired =>
      'Deine YouTube-Sitzung ist abgelaufen. Melde dich erneut an, um deine Playlists weiter zu synchronisieren.';

  @override
  String get youtubeAccountCookiesTitle => 'YouTube-Cookies einfügen';

  @override
  String get youtubeAccountCookiesBody =>
      'Melde dich in einem Browser bei YouTube an und kopiere dann den Cookie-Anfrageheader einer beliebigen youtube.com-Anfrage (Entwicklertools: Netzwerk → Header) oder exportiere eine cookies.txt-Datei und füge sie hier ein. Es werden nur Cookies von youtube.com gespeichert.';

  @override
  String get youtubeAccountCookiesHint =>
      'Cookie-Header, cookies.txt oder exportiertes Cookie-JSON';

  @override
  String get youtubeAccountCookiesImport => 'Cookies importieren';

  @override
  String get youtubeAccountCookiesFile => 'cookies.txt-Datei auswählen';

  @override
  String get youtubeAccountCookiesEmpty =>
      'In diesem Text wurden keine Cookies gefunden.';

  @override
  String get youtubeAccountCookiesUnreadable =>
      'Diese Datei konnte nicht gelesen werden.';

  @override
  String get youtubeAccountPlaylistsTitle => 'Deine Playlists';

  @override
  String get youtubeFeedForYou => 'Für dich';

  @override
  String get youtubeFeedFromLibrary => 'Von Interpreten, die du hörst';

  @override
  String get youtubeFeedFilterPlaylists => 'Playlists auswählen';

  @override
  String get youtubeFeedPlaylistsHidden =>
      'Alle Playlists sind in diesem Tab ausgeblendet.';

  @override
  String get youtubeFeedPlaylists => 'Deine Playlists';

  @override
  String get youtubeFeedSignInTitle =>
      'Melde dich für deinen persönlichen Feed an';

  @override
  String get youtubeFeedSignInBody =>
      'Dein YouTube-Startseitenfeed richtet sich danach, was du ansiehst und welche Kanäle du abonnierst. Nach der Anmeldung kannst du auch Playlists ansehen und importieren.';

  @override
  String get youtubeFeedSignInAction => 'Anmelden';

  @override
  String get youtubeFeedEmpty => 'Hier ist noch nichts. Suche oben nach etwas.';

  @override
  String get youtubePreviewEmpty =>
      'Diese Playlist enthält keine abspielbaren Titel.';

  @override
  String get youtubePreviewPlayAll => 'Alle abspielen';

  @override
  String get youtubeAccountLikedVideos => 'Videos mit „Mag ich“';

  @override
  String youtubeAccountPlaylistTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
      zero: 'Keine Titel',
    );
    return '$_temp0';
  }

  @override
  String get youtubeAccountImport => 'Importieren';

  @override
  String get youtubeAccountSync => 'Synchronisieren';

  @override
  String get youtubeAccountSyncAll =>
      'Alle importierten Playlists synchronisieren';

  @override
  String get youtubeAccountSyncHint =>
      'Beim Synchronisieren werden nur Titel hinzugefügt. Aus deinen Playlists wird nichts entfernt.';

  @override
  String youtubeAccountImportDone(int count, String name) {
    return '$count Titel aus $name importiert';
  }

  @override
  String youtubeAccountSyncDone(int count, String name) {
    return '$count neue Titel zu $name hinzugefügt';
  }

  @override
  String youtubeAccountSyncUpToDate(String name) {
    return '$name ist aktuell';
  }

  @override
  String youtubeAccountSyncLimited(int count) {
    return 'Es wurden nur die ersten $count neuen Titel hinzugefügt. Synchronisiere erneut, um den Rest zu übernehmen.';
  }

  @override
  String get youtubeAccountPlaylistEmpty =>
      'Diese Playlist enthält keine abspielbaren Titel.';

  @override
  String get youtubeAccountLoadFailed =>
      'Deine Playlists konnten nicht geladen werden.';

  @override
  String get youtubeAccountTryAgain => 'Erneut versuchen';

  @override
  String get youtubeAccountErrorNetwork =>
      'YouTube nicht erreichbar. Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get youtubeAccountErrorUnauthorized =>
      'Deine YouTube-Sitzung ist nicht mehr gültig. Melde dich erneut an.';

  @override
  String get youtubeAccountErrorResponse =>
      'YouTube hat eine unerwartete Antwort zurückgegeben.';

  @override
  String get youtubeAccountErrorRateLimited =>
      'YouTube begrenzt derzeit Anfragen. Versuche es in ein paar Minuten erneut.';

  @override
  String get youtubeAccountErrorStorage =>
      'Die Sitzung konnte auf diesem Gerät nicht sicher gespeichert werden.';

  @override
  String get youtubeAccountErrorGeneric =>
      'Dein YouTube-Konto ist nicht erreichbar.';

  @override
  String get playlistSyncFromYoutube => 'Von YouTube synchronisieren';

  @override
  String get playlistYoutubeBadge => 'YouTube';

  @override
  String get batchReplaceTitle => 'Songs gesammelt ersetzen';

  @override
  String get batchReplaceIntro =>
      'Wähle einen Ordner zum Vergleichen mit deiner Bibliothek aus. Dateien mit passenden Songs werden als Ersatz vorgeschlagen.';

  @override
  String get batchReplaceFolderLabel => 'Zu vergleichender Ordner';

  @override
  String get batchReplaceNoFolder => 'Kein Ordner ausgewählt';

  @override
  String get batchReplaceChooseFolder => 'Ordner auswählen';

  @override
  String get batchReplaceChangeFolder => 'Ändern';

  @override
  String get batchReplaceSubfolders => 'Unterordner einschließen';

  @override
  String get batchReplaceInsideLibrary =>
      'Dieser Ordner gehört bereits zu deiner Bibliothek. Wähle einen Ordner außerhalb davon.';

  @override
  String get batchReplacePhaseListing => 'Dateien werden aufgelistet';

  @override
  String get batchReplacePhaseReading => 'Tags werden gelesen';

  @override
  String get batchReplacePhaseReplacing => 'Songs werden ersetzt';

  @override
  String get batchReplaceStopping => 'Wird angehalten';

  @override
  String batchReplaceCompareError(Object error) {
    return 'Ordner konnte nicht verglichen werden: $error';
  }

  @override
  String batchReplaceMatched(int count) {
    return '$count passende Songs';
  }

  @override
  String batchReplaceCompared(int files, int songs) {
    return '$files Dateien mit $songs Songs aus der Bibliothek verglichen';
  }

  @override
  String get batchReplaceSelectAll => 'Alle auswählen';

  @override
  String get batchReplaceSelectNone => 'Keine auswählen';

  @override
  String batchReplaceConfidence(int percent) {
    return '$percent %';
  }

  @override
  String get batchReplaceSignalTitle => 'Titel';

  @override
  String get batchReplaceSignalFilename => 'Dateiname';

  @override
  String get batchReplaceSignalArtist => 'Interpret';

  @override
  String get batchReplaceSignalAlbum => 'Album';

  @override
  String get batchReplaceSignalDuration => 'Länge';

  @override
  String get batchReplaceLengthDiffers => 'Länge weicht ab';

  @override
  String batchReplaceUnmatched(int count) {
    return 'Für $count Dateien wurde kein Treffer gefunden';
  }

  @override
  String batchReplaceAndMore(int count) {
    return 'und $count weitere';
  }

  @override
  String get batchReplaceCompareAgain => 'Erneut vergleichen';

  @override
  String get batchReplaceNoMatchesTitle => 'Keine Treffer';

  @override
  String batchReplaceNoMatchesMessage(int files) {
    return 'Keine der $files Dateien in diesem Ordner scheint einem Song in deiner Bibliothek zu entsprechen.';
  }

  @override
  String get batchReplaceNothingSelected => 'Nichts ausgewählt';

  @override
  String get batchReplaceCollisionTitle => 'Dateien sind bereits vorhanden';

  @override
  String batchReplaceCollisionMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Ersatzdateien sind an den Zielorten bereits vorhanden. Möchtest du sie ersetzen oder überspringen?',
      one:
          'Eine Ersatzdatei ist am Zielort bereits vorhanden. Möchtest du sie ersetzen oder überspringen?',
    );
    return '$_temp0';
  }

  @override
  String get batchReplaceCollisionReplace => 'Ersetzen';

  @override
  String get batchReplaceCollisionSkip => 'Überspringen';

  @override
  String get batchReplaceOptionsTitle => 'Songs ersetzen';

  @override
  String get batchReplaceTransportSection => 'Neue Dateien';

  @override
  String get batchReplaceTransportCopy => 'In die Bibliothek kopieren';

  @override
  String get batchReplaceTransportCopyHint =>
      'Die Dateien bleiben im verglichenen Ordner erhalten';

  @override
  String get batchReplaceTransportMove => 'In die Bibliothek verschieben';

  @override
  String get batchReplaceTransportMoveHint =>
      'Verwendete Dateien werden aus dem verglichenen Ordner verschoben';

  @override
  String get batchReplaceOriginalSection => 'Alte Dateien';

  @override
  String get batchReplaceOriginalHide => 'Behalten, aber ausblenden';

  @override
  String get batchReplaceOriginalHideHint =>
      'Dateien bleiben auf der Festplatte, sind aber nicht in der Bibliothek';

  @override
  String get batchReplaceOriginalDelete => 'Löschen';

  @override
  String get batchReplaceOriginalDeleteHint =>
      'Dateien werden endgültig von der Festplatte gelöscht';

  @override
  String batchReplaceRun(int count) {
    return '$count Songs ersetzen';
  }

  @override
  String get batchReplaceDeleteTitle => 'Alte Dateien löschen?';

  @override
  String batchReplaceDeleteMessage(int count) {
    return '$count Originaldateien werden von der Festplatte gelöscht. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get batchReplaceDeleteConfirm => 'Löschen';

  @override
  String get batchReplaceOutcomeTitle => 'Songs gesammelt ersetzen';

  @override
  String batchReplaceOutcomeDone(int count) {
    return '$count Songs ersetzt.';
  }

  @override
  String batchReplaceOutcomeDoneFailed(int count, int failed) {
    return '$count Songs ersetzt, $failed konnten nicht ersetzt werden.';
  }

  @override
  String batchReplaceOutcomeStopped(int count) {
    return 'Nach dem Ersetzen von $count Songs angehalten.';
  }

  @override
  String batchReplaceOutcomeStoppedFailed(int count, int failed) {
    return 'Nach dem Ersetzen von $count Songs angehalten, $failed konnten nicht ersetzt werden.';
  }

  @override
  String batchReplaceFailureError(Object error) {
    return '$error';
  }

  @override
  String get settingsSearchBatchReplaceTitle => 'Songs gesammelt ersetzen';

  @override
  String get settingsSearchBatchReplaceSubtitle =>
      'Songs durch bessere Dateien aus einem anderen Ordner ersetzen';

  @override
  String get storageWispieCacheTitle => 'wispie-Cache';

  @override
  String get storageWispieCacheSubtitle =>
      'Wird bei Bedarf neu erstellt. Hier befinden sich keine persönlichen Daten.';

  @override
  String get storageCleanCacheAction => 'Bereinigen';

  @override
  String get storageCleanCacheTitle => 'Cache bereinigen?';

  @override
  String get storageCleanCacheBody =>
      'Löscht nicht mehr benötigte Cachedateien, leere Dateien und Dateien, die das Größenlimit überschreiten. Alles wird bei Bedarf neu erstellt.';

  @override
  String storageCleanCacheSuccess(String size) {
    return '$size bereinigt';
  }

  @override
  String get storageCleanCacheNothing => 'Cache ist bereits aufgeräumt';

  @override
  String storageCleanCacheError(String error) {
    return 'Fehler beim Bereinigen des Caches: $error';
  }

  @override
  String get storageCacheEmpty => 'Leer';

  @override
  String storageClearBucketTitle(String name) {
    return '$name leeren?';
  }

  @override
  String get storageClearBucketBody =>
      'Diese Dateien werden bei Bedarf neu erstellt.';

  @override
  String storageClearBucketSuccess(String name) {
    return '$name geleert';
  }

  @override
  String storageClearBucketError(String name, String error) {
    return 'Fehler beim Leeren von $name: $error';
  }

  @override
  String get storageClearWispieCacheTitle => 'wispie-Cache leeren?';

  @override
  String get storageClearWispieCacheBody =>
      'Alle zwischengespeicherten Dateien werden gelöscht und bei Bedarf neu erstellt. Deine Bibliothek, Playlists und Statistiken bleiben unverändert.';

  @override
  String get storageClearWispieCacheSuccess => 'wispie-Cache geleert';

  @override
  String get storageRemoteArtTitle => 'Heruntergeladene Cover';

  @override
  String get storageRemoteArtSubtitle =>
      'Online abgerufene Coverbilder für Designs';

  @override
  String get storageNotificationCacheTitle => 'Benachrichtigungscover';

  @override
  String get storageNotificationCacheSubtitle =>
      'Quadratische Cover für die Medienbenachrichtigung';

  @override
  String get storageYoutubeCacheTitle => 'Online-Seiten';

  @override
  String get storageYoutubeCacheSubtitle =>
      'Zwischengespeicherte YouTube-Seiten und Startseitenfeed';

  @override
  String storageBackupsLocation(String path) {
    return 'Gespeichert unter $path';
  }
}
