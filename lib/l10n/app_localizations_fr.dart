// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguageSystem => 'Suivre la langue du système';

  @override
  String get languageNativeName => 'Français';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsPageLibrarySubtitle => 'Dossiers, filtres, analyse';

  @override
  String get settingsPagePlaybackTitle => 'Lecture';

  @override
  String get settingsPagePlaybackSubtitle => 'Transitions, fondus, audio';

  @override
  String get settingsPageLyricsTitle => 'Paroles';

  @override
  String get settingsPageLyricsSubtitle =>
      'Synchronisation des mots, traduction, panneau latéral';

  @override
  String get settingsPageAppearanceTitle => 'Apparence';

  @override
  String get settingsPageAppearanceSubtitle =>
      'Écran de lecture, animations, icône de l’application';

  @override
  String get settingsPageHomeNavigationTitle => 'Accueil et navigation';

  @override
  String get settingsPageHomeNavigationSubtitle =>
      'Sections d’accueil, listes, actions rapides';

  @override
  String get settingsPageOnlineTitle => 'En ligne';

  @override
  String get settingsPageOnlineSubtitle => 'Catalogue et compte YouTube';

  @override
  String get onlineSettingsGroup => 'YouTube';

  @override
  String get settingsYoutubeEnabledTitle => 'YouTube';

  @override
  String get settingsYoutubeEnabledSubtitle =>
      'Afficher l’onglet YouTube et écouter de la musique depuis YouTube. La désactivation le masque entièrement.';

  @override
  String get settingsYoutubeAccountSubtitle =>
      'Connectez-vous pour importer vos playlists';

  @override
  String get settingsKwOnline =>
      'youtube,en ligne,diffusion,compte,importation';

  @override
  String get settingsPageSyncTitle => 'Synchronisation';

  @override
  String get settingsPageSyncSubtitle =>
      'Synchronisation chiffrée entre appareils';

  @override
  String get settingsPageBackupRestoreTitle => 'Sauvegarde et restauration';

  @override
  String get settingsPageBackupRestoreSubtitle =>
      'Exporter, importer, sauvegardes automatiques';

  @override
  String get settingsPageStorageTitle => 'Stockage';

  @override
  String get settingsPageStorageSubtitle => 'Espace disque, index, caches';

  @override
  String get settingsPageAboutTitle => 'À propos';

  @override
  String get settingsPageAboutSubtitle =>
      'Version, mises à jour, notes de version';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionCreate => 'Créer';

  @override
  String get actionDone => 'Terminé';

  @override
  String get actionChange => 'Modifier';

  @override
  String get actionDelete => 'Supprimer';

  @override
  String get actionHide => 'Masquer';

  @override
  String get actionDeletePermanently => 'Supprimer définitivement';

  @override
  String get actionBack => 'Retour';

  @override
  String get actionClose => 'Fermer';

  @override
  String get playlistNewTitle => 'Nouvelle playlist';

  @override
  String get playlistNameHint => 'Nom de la playlist';

  @override
  String playlistCreated(Object name) {
    return 'Playlist « $name » créée';
  }

  @override
  String songFavoriteRemoved(Object title) {
    return '$title retiré des favoris';
  }

  @override
  String songFavoriteAdded(Object title) {
    return '$title ajouté aux favoris';
  }

  @override
  String songWillSuggestMore(Object title) {
    return '$title sera proposé plus souvent';
  }

  @override
  String songWillSuggestLess(Object title) {
    return '$title sera proposé moins souvent';
  }

  @override
  String songAddedToNextUp(Object title) {
    return 'Ajouté à la liste À suivre : $title';
  }

  @override
  String songShareText(Object artist, Object title) {
    return '$title par $artist';
  }

  @override
  String songAddedToPlaylist(Object name) {
    return 'Ajouté à $name';
  }

  @override
  String songRemovedFromPlaylist(Object title) {
    return '$title retiré de la playlist';
  }

  @override
  String songMovedTo(Object path, Object title) {
    return '$title déplacé vers $path';
  }

  @override
  String songMoveError(Object error) {
    return 'Erreur lors du déplacement du morceau : $error';
  }

  @override
  String songRemovedFromLibrary(Object title) {
    return '$title retiré de la bibliothèque';
  }

  @override
  String get songDeleteTitle => 'Supprimer le morceau';

  @override
  String songDeleteConfirm(Object title) {
    return 'Voulez-vous vraiment supprimer définitivement « $title » de votre appareil ? Cette action est irréversible.';
  }

  @override
  String songDeleted(Object title) {
    return '$title supprimé';
  }

  @override
  String songDeleteError(Object error) {
    return 'Erreur lors de la suppression du fichier : $error';
  }

  @override
  String get coverSearching =>
      'Recherche de pochettes sur Last.fm, Deezer et iTunes…';

  @override
  String get coverNoneFound => 'Aucune pochette manquante trouvée en ligne';

  @override
  String coverUpdated(Object source, Object title) {
    return 'Pochette de « $title » mise à jour ($source)';
  }

  @override
  String get coverDownloadFailed => 'Échec du téléchargement de la pochette';

  @override
  String coverFetchError(Object error) {
    return 'Erreur lors de la récupération de la pochette : $error';
  }

  @override
  String get metaResultsTitle => 'Résultats de la récupération des métadonnées';

  @override
  String get metaFetchingTitle => 'Récupération des métadonnées manquantes';

  @override
  String get metaStatUpdated => 'Mis à jour';

  @override
  String get metaStatNotFound => 'Introuvable';

  @override
  String get metaStatSkipped => 'Ignoré';

  @override
  String get metaUndoAll => 'Tout annuler';

  @override
  String get metaUndoSong => 'Annuler pour ce morceau';

  @override
  String metaRevertedCount(int count) {
    return 'Modifications des métadonnées annulées pour $count piste(s)';
  }

  @override
  String metaViaSource(Object source) {
    return 'via $source';
  }

  @override
  String metaMoreItems(int count) {
    return '… et $count de plus';
  }

  @override
  String get metaCouldNotFind => 'Introuvable';

  @override
  String get metaUnknownArtist => 'Artiste inconnu';

  @override
  String metaAllHaveMetadata(int count) {
    return 'Les $count pistes ont déjà des métadonnées';
  }

  @override
  String get metaNoMissingMetadata =>
      'Aucune piste avec des métadonnées manquantes trouvée';

  @override
  String metaSearchingBatch(int batch) {
    return 'Recherche du lot $batch…';
  }

  @override
  String metaCancelledSummary(int updated, int notFound) {
    return 'Récupération des métadonnées annulée ($updated mises à jour, $notFound introuvables)';
  }

  @override
  String get songMenuTitle => 'Options du morceau';

  @override
  String get songMenuPlaybackHint =>
      'Actions de file d’attente, de playlist et de partage';

  @override
  String get songMenuLibraryHint =>
      'Déplacer le morceau et modifier ses métadonnées';

  @override
  String get songMenuPersonalize => 'Personnaliser';

  @override
  String get songMenuPersonalizeHint =>
      'Réglages des favoris et des recommandations';

  @override
  String get songMenuDanger => 'Zone sensible';

  @override
  String get songMenuDangerHint =>
      'Retirer de la playlist ou supprimer le morceau';

  @override
  String get songMenuPlayNext => 'Lire ensuite';

  @override
  String get songMenuPlayNextHint =>
      'Ajouter le morceau juste après la piste en cours';

  @override
  String get songMenuAddToPlaylist => 'Ajouter à une playlist';

  @override
  String get songMenuAddToPlaylistHint =>
      'Ajouter rapidement à votre playlist la plus récente';

  @override
  String get songMenuAddToNewPlaylist => 'Ajouter à une nouvelle playlist';

  @override
  String get songMenuAddToNewPlaylistHint =>
      'Créer une playlist et y ajouter ce morceau';

  @override
  String get songMenuShare => 'Partager';

  @override
  String get songMenuShareHint =>
      'Partager le fichier audio avec une autre application';

  @override
  String get songMenuFetchCover => 'Récupérer la pochette manquante';

  @override
  String get songMenuFetchCoverHint =>
      'Rechercher une pochette sur Last.fm, Deezer et iTunes';

  @override
  String get songMenuFetchMetadata => 'Récupérer les métadonnées manquantes';

  @override
  String get songMenuFetchMetadataHint =>
      'Rechercher en ligne le titre, l’artiste, l’album et la pochette';

  @override
  String get songMenuMoveToFolder => 'Déplacer vers un dossier';

  @override
  String get songMenuMoveToFolderHint =>
      'Déplacer ce fichier dans un autre dossier';

  @override
  String get songMenuManagePlaylists => 'Gérer les playlists';

  @override
  String get songMenuManagePlaylistsHint =>
      'Ajouter ou retirer des morceaux des playlists';

  @override
  String get songMenuEditMetadata => 'Modifier les métadonnées';

  @override
  String get songMenuEditMetadataHint => 'Ouvrir l’éditeur de métadonnées';

  @override
  String get songMenuRemoveFavorite => 'Retirer des favoris';

  @override
  String get songMenuAddFavorite => 'Ajouter aux favoris';

  @override
  String get songMenuFavoritesHint => 'Gérer la liste de vos morceaux favoris';

  @override
  String get songMenuSuggestMore => 'Proposer plus souvent';

  @override
  String get songMenuSuggestLess => 'Proposer moins souvent';

  @override
  String get songMenuSuggestHint =>
      'Régler la fréquence d’apparition de ce morceau dans les suggestions';

  @override
  String get songMenuRemoveFromPlaylist => 'Retirer de la playlist actuelle';

  @override
  String get songMenuRemoveFromPlaylistHint =>
      'Conserver le fichier, retirer son association à la playlist';

  @override
  String get songMenuRemoveFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get songMenuRemoveFromLibraryHint =>
      'Conserver le fichier, mais le masquer de la bibliothèque';

  @override
  String get songMenuDeleteHint => 'Supprimer le fichier de l’appareil';

  @override
  String get bulkSelected => 'sélectionné(s)';

  @override
  String get bulkSelectAll => 'Tout sélectionner';

  @override
  String get bulkFavorite => 'Ajouter aux favoris';

  @override
  String get bulkUnfavorite => 'Retirer des favoris';

  @override
  String bulkRemovedFromFavorites(int count) {
    return '$count morceaux retirés des favoris';
  }

  @override
  String bulkAddedToFavorites(int count) {
    return '$count morceaux ajoutés aux favoris';
  }

  @override
  String get bulkPlaylist => 'Playlist';

  @override
  String bulkAddedToPlaylist(int count, Object name) {
    return '$count morceaux ajoutés à $name';
  }

  @override
  String bulkSongsCount(int count) {
    return '$count morceaux';
  }

  @override
  String get bulkMetadata => 'Métadonnées';

  @override
  String get bulkHideTitle => 'Masquer les morceaux';

  @override
  String bulkHideMessage(int count) {
    return 'Masquer les $count morceaux sélectionnés de la bibliothèque ?';
  }

  @override
  String get bulkDeleteTitle => 'Supprimer les fichiers';

  @override
  String bulkDeleteMessage(int count) {
    return 'Supprimer définitivement les $count fichiers du stockage ? Cette action est irréversible.';
  }

  @override
  String bulkAddedToQueue(int count) {
    return '$count morceaux ajoutés à la file d’attente';
  }

  @override
  String get bulkMove => 'Déplacer';

  @override
  String bulkMovedTo(int count, Object path) {
    return '$count morceaux déplacés vers $path';
  }

  @override
  String bulkMoveError(Object error) {
    return 'Erreur lors du déplacement des morceaux : $error';
  }

  @override
  String bulkWillSuggestMore(int count) {
    return '$count morceaux seront proposés plus souvent';
  }

  @override
  String bulkWillSuggestLess(int count) {
    return '$count morceaux seront proposés moins souvent';
  }

  @override
  String get queueTabUpNext => 'À suivre';

  @override
  String get queueTabHistory => 'Historique';

  @override
  String get queueActionMoveToTop => 'Déplacer en haut';

  @override
  String get queueActionRemove => 'Retirer';

  @override
  String get queueActionSongOptions => 'Options du morceau…';

  @override
  String get queueClearDialogTitle => 'Vider la file d’attente ?';

  @override
  String get queueClearDialogMessage =>
      'Tous les morceaux à venir seront retirés de la file d’attente actuelle.';

  @override
  String get queueClearAll => 'Tout vider';

  @override
  String get queueSectionPlayed => 'Écoutés';

  @override
  String get queueSectionNowPlaying => 'En cours de lecture';

  @override
  String get queueSectionUpNext => 'À suivre';

  @override
  String get queueSwipeAddToTop => 'Ajouter en haut';

  @override
  String get queueShuffleUpcomingTooltip => 'Mélanger les morceaux à venir';

  @override
  String get queueClearUpcomingTooltip => 'Vider les morceaux à venir';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return '$_temp0';
  }

  @override
  String queueRemainingSuffix(String remaining) {
    return '   ·  $remaining';
  }

  @override
  String get queueEmpty => 'La file d’attente est vide';

  @override
  String get queueRemoveFromQueueTooltip => 'Retirer de la file d’attente';

  @override
  String get queueRemovedLabel => 'Retiré de la file d’attente';

  @override
  String get queueUndo => 'Annuler';

  @override
  String get historyClearDialogTitle => 'Effacer l’historique ?';

  @override
  String get historyClearDialogMessage =>
      'Tous les instantanés enregistrés de la file d’attente seront supprimés.';

  @override
  String historyRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes restaurées',
      one: '1 piste restaurée',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadError => 'Impossible de charger l’historique';

  @override
  String get historyEmptyTitle => 'Aucune ancienne file d’attente';

  @override
  String get historyEmptyMessage =>
      'Les files d’attente que vous écoutez sont enregistrées ici automatiquement.';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files d’attente enregistrées',
      one: '1 file d’attente enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get historyClearAllTrailing => 'Tout effacer';

  @override
  String get historyDayToday => 'Aujourd’hui';

  @override
  String get historyDayYesterday => 'Hier';

  @override
  String get historyDayThisWeek => 'Cette semaine';

  @override
  String get historyDayThisMonth => 'Ce mois-ci';

  @override
  String get historyDayEarlier => 'Plus tôt';

  @override
  String get snapshotShuffledQueue => 'File d’attente mélangée';

  @override
  String get snapshotSavedQueue => 'File d’attente enregistrée';

  @override
  String get snapshotEmptyTracks =>
      'Aucune de ces pistes n’est encore dans votre bibliothèque.';

  @override
  String snapshotMoreHidden(int count) {
    return '+$count de plus';
  }

  @override
  String snapshotMissingCount(int count) {
    return '$count absentes de la bibliothèque';
  }

  @override
  String get queueMetaSeparator => '  · ';

  @override
  String get songListShuffle => 'Mélanger';

  @override
  String get songListPlay => 'Lire';

  @override
  String get songListPause => 'Mettre en pause';

  @override
  String get songListResume => 'Reprendre';

  @override
  String get songListFetchArtistCover =>
      'Récupérer la pochette de l’artiste en ligne';

  @override
  String get songListFetchAlbumCover =>
      'Récupérer la pochette de l’album en ligne';

  @override
  String get songListFetchCover => 'Récupérer la pochette en ligne';

  @override
  String get songListPlaylistOptions => 'Options de la playlist';

  @override
  String get songListSelectSongsToMerge =>
      'Sélectionner les morceaux à fusionner';

  @override
  String songListMergedSongs(int count) {
    return '$count morceaux fusionnés';
  }

  @override
  String songListMergeError(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get songListMergeSongs => 'Fusionner les morceaux';

  @override
  String get songListEmpty => 'Aucun morceau dans cette liste';

  @override
  String get actionRename => 'Renommer';

  @override
  String get songListRenamePlaylist => 'Renommer la playlist';

  @override
  String get songListDeletePlaylist => 'Supprimer la playlist';

  @override
  String songListDeletePlaylistConfirm(Object title) {
    return 'Voulez-vous vraiment supprimer « $title » ?';
  }

  @override
  String songListSearchingArtwork(Object name) {
    return 'Recherche en ligne d’une pochette pour $name…';
  }

  @override
  String songListSelectArtwork(Object name) {
    return 'Choisir une pochette pour $name';
  }

  @override
  String get songListUseSongCoverGrid =>
      'Utiliser la mosaïque des pochettes des morceaux';

  @override
  String get songListRemoveCustomArtwork =>
      'Supprimer la pochette personnalisée';

  @override
  String get songListChooseCustomImage => 'Choisir une image personnalisée';

  @override
  String get songListSelectFromDevice =>
      'Choisir une image dans le stockage de l’appareil';

  @override
  String songListArtworkFrom(Object source) {
    return 'Pochette provenant de $source';
  }

  @override
  String get songListNoOnlineArtwork => 'Aucune pochette disponible en ligne';

  @override
  String get songListResetArtwork =>
      'Rétablir la mosaïque des pochettes des morceaux';

  @override
  String songListArtworkUpdated(Object name) {
    return 'Pochette de $name mise à jour';
  }

  @override
  String get songListDownloadingArtwork => 'Téléchargement de la pochette…';

  @override
  String get songListArtworkDownloadFailed =>
      'Échec du téléchargement de la pochette';

  @override
  String get gradientDetailAlbums => 'Albums';

  @override
  String get gradientDetailSongs => 'Morceaux';

  @override
  String get gradientDetailShowAll => 'Tout afficher';

  @override
  String gradientDetailAlbumCount(int count) {
    return '$count albums';
  }

  @override
  String get syncPlayStats => 'Statistiques d’écoute';

  @override
  String get syncPlayStatsHint => 'Historique d’écoute et nombre d’écoutes';

  @override
  String get syncFavoritesHint => 'Morceaux favoris';

  @override
  String get syncSuggestLess => 'Proposer moins';

  @override
  String get syncSuggestLessHint =>
      'Morceaux que vous avez demandé à voir moins souvent';

  @override
  String get syncHiddenSongs => 'Morceaux masqués';

  @override
  String get syncPlaylistsHint => 'Toutes les playlists';

  @override
  String get syncMergedSongs => 'Morceaux fusionnés';

  @override
  String get syncMergedSongsHint => 'Groupes de morceaux fusionnés';

  @override
  String get syncAppSettings => 'Paramètres de l’application';

  @override
  String get syncAppSettingsHint => 'Thème, lecture et préférences d’interface';

  @override
  String get syncArtistArt => 'Pochettes des artistes';

  @override
  String get syncArtistArtHint => 'Choix de pochettes d’artistes en ligne';

  @override
  String get syncAlbumArt => 'Pochettes des albums';

  @override
  String get syncAlbumArtHint => 'Choix de pochettes d’albums en ligne';

  @override
  String get syncQueueHistory => 'Historique de la file d’attente';

  @override
  String get syncQueueHistoryHint => 'Files d’attente récemment écoutées';

  @override
  String get syncCurrentQueue => 'File d’attente actuelle';

  @override
  String get syncCurrentQueueHint =>
      'Envoyée automatiquement ; téléchargée uniquement lors d’une synchronisation manuelle';

  @override
  String get syncPreferCloudQueue => 'Privilégier la file d’attente du cloud';

  @override
  String get syncPreferCloudQueueHint =>
      'Activé : la synchronisation remplace la file d’attente de cet appareil par celle du cloud. Désactivé : la file de cet appareil est conservée et envoyée.';

  @override
  String get syncPrivacy => 'Confidentialité';

  @override
  String get syncEncryptedTitle => 'Chiffrement de bout en bout';

  @override
  String get syncEncryptedBody =>
      'Vos données sont chiffrées sur cet appareil avant l’envoi. Le serveur ne stocke que du texte chiffré et ne peut pas lire votre bibliothèque, votre historique ni vos paramètres.';

  @override
  String get syncRecoveryKeyTitle => 'Clé de récupération';

  @override
  String get syncRecoveryKeyBody =>
      'Si vous oubliez votre mot de passe, seule votre clé de récupération permet de retrouver l’accès. Personne d’autre ne le peut.';

  @override
  String get syncAccount => 'Compte';

  @override
  String get syncSignedIn => 'Connecté';

  @override
  String get syncConnected => 'Connexion établie';

  @override
  String get syncLogOut => 'Se déconnecter';

  @override
  String get syncLogOutBody =>
      'La synchronisation s’arrête sur cet appareil. Les données locales et celles du cloud sont conservées.';

  @override
  String get syncLogOutAndChange => 'Se déconnecter et modifier';

  @override
  String get syncCloud => 'Cloud';

  @override
  String get syncLastSynced => 'Dernière synchronisation';

  @override
  String get syncNever => 'Jamais';

  @override
  String syncUsedOfQuota(Object used, Object quota) {
    return '$used sur $quota utilisés';
  }

  @override
  String get syncJustNow => 'À l’instant';

  @override
  String syncMinutesAgo(int count) {
    return 'Il y a $count min';
  }

  @override
  String syncHoursAgo(int count) {
    return 'Il y a $count h';
  }

  @override
  String syncDaysAgo(int count) {
    return 'Il y a $count j';
  }

  @override
  String get syncAutoSync => 'Synchronisation automatique';

  @override
  String get syncAutoSyncHint =>
      'Synchroniser en arrière-plan lorsque l’application est ouverte';

  @override
  String get syncNow => 'Synchroniser maintenant';

  @override
  String get syncMergeDeviceHint => 'Fusionner cet appareil avec le cloud';

  @override
  String syncLastError(Object error) {
    return 'Dernière erreur : $error';
  }

  @override
  String get syncWhatGetsSynced => 'Données synchronisées';

  @override
  String get syncDeviceStatsAttribution =>
      'Attribution des statistiques par appareil';

  @override
  String get syncThisDevice => 'Cet appareil';

  @override
  String get syncOtherDevices => 'Autres appareils';

  @override
  String get syncTotalLibraryStats =>
      'Statistiques globales de la bibliothèque';

  @override
  String syncPlays(int count) {
    return '$count écoutes';
  }

  @override
  String get syncDangerZone => 'Zone sensible';

  @override
  String get syncOverwriteCloudTile =>
      'Remplacer le cloud par les données de cet appareil';

  @override
  String get syncOverwriteCloudTileHint =>
      'Remplacer toutes les données du cloud par celles de cet appareil';

  @override
  String get syncReplaceDeviceTile =>
      'Remplacer cet appareil par les données du cloud';

  @override
  String get syncReplaceDeviceTileHint =>
      'Effacer les données synchronisées de cet appareil et utiliser la copie du cloud';

  @override
  String get syncChangePassword => 'Modifier le mot de passe';

  @override
  String get syncNewRecoveryKey => 'Nouvelle clé de récupération';

  @override
  String get syncNewRecoveryKeyHint =>
      'L’ancienne clé de récupération cessera de fonctionner';

  @override
  String get syncChangeServer => 'Changer de serveur';

  @override
  String get syncChangeServerHint => 'Vous devez d’abord vous déconnecter';

  @override
  String get syncChangeServerBody =>
      'Vous serez d’abord déconnecté du serveur actuel. Les données locales seront conservées.';

  @override
  String get syncDeleteCloudAccount => 'Supprimer le compte cloud';

  @override
  String get syncDeleteCloudAccountHint =>
      'Supprimer définitivement les données du cloud. Les données locales seront conservées.';

  @override
  String get syncDeleteCloudAccountBody =>
      'Votre compte cloud et toutes les données chiffrées sur le serveur seront définitivement supprimés. Les données de cet appareil seront conservées.';

  @override
  String get syncOverwriteCloud => 'Remplacer les données du cloud';

  @override
  String get syncOverwriteCloudBody =>
      'Les données du cloud seront remplacées par celles de cet appareil. Les autres appareils devront choisir la suite. Les données de cet appareil seront conservées.';

  @override
  String get syncOverwriteCloudCheckbox =>
      'Je comprends que les données du cloud seront perdues';

  @override
  String get syncOverwrite => 'Remplacer';

  @override
  String get syncReplaceDevice => 'Remplacer cet appareil';

  @override
  String get syncReplaceDeviceBody =>
      'Les données synchronisées de cet appareil (statistiques, favoris, playlists, etc.) seront effacées et remplacées par la copie du cloud. Les fichiers musicaux ne seront pas modifiés.';

  @override
  String get syncReplaceDeviceCheckbox =>
      'Je comprends que les données synchronisées locales seront perdues';

  @override
  String get syncReplace => 'Remplacer';

  @override
  String get syncCurrentPassword => 'Mot de passe actuel';

  @override
  String get syncNewPassword => 'Nouveau mot de passe';

  @override
  String get syncPassword => 'Mot de passe';

  @override
  String get syncPasswordChanged => 'Mot de passe modifié';

  @override
  String get syncGenerate => 'Générer';

  @override
  String get appearanceGroupNowPlaying => 'Lecture en cours';

  @override
  String get appearanceVisualizerTitle => 'Visualiseur audio';

  @override
  String get appearanceVisualizerSubtitle =>
      'Barres sur la pochette pendant la lecture — le mode synchronisé suit le morceau, les basses sont à gauche';

  @override
  String get appearanceVisualizerClassic => 'Classique';

  @override
  String get appearanceVisualizerSynced => 'Synchronisé';

  @override
  String get appearanceProgressBarTitle => 'Style de la barre de progression';

  @override
  String get appearanceProgressBasicSubtitle => 'Barre de progression simple';

  @override
  String get appearanceProgressWaveformSubtitle =>
      'Forme d’onde audio statique';

  @override
  String get appearanceProgressReactiveSubtitle =>
      'Forme d’onde dynamique réactive au son, avec spectre en direct et réponse au rythme';

  @override
  String get appearanceProgressStandard => 'Standard';

  @override
  String get appearanceProgressWaveform => 'Forme d’onde';

  @override
  String get appearanceProgressSoundReactive => 'Réactive au son';

  @override
  String get appearanceHapticsTitle =>
      'Retour haptique lors du déplacement sur la forme d’onde';

  @override
  String get appearanceHapticsSubtitle =>
      'Retour haptique à chaque barre lors du déplacement dans le morceau';

  @override
  String get appearanceCoverSizingTitle => 'Taille de la pochette du lecteur';

  @override
  String get appearanceCoverSizingSubtitle =>
      'Ajuster automatiquement ou conserver les proportions d’origine';

  @override
  String get appearanceCoverAutoFit => 'Ajustement automatique';

  @override
  String get appearanceCoverSourceSize => 'Taille d’origine';

  @override
  String get appearanceImmersiveTitle => 'Mode immersif';

  @override
  String get appearanceImmersiveSubtitle =>
      'Pochette en plein écran et écrans de détails avec dégradé';

  @override
  String get appearancePlayerSwipeTitle => 'Le balayage change de panneau';

  @override
  String get appearancePlayerSwipeSubtitle =>
      'Balayez à gauche ou à droite pour passer entre les paroles, le lecteur et la file d’attente. Désactivez cette option pour changer de morceau à la place.';

  @override
  String get appearanceGroupPlayerMotion => 'Animations du lecteur';

  @override
  String get appearanceBeatCoverTitle => 'Pochette réactive au rythme';

  @override
  String get appearanceBeatCoverUnavailable =>
      'Indisponible lorsque le mode immersif est activé';

  @override
  String get appearanceBeatCoverSubtitle =>
      'La pochette de l’album pulse au rythme';

  @override
  String get appearanceCoverIntensityTitle => 'Intensité de la pochette';

  @override
  String get appearanceCoverIntensitySubtitle =>
      'Intensité de la réaction de la pochette';

  @override
  String get appearanceSpinArtworkTitle =>
      'Faire tourner la pochette pendant la lecture';

  @override
  String get appearanceSpinArtworkSubtitle =>
      'La pochette tourne lentement dans la barre inférieure réduite pendant la lecture d’un morceau';

  @override
  String get appearanceParticlesTitle => 'Particules réactives au rythme';

  @override
  String get appearanceParticlesSubtitle =>
      'Des particules flottantes dérivent et pulsent avec la musique';

  @override
  String get appearanceParticleDensityTitle => 'Densité des particules';

  @override
  String get appearanceParticleDensitySubtitle =>
      'Nombre de particules et vivacité de leur mouvement';

  @override
  String get appearanceBeatOffsetTitle =>
      'Décalage de synchronisation du rythme';

  @override
  String get appearanceBeatOffsetNone =>
      'Aucun décalage — augmentez-le si l’impulsion semble en avance';

  @override
  String appearanceBeatOffsetValue(int ms) {
    return '$ms ms';
  }

  @override
  String appearanceBeatOffsetBluetooth(int ms) {
    return '$ms ms (à augmenter avec le Bluetooth)';
  }

  @override
  String get appearanceCalibrateTitle =>
      'Calibrer la synchronisation du rythme';

  @override
  String get appearanceCalibrateSubtitle =>
      'Alignez les particules à l’oreille sur un clic régulier';

  @override
  String get appearanceAppIcon => 'Icône de l’application';

  @override
  String get appearanceIntensityMin => 'Min.';

  @override
  String get appearanceIntensitySubtle => 'Discrète';

  @override
  String get appearanceIntensityBalanced => 'Équilibrée';

  @override
  String get appearanceIntensityBold => 'Intense';

  @override
  String get appearanceIntensityMax => 'Max.';

  @override
  String get appearanceIntensityCustom => 'Personnalisée';

  @override
  String get backupExportAppData => 'Exporter les données de l’application';

  @override
  String get backupExportAppDataSubtitle =>
      'Sauvegarder vos statistiques, favoris et playlists';

  @override
  String backupExportFailed(Object error) {
    return 'Échec de l’exportation : $error';
  }

  @override
  String get backupImportAppData => 'Importer les données de l’application';

  @override
  String get backupImportAppDataSubtitle =>
      'Restaurer des données depuis une sauvegarde (remplace tout)';

  @override
  String get backupManageBackups => 'Gérer les sauvegardes';

  @override
  String get backupManageBackupsSubtitle =>
      'Créer, restaurer et gérer les sauvegardes de l’application';

  @override
  String get backupAutomaticBackups => 'Sauvegardes automatiques';

  @override
  String get backupAutoBackup => 'Sauvegarde automatique';

  @override
  String get backupAutoBackupSubtitle => 'Fréquence des sauvegardes';

  @override
  String get backupAutoBackupContent => 'Contenu des sauvegardes automatiques';

  @override
  String get backupAutoBackupContentSubtitle =>
      'Données incluses dans les sauvegardes automatiques';

  @override
  String get backupAutoBackupContentDialogSubtitle =>
      'Choisir le contenu des sauvegardes automatiques';

  @override
  String get backupSave => 'Enregistrer';

  @override
  String get backupAutoDeleteOld =>
      'Supprimer automatiquement les anciennes sauvegardes';

  @override
  String get backupAutoDeleteOldSubtitle =>
      'Supprimer les sauvegardes plus anciennes que cette durée';

  @override
  String get backupFrequencyDisabled => 'Désactivées';

  @override
  String get backupFrequencyEvery24Hours => 'Toutes les 24 heures';

  @override
  String get backupFrequencyEvery48Hours => 'Toutes les 48 heures';

  @override
  String get backupFrequencyEvery3Days => 'Tous les 3 jours';

  @override
  String get backupFrequencyEvery7Days => 'Tous les 7 jours';

  @override
  String backupDeleteAfterDays(int count) {
    return '$count jours';
  }

  @override
  String get backupExportOptionsTitle => 'Options d’exportation';

  @override
  String get backupExportSelectContent =>
      'Sélectionnez les données à exporter :';

  @override
  String get backupContentUserStats => 'Statistiques utilisateur';

  @override
  String get backupContentUserStatsSubtitle =>
      'Nombre d’écoutes, sessions, statistiques amusantes';

  @override
  String get backupContentUserData => 'Données utilisateur';

  @override
  String get backupContentUserDataSubtitle =>
      'Favoris, éléments masqués, playlists';

  @override
  String get backupContentUserSettings => 'Paramètres utilisateur';

  @override
  String get backupContentUserSettingsSubtitle =>
      'Thème, ordre de tri, préférences';

  @override
  String get backupContentCoverCacheSubtitle => 'Images des pochettes d’albums';

  @override
  String get backupContentLibraryCacheSubtitle =>
      'Métadonnées des morceaux en cache';

  @override
  String get backupContentSearchIndexSubtitle =>
      'Données d’indexation de la recherche';

  @override
  String get backupContentWaveformCacheSubtitle =>
      'Données de forme d’onde audio';

  @override
  String get backupContentColorCacheSubtitle => 'Thèmes de couleur des albums';

  @override
  String get backupContentLyricsCacheSubtitle => 'Paroles enregistrées';

  @override
  String get backupCancelUpper => 'ANNULER';

  @override
  String get backupExportUpper => 'EXPORTER';

  @override
  String get backupContinueUpper => 'CONTINUER';

  @override
  String get backupImportDataTitle => 'Importer des données';

  @override
  String get backupImportWarning =>
      'Toutes les données existantes seront remplacées par celles de l’importation.\n\nVos statistiques, favoris, playlists et paramètres actuels seront écrasés.\n\nCette action est irréversible.';

  @override
  String get backupImportingLabel => 'Importation…';

  @override
  String get backupImportingTitle => 'Importation des données';

  @override
  String get backupImportSuccess => 'Importation réussie !';

  @override
  String backupImportFailed(Object error) {
    return 'Échec de l’importation : $error';
  }

  @override
  String get metadataCoverUpdated => 'Pochette mise à jour';

  @override
  String metadataPickImageError(Object error) {
    return 'Erreur lors du choix de l’image : $error';
  }

  @override
  String get metadataRemoveCoverTitle => 'Supprimer la pochette';

  @override
  String get metadataRemoveCoverBody =>
      'Voulez-vous vraiment supprimer la pochette ?';

  @override
  String get metadataRemoveUpper => 'SUPPRIMER';

  @override
  String get metadataCoverRemoved => 'Pochette supprimée';

  @override
  String metadataRemoveCoverError(Object error) {
    return 'Erreur lors de la suppression de la pochette : $error';
  }

  @override
  String get metadataFixResultTitle =>
      'Résultat de la correction de la miniature';

  @override
  String get metadataFixReviewBody => 'Vérifiez les modifications ci-dessous :';

  @override
  String get metadataFixOriginal => 'Originale';

  @override
  String get metadataFixNew => 'Nouvelle';

  @override
  String metadataFixNewOption(int n) {
    return 'Nouvelle (option $n)';
  }

  @override
  String get metadataFixSeeAlternatives => 'Voir les alternatives';

  @override
  String get metadataFixApply => 'Appliquer';

  @override
  String get metadataFixSuccess => 'Miniature corrigée';

  @override
  String metadataFixError(Object error) {
    return 'Erreur lors de la correction de la miniature : $error';
  }

  @override
  String get metadataFixThumbnail => 'Corriger la miniature';

  @override
  String get metadataFixHelpBody =>
      'Cet outil améliore automatiquement vos pochettes d’album en :\n\n1. Détectant et supprimant les bandes et bordures noires (fréquentes sur les miniatures YouTube)\n2. Recadrant l’image en carré parfait (ratio 1:1)\n\nIdéal pour convertir les miniatures 16:9 en véritables pochettes d’album.';

  @override
  String get metadataGotIt => 'Compris';

  @override
  String get metadataExportCover => 'Exporter la pochette';

  @override
  String get metadataExport => 'Exporter';

  @override
  String metadataExportSuccess(Object uri) {
    return 'Pochette exportée vers $uri';
  }

  @override
  String metadataExportError(Object error) {
    return 'Erreur lors de l’exportation de la pochette : $error';
  }

  @override
  String get metadataReplaceSong => 'Remplacer le morceau';

  @override
  String get metadataReplaceHelpBody =>
      'Remplace le fichier de ce morceau par une autre copie du même morceau (meilleure extraction, sans perte, encodage propre).\n\nL’historique d’écoute, les favoris, les playlists et la date d’ajout à la bibliothèque sont transférés vers le nouveau fichier. Ses métadonnées sont relues depuis le fichier ; celles qui sont absentes sont indiquées comme inconnues.\n\nLe nouveau fichier doit se trouver hors des dossiers de votre bibliothèque et avoir un nom de fichier différent.';

  @override
  String metadataReplaced(Object filename) {
    return 'Remplacé par $filename';
  }

  @override
  String metadataReplaceError(Object error) {
    return 'Impossible de remplacer le fichier : $error';
  }

  @override
  String metadataReplaceFilesBody(Object oldName, Object newName) {
    return '$oldName\nremplacé par $newName';
  }

  @override
  String get metadataReplaceOriginalQuestion => 'Que faire de l’original ?';

  @override
  String get metadataReplaceRejectNoFile =>
      'Aucun fichier n’a été sélectionné.';

  @override
  String get metadataReplaceRejectUnsupported =>
      'Ce fichier n’est pas dans un format audio ou vidéo lisible par cette bibliothèque.';

  @override
  String get metadataReplaceRejectSameFilename =>
      'Le fichier de remplacement doit avoir un nom différent. Changer uniquement l’extension suffit.';

  @override
  String get metadataReplaceRejectInsideLibrary =>
      'Ce fichier se trouve dans l’un des dossiers de votre bibliothèque. Choisissez une copie située ailleurs.';

  @override
  String metadataReplaceRejectDestinationExists(String filename) {
    return 'Un fichier nommé « $filename » se trouve déjà à côté de l’original.';
  }

  @override
  String metadataReplaceRejectLibraryHasName(String filename) {
    return 'Votre bibliothèque contient déjà un morceau nommé « $filename ».';
  }

  @override
  String get metadataKeepHideUpper => 'CONSERVER ET MASQUER';

  @override
  String get metadataDeleteItUpper => 'LE SUPPRIMER';

  @override
  String get metadataSaved => 'Métadonnées mises à jour';

  @override
  String metadataSaveError(Object error) {
    return 'Erreur lors de l’enregistrement des métadonnées : $error';
  }

  @override
  String get metadataNoOnlineCover => 'Aucune pochette trouvée en ligne';

  @override
  String get metadataSelectCoverTitle => 'Choisir une pochette';

  @override
  String metadataResultTitleArtist(Object title, Object artist) {
    return '$title - $artist';
  }

  @override
  String metadataSourceLabel(Object source) {
    return 'Source : $source';
  }

  @override
  String metadataCoverUpdatedFrom(Object source) {
    return 'Pochette mise à jour depuis $source';
  }

  @override
  String get metadataNoOnlineMatch =>
      'Aucune métadonnée correspondante trouvée en ligne';

  @override
  String get metadataSelectMatchTitle => 'Choisir une correspondance en ligne';

  @override
  String metadataResultDetail(Object artist, Object album, Object source) {
    return '$artist · $album ($source)';
  }

  @override
  String metadataLoadedFrom(Object source) {
    return 'Métadonnées et pochette chargées depuis $source';
  }

  @override
  String metadataFetchError(Object error) {
    return 'Erreur lors de la récupération des métadonnées : $error';
  }

  @override
  String get metadataSectionCover => 'Pochette';

  @override
  String get metadataChangeCover => 'Modifier la pochette';

  @override
  String get metadataWhatDoesThisDo => 'À quoi cela sert-il ?';

  @override
  String get metadataSectionFile => 'Informations sur le fichier';

  @override
  String get metadataFilenameLabel => 'Nom du fichier (sans extension)';

  @override
  String get metadataFilenameHelper =>
      'Le renommage du fichier sera appliqué localement.';

  @override
  String get metadataSectionSong => 'Métadonnées du morceau';

  @override
  String get metadataFetchOnline => 'Récupérer en ligne';

  @override
  String get metadataTitleLabel => 'Titre';

  @override
  String get metadataArtistLabel => 'Artiste';

  @override
  String get metadataAlbumLabel => 'Album';

  @override
  String get metadataSectionExtra => 'Contenu supplémentaire';

  @override
  String get metadataEditLyrics => 'Modifier les paroles';

  @override
  String get metadataEditLyricsSubtitle =>
      'Afficher ou modifier les paroles intégrées';

  @override
  String get metadataSaveUpper => 'ENREGISTRER';

  @override
  String metadataLyricsLoadError(Object error) {
    return 'Erreur lors du chargement des paroles : $error';
  }

  @override
  String metadataLyricsSaveError(Object error) {
    return 'Erreur lors de l’enregistrement des paroles : $error';
  }

  @override
  String get metadataLyricsLoaded =>
      'Paroles chargées — appuyez sur ENREGISTRER pour appliquer';

  @override
  String get metadataSearchOnline => 'Rechercher en ligne';

  @override
  String get metadataLyricsHint =>
      'Les paroles sont intégrées au fichier audio. Vous pouvez utiliser des horodatages [mm:ss.xx] pour synchroniser les paroles.';

  @override
  String get metadataLyricsFieldHint => 'Saisissez les paroles ici…';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileAvatarFallback => 'U';

  @override
  String get profileDefaultName => 'Utilisateur';

  @override
  String get appName => 'wispie';

  @override
  String profileAppVersion(String version) {
    return 'wispie v$version';
  }

  @override
  String get profileHidden => 'Masqués';

  @override
  String get profileSuggestLess => 'À moins suggérer';

  @override
  String get profileShuffleSection => 'Lecture aléatoire';

  @override
  String get profileSmart => 'Lecture aléatoire intelligente';

  @override
  String get profileSmartSubtitle =>
      'Apprend vos goûts, les tendances et le contexte';

  @override
  String get profileChangeName => 'Modifier le nom affiché';

  @override
  String get profileNewNameHint => 'Nouveau nom';

  @override
  String get profileUpdate => 'Mettre à jour';

  @override
  String get profileNameUpdated => 'Nom mis à jour';

  @override
  String profileCurrentName(String name) {
    return 'Actuel : $name';
  }

  @override
  String get profileThemeStorage => 'Thème et stockage';

  @override
  String get profileFamiliar => 'Familier';

  @override
  String get profileDiscover => 'Découverte';

  @override
  String get profileFamiliarToDiscover => 'Du familier à la découverte';

  @override
  String get storageManageTitle => 'Gérer le stockage';

  @override
  String get storageRepairCardTitle => 'Réparer les liens de la bibliothèque';

  @override
  String get storageRepairCardBody =>
      'Pochettes d’album manquantes après une restauration ou sur un nouveau téléphone ? Cette fonction relie à nouveau les pochettes et les chemins de fichiers.';

  @override
  String get storageRepair => 'Réparer';

  @override
  String get storageRepairTitle => 'Réparer les liens de la bibliothèque ?';

  @override
  String get storageRepairBody =>
      'Cette fonction relie les pochettes d’album en cache et les chemins de fichiers à leur emplacement réel sur cet appareil.\n\nLes pistes dont les fichiers ne sont plus présents ici seront retirées de la bibliothèque. Les favoris, playlists et nombres d’écoutes seront conservés et automatiquement réassociés si ces fichiers réapparaissent.';

  @override
  String storageRepairError(Object error) {
    return 'Erreur lors de la réparation de la bibliothèque : $error';
  }

  @override
  String get storageDatabaseTitle => 'Base de données';

  @override
  String get storageDatabaseSubtitle =>
      'Données utilisateur, statistiques et paramètres';

  @override
  String get storageCoverCacheTitle => 'Cache des pochettes';

  @override
  String get storageCoverCacheSubtitle =>
      'Pochettes d’album des morceaux en cache';

  @override
  String get storageBackupsTitle => 'Sauvegardes';

  @override
  String get storageBackupsSubtitle => 'Fichiers de sauvegarde locaux';

  @override
  String get storageLibraryCacheTitle => 'Cache de la bibliothèque';

  @override
  String get storageLibraryCacheSubtitle =>
      'Données de la bibliothèque musicale en cache';

  @override
  String get storageSearchIndexTitle => 'Index de recherche';

  @override
  String get storageSearchIndexSubtitle =>
      'Index de recherche pour accélérer les requêtes';

  @override
  String get storageWaveformCacheTitle => 'Cache des formes d’onde';

  @override
  String get storageWaveformCacheSubtitle =>
      'Formes d’onde des morceaux en cache pour les visualiseurs';

  @override
  String get storageBeatAnalysisTitle => 'Analyse du rythme';

  @override
  String get storageBeatAnalysisSubtitle =>
      'Cartes rythmiques en cache pour le lecteur réactif';

  @override
  String get storageColorCacheTitle => 'Cache des couleurs';

  @override
  String get storageColorCacheSubtitle =>
      'Couleurs de thème extraites des pochettes d’album et mises en cache';

  @override
  String get storageLyricsCacheTitle => 'Cache des paroles';

  @override
  String get storageLyricsCacheSubtitle =>
      'Disponibilité et texte des paroles en cache';

  @override
  String get storageOnlineAudioTitle => 'Cache audio en ligne';

  @override
  String get storageOnlineAudioSubtitle =>
      'Morceaux écoutés en streaming conservés sur le disque pour une lecture hors ligne instantanée';

  @override
  String get storageClearOnlineAudioTitle => 'Vider le cache audio en ligne ?';

  @override
  String get storageClearOnlineAudioBody =>
      'Les morceaux téléchargés seront de nouveau diffusés depuis Internet. Votre bibliothèque, vos playlists et vos favoris ne seront pas modifiés.';

  @override
  String get storageClearOnlineAudioSuccess => 'Cache audio en ligne vidé';

  @override
  String storageClearOnlineAudioError(Object error) {
    return 'Erreur lors du vidage du cache audio en ligne : $error';
  }

  @override
  String get storageBlurredCacheTitle => 'Cache des arrière-plans floutés';

  @override
  String get storageBlurredCacheSubtitle => 'Arrière-plans floutés pré-générés';

  @override
  String get storageClearCache => 'Vider le cache';

  @override
  String get storageClearDatabaseTitle => 'Vider la base de données ?';

  @override
  String get storageClearDatabaseBody =>
      'Toutes vos données utilisateur seront définitivement supprimées, notamment :\n\n• Toutes les playlists\n• Les favoris et les morceaux masqués\n• Les statistiques de lecture\n• Les paramètres et préférences de l’application\n\nL’application sera réinitialisée. Cette action est irréversible.';

  @override
  String get storageClearDatabaseAction => 'Vider la base de données';

  @override
  String storageClearDatabaseError(Object error) {
    return 'Erreur lors du vidage de la base de données : $error';
  }

  @override
  String get storageClearCoversTitle => 'Vider le cache des pochettes ?';

  @override
  String get storageClearCoversBody =>
      'Toutes les pochettes d’album en cache seront supprimées.\n\nElles seront extraites à nouveau de vos fichiers musicaux la prochaine fois que vous parcourrez votre bibliothèque.';

  @override
  String get storageClearCoversAction => 'Vider les pochettes';

  @override
  String get storageClearCoversSuccess => 'Cache des pochettes vidé';

  @override
  String storageClearCoversError(Object error) {
    return 'Erreur lors de la suppression des pochettes : $error';
  }

  @override
  String get storageClearBackupsTitle => 'Supprimer les sauvegardes ?';

  @override
  String get storageClearBackupsBody =>
      'Tous les fichiers de sauvegarde locaux seront supprimés.\n\nVeillez à exporter les sauvegardes importantes avant de continuer.';

  @override
  String get storageClearBackupsAction => 'Supprimer les sauvegardes';

  @override
  String get storageClearBackupsSuccess => 'Sauvegardes supprimées';

  @override
  String storageClearBackupsError(Object error) {
    return 'Erreur lors de la suppression des sauvegardes : $error';
  }

  @override
  String get storageClearLibraryTitle => 'Vider le cache de la bibliothèque ?';

  @override
  String get storageClearLibraryBody =>
      'Le cache de la bibliothèque sera vidé.\n\nVotre bibliothèque musicale sera analysée à nouveau lors de la prochaine ouverture de l’application.';

  @override
  String get storageClearLibrarySuccess => 'Cache de la bibliothèque vidé';

  @override
  String storageClearLibraryError(Object error) {
    return 'Erreur lors du vidage du cache de la bibliothèque : $error';
  }

  @override
  String get storageClearSearchTitle => 'Vider l’index de recherche ?';

  @override
  String get storageClearSearchBody =>
      'L’index de recherche sera supprimé.\n\nIl sera automatiquement recréé lors de la prochaine analyse de votre bibliothèque.';

  @override
  String get storageClearSearchAction => 'Vider l’index';

  @override
  String get storageClearSearchSuccess => 'Index de recherche vidé';

  @override
  String storageClearSearchError(Object error) {
    return 'Erreur lors du vidage de l’index de recherche : $error';
  }

  @override
  String get storageClearWaveformTitle => 'Vider le cache des formes d’onde ?';

  @override
  String get storageClearWaveformBody =>
      'Toutes les formes d’onde des morceaux en cache seront supprimées.\n\nElles seront régénérées la prochaine fois que vous consulterez les détails d’un morceau.';

  @override
  String get storageClearWaveformSuccess => 'Cache des formes d’onde vidé';

  @override
  String storageClearWaveformError(Object error) {
    return 'Erreur lors du vidage du cache des formes d’onde : $error';
  }

  @override
  String get storageClearBeatTitle => 'Effacer l’analyse du rythme ?';

  @override
  String get storageClearBeatBody =>
      'Les cartes rythmiques en cache utilisées par le lecteur réactif au rythme seront supprimées.\n\nElles seront recréées automatiquement à la prochaine lecture de chaque morceau.';

  @override
  String get storageClearBeatSuccess => 'Cache de l’analyse du rythme vidé';

  @override
  String storageClearBeatError(Object error) {
    return 'Erreur lors du vidage du cache de l’analyse du rythme : $error';
  }

  @override
  String get storageClearColorTitle => 'Vider le cache des couleurs ?';

  @override
  String get storageClearColorBody =>
      'Toutes les couleurs de thème en cache seront supprimées.\n\nElles seront extraites à nouveau des pochettes d’album à la prochaine lecture des morceaux.';

  @override
  String get storageClearColorSuccess => 'Cache des couleurs vidé';

  @override
  String storageClearColorError(Object error) {
    return 'Erreur lors du vidage du cache des couleurs : $error';
  }

  @override
  String get storageClearLyricsTitle => 'Vider le cache des paroles ?';

  @override
  String get storageClearLyricsBody =>
      'Les recherches de paroles en cache seront supprimées.\n\nLes paroles seront relues depuis les métadonnées des morceaux lorsque nécessaire.';

  @override
  String get storageClearLyricsSuccess => 'Cache des paroles vidé';

  @override
  String storageClearLyricsError(Object error) {
    return 'Erreur lors du vidage du cache des paroles : $error';
  }

  @override
  String get storageClearBlurredTitle =>
      'Vider le cache des arrière-plans floutés ?';

  @override
  String get storageClearBlurredBody =>
      'Tous les arrière-plans floutés pré-générés seront supprimés.\n\nIls seront recréés lors du prochain lancement d’une reconstruction dans l’indexeur.';

  @override
  String get storageClearBlurredSuccess =>
      'Cache des arrière-plans floutés vidé';

  @override
  String storageClearBlurredError(Object error) {
    return 'Erreur lors du vidage du cache des arrière-plans floutés : $error';
  }

  @override
  String get storageClearAllTitle =>
      'Effacer toutes les données de l’application ?';

  @override
  String get storageClearAllBody =>
      'Cette action est risquée et irréversible.\n\nLes éléments suivants seront définitivement supprimés :\n• Toutes vos préférences et tous vos paramètres\n• Les statistiques et l’historique de lecture\n• Les pochettes des morceaux en cache\n• Toutes les sauvegardes locales\n• Le cache de la bibliothèque\n• L’index de recherche\n• Le cache des formes d’onde\n• Le cache des paroles\n\nL’application sera réinitialisée.';

  @override
  String get storageClearAllAction => 'Tout effacer';

  @override
  String storageClearAllError(Object error) {
    return 'Erreur lors de la suppression des données : $error';
  }

  @override
  String get storageClearAllTile => 'Effacer toutes les données utilisateur';

  @override
  String get storageClearAllTileSubtitle =>
      'Supprimer définitivement toutes les données et réinitialiser l’application';

  @override
  String get storageFinalConfirmTitle => 'Confirmation finale';

  @override
  String storageConfirmTypePrompt(Object word) {
    return 'Pour confirmer, saisissez « $word » ci-dessous :';
  }

  @override
  String get storageDeleteKeyword => 'SUPPRIMER';

  @override
  String get storageConfirmUpper => 'CONFIRMER';

  @override
  String get storageTypeExactly =>
      'Veuillez saisir exactement le texte de confirmation.';

  @override
  String storageSizeBytes(Object value) {
    return '$value o';
  }

  @override
  String storageSizeKb(Object value) {
    return '$value Ko';
  }

  @override
  String storageSizeMb(Object value) {
    return '$value Mo';
  }

  @override
  String storageSizeGb(Object value) {
    return '$value Go';
  }

  @override
  String get settingsSearchIndexerSubtitle =>
      'Reconstruire les index et les caches';

  @override
  String get settingsSearchMusicFoldersTitle => 'Dossiers musicaux';

  @override
  String get settingsSearchMusicFoldersSubtitle =>
      'Gérer les dossiers de la bibliothèque musicale';

  @override
  String get settingsSearchRescanTitle => 'Analyser de nouveau la bibliothèque';

  @override
  String get settingsSearchRescanSubtitle =>
      'Actualiser manuellement tous les morceaux depuis le disque';

  @override
  String get settingsSearchIncludeVideosTitle => 'Inclure les vidéos';

  @override
  String get settingsSearchIncludeVideosSubtitle =>
      'Afficher les fichiers vidéo dans votre bibliothèque musicale';

  @override
  String get settingsSearchMinFileSizeTitle => 'Taille minimale des fichiers';

  @override
  String get settingsSearchMinFileSizeSubtitle =>
      'Ignorer les fichiers plus petits que cette taille';

  @override
  String get settingsSearchMinDurationTitle => 'Durée minimale';

  @override
  String get settingsSearchMinDurationSubtitle =>
      'Ignorer les pistes plus courtes que cette durée';

  @override
  String get settingsSearchManageFoldersTitle => 'Gérer les dossiers musicaux';

  @override
  String get settingsSearchManageFoldersSubtitle =>
      'Ajouter, supprimer et analyser à nouveau des dossiers individuellement';

  @override
  String get settingsSearchPullToRefreshTitle => 'Tirer pour actualiser';

  @override
  String get settingsSearchPullToRefreshSubtitle =>
      'Balayer vers le bas pour actualiser la bibliothèque';

  @override
  String get settingsSearchAutoPauseMuteTitle =>
      'Mettre en pause en cas de sourdine';

  @override
  String get settingsSearchAutoPauseMuteSubtitle =>
      'Mettre la lecture en pause lorsque le volume atteint 0';

  @override
  String get settingsSearchAutoResumeUnmuteTitle =>
      'Reprendre après la sourdine';

  @override
  String get settingsSearchAutoResumeUnmuteSubtitle =>
      'Reprendre la lecture lorsque le volume est rétabli';

  @override
  String get settingsSearchGapTitle => 'Silence / délai';

  @override
  String get settingsSearchGapSubtitle => 'Silence entre les morceaux';

  @override
  String get settingsSearchFadeOutTitle => 'Fondu de sortie';

  @override
  String get settingsSearchFadeOutSubtitle =>
      'Appliquer un fondu au morceau qui se termine';

  @override
  String get settingsSearchFadeInTitle => 'Fondu d’entrée';

  @override
  String get settingsSearchFadeInSubtitle =>
      'Appliquer un fondu au morceau qui commence';

  @override
  String get settingsSearchFadePlayTitle => 'Fondu au démarrage';

  @override
  String get settingsSearchFadePlaySubtitle =>
      'Augmenter progressivement le volume au démarrage de la lecture';

  @override
  String get settingsSearchFadePauseTitle => 'Fondu à la pause';

  @override
  String get settingsSearchFadePauseSubtitle =>
      'Diminuer progressivement le volume à l’arrêt de la lecture';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Langue de traduction des paroles';

  @override
  String get settingsSearchTranslationModeSubtitle =>
      'Afficher une traduction sous les paroles ou remplacer les paroles d’origine';

  @override
  String get settingsSearchVisualizerSubtitle =>
      'Désactivé, barres classiques ou barres synchronisées avec le morceau';

  @override
  String get settingsSearchLanguageSubtitle =>
      'Choisir la langue de l’application';

  @override
  String get settingsSearchProgressBarSubtitle =>
      'Barre de progression standard, forme d’onde ou réactive au son';

  @override
  String get settingsSearchSongDurationTitle => 'Afficher la durée du morceau';

  @override
  String get settingsSearchSongDurationSubtitle =>
      'Afficher la durée dans les listes de morceaux';

  @override
  String get settingsSearchAutoHideBarsTitle =>
      'Masquer automatiquement les barres';

  @override
  String get settingsSearchAutoHideBarsSubtitle =>
      'L’en-tête et le dock inférieur se masquent lors du défilement vers le bas';

  @override
  String get settingsSearchAppIconSubtitle =>
      'Choisir l’icône utilisée par wispie';

  @override
  String get settingsSearchBeatCoverSubtitle =>
      'La pochette pulse au rythme (lecteur classique uniquement)';

  @override
  String get settingsSearchSpinArtworkSubtitle =>
      'La pochette tourne dans la barre inférieure réduite pendant la lecture';

  @override
  String get settingsSearchCoverIntensitySubtitle =>
      'Intensité de la réaction de la pochette au rythme';

  @override
  String get settingsSearchParticleDensitySubtitle =>
      'Nombre de particules et vivacité de leur mouvement';

  @override
  String get settingsSearchBeatOffsetSubtitle =>
      'Compenser la latence de sortie Bluetooth';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Afficher des recommandations rapides';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Afficher les files d’attente récemment écoutées';

  @override
  String get settingsSearchForYouSubtitle =>
      'Afficher les playlists recommandées';

  @override
  String get settingsSearchQuickActionsSubtitle =>
      'Personnaliser les actions par appui prolongé';

  @override
  String get settingsSearchReorderQuickActionsTitle =>
      'Réorganiser les actions rapides';

  @override
  String get settingsSearchReorderQuickActionsSubtitle =>
      'Choisir et ordonner les actions disponibles par appui prolongé sur un morceau';

  @override
  String get settingsSearchBulkRenameTitle => 'Renommer plusieurs fichiers';

  @override
  String get settingsSearchBulkRenameSubtitle =>
      'Renommer toute la bibliothèque à partir d’un modèle';

  @override
  String get settingsSearchManageStorageSubtitle =>
      'Espace disque et gestion des données';

  @override
  String get settingsSearchBackupsSubtitle =>
      'Parcourir, restaurer et supprimer les sauvegardes enregistrées';

  @override
  String get settingsSearchStorageUsageSubtitle =>
      'Espace disque utilisé par les pochettes, formes d’onde, paroles et caches';

  @override
  String get settingsCrumbStorage => 'Paramètres › Stockage';

  @override
  String get settingsCrumbLibrary => 'Paramètres › Bibliothèque';

  @override
  String get settingsCrumbLibraryFilters =>
      'Paramètres › Bibliothèque › Filtres';

  @override
  String get settingsCrumbLibraryFolders =>
      'Paramètres › Bibliothèque › Dossiers musicaux';

  @override
  String get settingsCrumbLibraryMaintenance =>
      'Paramètres › Bibliothèque › Maintenance';

  @override
  String get settingsCrumbPlaybackAudio => 'Paramètres › Lecture › Audio';

  @override
  String get settingsCrumbPlaybackTransitions =>
      'Paramètres › Lecture › Transitions';

  @override
  String get settingsCrumbPlaybackPlayPause =>
      'Paramètres › Lecture › Lecture / pause';

  @override
  String get settingsCrumbLyricsTiming =>
      'Paramètres › Paroles › Affichage et synchronisation';

  @override
  String get settingsCrumbLyricsTranslation =>
      'Paramètres › Paroles › Traduction';

  @override
  String get settingsCrumbAppearanceLanguage =>
      'Paramètres › Apparence › Langue';

  @override
  String get settingsCrumbAppearanceNowPlaying =>
      'Paramètres › Apparence › Lecture en cours';

  @override
  String get settingsCrumbAppearanceAppIcon =>
      'Paramètres › Apparence › Icône de l’application';

  @override
  String get settingsCrumbAppearanceMotion =>
      'Paramètres › Apparence › Animations du lecteur';

  @override
  String get settingsCrumbAppearanceLists =>
      'Paramètres › Apparence › Listes et navigation';

  @override
  String get settingsCrumbHomeLists =>
      'Paramètres › Accueil et navigation › Listes et navigation';

  @override
  String get settingsCrumbHomeScreen =>
      'Paramètres › Accueil et navigation › Écran d’accueil';

  @override
  String get settingsCrumbBackup => 'Paramètres › Sauvegarde et restauration';

  @override
  String get settingsCrumbAutoBackups =>
      'Paramètres › Sauvegarde et restauration › Sauvegardes automatiques';

  @override
  String get settingsCrumbManageBackups =>
      'Paramètres › Gestion des données › Gérer les sauvegardes';

  @override
  String get settingsCrumbManageStorage =>
      'Paramètres › Gestion des données › Gérer le stockage';

  @override
  String get settingsKwLibrary => 'analyse,dossiers,filtres,morceaux';

  @override
  String get settingsKwPlayback => 'audio,son,transitions';

  @override
  String get settingsKwLyrics => 'paroles,traduction,karaoké,sous-titres';

  @override
  String get settingsKwHome =>
      'accueil,recommandations rapides,gestes,barres,disposition';

  @override
  String get settingsKwStorage => 'disque,espace,cache,indexeur,nettoyage';

  @override
  String get settingsKwAppearance => 'thème,couleur,affichage,apparence';

  @override
  String get settingsKwSync => 'cloud,compte,appareils,chiffré';

  @override
  String get settingsKwBackup =>
      'sauvegarde,restauration,exportation,importation,données';

  @override
  String get settingsKwIndexer => 'index,reconstruction,cache,réindexation';

  @override
  String get settingsKwAbout =>
      'version,mise à jour,journal des modifications,version';

  @override
  String get settingsKwFolders =>
      'répertoire,chemin,ajouter un dossier,sources';

  @override
  String get settingsKwRescan => 'actualiser,recharger,synchroniser';

  @override
  String get settingsKwVideos => 'vidéo,mp4,clips';

  @override
  String get settingsKwMinFileSize => 'taille,ignorer,petit,filtre';

  @override
  String get settingsKwMinDuration => 'durée,court,ignorer,filtre,interlude';

  @override
  String get settingsKwManageFolders => 'dossier,répertoire,stockage,carte SD';

  @override
  String get settingsKwPullToRefresh => 'balayage,geste,recharger';

  @override
  String get settingsKwMute => 'volume,silencieux,sourdine';

  @override
  String get settingsKwUnmute => 'volume,activer le son,reprendre';

  @override
  String get settingsKwGap => 'pause,silence,entre,transition';

  @override
  String get settingsKwCrossfade =>
      'fondu enchaîné,sans blanc,transition,mélange';

  @override
  String get settingsKwFadePlay => 'progression,volume,démarrage';

  @override
  String get settingsKwFadePause => 'progression,volume,arrêt';

  @override
  String get settingsKwRichSync =>
      'paroles,richsync,karaoké,mot,synchronisation';

  @override
  String get settingsKwSidebar =>
      'panneau latéral,panneau,ordinateur,file d’attente,paroles';

  @override
  String get settingsKwPlayerSwipe =>
      'balayage,geste,panneaux,paroles,file d’attente,passer,piste';

  @override
  String get settingsKwKeepAwake =>
      'veille,verrouillage de l’écran,affichage,paroles';

  @override
  String get settingsKwAutoTranslate =>
      'traduire,traduction,langue,paroles,automatique';

  @override
  String get settingsKwTargetLang =>
      'traduire,langue,espagnol,anglais,japonais';

  @override
  String get settingsKwTranslationMode =>
      'traduire,mode,sous-texte,remplacer,affichage';

  @override
  String get settingsKwVisualizer =>
      'onde,animation,spectre,barres,synchronisation,basses';

  @override
  String get settingsKwLanguage =>
      'langue,paramètres régionaux,traduction,anglais';

  @override
  String get settingsKwProgressBar =>
      'recherche,progression,onde,réactif,spectre';

  @override
  String get settingsKwHaptics =>
      'vibration,haptique,retour,forme d’onde,défilement,recherche';

  @override
  String get settingsKwSongDuration => 'durée,temps,listes';

  @override
  String get settingsKwAutoHide => 'navigation,dock,en-tête,défilement,masquer';

  @override
  String get settingsKwCoverSizing =>
      'pochette,illustration,proportions,recadrage';

  @override
  String get settingsKwImmersive =>
      'immersif,plein écran,lecteur,détails,dégradé,pochette,design';

  @override
  String get settingsKwAppIcon => 'icône,logo,lanceur,dock,classique,nouveau';

  @override
  String get settingsKwBeatCover => 'pulsation,rythme,pochette,animation';

  @override
  String get settingsKwSpinArtwork =>
      'tourner,pivoter,rotation,pochette,dock,miniature';

  @override
  String get settingsKwBeatParticles => 'particules,points,rythme,animation';

  @override
  String get settingsKwCoverIntensity =>
      'pochette,album,pulsation,discret,équilibré,intense';

  @override
  String get settingsKwParticleDensity =>
      'particules,points,densité,discret,équilibré,intense';

  @override
  String get settingsKwBeatOffset =>
      'bluetooth,latence,délai,synchronisation,en avance';

  @override
  String get settingsKwCalibrate =>
      'étalonner,synchronisation,latence,décalage,test,clic';

  @override
  String get settingsKwQuickPicks => 'accueil,recommandations,suggestions';

  @override
  String get settingsKwRecentQueues => 'accueil,historique,file d’attente';

  @override
  String get settingsKwForYou => 'accueil,mix,recommandations';

  @override
  String get settingsKwQuickActions => 'appui prolongé,menu,raccourcis';

  @override
  String get settingsKwReorderQuickActions =>
      'appui prolongé,ordre,menu,raccourcis';

  @override
  String get settingsKwExport => 'sauvegarde,enregistrer,exporter';

  @override
  String get settingsKwImport => 'restaurer,charger,importer';

  @override
  String get settingsKwManageBackups => 'sauvegarde,restaurer,supprimer';

  @override
  String get settingsKwBulkRename =>
      'renommer,noms de fichiers,lot,en masse,format,nomenclature';

  @override
  String get settingsKwBatchReplace =>
      'remplacer,échanger,améliorer,flac,sans perte,lot,comparer,dossier,doublon';

  @override
  String get settingsKwManageStorage => 'disque,espace,cache,nettoyage';

  @override
  String get settingsKwBackups => 'sauvegarde,restauration,archive';

  @override
  String get settingsKwStorageUsage =>
      'disque,espace,vider le cache,utilisation';

  @override
  String get settingsKwAutoBackup => 'planification,fréquence,automatique';

  @override
  String get settingsKwAutoBackupContent => 'contenu,categories,automatique';

  @override
  String get settingsKwAutoDelete => 'purger,nettoyage,rétention,ancien';

  @override
  String get setupUnableToAccessFolder =>
      'Impossible d’accéder au dossier sélectionné';

  @override
  String get setupStoragePermissionRequired =>
      'L’autorisation d’accès au stockage est nécessaire pour analyser votre bibliothèque musicale.';

  @override
  String get setupEnterDisplayName => 'Veuillez saisir un nom d’affichage';

  @override
  String setupSetupError(String error) {
    return 'Erreur de configuration : $error';
  }

  @override
  String get setupIntroTagline => 'Votre musique reste sur votre appareil.';

  @override
  String get setupGetStarted => 'Commencer';

  @override
  String get setupPreviousStep => 'Étape précédente';

  @override
  String get setupSettingThingsUp => 'Configuration en cours';

  @override
  String get setupStartListening => 'Commencer l’écoute';

  @override
  String get setupContinue => 'Continuer';

  @override
  String get setupNameTitle => 'Comment souhaitez-vous être appelé ?';

  @override
  String get setupNameSubtitle =>
      'wispie utilise votre nom pour vous saluer et signer votre historique d’écoute. Quoi qu’il en soit, rien ne quitte cet appareil.';

  @override
  String get setupNameHint => 'Votre nom';

  @override
  String setupGreeting(String name) {
    return 'Ravi de vous rencontrer, $name.';
  }

  @override
  String get setupAppearanceTitle => 'Personnalisez l’apparence.';

  @override
  String get setupAppearanceSubtitle =>
      'Tous les réglages de cette page se trouvent aussi dans Paramètres. Vous pourrez les modifier à tout moment.';

  @override
  String get setupImmersiveSubtitle =>
      'Un lecteur avec pochette en plein écran et des écrans de détails avec dégradé.';

  @override
  String get setupVisualizerSubtitle =>
      'Des barres sur la pochette pendant l’écoute. Le mode synchronisé suit le morceau au lieu d’afficher un motif aléatoire.';

  @override
  String get setupBeatCoverSubtitle =>
      'La pochette respire au rythme de chaque battement.';

  @override
  String get setupParticlesSubtitle =>
      'Des particules dérivent sur le lecteur et chaque battement les entraîne au lieu de simplement les faire clignoter.';

  @override
  String get setupProgressBarTitle => 'Barre de progression';

  @override
  String get setupProgressBarSubtitle =>
      'Représentez le morceau sous forme d’onde plutôt qu’avec une simple ligne. Le mode réactif au son l’anime pendant la lecture.';

  @override
  String get setupFoldersTitle => 'Où se trouve votre musique ?';

  @override
  String get setupFoldersSubtitle =>
      'Indiquez à wispie les dossiers où se trouvent vos morceaux. L’application ne fait que les lire, et vous pouvez en ajouter autant que vous voulez.';

  @override
  String get setupStoragePermissionTitle => 'Autorisation de stockage';

  @override
  String get setupStoragePermissionSubtitle =>
      'wispie en a besoin pour trouver les fichiers audio sur cet appareil.';

  @override
  String get setupOpenSystemSettings => 'Ouvrir les paramètres système';

  @override
  String get setupGrantPermission => 'Accorder l’autorisation';

  @override
  String get setupNoFoldersTitle => 'Aucun dossier pour le moment';

  @override
  String get setupNoFoldersSubtitle =>
      'Ajoutez le dossier qui contient vos morceaux.';

  @override
  String get setupRemoveFolderTooltip => 'Retirer le dossier';

  @override
  String get setupAddFolder => 'Ajouter un dossier';

  @override
  String get setupSummaryMusicFolders => 'Dossiers musicaux';

  @override
  String get setupReadyTitle => 'Tout est prêt.';

  @override
  String setupReadyTitleNamed(String name) {
    return 'Tout est prêt, $name.';
  }

  @override
  String get setupReadySubtitle =>
      'Voici ce qui a été configuré. Vous pourrez tout modifier plus tard dans Paramètres.';

  @override
  String get setupOn => 'Activé';

  @override
  String get setupOff => 'Désactivé';

  @override
  String backupLoadError(Object error) {
    return 'Erreur lors du chargement des sauvegardes : $error';
  }

  @override
  String backupCreated(Object name) {
    return 'Sauvegarde créée : $name';
  }

  @override
  String backupCreateFailed(Object error) {
    return 'Échec de la création de la sauvegarde : $error';
  }

  @override
  String backupValidateFailed(Object error) {
    return 'Échec de la validation de la sauvegarde : $error';
  }

  @override
  String get backupReplaceTitle => 'DANGER : remplacement complet des données';

  @override
  String backupReplaceConfirm(Object name) {
    return 'Voulez-vous vraiment restaurer à partir de $name ?';
  }

  @override
  String get backupReplaceWarning =>
      'ATTENTION : toutes vos données actuelles seront COMPLÈTEMENT REMPLACÉES :';

  @override
  String get backupReplaceItemStats =>
      '• Toutes vos statistiques et tout votre historique d’écoute';

  @override
  String get backupReplaceItemFavorites =>
      '• Tous vos favoris et toutes vos playlists';

  @override
  String get backupReplaceItemHidden =>
      '• Tous vos morceaux masqués et toutes vos préférences';

  @override
  String get backupReplaceItemSettings =>
      '• Tous vos paramètres et états actuels';

  @override
  String get backupReplaceItemLibrary =>
      '• Votre bibliothèque de morceaux analysée';

  @override
  String get backupReplaceRekeyNote =>
      'Les pochettes d’album et chemins de fichiers seront automatiquement reliés à cet appareil après la restauration. Les pistes de la sauvegarde dont les fichiers sont absents de cet appareil seront retirées de la bibliothèque.';

  @override
  String get backupReplaceIrreversible =>
      'VOS DONNÉES ACTUELLES SERONT DÉFINITIVEMENT PERDUES !';

  @override
  String get backupReplaceNoUndo => 'IL EST IMPOSSIBLE d’annuler cette action.';

  @override
  String get backupReplaceConfirmAction => 'OUI, TOUT REMPLACER';

  @override
  String get backupRestoringLabel => 'Restauration des données…';

  @override
  String get backupRestoreSuccess => 'Toutes les données ont été remplacées';

  @override
  String backupRestoreFailed(Object error) {
    return 'Échec de la restauration de la sauvegarde : $error';
  }

  @override
  String get backupRestoreReloadingLibrary =>
      'Rechargement de la bibliothèque…';

  @override
  String get backupRestoreRefreshingPlaylists =>
      'Actualisation des playlists et des mix…';

  @override
  String get backupDeleteTitle => 'Supprimer la sauvegarde';

  @override
  String backupDeleteConfirm(Object name) {
    return 'Voulez-vous vraiment supprimer $name ?';
  }

  @override
  String get backupDeleteUpper => 'SUPPRIMER';

  @override
  String get backupDeleted => 'Sauvegarde supprimée';

  @override
  String backupDeleteFailed(Object error) {
    return 'Échec de la suppression de la sauvegarde : $error';
  }

  @override
  String backupExportedTo(Object path) {
    return 'Sauvegarde exportée vers : $path';
  }

  @override
  String get backupNoOlderBackup =>
      'Aucune sauvegarde plus ancienne à comparer.';

  @override
  String get backupComparing => 'Comparaison des sauvegardes…';

  @override
  String backupComparisonTitle(int number) {
    return 'Comparaison avec la sauvegarde n° $number';
  }

  @override
  String get backupDiffStatsRows => 'Lignes de statistiques';

  @override
  String get backupDiffSize => 'Taille';

  @override
  String get backupDiffDataAdded => 'Données ajoutées';

  @override
  String get backupCloseUpper => 'FERMER';

  @override
  String backupCompareError(Object error) {
    return 'Erreur lors de la comparaison des sauvegardes : $error';
  }

  @override
  String get backupNoChange => 'Aucun changement';

  @override
  String get backupManagementTitle => 'Gestion des sauvegardes';

  @override
  String get backupCreating => 'Création en cours…';

  @override
  String get backupCreateAction => 'Créer une sauvegarde';

  @override
  String get backupEmptyTitle => 'Aucune sauvegarde pour le moment';

  @override
  String get backupEmptySubtitle =>
      'Créez votre première sauvegarde pour protéger vos données';

  @override
  String backupSizeLabel(Object size) {
    return 'Taille : $size';
  }

  @override
  String get backupActionRestore => 'Restaurer';

  @override
  String get backupActionCompare => 'Comparer';

  @override
  String get backupRestartTitle => 'Redémarrage nécessaire';

  @override
  String get backupRestartMessage =>
      'La restauration de la sauvegarde a réussi.\n\nL’application doit redémarrer pour appliquer correctement toutes les modifications.';

  @override
  String get backupRestartNow => 'Redémarrer maintenant';

  @override
  String get backupSelectContentSubtitle =>
      'Choisissez le contenu à sauvegarder';

  @override
  String get backupContentArtistArtCache => 'Cache des pochettes d’artistes';

  @override
  String get backupContentAlbumArtCache => 'Cache des pochettes d’albums';

  @override
  String get backupContentDescUserStats =>
      'Historique d’écoute, statistiques, groupes fusionnés';

  @override
  String get backupContentDescUserData => 'Favoris, playlists, préférences';

  @override
  String get backupContentDescUserSettings =>
      'Thème, ordre de tri, préférences de l’application';

  @override
  String get backupContentDescCoverCache => 'Pochettes d’album en cache';

  @override
  String get backupContentDescLibraryCache => 'Métadonnées en cache';

  @override
  String get backupContentDescSearchIndex => 'Base de données de recherche';

  @override
  String get backupContentDescWaveformCache => 'Données des formes d’onde';

  @override
  String get backupContentDescColorCache => 'Palettes de couleurs';

  @override
  String get backupContentDescLyricsCache => 'Paroles en cache';

  @override
  String get backupContentDescArtistArtCache => 'Images d’artistes en cache';

  @override
  String get backupContentDescAlbumArtCache => 'Images d’albums en cache';

  @override
  String get backupRestoringDataTitle => 'Restauration des données';

  @override
  String get importSelectTitle => 'Sélectionner les données à restaurer';

  @override
  String get importSectionCache => 'Cache';

  @override
  String get importOptionsTitle => 'Options de restauration';

  @override
  String get importReplaceDatabases => 'Remplacer les bases de données';

  @override
  String get importReplaceDatabasesSubtitle =>
      'Effacer les données existantes avant la restauration';

  @override
  String get syncEnterPassword => 'Saisissez votre mot de passe';

  @override
  String syncAuthUnexpectedError(String error) {
    return 'Une erreur s’est produite : $error';
  }

  @override
  String get syncUsernameTaken => 'Ce nom d’utilisateur est déjà utilisé';

  @override
  String get syncModeRecover => 'Récupérer';

  @override
  String get syncUsername => 'Nom d’utilisateur';

  @override
  String get syncEncryptionWarning =>
      'Vos données sont chiffrées de bout en bout. Si vous perdez votre mot de passe et votre clé de récupération, elles seront irrécupérables.';

  @override
  String get syncSecuringAccount => 'Sécurisation de votre compte…';

  @override
  String get syncCreateAccount => 'Créer un compte';

  @override
  String get syncLogIn => 'Se connecter';

  @override
  String get syncRecoverAccount => 'Récupérer le compte';

  @override
  String get syncHideAdvanced => 'Masquer les options avancées';

  @override
  String get syncAdvanced => 'Options avancées';

  @override
  String get syncRecoveryKeySaved => 'Clé de récupération enregistrée';

  @override
  String get syncCouldNotSaveFile => 'Impossible d’enregistrer le fichier';

  @override
  String get syncRecoveryKeyRevealTitle => 'Votre clé de récupération';

  @override
  String get syncRecoveryKeyRevealBody =>
      'C’est le seul moyen de retrouver l’accès si vous oubliez votre mot de passe. Elle ne sera affichée qu’une fois. Conservez-la en lieu sûr.';

  @override
  String get syncCopied => 'Copié';

  @override
  String get syncCopy => 'Copier';

  @override
  String get syncSaveToFile => 'Enregistrer dans un fichier';

  @override
  String get syncRecoveryKeySavedCheckbox =>
      'J’ai enregistré ma clé de récupération';

  @override
  String get syncUploadTitle => 'Importer les données de votre bibliothèque';

  @override
  String get syncSetupDeviceTitle => 'Configurer cet appareil';

  @override
  String get syncFreshAccountBody =>
      'La synchronisation automatique sera activée après le premier envoi de vos données.';

  @override
  String get syncChooseDeviceBody =>
      'Choisissez comment cet appareil rejoint vos données dans le cloud. La synchronisation automatique sera activée après cette étape.';

  @override
  String get syncEverythingNow => 'Tout synchroniser maintenant';

  @override
  String get syncMergeWithCloud => 'Fusionner cet appareil avec le cloud';

  @override
  String get syncSetupNewDevice => 'Configurer comme nouvel appareil';

  @override
  String get syncMergeExplanation =>
      'La fusion conserve les données des deux côtés. La configuration comme nouvel appareil efface d’abord les données synchronisées de cet appareil ; cette option est plus sûre si celui-ci contient déjà une ancienne copie du même historique.';

  @override
  String get syncCloudReplacedTitle =>
      'Les données du cloud ont été remplacées';

  @override
  String get syncCloudReplacedBody =>
      'Un autre appareil a remplacé les données du cloud. La synchronisation est suspendue sur cet appareil jusqu’à votre choix.';

  @override
  String get syncMergeIntoCloud =>
      'Fusionner cet appareil avec les nouvelles données du cloud';

  @override
  String get syncPhaseSigningIn => 'Connexion…';

  @override
  String get syncPhaseCheckingCloud => 'Vérification du cloud…';

  @override
  String get syncPhaseDownloadingBackup => 'Téléchargement de la sauvegarde…';

  @override
  String get syncPhaseApplyingBackup => 'Application de la sauvegarde…';

  @override
  String get syncPhaseDownloadingChanges => 'Téléchargement des modifications…';

  @override
  String get syncPhaseMerging => 'Fusion…';

  @override
  String get syncPhasePreparingUpload => 'Préparation de l’envoi…';

  @override
  String get syncPhaseEncrypting => 'Chiffrement…';

  @override
  String get syncPhaseUploading => 'Envoi…';

  @override
  String get syncPhaseFinishing => 'Finalisation…';

  @override
  String get syncPhaseError => 'Échec de la synchronisation';

  @override
  String get syncSyncing => 'Synchronisation…';

  @override
  String syncServerInfo(String name, String version) {
    return '$name - API v$version';
  }

  @override
  String syncServerInfoClosed(String name, String version) {
    return '$name - API v$version - inscriptions fermées';
  }

  @override
  String get syncServerUnreachable => 'Impossible de joindre le serveur';

  @override
  String get syncInsecureHttpWarning =>
      'HTTP non chiffré : à utiliser uniquement sur un réseau privé de confiance';

  @override
  String get syncServerUrl => 'URL du serveur';

  @override
  String get syncChecking => 'Vérification…';

  @override
  String get syncCheckServer => 'Vérifier le serveur';

  @override
  String get syncResetDefault => 'Rétablir la valeur par défaut';

  @override
  String get autoBackupRunningTitle => 'Sauvegarde en cours';

  @override
  String get autoBackupRunningSubtitle => 'Création de la sauvegarde…';

  @override
  String get autoBackupCompleteTitle => 'Sauvegarde automatique terminée';

  @override
  String get autoBackupSaved => 'Sauvegarde enregistrée';

  @override
  String get autoBackupFailedTitle => 'Échec de la sauvegarde automatique';

  @override
  String get autoBackupPermissionTitle => 'Autorisation requise';

  @override
  String get autoBackupPermissionSubtitle =>
      'La sauvegarde automatique nécessite l’accès au stockage';

  @override
  String get autoBackupGrant => 'Autoriser';

  @override
  String get downgradeTitle => 'Une version plus ancienne a été détectée';

  @override
  String downgradeMessage(String previousVersion, String currentVersion) {
    return 'wispie a été ouvert pour la dernière fois avec la version $previousVersion, alors que la version actuelle est $currentVersion. Vos données ont peut-être été modifiées par une version plus récente et pourraient être endommagées ou perdues avec celle-ci.';
  }

  @override
  String get downgradeQuit => 'Quitter';

  @override
  String get downgradeRiskIt => 'Continuer malgré le risque';

  @override
  String get indexerSettingsGroupTitle => 'Paramètres de l’indexeur';

  @override
  String get indexerPreventDuplicatesTitle => 'Éviter les pistes en double';

  @override
  String get indexerPreventDuplicatesSubtitle =>
      'Masquer les morceaux portant le même nom de fichier dans plusieurs dossiers';

  @override
  String get indexerExtractFeaturedTitle => 'Extraire les artistes invités';

  @override
  String get indexerExtractFeaturedSubtitle =>
      'Déplacer les artistes « ft./feat. » du titre vers le champ Artiste';

  @override
  String get indexerDatabaseOpsGroupTitle =>
      'Opérations sur les bases de données';

  @override
  String get indexerWarnRestart =>
      'Cette opération nécessite le redémarrage de l’application pour appliquer les modifications.';

  @override
  String get indexerCoverSearchGroupTitle => 'Pochettes et recherche';

  @override
  String get indexerWarnRepairLinks =>
      'Les pistes dont les fichiers ne sont plus sur cet appareil seront retirées de la bibliothèque. Les favoris, playlists et nombres d’écoutes seront conservés et réassociés si les fichiers reviennent.';

  @override
  String get indexerWarnSearchRestart =>
      'Vous devrez peut-être redémarrer l’application pour que les modifications de l’index de recherche soient entièrement appliquées.';

  @override
  String get indexerContentCachesGroupTitle => 'Caches de contenu';

  @override
  String get indexerRecommendationsGroupTitle => 'Recommandations';

  @override
  String get indexerTitle => 'Indexeur';

  @override
  String indexerArtistsAlbumsProgress(String artists, String albums) {
    return 'Artistes $artists · Albums $albums…';
  }

  @override
  String indexerProcessing(String progress) {
    return 'Traitement : $progress…';
  }

  @override
  String get indexerUnknownError => 'Erreur inconnue';

  @override
  String get indexerCompleted => 'Terminé';

  @override
  String indexerCached(int processed, int total) {
    return '$processed/$total mis en cache';
  }

  @override
  String indexerCachedFailed(int processed, int total, int failed) {
    return '$processed/$total mis en cache ($failed échecs)';
  }

  @override
  String get indexerReadyToRebuild => 'Prêt à reconstruire';

  @override
  String indexerArtistsOnly(String progress) {
    return 'Artistes $progress';
  }

  @override
  String indexerAlbumsOnly(String progress) {
    return 'Albums $progress';
  }

  @override
  String indexerFailedItemsQuestion(int failed) {
    return '$failed éléments de ce cache ont échoué. Que souhaitez-vous faire ?';
  }

  @override
  String indexerViewFailed(int failed) {
    return 'Afficher les $failed échecs';
  }

  @override
  String get indexerRetryFailed => 'Réessayer les échecs';

  @override
  String get indexerForceRebuild => 'Forcer la reconstruction';

  @override
  String indexerAlreadyCompleteQuestion(int processed, int total) {
    return 'Ce cache est déjà complet ($processed/$total). Voulez-vous forcer sa reconstruction ?';
  }

  @override
  String get indexerDoIt => 'Exécuter';

  @override
  String indexerOptimizing(String name) {
    return 'Optimisation de $name…';
  }

  @override
  String get indexerDoNotClose => 'Ne fermez pas l’application';

  @override
  String get indexerRestartRequiredMessage =>
      'L’opération a réussi.\n\nL’application doit redémarrer pour appliquer correctement toutes les modifications.';

  @override
  String indexerFailedItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments en échec',
      one: '1 élément en échec',
    );
    return '$_temp0';
  }

  @override
  String get indexerCouldNotProcess =>
      'Les éléments suivants n’ont pas pu être traités :';

  @override
  String indexerWarningsTitle(String name) {
    return 'Avertissements : $name';
  }

  @override
  String get indexerOk => 'OK';

  @override
  String get indexerJustMissing => 'Uniquement les éléments manquants';

  @override
  String get indexerForceAll => 'Tout forcer';

  @override
  String get beatSyncTitle => 'Synchronisation du rythme';

  @override
  String get beatPlayToCalibrate =>
      'Lancez un morceau pour calibrer la synchronisation.';

  @override
  String get beatAnalyzing => 'Analyse du rythme…';

  @override
  String get beatNoClearBeat => 'Aucun rythme net dans ce morceau.';

  @override
  String get beatDragInstruction =>
      'Faites glisser jusqu’à ce que l’explosion des particules coïncide avec les clics.';

  @override
  String beatOffsetMs(int value) {
    return '$value ms';
  }

  @override
  String get beatResetToZero => 'Réinitialiser à 0 ms';

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String get libraryFoldersTab => 'Dossiers';

  @override
  String get libraryNoMusicFolderTitle =>
      'Aucun dossier musical pour le moment';

  @override
  String get libraryNoMusicFolderMessage =>
      'Sélectionnez un dossier musical depuis l’accueil pour remplir cette section.';

  @override
  String get libraryFolderErrorTitle =>
      'Impossible de trouver votre dossier musical';

  @override
  String get libraryLoadErrorTitle => 'Impossible de charger la bibliothèque';

  @override
  String get libraryOpenFolderErrorTitle => 'Impossible d’ouvrir le dossier';

  @override
  String get libraryNoMatchesTitle => 'Aucun résultat';

  @override
  String libraryNoMatchesMessage(String query) {
    return 'Aucun élément de votre bibliothèque ne correspond à « $query ».';
  }

  @override
  String libraryFolderNoMatchesMessage(String query) {
    return 'Aucun élément de ce dossier ne correspond à « $query ».';
  }

  @override
  String libraryCollectionNoMatchesMessage(String query) {
    return 'Aucun élément ici ne correspond à « $query ».';
  }

  @override
  String get libraryFavorites => 'Favoris';

  @override
  String libraryMergedGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes',
      one: '1 groupe',
    );
    return '$_temp0';
  }

  @override
  String get libraryCreateMergeGroupTooltip =>
      'Créer un nouveau groupe de fusion';

  @override
  String get libraryDeletePlaylist => 'Supprimer la playlist';

  @override
  String get libraryPlaylistOptions => 'Options de la playlist';

  @override
  String get libraryFolderOptions => 'Options du dossier';

  @override
  String get libraryFilterAllHint =>
      'Filtrer les dossiers, playlists, morceaux…';

  @override
  String get libraryFilterSongsHint => 'Filtrer les dossiers et les morceaux…';

  @override
  String get libraryFilterCollectionsHint =>
      'Filtrer les artistes et les albums…';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Tout';

  @override
  String get libraryShuffleFolderTooltip => 'Mélanger le dossier';

  @override
  String get libraryNoArtistsTitle => 'Aucun artiste pour le moment';

  @override
  String get libraryNoAlbumsTitle => 'Aucun album pour le moment';

  @override
  String get libraryScanToFillMessage =>
      'Analysez un dossier musical pour remplir cette section.';

  @override
  String get actionClear => 'Effacer';

  @override
  String get actionSearch => 'Rechercher';

  @override
  String get actionShuffleAll => 'Tout mélanger';

  @override
  String get actionSeeAll => 'Tout afficher';

  @override
  String homeQueueCardSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
    );
    return '$date · $_temp0';
  }

  @override
  String homePlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
    );
    return 'Lecture de $_temp0';
  }

  @override
  String get homeOpenPlayer => 'Ouvrir le lecteur';

  @override
  String get homePlayNow => 'Lire maintenant';

  @override
  String homePlayAfterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes seront lues après le morceau en cours',
      one: '1 piste sera lue après le morceau en cours',
    );
    return '$_temp0';
  }

  @override
  String get homePlayAfterCurrent => 'Lire après le morceau en cours';

  @override
  String get homeSaveToNewPlaylist => 'Enregistrer dans une nouvelle playlist';

  @override
  String get homeUnpin => 'Désépingler';

  @override
  String get homePinRecommendation => 'Épingler la recommandation';

  @override
  String get homeRenameRecommendation => 'Renommer la recommandation';

  @override
  String get homeRenameRecommendationTitle => 'Renommer la recommandation';

  @override
  String get homeRemoveRecommendation => 'Supprimer la recommandation';

  @override
  String get homeRemoveRecommendationTitle => 'Supprimer la recommandation ?';

  @override
  String homeRemoveRecommendationMessage(String title) {
    return 'Voulez-vous vraiment supprimer « $title » ?';
  }

  @override
  String get homeErrorTitle => 'Une erreur s’est produite';

  @override
  String get homeTryAgain => 'Réessayer';

  @override
  String get homeNoSongsTitle => 'Aucun morceau trouvé';

  @override
  String get homeNoSongsMessage =>
      'Sélectionnez votre dossier musical pour commencer à écouter votre musique hors ligne.';

  @override
  String get homeSelectFolder => 'Sélectionner un dossier musical';

  @override
  String get homeQuickPicks => 'Sélections rapides';

  @override
  String get homeRecentQueues => 'Files d’attente récentes';

  @override
  String get homePlaylists => 'Vos playlists';

  @override
  String get homeForYou => 'Pour vous';

  @override
  String get mergedTitle => 'Morceaux fusionnés';

  @override
  String get mergedCreateGroupTooltip => 'Créer un groupe de fusion';

  @override
  String mergedGroupsTab(int count) {
    return 'Groupes ($count)';
  }

  @override
  String mergedAutoFindTab(int count) {
    return 'Détection auto ($count)';
  }

  @override
  String mergedCreatedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux fusionnés',
      one: '1 morceau fusionné',
    );
    return '$_temp0';
  }

  @override
  String get mergedEmptyTitle => 'Aucun morceau fusionné pour le moment';

  @override
  String get mergedEmptyBody =>
      'Regroupez différentes versions d’un même morceau (remixes, versions live ou acoustiques) afin qu’elles n’occupent qu’une place dans la lecture aléatoire.';

  @override
  String get mergedCreateGroupButton => 'Créer un groupe de fusion';

  @override
  String mergedPrioritySet(String title) {
    return '« $title » défini comme morceau prioritaire';
  }

  @override
  String get mergedPriorityCleared => 'Priorité supprimée';

  @override
  String get mergedNoCandidatesTitle => 'Aucun morceau candidat trouvé';

  @override
  String get mergedNoCandidatesBody =>
      'Aucune variante de morceau non fusionnée (remix, version live ou acoustique) n’a été détectée dans votre bibliothèque.';

  @override
  String mergedFoundGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes potentiels à fusionner trouvés',
      one: '1 groupe potentiel à fusionner trouvé',
    );
    return '$_temp0';
  }

  @override
  String get mergedMergeAll => 'Tout fusionner';

  @override
  String get mergedMergeAllTitle => 'Fusionner toutes les suggestions';

  @override
  String mergedMergeAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Créer $count groupes de fusion pour les variantes détectées ?',
      one: 'Créer 1 groupe de fusion pour les variantes détectées ?',
    );
    return '$_temp0';
  }

  @override
  String mergedCreatedGroupsSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groupes de fusion créés',
      one: '1 groupe de fusion créé',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeTitle => 'Séparer le morceau';

  @override
  String mergedUnmergeConfirm(String title) {
    return 'Retirer « $title » de ce groupe de fusion ?';
  }

  @override
  String get mergedUnmergeAction => 'Séparer';

  @override
  String mergedUnmergedSnack(String title) {
    return '« $title » séparé';
  }

  @override
  String get mergedDeleteGroupTitle => 'Supprimer le groupe de fusion';

  @override
  String get mergedDeleteGroupConfirm =>
      'Séparer tous les morceaux de ce groupe ?';

  @override
  String get mergedUnmergeAllAction => 'Tout séparer';

  @override
  String get mergedGroupDeleted => 'Groupe de fusion supprimé';

  @override
  String get mergedGroupLabel => 'Groupe de fusion';

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
  String get mergedUnmergeAllTooltip => 'Tout séparer';

  @override
  String get mergedPriorityBadge => 'Prioritaire';

  @override
  String get mergedPrioritySongTooltip =>
      'Morceau prioritaire pour la lecture aléatoire';

  @override
  String get mergedSetPriorityTooltip => 'Définir comme morceau prioritaire';

  @override
  String get mergedUnmergeSongTooltip => 'Séparer le morceau';

  @override
  String mergedSelectedCount(int selected, int total) {
    return '$selected/$total sélectionnés';
  }

  @override
  String get mergedMergeAction => 'Fusionner';

  @override
  String get sleepTimerTitle => 'Minuteur de veille';

  @override
  String get sleepTimerModeLabel => 'Mode du minuteur';

  @override
  String get sleepTimerDurationLabel => 'Durée';

  @override
  String get sleepTimerMinSuffix => 'min';

  @override
  String get sleepTimerTracksLabel => 'Nombre de pistes';

  @override
  String get sleepTimerLoopTitle => 'Répéter le morceau en cours';

  @override
  String get sleepTimerLoopSubtitle =>
      'Répéter le morceau en cours pendant une durée définie';

  @override
  String get sleepTimerPlayForTimeTitle => 'Lire pendant une durée définie';

  @override
  String get sleepTimerPlayForTimeSubtitle => 'Arrêter après une durée définie';

  @override
  String get sleepTimerStopAfterCurrentTitle =>
      'Arrêter après le morceau en cours';

  @override
  String get sleepTimerStopAfterCurrentSubtitle =>
      'Arrêter à la fin du morceau en cours';

  @override
  String get sleepTimerStopAfterTracksTitle => 'Arrêter après plusieurs pistes';

  @override
  String get sleepTimerStopAfterTracksSubtitle =>
      'Arrêter après la lecture de X morceaux supplémentaires';

  @override
  String get sleepTimerNoSong => 'Aucun morceau n’est en cours de lecture';

  @override
  String get sleepTimerCurrentSongLabel => 'Morceau en cours';

  @override
  String get sleepTimerLetFinishTitle => 'Laisser le morceau se terminer';

  @override
  String get sleepTimerLetFinishSubtitle =>
      'Attendre la fin du morceau en cours avant l’arrêt';

  @override
  String get sleepTimerStopImmediatelySubtitle =>
      'Arrêter immédiatement à l’expiration du minuteur';

  @override
  String get sleepTimerStart => 'Démarrer le minuteur';

  @override
  String get sleepTimerCancelActive => 'Annuler le minuteur actif';

  @override
  String get sleepTimerCancelled => 'Minuteur de veille annulé';

  @override
  String get sleepTimerFinished => 'Minuteur de veille terminé';

  @override
  String sleepTimerLoopingFor(int minutes) {
    return 'Répétition du morceau en cours pendant $minutes minutes';
  }

  @override
  String sleepTimerStopIn(int minutes) {
    return 'La musique s’arrêtera dans $minutes minutes';
  }

  @override
  String get sleepTimerStopAfterCurrent => 'Arrêt à la fin du morceau en cours';

  @override
  String sleepTimerStopAfterTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Arrêt après $count morceaux supplémentaires',
      one: 'Arrêt après 1 morceau supplémentaire',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchHint => 'Rechercher dans les paramètres';

  @override
  String get settingsValueNone => 'Aucun';

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
    return '$minutes min $seconds s';
  }

  @override
  String get settingsGroupLookAndFeel => 'Apparence et présentation';

  @override
  String get settingsGroupData => 'Données';

  @override
  String get settingsGroupApp => 'Application';

  @override
  String get settingsGroupFilters => 'Filtres';

  @override
  String get settingsGroupMaintenance => 'Maintenance';

  @override
  String get settingsScanningLibrary => 'Analyse de la bibliothèque…';

  @override
  String settingsResultsFor(String query) {
    return 'Résultats pour « $query »';
  }

  @override
  String get settingsNoResultsTitle => 'Aucun paramètre trouvé';

  @override
  String settingsNoResultsMessage(String query) {
    return 'Aucun résultat pour « $query ».';
  }

  @override
  String get homeSettingsGroupLists => 'Listes et navigation';

  @override
  String get homeSettingsAutoHideBarsSubtitle =>
      'L’en-tête et le dock inférieur se masquent lors du défilement vers le bas et réapparaissent lors du défilement vers le haut';

  @override
  String get homeSettingsGroupHome => 'Écran d’accueil';

  @override
  String get playbackGroupTransitions => 'Transitions';

  @override
  String get playbackGroupPlayPause => 'Lecture / pause';

  @override
  String get playbackGroupAudio => 'Audio';

  @override
  String get playbackGapOff => 'Silence / délai (désactivé)';

  @override
  String get playbackFadeOutOff => 'Fondu de sortie (désactivé)';

  @override
  String get playbackFadeInOff => 'Fondu d’entrée (désactivé)';

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
  String get bulkRenameTokenCurrentName => 'Nom actuel';

  @override
  String get bulkRenameTokenNumber => 'Numéro';

  @override
  String get bulkRenameTokenYear => 'Année';

  @override
  String bulkRenameAnalyzeError(String error) {
    return 'Impossible d’analyser la bibliothèque : $error';
  }

  @override
  String bulkRenameRenameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Renommer $count morceaux',
      one: 'Renommer 1 morceau',
    );
    return '$_temp0';
  }

  @override
  String get bulkRenameConfirmMessage =>
      'Les fichiers seront renommés sur place. Les statistiques d’écoute, les playlists et les pochettes en cache seront transférées, et la base de données sera mise à jour à chaque déplacement du fichier.';

  @override
  String get bulkRenameNothingLeft => 'Il n’y a plus rien à renommer';

  @override
  String get bulkRenamePhaseStarting => 'Démarrage';

  @override
  String get bulkRenameTitle => 'Renommer plusieurs fichiers';

  @override
  String get bulkRenameFormatArtistTitle => 'Artiste - Titre';

  @override
  String get bulkRenameFormatArtistAlbumTitle => 'Artiste - Album - Titre';

  @override
  String get bulkRenameCustomSubtitle => 'Votre propre format';

  @override
  String get bulkRenameSectionFormat => 'FORMAT';

  @override
  String get bulkRenameSectionArrange => 'ORDRE';

  @override
  String get bulkRenameSectionPreview => 'APERÇU';

  @override
  String get bulkRenameEmptySegments =>
      'Ajoutez un champ ci-dessous pour commencer à créer un nom.';

  @override
  String get bulkRenameLiteralHint => 'Texte, par ex. « - »';

  @override
  String get bulkRenameTextChip => 'Texte';

  @override
  String get bulkRenameAnalyzing => 'Analyse de la bibliothèque';

  @override
  String bulkRenameCountToRename(int count) {
    return '$count à renommer';
  }

  @override
  String bulkRenameSkippedCount(int count) {
    return '$count ignorés';
  }

  @override
  String bulkRenameAndMore(int count) {
    return 'et $count de plus';
  }

  @override
  String bulkRenameChecking(int done, int total) {
    return 'Vérification des noms — $done sur $total';
  }

  @override
  String get bulkRenameStop => 'Arrêter';

  @override
  String get bulkRenameStopping => 'Arrêt en cours…';

  @override
  String get bulkRenamePleaseWait => 'Veuillez patienter';

  @override
  String bulkRenameProgressCount(int done, int total) {
    return '$done sur $total';
  }

  @override
  String bulkRenameStopped(int count) {
    return 'Arrêt après $count morceaux. Leurs statistiques et pochettes en cache ont été transférées ; les autres n’ont pas été modifiés.';
  }

  @override
  String bulkRenameStoppedFailed(int count, int failed) {
    return 'Arrêt après $count morceaux ; $failed n’ont pas pu être renommés.';
  }

  @override
  String bulkRenameCompleted(int count) {
    return '$count morceaux renommés. Statistiques et pochettes en cache transférées.';
  }

  @override
  String bulkRenameCompletedFailed(int count, int failed) {
    return '$count morceaux renommés ; $failed n’ont pas pu l’être.';
  }

  @override
  String get bulkRenameFinishedTitle => 'Renommage terminé';

  @override
  String get bulkRenameSkipNoTitleText =>
      'Aucun texte de titre après le nettoyage';

  @override
  String get bulkRenameSkipAlreadyNamed => 'Porte déjà ce nom';

  @override
  String bulkRenameSkipSameNameAs(String filename) {
    return 'Même nom que « $filename » dans ce dossier';
  }

  @override
  String get bulkRenameSkipAnotherSelected =>
      'Un autre morceau sélectionné porte déjà ce nom';

  @override
  String get bulkRenameSkipFileExists =>
      'Un fichier portant ce nom existe déjà ici';

  @override
  String get shuffleResetDone =>
      'Paramètres réinitialisés aux valeurs par défaut';

  @override
  String get shuffleReset => 'Réinitialiser';

  @override
  String get lyricsGroupDisplayTiming => 'Affichage et synchronisation';

  @override
  String get lyricsSimulateWordSyncTitle =>
      'Simuler la synchronisation mot à mot';

  @override
  String get lyricsSimulateWordSyncSubtitle =>
      'Générer une synchronisation au niveau des mots à partir des paroles synchronisées par ligne, avec une estimation prosodique';

  @override
  String get lyricsDesktopSidebarTitle =>
      'Panneau latéral des paroles et de la file d’attente';

  @override
  String get lyricsDesktopSidebarSubtitle =>
      'Afficher la poignée d’extension au survol pour rouvrir le panneau latéral des paroles et de la file d’attente lorsqu’il est masqué';

  @override
  String get lyricsKeepScreenAwakeTitle =>
      'Garder l’écran actif avec les paroles';

  @override
  String get lyricsKeepScreenAwakeSubtitle =>
      'Empêcher la mise en veille lorsque le panneau des paroles est ouvert';

  @override
  String get lyricsGroupTranslation => 'Traduction';

  @override
  String get lyricsAutoTranslateTitle => 'Traduire automatiquement les paroles';

  @override
  String get lyricsAutoTranslateSubtitle =>
      'Traduire automatiquement les paroles dans la langue cible sélectionnée';

  @override
  String get lyricsTargetLanguageTitle => 'Langue cible';

  @override
  String get lyricsTranslationDisplayTitle => 'Affichage de la traduction';

  @override
  String get lyricsTranslationModeReplaceSubtitle =>
      'Remplacer les paroles d’origine';

  @override
  String get lyricsTranslationModeSubtextSubtitle =>
      'Afficher la traduction sous les paroles';

  @override
  String get lyricsModeSubtext => 'En sous-titre';

  @override
  String get lyricsModeReplace => 'Remplacer l’original';

  @override
  String get lyricsTranslateTitle => 'Traduire les paroles';

  @override
  String get lyricsDisplayMode => 'Mode d’affichage';

  @override
  String get lyricsModeSubtextDescription =>
      'Afficher la traduction sous les paroles';

  @override
  String get lyricsModeReplaceDescription =>
      'Remplacer entièrement les paroles d’origine';

  @override
  String get lyricsAutoTranslateAllTitle =>
      'Traduire automatiquement tous les morceaux';

  @override
  String get lyricsAutoTranslateAllSubtitle =>
      'Traduire automatiquement les paroles dans la langue sélectionnée';

  @override
  String get lyricsTargetLanguageLabel => 'Langue cible';

  @override
  String get lyricsSearchLanguageHint => 'Rechercher une langue…';

  @override
  String get lyricsClearCache => 'Vider le cache';

  @override
  String get lyricsTranslateNow => 'Traduire maintenant';

  @override
  String get lyricsFindTitle => 'Trouver les paroles';

  @override
  String get lyricsNoResults =>
      'Aucune parole trouvée. Essayez un autre titre ou artiste, ou vérifiez votre connexion.';

  @override
  String lyricsSearchFailed(String error) {
    return 'Échec de la recherche de paroles : $error';
  }

  @override
  String get lyricsInstrumentalWarning =>
      'Marqué comme instrumental. Cette action efface toutes les paroles enregistrées dans le fichier.';

  @override
  String get lyricsApplyUpper => 'APPLIQUER';

  @override
  String get lyricsPlainText => 'Texte brut';

  @override
  String get lyricsUnknownLength => 'Durée inconnue';

  @override
  String lyricsDurationExactMatch(String duration) {
    return '$duration · correspondance exacte';
  }

  @override
  String get lyricsBadgeWordSync => 'SYNCHRONISATION MOT À MOT';

  @override
  String get lyricsBadgeLineSync => 'SYNCHRONISATION PAR LIGNE';

  @override
  String get lyricsBadgeInstrumental => 'INSTRUMENTAL';

  @override
  String get lyricsBadgePlain => 'TEXTE BRUT';

  @override
  String get lyricsSaved => 'Paroles enregistrées';

  @override
  String lyricsSaveError(Object error) {
    return 'Impossible d’enregistrer les paroles : $error';
  }

  @override
  String get lyricsTranslationCleared => 'Traduction en cache supprimée';

  @override
  String get lyricsAlreadyTranslated =>
      'Les paroles sont déjà dans la langue cible';

  @override
  String get lyricsTranslated => 'Paroles traduites';

  @override
  String get lyricsTranslateError => 'Impossible de traduire les paroles';

  @override
  String lyricsTranslationFailed(Object error) {
    return 'Échec de la traduction : $error';
  }

  @override
  String get lyricsHideTimingTooltip =>
      'Masquer la synchronisation des paroles';

  @override
  String get lyricsAdjustTimingTooltip =>
      'Ajuster la synchronisation des paroles — maintenir pour afficher les réglages précis';

  @override
  String get lyricsFindOnline => 'Trouver les paroles en ligne';

  @override
  String get lyricsEmptyTitle => 'Aucune parole';

  @override
  String get lyricsEmptySubtitle =>
      'Cette piste ne contient pas de paroles intégrées.';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languageItalian => 'Italien';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageChinese => 'Chinois';

  @override
  String get languageKorean => 'Coréen';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String get languageRussian => 'Russe';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get languageDutch => 'Néerlandais';

  @override
  String get languagePolish => 'Polonais';

  @override
  String get languageTurkish => 'Turc';

  @override
  String get languageVietnamese => 'Vietnamien';

  @override
  String get languageUkrainian => 'Ukrainien';

  @override
  String get languageSwedish => 'Suédois';

  @override
  String get languageIndonesian => 'Indonésien';

  @override
  String get languageThai => 'Thaï';

  @override
  String get languageCzech => 'Tchèque';

  @override
  String get languageGreek => 'Grec';

  @override
  String get languageHungarian => 'Hongrois';

  @override
  String get languageRomanian => 'Roumain';

  @override
  String get languageDanish => 'Danois';

  @override
  String get languageFinnish => 'Finnois';

  @override
  String get languageNorwegian => 'Norvégien';

  @override
  String get selectSongsTitle => 'Sélectionner des morceaux';

  @override
  String get selectSongsWhatIsMerging => 'Qu’est-ce que la fusion ?';

  @override
  String get selectSongsMergedExplanation =>
      'Les morceaux fusionnés sont différentes versions d’un même morceau :';

  @override
  String get selectSongsBulletVersions =>
      'Par exemple, des remixes, versions live ou versions de qualité différente';

  @override
  String get selectSongsBulletFavorites =>
      'Les favoris et l’option « proposer moins » sont propres à chaque morceau';

  @override
  String get selectSongsBulletStats =>
      'Vos nombres d’écoutes et statistiques restent inchangés';

  @override
  String get selectSongsBulletPriority =>
      'Choisissez un morceau prioritaire (⭐) pour le privilégier en lecture aléatoire';

  @override
  String get selectSongsSearchHint => 'Rechercher des morceaux…';

  @override
  String selectSongsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '1 sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get selectSongsReadyToMerge => 'Prêt à fusionner';

  @override
  String get selectSongsPrioritySongTooltip => 'Morceau prioritaire';

  @override
  String get selectSongsSetPriorityTooltip => 'Définir comme prioritaire';

  @override
  String get selectSongsPriorityBadge => 'PRIORITAIRE';

  @override
  String selectSongsMinSelection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sélectionnez au moins $count morceaux',
      one: 'Sélectionnez au moins 1 morceau',
    );
    return '$_temp0';
  }

  @override
  String selectSongsMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fusionner $count morceaux',
      one: 'Fusionner 1 morceau',
    );
    return '$_temp0';
  }

  @override
  String selectSongsSelectAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sélectionner $count morceaux',
      one: 'Sélectionner 1 morceau',
    );
    return '$_temp0';
  }

  @override
  String get foldersAddedSnack => 'Dossier musical ajouté';

  @override
  String get foldersRemovedSnack => 'Dossier musical retiré';

  @override
  String get foldersSubtitle =>
      'Sélectionnez les dossiers contenant vos fichiers musicaux';

  @override
  String get foldersEmptyTitle => 'Aucun dossier ajouté pour le moment';

  @override
  String get foldersEmptyMessage =>
      'Ajoutez un dossier pour créer votre bibliothèque.';

  @override
  String get foldersAddButton => 'Ajouter un dossier';

  @override
  String get foldersAllFilesGrantedTitle =>
      'Accès à tous les fichiers autorisé';

  @override
  String get foldersAllFilesGrantedSubtitle =>
      'wispie peut lire la musique dans chaque dossier que vous ajoutez.';

  @override
  String get foldersAllFilesMissingTitle =>
      'Accès à tous les fichiers désactivé';

  @override
  String get foldersAllFilesMissingSubtitle =>
      'Autorisez-le pour que wispie trouve la musique dans les dossiers hors de la bibliothèque multimédia par défaut.';

  @override
  String get foldersAllFilesAllowButton =>
      'Autoriser l’accès à tous les fichiers';

  @override
  String get foldersShortcutInternalStorage => 'Stockage interne';

  @override
  String get foldersShortcutMusic => 'Musique';

  @override
  String get foldersShortcutDownload => 'Téléchargement';

  @override
  String get foldersShortcutStorageRoot => 'Racine du stockage';

  @override
  String get foldersShortcutDownloads => 'Téléchargements';

  @override
  String get foldersShortcutDocuments => 'Documents';

  @override
  String get foldersDoesNotExist => 'Le dossier n’existe pas';

  @override
  String get foldersPermissionError =>
      'Accès refusé ou erreur lors de la lecture du dossier';

  @override
  String get foldersNewFolderTitle => 'Nouveau dossier';

  @override
  String get foldersFolderNameLabel => 'Nom du dossier';

  @override
  String get foldersFolderNameHint => 'Saisissez le nom du dossier';

  @override
  String foldersCreateError(String error) {
    return 'Erreur lors de la création du dossier : $error';
  }

  @override
  String get foldersGoUp => '.. (Remonter)';

  @override
  String get foldersGoBack => '.. (Retour)';

  @override
  String get foldersNoSubfolders =>
      'Aucun sous-dossier trouvé.\nSélectionnez ce dossier s’il contient votre musique.';

  @override
  String get foldersSelectThisFolder => 'Sélectionner ce dossier';

  @override
  String get foldersSelectDestination =>
      'Sélectionner le dossier de destination';

  @override
  String get foldersEmptyFolder =>
      'Dossier vide. Vous pouvez le sélectionner ci-dessous.';

  @override
  String foldersSelected(String name) {
    return 'Sélectionné : $name';
  }

  @override
  String get foldersRoot => 'Racine';

  @override
  String get foldersMoveFolder => 'Déplacer le dossier';

  @override
  String foldersMovedTo(String name, String path) {
    return '$name déplacé vers $path';
  }

  @override
  String foldersMoveError(String error) {
    return 'Erreur lors du déplacement du dossier : $error';
  }

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsSearchHint => 'Rechercher des playlists…';

  @override
  String get playlistsCreate => 'Créer une playlist';

  @override
  String get playlistsNoMatches => 'Aucune playlist correspondante trouvée';

  @override
  String playlistsCreatedOn(String date) {
    return 'Créée le $date';
  }

  @override
  String get playlistsCreatedToday => 'aujourd’hui';

  @override
  String get playlistsCreatedYesterday => 'hier';

  @override
  String playlistsDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count jours',
      one: 'Il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String playlistsWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il y a $count semaines',
      one: 'Il y a 1 semaine',
    );
    return '$_temp0';
  }

  @override
  String get playlistsEmptyTitle => 'Aucune playlist pour le moment';

  @override
  String get playlistsEmptyMessage =>
      'Créez votre première playlist pour commencer';

  @override
  String get playlistsNameHint => 'Saisissez le nom de la playlist';

  @override
  String get statsTitle => 'Écoute';

  @override
  String get statsLoadErrorTitle => 'Impossible de charger vos statistiques';

  @override
  String get statsReadingHistory => 'Lecture de votre historique d’écoute';

  @override
  String get statsEmptyTitle => 'Aucun historique d’écoute pour le moment';

  @override
  String get statsEmptyMessage =>
      'Écoutez un morceau pour découvrir vos habitudes d’écoute ici.';

  @override
  String get statsSectionOverTime => 'Au fil du temps';

  @override
  String get statsSectionWhen => 'Vos moments d’écoute';

  @override
  String get statsSectionTop => 'Vos préférés';

  @override
  String get statsSectionTaste => 'Vos goûts';

  @override
  String get statsByHour => 'PAR HEURE';

  @override
  String get statsByWeekday => 'PAR JOUR DE LA SEMAINE';

  @override
  String get statsNoListening => 'Aucune écoute enregistrée';

  @override
  String statsAcrossPlays(String time, String plays) {
    return '$time sur $plays';
  }

  @override
  String statsDayTotals(String time, String plays) {
    return '$time · $plays';
  }

  @override
  String get statsLibraryExplored => 'Bibliothèque explorée';

  @override
  String get statsPlaysFavourites => 'Écoutes de morceaux favoris';

  @override
  String get statsPlaysSkipped => 'Écoutes interrompues';

  @override
  String get statsAvgPlay => 'DURÉE MOYENNE D’ÉCOUTE';

  @override
  String get statsOnActiveDay => 'LORS D’UNE JOURNÉE ACTIVE';

  @override
  String get statsFirstListen => 'PREMIÈRE ÉCOUTE';

  @override
  String statsShareOf(String share, String count) {
    return '$share sur $count';
  }

  @override
  String get statsTopArtists => 'ARTISTES PRÉFÉRÉS';

  @override
  String get statsTopAlbums => 'ALBUMS PRÉFÉRÉS';

  @override
  String get statsTopTracks => 'MORCEAUX PRÉFÉRÉS';

  @override
  String get statsTimeListened => 'TEMPS D’ÉCOUTE';

  @override
  String statsRangeWithDays(String range, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours avec de la musique',
      one: '1 jour avec de la musique',
    );
    return '$range · $_temp0';
  }

  @override
  String get statsPlays => 'ÉCOUTES';

  @override
  String get statsSkips => 'MORCEAUX PASSÉS';

  @override
  String get statsTracks => 'PISTES';

  @override
  String get statsStreak => 'SÉRIE';

  @override
  String statsStreakBest(int count) {
    return 'record : $count';
  }

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count écoutes',
      one: '1 écoute',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours actifs',
      one: '1 jour actif',
    );
    return '$_temp0';
  }

  @override
  String statsSummary(String duration, String plays, String days) {
    return '$duration · $plays · $days';
  }

  @override
  String get statsEmptyHint =>
      'Écoutez un morceau pour commencer votre historique';

  @override
  String get statsLoadError => 'Impossible de charger vos statistiques';

  @override
  String statsDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String statsDurationHours(int hours) {
    return '$hours h';
  }

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get statsSameAsBefore => 'identique à la période précédente';

  @override
  String statsHourTickAm(int hour) {
    return '$hour h';
  }

  @override
  String statsHourTickPm(int hour) {
    return '$hour h';
  }

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get actionRefresh => 'Actualiser';

  @override
  String get sessionDetailTitle => 'Détails de la session';

  @override
  String sessionStartedAt(String time) {
    return 'Commencée à $time';
  }

  @override
  String get sessionSongSingular => 'Morceau';

  @override
  String get sessionSongsPlayed => 'Morceaux écoutés';

  @override
  String get sessionNoSongs => 'Aucun morceau enregistré';

  @override
  String get sessionRepeatNow => 'Relancer la file d’attente';

  @override
  String get sessionNoSongsAvailable => 'Aucun morceau disponible à la lecture';

  @override
  String sessionAfterCurrentSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux seront lus après le morceau en cours',
      one: '1 morceau sera lu après le morceau en cours',
    );
    return '$_temp0';
  }

  @override
  String sessionPlayingSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lecture de $count morceaux de cette session',
      one: 'Lecture d’un morceau de cette session',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryTitle => 'Historique des sessions';

  @override
  String get sessionLoadFailed => 'Échec du chargement des sessions';

  @override
  String get sessionEmptyTitle => 'Aucune session pour le moment';

  @override
  String get sessionEmptyMessage =>
      'Commencez à écouter pour créer votre historique de sessions';

  @override
  String get playHistoryTitle => 'Historique des morceaux';

  @override
  String get playHistoryEmptyTitle =>
      'Aucun historique d’écoute pour le moment';

  @override
  String get playHistoryEmptyMessage =>
      'Commencez à écouter pour créer votre historique.';

  @override
  String get playHistoryListen => 'Écoute';

  @override
  String get playHistorySkip => 'Passé';

  @override
  String playHistorySummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count écoutes',
      one: '1 écoute',
    );
    return '$_temp0 · $duration';
  }

  @override
  String playHistoryDate(String month, int day, int year) {
    return '$day $month $year';
  }

  @override
  String get monthShortJan => 'janv.';

  @override
  String get monthShortFeb => 'févr.';

  @override
  String get monthShortMar => 'mars';

  @override
  String get monthShortApr => 'avr.';

  @override
  String get monthShortMay => 'mai';

  @override
  String get monthShortJun => 'juin';

  @override
  String get monthShortJul => 'juil.';

  @override
  String get monthShortAug => 'août';

  @override
  String get monthShortSep => 'sept.';

  @override
  String get monthShortOct => 'oct.';

  @override
  String get monthShortNov => 'nov.';

  @override
  String get monthShortDec => 'déc.';

  @override
  String get searchFieldHint => 'Rechercher des morceaux, artistes, albums…';

  @override
  String get onlineTab => 'YouTube';

  @override
  String get onlineSearchHint => 'Rechercher sur YouTube';

  @override
  String get onlineSearchPrompt => 'Rechercher des morceaux sur YouTube';

  @override
  String get onlineLoading => 'Recherche sur YouTube…';

  @override
  String get onlineNoResults => 'Aucun morceau trouvé';

  @override
  String get onlineArtistNotFound =>
      'Aucun artiste YouTube trouvé sous ce nom.';

  @override
  String get onlineAlbumNotFound => 'Aucun album YouTube trouvé sous ce nom.';

  @override
  String get onlineYoutubeError =>
      'Impossible de charger les données depuis YouTube.';

  @override
  String get onlineYoutubeErrorNetwork =>
      'Impossible de joindre YouTube. Vérifiez votre connexion.';

  @override
  String get onlineYoutubeErrorRateLimited =>
      'YouTube limite le nombre de requêtes. Patientez un instant puis réessayez.';

  @override
  String get onlineYoutubeErrorUnavailable =>
      'Cette vidéo n’est pas disponible sur YouTube.';

  @override
  String get onlineYoutubeErrorBlocked =>
      'YouTube a refusé ce morceau. Essayez un autre résultat.';

  @override
  String get onlineYoutubeErrorResponse =>
      'YouTube a renvoyé une réponse inattendue.';

  @override
  String get onlineUnavailable => 'Indisponible en ligne';

  @override
  String get onlineLibraryAdd => 'Ajouter à la bibliothèque';

  @override
  String get onlineLibraryRemove => 'Retirer de la bibliothèque';

  @override
  String onlineLibraryAdded(String title) {
    return '$title ajouté à votre bibliothèque';
  }

  @override
  String onlineLibraryRemoved(String title) {
    return '$title retiré de votre bibliothèque';
  }

  @override
  String onlineLibraryAddFailed(String title) {
    return 'Impossible d’enregistrer $title dans votre bibliothèque';
  }

  @override
  String get songMenuLibrarySaveHint =>
      'Conserver ce morceau en streaming dans votre bibliothèque';

  @override
  String get searchEmptyTitle => 'Rechercher dans votre collection musicale';

  @override
  String get searchEmptyMessage =>
      'Trouvez des morceaux, artistes, albums et paroles.';

  @override
  String get searchFailed => 'Impossible d’effectuer la recherche';

  @override
  String searchNoResults(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get searchNoResultsHint =>
      'Essayez d’autres mots-clés ou vérifiez vos filtres.';

  @override
  String searchArtistsSection(int count) {
    return 'Artistes ($count)';
  }

  @override
  String searchAlbumsSection(int count) {
    return 'Albums ($count)';
  }

  @override
  String searchSongsSection(int count) {
    return 'Morceaux ($count)';
  }

  @override
  String searchAlbumSubtitle(String artist, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
    );
    return '$artist · $_temp0';
  }

  @override
  String get quickActionSuggestMore => 'Proposer plus souvent';

  @override
  String get quickActionSuggestLess => 'Proposer moins souvent';

  @override
  String get quickActionGoToAlbum => 'Accéder à l’album';

  @override
  String get quickActionGoToArtist => 'Accéder à l’artiste';

  @override
  String get aboutChecking => 'Recherche de mises à jour…';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Mise à jour disponible : $version';
  }

  @override
  String get aboutUpToDate => 'Vous utilisez la dernière version';

  @override
  String get aboutCheckForUpdates => 'Rechercher des mises à jour';

  @override
  String get aboutCheckingSubtitle => 'wispie vérifie les versions sur GitHub.';

  @override
  String get aboutUpdateAvailableSubtitle =>
      'Une nouvelle version est disponible sur GitHub.';

  @override
  String aboutLatestRelease(String version) {
    return 'Dernière version : $version';
  }

  @override
  String get aboutTapToCheck =>
      'Appuyez ci-dessous pour vérifier manuellement.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutUnknown => 'Inconnue';

  @override
  String get aboutCheckNow => 'Vérifier maintenant';

  @override
  String get aboutViewRelease => 'Afficher la version';

  @override
  String get aboutSupportGroup => 'Assistance';

  @override
  String get aboutContactTitle => 'Me contacter';

  @override
  String get aboutContactSubtitle => 'Bugs, idées ou autre chose';

  @override
  String get aboutIssuesTitle => 'Signaler un problème';

  @override
  String get aboutIssuesSubtitle => 'Ouvre le dépôt wispie sur GitHub';

  @override
  String get aboutLinkFailed => 'Impossible d’ouvrir le lien';

  @override
  String get aboutDebugGroup => 'Débogage';

  @override
  String get aboutPersistWrites => 'Conserver les écritures';

  @override
  String get aboutPersistWritesSubtitle =>
      'Par défaut, les versions de débogage appliquent les modifications à une copie temporaire. Le réglage prend effet au prochain lancement.';

  @override
  String get appIconMoreSoon => 'D’autres icônes bientôt disponibles';

  @override
  String get appIconDesktopNote =>
      'Les lanceurs et gestionnaires de fichiers de bureau conservent l’icône par défaut ; l’icône de la fenêtre et du Dock suit votre choix.';

  @override
  String get storageSettingsDiskGroup => 'Disque';

  @override
  String get storageSettingsIndexesGroup => 'Index et caches';

  @override
  String get shellNavHome => 'Accueil';

  @override
  String get shellSearchTooltip => 'Rechercher (Ctrl+K)';

  @override
  String get shellShowSidebar => 'Afficher le panneau latéral';

  @override
  String get shellHideSidebar => 'Masquer le panneau latéral';

  @override
  String get shellNothingUpNext => 'Rien à suivre';

  @override
  String get shellNextInQueue => 'Prochain dans la file d’attente';

  @override
  String get shellPlayNext => 'Lire ensuite';

  @override
  String get playerNothingPlaying => 'Aucun morceau en cours de lecture';

  @override
  String get playerPanePlayer => 'Lecteur';

  @override
  String get playerPaneQueue => 'File d’attente';

  @override
  String get playerCloseEsc => 'Fermer (Échap)';

  @override
  String get playerSongOptions => 'Options du morceau';

  @override
  String get playerShowArtwork => 'Afficher la pochette';

  @override
  String get playerShowVideo => 'Afficher la vidéo';

  @override
  String get drawerQueueHistory => 'Historique de la file d’attente';

  @override
  String get drawerTools => 'Outils';

  @override
  String get nowPlayingBarShuffleTooltip =>
      'Lecture aléatoire (maintenir pour relancer le mélange)';

  @override
  String get shuffleButtonAfterSong => 'Mélanger après le morceau en cours';

  @override
  String get shuffleButtonAfterQueue =>
      'Mélanger après la file d’attente actuelle';

  @override
  String shuffleButtonScanningTooltip(String percentage) {
    return 'Analyse de la bibliothèque ($percentage %)';
  }

  @override
  String shuffleButtonScanningSemantics(String percentage) {
    return 'Analyse de la bibliothèque terminée à $percentage %';
  }

  @override
  String shuffleButtonScanningMessage(String percentage) {
    return 'Analyse de la bibliothèque : $percentage %';
  }

  @override
  String heartMenuRemoveFromPlaylist(String name) {
    return 'Retirer de $name';
  }

  @override
  String heartMenuRemovedFromPlaylist(String name) {
    return 'Retiré de $name';
  }

  @override
  String get sortBy => 'Trier par';

  @override
  String get sortTitleAZ => 'Titre (A-Z)';

  @override
  String get sortDateAdded => 'Date d’ajout';

  @override
  String get sortSongDateOldNew => 'Date du morceau (ancien - récent)';

  @override
  String get sortSongDateNewOld => 'Date du morceau (récent - ancien)';

  @override
  String get sortMostPlayed => 'Les plus écoutés';

  @override
  String get sortRecentlyPlayed => 'Récemment écoutés';

  @override
  String get sortRecommended => 'Recommandés';

  @override
  String get searchFilterArtists => 'Artistes';

  @override
  String get playlistDialogAddTo => 'Ajouter à…';

  @override
  String get playlistDialogBulkAddTo => 'Ajouter en lot à…';

  @override
  String get playlistDialogUpdatedSelections => 'Sélections mises à jour';

  @override
  String get albumCardAllSongs => 'Tous les morceaux';

  @override
  String dangerDialogTypeToConfirm(String text) {
    return 'Saisissez « $text » pour confirmer';
  }

  @override
  String dangerDialogCountdown(String label, int seconds) {
    return '$label ($seconds)';
  }

  @override
  String get appDialogConfirm => 'Confirmer';

  @override
  String get appDialogEnterName => 'Saisissez un nom…';

  @override
  String get transportRepeatOff => 'Répétition désactivée';

  @override
  String get transportRepeatAll => 'Tout répéter';

  @override
  String get transportRepeatOne => 'Répéter le morceau';

  @override
  String durationSongsWithTotal(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '1 morceau',
    );
    return '$_temp0 • $duration';
  }

  @override
  String waveformDeltaMinutes(String minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String waveformDeltaSeconds(String value) {
    return '$value s';
  }

  @override
  String get waveformDeltaZero => '0 s';

  @override
  String lyricsMatchContains(String line) {
    return 'contient « $line »';
  }

  @override
  String get lyricsMatchPrefix => 'contient « ';

  @override
  String get lyricsMatchAvailable => 'Paroles disponibles';

  @override
  String get lyricsResumeSync => 'Reprendre la synchronisation';

  @override
  String get lyricsTimingTitle => 'Synchronisation des paroles';

  @override
  String get lyricsTimingLater => 'Plus tard';

  @override
  String get lyricsTimingSyncToLine => 'Synchroniser sur cette ligne';

  @override
  String get lyricsTimingReset => 'Réinitialiser la synchronisation';

  @override
  String lyricsTimingSnapped(String value) {
    return 'Calé sur $value';
  }

  @override
  String get lyricsTimingRangeLabel =>
      'Plage (jusqu’à 60 s dans les deux sens)';

  @override
  String get lyricsTimingFineLabel =>
      'Réglage précis (5 s de chaque côté, pas de 0,01 s)';

  @override
  String get lyricsTimingResetTooltip =>
      'Touchez deux fois pour réinitialiser à 0,00';

  @override
  String get quickActionsTitle => 'Actions rapides';

  @override
  String get quickActionsResetDone => 'Valeurs par défaut rétablies';

  @override
  String quickActionsEnabledHeader(int count) {
    return 'ACTIVÉES ($count)';
  }

  @override
  String quickActionsDisabledHeader(int count) {
    return 'DÉSACTIVÉES ($count)';
  }

  @override
  String get quickActionsGoToAlbum => 'Accéder à l’album';

  @override
  String get quickActionsGoToArtist => 'Accéder à l’artiste';

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String get updateCurrentLabel => 'Actuelle';

  @override
  String get updateAvailableBody =>
      'Une nouvelle version de wispie est prête à être téléchargée.';

  @override
  String get updateSkipVersion => 'Ignorer cette version';

  @override
  String get updateWhatsNew => 'Quoi de neuf ?';

  @override
  String get externalOpenAddToLibrary => 'Ajouter à la bibliothèque';

  @override
  String get externalOpenDismiss => 'Ignorer';

  @override
  String get wideTrackTime => 'Temps';

  @override
  String get floatingDockNext => 'Suivant';

  @override
  String get barSeekLabel => 'Rechercher dans le morceau';

  @override
  String get indexerOpOptimizeDatabasesTitle =>
      'Optimiser les bases de données';

  @override
  String get indexerOpOptimizeDatabasesDesc =>
      'Nettoyer et optimiser toutes les bases de données de l’application';

  @override
  String get indexerOpRepairLinksTitle =>
      'Réparer les liens de la bibliothèque';

  @override
  String get indexerOpRepairLinksDesc =>
      'Relier les pochettes d’album et chemins de fichiers après une restauration ou sur un nouvel appareil';

  @override
  String get indexerOpMatchIdentityTitle =>
      'Associer les morceaux par leur audio';

  @override
  String get indexerOpMatchIdentityDesc =>
      'Créer l’empreinte audio de chaque fichier afin que les morceaux renommés conservent leurs favoris, playlists et statistiques et puissent être associés entre appareils synchronisés';

  @override
  String get indexerOpCoverCacheTitle => 'Reconstruire le cache des pochettes';

  @override
  String get indexerOpCoverCacheDesc =>
      'Extraire et mettre en cache les pochettes intégrées aux fichiers';

  @override
  String get indexerOpSearchIndexTitle => 'Reconstruire les index de recherche';

  @override
  String get indexerOpSearchIndexDesc =>
      'Reconstruire l’index de recherche de tous les morceaux';

  @override
  String get indexerOpLyricsCacheTitle => 'Reconstruire le cache des paroles';

  @override
  String get indexerOpLyricsCacheDesc =>
      'Extraire et mettre en cache les paroles de tous les morceaux';

  @override
  String get indexerOpWaveformCacheTitle =>
      'Reconstruire le cache des formes d’onde';

  @override
  String get indexerOpWaveformCacheDesc =>
      'Générer les formes d’onde de tous les morceaux';

  @override
  String get indexerOpColorCacheTitle =>
      'Reconstruire le thème de l’application à partir des pochettes';

  @override
  String get indexerOpColorCacheDesc =>
      'Extraire les thèmes de couleur de toutes les pochettes';

  @override
  String get indexerOpBlurredCacheTitle =>
      'Reconstruire le cache des arrière-plans floutés';

  @override
  String get indexerOpBlurredCacheDesc =>
      'Pré-générer des arrière-plans floutés optimisés';

  @override
  String get indexerOpRecommendationsTitle =>
      'Reconstruire les recommandations';

  @override
  String get indexerOpRecommendationsDesc =>
      'Forcer la reconstruction de toutes les playlists recommandées';

  @override
  String get indexerOpArtistAlbumArtTitle =>
      'Récupérer les pochettes d’artistes et d’albums';

  @override
  String get indexerOpArtistAlbumArtDesc =>
      'Récupérer en ligne les pochettes manquantes d’artistes et d’albums, en commençant par les plus grandes collections';

  @override
  String get indexerCounting => 'Comptage…';

  @override
  String get indexerWorking => 'Traitement en cours…';

  @override
  String get indexerStopping => 'Arrêt en cours…';

  @override
  String indexerProgressPercent(int percent) {
    return 'Traitement : $percent %';
  }

  @override
  String indexerProgressFailed(int done, int total, int failed) {
    return 'Traitement : $done/$total ($failed échecs)';
  }

  @override
  String indexerStoppedAt(int done, int total) {
    return 'Arrêté à $done/$total';
  }

  @override
  String indexerFinished(int processed, int failed) {
    return 'Terminé : $processed traités, $failed échecs';
  }

  @override
  String get indexerNothingToDo => 'Rien à faire, tout est déjà à jour';

  @override
  String get indexerErrorBusy => 'Déjà en cours en arrière-plan';

  @override
  String get indexerErrorOffline =>
      'Connexion perdue ; le reste reprendra automatiquement';

  @override
  String get indexerStop => 'Arrêter';

  @override
  String get youtubeAccountTitle => 'Compte YouTube';

  @override
  String get youtubeAccountLoading => 'Chargement de votre compte YouTube…';

  @override
  String get youtubeAccountSignedOutTitle =>
      'Importez vos playlists YouTube ici';

  @override
  String get youtubeAccountSignedOutBody =>
      'Connectez-vous pour importer vos playlists YouTube dans cette bibliothèque. La recherche, la lecture, les favoris et les statistiques d’écoute fonctionnent sans compte.';

  @override
  String get youtubeAccountSignIn => 'Se connecter avec Google';

  @override
  String get youtubeAccountSignInTryWeb => 'Essayer la connexion intégrée';

  @override
  String get youtubeAccountSignInHint =>
      'Ouvre la page de connexion officielle de Google dans l’application. Wispie conserve la session YouTube obtenue sur cet appareil et ne voit jamais votre mot de passe.';

  @override
  String get youtubeAccountSignInHintManual =>
      'Connectez-vous à YouTube dans un navigateur, puis transférez les cookies de session : l’écran du compte accepte un en-tête Cookie, un fichier cookies.txt ou un JSON de cookies. Les cookies restent sur cet appareil et sont les seuls éléments nécessaires à wispie.';

  @override
  String get youtubeAccountWebTitle => 'Connexion Google';

  @override
  String get youtubeAccountWebTrouble =>
      'Un problème de connexion ? Utilisez plutôt les cookies';

  @override
  String get youtubeAccountWebTroubleAction => 'Utiliser les cookies';

  @override
  String get youtubeAccountWebFailed =>
      'Impossible de charger cette page. Vérifiez votre connexion ou utilisez les cookies.';

  @override
  String get youtubeAccountWebUnsupported =>
      'Cette plateforme ne dispose pas de navigateur intégré.';

  @override
  String get youtubeAccountWebBlockedTitle =>
      'Google a bloqué la connexion intégrée';

  @override
  String get youtubeAccountWebBlockedBody =>
      'Google refuse les connexions depuis d’autres applications ; un mot de passe saisi ici ne peut donc pas être accepté. Connectez-vous à YouTube dans votre navigateur, puis importez les cookies de session depuis l’écran du compte : le résultat est identique et votre mot de passe n’est jamais saisi dans wispie.';

  @override
  String get youtubeAccountWebPasskeyTitle => 'Google demande une clé d’accès';

  @override
  String get youtubeAccountWebPasskeyBody =>
      'Une clé d’accès ne peut pas être utilisée depuis une autre application ; cette étape ne peut donc pas aboutir ici. Connectez-vous plutôt avec votre mot de passe ; la suite du processus fonctionnera normalement.';

  @override
  String get youtubeAccountWebPasskeyAction => 'Utiliser mon mot de passe';

  @override
  String get youtubeAccountOpenYouTube => 'Ouvrir youtube.com';

  @override
  String get youtubeSearchSongs => 'Morceaux';

  @override
  String get youtubeSearchAlbums => 'Albums';

  @override
  String get youtubeSearchPlaylists => 'Playlists';

  @override
  String get youtubeSearchArtists => 'Artistes';

  @override
  String get youtubeArtistSongsTitle => 'Morceaux populaires';

  @override
  String get youtubeArtistAlbumsTitle => 'Albums et singles';

  @override
  String get youtubeCollectionEmpty => 'Aucun morceau à écouter ici.';

  @override
  String get youtubeAccountSignOut => 'Se déconnecter';

  @override
  String youtubeAccountSignedInAs(String name) {
    return 'Connecté en tant que $name';
  }

  @override
  String get youtubeAccountSessionExpired =>
      'Votre session YouTube a expiré. Reconnectez-vous pour continuer à synchroniser vos playlists.';

  @override
  String get youtubeAccountCookiesTitle => 'Coller les cookies YouTube';

  @override
  String get youtubeAccountCookiesBody =>
      'Connectez-vous à YouTube dans un navigateur, puis copiez l’en-tête de requête Cookie d’une requête youtube.com (outils de développement : Réseau -> En-têtes), ou exportez un fichier cookies.txt et collez son contenu ici. Seuls les cookies youtube.com sont conservés.';

  @override
  String get youtubeAccountCookiesHint =>
      'En-tête Cookie, fichier cookies.txt ou JSON de cookies exporté';

  @override
  String get youtubeAccountCookiesImport => 'Importer les cookies';

  @override
  String get youtubeAccountCookiesFile => 'Choisir un fichier cookies.txt';

  @override
  String get youtubeAccountCookiesEmpty => 'Aucun cookie trouvé dans ce texte.';

  @override
  String get youtubeAccountCookiesUnreadable =>
      'Impossible de lire ce fichier.';

  @override
  String get youtubeAccountPlaylistsTitle => 'Vos playlists';

  @override
  String get youtubeFeedForYou => 'Pour vous';

  @override
  String get youtubeFeedFromLibrary => 'D’après les artistes que vous écoutez';

  @override
  String get youtubeFeedFilterPlaylists => 'Choisir les playlists';

  @override
  String get youtubeFeedPlaylistsHidden =>
      'Toutes les playlists sont masquées dans cet onglet.';

  @override
  String get youtubeFeedPlaylists => 'Vos playlists';

  @override
  String get youtubeFeedSignInTitle =>
      'Connectez-vous pour accéder à votre fil';

  @override
  String get youtubeFeedSignInBody =>
      'Votre fil d’accueil YouTube dépend de ce que vous regardez et des chaînes auxquelles vous êtes abonné. Connectez-vous aussi pour prévisualiser et importer vos playlists.';

  @override
  String get youtubeFeedSignInAction => 'Se connecter';

  @override
  String get youtubeFeedEmpty =>
      'Rien ici pour le moment. Lancez une recherche ci-dessus.';

  @override
  String get youtubePreviewEmpty =>
      'Cette playlist ne contient aucune piste lisible.';

  @override
  String get youtubePreviewPlayAll => 'Tout lire';

  @override
  String get youtubeAccountLikedVideos => 'Vidéos aimées';

  @override
  String youtubeAccountPlaylistTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistes',
      one: '1 piste',
      zero: 'Aucune piste',
    );
    return '$_temp0';
  }

  @override
  String get youtubeAccountImport => 'Importer';

  @override
  String get youtubeAccountSync => 'Synchroniser';

  @override
  String get youtubeAccountSyncAll =>
      'Synchroniser toutes les playlists importées';

  @override
  String get youtubeAccountSyncHint =>
      'La synchronisation ajoute uniquement des pistes. Rien n’est jamais retiré de vos playlists.';

  @override
  String youtubeAccountImportDone(int count, String name) {
    return '$count pistes importées depuis $name';
  }

  @override
  String youtubeAccountSyncDone(int count, String name) {
    return '$count nouvelles pistes ajoutées à $name';
  }

  @override
  String youtubeAccountSyncUpToDate(String name) {
    return '$name est à jour';
  }

  @override
  String youtubeAccountSyncLimited(int count) {
    return 'Seules les $count premières nouvelles pistes ont été ajoutées. Relancez la synchronisation pour récupérer le reste.';
  }

  @override
  String get youtubeAccountPlaylistEmpty =>
      'Cette playlist ne contient aucune piste lisible.';

  @override
  String get youtubeAccountLoadFailed => 'Impossible de charger vos playlists.';

  @override
  String get youtubeAccountTryAgain => 'Réessayer';

  @override
  String get youtubeAccountErrorNetwork =>
      'Impossible de joindre YouTube. Vérifiez votre connexion et réessayez.';

  @override
  String get youtubeAccountErrorUnauthorized =>
      'Votre session YouTube n’est plus valide. Reconnectez-vous.';

  @override
  String get youtubeAccountErrorResponse =>
      'YouTube a renvoyé une réponse inattendue.';

  @override
  String get youtubeAccountErrorRateLimited =>
      'YouTube limite les requêtes pour le moment. Réessayez dans quelques minutes.';

  @override
  String get youtubeAccountErrorStorage =>
      'Impossible de stocker la session de manière sécurisée sur cet appareil.';

  @override
  String get youtubeAccountErrorGeneric =>
      'Impossible de joindre votre compte YouTube.';

  @override
  String get playlistSyncFromYoutube => 'Synchroniser depuis YouTube';

  @override
  String get playlistYoutubeBadge => 'YouTube';

  @override
  String get batchReplaceTitle => 'Remplacement en lot';

  @override
  String get batchReplaceIntro =>
      'Choisissez un dossier à comparer à votre bibliothèque. Les fichiers correspondant à des morceaux seront proposés en remplacement.';

  @override
  String get batchReplaceFolderLabel => 'Dossier à comparer';

  @override
  String get batchReplaceNoFolder => 'Aucun dossier sélectionné';

  @override
  String get batchReplaceChooseFolder => 'Choisir un dossier';

  @override
  String get batchReplaceChangeFolder => 'Modifier';

  @override
  String get batchReplaceSubfolders => 'Inclure les sous-dossiers';

  @override
  String get batchReplaceInsideLibrary =>
      'Ce dossier fait déjà partie de votre bibliothèque. Choisissez un dossier situé en dehors.';

  @override
  String get batchReplacePhaseListing => 'Liste des fichiers';

  @override
  String get batchReplacePhaseReading => 'Lecture des balises';

  @override
  String get batchReplacePhaseReplacing => 'Remplacement des morceaux';

  @override
  String get batchReplaceStopping => 'Arrêt en cours';

  @override
  String batchReplaceCompareError(Object error) {
    return 'Impossible de comparer ce dossier : $error';
  }

  @override
  String batchReplaceMatched(int count) {
    return '$count morceaux correspondants';
  }

  @override
  String batchReplaceCompared(int files, int songs) {
    return '$files fichiers comparés aux $songs morceaux de la bibliothèque';
  }

  @override
  String get batchReplaceSelectAll => 'Tout sélectionner';

  @override
  String get batchReplaceSelectNone => 'Tout désélectionner';

  @override
  String batchReplaceConfidence(int percent) {
    return '$percent %';
  }

  @override
  String get batchReplaceSignalTitle => 'Titre';

  @override
  String get batchReplaceSignalFilename => 'Nom du fichier';

  @override
  String get batchReplaceSignalArtist => 'Artiste';

  @override
  String get batchReplaceSignalAlbum => 'Album';

  @override
  String get batchReplaceSignalDuration => 'Durée';

  @override
  String get batchReplaceLengthDiffers => 'la durée diffère';

  @override
  String batchReplaceUnmatched(int count) {
    return 'Aucun morceau correspondant pour $count fichiers';
  }

  @override
  String batchReplaceAndMore(int count) {
    return 'et $count de plus';
  }

  @override
  String get batchReplaceCompareAgain => 'Comparer à nouveau';

  @override
  String get batchReplaceNoMatchesTitle => 'Aucune correspondance';

  @override
  String batchReplaceNoMatchesMessage(int files) {
    return 'Aucun des $files fichiers de ce dossier ne semble correspondre à un morceau déjà présent dans votre bibliothèque.';
  }

  @override
  String get batchReplaceNothingSelected => 'Aucun élément sélectionné';

  @override
  String get batchReplaceCollisionTitle => 'Des fichiers existent déjà';

  @override
  String batchReplaceCollisionMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fichiers de remplacement existent déjà à l’emplacement où ils seraient copiés. Les remplacer ou les ignorer ?',
      one:
          'Un fichier de remplacement existe déjà à l’emplacement où il serait copié. Le remplacer ou l’ignorer ?',
    );
    return '$_temp0';
  }

  @override
  String get batchReplaceCollisionReplace => 'Remplacer';

  @override
  String get batchReplaceCollisionSkip => 'Ignorer';

  @override
  String get batchReplaceOptionsTitle => 'Remplacer les morceaux';

  @override
  String get batchReplaceTransportSection => 'Nouveaux fichiers';

  @override
  String get batchReplaceTransportCopy => 'Copier dans la bibliothèque';

  @override
  String get batchReplaceTransportCopyHint =>
      'Les copies restent dans le dossier comparé';

  @override
  String get batchReplaceTransportMove => 'Déplacer dans la bibliothèque';

  @override
  String get batchReplaceTransportMoveHint =>
      'Les fichiers utilisés seront retirés du dossier comparé';

  @override
  String get batchReplaceOriginalSection => 'Anciens fichiers';

  @override
  String get batchReplaceOriginalHide => 'Les conserver masqués';

  @override
  String get batchReplaceOriginalHideHint =>
      'Les fichiers restent sur le disque, hors de la bibliothèque';

  @override
  String get batchReplaceOriginalDelete => 'Les supprimer';

  @override
  String get batchReplaceOriginalDeleteHint =>
      'Les fichiers seront définitivement supprimés du disque';

  @override
  String batchReplaceRun(int count) {
    return 'Remplacer $count morceaux';
  }

  @override
  String get batchReplaceDeleteTitle => 'Supprimer les anciens fichiers ?';

  @override
  String batchReplaceDeleteMessage(int count) {
    return '$count fichiers d’origine seront supprimés du disque. Cette action est irréversible.';
  }

  @override
  String get batchReplaceDeleteConfirm => 'Supprimer';

  @override
  String get batchReplaceOutcomeTitle => 'Remplacement en lot';

  @override
  String batchReplaceOutcomeDone(int count) {
    return '$count morceaux remplacés.';
  }

  @override
  String batchReplaceOutcomeDoneFailed(int count, int failed) {
    return '$count morceaux remplacés ; $failed n’ont pas pu l’être.';
  }

  @override
  String batchReplaceOutcomeStopped(int count) {
    return 'Arrêt après le remplacement de $count morceaux.';
  }

  @override
  String batchReplaceOutcomeStoppedFailed(int count, int failed) {
    return 'Arrêt après le remplacement de $count morceaux ; $failed n’ont pas pu l’être.';
  }

  @override
  String batchReplaceFailureError(Object error) {
    return '$error';
  }

  @override
  String get settingsSearchBatchReplaceTitle => 'Remplacer plusieurs morceaux';

  @override
  String get settingsSearchBatchReplaceSubtitle =>
      'Remplacer des morceaux par de meilleurs fichiers provenant d’un autre dossier';

  @override
  String get storageWispieCacheTitle => 'Cache wispie';

  @override
  String get storageWispieCacheSubtitle =>
      'Reconstruit à la demande. Aucune donnée personnelle n’est stockée ici.';

  @override
  String get storageCleanCacheAction => 'Nettoyer';

  @override
  String get storageCleanCacheTitle => 'Nettoyer le cache ?';

  @override
  String get storageCleanCacheBody =>
      'Supprime les fichiers en cache qui ne sont plus référencés, les fichiers vides et ceux qui dépassent la limite de taille. Tout sera reconstruit si nécessaire.';

  @override
  String storageCleanCacheSuccess(String size) {
    return 'Cache nettoyé : $size';
  }

  @override
  String get storageCleanCacheNothing => 'Le cache est déjà propre';

  @override
  String storageCleanCacheError(String error) {
    return 'Erreur lors du nettoyage du cache : $error';
  }

  @override
  String get storageCacheEmpty => 'Vide';

  @override
  String storageClearBucketTitle(String name) {
    return 'Vider $name ?';
  }

  @override
  String get storageClearBucketBody =>
      'Ces fichiers seront recréés la prochaine fois qu’ils seront nécessaires.';

  @override
  String storageClearBucketSuccess(String name) {
    return '$name vidé';
  }

  @override
  String storageClearBucketError(String name, String error) {
    return 'Erreur lors du vidage de $name : $error';
  }

  @override
  String get storageClearWispieCacheTitle => 'Vider le cache wispie ?';

  @override
  String get storageClearWispieCacheBody =>
      'Tous les fichiers en cache seront supprimés et recréés si nécessaire. Votre bibliothèque, vos playlists et vos statistiques ne seront pas modifiées.';

  @override
  String get storageClearWispieCacheSuccess => 'Cache wispie vidé';

  @override
  String get storageRemoteArtTitle => 'Pochettes téléchargées';

  @override
  String get storageRemoteArtSubtitle =>
      'Pochettes récupérées en ligne pour les thèmes';

  @override
  String get storageNotificationCacheTitle => 'Pochettes de notification';

  @override
  String get storageNotificationCacheSubtitle =>
      'Pochettes carrées pour la notification multimédia';

  @override
  String get storageYoutubeCacheTitle => 'Pages en ligne';

  @override
  String get storageYoutubeCacheSubtitle =>
      'Pages YouTube et fil d’accueil en cache';

  @override
  String storageBackupsLocation(String path) {
    return 'Enregistré dans $path';
  }
}
