// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Seguir el idioma del sistema';

  @override
  String get languageNativeName => 'Español';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsPageLibrarySubtitle => 'Carpetas, filtros y análisis';

  @override
  String get settingsPagePlaybackTitle => 'Reproducción';

  @override
  String get settingsPagePlaybackSubtitle => 'Transiciones, fundidos y audio';

  @override
  String get settingsPageLyricsTitle => 'Letras';

  @override
  String get settingsPageLyricsSubtitle =>
      'Sincronización por palabras, traducción y panel lateral';

  @override
  String get settingsPageAppearanceTitle => 'Apariencia';

  @override
  String get settingsPageAppearanceSubtitle =>
      'Reproducción, movimiento e icono de la aplicación';

  @override
  String get settingsPageHomeNavigationTitle => 'Inicio y navegación';

  @override
  String get settingsPageHomeNavigationSubtitle =>
      'Secciones de inicio, listas y acciones rápidas';

  @override
  String get settingsPageOnlineTitle => 'En línea';

  @override
  String get settingsPageOnlineSubtitle => 'Catálogo y cuenta de YouTube';

  @override
  String get onlineSettingsGroup => 'YouTube';

  @override
  String get settingsYoutubeEnabledTitle => 'YouTube';

  @override
  String get settingsYoutubeEnabledSubtitle =>
      'Muestra la pestaña de YouTube y reproduce música de YouTube. Si desactivas esta opción, la pestaña desaparecerá por completo.';

  @override
  String get settingsYoutubeAccountSubtitle =>
      'Inicia sesión para importar tus listas de reproducción';

  @override
  String get settingsKwOnline => 'youtube,en línea,streaming,cuenta,importar';

  @override
  String get settingsPageSyncTitle => 'Sincronización';

  @override
  String get settingsPageSyncSubtitle =>
      'Sincronización cifrada entre dispositivos';

  @override
  String get settingsPageBackupRestoreTitle =>
      'Copia de seguridad y restauración';

  @override
  String get settingsPageBackupRestoreSubtitle =>
      'Exportaciones, importaciones y copias automáticas';

  @override
  String get settingsPageStorageTitle => 'Almacenamiento';

  @override
  String get settingsPageStorageSubtitle => 'Uso del disco, índices y cachés';

  @override
  String get settingsPageAboutTitle => 'Acerca de';

  @override
  String get settingsPageAboutSubtitle =>
      'Versión, actualizaciones y notas de la versión';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionCreate => 'Crear';

  @override
  String get actionDone => 'Listo';

  @override
  String get actionChange => 'Cambiar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionHide => 'Ocultar';

  @override
  String get actionDeletePermanently => 'Eliminar permanentemente';

  @override
  String get actionBack => 'Atrás';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get playlistNewTitle => 'Nueva lista de reproducción';

  @override
  String get playlistNameHint => 'Nombre de la lista de reproducción';

  @override
  String playlistCreated(Object name) {
    return 'Se creó la lista de reproducción «$name»';
  }

  @override
  String songFavoriteRemoved(Object title) {
    return 'Se quitó $title de favoritos';
  }

  @override
  String songFavoriteAdded(Object title) {
    return 'Se añadió $title a favoritos';
  }

  @override
  String songWillSuggestMore(Object title) {
    return 'Se recomendará $title con más frecuencia';
  }

  @override
  String songWillSuggestLess(Object title) {
    return 'Se recomendará $title con menos frecuencia';
  }

  @override
  String songAddedToNextUp(Object title) {
    return 'Añadido a A continuación: $title';
  }

  @override
  String songShareText(Object artist, Object title) {
    return '$title de $artist';
  }

  @override
  String songAddedToPlaylist(Object name) {
    return 'Añadido a $name';
  }

  @override
  String songRemovedFromPlaylist(Object title) {
    return 'Se quitó $title de la lista de reproducción';
  }

  @override
  String songMovedTo(Object path, Object title) {
    return 'Se movió $title a $path';
  }

  @override
  String songMoveError(Object error) {
    return 'Error al mover la canción: $error';
  }

  @override
  String songRemovedFromLibrary(Object title) {
    return 'Se quitó $title de la biblioteca';
  }

  @override
  String get songDeleteTitle => 'Eliminar canción';

  @override
  String songDeleteConfirm(Object title) {
    return '¿Seguro que quieres eliminar permanentemente «$title» de tu dispositivo? Esta acción no se puede deshacer.';
  }

  @override
  String songDeleted(Object title) {
    return 'Se eliminó $title';
  }

  @override
  String songDeleteError(Object error) {
    return 'Error al eliminar el archivo: $error';
  }

  @override
  String get coverSearching =>
      'Buscando carátulas en Last.fm, Deezer e iTunes...';

  @override
  String get coverNoneFound => 'No se encontraron carátulas faltantes en línea';

  @override
  String coverUpdated(Object source, Object title) {
    return 'Se actualizó la carátula de «$title» ($source)';
  }

  @override
  String get coverDownloadFailed => 'No se pudo descargar la carátula';

  @override
  String coverFetchError(Object error) {
    return 'Error al obtener la carátula: $error';
  }

  @override
  String get metaResultsTitle => 'Resultados de búsqueda de metadatos';

  @override
  String get metaFetchingTitle => 'Buscando metadatos faltantes';

  @override
  String get metaStatUpdated => 'Actualizado';

  @override
  String get metaStatNotFound => 'No encontrado';

  @override
  String get metaStatSkipped => 'Omitido';

  @override
  String get metaUndoAll => 'Deshacer todo';

  @override
  String get metaUndoSong => 'Deshacer para esta canción';

  @override
  String metaRevertedCount(int count) {
    return 'Se revirtieron los cambios de metadatos de $count pistas';
  }

  @override
  String metaViaSource(Object source) {
    return 'mediante $source';
  }

  @override
  String metaMoreItems(int count) {
    return '... y $count más';
  }

  @override
  String get metaCouldNotFind => 'No se pudo encontrar';

  @override
  String get metaUnknownArtist => 'Artista desconocido';

  @override
  String metaAllHaveMetadata(int count) {
    return 'Las $count pistas ya tienen metadatos';
  }

  @override
  String get metaNoMissingMetadata =>
      'No se encontraron pistas con metadatos faltantes';

  @override
  String metaSearchingBatch(int batch) {
    return 'Buscando el lote $batch...';
  }

  @override
  String metaCancelledSummary(int updated, int notFound) {
    return 'Búsqueda de metadatos cancelada ($updated actualizados, $notFound no encontrados)';
  }

  @override
  String get songMenuTitle => 'Opciones de la canción';

  @override
  String get songMenuPlaybackHint =>
      'Acciones de cola, listas y uso compartido';

  @override
  String get songMenuLibraryHint => 'Mover la canción y editar sus metadatos';

  @override
  String get songMenuPersonalize => 'Personalizar';

  @override
  String get songMenuPersonalizeHint =>
      'Ajustes de favoritos y recomendaciones';

  @override
  String get songMenuDanger => 'Zona de peligro';

  @override
  String get songMenuDangerHint =>
      'Quitar de la lista de reproducción o eliminar la canción';

  @override
  String get songMenuPlayNext => 'Reproducir a continuación';

  @override
  String get songMenuPlayNextHint =>
      'Añade la canción para que suene justo después de la actual';

  @override
  String get songMenuAddToPlaylist => 'Añadir a una lista de reproducción';

  @override
  String get songMenuAddToPlaylistHint =>
      'Añadir rápidamente a la lista de reproducción más reciente';

  @override
  String get songMenuAddToNewPlaylist => 'Añadir a una lista nueva';

  @override
  String get songMenuAddToNewPlaylistHint =>
      'Crea una lista de reproducción y añade esta canción';

  @override
  String get songMenuShare => 'Compartir';

  @override
  String get songMenuShareHint =>
      'Compartir el archivo de audio con otras aplicaciones';

  @override
  String get songMenuFetchCover => 'Buscar carátula faltante';

  @override
  String get songMenuFetchCoverHint =>
      'Buscar una carátula en Last.fm, Deezer e iTunes';

  @override
  String get songMenuFetchMetadata => 'Buscar metadatos faltantes';

  @override
  String get songMenuFetchMetadataHint =>
      'Buscar en línea el título, artista, álbum y carátula';

  @override
  String get songMenuMoveToFolder => 'Mover a una carpeta';

  @override
  String get songMenuMoveToFolderHint => 'Mover este archivo a otra carpeta';

  @override
  String get songMenuManagePlaylists => 'Gestionar listas de reproducción';

  @override
  String get songMenuManagePlaylistsHint =>
      'Añadir a listas de reproducción o quitar de ellas';

  @override
  String get songMenuEditMetadata => 'Editar metadatos';

  @override
  String get songMenuEditMetadataHint => 'Abrir el editor de metadatos';

  @override
  String get songMenuRemoveFavorite => 'Quitar de favoritos';

  @override
  String get songMenuAddFavorite => 'Añadir a favoritos';

  @override
  String get songMenuFavoritesHint => 'Ajustar tu lista de canciones favoritas';

  @override
  String get songMenuSuggestMore => 'Recomendar más';

  @override
  String get songMenuSuggestLess => 'Recomendar menos';

  @override
  String get songMenuSuggestHint =>
      'Ajustar la frecuencia con la que se recomienda esta canción';

  @override
  String get songMenuRemoveFromPlaylist => 'Quitar de la lista actual';

  @override
  String get songMenuRemoveFromPlaylistHint =>
      'Conservar el archivo y quitarlo de la lista';

  @override
  String get songMenuRemoveFromLibrary => 'Quitar de la biblioteca';

  @override
  String get songMenuRemoveFromLibraryHint =>
      'Conservar el archivo, pero ocultarlo de la biblioteca';

  @override
  String get songMenuDeleteHint => 'Eliminar el archivo del dispositivo';

  @override
  String get bulkSelected => 'seleccionados';

  @override
  String get bulkSelectAll => 'Seleccionar todo';

  @override
  String get bulkFavorite => 'Añadir a favoritos';

  @override
  String get bulkUnfavorite => 'Quitar de favoritos';

  @override
  String bulkRemovedFromFavorites(int count) {
    return 'Se quitaron $count canciones de favoritos';
  }

  @override
  String bulkAddedToFavorites(int count) {
    return 'Se añadieron $count canciones a favoritos';
  }

  @override
  String get bulkPlaylist => 'Lista de reproducción';

  @override
  String bulkAddedToPlaylist(int count, Object name) {
    return 'Se añadieron $count canciones a $name';
  }

  @override
  String bulkSongsCount(int count) {
    return '$count canciones';
  }

  @override
  String get bulkMetadata => 'Metadatos';

  @override
  String get bulkHideTitle => 'Ocultar canciones';

  @override
  String bulkHideMessage(int count) {
    return '¿Ocultar de la biblioteca las $count canciones seleccionadas?';
  }

  @override
  String get bulkDeleteTitle => 'Eliminar archivos';

  @override
  String bulkDeleteMessage(int count) {
    return '¿Eliminar permanentemente $count archivos del almacenamiento? Esta acción no se puede deshacer.';
  }

  @override
  String bulkAddedToQueue(int count) {
    return 'Se añadieron $count canciones a la cola';
  }

  @override
  String get bulkMove => 'Mover';

  @override
  String bulkMovedTo(int count, Object path) {
    return 'Se movieron $count canciones a $path';
  }

  @override
  String bulkMoveError(Object error) {
    return 'Error al mover las canciones: $error';
  }

  @override
  String bulkWillSuggestMore(int count) {
    return 'Se recomendarán $count canciones con más frecuencia';
  }

  @override
  String bulkWillSuggestLess(int count) {
    return 'Se recomendarán $count canciones con menos frecuencia';
  }

  @override
  String get queueTabUpNext => 'A continuación';

  @override
  String get queueTabHistory => 'Historial';

  @override
  String get queueActionMoveToTop => 'Mover al principio';

  @override
  String get queueActionRemove => 'Quitar';

  @override
  String get queueActionSongOptions => 'Opciones de la canción…';

  @override
  String get queueClearDialogTitle => '¿Vaciar la cola?';

  @override
  String get queueClearDialogMessage =>
      'Se quitarán de la cola actual todas las canciones que están por venir.';

  @override
  String get queueClearAll => 'Vaciar todo';

  @override
  String get queueSectionPlayed => 'Reproducidas';

  @override
  String get queueSectionNowPlaying => 'Reproduciendo ahora';

  @override
  String get queueSectionUpNext => 'A continuación';

  @override
  String get queueSwipeAddToTop => 'Añadir al principio';

  @override
  String get queueShuffleUpcomingTooltip => 'Aleatorizar próximas canciones';

  @override
  String get queueClearUpcomingTooltip => 'Vaciar próximas canciones';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String queueRemainingSuffix(String remaining) {
    return '  ·  $remaining';
  }

  @override
  String get queueEmpty => 'La cola está vacía';

  @override
  String get queueRemoveFromQueueTooltip => 'Quitar de la cola';

  @override
  String get queueRemovedLabel => 'Quitada de la cola';

  @override
  String get queueUndo => 'Deshacer';

  @override
  String get historyClearDialogTitle => '¿Borrar el historial?';

  @override
  String get historyClearDialogMessage =>
      'Se eliminarán todas las instantáneas guardadas de la cola.';

  @override
  String historyRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se restauraron $count pistas',
      one: 'Se restauró 1 pista',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadError => 'No se pudo cargar el historial';

  @override
  String get historyEmptyTitle => 'No hay colas anteriores';

  @override
  String get historyEmptyMessage =>
      'Las colas que reproduces se guardan aquí automáticamente.';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colas guardadas',
      one: '1 cola guardada',
    );
    return '$_temp0';
  }

  @override
  String get historyClearAllTrailing => 'Borrar todo';

  @override
  String get historyDayToday => 'Hoy';

  @override
  String get historyDayYesterday => 'Ayer';

  @override
  String get historyDayThisWeek => 'Esta semana';

  @override
  String get historyDayThisMonth => 'Este mes';

  @override
  String get historyDayEarlier => 'Anteriores';

  @override
  String get snapshotShuffledQueue => 'Cola aleatoria';

  @override
  String get snapshotSavedQueue => 'Cola guardada';

  @override
  String get snapshotEmptyTracks =>
      'Ninguna de estas pistas sigue en tu biblioteca.';

  @override
  String snapshotMoreHidden(int count) {
    return '+$count más';
  }

  @override
  String snapshotMissingCount(int count) {
    return '$count no están en la biblioteca';
  }

  @override
  String get queueMetaSeparator => ' · ';

  @override
  String get songListShuffle => 'Aleatorio';

  @override
  String get songListPlay => 'Reproducir';

  @override
  String get songListPause => 'Pausar';

  @override
  String get songListResume => 'Reanudar';

  @override
  String get songListFetchArtistCover =>
      'Buscar en línea la carátula del artista';

  @override
  String get songListFetchAlbumCover => 'Buscar en línea la carátula del álbum';

  @override
  String get songListFetchCover => 'Buscar carátula en línea';

  @override
  String get songListPlaylistOptions => 'Opciones de la lista de reproducción';

  @override
  String get songListSelectSongsToMerge =>
      'Seleccionar canciones para combinar';

  @override
  String songListMergedSongs(int count) {
    return 'Se combinaron $count canciones';
  }

  @override
  String songListMergeError(Object error) {
    return 'Se produjo un error: $error';
  }

  @override
  String get songListMergeSongs => 'Combinar canciones';

  @override
  String get songListEmpty => 'No hay canciones en esta lista';

  @override
  String get actionRename => 'Cambiar nombre';

  @override
  String get songListRenamePlaylist =>
      'Cambiar nombre de la lista de reproducción';

  @override
  String get songListDeletePlaylist => 'Eliminar lista de reproducción';

  @override
  String songListDeletePlaylistConfirm(Object title) {
    return '¿Seguro que quieres eliminar «$title»?';
  }

  @override
  String songListSearchingArtwork(Object name) {
    return 'Buscando en línea la ilustración de $name...';
  }

  @override
  String songListSelectArtwork(Object name) {
    return 'Seleccionar ilustración para $name';
  }

  @override
  String get songListUseSongCoverGrid =>
      'Usar mosaico de carátulas de canciones';

  @override
  String get songListRemoveCustomArtwork => 'Quitar ilustración personalizada';

  @override
  String get songListChooseCustomImage => 'Elegir imagen personalizada';

  @override
  String get songListSelectFromDevice =>
      'Seleccionar imagen del almacenamiento del dispositivo';

  @override
  String songListArtworkFrom(Object source) {
    return 'Ilustración de $source';
  }

  @override
  String get songListNoOnlineArtwork =>
      'No se encontraron ilustraciones en línea';

  @override
  String get songListResetArtwork =>
      'Restablecer al mosaico de carátulas de canciones';

  @override
  String songListArtworkUpdated(Object name) {
    return 'Se actualizó la ilustración de $name';
  }

  @override
  String get songListDownloadingArtwork => 'Descargando ilustración...';

  @override
  String get songListArtworkDownloadFailed =>
      'No se pudo descargar la ilustración';

  @override
  String get gradientDetailAlbums => 'Álbumes';

  @override
  String get gradientDetailSongs => 'Canciones';

  @override
  String get gradientDetailShowAll => 'Mostrar todo';

  @override
  String gradientDetailAlbumCount(int count) {
    return '$count álbumes';
  }

  @override
  String get syncPlayStats => 'Estadísticas de reproducción';

  @override
  String get syncPlayStatsHint =>
      'Historial de escucha y recuentos de reproducciones';

  @override
  String get syncFavoritesHint => 'Canciones favoritas';

  @override
  String get syncSuggestLess => 'Recomendar menos';

  @override
  String get syncSuggestLessHint =>
      'Canciones que pediste ver con menos frecuencia';

  @override
  String get syncHiddenSongs => 'Canciones ocultas';

  @override
  String get syncPlaylistsHint => 'Todas las listas de reproducción';

  @override
  String get syncMergedSongs => 'Canciones combinadas';

  @override
  String get syncMergedSongsHint => 'Grupos de canciones combinadas';

  @override
  String get syncAppSettings => 'Ajustes de la aplicación';

  @override
  String get syncAppSettingsHint =>
      'Tema, reproducción y preferencias de interfaz';

  @override
  String get syncArtistArt => 'Ilustraciones de artistas';

  @override
  String get syncArtistArtHint => 'Selección de carátulas de artistas en línea';

  @override
  String get syncAlbumArt => 'Ilustraciones de álbumes';

  @override
  String get syncAlbumArtHint => 'Selección de carátulas de álbumes en línea';

  @override
  String get syncQueueHistory => 'Historial de la cola';

  @override
  String get syncQueueHistoryHint => 'Colas reproducidas recientemente';

  @override
  String get syncCurrentQueue => 'Cola actual';

  @override
  String get syncCurrentQueueHint =>
      'Se sube automáticamente; solo se descarga al sincronizar manualmente';

  @override
  String get syncPreferCloudQueue => 'Preferir la cola de la nube';

  @override
  String get syncPreferCloudQueueHint =>
      'Activado: al sincronizar, se reemplaza la cola de este dispositivo por la de la nube. Desactivado: se conserva y sube la cola de este dispositivo.';

  @override
  String get syncPrivacy => 'Privacidad';

  @override
  String get syncEncryptedTitle => 'Cifrado de extremo a extremo';

  @override
  String get syncEncryptedBody =>
      'Tus datos se cifran en este dispositivo antes de subirlos. El servidor solo almacena texto cifrado y no puede leer tu biblioteca, historial ni ajustes.';

  @override
  String get syncRecoveryKeyTitle => 'Clave de recuperación';

  @override
  String get syncRecoveryKeyBody =>
      'Si olvidas la contraseña, solo podrás recuperar el acceso con la clave de recuperación. Nadie más puede hacerlo.';

  @override
  String get syncAccount => 'Cuenta';

  @override
  String get syncSignedIn => 'Sesión iniciada';

  @override
  String get syncConnected => 'Conectado';

  @override
  String get syncLogOut => 'Cerrar sesión';

  @override
  String get syncLogOutBody =>
      'La sincronización se detiene en este dispositivo. Se conservan tanto los datos locales como los de la nube.';

  @override
  String get syncLogOutAndChange => 'Cerrar sesión y cambiar';

  @override
  String get syncCloud => 'Nube';

  @override
  String get syncLastSynced => 'Última sincronización';

  @override
  String get syncNever => 'Nunca';

  @override
  String syncUsedOfQuota(Object used, Object quota) {
    return '$used de $quota usados';
  }

  @override
  String get syncJustNow => 'Ahora mismo';

  @override
  String syncMinutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String syncHoursAgo(int count) {
    return 'hace $count h';
  }

  @override
  String syncDaysAgo(int count) {
    return 'hace $count d';
  }

  @override
  String get syncAutoSync => 'Sincronización automática';

  @override
  String get syncAutoSyncHint =>
      'Sincroniza en segundo plano mientras la aplicación está abierta';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get syncMergeDeviceHint => 'Combinar este dispositivo con la nube';

  @override
  String syncLastError(Object error) {
    return 'Último error: $error';
  }

  @override
  String get syncWhatGetsSynced => 'Qué se sincroniza';

  @override
  String get syncDeviceStatsAttribution =>
      'Atribución de estadísticas del dispositivo';

  @override
  String get syncThisDevice => 'Este dispositivo';

  @override
  String get syncOtherDevices => 'Otros dispositivos';

  @override
  String get syncTotalLibraryStats => 'Estadísticas totales de la biblioteca';

  @override
  String syncPlays(int count) {
    return '$count reproducciones';
  }

  @override
  String get syncDangerZone => 'Zona de peligro';

  @override
  String get syncOverwriteCloudTile =>
      'Reemplazar la nube con este dispositivo';

  @override
  String get syncOverwriteCloudTileHint =>
      'Reemplazar todos los datos de la nube por los de este dispositivo';

  @override
  String get syncReplaceDeviceTile => 'Reemplazar este dispositivo con la nube';

  @override
  String get syncReplaceDeviceTileHint =>
      'Borrar los datos sincronizados de este dispositivo y usar la copia de la nube';

  @override
  String get syncChangePassword => 'Cambiar contraseña';

  @override
  String get syncNewRecoveryKey => 'Nueva clave de recuperación';

  @override
  String get syncNewRecoveryKeyHint =>
      'La clave de recuperación anterior dejará de funcionar';

  @override
  String get syncChangeServer => 'Cambiar servidor';

  @override
  String get syncChangeServerHint => 'Primero debes cerrar sesión';

  @override
  String get syncChangeServerBody =>
      'Primero se cerrará tu sesión en el servidor actual. Los datos locales se conservarán.';

  @override
  String get syncDeleteCloudAccount => 'Eliminar cuenta de la nube';

  @override
  String get syncDeleteCloudAccountHint =>
      'Elimina permanentemente los datos de la nube. Los datos locales se conservan.';

  @override
  String get syncDeleteCloudAccountBody =>
      'Tu cuenta de la nube y todos los datos cifrados del servidor se eliminarán permanentemente. Los datos de este dispositivo se conservarán.';

  @override
  String get syncOverwriteCloud => 'Reemplazar la nube';

  @override
  String get syncOverwriteCloudBody =>
      'Este dispositivo reemplazará todos los datos de la nube. Se pedirá a los demás dispositivos que elijan cómo continuar. Este dispositivo conservará sus datos.';

  @override
  String get syncOverwriteCloudCheckbox =>
      'Entiendo que se perderán los datos de la nube';

  @override
  String get syncOverwrite => 'Reemplazar';

  @override
  String get syncReplaceDevice => 'Reemplazar dispositivo';

  @override
  String get syncReplaceDeviceBody =>
      'Los datos sincronizados de este dispositivo (estadísticas, favoritos, listas de reproducción, etc.) se borrarán y se reemplazarán por la copia de la nube. Los archivos de música no se modificarán.';

  @override
  String get syncReplaceDeviceCheckbox =>
      'Entiendo que se perderán los datos sincronizados locales';

  @override
  String get syncReplace => 'Reemplazar';

  @override
  String get syncCurrentPassword => 'Contraseña actual';

  @override
  String get syncNewPassword => 'Nueva contraseña';

  @override
  String get syncPassword => 'Contraseña';

  @override
  String get syncPasswordChanged => 'Se cambió la contraseña';

  @override
  String get syncGenerate => 'Generar';

  @override
  String get appearanceGroupNowPlaying => 'Reproducción actual';

  @override
  String get appearanceVisualizerTitle => 'Visualizador de audio';

  @override
  String get appearanceVisualizerSubtitle =>
      'Barras sobre la ilustración durante la reproducción: sincronizadas con la canción, con los graves a la izquierda';

  @override
  String get appearanceVisualizerClassic => 'Clásico';

  @override
  String get appearanceVisualizerSynced => 'Sincronizado';

  @override
  String get appearanceProgressBarTitle => 'Estilo de la barra de progreso';

  @override
  String get appearanceProgressBasicSubtitle => 'Barra de progreso sencilla';

  @override
  String get appearanceProgressWaveformSubtitle => 'Forma de onda estática';

  @override
  String get appearanceProgressReactiveSubtitle =>
      'Forma de onda dinámica que reacciona al sonido, con espectro y respuesta al ritmo en tiempo real';

  @override
  String get appearanceProgressStandard => 'Estándar';

  @override
  String get appearanceProgressWaveform => 'Forma de onda';

  @override
  String get appearanceProgressSoundReactive => 'Reactiva al sonido';

  @override
  String get appearanceHapticsTitle =>
      'Respuesta háptica al buscar en la forma de onda';

  @override
  String get appearanceHapticsSubtitle =>
      'Respuesta háptica por cada barra al buscar';

  @override
  String get appearanceCoverSizingTitle => 'Tamaño de carátula del reproductor';

  @override
  String get appearanceCoverSizingSubtitle =>
      'Ajustar automáticamente o conservar la relación de aspecto original';

  @override
  String get appearanceCoverAutoFit => 'Ajustar automáticamente';

  @override
  String get appearanceCoverSourceSize => 'Tamaño original';

  @override
  String get appearanceImmersiveTitle => 'Diseño inmersivo';

  @override
  String get appearanceImmersiveSubtitle =>
      'Carátula a pantalla completa y pantallas de detalles con degradado';

  @override
  String get appearancePlayerSwipeTitle => 'Deslizar para cambiar de panel';

  @override
  String get appearancePlayerSwipeSubtitle =>
      'Desliza a izquierda o derecha para cambiar entre letras, reproductor y cola. Desactiva esta opción para cambiar de canción.';

  @override
  String get appearanceGroupPlayerMotion => 'Movimiento del reproductor';

  @override
  String get appearanceBeatCoverTitle => 'Carátula reactiva al ritmo';

  @override
  String get appearanceBeatCoverUnavailable =>
      'No disponible con el diseño inmersivo activado';

  @override
  String get appearanceBeatCoverSubtitle =>
      'La carátula del álbum late al ritmo de la música';

  @override
  String get appearanceCoverIntensityTitle => 'Intensidad de la carátula';

  @override
  String get appearanceCoverIntensitySubtitle =>
      'Grado de reacción de la carátula';

  @override
  String get appearanceSpinArtworkTitle =>
      'Girar la ilustración durante la reproducción';

  @override
  String get appearanceSpinArtworkSubtitle =>
      'La ilustración gira lentamente en la barra inferior minimizada mientras suena una canción';

  @override
  String get appearanceParticlesTitle => 'Partículas reactivas al ritmo';

  @override
  String get appearanceParticlesSubtitle =>
      'Partículas flotantes que se desplazan y pulsan con la música';

  @override
  String get appearanceParticleDensityTitle => 'Densidad de partículas';

  @override
  String get appearanceParticleDensitySubtitle =>
      'Cantidad y actividad de las partículas';

  @override
  String get appearanceBeatOffsetTitle =>
      'Desfase de sincronización con el ritmo';

  @override
  String get appearanceBeatOffsetNone =>
      'Sin desfase; auméntalo si el pulso parece adelantado';

  @override
  String appearanceBeatOffsetValue(int ms) {
    return '$ms ms';
  }

  @override
  String appearanceBeatOffsetBluetooth(int ms) {
    return '$ms ms (auméntalo para Bluetooth)';
  }

  @override
  String get appearanceCalibrateTitle => 'Calibrar sincronización con el ritmo';

  @override
  String get appearanceCalibrateSubtitle =>
      'Ajusta las partículas a un metrónomo de oído';

  @override
  String get appearanceAppIcon => 'Icono de la aplicación';

  @override
  String get appearanceIntensityMin => 'Mínima';

  @override
  String get appearanceIntensitySubtle => 'Suave';

  @override
  String get appearanceIntensityBalanced => 'Equilibrada';

  @override
  String get appearanceIntensityBold => 'Intensa';

  @override
  String get appearanceIntensityMax => 'Máxima';

  @override
  String get appearanceIntensityCustom => 'Personalizada';

  @override
  String get backupExportAppData => 'Exportar datos de la aplicación';

  @override
  String get backupExportAppDataSubtitle =>
      'Crea una copia de tus estadísticas, favoritos y listas de reproducción';

  @override
  String backupExportFailed(Object error) {
    return 'No se pudieron exportar los datos: $error';
  }

  @override
  String get backupImportAppData => 'Importar datos de la aplicación';

  @override
  String get backupImportAppDataSubtitle =>
      'Restaurar datos desde una copia de seguridad (reemplaza todo)';

  @override
  String get backupManageBackups => 'Gestionar copias de seguridad';

  @override
  String get backupManageBackupsSubtitle =>
      'Crear, restaurar y gestionar copias de seguridad de la aplicación';

  @override
  String get backupAutomaticBackups => 'Copias de seguridad automáticas';

  @override
  String get backupAutoBackup => 'Copia de seguridad automática';

  @override
  String get backupAutoBackupSubtitle =>
      'Frecuencia de las copias de seguridad';

  @override
  String get backupAutoBackupContent => 'Contenido de la copia automática';

  @override
  String get backupAutoBackupContentSubtitle =>
      'Datos incluidos en las copias de seguridad automáticas';

  @override
  String get backupAutoBackupContentDialogSubtitle =>
      'Selecciona el contenido para las copias de seguridad automáticas';

  @override
  String get backupSave => 'Guardar';

  @override
  String get backupAutoDeleteOld => 'Eliminar copias antiguas automáticamente';

  @override
  String get backupAutoDeleteOldSubtitle =>
      'Eliminar copias anteriores a este plazo';

  @override
  String get backupFrequencyDisabled => 'Desactivadas';

  @override
  String get backupFrequencyEvery24Hours => 'Cada 24 horas';

  @override
  String get backupFrequencyEvery48Hours => 'Cada 48 horas';

  @override
  String get backupFrequencyEvery3Days => 'Cada 3 días';

  @override
  String get backupFrequencyEvery7Days => 'Cada 7 días';

  @override
  String backupDeleteAfterDays(int count) {
    return '$count días';
  }

  @override
  String get backupExportOptionsTitle => 'Opciones de exportación';

  @override
  String get backupExportSelectContent =>
      'Selecciona el contenido que quieres exportar:';

  @override
  String get backupContentUserStats => 'Estadísticas de usuario';

  @override
  String get backupContentUserStatsSubtitle =>
      'Recuentos de reproducción, sesiones y estadísticas curiosas';

  @override
  String get backupContentUserData => 'Datos de usuario';

  @override
  String get backupContentUserDataSubtitle =>
      'Favoritos, elementos ocultos y listas de reproducción';

  @override
  String get backupContentUserSettings => 'Ajustes de usuario';

  @override
  String get backupContentUserSettingsSubtitle => 'Tema, orden y preferencias';

  @override
  String get backupContentCoverCacheSubtitle =>
      'Imágenes de carátulas de álbumes';

  @override
  String get backupContentLibraryCacheSubtitle =>
      'Metadatos de canciones en caché';

  @override
  String get backupContentSearchIndexSubtitle => 'Datos del índice de búsqueda';

  @override
  String get backupContentWaveformCacheSubtitle =>
      'Datos de formas de onda de audio';

  @override
  String get backupContentColorCacheSubtitle => 'Temas de color de álbumes';

  @override
  String get backupContentLyricsCacheSubtitle => 'Datos de letras guardados';

  @override
  String get backupCancelUpper => 'CANCELAR';

  @override
  String get backupExportUpper => 'EXPORTAR';

  @override
  String get backupContinueUpper => 'CONTINUAR';

  @override
  String get backupImportDataTitle => 'Importar datos';

  @override
  String get backupImportWarning =>
      'Se reemplazarán TODOS los datos existentes por los datos importados.\n\nSe sobrescribirán tus estadísticas, favoritos, listas de reproducción y ajustes actuales.\n\nEsta acción no se puede deshacer.';

  @override
  String get backupImportingLabel => 'Importando…';

  @override
  String get backupImportingTitle => 'Importando datos';

  @override
  String get backupImportSuccess => '¡Datos importados correctamente!';

  @override
  String backupImportFailed(Object error) {
    return 'No se pudieron importar los datos: $error';
  }

  @override
  String get metadataCoverUpdated => 'La carátula se actualizó correctamente';

  @override
  String metadataPickImageError(Object error) {
    return 'Error al elegir la imagen: $error';
  }

  @override
  String get metadataRemoveCoverTitle => 'Quitar carátula';

  @override
  String get metadataRemoveCoverBody =>
      '¿Seguro que quieres quitar la carátula?';

  @override
  String get metadataRemoveUpper => 'QUITAR';

  @override
  String get metadataCoverRemoved => 'Se quitó la carátula';

  @override
  String metadataRemoveCoverError(Object error) {
    return 'Error al quitar la carátula: $error';
  }

  @override
  String get metadataFixResultTitle =>
      'Resultado de la corrección de miniatura';

  @override
  String get metadataFixReviewBody => 'Revisa los cambios siguientes:';

  @override
  String get metadataFixOriginal => 'Original';

  @override
  String get metadataFixNew => 'Nuevo';

  @override
  String metadataFixNewOption(int n) {
    return 'Nuevo (opción $n)';
  }

  @override
  String get metadataFixSeeAlternatives => 'Ver alternativas';

  @override
  String get metadataFixApply => 'Aplicar';

  @override
  String get metadataFixSuccess => 'La miniatura se corrigió correctamente';

  @override
  String metadataFixError(Object error) {
    return 'Error al corregir la miniatura: $error';
  }

  @override
  String get metadataFixThumbnail => 'Corregir miniatura';

  @override
  String get metadataFixHelpBody =>
      'Esta herramienta mejora automáticamente la carátula del álbum:\n\n1. Detecta y elimina las barras o los bordes negros (habituales en miniaturas de YouTube).\n2. Recorta la imagen para dejarla perfectamente cuadrada (relación 1:1).\n\nEs ideal para convertir miniaturas 16:9 en carátulas de álbum.';

  @override
  String get metadataGotIt => 'Entendido';

  @override
  String get metadataExportCover => 'Exportar carátula';

  @override
  String get metadataExport => 'Exportar';

  @override
  String metadataExportSuccess(Object uri) {
    return 'Carátula exportada a $uri';
  }

  @override
  String metadataExportError(Object error) {
    return 'Error al exportar la carátula: $error';
  }

  @override
  String get metadataReplaceSong => 'Reemplazar canción';

  @override
  String get metadataReplaceHelpBody =>
      'Sustituye el archivo de esta canción por otra copia de la misma canción (mejor extracción, sin pérdida o codificación limpia).\n\nEl historial de reproducción, favoritos, listas de reproducción y fecha de incorporación a la biblioteca se trasladan al archivo nuevo. Se vuelven a leer sus metadatos y lo que falte aparecerá como desconocido.\n\nEl archivo nuevo debe estar fuera de las carpetas de la biblioteca y tener un nombre distinto.';

  @override
  String metadataReplaced(Object filename) {
    return 'Se reemplazó por $filename';
  }

  @override
  String metadataReplaceError(Object error) {
    return 'No se pudo reemplazar el archivo: $error';
  }

  @override
  String metadataReplaceFilesBody(Object oldName, Object newName) {
    return '$oldName\nreemplazado por $newName';
  }

  @override
  String get metadataReplaceOriginalQuestion =>
      '¿Qué quieres hacer con el original?';

  @override
  String get metadataReplaceRejectNoFile => 'No se seleccionó ningún archivo.';

  @override
  String get metadataReplaceRejectUnsupported =>
      'La biblioteca no puede leer ese formato de audio o vídeo.';

  @override
  String get metadataReplaceRejectSameFilename =>
      'El archivo de reemplazo debe tener un nombre distinto. Basta con cambiar la extensión.';

  @override
  String get metadataReplaceRejectInsideLibrary =>
      'Ese archivo está dentro de una de las carpetas de la biblioteca. Elige una copia que esté fuera.';

  @override
  String metadataReplaceRejectDestinationExists(String filename) {
    return 'Ya hay un archivo llamado «$filename» junto al original.';
  }

  @override
  String metadataReplaceRejectLibraryHasName(String filename) {
    return 'Ya hay una canción llamada «$filename» en tu biblioteca.';
  }

  @override
  String get metadataKeepHideUpper => 'CONSERVAR Y OCULTAR';

  @override
  String get metadataDeleteItUpper => 'ELIMINAR';

  @override
  String get metadataSaved => 'Metadatos actualizados correctamente';

  @override
  String metadataSaveError(Object error) {
    return 'Error al guardar los metadatos: $error';
  }

  @override
  String get metadataNoOnlineCover =>
      'No se encontró ninguna carátula en línea';

  @override
  String get metadataSelectCoverTitle => 'Seleccionar carátula';

  @override
  String metadataResultTitleArtist(Object title, Object artist) {
    return '$title - $artist';
  }

  @override
  String metadataSourceLabel(Object source) {
    return 'Fuente: $source';
  }

  @override
  String metadataCoverUpdatedFrom(Object source) {
    return 'Carátula actualizada desde $source';
  }

  @override
  String get metadataNoOnlineMatch =>
      'No se encontraron metadatos coincidentes en línea';

  @override
  String get metadataSelectMatchTitle => 'Seleccionar coincidencia en línea';

  @override
  String metadataResultDetail(Object artist, Object album, Object source) {
    return '$artist · $album ($source)';
  }

  @override
  String metadataLoadedFrom(Object source) {
    return 'Metadatos y carátula cargados desde $source';
  }

  @override
  String metadataFetchError(Object error) {
    return 'Error al obtener los metadatos: $error';
  }

  @override
  String get metadataSectionCover => 'Carátula';

  @override
  String get metadataChangeCover => 'Cambiar carátula';

  @override
  String get metadataWhatDoesThisDo => '¿Qué hace esto?';

  @override
  String get metadataSectionFile => 'Información del archivo';

  @override
  String get metadataFilenameLabel => 'Nombre de archivo (sin extensión)';

  @override
  String get metadataFilenameHelper =>
      'Al cambiar el nombre, se actualizará localmente.';

  @override
  String get metadataSectionSong => 'Metadatos de la canción';

  @override
  String get metadataFetchOnline => 'Buscar en línea';

  @override
  String get metadataTitleLabel => 'Título';

  @override
  String get metadataArtistLabel => 'Artista';

  @override
  String get metadataAlbumLabel => 'Álbum';

  @override
  String get metadataSectionExtra => 'Contenido adicional';

  @override
  String get metadataEditLyrics => 'Editar letras';

  @override
  String get metadataEditLyricsSubtitle => 'Ver o editar las letras insertadas';

  @override
  String get metadataSaveUpper => 'GUARDAR';

  @override
  String metadataLyricsLoadError(Object error) {
    return 'Error al cargar las letras: $error';
  }

  @override
  String metadataLyricsSaveError(Object error) {
    return 'Error al guardar las letras: $error';
  }

  @override
  String get metadataLyricsLoaded =>
      'Letras cargadas: pulsa GUARDAR para aplicarlas';

  @override
  String get metadataSearchOnline => 'Buscar en línea';

  @override
  String get metadataLyricsHint =>
      'Las letras están insertadas en el archivo de audio. Puedes usar marcas de tiempo [mm:ss.xx] para sincronizarlas.';

  @override
  String get metadataLyricsFieldHint => 'Escribe las letras aquí...';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileAvatarFallback => 'U';

  @override
  String get profileDefaultName => 'Usuario';

  @override
  String get appName => 'wispie';

  @override
  String profileAppVersion(String version) {
    return 'wispie v$version';
  }

  @override
  String get profileHidden => 'Oculto';

  @override
  String get profileSuggestLess => 'Recomendar menos';

  @override
  String get profileShuffleSection => 'Reproducción aleatoria';

  @override
  String get profileSmart => 'Aleatorio inteligente';

  @override
  String get profileSmartSubtitle =>
      'Aprende tus gustos, tendencias y contexto';

  @override
  String get profileChangeName => 'Cambiar nombre visible';

  @override
  String get profileNewNameHint => 'Nombre nuevo';

  @override
  String get profileUpdate => 'Actualizar';

  @override
  String get profileNameUpdated => 'Nombre actualizado';

  @override
  String profileCurrentName(String name) {
    return 'Actual: $name';
  }

  @override
  String get profileThemeStorage => 'Tema y almacenamiento';

  @override
  String get profileFamiliar => 'Conocido';

  @override
  String get profileDiscover => 'Descubrir';

  @override
  String get profileFamiliarToDiscover => 'De conocido a descubrimiento';

  @override
  String get storageManageTitle => 'Gestionar almacenamiento';

  @override
  String get storageRepairCardTitle => 'Reparar enlaces de la biblioteca';

  @override
  String get storageRepairCardBody =>
      '¿Faltan carátulas después de restaurar una copia o cambiar de teléfono? Esto vuelve a enlazar las carátulas y las rutas de los archivos.';

  @override
  String get storageRepair => 'Reparar';

  @override
  String get storageRepairTitle => '¿Reparar enlaces de la biblioteca?';

  @override
  String get storageRepairBody =>
      'Esto vuelve a enlazar las carátulas en caché y las rutas de los archivos con su ubicación real en este dispositivo.\n\nLas pistas cuyos archivos ya no estén aquí se quitarán de la biblioteca. Se conservarán los favoritos, las listas de reproducción y los recuentos de reproducción, y se volverán a vincular automáticamente si los archivos regresan.';

  @override
  String storageRepairError(Object error) {
    return 'Error al reparar la biblioteca: $error';
  }

  @override
  String get storageDatabaseTitle => 'Base de datos';

  @override
  String get storageDatabaseSubtitle =>
      'Datos de usuario, estadísticas y ajustes';

  @override
  String get storageCoverCacheTitle => 'Caché de carátulas';

  @override
  String get storageCoverCacheSubtitle => 'Carátulas de canciones en caché';

  @override
  String get storageBackupsTitle => 'Copias de seguridad';

  @override
  String get storageBackupsSubtitle =>
      'Archivos de copias de seguridad locales';

  @override
  String get storageLibraryCacheTitle => 'Caché de la biblioteca';

  @override
  String get storageLibraryCacheSubtitle =>
      'Datos de canciones de la biblioteca en caché';

  @override
  String get storageSearchIndexTitle => 'Índice de búsqueda';

  @override
  String get storageSearchIndexSubtitle => 'Índice para acelerar las búsquedas';

  @override
  String get storageWaveformCacheTitle => 'Caché de formas de onda';

  @override
  String get storageWaveformCacheSubtitle =>
      'Formas de onda de canciones en caché para los visualizadores';

  @override
  String get storageBeatAnalysisTitle => 'Análisis del ritmo';

  @override
  String get storageBeatAnalysisSubtitle =>
      'Mapas de ritmo en caché para el reproductor reactivo';

  @override
  String get storageColorCacheTitle => 'Caché de colores';

  @override
  String get storageColorCacheSubtitle =>
      'Colores de tema extraídos de las carátulas en caché';

  @override
  String get storageLyricsCacheTitle => 'Caché de letras';

  @override
  String get storageLyricsCacheSubtitle =>
      'Disponibilidad y texto de las letras en caché';

  @override
  String get storageOnlineAudioTitle => 'Caché de audio en línea';

  @override
  String get storageOnlineAudioSubtitle =>
      'Pistas en streaming guardadas en el disco para reproducirlas al instante y sin conexión';

  @override
  String get storageClearOnlineAudioTitle =>
      '¿Borrar la caché de audio en línea?';

  @override
  String get storageClearOnlineAudioBody =>
      'Las pistas descargadas volverán a reproducirse en streaming desde Internet. Tu biblioteca, listas de reproducción y favoritos no se modificarán.';

  @override
  String get storageClearOnlineAudioSuccess =>
      'Se borró la caché de audio en línea';

  @override
  String storageClearOnlineAudioError(Object error) {
    return 'Error al borrar la caché de audio en línea: $error';
  }

  @override
  String get storageBlurredCacheTitle => 'Caché de fondos desenfocados';

  @override
  String get storageBlurredCacheSubtitle =>
      'Fondos desenfocados generados previamente';

  @override
  String get storageClearCache => 'Borrar caché';

  @override
  String get storageClearDatabaseTitle => '¿Borrar la base de datos?';

  @override
  String get storageClearDatabaseBody =>
      'Se eliminarán permanentemente todos tus datos, incluidos:\n\n• Todas las listas de reproducción\n• Canciones favoritas y ocultas\n• Estadísticas de reproducción\n• Ajustes y preferencias de la aplicación\n\nLa aplicación se restablecerá. Esta acción no se puede deshacer.';

  @override
  String get storageClearDatabaseAction => 'Borrar base de datos';

  @override
  String storageClearDatabaseError(Object error) {
    return 'Error al borrar la base de datos: $error';
  }

  @override
  String get storageClearCoversTitle => '¿Borrar la caché de carátulas?';

  @override
  String get storageClearCoversBody =>
      'Se eliminarán todas las carátulas de álbumes almacenadas en caché.\n\nLas carátulas volverán a extraerse de tus archivos de música la próxima vez que explores la biblioteca.';

  @override
  String get storageClearCoversAction => 'Borrar carátulas';

  @override
  String get storageClearCoversSuccess => 'Se borró la caché de carátulas';

  @override
  String storageClearCoversError(Object error) {
    return 'Error al borrar las carátulas: $error';
  }

  @override
  String get storageClearBackupsTitle => '¿Borrar las copias de seguridad?';

  @override
  String get storageClearBackupsBody =>
      'Se eliminarán todos los archivos locales de copias de seguridad.\n\nAntes de continuar, asegúrate de haber exportado las copias que quieras conservar.';

  @override
  String get storageClearBackupsAction => 'Borrar copias de seguridad';

  @override
  String get storageClearBackupsSuccess =>
      'Se borraron las copias de seguridad';

  @override
  String storageClearBackupsError(Object error) {
    return 'Error al borrar las copias de seguridad: $error';
  }

  @override
  String get storageClearLibraryTitle => '¿Borrar la caché de la biblioteca?';

  @override
  String get storageClearLibraryBody =>
      'Se borrará la caché de la biblioteca.\n\nLa biblioteca de música se volverá a analizar la próxima vez que abras la aplicación.';

  @override
  String get storageClearLibrarySuccess => 'Se borró la caché de la biblioteca';

  @override
  String storageClearLibraryError(Object error) {
    return 'Error al borrar la caché de la biblioteca: $error';
  }

  @override
  String get storageClearSearchTitle => '¿Borrar el índice de búsqueda?';

  @override
  String get storageClearSearchBody =>
      'Se eliminará el índice de búsqueda.\n\nEl índice se reconstruirá automáticamente al volver a analizar la biblioteca.';

  @override
  String get storageClearSearchAction => 'Borrar índice';

  @override
  String get storageClearSearchSuccess => 'Se borró el índice de búsqueda';

  @override
  String storageClearSearchError(Object error) {
    return 'Error al borrar el índice de búsqueda: $error';
  }

  @override
  String get storageClearWaveformTitle => '¿Borrar la caché de formas de onda?';

  @override
  String get storageClearWaveformBody =>
      'Se eliminarán todas las formas de onda de canciones almacenadas en caché.\n\nLas formas de onda se generarán de nuevo la próxima vez que consultes los detalles de una canción.';

  @override
  String get storageClearWaveformSuccess =>
      'Se borró la caché de formas de onda';

  @override
  String storageClearWaveformError(Object error) {
    return 'Error al borrar la caché de formas de onda: $error';
  }

  @override
  String get storageClearBeatTitle => '¿Borrar el análisis del ritmo?';

  @override
  String get storageClearBeatBody =>
      'Se eliminarán los mapas de ritmo en caché que usa el reproductor reactivo.\n\nSe volverán a generar automáticamente la próxima vez que se reproduzca cada canción.';

  @override
  String get storageClearBeatSuccess =>
      'Se borró la caché de análisis del ritmo';

  @override
  String storageClearBeatError(Object error) {
    return 'Error al borrar la caché de análisis del ritmo: $error';
  }

  @override
  String get storageClearColorTitle => '¿Borrar la caché de colores?';

  @override
  String get storageClearColorBody =>
      'Se eliminarán todos los colores de tema almacenados en caché.\n\nLos colores volverán a extraerse de las carátulas la próxima vez que se reproduzcan las canciones.';

  @override
  String get storageClearColorSuccess => 'Se borró la caché de colores';

  @override
  String storageClearColorError(Object error) {
    return 'Error al borrar la caché de colores: $error';
  }

  @override
  String get storageClearLyricsTitle => '¿Borrar la caché de letras?';

  @override
  String get storageClearLyricsBody =>
      'Se eliminarán las búsquedas de letras almacenadas en caché.\n\nLas letras se volverán a leer de los metadatos de las canciones cuando hagan falta.';

  @override
  String get storageClearLyricsSuccess => 'Se borró la caché de letras';

  @override
  String storageClearLyricsError(Object error) {
    return 'Error al borrar la caché de letras: $error';
  }

  @override
  String get storageClearBlurredTitle =>
      '¿Borrar la caché de fondos desenfocados?';

  @override
  String get storageClearBlurredBody =>
      'Se eliminarán todos los fondos desenfocados generados previamente.\n\nSe volverán a generar la próxima vez que inicies una reconstrucción desde el indexador.';

  @override
  String get storageClearBlurredSuccess =>
      'Se borró la caché de fondos desenfocados';

  @override
  String storageClearBlurredError(Object error) {
    return 'Error al borrar la caché de fondos desenfocados: $error';
  }

  @override
  String get storageClearAllTitle =>
      '¿Borrar todos los datos de la aplicación?';

  @override
  String get storageClearAllBody =>
      'Esta acción es peligrosa y no se puede deshacer.\n\nSe eliminarán permanentemente:\n• Todas tus preferencias y ajustes\n• Estadísticas e historial de reproducción\n• Carátulas de canciones en caché\n• Todas las copias de seguridad locales\n• Caché de la biblioteca\n• Índice de búsqueda\n• Caché de formas de onda\n• Caché de letras\n\nLa aplicación se restablecerá.';

  @override
  String get storageClearAllAction => 'Borrar todo';

  @override
  String storageClearAllError(Object error) {
    return 'Error al borrar los datos: $error';
  }

  @override
  String get storageClearAllTile => 'Borrar todos los datos de usuario';

  @override
  String get storageClearAllTileSubtitle =>
      'Elimina permanentemente todos los datos y restablece la aplicación';

  @override
  String get storageFinalConfirmTitle => 'Confirmación final';

  @override
  String storageConfirmTypePrompt(Object word) {
    return 'Para confirmar, escribe «$word» abajo:';
  }

  @override
  String get storageDeleteKeyword => 'ELIMINAR';

  @override
  String get storageConfirmUpper => 'CONFIRMAR';

  @override
  String get storageTypeExactly =>
      'Escribe exactamente el texto de confirmación.';

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
  String get settingsSearchIndexerSubtitle => 'Reconstruir índices y cachés';

  @override
  String get settingsSearchMusicFoldersTitle => 'Carpetas de música';

  @override
  String get settingsSearchMusicFoldersSubtitle =>
      'Gestionar las carpetas de la biblioteca de música';

  @override
  String get settingsSearchRescanTitle => 'Volver a analizar la biblioteca';

  @override
  String get settingsSearchRescanSubtitle =>
      'Actualizar manualmente todas las canciones del disco';

  @override
  String get settingsSearchIncludeVideosTitle => 'Incluir vídeos';

  @override
  String get settingsSearchIncludeVideosSubtitle =>
      'Mostrar archivos de vídeo en la biblioteca de canciones';

  @override
  String get settingsSearchMinFileSizeTitle => 'Tamaño mínimo de archivo';

  @override
  String get settingsSearchMinFileSizeSubtitle =>
      'Ignorar archivos más pequeños que este valor';

  @override
  String get settingsSearchMinDurationTitle => 'Duración mínima';

  @override
  String get settingsSearchMinDurationSubtitle =>
      'Ignorar pistas más cortas que este valor';

  @override
  String get settingsSearchManageFoldersTitle => 'Gestionar carpetas de música';

  @override
  String get settingsSearchManageFoldersSubtitle =>
      'Añadir, quitar y volver a analizar carpetas individuales';

  @override
  String get settingsSearchPullToRefreshTitle => 'Deslizar para actualizar';

  @override
  String get settingsSearchPullToRefreshSubtitle =>
      'Desliza hacia abajo para actualizar la biblioteca';

  @override
  String get settingsSearchAutoPauseMuteTitle =>
      'Pausar automáticamente al silenciar';

  @override
  String get settingsSearchAutoPauseMuteSubtitle =>
      'Pausar la reproducción cuando el volumen llegue a 0';

  @override
  String get settingsSearchAutoResumeUnmuteTitle =>
      'Reanudar automáticamente al activar el sonido';

  @override
  String get settingsSearchAutoResumeUnmuteSubtitle =>
      'Reanudar la reproducción cuando se restaure el volumen';

  @override
  String get settingsSearchGapTitle => 'Pausa o retraso';

  @override
  String get settingsSearchGapSubtitle => 'Silencio entre pistas';

  @override
  String get settingsSearchFadeOutTitle => 'Fundido de salida';

  @override
  String get settingsSearchFadeOutSubtitle =>
      'Aplicar un fundido a la pista que termina';

  @override
  String get settingsSearchFadeInTitle => 'Fundido de entrada';

  @override
  String get settingsSearchFadeInSubtitle =>
      'Aplicar un fundido a la pista que empieza';

  @override
  String get settingsSearchFadePlayTitle => 'Fundido al reproducir';

  @override
  String get settingsSearchFadePlaySubtitle =>
      'Subir el volumen gradualmente al empezar la reproducción';

  @override
  String get settingsSearchFadePauseTitle => 'Fundido al pausar';

  @override
  String get settingsSearchFadePauseSubtitle =>
      'Bajar el volumen gradualmente al detener la reproducción';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Idioma al que se traducirán las letras';

  @override
  String get settingsSearchTranslationModeSubtitle =>
      'Mostrar texto secundario debajo de las letras o sustituir las letras originales';

  @override
  String get settingsSearchVisualizerSubtitle =>
      'Desactivado, barras clásicas o barras sincronizadas con la canción';

  @override
  String get settingsSearchLanguageSubtitle =>
      'Elegir el idioma de la aplicación';

  @override
  String get settingsSearchProgressBarSubtitle =>
      'Barra estándar, forma de onda o barra reactiva al sonido';

  @override
  String get settingsSearchSongDurationTitle =>
      'Mostrar duración de la canción';

  @override
  String get settingsSearchSongDurationSubtitle =>
      'Mostrar la duración en las listas de canciones';

  @override
  String get settingsSearchAutoHideBarsTitle =>
      'Ocultar barras automáticamente';

  @override
  String get settingsSearchAutoHideBarsSubtitle =>
      'El encabezado y la barra inferior se ocultan al deslizar hacia abajo';

  @override
  String get settingsSearchAppIconSubtitle => 'Elegir el icono que usa wispie';

  @override
  String get settingsSearchBeatCoverSubtitle =>
      'La carátula del álbum late al ritmo de la música (solo en el reproductor clásico)';

  @override
  String get settingsSearchSpinArtworkSubtitle =>
      'La ilustración gira en la barra inferior minimizada mientras suena una canción';

  @override
  String get settingsSearchCoverIntensitySubtitle =>
      'Grado de reacción de la carátula al ritmo';

  @override
  String get settingsSearchParticleDensitySubtitle =>
      'Cantidad y actividad de las partículas';

  @override
  String get settingsSearchBeatOffsetSubtitle =>
      'Compensar la latencia de la salida Bluetooth';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Mostrar recomendaciones rápidas';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Mostrar las colas reproducidas recientemente';

  @override
  String get settingsSearchForYouSubtitle =>
      'Mostrar listas de reproducción recomendadas';

  @override
  String get settingsSearchQuickActionsSubtitle =>
      'Personalizar acciones al mantener pulsado';

  @override
  String get settingsSearchReorderQuickActionsTitle =>
      'Reordenar acciones rápidas';

  @override
  String get settingsSearchReorderQuickActionsSubtitle =>
      'Elegir y ordenar las acciones disponibles al mantener pulsada una canción';

  @override
  String get settingsSearchBulkRenameTitle =>
      'Cambiar el nombre de varios archivos';

  @override
  String get settingsSearchBulkRenameSubtitle =>
      'Cambiar los nombres de toda la biblioteca mediante un formato';

  @override
  String get settingsSearchManageStorageSubtitle =>
      'Uso del disco y gestión de datos';

  @override
  String get settingsSearchBackupsSubtitle =>
      'Explorar, restaurar y eliminar copias de seguridad guardadas';

  @override
  String get settingsSearchStorageUsageSubtitle =>
      'Uso del disco por carátulas, formas de onda, letras y cachés';

  @override
  String get settingsCrumbStorage => 'Ajustes › Almacenamiento';

  @override
  String get settingsCrumbLibrary => 'Ajustes › Biblioteca';

  @override
  String get settingsCrumbLibraryFilters => 'Ajustes › Biblioteca › Filtros';

  @override
  String get settingsCrumbLibraryFolders =>
      'Ajustes › Biblioteca › Carpetas de música';

  @override
  String get settingsCrumbLibraryMaintenance =>
      'Ajustes › Biblioteca › Mantenimiento';

  @override
  String get settingsCrumbPlaybackAudio => 'Ajustes › Reproducción › Audio';

  @override
  String get settingsCrumbPlaybackTransitions =>
      'Ajustes › Reproducción › Transiciones';

  @override
  String get settingsCrumbPlaybackPlayPause =>
      'Ajustes › Reproducción › Reproducir o pausar';

  @override
  String get settingsCrumbLyricsTiming =>
      'Ajustes › Letras › Visualización y sincronización';

  @override
  String get settingsCrumbLyricsTranslation => 'Ajustes › Letras › Traducción';

  @override
  String get settingsCrumbAppearanceLanguage => 'Ajustes › Apariencia › Idioma';

  @override
  String get settingsCrumbAppearanceNowPlaying =>
      'Ajustes › Apariencia › Reproducción actual';

  @override
  String get settingsCrumbAppearanceAppIcon =>
      'Ajustes › Apariencia › Icono de la aplicación';

  @override
  String get settingsCrumbAppearanceMotion =>
      'Ajustes › Apariencia › Movimiento del reproductor';

  @override
  String get settingsCrumbAppearanceLists =>
      'Ajustes › Apariencia › Listas y navegación';

  @override
  String get settingsCrumbHomeLists =>
      'Ajustes › Inicio y navegación › Listas y navegación';

  @override
  String get settingsCrumbHomeScreen =>
      'Ajustes › Inicio y navegación › Pantalla de inicio';

  @override
  String get settingsCrumbBackup =>
      'Ajustes › Copia de seguridad y restauración';

  @override
  String get settingsCrumbAutoBackups =>
      'Ajustes › Copia de seguridad y restauración › Copias automáticas';

  @override
  String get settingsCrumbManageBackups =>
      'Ajustes › Gestión de datos › Gestionar copias de seguridad';

  @override
  String get settingsCrumbManageStorage =>
      'Ajustes › Gestión de datos › Gestionar almacenamiento';

  @override
  String get settingsKwLibrary => 'analizar,carpetas,filtros,canciones';

  @override
  String get settingsKwPlayback => 'audio,sonido,transiciones';

  @override
  String get settingsKwLyrics => 'letras,traducir,karaoke,subtítulos';

  @override
  String get settingsKwHome =>
      'inicio,selecciones rápidas,gestos,barras,diseño';

  @override
  String get settingsKwStorage => 'disco,espacio,caché,indexador,limpieza';

  @override
  String get settingsKwAppearance => 'tema,color,pantalla,aspecto';

  @override
  String get settingsKwSync => 'nube,cuenta,dispositivos,cifrado';

  @override
  String get settingsKwBackup =>
      'copia de seguridad,restaurar,exportar,importar,datos';

  @override
  String get settingsKwIndexer => 'índice,reconstruir,caché,reindexar';

  @override
  String get settingsKwAbout =>
      'versión,actualización,registro de cambios,lanzamiento';

  @override
  String get settingsKwFolders => 'directorio,ruta,añadir carpeta,fuentes';

  @override
  String get settingsKwRescan => 'actualizar,recargar,sincronizar';

  @override
  String get settingsKwVideos => 'vídeo,mp4,clips';

  @override
  String get settingsKwMinFileSize => 'tamaño,omitir,pequeño,filtro';

  @override
  String get settingsKwMinDuration => 'duración,corto,omitir,filtro,interludio';

  @override
  String get settingsKwManageFolders =>
      'carpeta,directorio,almacenamiento,tarjeta SD';

  @override
  String get settingsKwPullToRefresh => 'deslizar,gesto,recargar';

  @override
  String get settingsKwMute => 'volumen,silencio,silenciar';

  @override
  String get settingsKwUnmute => 'volumen,activar sonido,continuar';

  @override
  String get settingsKwGap => 'pausa,silencio,entre,transición';

  @override
  String get settingsKwCrossfade =>
      'fundido cruzado,sin pausas,transición,mezcla';

  @override
  String get settingsKwFadePlay => 'subida,volumen,inicio';

  @override
  String get settingsKwFadePause => 'bajada,volumen,detener';

  @override
  String get settingsKwRichSync =>
      'letras,sincronización avanzada,karaoke,palabras,sincronizar';

  @override
  String get settingsKwSidebar => 'panel lateral,escritorio,cola,letras';

  @override
  String get settingsKwPlayerSwipe =>
      'deslizar,gesto,paneles,letras,cola,omitir,pista';

  @override
  String get settingsKwKeepAwake =>
      'suspensión,bloqueo de pantalla,pantalla,letras';

  @override
  String get settingsKwAutoTranslate =>
      'traducir,traducción,idioma,letras,automático';

  @override
  String get settingsKwTargetLang => 'traducir,idioma,español,inglés,japonés';

  @override
  String get settingsKwTranslationMode =>
      'traducir,modo,texto secundario,sustituir,visualización';

  @override
  String get settingsKwVisualizer =>
      'onda,animación,espectro,barras,sincronización,graves';

  @override
  String get settingsKwLanguage =>
      'idioma,configuración regional,traducción,inglés';

  @override
  String get settingsKwProgressBar =>
      'búsqueda,progreso,onda,reactivo,espectro';

  @override
  String get settingsKwHaptics =>
      'vibrar,háptico,respuesta,forma de onda,deslizar,buscar';

  @override
  String get settingsKwSongDuration => 'duración,tiempo,listas';

  @override
  String get settingsKwAutoHide =>
      'navegación,barra inferior,encabezado,desplazamiento,ocultar';

  @override
  String get settingsKwCoverSizing =>
      'ilustración,carátula,relación de aspecto,recortar';

  @override
  String get settingsKwImmersive =>
      'inmersivo,pantalla completa,reproductor,detalles,degradado,carátula,diseño';

  @override
  String get settingsKwAppIcon =>
      'icono,logotipo,launcher,barra inferior,clásico,nuevo';

  @override
  String get settingsKwBeatCover => 'pulso,ritmo,ilustración,movimiento';

  @override
  String get settingsKwSpinArtwork =>
      'girar,rotar,ilustración,barra inferior,minirreproductor';

  @override
  String get settingsKwBeatParticles => 'partículas,ritmo,movimiento';

  @override
  String get settingsKwCoverIntensity =>
      'carátula,álbum,pulso,sutil,equilibrado,intenso';

  @override
  String get settingsKwParticleDensity =>
      'partículas,densidad,sutil,equilibrado,intenso';

  @override
  String get settingsKwBeatOffset =>
      'bluetooth,latencia,retraso,sincronización,adelantado';

  @override
  String get settingsKwCalibrate =>
      'calibrar,sincronización,latencia,desfase,prueba,metrónomo';

  @override
  String get settingsKwQuickPicks => 'inicio,recomendaciones,sugerencias';

  @override
  String get settingsKwRecentQueues => 'inicio,historial,cola';

  @override
  String get settingsKwForYou => 'inicio,mezclas,recomendaciones';

  @override
  String get settingsKwQuickActions => 'mantener pulsado,menú,accesos directos';

  @override
  String get settingsKwReorderQuickActions =>
      'mantener pulsado,orden,menú,accesos directos';

  @override
  String get settingsKwExport => 'copia de seguridad,guardar,exportar';

  @override
  String get settingsKwImport => 'restaurar,cargar,importar';

  @override
  String get settingsKwManageBackups => 'copia de seguridad,restaurar,eliminar';

  @override
  String get settingsKwBulkRename =>
      'cambiar nombre,nombres de archivo,lote,masivo,formato,nomenclatura';

  @override
  String get settingsKwBatchReplace =>
      'reemplazar,cambiar,mejorar,flac,sin pérdida,lote,comparar,carpeta,duplicado';

  @override
  String get settingsKwManageStorage => 'disco,espacio,caché,limpieza';

  @override
  String get settingsKwBackups => 'copia de seguridad,restaurar,archivo';

  @override
  String get settingsKwStorageUsage => 'disco,espacio,borrar caché,uso';

  @override
  String get settingsKwAutoBackup => 'programación,frecuencia,automático';

  @override
  String get settingsKwAutoBackupContent => 'contenido,categorías,automático';

  @override
  String get settingsKwAutoDelete => 'depurar,limpieza,retención,antiguo';

  @override
  String get setupUnableToAccessFolder =>
      'No se puede acceder a la carpeta seleccionada';

  @override
  String get setupStoragePermissionRequired =>
      'Se necesita permiso de almacenamiento para analizar la biblioteca de música.';

  @override
  String get setupEnterDisplayName => 'Introduce un nombre visible';

  @override
  String setupSetupError(String error) {
    return 'Error de configuración: $error';
  }

  @override
  String get setupIntroTagline => 'Tu música se queda en tu dispositivo.';

  @override
  String get setupGetStarted => 'Empezar';

  @override
  String get setupPreviousStep => 'Paso anterior';

  @override
  String get setupSettingThingsUp => 'Preparando todo';

  @override
  String get setupStartListening => 'Empezar a escuchar';

  @override
  String get setupContinue => 'Continuar';

  @override
  String get setupNameTitle => '¿Cómo te llamas?';

  @override
  String get setupNameSubtitle =>
      'wispie usa tu nombre para saludarte y para identificar tu historial de escucha. En cualquier caso, nada sale de este dispositivo.';

  @override
  String get setupNameHint => 'Tu nombre';

  @override
  String setupGreeting(String name) {
    return 'Encantado de conocerte, $name.';
  }

  @override
  String get setupAppearanceTitle => 'Personaliza la apariencia.';

  @override
  String get setupAppearanceSubtitle =>
      'Todo lo de esta página también está en Ajustes, así que puedes cambiarlo cuando quieras.';

  @override
  String get setupImmersiveSubtitle =>
      'Un reproductor con carátula a pantalla completa y pantallas de detalles con degradado.';

  @override
  String get setupVisualizerSubtitle =>
      'Barras sobre la ilustración mientras escuchas. El visualizador sincronizado sigue la canción en lugar de mostrar un patrón aleatorio.';

  @override
  String get setupBeatCoverSubtitle =>
      'La carátula del álbum pulsa con cada ritmo.';

  @override
  String get setupParticlesSubtitle =>
      'Las partículas se desplazan por el reproductor y cada ritmo las impulsa más lejos en lugar de limitarse a parpadear.';

  @override
  String get setupProgressBarTitle => 'Barra de progreso';

  @override
  String get setupProgressBarSubtitle =>
      'Representa la canción como una forma de onda en lugar de una línea sencilla. El modo reactivo al sonido anima la forma de onda durante la reproducción.';

  @override
  String get setupFoldersTitle => '¿Dónde está tu música?';

  @override
  String get setupFoldersSubtitle =>
      'Indica a wispie en qué carpetas están tus canciones. Solo las lee y puedes añadir tantas carpetas como quieras.';

  @override
  String get setupStoragePermissionTitle => 'Permiso de almacenamiento';

  @override
  String get setupStoragePermissionSubtitle =>
      'wispie lo necesita para encontrar archivos de audio en este dispositivo.';

  @override
  String get setupOpenSystemSettings => 'Abrir ajustes del sistema';

  @override
  String get setupGrantPermission => 'Conceder permiso';

  @override
  String get setupNoFoldersTitle => 'Aún no hay carpetas';

  @override
  String get setupNoFoldersSubtitle =>
      'Añade la carpeta que contiene tus canciones.';

  @override
  String get setupRemoveFolderTooltip => 'Quitar carpeta';

  @override
  String get setupAddFolder => 'Añadir carpeta';

  @override
  String get setupSummaryMusicFolders => 'Carpetas de música';

  @override
  String get setupReadyTitle => 'Todo listo.';

  @override
  String setupReadyTitleNamed(String name) {
    return 'Todo listo, $name.';
  }

  @override
  String get setupReadySubtitle =>
      'Esto es lo que hemos configurado. Puedes cambiarlo cuando quieras desde Ajustes.';

  @override
  String get setupOn => 'Activado';

  @override
  String get setupOff => 'Desactivado';

  @override
  String backupLoadError(Object error) {
    return 'Error al cargar las copias de seguridad: $error';
  }

  @override
  String backupCreated(Object name) {
    return 'Copia de seguridad creada: $name';
  }

  @override
  String backupCreateFailed(Object error) {
    return 'No se pudo crear la copia de seguridad: $error';
  }

  @override
  String backupValidateFailed(Object error) {
    return 'No se pudo validar la copia de seguridad: $error';
  }

  @override
  String get backupReplaceTitle => 'PELIGRO: Reemplazo total de datos';

  @override
  String backupReplaceConfirm(Object name) {
    return '¿Seguro que quieres restaurar la copia $name?';
  }

  @override
  String get backupReplaceWarning =>
      'AVISO: Se REEMPLAZARÁN POR COMPLETO todos tus datos actuales:';

  @override
  String get backupReplaceItemStats =>
      '• Todas tus estadísticas e historial de reproducción actuales';

  @override
  String get backupReplaceItemFavorites =>
      '• Todos tus favoritos y listas de reproducción';

  @override
  String get backupReplaceItemHidden =>
      '• Todas tus canciones ocultas y preferencias';

  @override
  String get backupReplaceItemSettings =>
      '• Todos tus ajustes y estado actuales';

  @override
  String get backupReplaceItemLibrary =>
      '• La biblioteca de canciones analizada';

  @override
  String get backupReplaceRekeyNote =>
      'Después de restaurar, las carátulas de los álbumes y las rutas de los archivos se volverán a vincular automáticamente a este dispositivo. Las pistas de la copia cuyos archivos no estén en este dispositivo se quitarán de la biblioteca.';

  @override
  String get backupReplaceIrreversible =>
      '¡TUS DATOS ACTUALES SE PERDERÁN PERMANENTEMENTE!';

  @override
  String get backupReplaceNoUndo => 'NO hay forma de deshacer esta acción.';

  @override
  String get backupReplaceConfirmAction => 'SÍ, REEMPLAZAR TODO';

  @override
  String get backupRestoringLabel => 'Restaurando datos…';

  @override
  String get backupRestoreSuccess =>
      '¡Se reemplazaron todos los datos correctamente!';

  @override
  String backupRestoreFailed(Object error) {
    return 'No se pudo restaurar la copia de seguridad: $error';
  }

  @override
  String get backupRestoreReloadingLibrary =>
      'Volviendo a cargar la biblioteca…';

  @override
  String get backupRestoreRefreshingPlaylists =>
      'Actualizando listas y mezclas…';

  @override
  String get backupDeleteTitle => 'Eliminar copia de seguridad';

  @override
  String backupDeleteConfirm(Object name) {
    return '¿Seguro que quieres eliminar $name?';
  }

  @override
  String get backupDeleteUpper => 'ELIMINAR';

  @override
  String get backupDeleted => 'Se eliminó la copia de seguridad';

  @override
  String backupDeleteFailed(Object error) {
    return 'No se pudo eliminar la copia de seguridad: $error';
  }

  @override
  String backupExportedTo(Object path) {
    return 'Copia de seguridad exportada a: $path';
  }

  @override
  String get backupNoOlderBackup =>
      'No hay ninguna copia anterior con la que comparar.';

  @override
  String get backupComparing => 'Comparando copias de seguridad...';

  @override
  String backupComparisonTitle(int number) {
    return 'Comparación con n.º $number';
  }

  @override
  String get backupDiffStatsRows => 'Filas de estadísticas';

  @override
  String get backupDiffSize => 'Tamaño';

  @override
  String get backupDiffDataAdded => 'Datos añadidos';

  @override
  String get backupCloseUpper => 'CERRAR';

  @override
  String backupCompareError(Object error) {
    return 'Error al comparar las copias de seguridad: $error';
  }

  @override
  String get backupNoChange => 'Sin cambios';

  @override
  String get backupManagementTitle => 'Gestión de copias de seguridad';

  @override
  String get backupCreating => 'Creando...';

  @override
  String get backupCreateAction => 'Crear copia de seguridad';

  @override
  String get backupEmptyTitle => 'Aún no hay copias de seguridad';

  @override
  String get backupEmptySubtitle =>
      'Crea tu primera copia para proteger tus datos';

  @override
  String backupSizeLabel(Object size) {
    return 'Tamaño: $size';
  }

  @override
  String get backupActionRestore => 'Restaurar';

  @override
  String get backupActionCompare => 'Comparar';

  @override
  String get backupRestartTitle => 'Es necesario reiniciar';

  @override
  String get backupRestartMessage =>
      'La restauración de la copia de seguridad se completó correctamente.\n\nLa aplicación debe reiniciarse para aplicar todos los cambios.';

  @override
  String get backupRestartNow => 'Reiniciar ahora';

  @override
  String get backupSelectContentSubtitle =>
      'Selecciona el contenido para incluir en la copia';

  @override
  String get backupContentArtistArtCache =>
      'Caché de ilustraciones de artistas';

  @override
  String get backupContentAlbumArtCache => 'Caché de carátulas de álbumes';

  @override
  String get backupContentDescUserStats =>
      'Historial de reproducción, estadísticas y grupos de canciones combinadas';

  @override
  String get backupContentDescUserData =>
      'Favoritos, listas de reproducción y preferencias';

  @override
  String get backupContentDescUserSettings =>
      'Tema, orden y preferencias de la aplicación';

  @override
  String get backupContentDescCoverCache => 'Carátulas de álbumes en caché';

  @override
  String get backupContentDescLibraryCache => 'Metadatos en caché';

  @override
  String get backupContentDescSearchIndex => 'Base de datos de búsqueda';

  @override
  String get backupContentDescWaveformCache => 'Datos de formas de onda';

  @override
  String get backupContentDescColorCache => 'Paletas de colores';

  @override
  String get backupContentDescLyricsCache => 'Letras en caché';

  @override
  String get backupContentDescArtistArtCache => 'Imágenes de artistas en caché';

  @override
  String get backupContentDescAlbumArtCache => 'Imágenes de álbumes en caché';

  @override
  String get backupRestoringDataTitle => 'Restaurando datos';

  @override
  String get importSelectTitle => 'Seleccionar datos para restaurar';

  @override
  String get importSectionCache => 'Caché';

  @override
  String get importOptionsTitle => 'Opciones de restauración';

  @override
  String get importReplaceDatabases => 'Reemplazar bases de datos';

  @override
  String get importReplaceDatabasesSubtitle =>
      'Borrar los datos existentes antes de restaurarlos';

  @override
  String get syncEnterPassword => 'Introduce tu contraseña';

  @override
  String syncAuthUnexpectedError(String error) {
    return 'Se produjo un error: $error';
  }

  @override
  String get syncUsernameTaken => 'Ese nombre de usuario ya está en uso';

  @override
  String get syncModeRecover => 'Recuperar';

  @override
  String get syncUsername => 'Nombre de usuario';

  @override
  String get syncEncryptionWarning =>
      'Tus datos están cifrados de extremo a extremo. Si pierdes la contraseña y la clave de recuperación, no será posible recuperarlos.';

  @override
  String get syncSecuringAccount => 'Protegiendo tu cuenta...';

  @override
  String get syncCreateAccount => 'Crear cuenta';

  @override
  String get syncLogIn => 'Iniciar sesión';

  @override
  String get syncRecoverAccount => 'Recuperar cuenta';

  @override
  String get syncHideAdvanced => 'Ocultar opciones avanzadas';

  @override
  String get syncAdvanced => 'Opciones avanzadas';

  @override
  String get syncRecoveryKeySaved => 'Clave de recuperación guardada';

  @override
  String get syncCouldNotSaveFile => 'No se pudo guardar el archivo';

  @override
  String get syncRecoveryKeyRevealTitle => 'Tu clave de recuperación';

  @override
  String get syncRecoveryKeyRevealBody =>
      'Esta es la única forma de recuperar el acceso si olvidas la contraseña. Solo se mostrará una vez. Guárdala en un lugar seguro.';

  @override
  String get syncCopied => 'Copiado';

  @override
  String get syncCopy => 'Copiar';

  @override
  String get syncSaveToFile => 'Guardar en un archivo';

  @override
  String get syncRecoveryKeySavedCheckbox =>
      'He guardado mi clave de recuperación';

  @override
  String get syncUploadTitle => 'Subir los datos de tu biblioteca';

  @override
  String get syncSetupDeviceTitle => 'Configurar este dispositivo';

  @override
  String get syncFreshAccountBody =>
      'La sincronización automática se activará cuando subas tus datos por primera vez.';

  @override
  String get syncChooseDeviceBody =>
      'Elige cómo se incorporará este dispositivo a tus datos de la nube. La sincronización automática se activará después de este paso.';

  @override
  String get syncEverythingNow => 'Sincronizar todo ahora';

  @override
  String get syncMergeWithCloud => 'Combinar este dispositivo con la nube';

  @override
  String get syncSetupNewDevice => 'Configurar como dispositivo nuevo';

  @override
  String get syncMergeExplanation =>
      'Al combinar, se conservan los datos de ambos lados. Si configuras un dispositivo nuevo, primero se borrarán los datos sincronizados de este dispositivo. Es más seguro si ya contiene una copia antigua del mismo historial.';

  @override
  String get syncCloudReplacedTitle => 'Se reemplazaron los datos de la nube';

  @override
  String get syncCloudReplacedBody =>
      'Otro dispositivo reemplazó los datos de la nube. La sincronización está en pausa en este dispositivo hasta que elijas una opción.';

  @override
  String get syncMergeIntoCloud =>
      'Combinar este dispositivo con los nuevos datos de la nube';

  @override
  String get syncPhaseSigningIn => 'Iniciando sesión...';

  @override
  String get syncPhaseCheckingCloud => 'Comprobando la nube...';

  @override
  String get syncPhaseDownloadingBackup => 'Descargando copia de seguridad...';

  @override
  String get syncPhaseApplyingBackup => 'Aplicando copia de seguridad...';

  @override
  String get syncPhaseDownloadingChanges => 'Descargando cambios...';

  @override
  String get syncPhaseMerging => 'Combinando...';

  @override
  String get syncPhasePreparingUpload => 'Preparando la subida...';

  @override
  String get syncPhaseEncrypting => 'Cifrando...';

  @override
  String get syncPhaseUploading => 'Subiendo...';

  @override
  String get syncPhaseFinishing => 'Finalizando...';

  @override
  String get syncPhaseError => 'Error de sincronización';

  @override
  String get syncSyncing => 'Sincronizando...';

  @override
  String syncServerInfo(String name, String version) {
    return '$name - API v$version';
  }

  @override
  String syncServerInfoClosed(String name, String version) {
    return '$name - API v$version - registro cerrado';
  }

  @override
  String get syncServerUnreachable => 'No se pudo conectar con el servidor';

  @override
  String get syncInsecureHttpWarning =>
      'HTTP sin cifrar: úsalo solo en una red privada de confianza';

  @override
  String get syncServerUrl => 'URL del servidor';

  @override
  String get syncChecking => 'Comprobando...';

  @override
  String get syncCheckServer => 'Comprobar servidor';

  @override
  String get syncResetDefault => 'Restablecer valores predeterminados';

  @override
  String get autoBackupRunningTitle => 'Creando copia de seguridad';

  @override
  String get autoBackupRunningSubtitle => 'Creando copia...';

  @override
  String get autoBackupCompleteTitle =>
      'Copia de seguridad automática completada';

  @override
  String get autoBackupSaved => 'Copia de seguridad guardada';

  @override
  String get autoBackupFailedTitle => 'Falló la copia de seguridad automática';

  @override
  String get autoBackupPermissionTitle => 'Se necesita permiso';

  @override
  String get autoBackupPermissionSubtitle =>
      'La copia automática necesita acceso al almacenamiento';

  @override
  String get autoBackupGrant => 'Conceder';

  @override
  String get downgradeTitle => 'Se detectó una versión anterior';

  @override
  String downgradeMessage(String previousVersion, String currentVersion) {
    return 'wispie se abrió por última vez con la versión $previousVersion, pero esta es la $currentVersion. Una versión más reciente podría haber modificado tus datos y esta versión podría dañarlos o perderlos.';
  }

  @override
  String get downgradeQuit => 'Salir';

  @override
  String get downgradeRiskIt => 'Continuar bajo mi responsabilidad';

  @override
  String get indexerSettingsGroupTitle => 'Ajustes del indexador';

  @override
  String get indexerPreventDuplicatesTitle => 'Evitar pistas duplicadas';

  @override
  String get indexerPreventDuplicatesSubtitle =>
      'Ocultar canciones con el mismo nombre de archivo en distintas carpetas';

  @override
  String get indexerExtractFeaturedTitle => 'Extraer artistas invitados';

  @override
  String get indexerExtractFeaturedSubtitle =>
      'Mover los artistas «ft./feat.» del título al campo de artista';

  @override
  String get indexerDatabaseOpsGroupTitle => 'Operaciones de la base de datos';

  @override
  String get indexerWarnRestart =>
      'Esta operación requiere reiniciar la aplicación para aplicar los cambios.';

  @override
  String get indexerCoverSearchGroupTitle => 'Carátulas y búsqueda';

  @override
  String get indexerWarnRepairLinks =>
      'Las pistas cuyos archivos ya no estén en este dispositivo se quitarán de la biblioteca. Se conservarán los favoritos, las listas de reproducción y los recuentos de reproducción, y se volverán a vincular si los archivos regresan.';

  @override
  String get indexerWarnSearchRestart =>
      'Es posible que debas reiniciar la aplicación para que se apliquen todos los cambios en el índice de búsqueda.';

  @override
  String get indexerContentCachesGroupTitle => 'Cachés de contenido';

  @override
  String get indexerRecommendationsGroupTitle => 'Recomendaciones';

  @override
  String get indexerTitle => 'Indexador';

  @override
  String indexerArtistsAlbumsProgress(String artists, String albums) {
    return 'Artistas $artists · Álbumes $albums...';
  }

  @override
  String indexerProcessing(String progress) {
    return 'Procesando $progress...';
  }

  @override
  String get indexerUnknownError => 'Error desconocido';

  @override
  String get indexerCompleted => 'Completado';

  @override
  String indexerCached(int processed, int total) {
    return '$processed/$total en caché';
  }

  @override
  String indexerCachedFailed(int processed, int total, int failed) {
    return '$processed/$total en caché ($failed fallidos)';
  }

  @override
  String get indexerReadyToRebuild => 'Listo para reconstruir';

  @override
  String indexerArtistsOnly(String progress) {
    return 'Artistas $progress';
  }

  @override
  String indexerAlbumsOnly(String progress) {
    return 'Álbumes $progress';
  }

  @override
  String indexerFailedItemsQuestion(int failed) {
    return 'Hay $failed elementos fallidos en esta caché. ¿Qué quieres hacer?';
  }

  @override
  String indexerViewFailed(int failed) {
    return 'Ver $failed fallidos';
  }

  @override
  String get indexerRetryFailed => 'Reintentar fallidos';

  @override
  String get indexerForceRebuild => 'Forzar reconstrucción';

  @override
  String indexerAlreadyCompleteQuestion(int processed, int total) {
    return 'Esta caché ya está completa ($processed/$total). ¿Quieres forzar su reconstrucción?';
  }

  @override
  String get indexerDoIt => 'Hacerlo';

  @override
  String indexerOptimizing(String name) {
    return 'Optimizando $name...';
  }

  @override
  String get indexerDoNotClose => 'No cierres la aplicación';

  @override
  String get indexerRestartRequiredMessage =>
      'La operación se completó correctamente.\n\nLa aplicación debe reiniciarse para aplicar todos los cambios.';

  @override
  String indexerFailedItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos fallidos',
      one: '1 elemento fallido',
    );
    return '$_temp0';
  }

  @override
  String get indexerCouldNotProcess =>
      'No se pudieron procesar los elementos siguientes:';

  @override
  String indexerWarningsTitle(String name) {
    return 'Avisos de $name';
  }

  @override
  String get indexerOk => 'Aceptar';

  @override
  String get indexerJustMissing => 'Solo los que faltan';

  @override
  String get indexerForceAll => 'Forzar todo';

  @override
  String get beatSyncTitle => 'Sincronización con el ritmo';

  @override
  String get beatPlayToCalibrate => 'Reproduce una canción para calibrar.';

  @override
  String get beatAnalyzing => 'Analizando el ritmo...';

  @override
  String get beatNoClearBeat => 'No se detecta un ritmo claro en esta pista.';

  @override
  String get beatDragInstruction =>
      'Arrastra hasta que las partículas estallen al compás.';

  @override
  String beatOffsetMs(int value) {
    return '$value ms';
  }

  @override
  String get beatResetToZero => 'Restablecer a 0 ms';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryFoldersTab => 'Carpetas';

  @override
  String get libraryNoMusicFolderTitle =>
      'Aún no hay ninguna carpeta de música';

  @override
  String get libraryNoMusicFolderMessage =>
      'Selecciona una carpeta de música en Inicio para completar esta sección.';

  @override
  String get libraryFolderErrorTitle => 'No se encontró la carpeta de música';

  @override
  String get libraryLoadErrorTitle => 'No se pudo cargar la biblioteca';

  @override
  String get libraryOpenFolderErrorTitle => 'No se pudo abrir la carpeta';

  @override
  String get libraryNoMatchesTitle => 'No hay coincidencias';

  @override
  String libraryNoMatchesMessage(String query) {
    return 'No hay nada en tu biblioteca que coincida con «$query».';
  }

  @override
  String libraryFolderNoMatchesMessage(String query) {
    return 'No hay nada en esta carpeta que coincida con «$query».';
  }

  @override
  String libraryCollectionNoMatchesMessage(String query) {
    return 'No hay nada aquí que coincida con «$query».';
  }

  @override
  String get libraryFavorites => 'Favoritos';

  @override
  String libraryMergedGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grupos',
      one: '1 grupo',
    );
    return '$_temp0';
  }

  @override
  String get libraryCreateMergeGroupTooltip =>
      'Crear grupo de canciones combinado';

  @override
  String get libraryDeletePlaylist => 'Eliminar lista de reproducción';

  @override
  String get libraryPlaylistOptions => 'Opciones de la lista de reproducción';

  @override
  String get libraryFolderOptions => 'Opciones de carpeta';

  @override
  String get libraryFilterAllHint =>
      'Filtrar carpetas, listas de reproducción, canciones...';

  @override
  String get libraryFilterSongsHint => 'Filtrar carpetas y canciones...';

  @override
  String get libraryFilterCollectionsHint => 'Filtrar artistas y álbumes...';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Todo';

  @override
  String get libraryShuffleFolderTooltip =>
      'Reproducir la carpeta en orden aleatorio';

  @override
  String get libraryNoArtistsTitle => 'Aún no hay artistas';

  @override
  String get libraryNoAlbumsTitle => 'Aún no hay álbumes';

  @override
  String get libraryScanToFillMessage =>
      'Analiza una carpeta de música para completar esta sección.';

  @override
  String get actionClear => 'Borrar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionShuffleAll => 'Reproducir todo en orden aleatorio';

  @override
  String get actionSeeAll => 'Ver todo';

  @override
  String homeQueueCardSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$date · $_temp0';
  }

  @override
  String homePlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return 'Reproduciendo $_temp0';
  }

  @override
  String get homeOpenPlayer => 'Abrir reproductor';

  @override
  String get homePlayNow => 'Reproducir ahora';

  @override
  String homePlayAfterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas sonarán después de la canción actual',
      one: '1 pista sonará después de la canción actual',
    );
    return '$_temp0';
  }

  @override
  String get homePlayAfterCurrent => 'Reproducir después de la canción actual';

  @override
  String get homeSaveToNewPlaylist => 'Guardar en una lista nueva';

  @override
  String get homeUnpin => 'Desfijar';

  @override
  String get homePinRecommendation => 'Fijar recomendación';

  @override
  String get homeRenameRecommendation => 'Cambiar nombre de la recomendación';

  @override
  String get homeRenameRecommendationTitle =>
      'Cambiar nombre de la recomendación';

  @override
  String get homeRemoveRecommendation => 'Quitar recomendación';

  @override
  String get homeRemoveRecommendationTitle => '¿Quitar recomendación?';

  @override
  String homeRemoveRecommendationMessage(String title) {
    return '¿Seguro que quieres quitar «$title»?';
  }

  @override
  String get homeErrorTitle => 'Se produjo un error';

  @override
  String get homeTryAgain => 'Volver a intentarlo';

  @override
  String get homeNoSongsTitle => 'No se encontraron canciones';

  @override
  String get homeNoSongsMessage =>
      'Selecciona tu carpeta de música para empezar a escuchar sin conexión.';

  @override
  String get homeSelectFolder => 'Seleccionar carpeta de música';

  @override
  String get homeQuickPicks => 'Selecciones rápidas';

  @override
  String get homeRecentQueues => 'Colas recientes';

  @override
  String get homePlaylists => 'Tus listas de reproducción';

  @override
  String get homeForYou => 'Para ti';

  @override
  String get mergedTitle => 'Canciones combinadas';

  @override
  String get mergedCreateGroupTooltip => 'Combinar canciones en un grupo';

  @override
  String mergedGroupsTab(int count) {
    return 'Grupos ($count)';
  }

  @override
  String mergedAutoFindTab(int count) {
    return 'Búsqueda automática ($count)';
  }

  @override
  String mergedCreatedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se combinaron $count canciones',
      one: 'Se combinó 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get mergedEmptyTitle => 'Aún no hay canciones combinadas';

  @override
  String get mergedEmptyBody =>
      'Agrupa distintas versiones de una misma canción (remixes, directos o versiones acústicas) para que ocupen un solo lugar al reproducir en orden aleatorio.';

  @override
  String get mergedCreateGroupButton => 'Crear grupo de canciones combinadas';

  @override
  String mergedPrioritySet(String title) {
    return '«$title» se estableció como canción prioritaria';
  }

  @override
  String get mergedPriorityCleared => 'Se quitó la prioridad';

  @override
  String get mergedNoCandidatesTitle =>
      'No se encontraron canciones candidatas';

  @override
  String get mergedNoCandidatesBody =>
      'No se detectaron versiones sin combinar (remixes, directos o versiones acústicas) en tu biblioteca.';

  @override
  String mergedFoundGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se encontraron $count posibles grupos para combinar',
      one: 'Se encontró 1 posible grupo para combinar',
    );
    return '$_temp0';
  }

  @override
  String get mergedMergeAll => 'Combinar todo';

  @override
  String get mergedMergeAllTitle => 'Combinar todas las sugerencias';

  @override
  String mergedMergeAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Crear $count grupos con las versiones de canciones detectadas?',
      one: '¿Crear 1 grupo con las versiones de canciones detectadas?',
    );
    return '$_temp0';
  }

  @override
  String mergedCreatedGroupsSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se crearon $count grupos de canciones combinadas',
      one: 'Se creó 1 grupo de canciones combinadas',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeTitle => 'Separar canción';

  @override
  String mergedUnmergeConfirm(String title) {
    return '¿Quitar «$title» de este grupo?';
  }

  @override
  String get mergedUnmergeAction => 'Separar';

  @override
  String mergedUnmergedSnack(String title) {
    return 'Se separó «$title»';
  }

  @override
  String get mergedDeleteGroupTitle => 'Eliminar grupo de canciones combinadas';

  @override
  String get mergedDeleteGroupConfirm =>
      '¿Separar todas las canciones de este grupo?';

  @override
  String get mergedUnmergeAllAction => 'Separar todo';

  @override
  String get mergedGroupDeleted =>
      'Se eliminó el grupo de canciones combinadas';

  @override
  String get mergedGroupLabel => 'Grupo de canciones combinadas';

  @override
  String mergedVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versiones',
      one: '1 versión',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeAllTooltip => 'Separar todo';

  @override
  String get mergedPriorityBadge => 'Prioritaria';

  @override
  String get mergedPrioritySongTooltip =>
      'Canción prioritaria para el orden aleatorio';

  @override
  String get mergedSetPriorityTooltip => 'Establecer como canción prioritaria';

  @override
  String get mergedUnmergeSongTooltip => 'Separar canción';

  @override
  String mergedSelectedCount(int selected, int total) {
    return '$selected/$total seleccionadas';
  }

  @override
  String get mergedMergeAction => 'Combinar';

  @override
  String get sleepTimerTitle => 'Temporizador de apagado';

  @override
  String get sleepTimerModeLabel => 'Modo del temporizador';

  @override
  String get sleepTimerDurationLabel => 'Duración';

  @override
  String get sleepTimerMinSuffix => 'min';

  @override
  String get sleepTimerTracksLabel => 'Número de pistas';

  @override
  String get sleepTimerLoopTitle => 'Repetir canción actual';

  @override
  String get sleepTimerLoopSubtitle =>
      'Repetir la canción actual durante un tiempo determinado';

  @override
  String get sleepTimerPlayForTimeTitle => 'Reproducir durante un tiempo';

  @override
  String get sleepTimerPlayForTimeSubtitle =>
      'Detener la reproducción después de un tiempo determinado';

  @override
  String get sleepTimerStopAfterCurrentTitle =>
      'Detener al terminar la canción actual';

  @override
  String get sleepTimerStopAfterCurrentSubtitle =>
      'Detener cuando termine la canción actual';

  @override
  String get sleepTimerStopAfterTracksTitle =>
      'Detener después de varias pistas';

  @override
  String get sleepTimerStopAfterTracksSubtitle =>
      'Detener después de reproducir X canciones más';

  @override
  String get sleepTimerNoSong => 'No se está reproduciendo ninguna canción';

  @override
  String get sleepTimerCurrentSongLabel => 'Canción actual';

  @override
  String get sleepTimerLetFinishTitle => 'Dejar que termine la canción actual';

  @override
  String get sleepTimerLetFinishSubtitle =>
      'Esperar a que termine la canción actual antes de detener la reproducción';

  @override
  String get sleepTimerStopImmediatelySubtitle =>
      'Detener inmediatamente al terminar el temporizador';

  @override
  String get sleepTimerStart => 'Iniciar temporizador';

  @override
  String get sleepTimerCancelActive => 'Cancelar temporizador activo';

  @override
  String get sleepTimerCancelled => 'Se canceló el temporizador de apagado';

  @override
  String get sleepTimerFinished => 'Terminó el temporizador de apagado';

  @override
  String sleepTimerLoopingFor(int minutes) {
    return 'Repitiendo la canción actual durante $minutes min';
  }

  @override
  String sleepTimerStopIn(int minutes) {
    return 'La música se detendrá en $minutes min';
  }

  @override
  String get sleepTimerStopAfterCurrent =>
      'Se detendrá al terminar la canción actual';

  @override
  String sleepTimerStopAfterTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se detendrá después de $count canciones más',
      one: 'Se detendrá después de 1 canción más',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchHint => 'Buscar en ajustes';

  @override
  String get settingsValueNone => 'Ninguno';

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
  String get settingsGroupLookAndFeel => 'Aspecto';

  @override
  String get settingsGroupData => 'Datos';

  @override
  String get settingsGroupApp => 'Aplicación';

  @override
  String get settingsGroupFilters => 'Filtros';

  @override
  String get settingsGroupMaintenance => 'Mantenimiento';

  @override
  String get settingsScanningLibrary => 'Analizando la biblioteca…';

  @override
  String settingsResultsFor(String query) {
    return 'Resultados para «$query»';
  }

  @override
  String get settingsNoResultsTitle => 'No se encontraron ajustes';

  @override
  String settingsNoResultsMessage(String query) {
    return 'No hay nada que coincida con «$query».';
  }

  @override
  String get homeSettingsGroupLists => 'Listas y navegación';

  @override
  String get homeSettingsAutoHideBarsSubtitle =>
      'El encabezado y la barra inferior se ocultan al deslizar hacia abajo y vuelven al deslizar hacia arriba';

  @override
  String get homeSettingsGroupHome => 'Pantalla de inicio';

  @override
  String get playbackGroupTransitions => 'Transiciones';

  @override
  String get playbackGroupPlayPause => 'Reproducir o pausar';

  @override
  String get playbackGroupAudio => 'Audio';

  @override
  String get playbackGapOff => 'Pausa o retraso (desactivado)';

  @override
  String get playbackFadeOutOff => 'Fundido de salida (desactivado)';

  @override
  String get playbackFadeInOff => 'Fundido de entrada (desactivado)';

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
  String get bulkRenameTokenCurrentName => 'Nombre actual';

  @override
  String get bulkRenameTokenNumber => 'Número';

  @override
  String get bulkRenameTokenYear => 'Año';

  @override
  String bulkRenameAnalyzeError(String error) {
    return 'No se pudo analizar la biblioteca: $error';
  }

  @override
  String bulkRenameRenameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cambiar el nombre de $count canciones',
      one: 'Cambiar el nombre de 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get bulkRenameConfirmMessage =>
      'Los archivos se renombran en su ubicación. Las estadísticas de reproducción, las listas de reproducción y las ilustraciones en caché se trasladan, y la base de datos se actualiza a medida que se guarda cada archivo.';

  @override
  String get bulkRenameNothingLeft => 'No quedan archivos por renombrar';

  @override
  String get bulkRenamePhaseStarting => 'Iniciando';

  @override
  String get bulkRenameTitle => 'Cambiar nombres en lote';

  @override
  String get bulkRenameFormatArtistTitle => 'Artista - Título';

  @override
  String get bulkRenameFormatArtistAlbumTitle => 'Artista - Álbum - Título';

  @override
  String get bulkRenameCustomSubtitle => 'Tu propia disposición';

  @override
  String get bulkRenameSectionFormat => 'FORMATO';

  @override
  String get bulkRenameSectionArrange => 'ORDEN';

  @override
  String get bulkRenameSectionPreview => 'VISTA PREVIA';

  @override
  String get bulkRenameEmptySegments =>
      'Añade un campo abajo para empezar a crear un nombre.';

  @override
  String get bulkRenameLiteralHint => 'Texto, p. ej., « - »';

  @override
  String get bulkRenameTextChip => 'Texto';

  @override
  String get bulkRenameAnalyzing => 'Analizando la biblioteca';

  @override
  String bulkRenameCountToRename(int count) {
    return '$count por renombrar';
  }

  @override
  String bulkRenameSkippedCount(int count) {
    return '$count omitidas';
  }

  @override
  String bulkRenameAndMore(int count) {
    return 'y $count más';
  }

  @override
  String bulkRenameChecking(int done, int total) {
    return 'Comprobando nombres: $done de $total';
  }

  @override
  String get bulkRenameStop => 'Detener';

  @override
  String get bulkRenameStopping => 'Deteniendo...';

  @override
  String get bulkRenamePleaseWait => 'Espera un momento';

  @override
  String bulkRenameProgressCount(int done, int total) {
    return '$done de $total';
  }

  @override
  String bulkRenameStopped(int count) {
    return 'Se detuvo después de $count canciones. Se trasladaron sus estadísticas e ilustraciones en caché; el resto no se modificó.';
  }

  @override
  String bulkRenameStoppedFailed(int count, int failed) {
    return 'Se detuvo después de $count canciones; no se pudo cambiar el nombre de $failed.';
  }

  @override
  String bulkRenameCompleted(int count) {
    return 'Se cambió el nombre de $count canciones. Se trasladaron las estadísticas y las ilustraciones en caché.';
  }

  @override
  String bulkRenameCompletedFailed(int count, int failed) {
    return 'Se cambió el nombre de $count canciones; no se pudo cambiar el de $failed.';
  }

  @override
  String get bulkRenameFinishedTitle => 'Cambio de nombre finalizado';

  @override
  String get bulkRenameSkipNoTitleText =>
      'No queda texto del título después de limpiar el nombre';

  @override
  String get bulkRenameSkipAlreadyNamed => 'Ya tiene este nombre';

  @override
  String bulkRenameSkipSameNameAs(String filename) {
    return 'Tiene el mismo nombre que «$filename» en esta carpeta';
  }

  @override
  String get bulkRenameSkipAnotherSelected =>
      'Otra canción seleccionada ya tiene ese nombre';

  @override
  String get bulkRenameSkipFileExists => 'Ya existe un archivo con ese nombre';

  @override
  String get shuffleResetDone =>
      'Se restablecieron los ajustes predeterminados';

  @override
  String get shuffleReset => 'Restablecer';

  @override
  String get lyricsGroupDisplayTiming => 'Visualización y sincronización';

  @override
  String get lyricsSimulateWordSyncTitle =>
      'Simular sincronización por palabras';

  @override
  String get lyricsSimulateWordSyncSubtitle =>
      'Generar tiempos por palabra a partir de letras sincronizadas por línea mediante estimación prosódica';

  @override
  String get lyricsDesktopSidebarTitle => 'Panel lateral de letras y cola';

  @override
  String get lyricsDesktopSidebarSubtitle =>
      'Mostrar el control de expansión al pasar el cursor para volver a abrir el panel lateral de letras y cola cuando esté oculto';

  @override
  String get lyricsKeepScreenAwakeTitle =>
      'Mantener la pantalla activa al ver letras';

  @override
  String get lyricsKeepScreenAwakeSubtitle =>
      'Evitar que la pantalla se suspenda mientras está abierto el panel de letras';

  @override
  String get lyricsGroupTranslation => 'Traducción';

  @override
  String get lyricsAutoTranslateTitle => 'Traducir letras automáticamente';

  @override
  String get lyricsAutoTranslateSubtitle =>
      'Traducir las letras automáticamente al idioma seleccionado';

  @override
  String get lyricsTargetLanguageTitle => 'Idioma de destino';

  @override
  String get lyricsTranslationDisplayTitle => 'Visualización de la traducción';

  @override
  String get lyricsTranslationModeReplaceSubtitle =>
      'Sustituir las letras originales';

  @override
  String get lyricsTranslationModeSubtextSubtitle =>
      'Mostrar texto secundario debajo de las letras';

  @override
  String get lyricsModeSubtext => 'Texto secundario debajo';

  @override
  String get lyricsModeReplace => 'Sustituir las originales';

  @override
  String get lyricsTranslateTitle => 'Traducir letras';

  @override
  String get lyricsDisplayMode => 'Modo de visualización';

  @override
  String get lyricsModeSubtextDescription =>
      'Mostrar la traducción debajo de las letras';

  @override
  String get lyricsModeReplaceDescription =>
      'Sustituir por completo las letras originales';

  @override
  String get lyricsAutoTranslateAllTitle =>
      'Traducir todas las canciones automáticamente';

  @override
  String get lyricsAutoTranslateAllSubtitle =>
      'Traducir las letras automáticamente al idioma seleccionado';

  @override
  String get lyricsTargetLanguageLabel => 'Idioma de destino';

  @override
  String get lyricsSearchLanguageHint => 'Buscar idioma...';

  @override
  String get lyricsClearCache => 'Borrar caché';

  @override
  String get lyricsTranslateNow => 'Traducir ahora';

  @override
  String get lyricsFindTitle => 'Buscar letras';

  @override
  String get lyricsNoResults =>
      'No se encontraron letras. Prueba con otro título o artista, o comprueba la conexión.';

  @override
  String lyricsSearchFailed(String error) {
    return 'No se pudieron buscar las letras: $error';
  }

  @override
  String get lyricsInstrumentalWarning =>
      'Marcado como instrumental. Al aplicar el cambio, se borrarán las letras guardadas en el archivo.';

  @override
  String get lyricsApplyUpper => 'APLICAR';

  @override
  String get lyricsPlainText => 'Texto sin formato';

  @override
  String get lyricsUnknownLength => 'Duración desconocida';

  @override
  String lyricsDurationExactMatch(String duration) {
    return '$duration · coincidencia exacta';
  }

  @override
  String get lyricsBadgeWordSync => 'SINCRONIZACIÓN POR PALABRAS';

  @override
  String get lyricsBadgeLineSync => 'SINCRONIZACIÓN POR LÍNEAS';

  @override
  String get lyricsBadgeInstrumental => 'INSTRUMENTAL';

  @override
  String get lyricsBadgePlain => 'SIN FORMATO';

  @override
  String get lyricsSaved => 'Letras guardadas';

  @override
  String lyricsSaveError(Object error) {
    return 'No se pudieron guardar las letras: $error';
  }

  @override
  String get lyricsTranslationCleared => 'Se borró la traducción en caché';

  @override
  String get lyricsAlreadyTranslated =>
      'Las letras ya están en el idioma de destino';

  @override
  String get lyricsTranslated => 'Letras traducidas';

  @override
  String get lyricsTranslateError => 'No se pudieron traducir las letras';

  @override
  String lyricsTranslationFailed(Object error) {
    return 'Falló la traducción: $error';
  }

  @override
  String get lyricsHideTimingTooltip => 'Ocultar sincronización de letras';

  @override
  String get lyricsAdjustTimingTooltip =>
      'Ajustar la sincronización de letras: mantén pulsado para controles de precisión';

  @override
  String get lyricsFindOnline => 'Buscar letras en línea';

  @override
  String get lyricsEmptyTitle => 'No hay letras';

  @override
  String get lyricsEmptySubtitle => 'Esta pista no tiene letras insertadas.';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageGerman => 'Alemán';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get languageChinese => 'Chino';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languagePortuguese => 'Portugués';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageDutch => 'Neerlandés';

  @override
  String get languagePolish => 'Polaco';

  @override
  String get languageTurkish => 'Turco';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get languageUkrainian => 'Ucraniano';

  @override
  String get languageSwedish => 'Sueco';

  @override
  String get languageIndonesian => 'Indonesio';

  @override
  String get languageThai => 'Tailandés';

  @override
  String get languageCzech => 'Checo';

  @override
  String get languageGreek => 'Griego';

  @override
  String get languageHungarian => 'Húngaro';

  @override
  String get languageRomanian => 'Rumano';

  @override
  String get languageDanish => 'Danés';

  @override
  String get languageFinnish => 'Finés';

  @override
  String get languageNorwegian => 'Noruego';

  @override
  String get selectSongsTitle => 'Seleccionar canciones';

  @override
  String get selectSongsWhatIsMerging => '¿Qué significa combinar canciones?';

  @override
  String get selectSongsMergedExplanation =>
      'Las canciones combinadas son versiones distintas de una misma canción:';

  @override
  String get selectSongsBulletVersions =>
      'Por ejemplo, remixes, versiones en directo o versiones con distinta calidad';

  @override
  String get selectSongsBulletFavorites =>
      'Los favoritos y las opciones para recomendar menos se gestionan por canción';

  @override
  String get selectSongsBulletStats =>
      'Tus recuentos de reproducción y estadísticas no cambian';

  @override
  String get selectSongsBulletPriority =>
      'Elige una canción prioritaria para darle preferencia al reproducir en orden aleatorio';

  @override
  String get selectSongsSearchHint => 'Buscar canciones...';

  @override
  String selectSongsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionadas',
      one: '1 seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get selectSongsReadyToMerge => 'Listas para combinar';

  @override
  String get selectSongsPrioritySongTooltip => 'Canción prioritaria';

  @override
  String get selectSongsSetPriorityTooltip => 'Establecer como prioritaria';

  @override
  String get selectSongsPriorityBadge => 'PRIORITARIA';

  @override
  String selectSongsMinSelection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selecciona al menos $count canciones',
      one: 'Selecciona al menos 1 canción',
    );
    return '$_temp0';
  }

  @override
  String selectSongsMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Combinar $count canciones',
      one: 'Combinar 1 canción',
    );
    return '$_temp0';
  }

  @override
  String selectSongsSelectAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seleccionar $count canciones',
      one: 'Seleccionar 1 canción',
    );
    return '$_temp0';
  }

  @override
  String get foldersAddedSnack => 'Se añadió la carpeta de música';

  @override
  String get foldersRemovedSnack => 'Se quitó la carpeta de música';

  @override
  String get foldersSubtitle =>
      'Selecciona las carpetas que contienen tus archivos de música';

  @override
  String get foldersEmptyTitle => 'Aún no se han añadido carpetas';

  @override
  String get foldersEmptyMessage =>
      'Añade una carpeta para crear tu biblioteca.';

  @override
  String get foldersAddButton => 'Añadir carpeta';

  @override
  String get foldersAllFilesGrantedTitle =>
      'Acceso a todos los archivos concedido';

  @override
  String get foldersAllFilesGrantedSubtitle =>
      'wispie puede leer la música de todas las carpetas que añadas.';

  @override
  String get foldersAllFilesMissingTitle =>
      'El acceso a todos los archivos está desactivado';

  @override
  String get foldersAllFilesMissingSubtitle =>
      'Permítelo para que wispie encuentre música fuera de la biblioteca multimedia predeterminada.';

  @override
  String get foldersAllFilesAllowButton =>
      'Permitir acceso a todos los archivos';

  @override
  String get foldersShortcutInternalStorage => 'Almacenamiento interno';

  @override
  String get foldersShortcutMusic => 'Música';

  @override
  String get foldersShortcutDownload => 'Descarga';

  @override
  String get foldersShortcutStorageRoot => 'Raíz del almacenamiento';

  @override
  String get foldersShortcutDownloads => 'Descargas';

  @override
  String get foldersShortcutDocuments => 'Documentos';

  @override
  String get foldersDoesNotExist => 'La carpeta no existe';

  @override
  String get foldersPermissionError =>
      'Permiso denegado o error al leer la carpeta';

  @override
  String get foldersNewFolderTitle => 'Nueva carpeta';

  @override
  String get foldersFolderNameLabel => 'Nombre de la carpeta';

  @override
  String get foldersFolderNameHint => 'Introduce el nombre de la carpeta';

  @override
  String foldersCreateError(String error) {
    return 'Error al crear la carpeta: $error';
  }

  @override
  String get foldersGoUp => '.. (Subir)';

  @override
  String get foldersGoBack => '.. (Volver)';

  @override
  String get foldersNoSubfolders =>
      'No se encontraron subcarpetas.\nSelecciona esta carpeta si contiene tu música.';

  @override
  String get foldersSelectThisFolder => 'Seleccionar esta carpeta';

  @override
  String get foldersSelectDestination => 'Seleccionar carpeta de destino';

  @override
  String get foldersEmptyFolder =>
      'La carpeta está vacía. Puedes seleccionarla abajo.';

  @override
  String foldersSelected(String name) {
    return 'Seleccionada: $name';
  }

  @override
  String get foldersRoot => 'Raíz';

  @override
  String get foldersMoveFolder => 'Mover carpeta';

  @override
  String foldersMovedTo(String name, String path) {
    return 'Se movió $name a $path';
  }

  @override
  String foldersMoveError(String error) {
    return 'Error al mover la carpeta: $error';
  }

  @override
  String get playlistsTitle => 'Listas de reproducción';

  @override
  String get playlistsSearchHint => 'Buscar listas de reproducción...';

  @override
  String get playlistsCreate => 'Crear lista de reproducción';

  @override
  String get playlistsNoMatches =>
      'No se encontraron listas de reproducción coincidentes';

  @override
  String playlistsCreatedOn(String date) {
    return 'Creada $date';
  }

  @override
  String get playlistsCreatedToday => 'hoy';

  @override
  String get playlistsCreatedYesterday => 'ayer';

  @override
  String playlistsDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String playlistsWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count semanas',
      one: 'hace 1 semana',
    );
    return '$_temp0';
  }

  @override
  String get playlistsEmptyTitle => 'Aún no hay listas de reproducción';

  @override
  String get playlistsEmptyMessage =>
      'Crea tu primera lista de reproducción para empezar';

  @override
  String get playlistsNameHint =>
      'Introduce el nombre de la lista de reproducción';

  @override
  String get statsTitle => 'Estadísticas de escucha';

  @override
  String get statsLoadErrorTitle => 'No se pudieron cargar tus estadísticas';

  @override
  String get statsReadingHistory => 'Leyendo tu historial de escucha';

  @override
  String get statsEmptyTitle => 'Aún no hay historial de escucha';

  @override
  String get statsEmptyMessage =>
      'Reproduce algo y aquí aparecerán tus hábitos de escucha.';

  @override
  String get statsSectionOverTime => 'A lo largo del tiempo';

  @override
  String get statsSectionWhen => 'Cuándo escuchas';

  @override
  String get statsSectionTop => 'Tus favoritos';

  @override
  String get statsSectionTaste => 'Tus gustos';

  @override
  String get statsByHour => 'POR HORA';

  @override
  String get statsByWeekday => 'POR DÍA DE LA SEMANA';

  @override
  String get statsNoListening => 'No hay datos de escucha';

  @override
  String statsAcrossPlays(String time, String plays) {
    return '$time en $plays';
  }

  @override
  String statsDayTotals(String time, String plays) {
    return '$time · $plays';
  }

  @override
  String get statsLibraryExplored => 'Biblioteca explorada';

  @override
  String get statsPlaysFavourites => 'Reproducciones de canciones favoritas';

  @override
  String get statsPlaysSkipped => 'Reproducciones omitidas';

  @override
  String get statsAvgPlay => 'DURACIÓN MEDIA DE REPRODUCCIÓN';

  @override
  String get statsOnActiveDay => 'EN UN DÍA ACTIVO';

  @override
  String get statsFirstListen => 'PRIMERA ESCUCHA';

  @override
  String statsShareOf(String share, String count) {
    return '$share de $count';
  }

  @override
  String get statsTopArtists => 'ARTISTAS FAVORITOS';

  @override
  String get statsTopAlbums => 'ÁLBUMES FAVORITOS';

  @override
  String get statsTopTracks => 'CANCIONES FAVORITAS';

  @override
  String get statsTimeListened => 'TIEMPO DE ESCUCHA';

  @override
  String statsRangeWithDays(String range, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días con música',
      one: '1 día con música',
    );
    return '$range · $_temp0';
  }

  @override
  String get statsPlays => 'REPRODUCCIONES';

  @override
  String get statsSkips => 'CANCIONES OMITIDAS';

  @override
  String get statsTracks => 'PISTAS';

  @override
  String get statsStreak => 'RACHA';

  @override
  String statsStreakBest(int count) {
    return 'mejor: $count';
  }

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproducciones',
      one: '1 reproducción',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días activos',
      one: '1 día activo',
    );
    return '$_temp0';
  }

  @override
  String statsSummary(String duration, String plays, String days) {
    return '$duration · $plays · $days';
  }

  @override
  String get statsEmptyHint =>
      'Reproduce algo para empezar a crear tu historial';

  @override
  String get statsLoadError => 'No se pudieron cargar tus estadísticas';

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
  String get statsSameAsBefore => 'igual que antes';

  @override
  String statsHourTickAm(int hour) {
    return '$hour a. m.';
  }

  @override
  String statsHourTickPm(int hour) {
    return '$hour p. m.';
  }

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionRefresh => 'Actualizar';

  @override
  String get sessionDetailTitle => 'Detalles de la sesión';

  @override
  String sessionStartedAt(String time) {
    return 'Empezó a las $time';
  }

  @override
  String get sessionSongSingular => 'Canción';

  @override
  String get sessionSongsPlayed => 'Canciones reproducidas';

  @override
  String get sessionNoSongs => 'No hay canciones registradas';

  @override
  String get sessionRepeatNow => 'Repetir cola ahora';

  @override
  String get sessionNoSongsAvailable =>
      'No hay canciones disponibles para reproducir';

  @override
  String sessionAfterCurrentSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sonarán $count canciones después de la actual',
      one: 'Sonará 1 canción después de la actual',
    );
    return '$_temp0';
  }

  @override
  String sessionPlayingSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reproduciendo $count canciones de esta sesión',
      one: 'Reproduciendo 1 canción de esta sesión',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryTitle => 'Historial de sesiones';

  @override
  String get sessionLoadFailed => 'No se pudieron cargar las sesiones';

  @override
  String get sessionEmptyTitle => 'Aún no hay sesiones';

  @override
  String get sessionEmptyMessage =>
      'Empieza a escuchar música para crear tu historial de sesiones';

  @override
  String get playHistoryTitle => 'Historial de canciones';

  @override
  String get playHistoryEmptyTitle => 'Aún no hay historial de reproducción';

  @override
  String get playHistoryEmptyMessage =>
      'Empieza a escuchar música para crear tu historial.';

  @override
  String get playHistoryListen => 'Escucha';

  @override
  String get playHistorySkip => 'Omisión';

  @override
  String playHistorySummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproducciones',
      one: '1 reproducción',
    );
    return '$_temp0 · $duration';
  }

  @override
  String playHistoryDate(String month, int day, int year) {
    return '$day de $month de $year';
  }

  @override
  String get monthShortJan => 'ene';

  @override
  String get monthShortFeb => 'feb';

  @override
  String get monthShortMar => 'mar';

  @override
  String get monthShortApr => 'abr';

  @override
  String get monthShortMay => 'may';

  @override
  String get monthShortJun => 'jun';

  @override
  String get monthShortJul => 'jul';

  @override
  String get monthShortAug => 'ago';

  @override
  String get monthShortSep => 'sep';

  @override
  String get monthShortOct => 'oct';

  @override
  String get monthShortNov => 'nov';

  @override
  String get monthShortDec => 'dic';

  @override
  String get searchFieldHint => 'Buscar canciones, artistas, álbumes...';

  @override
  String get onlineTab => 'YouTube';

  @override
  String get onlineSearchHint => 'Buscar en YouTube';

  @override
  String get onlineSearchPrompt => 'Buscar pistas en YouTube';

  @override
  String get onlineLoading => 'Buscando en YouTube...';

  @override
  String get onlineNoResults => 'No se encontraron pistas';

  @override
  String get onlineArtistNotFound =>
      'No se encontró ningún artista de YouTube con ese nombre.';

  @override
  String get onlineAlbumNotFound =>
      'No se encontró ningún álbum de YouTube con ese nombre.';

  @override
  String get onlineYoutubeError => 'No se pudo cargar contenido de YouTube.';

  @override
  String get onlineYoutubeErrorNetwork =>
      'No se pudo conectar con YouTube. Comprueba la conexión.';

  @override
  String get onlineYoutubeErrorRateLimited =>
      'YouTube está limitando las solicitudes. Espera un momento e inténtalo de nuevo.';

  @override
  String get onlineYoutubeErrorUnavailable =>
      'Este vídeo no está disponible en YouTube.';

  @override
  String get onlineYoutubeErrorBlocked =>
      'YouTube rechazó esta pista. Prueba con otro resultado.';

  @override
  String get onlineYoutubeErrorResponse =>
      'YouTube devolvió una respuesta inesperada.';

  @override
  String get onlineUnavailable => 'No disponible en línea';

  @override
  String get onlineLibraryAdd => 'Añadir a la biblioteca';

  @override
  String get onlineLibraryRemove => 'Quitar de la biblioteca';

  @override
  String onlineLibraryAdded(String title) {
    return 'Se añadió $title a tu biblioteca';
  }

  @override
  String onlineLibraryRemoved(String title) {
    return 'Se quitó $title de tu biblioteca';
  }

  @override
  String onlineLibraryAddFailed(String title) {
    return 'No se pudo guardar $title en tu biblioteca';
  }

  @override
  String get songMenuLibrarySaveHint =>
      'Conservar esta pista en streaming en tu biblioteca';

  @override
  String get searchEmptyTitle => 'Busca en tu colección de música';

  @override
  String get searchEmptyMessage =>
      'Encuentra canciones, artistas, álbumes y letras.';

  @override
  String get searchFailed => 'No se pudo realizar la búsqueda';

  @override
  String searchNoResults(String query) {
    return 'No se encontraron resultados para «$query»';
  }

  @override
  String get searchNoResultsHint =>
      'Prueba con otras palabras clave o revisa los filtros.';

  @override
  String searchArtistsSection(int count) {
    return 'Artistas ($count)';
  }

  @override
  String searchAlbumsSection(int count) {
    return 'Álbumes ($count)';
  }

  @override
  String searchSongsSection(int count) {
    return 'Canciones ($count)';
  }

  @override
  String searchAlbumSubtitle(String artist, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$artist · $_temp0';
  }

  @override
  String get quickActionSuggestMore => 'Recomendar con más frecuencia';

  @override
  String get quickActionSuggestLess => 'Recomendar con menos frecuencia';

  @override
  String get quickActionGoToAlbum => 'Ir al álbum';

  @override
  String get quickActionGoToArtist => 'Ir al artista';

  @override
  String get aboutChecking => 'Buscando actualizaciones…';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Actualización disponible: $version';
  }

  @override
  String get aboutUpToDate => 'Tienes la versión más reciente';

  @override
  String get aboutCheckForUpdates => 'Buscar actualizaciones';

  @override
  String get aboutCheckingSubtitle =>
      'wispie está comprobando las versiones de GitHub.';

  @override
  String get aboutUpdateAvailableSubtitle =>
      'Hay una versión más reciente disponible en GitHub.';

  @override
  String aboutLatestRelease(String version) {
    return 'Última versión: $version';
  }

  @override
  String get aboutTapToCheck => 'Pulsa abajo para comprobarlo manualmente.';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get aboutUnknown => 'Desconocido';

  @override
  String get aboutCheckNow => 'Comprobar ahora';

  @override
  String get aboutViewRelease => 'Ver versión';

  @override
  String get aboutSupportGroup => 'Ayuda';

  @override
  String get aboutContactTitle => 'Contactar';

  @override
  String get aboutContactSubtitle => 'Problemas, ideas o cualquier otra cosa';

  @override
  String get aboutIssuesTitle => 'Informar de un problema';

  @override
  String get aboutIssuesSubtitle => 'Abre el repositorio de wispie en GitHub';

  @override
  String get aboutLinkFailed => 'No se pudo abrir el enlace';

  @override
  String get aboutDebugGroup => 'Depuración';

  @override
  String get aboutPersistWrites => 'Conservar cambios';

  @override
  String get aboutPersistWritesSubtitle =>
      'Por defecto, las compilaciones de depuración guardan los cambios en una copia temporal. Se aplica al próximo inicio.';

  @override
  String get appIconMoreSoon => 'Próximamente habrá más iconos';

  @override
  String get appIconDesktopNote =>
      'Los lanzadores y gestores de archivos de escritorio mantienen el icono predeterminado; el icono de la ventana y del Dock sigue tu elección.';

  @override
  String get storageSettingsDiskGroup => 'Disco';

  @override
  String get storageSettingsIndexesGroup => 'Índices y cachés';

  @override
  String get shellNavHome => 'Inicio';

  @override
  String get shellSearchTooltip => 'Buscar (Ctrl+K)';

  @override
  String get shellShowSidebar => 'Mostrar panel lateral';

  @override
  String get shellHideSidebar => 'Ocultar panel lateral';

  @override
  String get shellNothingUpNext => 'No hay nada a continuación';

  @override
  String get shellNextInQueue => 'Siguiente en la cola';

  @override
  String get shellPlayNext => 'Reproducir a continuación';

  @override
  String get playerNothingPlaying => 'No hay nada en reproducción';

  @override
  String get playerPanePlayer => 'Reproductor';

  @override
  String get playerPaneQueue => 'Cola';

  @override
  String get playerCloseEsc => 'Cerrar (Esc)';

  @override
  String get playerSongOptions => 'Opciones de la canción';

  @override
  String get playerShowArtwork => 'Mostrar ilustración';

  @override
  String get playerShowVideo => 'Mostrar vídeo';

  @override
  String get drawerQueueHistory => 'Historial de la cola';

  @override
  String get drawerTools => 'Herramientas';

  @override
  String get nowPlayingBarShuffleTooltip =>
      'Reproducción aleatoria (mantén pulsado para generar otra cola)';

  @override
  String get shuffleButtonAfterSong => 'Aleatorio después de la canción actual';

  @override
  String get shuffleButtonAfterQueue => 'Aleatorio después de la cola actual';

  @override
  String shuffleButtonScanningTooltip(String percentage) {
    return 'Analizando la biblioteca ($percentage%)';
  }

  @override
  String shuffleButtonScanningSemantics(String percentage) {
    return 'Analizando la biblioteca: $percentage% completado';
  }

  @override
  String shuffleButtonScanningMessage(String percentage) {
    return 'Analizando la biblioteca: $percentage%';
  }

  @override
  String heartMenuRemoveFromPlaylist(String name) {
    return 'Quitar de $name';
  }

  @override
  String heartMenuRemovedFromPlaylist(String name) {
    return 'Se quitó de $name';
  }

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortTitleAZ => 'Título (A-Z)';

  @override
  String get sortDateAdded => 'Fecha de incorporación';

  @override
  String get sortSongDateOldNew => 'Fecha de la canción (antigua a reciente)';

  @override
  String get sortSongDateNewOld => 'Fecha de la canción (reciente a antigua)';

  @override
  String get sortMostPlayed => 'Más reproducidas';

  @override
  String get sortRecentlyPlayed => 'Reproducidas recientemente';

  @override
  String get sortRecommended => 'Recomendadas';

  @override
  String get searchFilterArtists => 'Artistas';

  @override
  String get playlistDialogAddTo => 'Añadir a...';

  @override
  String get playlistDialogBulkAddTo => 'Añadir varias a...';

  @override
  String get playlistDialogUpdatedSelections => 'Selecciones actualizadas';

  @override
  String get albumCardAllSongs => 'Todas las canciones';

  @override
  String dangerDialogTypeToConfirm(String text) {
    return 'Escribe «$text» para confirmar';
  }

  @override
  String dangerDialogCountdown(String label, int seconds) {
    return '$label ($seconds)';
  }

  @override
  String get appDialogConfirm => 'Confirmar';

  @override
  String get appDialogEnterName => 'Introduce un nombre...';

  @override
  String get transportRepeatOff => 'Repetición desactivada';

  @override
  String get transportRepeatAll => 'Repetir todo';

  @override
  String get transportRepeatOne => 'Repetir una';

  @override
  String durationSongsWithTotal(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
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
    return 'contiene «$line»';
  }

  @override
  String get lyricsMatchPrefix => 'contiene «';

  @override
  String get lyricsMatchAvailable => 'Letras disponibles';

  @override
  String get lyricsResumeSync => 'Reanudar sincronización';

  @override
  String get lyricsTimingTitle => 'Sincronización de letras';

  @override
  String get lyricsTimingLater => 'Más tarde';

  @override
  String get lyricsTimingSyncToLine => 'Sincronizar con esta línea';

  @override
  String get lyricsTimingReset => 'Restablecer sincronización';

  @override
  String lyricsTimingSnapped(String value) {
    return 'Ajustado a $value';
  }

  @override
  String get lyricsTimingRangeLabel =>
      'Intervalo (hasta 60 s en cualquier dirección)';

  @override
  String get lyricsTimingFineLabel =>
      'Ajuste fino (5 s a cada lado, pasos de 0,01 s)';

  @override
  String get lyricsTimingResetTooltip =>
      'Toca dos veces para restablecer a 0,00';

  @override
  String get quickActionsTitle => 'Acciones rápidas';

  @override
  String get quickActionsResetDone =>
      'Restablecidas las opciones predeterminadas';

  @override
  String quickActionsEnabledHeader(int count) {
    return 'ACTIVADAS ($count)';
  }

  @override
  String quickActionsDisabledHeader(int count) {
    return 'DESACTIVADAS ($count)';
  }

  @override
  String get quickActionsGoToAlbum => 'Ir al álbum';

  @override
  String get quickActionsGoToArtist => 'Ir al artista';

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String get updateCurrentLabel => 'Actual';

  @override
  String get updateAvailableBody =>
      'Hay una nueva versión de wispie lista para descargar.';

  @override
  String get updateSkipVersion => 'Omitir esta versión';

  @override
  String get updateWhatsNew => '¿Qué novedades hay?';

  @override
  String get externalOpenAddToLibrary => 'Añadir a la biblioteca';

  @override
  String get externalOpenDismiss => 'Descartar';

  @override
  String get wideTrackTime => 'Tiempo';

  @override
  String get floatingDockNext => 'Siguiente';

  @override
  String get barSeekLabel => 'Buscar';

  @override
  String get indexerOpOptimizeDatabasesTitle => 'Optimizar bases de datos';

  @override
  String get indexerOpOptimizeDatabasesDesc =>
      'Limpiar y optimizar todas las bases de datos de la aplicación';

  @override
  String get indexerOpRepairLinksTitle => 'Reparar enlaces de la biblioteca';

  @override
  String get indexerOpRepairLinksDesc =>
      'Volver a enlazar las carátulas y las rutas de archivos después de restaurar una copia o cambiar de dispositivo';

  @override
  String get indexerOpMatchIdentityTitle => 'Identificar canciones por audio';

  @override
  String get indexerOpMatchIdentityDesc =>
      'Crear una huella de cada archivo para que las canciones renombradas conserven sus favoritos, listas de reproducción y estadísticas, y puedan identificarse entre dispositivos sincronizados';

  @override
  String get indexerOpCoverCacheTitle => 'Reconstruir cachés de carátulas';

  @override
  String get indexerOpCoverCacheDesc =>
      'Extraer y guardar en caché las carátulas insertadas en los archivos';

  @override
  String get indexerOpSearchIndexTitle => 'Reconstruir índices de búsqueda';

  @override
  String get indexerOpSearchIndexDesc =>
      'Reconstruir el índice de búsqueda de todas las canciones';

  @override
  String get indexerOpLyricsCacheTitle => 'Reconstruir caché de letras';

  @override
  String get indexerOpLyricsCacheDesc =>
      'Extraer y guardar en caché las letras de todas las canciones';

  @override
  String get indexerOpWaveformCacheTitle =>
      'Reconstruir caché de formas de onda';

  @override
  String get indexerOpWaveformCacheDesc =>
      'Generar datos de formas de onda para todas las canciones';

  @override
  String get indexerOpColorCacheTitle =>
      'Reconstruir temas de la aplicación desde las carátulas';

  @override
  String get indexerOpColorCacheDesc =>
      'Extraer temas de color de todas las carátulas';

  @override
  String get indexerOpBlurredCacheTitle =>
      'Reconstruir caché de fondos desenfocados';

  @override
  String get indexerOpBlurredCacheDesc =>
      'Generar previamente fondos desenfocados optimizados';

  @override
  String get indexerOpRecommendationsTitle => 'Reconstruir recomendaciones';

  @override
  String get indexerOpRecommendationsDesc =>
      'Forzar la reconstrucción de todas las listas de reproducción recomendadas';

  @override
  String get indexerOpArtistAlbumArtTitle =>
      'Buscar carátulas de artistas y álbumes';

  @override
  String get indexerOpArtistAlbumArtDesc =>
      'Buscar en línea las carátulas que faltan de artistas y álbumes, empezando por las colecciones más grandes';

  @override
  String get indexerCounting => 'Contando...';

  @override
  String get indexerWorking => 'Procesando...';

  @override
  String get indexerStopping => 'Deteniendo...';

  @override
  String indexerProgressPercent(int percent) {
    return 'Procesando $percent%';
  }

  @override
  String indexerProgressFailed(int done, int total, int failed) {
    return 'Procesando $done/$total ($failed fallidos)';
  }

  @override
  String indexerStoppedAt(int done, int total) {
    return 'Se detuvo en $done/$total';
  }

  @override
  String indexerFinished(int processed, int failed) {
    return 'Listo: $processed procesados, $failed fallidos';
  }

  @override
  String get indexerNothingToDo => 'No hay nada que hacer; ya está actualizado';

  @override
  String get indexerErrorBusy => 'Ya se está ejecutando en segundo plano';

  @override
  String get indexerErrorOffline =>
      'Se perdió la conexión; el resto se reanudará automáticamente';

  @override
  String get indexerStop => 'Detener';

  @override
  String get youtubeAccountTitle => 'Cuenta de YouTube';

  @override
  String get youtubeAccountLoading => 'Cargando tu cuenta de YouTube...';

  @override
  String get youtubeAccountSignedOutTitle => 'Trae aquí tus listas de YouTube';

  @override
  String get youtubeAccountSignedOutBody =>
      'Inicia sesión para importar tus listas de YouTube a esta biblioteca. Puedes buscar, reproducir, marcar favoritos y consultar estadísticas de escucha sin una cuenta.';

  @override
  String get youtubeAccountSignIn => 'Iniciar sesión con Google';

  @override
  String get youtubeAccountSignInTryWeb =>
      'Probar el inicio de sesión en la aplicación';

  @override
  String get youtubeAccountSignInHint =>
      'Abre la página de inicio de sesión de Google dentro de la aplicación. Wispie conserva la sesión de YouTube en este dispositivo y nunca ve tu contraseña.';

  @override
  String get youtubeAccountSignInHintManual =>
      'Inicia sesión en YouTube desde un navegador y luego importa las cookies de sesión desde la pantalla de cuenta: puedes pegar un encabezado Cookie, un archivo cookies.txt o un JSON de cookies. Las cookies se guardan en este dispositivo y son lo único que necesita wispie.';

  @override
  String get youtubeAccountWebTitle => 'Inicio de sesión de Google';

  @override
  String get youtubeAccountWebTrouble =>
      '¿Problemas para iniciar sesión? Usa las cookies';

  @override
  String get youtubeAccountWebTroubleAction => 'Usar cookies';

  @override
  String get youtubeAccountWebFailed =>
      'No se pudo cargar la página. Comprueba la conexión o usa las cookies.';

  @override
  String get youtubeAccountWebUnsupported =>
      'Esta plataforma no tiene navegador integrado.';

  @override
  String get youtubeAccountWebBlockedTitle =>
      'Google bloqueó el inicio de sesión integrado';

  @override
  String get youtubeAccountWebBlockedBody =>
      'Google no permite iniciar sesión desde otras aplicaciones, así que no se puede aceptar una contraseña escrita aquí. Inicia sesión en YouTube desde el navegador e importa las cookies de sesión en la pantalla de cuenta: el resultado es el mismo y nunca tendrás que escribir la contraseña en wispie.';

  @override
  String get youtubeAccountWebPasskeyTitle =>
      'Google solicita una llave de acceso';

  @override
  String get youtubeAccountWebPasskeyBody =>
      'No se puede usar una llave de acceso desde otra aplicación, por lo que no es posible completar ese paso aquí. Inicia sesión con tu contraseña; el resto del proceso funcionará con normalidad.';

  @override
  String get youtubeAccountWebPasskeyAction => 'Usar mi contraseña';

  @override
  String get youtubeAccountOpenYouTube => 'Abrir youtube.com';

  @override
  String get youtubeSearchSongs => 'Canciones';

  @override
  String get youtubeSearchAlbums => 'Álbumes';

  @override
  String get youtubeSearchPlaylists => 'Listas de reproducción';

  @override
  String get youtubeSearchArtists => 'Artistas';

  @override
  String get youtubeArtistSongsTitle => 'Canciones principales';

  @override
  String get youtubeArtistAlbumsTitle => 'Álbumes y sencillos';

  @override
  String get youtubeCollectionEmpty => 'No hay nada que reproducir aquí.';

  @override
  String get youtubeAccountSignOut => 'Cerrar sesión';

  @override
  String youtubeAccountSignedInAs(String name) {
    return 'Sesión iniciada como $name';
  }

  @override
  String get youtubeAccountSessionExpired =>
      'Tu sesión de YouTube ha caducado. Vuelve a iniciar sesión para seguir sincronizando las listas.';

  @override
  String get youtubeAccountCookiesTitle => 'Pegar cookies de YouTube';

  @override
  String get youtubeAccountCookiesBody =>
      'Inicia sesión en YouTube desde un navegador y copia el encabezado de solicitud Cookie de cualquier petición a youtube.com (herramientas de desarrollador: Red -> Encabezados), o exporta un archivo cookies.txt y pégalo aquí. Solo se conservarán las cookies de youtube.com.';

  @override
  String get youtubeAccountCookiesHint =>
      'Encabezado Cookie, cookies.txt o JSON de cookies exportado';

  @override
  String get youtubeAccountCookiesImport => 'Importar cookies';

  @override
  String get youtubeAccountCookiesFile => 'Elegir archivo cookies.txt';

  @override
  String get youtubeAccountCookiesEmpty =>
      'No se encontraron cookies en ese texto.';

  @override
  String get youtubeAccountCookiesUnreadable => 'No se pudo leer ese archivo.';

  @override
  String get youtubeAccountPlaylistsTitle => 'Tus listas de reproducción';

  @override
  String get youtubeFeedForYou => 'Para ti';

  @override
  String get youtubeFeedFromLibrary => 'De los artistas que escuchas';

  @override
  String get youtubeFeedFilterPlaylists => 'Elegir listas de reproducción';

  @override
  String get youtubeFeedPlaylistsHidden =>
      'Todas las listas de reproducción están ocultas en esta pestaña.';

  @override
  String get youtubeFeedPlaylists => 'Tus listas de reproducción';

  @override
  String get youtubeFeedSignInTitle => 'Inicia sesión para ver tu feed';

  @override
  String get youtubeFeedSignInBody =>
      'Tu feed de inicio de YouTube se basa en lo que ves y en los canales a los que te suscribes. Si inicias sesión, también podrás previsualizar e importar tus listas de reproducción.';

  @override
  String get youtubeFeedSignInAction => 'Iniciar sesión';

  @override
  String get youtubeFeedEmpty => 'Aún no hay nada aquí. Busca algo arriba.';

  @override
  String get youtubePreviewEmpty =>
      'Esta lista de reproducción no tiene pistas reproducibles.';

  @override
  String get youtubePreviewPlayAll => 'Reproducir todo';

  @override
  String get youtubeAccountLikedVideos => 'Vídeos que te gustan';

  @override
  String youtubeAccountPlaylistTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
      zero: 'No hay pistas',
    );
    return '$_temp0';
  }

  @override
  String get youtubeAccountImport => 'Importar';

  @override
  String get youtubeAccountSync => 'Sincronizar';

  @override
  String get youtubeAccountSyncAll => 'Sincronizar todas las listas importadas';

  @override
  String get youtubeAccountSyncHint =>
      'La sincronización solo añade pistas. Nunca se quita nada de tus listas de reproducción.';

  @override
  String youtubeAccountImportDone(int count, String name) {
    return 'Se importaron $count pistas de $name';
  }

  @override
  String youtubeAccountSyncDone(int count, String name) {
    return 'Se añadieron $count pistas nuevas a $name';
  }

  @override
  String youtubeAccountSyncUpToDate(String name) {
    return '$name está actualizado';
  }

  @override
  String youtubeAccountSyncLimited(int count) {
    return 'Solo se añadieron las primeras $count pistas nuevas. Vuelve a sincronizar para añadir el resto.';
  }

  @override
  String get youtubeAccountPlaylistEmpty =>
      'Esa lista de reproducción no tiene pistas reproducibles.';

  @override
  String get youtubeAccountLoadFailed =>
      'No se pudieron cargar tus listas de reproducción.';

  @override
  String get youtubeAccountTryAgain => 'Volver a intentarlo';

  @override
  String get youtubeAccountErrorNetwork =>
      'No se pudo conectar con YouTube. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get youtubeAccountErrorUnauthorized =>
      'Tu sesión de YouTube ya no es válida. Inicia sesión de nuevo.';

  @override
  String get youtubeAccountErrorResponse =>
      'YouTube devolvió una respuesta inesperada.';

  @override
  String get youtubeAccountErrorRateLimited =>
      'YouTube está limitando las solicitudes ahora mismo. Vuelve a intentarlo en unos minutos.';

  @override
  String get youtubeAccountErrorStorage =>
      'No se pudo guardar la sesión de forma segura en este dispositivo.';

  @override
  String get youtubeAccountErrorGeneric =>
      'No se pudo acceder a tu cuenta de YouTube.';

  @override
  String get playlistSyncFromYoutube => 'Sincronizar desde YouTube';

  @override
  String get playlistYoutubeBadge => 'YouTube';

  @override
  String get batchReplaceTitle => 'Reemplazo en lote';

  @override
  String get batchReplaceIntro =>
      'Elige una carpeta para compararla con tu biblioteca. Se propondrá reemplazar las canciones cuyos archivos coincidan.';

  @override
  String get batchReplaceFolderLabel => 'Carpeta para comparar';

  @override
  String get batchReplaceNoFolder => 'No se ha seleccionado ninguna carpeta';

  @override
  String get batchReplaceChooseFolder => 'Elegir carpeta';

  @override
  String get batchReplaceChangeFolder => 'Cambiar';

  @override
  String get batchReplaceSubfolders => 'Incluir subcarpetas';

  @override
  String get batchReplaceInsideLibrary =>
      'Esa carpeta ya forma parte de tu biblioteca. Elige una carpeta externa.';

  @override
  String get batchReplacePhaseListing => 'Enumerando archivos';

  @override
  String get batchReplacePhaseReading => 'Leyendo etiquetas';

  @override
  String get batchReplacePhaseReplacing => 'Reemplazando canciones';

  @override
  String get batchReplaceStopping => 'Deteniendo';

  @override
  String batchReplaceCompareError(Object error) {
    return 'No se pudo comparar esa carpeta: $error';
  }

  @override
  String batchReplaceMatched(int count) {
    return 'Coincidieron $count canciones';
  }

  @override
  String batchReplaceCompared(int files, int songs) {
    return 'Se compararon $files archivos con $songs canciones de la biblioteca';
  }

  @override
  String get batchReplaceSelectAll => 'Seleccionar todo';

  @override
  String get batchReplaceSelectNone => 'No seleccionar nada';

  @override
  String batchReplaceConfidence(int percent) {
    return '$percent%';
  }

  @override
  String get batchReplaceSignalTitle => 'Título';

  @override
  String get batchReplaceSignalFilename => 'Nombre del archivo';

  @override
  String get batchReplaceSignalArtist => 'Artista';

  @override
  String get batchReplaceSignalAlbum => 'Álbum';

  @override
  String get batchReplaceSignalDuration => 'Duración';

  @override
  String get batchReplaceLengthDiffers => 'la duración es distinta';

  @override
  String batchReplaceUnmatched(int count) {
    return 'Ninguna canción coincidió con $count archivos';
  }

  @override
  String batchReplaceAndMore(int count) {
    return 'y $count más';
  }

  @override
  String get batchReplaceCompareAgain => 'Volver a comparar';

  @override
  String get batchReplaceNoMatchesTitle => 'No hay coincidencias';

  @override
  String batchReplaceNoMatchesMessage(int files) {
    return 'Ninguno de los $files archivos de esa carpeta parece una canción que ya esté en tu biblioteca.';
  }

  @override
  String get batchReplaceNothingSelected => 'No hay nada seleccionado';

  @override
  String get batchReplaceCollisionTitle => 'Los archivos ya existen';

  @override
  String batchReplaceCollisionMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ya existen $count archivos de reemplazo en las ubicaciones de destino. ¿Quieres reemplazarlos u omitirlos?',
      one:
          'Ya existe un archivo de reemplazo en la ubicación de destino. ¿Quieres reemplazarlo u omitirlo?',
    );
    return '$_temp0';
  }

  @override
  String get batchReplaceCollisionReplace => 'Reemplazar';

  @override
  String get batchReplaceCollisionSkip => 'Omitir';

  @override
  String get batchReplaceOptionsTitle => 'Reemplazar canciones';

  @override
  String get batchReplaceTransportSection => 'Archivos nuevos';

  @override
  String get batchReplaceTransportCopy => 'Copiar a la biblioteca';

  @override
  String get batchReplaceTransportCopyHint =>
      'Se conservarán las copias de la carpeta comparada';

  @override
  String get batchReplaceTransportMove => 'Mover a la biblioteca';

  @override
  String get batchReplaceTransportMoveHint =>
      'Los archivos utilizados se quitarán de la carpeta comparada';

  @override
  String get batchReplaceOriginalSection => 'Archivos antiguos';

  @override
  String get batchReplaceOriginalHide => 'Conservarlos ocultos';

  @override
  String get batchReplaceOriginalHideHint =>
      'Los archivos permanecerán en el disco, fuera de la biblioteca';

  @override
  String get batchReplaceOriginalDelete => 'Eliminarlos';

  @override
  String get batchReplaceOriginalDeleteHint =>
      'Los archivos se eliminarán permanentemente del disco';

  @override
  String batchReplaceRun(int count) {
    return 'Reemplazar $count canciones';
  }

  @override
  String get batchReplaceDeleteTitle => '¿Eliminar los archivos antiguos?';

  @override
  String batchReplaceDeleteMessage(int count) {
    return 'Se eliminarán $count archivos originales del disco. Esta acción no se puede deshacer.';
  }

  @override
  String get batchReplaceDeleteConfirm => 'Eliminar';

  @override
  String get batchReplaceOutcomeTitle => 'Reemplazo en lote';

  @override
  String batchReplaceOutcomeDone(int count) {
    return 'Se reemplazaron $count canciones.';
  }

  @override
  String batchReplaceOutcomeDoneFailed(int count, int failed) {
    return 'Se reemplazaron $count canciones; no se pudieron reemplazar $failed.';
  }

  @override
  String batchReplaceOutcomeStopped(int count) {
    return 'Se detuvo después de reemplazar $count canciones.';
  }

  @override
  String batchReplaceOutcomeStoppedFailed(int count, int failed) {
    return 'Se detuvo después de reemplazar $count canciones; no se pudieron reemplazar $failed.';
  }

  @override
  String batchReplaceFailureError(Object error) {
    return '$error';
  }

  @override
  String get settingsSearchBatchReplaceTitle => 'Reemplazar canciones en lote';

  @override
  String get settingsSearchBatchReplaceSubtitle =>
      'Sustituir canciones por archivos mejores de otra carpeta';

  @override
  String get storageWispieCacheTitle => 'Caché de wispie';

  @override
  String get storageWispieCacheSubtitle =>
      'Se vuelve a generar cuando hace falta. Aquí no se guardan tus datos.';

  @override
  String get storageCleanCacheAction => 'Limpiar';

  @override
  String get storageCleanCacheTitle => '¿Limpiar la caché?';

  @override
  String get storageCleanCacheBody =>
      'Elimina los archivos en caché que no se usan, los archivos vacíos y los que superan el límite de tamaño. Todo se vuelve a generar cuando hace falta.';

  @override
  String storageCleanCacheSuccess(String size) {
    return 'Se limpió $size';
  }

  @override
  String get storageCleanCacheNothing => 'La caché ya está limpia';

  @override
  String storageCleanCacheError(String error) {
    return 'Error al limpiar la caché: $error';
  }

  @override
  String get storageCacheEmpty => 'Vacía';

  @override
  String storageClearBucketTitle(String name) {
    return '¿Borrar $name?';
  }

  @override
  String get storageClearBucketBody =>
      'Estos archivos se volverán a generar cuando se necesiten.';

  @override
  String storageClearBucketSuccess(String name) {
    return 'Se borró $name';
  }

  @override
  String storageClearBucketError(String name, String error) {
    return 'Error al borrar $name: $error';
  }

  @override
  String get storageClearWispieCacheTitle => '¿Borrar la caché de wispie?';

  @override
  String get storageClearWispieCacheBody =>
      'Se eliminarán todos los archivos en caché y se volverán a generar cuando hagan falta. Tu biblioteca, listas de reproducción y estadísticas no se modificarán.';

  @override
  String get storageClearWispieCacheSuccess => 'Se borró la caché de wispie';

  @override
  String get storageRemoteArtTitle => 'Ilustraciones descargadas';

  @override
  String get storageRemoteArtSubtitle =>
      'Ilustraciones obtenidas en línea para los temas';

  @override
  String get storageNotificationCacheTitle => 'Ilustraciones de notificación';

  @override
  String get storageNotificationCacheSubtitle =>
      'Carátulas cuadradas para la notificación multimedia';

  @override
  String get storageYoutubeCacheTitle => 'Páginas en línea';

  @override
  String get storageYoutubeCacheSubtitle =>
      'Páginas de YouTube y feed de inicio en caché';

  @override
  String storageBackupsLocation(String path) {
    return 'Guardadas en $path';
  }
}
