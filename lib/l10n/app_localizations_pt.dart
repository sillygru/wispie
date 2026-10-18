// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Idioma do sistema';

  @override
  String get languageNativeName => 'Português (Brasil)';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsPageLibrarySubtitle =>
      'Pastas, filtros, busca de arquivos';

  @override
  String get settingsPagePlaybackTitle => 'Reprodução';

  @override
  String get settingsPagePlaybackSubtitle => 'Transições, fades, áudio';

  @override
  String get settingsPageLyricsTitle => 'Letras';

  @override
  String get settingsPageLyricsSubtitle =>
      'Sincronização por palavra, tradução, barra lateral';

  @override
  String get settingsPageAppearanceTitle => 'Aparência';

  @override
  String get settingsPageAppearanceSubtitle =>
      'Tocando agora, movimento, ícone do app';

  @override
  String get settingsPageHomeNavigationTitle => 'Início e navegação';

  @override
  String get settingsPageHomeNavigationSubtitle =>
      'Seções do início, listas, ações rápidas';

  @override
  String get settingsPageSyncTitle => 'Sincronização';

  @override
  String get settingsPageSyncSubtitle =>
      'Sincronização criptografada entre dispositivos';

  @override
  String get settingsPageBackupRestoreTitle => 'Backups e restauração';

  @override
  String get settingsPageBackupRestoreSubtitle =>
      'Exportar, importar, backups automáticos';

  @override
  String get settingsPageStorageTitle => 'Armazenamento';

  @override
  String get settingsPageStorageSubtitle => 'Espaço em disco, índices, cache';

  @override
  String get settingsPageAboutTitle => 'Sobre';

  @override
  String get settingsPageAboutSubtitle =>
      'Versão, atualizações, notas de lançamento';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionCreate => 'Criar';

  @override
  String get actionDone => 'Concluído';

  @override
  String get actionChange => 'Alterar';

  @override
  String get actionDelete => 'Excluir';

  @override
  String get actionHide => 'Ocultar';

  @override
  String get actionDeletePermanently => 'Excluir permanentemente';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get playlistNewTitle => 'Nova playlist';

  @override
  String get playlistNameHint => 'Nome da playlist';

  @override
  String playlistCreated(Object name) {
    return 'Playlist \"$name\" criada';
  }

  @override
  String songFavoriteRemoved(Object title) {
    return '$title removida dos favoritos';
  }

  @override
  String songFavoriteAdded(Object title) {
    return '$title adicionada aos favoritos';
  }

  @override
  String songWillSuggestMore(Object title) {
    return '$title será sugerida com mais frequência';
  }

  @override
  String songWillSuggestLess(Object title) {
    return '$title será sugerida com menos frequência';
  }

  @override
  String songAddedToNextUp(Object title) {
    return 'Adicionada a A seguir: $title';
  }

  @override
  String songShareText(Object artist, Object title) {
    return '$title de $artist';
  }

  @override
  String songAddedToPlaylist(Object name) {
    return 'Adicionada a $name';
  }

  @override
  String songRemovedFromPlaylist(Object title) {
    return '$title removida da playlist';
  }

  @override
  String songMovedTo(Object path, Object title) {
    return '$title movida para $path';
  }

  @override
  String songMoveError(Object error) {
    return 'Erro ao mover a música: $error';
  }

  @override
  String songRemovedFromLibrary(Object title) {
    return '$title removida da biblioteca';
  }

  @override
  String get songDeleteTitle => 'Excluir música';

  @override
  String songDeleteConfirm(Object title) {
    return 'Tem certeza de que deseja excluir permanentemente \'\'$title\'\' do seu dispositivo? Essa ação não pode ser desfeita.';
  }

  @override
  String songDeleted(Object title) {
    return '$title excluída';
  }

  @override
  String songDeleteError(Object error) {
    return 'Erro ao excluir o arquivo: $error';
  }

  @override
  String get coverSearching => 'Buscando capas no Last.fm, Deezer e iTunes...';

  @override
  String get coverNoneFound => 'Nenhuma capa faltando foi encontrada online';

  @override
  String coverUpdated(Object source, Object title) {
    return 'Capa atualizada para \"$title\" ($source)';
  }

  @override
  String get coverDownloadFailed => 'Falha ao baixar a capa';

  @override
  String coverFetchError(Object error) {
    return 'Erro ao buscar a capa: $error';
  }

  @override
  String get metaResultsTitle => 'Resultados da busca de metadata';

  @override
  String get metaFetchingTitle => 'Buscando metadata faltando';

  @override
  String get metaStatUpdated => 'Atualizado';

  @override
  String get metaStatNotFound => 'Não encontrado';

  @override
  String get metaStatSkipped => 'Ignorado';

  @override
  String get metaUndoAll => 'Desfazer tudo';

  @override
  String get metaUndoSong => 'Desfazer esta música';

  @override
  String metaRevertedCount(int count) {
    return 'Alterações de metadata revertidas em $count faixa(s)';
  }

  @override
  String metaViaSource(Object source) {
    return 'via $source';
  }

  @override
  String metaMoreItems(int count) {
    return '... e mais $count';
  }

  @override
  String get metaCouldNotFind => 'Não foi possível encontrar';

  @override
  String get metaUnknownArtist => 'Artista desconhecido';

  @override
  String metaAllHaveMetadata(int count) {
    return 'Todas as $count faixas já têm metadata';
  }

  @override
  String get metaNoMissingMetadata =>
      'Nenhuma música com metadata faltando foi encontrada';

  @override
  String metaSearchingBatch(int batch) {
    return 'Buscando o lote $batch...';
  }

  @override
  String metaCancelledSummary(int updated, int notFound) {
    return 'Busca de metadata cancelada ($updated atualizadas, $notFound não encontradas)';
  }

  @override
  String get songMenuTitle => 'Opções da música';

  @override
  String get songMenuPlaybackHint =>
      'Ações de fila, playlist e compartilhamento';

  @override
  String get songMenuLibraryHint => 'Mover música e editar metadata';

  @override
  String get songMenuPersonalize => 'Personalizar';

  @override
  String get songMenuPersonalizeHint =>
      'Configurações de favoritos e recomendações';

  @override
  String get songMenuDanger => 'Zona de perigo';

  @override
  String get songMenuDangerHint => 'Remover da playlist ou excluir a música';

  @override
  String get songMenuPlayNext => 'Tocar em seguida';

  @override
  String get songMenuPlayNextHint =>
      'Adicionar a música para tocar logo após a faixa atual';

  @override
  String get songMenuPlayNextDuplicate =>
      'Tocar em seguida (permitir duplicatas)';

  @override
  String get songMenuPlayNextDuplicateHint =>
      'Adicionar de novo mesmo que já esteja na fila';

  @override
  String get songMenuAddToPlaylist => 'Adicionar à playlist';

  @override
  String get songMenuAddToPlaylistHint =>
      'Adicionar rapidamente à playlist mais recente';

  @override
  String get songMenuAddToNewPlaylist => 'Adicionar a uma nova playlist';

  @override
  String get songMenuAddToNewPlaylistHint =>
      'Criar uma playlist e adicionar esta música';

  @override
  String get songMenuShare => 'Compartilhar';

  @override
  String get songMenuShareHint =>
      'Compartilhar o arquivo de áudio com outros apps';

  @override
  String get songMenuFetchCover => 'Buscar capa faltando';

  @override
  String get songMenuFetchCoverHint =>
      'Tentar buscar capas no Last.fm, Deezer e iTunes';

  @override
  String get songMenuFetchMetadata => 'Buscar metadata faltando';

  @override
  String get songMenuFetchMetadataHint =>
      'Buscar online título, artista, álbum e capa';

  @override
  String get songMenuMoveToFolder => 'Mover para pasta';

  @override
  String get songMenuMoveToFolderHint => 'Mover este arquivo para outra pasta';

  @override
  String get songMenuManagePlaylists => 'Gerenciar playlists';

  @override
  String get songMenuManagePlaylistsHint => 'Adicionar ou remover de playlists';

  @override
  String get songMenuEditMetadata => 'Editar';

  @override
  String get songMenuEditMetadataHint => 'Abrir o editor de metadata';

  @override
  String get songMenuRemoveFavorite => 'Remover dos favoritos';

  @override
  String get songMenuAddFavorite => 'Adicionar aos favoritos';

  @override
  String get songMenuFavoritesHint => 'Ajustar sua lista de músicas favoritas';

  @override
  String get songMenuSuggestMore => 'Sugerir mais';

  @override
  String get songMenuSuggestLess => 'Sugerir menos';

  @override
  String get songMenuSuggestHint =>
      'Ajustar com que frequência esta música aparece nas sugestões';

  @override
  String get songMenuRemoveFromPlaylist => 'Remover da lista atual';

  @override
  String get songMenuRemoveFromPlaylistHint =>
      'Manter o arquivo, remover da playlist';

  @override
  String get songMenuRemoveFromLibrary => 'Remover da biblioteca';

  @override
  String get songMenuRemoveFromLibraryHint =>
      'Manter o arquivo, mas ocultar da biblioteca';

  @override
  String get songMenuDeleteHint => 'Excluir o arquivo do dispositivo';

  @override
  String get bulkSelected => 'selecionadas';

  @override
  String get bulkSelectAll => 'Selecionar tudo';

  @override
  String get bulkFavorite => 'Favoritar';

  @override
  String get bulkUnfavorite => 'Desfavoritar';

  @override
  String bulkRemovedFromFavorites(int count) {
    return '$count músicas removidas dos favoritos';
  }

  @override
  String bulkAddedToFavorites(int count) {
    return '$count músicas adicionadas aos favoritos';
  }

  @override
  String get bulkPlaylist => 'Playlist';

  @override
  String bulkAddedToPlaylist(int count, Object name) {
    return '$count músicas adicionadas a $name';
  }

  @override
  String bulkSongsCount(int count) {
    return '$count músicas';
  }

  @override
  String get bulkMetadata => 'metadata';

  @override
  String get bulkHideTitle => 'Ocultar músicas';

  @override
  String bulkHideMessage(int count) {
    return 'Ocultar $count músicas selecionadas da biblioteca?';
  }

  @override
  String get bulkDeleteTitle => 'Excluir arquivos';

  @override
  String bulkDeleteMessage(int count) {
    return 'Excluir permanentemente $count arquivos do armazenamento? Essa ação não pode ser desfeita.';
  }

  @override
  String bulkAddedToQueue(int count) {
    return '$count músicas adicionadas à fila';
  }

  @override
  String get bulkMove => 'Mover';

  @override
  String bulkMovedTo(int count, Object path) {
    return '$count músicas movidas para $path';
  }

  @override
  String bulkMoveError(Object error) {
    return 'Erro ao mover as músicas: $error';
  }

  @override
  String bulkWillSuggestMore(int count) {
    return 'Serão sugeridas mais $count músicas';
  }

  @override
  String bulkWillSuggestLess(int count) {
    return 'Serão sugeridas menos $count músicas';
  }

  @override
  String get queueTabUpNext => 'A seguir';

  @override
  String get queueTabHistory => 'Histórico';

  @override
  String get queueActionMoveToTop => 'Mover para o topo';

  @override
  String get queueActionRemove => 'Remover';

  @override
  String get queueActionSongOptions => 'Opções da música…';

  @override
  String get queueClearDialogTitle => 'Limpar fila?';

  @override
  String get queueClearDialogMessage =>
      'Isso vai remover todas as músicas seguintes da fila atual.';

  @override
  String get queueClearAll => 'Limpar tudo';

  @override
  String get queueSectionPlayed => 'Já tocadas';

  @override
  String get queueSectionNowPlaying => 'Tocando agora';

  @override
  String get queueSectionUpNext => 'A seguir';

  @override
  String get queueSwipeAddToTop => 'Adicionar ao topo';

  @override
  String get queueShuffleUpcomingTooltip => 'Embaralhar seguintes';

  @override
  String get queueClearUpcomingTooltip => 'Limpar seguintes';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0';
  }

  @override
  String queueRemainingSuffix(String remaining) {
    return '  ·  $remaining';
  }

  @override
  String get queueEmpty => 'A fila está vazia';

  @override
  String get queueRemoveFromQueueTooltip => 'Remover da fila';

  @override
  String queueRemovedTitle(String title) {
    return '$title removida';
  }

  @override
  String get queueUndo => 'Desfazer';

  @override
  String get historyClearDialogTitle => 'Limpar histórico?';

  @override
  String get historyClearDialogMessage =>
      'Isso vai excluir todas as filas salvas.';

  @override
  String historyRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restauradas $count faixas',
      one: 'Restaurada 1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadError => 'Não foi possível carregar o histórico';

  @override
  String get historyEmptyTitle => 'Não há filas anteriores';

  @override
  String get historyEmptyMessage =>
      'As filas que você tocar são salvas aqui automaticamente.';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filas salvas',
      one: '1 fila salva',
    );
    return '$_temp0';
  }

  @override
  String get historyClearAllTrailing => 'Limpar tudo';

  @override
  String get historyDayToday => 'Hoje';

  @override
  String get historyDayYesterday => 'Ontem';

  @override
  String get historyDayThisWeek => 'Esta semana';

  @override
  String get historyDayThisMonth => 'Este mês';

  @override
  String get historyDayEarlier => 'Anteriormente';

  @override
  String get snapshotShuffledQueue => 'Fila embaralhada';

  @override
  String get snapshotSavedQueue => 'Fila salva';

  @override
  String get snapshotEmptyTracks =>
      'Nenhuma dessas faixas ainda está na sua biblioteca.';

  @override
  String snapshotMoreHidden(int count) {
    return '+$count a mais';
  }

  @override
  String snapshotMissingCount(int count) {
    return '$count faltando na biblioteca';
  }

  @override
  String get queueMetaSeparator => '  ·  ';

  @override
  String get songListShuffle => 'Aleatório';

  @override
  String get songListPlay => 'Reproduzir';

  @override
  String get songListPause => 'Pausar';

  @override
  String get songListResume => 'Continuar';

  @override
  String get songListFetchArtistCover => 'Buscar capa do artista online';

  @override
  String get songListFetchAlbumCover => 'Buscar capa do álbum online';

  @override
  String get songListFetchCover => 'Buscar capa online';

  @override
  String get songListPlaylistOptions => 'Opções da playlist';

  @override
  String get songListSelectSongsToMerge => 'Selecionar músicas para mesclar';

  @override
  String songListMergedSongs(int count) {
    return '$count músicas mescladas';
  }

  @override
  String songListMergeError(Object error) {
    return 'Erro: $error';
  }

  @override
  String get songListMergeSongs => 'Mesclar músicas';

  @override
  String get songListEmpty => 'Não há músicas nesta lista';

  @override
  String get actionRename => 'Renomear';

  @override
  String get songListRenamePlaylist => 'Renomear playlist';

  @override
  String get songListDeletePlaylist => 'Excluir playlist';

  @override
  String songListDeletePlaylistConfirm(Object title) {
    return 'Tem certeza de que deseja excluir \"$title\"?';
  }

  @override
  String songListSearchingArtwork(Object name) {
    return 'Buscando online a capa de $name...';
  }

  @override
  String songListSelectArtwork(Object name) {
    return 'Selecionar capa para $name';
  }

  @override
  String get songListUseSongCoverGrid => 'Usar grade de capas de música';

  @override
  String get songListRemoveCustomArtwork => 'Remover capa personalizada';

  @override
  String get songListChooseCustomImage => 'Escolher imagem personalizada';

  @override
  String get songListSelectFromDevice =>
      'Selecionar imagem do armazenamento do dispositivo';

  @override
  String songListArtworkFrom(Object source) {
    return 'Capa de $source';
  }

  @override
  String get songListNoOnlineArtwork =>
      'Nenhuma opção de capa online encontrada';

  @override
  String get songListResetArtwork =>
      'Restaurar para a grade de capas de música';

  @override
  String songListArtworkUpdated(Object name) {
    return 'Capa atualizada para $name';
  }

  @override
  String get songListDownloadingArtwork => 'Baixando capa...';

  @override
  String get songListArtworkDownloadFailed => 'Falha ao baixar a capa';

  @override
  String get gradientDetailAlbums => 'Álbuns';

  @override
  String get gradientDetailSongs => 'Músicas';

  @override
  String get gradientDetailShowAll => 'Mostrar tudo';

  @override
  String gradientDetailAlbumCount(int count) {
    return '$count álbuns';
  }

  @override
  String get syncPlayStats => 'Estatísticas de reprodução';

  @override
  String get syncPlayStatsHint =>
      'Histórico de audição e contagem de reproduções';

  @override
  String get syncFavoritesHint => 'Músicas favoritas';

  @override
  String get syncSuggestLess => 'Sugerir menos';

  @override
  String get syncSuggestLessHint => 'Músicas que você pediu para ver menos';

  @override
  String get syncHiddenSongs => 'Músicas ocultas';

  @override
  String get syncPlaylistsHint => 'Todas as playlists';

  @override
  String get syncMergedSongs => 'Músicas mescladas';

  @override
  String get syncMergedSongsHint => 'Grupos de músicas mescladas';

  @override
  String get syncAppSettings => 'Configurações do app';

  @override
  String get syncAppSettingsHint =>
      'Tema, reprodução e preferências de interface';

  @override
  String get syncArtistArt => 'Capa do artista';

  @override
  String get syncArtistArtHint => 'Opções de capa do artista online';

  @override
  String get syncAlbumArt => 'Capa do álbum';

  @override
  String get syncAlbumArtHint => 'Opções de capa do álbum online';

  @override
  String get syncPrivacy => 'Privacidade';

  @override
  String get syncEncryptedTitle => 'Criptografia de ponta a ponta';

  @override
  String get syncEncryptedBody =>
      'Seus dados são criptografados neste dispositivo antes do envio. O servidor armazena apenas o texto cifrado e não consegue ler sua biblioteca, seu histórico nem suas configurações.';

  @override
  String get syncRecoveryKeyTitle => 'Chave de recuperação';

  @override
  String get syncRecoveryKeyBody =>
      'Se você esquecer sua senha, apenas sua chave de recuperação pode restaurar o acesso. Ninguém mais pode.';

  @override
  String get syncAccount => 'Conta';

  @override
  String get syncSignedIn => 'Sessão iniciada';

  @override
  String get syncConnected => 'Conectado';

  @override
  String get syncLogOut => 'Sair';

  @override
  String get syncLogOutBody =>
      'A sincronização para neste dispositivo. Os dados locais e na nuvem são mantidos.';

  @override
  String get syncLogOutAndChange => 'Sair e alterar';

  @override
  String get syncCloud => 'Nuvem';

  @override
  String get syncLastSynced => 'Última sincronização';

  @override
  String get syncNever => 'Nunca';

  @override
  String syncUsedOfQuota(Object used, Object quota) {
    return '$used de $quota usados';
  }

  @override
  String get syncJustNow => 'Agora mesmo';

  @override
  String syncMinutesAgo(int count) {
    return 'há $count min';
  }

  @override
  String syncHoursAgo(int count) {
    return 'há $count h';
  }

  @override
  String syncDaysAgo(int count) {
    return 'há $count d';
  }

  @override
  String get syncAutoSync => 'Sincronização automática';

  @override
  String get syncAutoSyncHint =>
      'Sincronizar em segundo plano enquanto o app estiver aberto';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get syncMergeDeviceHint => 'Mesclar este dispositivo com a nuvem';

  @override
  String syncLastError(Object error) {
    return 'Último erro: $error';
  }

  @override
  String get syncWhatGetsSynced => 'O que é sincronizado';

  @override
  String get syncDeviceStatsAttribution =>
      'Atribuição de estatísticas por dispositivo';

  @override
  String get syncThisDevice => 'Este dispositivo';

  @override
  String get syncOtherDevices => 'Outros dispositivos';

  @override
  String get syncTotalLibraryStats => 'Estatísticas totais da biblioteca';

  @override
  String syncPlays(int count) {
    return '$count reproduções';
  }

  @override
  String get syncDangerZone => 'Zona de perigo';

  @override
  String get syncOverwriteCloudTile =>
      'Substituir a nuvem com este dispositivo';

  @override
  String get syncOverwriteCloudTileHint =>
      'Substituir todos os dados da nuvem pelos que estão neste dispositivo';

  @override
  String get syncReplaceDeviceTile => 'Substituir este dispositivo pela nuvem';

  @override
  String get syncReplaceDeviceTileHint =>
      'Apagar os dados sincronizados neste dispositivo e usar a cópia da nuvem';

  @override
  String get syncChangePassword => 'Alterar senha';

  @override
  String get syncNewRecoveryKey => 'Nova chave de recuperação';

  @override
  String get syncNewRecoveryKeyHint =>
      'A chave de recuperação antiga deixa de funcionar';

  @override
  String get syncChangeServer => 'Alterar servidor';

  @override
  String get syncChangeServerHint => 'É necessário sair primeiro';

  @override
  String get syncChangeServerBody =>
      'Você sairá do servidor atual primeiro. Os dados locais são mantidos.';

  @override
  String get syncDeleteCloudAccount => 'Excluir conta na nuvem';

  @override
  String get syncDeleteCloudAccountHint =>
      'Remove os dados da nuvem permanentemente. Os dados locais são mantidos';

  @override
  String get syncDeleteCloudAccountBody =>
      'Sua conta na nuvem e todos os dados criptografados no servidor são excluídos permanentemente. Os dados neste dispositivo são mantidos.';

  @override
  String get syncOverwriteCloud => 'Substituir a nuvem';

  @override
  String get syncOverwriteCloudBody =>
      'Todos os dados na nuvem serão substituídos pelos deste dispositivo. Os outros dispositivos serão questionados sobre como continuar. Este dispositivo mantém seus dados.';

  @override
  String get syncOverwriteCloudCheckbox =>
      'Entendo que os dados da nuvem serão perdidos';

  @override
  String get syncOverwrite => 'Substituir';

  @override
  String get syncReplaceDevice => 'Substituir este dispositivo';

  @override
  String get syncReplaceDeviceBody =>
      'Os dados sincronizados neste dispositivo (estatísticas, favoritos, playlists e assim por diante) serão apagados e substituídos pela cópia da nuvem. Os arquivos de música não são alterados.';

  @override
  String get syncReplaceDeviceCheckbox =>
      'Entendo que os dados sincronizados locais serão perdidos';

  @override
  String get syncReplace => 'Substituir';

  @override
  String get syncCurrentPassword => 'Senha atual';

  @override
  String get syncNewPassword => 'Nova senha';

  @override
  String get syncPassword => 'Senha';

  @override
  String get syncPasswordChanged => 'Senha alterada';

  @override
  String get syncGenerate => 'Gerar';

  @override
  String get appearanceGroupNowPlaying => 'Tocando agora';

  @override
  String get appearanceVisualizerTitle => 'Visualizador de áudio';

  @override
  String get appearanceVisualizerSubtitle =>
      'Barras sobre a capa durante a reprodução — o modo sincronizado acompanha a música, com os graves à esquerda';

  @override
  String get appearanceVisualizerClassic => 'Clássico';

  @override
  String get appearanceVisualizerSynced => 'Sincronizado';

  @override
  String get appearanceProgressBarTitle => 'Estilo da barra de progresso';

  @override
  String get appearanceProgressBasicSubtitle =>
      'Barra de progresso de linha simples';

  @override
  String get appearanceProgressWaveformSubtitle =>
      'Forma de onda de áudio estática';

  @override
  String get appearanceProgressReactiveSubtitle =>
      'Forma de onda dinâmica reativa ao som, com espectro ao vivo e resposta à batida';

  @override
  String get appearanceProgressStandard => 'Padrão';

  @override
  String get appearanceProgressWaveform => 'Forma de onda';

  @override
  String get appearanceProgressSoundReactive => 'Reativo ao som';

  @override
  String get appearanceHapticsTitle =>
      'Retorno tátil ao arrastar a forma de onda';

  @override
  String get appearanceHapticsSubtitle =>
      'Retorno tátil para cada barra ao avançar na faixa';

  @override
  String get appearanceCoverSizingTitle => 'Dimensionamento da capa do player';

  @override
  String get appearanceCoverSizingSubtitle =>
      'Ajuste automático ou preservar a proporção do original';

  @override
  String get appearanceCoverAutoFit => 'Ajuste automático';

  @override
  String get appearanceCoverSourceSize => 'Tamanho original';

  @override
  String get appearanceImmersiveTitle => 'Design imersivo';

  @override
  String get appearanceImmersiveSubtitle =>
      'Capa do player em tela cheia e telas de detalhes com gradiente';

  @override
  String get appearanceGroupPlayerMotion => 'Movimento do player';

  @override
  String get appearanceBeatCoverTitle => 'Capa reativa à batida';

  @override
  String get appearanceBeatCoverUnavailable =>
      'Indisponível enquanto o design imersivo estiver ativo';

  @override
  String get appearanceBeatCoverSubtitle =>
      'A capa do álbum pulsa com a batida';

  @override
  String get appearanceCoverIntensityTitle => 'Intensidade da capa';

  @override
  String get appearanceCoverIntensitySubtitle =>
      'Com que intensidade a capa reage';

  @override
  String get appearanceSpinArtworkTitle => 'Girar a capa durante a reprodução';

  @override
  String get appearanceSpinArtworkSubtitle =>
      'A capa gira lentamente na barra inferior minimizada enquanto uma música toca';

  @override
  String get appearanceParticlesTitle => 'Partículas reativas à batida';

  @override
  String get appearanceParticlesSubtitle =>
      'Partículas flutuantes que vagam e respiram com a música';

  @override
  String get appearanceParticleDensityTitle => 'Densidade das partículas';

  @override
  String get appearanceParticleDensitySubtitle =>
      'Quantas partículas existem e quão vivas elas ficam';

  @override
  String get appearanceBeatOffsetTitle => 'Ajuste de sincronia da batida';

  @override
  String get appearanceBeatOffsetNone =>
      'Sem ajuste — aumente se o pulso parecer adiantado';

  @override
  String appearanceBeatOffsetValue(int ms) {
    return '$ms ms';
  }

  @override
  String appearanceBeatOffsetBluetooth(int ms) {
    return '$ms ms (aumente para Bluetooth)';
  }

  @override
  String get appearanceCalibrateTitle => 'Calibrar sincronia da batida';

  @override
  String get appearanceCalibrateSubtitle =>
      'Alinhe as partículas com uma faixa de cliques de ouvido';

  @override
  String get appearanceAppIcon => 'Ícone do app';

  @override
  String get appearanceIntensityMin => 'Mín';

  @override
  String get appearanceIntensitySubtle => 'Sutil';

  @override
  String get appearanceIntensityBalanced => 'Equilibrado';

  @override
  String get appearanceIntensityBold => 'Forte';

  @override
  String get appearanceIntensityMax => 'Máx';

  @override
  String get appearanceIntensityCustom => 'Personalizado';

  @override
  String get backupExportAppData => 'Exportar dados do app';

  @override
  String get backupExportAppDataSubtitle =>
      'Faça backup das suas estatísticas, favoritos e playlists';

  @override
  String backupExportFailed(Object error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get backupImportAppData => 'Importar dados do app';

  @override
  String get backupImportAppDataSubtitle =>
      'Restaurar dados de um backup (substitui tudo)';

  @override
  String get backupManageBackups => 'Gerenciar backups';

  @override
  String get backupManageBackupsSubtitle =>
      'Criar, restaurar e gerenciar backups do app';

  @override
  String get backupAutomaticBackups => 'Backups automáticos';

  @override
  String get backupAutoBackup => 'Backup automático';

  @override
  String get backupAutoBackupSubtitle => 'Com que frequência um backup é feito';

  @override
  String get backupAutoBackupContent => 'Conteúdo do backup automático';

  @override
  String get backupAutoBackupContentSubtitle =>
      'Quais dados são incluídos nos backups automáticos';

  @override
  String get backupAutoBackupContentDialogSubtitle =>
      'Selecione o conteúdo dos backups automáticos';

  @override
  String get backupSave => 'Salvar';

  @override
  String get backupAutoDeleteOld => 'Excluir backups antigos automaticamente';

  @override
  String get backupAutoDeleteOldSubtitle =>
      'Descartar backups mais antigos que isso';

  @override
  String get backupFrequencyDisabled => 'Desativado';

  @override
  String get backupFrequencyEvery24Hours => 'A cada 24 horas';

  @override
  String get backupFrequencyEvery48Hours => 'A cada 48 horas';

  @override
  String get backupFrequencyEvery3Days => 'A cada 3 dias';

  @override
  String get backupFrequencyEvery7Days => 'A cada 7 dias';

  @override
  String backupDeleteAfterDays(int count) {
    return '$count dias';
  }

  @override
  String get backupExportOptionsTitle => 'Opções de exportação';

  @override
  String get backupExportSelectContent => 'Selecione o conteúdo a exportar:';

  @override
  String get backupContentUserStats => 'Estatísticas do usuário';

  @override
  String get backupContentUserStatsSubtitle =>
      'Contagem de reproduções, sessões, estatísticas divertidas';

  @override
  String get backupContentUserData => 'Dados do usuário';

  @override
  String get backupContentUserDataSubtitle =>
      'Favoritos, músicas ocultas, playlists';

  @override
  String get backupContentUserSettings => 'Configurações do usuário';

  @override
  String get backupContentUserSettingsSubtitle =>
      'Tema, ordem de classificação, preferências';

  @override
  String get backupContentCoverCacheSubtitle => 'Imagens das capas dos álbuns';

  @override
  String get backupContentLibraryCacheSubtitle =>
      'Metadata de músicas em cache';

  @override
  String get backupContentSearchIndexSubtitle => 'Dados de busca indexados';

  @override
  String get backupContentWaveformCacheSubtitle =>
      'Dados de forma de onda de áudio';

  @override
  String get backupContentColorCacheSubtitle => 'Temas de cor dos álbuns';

  @override
  String get backupContentLyricsCacheSubtitle => 'Dados de letras armazenados';

  @override
  String get backupCancelUpper => 'CANCELAR';

  @override
  String get backupExportUpper => 'EXPORTAR';

  @override
  String get backupContinueUpper => 'CONTINUAR';

  @override
  String get backupImportDataTitle => 'Importar dados';

  @override
  String get backupImportWarning =>
      'Isto vai substituir TODOS os dados existentes pelos dados importados.\n\nSuas estatísticas, seus favoritos, suas playlists e suas configurações atuais serão sobrescritos.\n\nEsta ação não pode ser desfeita.';

  @override
  String get backupImportingLabel => 'Importando…';

  @override
  String get backupImportingTitle => 'Importando dados';

  @override
  String get backupImportSuccess => 'Importação concluída com sucesso!';

  @override
  String backupImportFailed(Object error) {
    return 'Falha na importação: $error';
  }

  @override
  String get metadataCoverUpdated => 'Capa atualizada com sucesso';

  @override
  String metadataPickImageError(Object error) {
    return 'Erro ao selecionar a imagem: $error';
  }

  @override
  String get metadataRemoveCoverTitle => 'Remover capa';

  @override
  String get metadataRemoveCoverBody =>
      'Tem certeza de que deseja remover a capa?';

  @override
  String get metadataRemoveUpper => 'REMOVER';

  @override
  String get metadataCoverRemoved => 'Capa removida';

  @override
  String metadataRemoveCoverError(Object error) {
    return 'Erro ao remover a capa: $error';
  }

  @override
  String get metadataFixResultTitle => 'Resultado da correção da miniatura';

  @override
  String get metadataFixReviewBody => 'Revise as alterações abaixo:';

  @override
  String get metadataFixOriginal => 'Original';

  @override
  String get metadataFixNew => 'Nova';

  @override
  String metadataFixNewOption(int n) {
    return 'Nova (opção $n)';
  }

  @override
  String get metadataFixSeeAlternatives => 'Ver alternativas';

  @override
  String get metadataFixApply => 'Aplicar';

  @override
  String get metadataFixSuccess => 'Miniatura corrigida com sucesso';

  @override
  String metadataFixError(Object error) {
    return 'Erro ao corrigir a miniatura: $error';
  }

  @override
  String get metadataFixThumbnail => 'Corrigir miniatura';

  @override
  String get metadataFixHelpBody =>
      'Esta ferramenta melhora automaticamente a capa do álbum ao:\n\n1. Detectar e remover barras e bordas pretas (comuns em miniaturas do YouTube)\n2. Recortar a imagem em um quadrado perfeito (proporção 1:1)\n\nIdeal para converter miniaturas 16:9 em capas de álbum adequadas.';

  @override
  String get metadataGotIt => 'Entendi';

  @override
  String get metadataExportCover => 'Exportar capa';

  @override
  String get metadataExport => 'Exportar';

  @override
  String metadataExportSuccess(Object uri) {
    return 'Capa exportada para $uri';
  }

  @override
  String metadataExportError(Object error) {
    return 'Erro ao exportar a capa: $error';
  }

  @override
  String get metadataReplaceSong => 'Substituir música';

  @override
  String get metadataReplaceHelpBody =>
      'Troca o arquivo desta música por outra cópia da mesma música (rip melhor, sem perdas, codificação limpa).\n\nO histórico de reprodução, os favoritos, as playlists e a data na biblioteca passam para o novo arquivo. A metadata é lida novamente do arquivo, e tudo o que faltar aparece como desconhecido.\n\nO novo arquivo precisa estar fora das pastas da sua biblioteca e ter um nome de arquivo diferente.';

  @override
  String metadataReplaced(Object filename) {
    return 'Substituída por $filename';
  }

  @override
  String metadataReplaceError(Object error) {
    return 'Não foi possível substituir o arquivo: $error';
  }

  @override
  String metadataReplaceFilesBody(Object oldName, Object newName) {
    return '$oldName\nsubstituída por $newName';
  }

  @override
  String get metadataReplaceOriginalQuestion =>
      'O que deve acontecer com o original?';

  @override
  String get metadataReplaceRejectNoFile => 'Nenhum arquivo foi selecionado.';

  @override
  String get metadataReplaceRejectUnsupported =>
      'Esse arquivo não está em um formato de áudio ou vídeo que esta biblioteca consegue ler.';

  @override
  String get metadataReplaceRejectSameFilename =>
      'A substituição precisa de um nome de arquivo diferente. Alterar apenas a extensão já basta.';

  @override
  String get metadataReplaceRejectInsideLibrary =>
      'Esse arquivo está dentro de uma das suas pastas da biblioteca. Escolha uma cópia de algum lugar fora da sua biblioteca.';

  @override
  String metadataReplaceRejectDestinationExists(String filename) {
    return 'Um arquivo chamado \"$filename\" já está ao lado do original.';
  }

  @override
  String metadataReplaceRejectLibraryHasName(String filename) {
    return 'Sua biblioteca já tem uma música chamada \"$filename\".';
  }

  @override
  String get metadataKeepHideUpper => 'MANTER, OCULTAR';

  @override
  String get metadataDeleteItUpper => 'EXCLUIR';

  @override
  String get metadataSaved => 'Metadata atualizada com sucesso';

  @override
  String metadataSaveError(Object error) {
    return 'Erro ao salvar a metadata: $error';
  }

  @override
  String get metadataNoOnlineCover => 'Nenhuma capa encontrada online';

  @override
  String get metadataSelectCoverTitle => 'Selecionar capa';

  @override
  String metadataResultTitleArtist(Object title, Object artist) {
    return '$title - $artist';
  }

  @override
  String metadataSourceLabel(Object source) {
    return 'Fonte: $source';
  }

  @override
  String metadataCoverUpdatedFrom(Object source) {
    return 'Capa atualizada de $source';
  }

  @override
  String get metadataNoOnlineMatch =>
      'Nenhuma metadata correspondente encontrada online';

  @override
  String get metadataSelectMatchTitle => 'Selecionar correspondência online';

  @override
  String metadataResultDetail(Object artist, Object album, Object source) {
    return '$artist · $album ($source)';
  }

  @override
  String metadataLoadedFrom(Object source) {
    return 'Metadata e capa carregadas de $source';
  }

  @override
  String metadataFetchError(Object error) {
    return 'Erro ao buscar a metadata: $error';
  }

  @override
  String get metadataSectionCover => 'Capa';

  @override
  String get metadataChangeCover => 'Alterar capa';

  @override
  String get metadataWhatDoesThisDo => 'O que isso faz?';

  @override
  String get metadataSectionFile => 'Informações do arquivo';

  @override
  String get metadataFilenameLabel => 'Nome do arquivo (sem a extensão)';

  @override
  String get metadataFilenameHelper =>
      'Renomear o arquivo vai atualizá-lo localmente.';

  @override
  String get metadataSectionSong => 'Metadata da música';

  @override
  String get metadataFetchOnline => 'Buscar online';

  @override
  String get metadataTitleLabel => 'Título';

  @override
  String get metadataArtistLabel => 'Artista';

  @override
  String get metadataAlbumLabel => 'Álbum';

  @override
  String get metadataSectionExtra => 'Conteúdo adicional';

  @override
  String get metadataEditLyrics => 'Editar letras';

  @override
  String get metadataEditLyricsSubtitle =>
      'Ver ou editar as letras incorporadas';

  @override
  String get metadataSaveUpper => 'SALVAR';

  @override
  String metadataLyricsLoadError(Object error) {
    return 'Erro ao carregar as letras: $error';
  }

  @override
  String metadataLyricsSaveError(Object error) {
    return 'Erro ao salvar as letras: $error';
  }

  @override
  String get metadataLyricsLoaded =>
      'Letras carregadas — pressione SALVAR para aplicar';

  @override
  String get metadataSearchOnline => 'Buscar online';

  @override
  String get metadataLyricsHint =>
      'As letras estão incorporadas no arquivo de áudio. Você pode usar marcas de tempo [mm:ss.xx] para letras sincronizadas.';

  @override
  String get metadataLyricsFieldHint => 'Digite as letras aqui...';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileAvatarFallback => 'U';

  @override
  String get profileDefaultName => 'Usuário';

  @override
  String profileAppVersion(String version) {
    return 'wispie v$version';
  }

  @override
  String get profileHidden => 'Ocultas';

  @override
  String get profileSuggestLess => 'Sugerir menos';

  @override
  String get profileShuffleSection => 'Personalidade do aleatório';

  @override
  String get profileSmart => 'Inteligente';

  @override
  String get profileSmartSubtitle =>
      'Aprende seu gosto, tendências e contexto. Recomendado';

  @override
  String get profileDefault => 'Padrão';

  @override
  String get profileDefaultSubtitle => 'Mistura equilibrada com anti-repetição';

  @override
  String get profileExplorer => 'Explorador';

  @override
  String get profileExplorerSubtitle => 'Prioriza músicas novas e raras';

  @override
  String get profileConsistent => 'Consistente';

  @override
  String get profileConsistentSubtitle => 'Com muitos favoritos';

  @override
  String get profileCustomSubtitle => 'Configure seu próprio aleatório';

  @override
  String get profileChangeName => 'Alterar o nome exibido';

  @override
  String get profileNewNameHint => 'Novo nome';

  @override
  String get profileUpdate => 'Atualizar';

  @override
  String get profileNameUpdated => 'Nome atualizado';

  @override
  String profileCurrentName(String name) {
    return 'Atual: $name';
  }

  @override
  String get profilePersonalitySaved => 'Personalidade salva';

  @override
  String get profileAppliesNextQueue => 'Aplica-se à próxima fila';

  @override
  String get profileConfigureCustomShuffle =>
      'Configurar aleatório personalizado';

  @override
  String get profileConfigureCustomShuffleSubtitle =>
      'Ajustar as configurações de comportamento do aleatório';

  @override
  String get profileThemeStorage => 'Tema e armazenamento';

  @override
  String get profileFamiliar => 'Familiar';

  @override
  String get profileDiscover => 'Descobrir';

  @override
  String get profileFamiliarToDiscover => 'Familiar até Descobrir';

  @override
  String get profileLegacyCaption =>
      'Legado: comportamento fixo, mantido por compatibilidade';

  @override
  String get storageManageTitle => 'Gerenciar armazenamento';

  @override
  String get storageRepairCardTitle => 'Reparar links da biblioteca';

  @override
  String get storageRepairCardBody =>
      'Capa faltando depois de uma restauração ou de um celular novo? Isso re-vincula as capas e os caminhos dos arquivos.';

  @override
  String get storageRepair => 'Reparar';

  @override
  String get storageRepairTitle => 'Reparar links da biblioteca?';

  @override
  String get storageRepairBody =>
      'Isso re-vincula as capas em cache e os caminhos dos arquivos aonde eles realmente estão neste dispositivo.\n\nAs faixas cujos arquivos não estão mais aqui serão removidas da biblioteca. Favoritos, playlists e contagens de reprodução são mantidos, e se reconectam automaticamente se esses arquivos voltarem.';

  @override
  String storageRepairError(Object error) {
    return 'Erro ao reparar a biblioteca: $error';
  }

  @override
  String get storageDatabaseTitle => 'Banco de dados';

  @override
  String get storageDatabaseSubtitle =>
      'Dados do usuário, estatísticas e configurações';

  @override
  String get storageCoverCacheTitle => 'Cache das capas';

  @override
  String get storageCoverCacheSubtitle => 'Capas de música em cache';

  @override
  String get storageBackupsTitle => 'Backups';

  @override
  String get storageBackupsSubtitle => 'Arquivos de backup locais';

  @override
  String get storageLibraryCacheTitle => 'Cache da biblioteca';

  @override
  String get storageLibraryCacheSubtitle =>
      'Dados da biblioteca de músicas em cache';

  @override
  String get storageSearchIndexTitle => 'Índice de busca';

  @override
  String get storageSearchIndexSubtitle =>
      'Índice de busca para consultas rápidas';

  @override
  String get storageWaveformCacheTitle => 'Cache de formas de onda';

  @override
  String get storageWaveformCacheSubtitle =>
      'Formas de onda das músicas em cache para visualizadores';

  @override
  String get storageBeatAnalysisTitle => 'Análise de batidas';

  @override
  String get storageBeatAnalysisSubtitle =>
      'Mapas de batidas em cache para o player reativo';

  @override
  String get storageColorCacheTitle => 'Cache de cores';

  @override
  String get storageColorCacheSubtitle =>
      'Cores de tema em cache a partir das capas';

  @override
  String get storageLyricsCacheTitle => 'Cache de letras';

  @override
  String get storageLyricsCacheSubtitle =>
      'Disponibilidade e texto das letras em cache';

  @override
  String get storageBlurredCacheTitle => 'Cache de desfoque';

  @override
  String get storageBlurredCacheSubtitle => 'Fundos desfocados pré-gerados';

  @override
  String get storageClearCache => 'Limpar cache';

  @override
  String get storageClearDatabaseTitle => 'Limpar banco de dados?';

  @override
  String get storageClearDatabaseBody =>
      'Isso vai excluir permanentemente todos os seus dados do usuário, incluindo:\n\n• Todas as playlists\n• Favoritos e músicas ocultas\n• Estatísticas de reprodução\n• Configurações e preferências do app\n\nO app será redefinido. Essa ação não pode ser desfeita.';

  @override
  String get storageClearDatabaseAction => 'Limpar banco de dados';

  @override
  String storageClearDatabaseError(Object error) {
    return 'Erro ao limpar o banco de dados: $error';
  }

  @override
  String get storageClearCoversTitle => 'Limpar cache de capas?';

  @override
  String get storageClearCoversBody =>
      'Isso vai excluir todas as capas em cache.\n\nAs capas serão re-extraídas dos seus arquivos de música na próxima vez que você navegar pela biblioteca.';

  @override
  String get storageClearCoversAction => 'Limpar capas';

  @override
  String get storageClearCoversSuccess => 'Cache de capas limpo com sucesso';

  @override
  String storageClearCoversError(Object error) {
    return 'Erro ao limpar as capas: $error';
  }

  @override
  String get storageClearBackupsTitle => 'Limpar backups?';

  @override
  String get storageClearBackupsBody =>
      'Isso vai excluir todos os arquivos de backup locais.\n\nGaranta que você exportou todos os backups importantes antes de continuar.';

  @override
  String get storageClearBackupsAction => 'Limpar backups';

  @override
  String get storageClearBackupsSuccess => 'Backups limpos com sucesso';

  @override
  String storageClearBackupsError(Object error) {
    return 'Erro ao limpar os backups: $error';
  }

  @override
  String get storageClearLibraryTitle => 'Limpar cache da biblioteca?';

  @override
  String get storageClearLibraryBody =>
      'Isso vai limpar o cache da biblioteca.\n\nSua biblioteca de músicas será escaneada novamente na próxima vez que você abrir o app.';

  @override
  String get storageClearLibrarySuccess =>
      'Cache da biblioteca limpo com sucesso';

  @override
  String storageClearLibraryError(Object error) {
    return 'Erro ao limpar o cache da biblioteca: $error';
  }

  @override
  String get storageClearSearchTitle => 'Limpar índice de busca?';

  @override
  String get storageClearSearchBody =>
      'Isso vai excluir o índice de busca.\n\nO índice de busca será reconstruído automaticamente quando você escanear sua biblioteca novamente.';

  @override
  String get storageClearSearchAction => 'Limpar índice';

  @override
  String get storageClearSearchSuccess => 'Índice de busca limpo com sucesso';

  @override
  String storageClearSearchError(Object error) {
    return 'Erro ao limpar o índice de busca: $error';
  }

  @override
  String get storageClearWaveformTitle => 'Limpar cache de formas de onda?';

  @override
  String get storageClearWaveformBody =>
      'Isso vai excluir todas as formas de onda das músicas em cache.\n\nAs formas de onda serão regeneradas na próxima vez que você abrir os detalhes de uma música.';

  @override
  String get storageClearWaveformSuccess =>
      'Cache de formas de onda limpo com sucesso';

  @override
  String storageClearWaveformError(Object error) {
    return 'Erro ao limpar o cache de formas de onda: $error';
  }

  @override
  String get storageClearBeatTitle => 'Limpar análise de batidas?';

  @override
  String get storageClearBeatBody =>
      'Isso vai excluir os mapas de batidas em cache usados pelo player reativo às batidas.\n\nEles são reconstruídos automaticamente na próxima vez que cada música tocar.';

  @override
  String get storageClearBeatSuccess =>
      'Cache de análise de batidas limpo com sucesso';

  @override
  String storageClearBeatError(Object error) {
    return 'Erro ao limpar o cache de análise de batidas: $error';
  }

  @override
  String get storageClearColorTitle => 'Limpar cache de cores?';

  @override
  String get storageClearColorBody =>
      'Isso vai excluir todas as cores de tema em cache.\n\nAs cores serão re-extraídas das capas na próxima vez que as músicas tocarem.';

  @override
  String get storageClearColorSuccess => 'Cache de cores limpo com sucesso';

  @override
  String storageClearColorError(Object error) {
    return 'Erro ao limpar o cache de cores: $error';
  }

  @override
  String get storageClearLyricsTitle => 'Limpar cache de letras?';

  @override
  String get storageClearLyricsBody =>
      'Isso vai remover as buscas de letras em cache.\n\nAs letras serão lidas novamente da metadata da música quando necessário.';

  @override
  String get storageClearLyricsSuccess => 'Cache de letras limpo com sucesso';

  @override
  String storageClearLyricsError(Object error) {
    return 'Erro ao limpar o cache de letras: $error';
  }

  @override
  String get storageClearBlurredTitle => 'Limpar cache de fundos desfocados?';

  @override
  String get storageClearBlurredBody =>
      'Isso vai excluir todos os fundos desfocados pré-gerados.\n\nEles serão regerados na próxima vez que você acionar uma reconstrução no Indexador.';

  @override
  String get storageClearBlurredSuccess =>
      'Cache de fundos desfocados limpo com sucesso';

  @override
  String storageClearBlurredError(Object error) {
    return 'Erro ao limpar o cache de desfoque: $error';
  }

  @override
  String get storageClearAllTitle => 'Limpar todos os dados do app?';

  @override
  String get storageClearAllBody =>
      'Essa ação é perigosa e não pode ser desfeita.\n\nEla vai excluir permanentemente:\n• Todas as suas preferências e configurações\n• Estatísticas e histórico de reprodução\n• Capas de músicas em cache\n• Todos os backups locais\n• Cache da biblioteca\n• Índice de busca\n• Cache de formas de onda\n• Cache de letras\n\nO app será redefinido.';

  @override
  String get storageClearAllAction => 'Limpar tudo';

  @override
  String storageClearAllError(Object error) {
    return 'Erro ao limpar os dados: $error';
  }

  @override
  String get storageClearAllTile => 'Limpar todos os dados do usuário';

  @override
  String get storageClearAllTileSubtitle =>
      'Excluir permanentemente todos os dados e redefinir o app';

  @override
  String get storageFinalConfirmTitle => 'Confirmação final';

  @override
  String storageConfirmTypePrompt(Object word) {
    return 'Para confirmar, digite \"$word\" abaixo:';
  }

  @override
  String get storageDeleteKeyword => 'EXCLUIR';

  @override
  String get storageConfirmUpper => 'CONFIRMAR';

  @override
  String get storageTypeExactly => 'Digite o texto de confirmação exatamente.';

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
  String get settingsSearchIndexerSubtitle => 'Reconstruir índices e caches';

  @override
  String get settingsSearchMusicFoldersTitle => 'Pastas de música';

  @override
  String get settingsSearchMusicFoldersSubtitle =>
      'Gerenciar as pastas da biblioteca de músicas';

  @override
  String get settingsSearchRescanTitle => 'Escanear biblioteca agora';

  @override
  String get settingsSearchRescanSubtitle =>
      'Atualizar manualmente todas as músicas do disco';

  @override
  String get settingsSearchIncludeVideosTitle => 'Incluir vídeos';

  @override
  String get settingsSearchIncludeVideosSubtitle =>
      'Mostrar arquivos de vídeo na sua biblioteca de músicas';

  @override
  String get settingsSearchMinFileSizeTitle => 'Tamanho mínimo do arquivo';

  @override
  String get settingsSearchMinFileSizeSubtitle =>
      'Ignorar arquivos menores que isso';

  @override
  String get settingsSearchMinDurationTitle => 'Duração mínima';

  @override
  String get settingsSearchMinDurationSubtitle =>
      'Ignorar faixas mais curtas que isso';

  @override
  String get settingsSearchManageFoldersTitle => 'Gerenciar pastas de música';

  @override
  String get settingsSearchManageFoldersSubtitle =>
      'Adicionar, remover e escanear pastas individuais';

  @override
  String get settingsSearchPullToRefreshTitle => 'Puxar para atualizar';

  @override
  String get settingsSearchPullToRefreshSubtitle =>
      'Deslizar para baixo para atualizar a biblioteca';

  @override
  String get settingsSearchAutoPauseMuteTitle => 'Pausar ao silenciar';

  @override
  String get settingsSearchAutoPauseMuteSubtitle =>
      'Pausar a reprodução quando o volume chegar a 0';

  @override
  String get settingsSearchAutoResumeUnmuteTitle => 'Retomar ao reativar o som';

  @override
  String get settingsSearchAutoResumeUnmuteSubtitle =>
      'Retomar a reprodução quando o volume for restaurado';

  @override
  String get settingsSearchGapTitle => 'Intervalo / Atraso';

  @override
  String get settingsSearchGapSubtitle => 'Silêncio entre as faixas';

  @override
  String get settingsSearchFadeOutTitle => 'Fade de saída';

  @override
  String get settingsSearchFadeOutSubtitle => 'Fade na faixa que sai';

  @override
  String get settingsSearchFadeInTitle => 'Fade de entrada';

  @override
  String get settingsSearchFadeInSubtitle => 'Fade na faixa que entra';

  @override
  String get settingsSearchFadePlayTitle => 'Fade ao tocar';

  @override
  String get settingsSearchFadePlaySubtitle =>
      'Aumentar o volume gradualmente quando a reprodução começa';

  @override
  String get settingsSearchFadePauseTitle => 'Fade ao pausar';

  @override
  String get settingsSearchFadePauseSubtitle =>
      'Diminuir o volume gradualmente quando a reprodução para';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Idioma para o qual traduzir as letras';

  @override
  String get settingsSearchTranslationModeSubtitle =>
      'Mostrar subtexto abaixo das letras ou substituir as letras base';

  @override
  String get settingsSearchVisualizerSubtitle =>
      'Desativado, barras clássicas ou barras sincronizadas com a música';

  @override
  String get settingsSearchLanguageSubtitle => 'Escolha o idioma do app';

  @override
  String get settingsSearchProgressBarSubtitle =>
      'Barra de progresso padrão, de forma de onda ou reativa ao som';

  @override
  String get settingsSearchSongDurationTitle => 'Mostrar duração da música';

  @override
  String get settingsSearchSongDurationSubtitle =>
      'Exibir a duração nas listas de músicas';

  @override
  String get settingsSearchAutoHideBarsTitle =>
      'Ocultar barras automaticamente';

  @override
  String get settingsSearchAutoHideBarsSubtitle =>
      'O cabeçalho e a barra inferior se ocultam ao rolar para baixo';

  @override
  String get settingsSearchAppIconSubtitle => 'Escolha qual ícone o wispie usa';

  @override
  String get settingsSearchBeatCoverSubtitle =>
      'A capa pulsa com a batida (somente player clássico)';

  @override
  String get settingsSearchSpinArtworkSubtitle =>
      'A capa gira na barra inferior minimizada enquanto uma música toca';

  @override
  String get settingsSearchCoverIntensitySubtitle =>
      'Quão fortemente a capa reage à batida';

  @override
  String get settingsSearchParticleDensitySubtitle =>
      'Quantas partículas e quão vivas elas são';

  @override
  String get settingsSearchBeatOffsetSubtitle =>
      'Compensar a latência de saída do Bluetooth';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Mostrar recomendações de escolhas rápidas';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Mostrar filas tocadas recentemente';

  @override
  String get settingsSearchForYouSubtitle => 'Mostrar playlists recomendadas';

  @override
  String get settingsSearchQuickActionsSubtitle =>
      'Personalizar ações de pressionar e segurar';

  @override
  String get settingsSearchReorderQuickActionsTitle =>
      'Reordenar ações rápidas';

  @override
  String get settingsSearchReorderQuickActionsSubtitle =>
      'Escolher e ordenar as ações de pressionar e segurar em uma música';

  @override
  String get settingsSearchBulkRenameTitle => 'Renomear arquivos em massa';

  @override
  String get settingsSearchBulkRenameSubtitle =>
      'Renomear toda a biblioteca a partir de um formato';

  @override
  String get settingsSearchManageStorageSubtitle =>
      'Uso de disco e gerenciamento de dados';

  @override
  String get settingsSearchBackupsSubtitle =>
      'Navegar, restaurar e excluir backups salvos';

  @override
  String get settingsSearchStorageUsageSubtitle =>
      'Uso de disco por capas, formas de onda, letras e caches';

  @override
  String get settingsCrumbStorage => 'Configurações › Armazenamento';

  @override
  String get settingsCrumbLibrary => 'Configurações › Biblioteca';

  @override
  String get settingsCrumbLibraryFilters =>
      'Configurações › Biblioteca › Filtros';

  @override
  String get settingsCrumbLibraryFolders =>
      'Configurações › Biblioteca › Pastas de música';

  @override
  String get settingsCrumbLibraryMaintenance =>
      'Configurações › Biblioteca › Manutenção';

  @override
  String get settingsCrumbPlaybackAudio => 'Configurações › Reprodução › Áudio';

  @override
  String get settingsCrumbPlaybackTransitions =>
      'Configurações › Reprodução › Transições';

  @override
  String get settingsCrumbPlaybackPlayPause =>
      'Configurações › Reprodução › Tocar / Pausar';

  @override
  String get settingsCrumbLyricsTiming =>
      'Configurações › Letras › Exibição e sincronização';

  @override
  String get settingsCrumbLyricsTranslation =>
      'Configurações › Letras › Tradução';

  @override
  String get settingsCrumbAppearanceLanguage =>
      'Configurações › Aparência › Idioma';

  @override
  String get settingsCrumbAppearanceNowPlaying =>
      'Configurações › Aparência › Tocando agora';

  @override
  String get settingsCrumbAppearanceAppIcon =>
      'Configurações › Aparência › Ícone do app';

  @override
  String get settingsCrumbAppearanceMotion =>
      'Configurações › Aparência › Movimento do player';

  @override
  String get settingsCrumbAppearanceLists =>
      'Configurações › Aparência › Listas e navegação';

  @override
  String get settingsCrumbHomeLists =>
      'Configurações › Início e navegação › Listas e navegação';

  @override
  String get settingsCrumbHomeScreen =>
      'Configurações › Início e navegação › Tela inicial';

  @override
  String get settingsCrumbBackup => 'Configurações › Backup e restauração';

  @override
  String get settingsCrumbAutoBackups =>
      'Configurações › Backup e restauração › Backups automáticos';

  @override
  String get settingsCrumbManageBackups =>
      'Configurações › Gerenciamento de dados › Gerenciar backups';

  @override
  String get settingsCrumbManageStorage =>
      'Configurações › Gerenciamento de dados › Gerenciar armazenamento';

  @override
  String get settingsCrumbProfileShuffle => 'Perfil › Aleatório';

  @override
  String get settingsKwLibrary =>
      'escaneamento,pastas,filtros,músicas,biblioteca';

  @override
  String get settingsKwPlayback => 'áudio,som,transições,reprodução';

  @override
  String get settingsKwLyrics => 'letras,traduzir,karaokê,legendas';

  @override
  String get settingsKwHome => 'início,escolhas rápidas,gestos,barras,layout';

  @override
  String get settingsKwStorage => 'disco,espaço,cache,indexador,limpeza';

  @override
  String get settingsKwAppearance => 'tema,cor,exibição,visual,aparência';

  @override
  String get settingsKwSync => 'nuvem,conta,dispositivos,criptografado';

  @override
  String get settingsKwBackup => 'backup,restaurar,exportar,importar,dados';

  @override
  String get settingsKwIndexer => 'índice,reconstruir,cache,reindexar';

  @override
  String get settingsKwAbout =>
      'versão,atualização,notas de lançamento,lançamento';

  @override
  String get settingsKwFolders => 'diretório,caminho,adicionar pasta,fontes';

  @override
  String get settingsKwRescan => 'atualizar,recarregar,sincronizar';

  @override
  String get settingsKwVideos => 'vídeo,mp4,clipes';

  @override
  String get settingsKwMinFileSize => 'tamanho,ignorar,pequeno,filtro';

  @override
  String get settingsKwMinDuration => 'duração,curto,ignorar,filtro,interlúdio';

  @override
  String get settingsKwManageFolders =>
      'pasta,diretório,armazenamento,cartão sd';

  @override
  String get settingsKwPullToRefresh => 'deslizar,gesto,recarregar';

  @override
  String get settingsKwMute => 'volume,silencioso,mudo';

  @override
  String get settingsKwUnmute => 'volume,ativar som,continuar';

  @override
  String get settingsKwGap => 'pausa,silêncio,entre,transição';

  @override
  String get settingsKwCrossfade =>
      'crossfade,sem intervalos,transição,mistura';

  @override
  String get settingsKwFadePlay => 'aumento gradual,volume,início';

  @override
  String get settingsKwFadePause => 'diminuição gradual,volume,parar';

  @override
  String get settingsKwRichSync =>
      'letras,richsync,karaokê,palavra,sincronização';

  @override
  String get settingsKwSidebar => 'barra lateral,painel,desktop,fila,letras';

  @override
  String get settingsKwKeepAwake => 'sono,manter ativo,tela,letras';

  @override
  String get settingsKwAutoTranslate =>
      'traduzir,tradução,idioma,letras,automático';

  @override
  String get settingsKwTargetLang => 'traduzir,idioma,espanhol,inglês,japonês';

  @override
  String get settingsKwTranslationMode =>
      'traduzir,modo,subtexto,substituir,exibição';

  @override
  String get settingsKwVisualizer =>
      'onda,animação,espectro,barras,sincronização,grave';

  @override
  String get settingsKwLanguage => 'idioma,região,tradução,inglês';

  @override
  String get settingsKwProgressBar => 'buscar,progresso,onda,reativo,espectro';

  @override
  String get settingsKwHaptics =>
      'vibrar,tátil,retorno,forma de onda,arrastar,buscar';

  @override
  String get settingsKwSongDuration => 'duração,tempo,listas';

  @override
  String get settingsKwAutoHide => 'navegação,dock,cabeçalho,rolagem,ocultar';

  @override
  String get settingsKwCoverSizing => 'capa,arte do álbum,proporção,corte';

  @override
  String get settingsKwImmersive =>
      'imersivo,tela cheia,player,detalhe,gradiente,capa,design';

  @override
  String get settingsKwAppIcon => 'ícone,logo,iniciador,dock,clássico,novo';

  @override
  String get settingsKwBeatCover => 'pulso,batida,capa,movimento';

  @override
  String get settingsKwSpinArtwork => 'girar,rotacionar,rodar,capa,dock,mini';

  @override
  String get settingsKwBeatParticles =>
      'partículas,flutuantes,batida,movimento';

  @override
  String get settingsKwCoverIntensity =>
      'capa,álbum,pulso,sutil,equilibrado,intenso';

  @override
  String get settingsKwParticleDensity =>
      'partículas,flutuantes,densidade,sutil,equilibrado,intenso';

  @override
  String get settingsKwBeatOffset =>
      'bluetooth,latência,atraso,sincronização,antecipado';

  @override
  String get settingsKwCalibrate =>
      'calibrar,sincronização,latência,deslocamento,teste,clique';

  @override
  String get settingsKwQuickPicks => 'início,recomendações,sugestões';

  @override
  String get settingsKwRecentQueues => 'início,histórico,fila';

  @override
  String get settingsKwForYou => 'início,mixes,recomendações';

  @override
  String get settingsKwQuickActions => 'pressionar longo,menu,atalhos';

  @override
  String get settingsKwReorderQuickActions =>
      'pressionar longo,ordem,menu,atalhos';

  @override
  String get settingsKwExport => 'backup,salvar,exportar';

  @override
  String get settingsKwImport => 'restaurar,carregar,importar';

  @override
  String get settingsKwManageBackups => 'backup,restaurar,excluir';

  @override
  String get settingsKwBulkRename =>
      'renomear,nomes de arquivo,lote,massa,formato,nomenclatura';

  @override
  String get settingsKwManageStorage => 'disco,espaço,cache,limpeza';

  @override
  String get settingsKwBackups => 'backup,restaurar,arquivo';

  @override
  String get settingsKwStorageUsage => 'disco,espaço,limpar cache,uso';

  @override
  String get settingsKwAutoBackup => 'agenda,frequência,automático';

  @override
  String get settingsKwAutoBackupContent => 'conteúdo,categorias,automático';

  @override
  String get settingsKwAutoDelete => 'poda,limpeza,retenção,antigo';

  @override
  String get settingsKwShuffle =>
      'embaralhar,personalidade,pesos,aleatório,explorador';

  @override
  String get setupUnableToAccessFolder =>
      'Não foi possível acessar a pasta selecionada';

  @override
  String get setupStoragePermissionRequired =>
      'A permissão de armazenamento é necessária para escanear sua biblioteca de músicas.';

  @override
  String get setupEnterDisplayName => 'Digite um nome de exibição';

  @override
  String setupSetupError(String error) {
    return 'Erro de configuração: $error';
  }

  @override
  String get setupIntroTagline => 'Sua música fica no seu dispositivo.';

  @override
  String get setupGetStarted => 'Começar';

  @override
  String get setupPreviousStep => 'Etapa anterior';

  @override
  String get setupSettingThingsUp => 'Configurando tudo';

  @override
  String get setupStartListening => 'Começar a ouvir';

  @override
  String get setupContinue => 'Continuar';

  @override
  String get setupNameTitle => 'Como devemos chamar você?';

  @override
  String get setupNameSubtitle =>
      'O wispie usa seu nome para cumprimentar você e assinar seu histórico de audição. Nada sai deste dispositivo de qualquer forma.';

  @override
  String get setupNameHint => 'Seu nome';

  @override
  String setupGreeting(String name) {
    return 'Prazer em conhecer você, $name.';
  }

  @override
  String get setupAppearanceTitle => 'Deixe com a aparência que você preferir.';

  @override
  String get setupAppearanceSubtitle =>
      'Tudo nesta página também fica nas Configurações, então você pode mudar quando quiser.';

  @override
  String get setupImmersiveSubtitle =>
      'Um player de capa em tela cheia e telas de detalhes com gradiente.';

  @override
  String get setupVisualizerSubtitle =>
      'Barras sobre a capa enquanto você ouve. Sincronizado acompanha a música em vez de um padrão aleatório.';

  @override
  String get setupBeatCoverSubtitle => 'A capa respira a cada batida.';

  @override
  String get setupParticlesSubtitle =>
      'Partículas flutuam pelo player, e cada batida as impulsiona mais em vez de apenas piscá-las.';

  @override
  String get setupProgressBarTitle => 'Barra de progresso';

  @override
  String get setupProgressBarSubtitle =>
      'Desenhe a própria música como uma forma de onda em vez de uma linha simples. Som reativo faz ela se mover enquanto toca.';

  @override
  String get setupFoldersTitle => 'Onde está sua música?';

  @override
  String get setupFoldersSubtitle =>
      'Aponte o wispie para as pastas onde suas músicas estão. Ele apenas as lê, e você pode adicionar quantas quiser.';

  @override
  String get setupStoragePermissionTitle => 'Permissão de armazenamento';

  @override
  String get setupStoragePermissionSubtitle =>
      'O wispie precisa dela para encontrar arquivos de áudio neste dispositivo.';

  @override
  String get setupOpenSystemSettings => 'Abrir configurações do sistema';

  @override
  String get setupGrantPermission => 'Conceder permissão';

  @override
  String get setupNoFoldersTitle => 'Nenhuma pasta ainda';

  @override
  String get setupNoFoldersSubtitle =>
      'Adicione a pasta que contém suas músicas.';

  @override
  String get setupRemoveFolderTooltip => 'Remover pasta';

  @override
  String get setupAddFolder => 'Adicionar uma pasta';

  @override
  String get setupSummaryMusicFolders => 'Pastas de música';

  @override
  String get setupReadyTitle => 'Tudo pronto.';

  @override
  String setupReadyTitleNamed(String name) {
    return 'Tudo pronto, $name.';
  }

  @override
  String get setupReadySubtitle =>
      'Aqui está o que configuramos. Você pode alterar qualquer coisa depois nas Configurações.';

  @override
  String get setupOn => 'Ativado';

  @override
  String get setupOff => 'Desativado';

  @override
  String backupLoadError(Object error) {
    return 'Erro ao carregar backups: $error';
  }

  @override
  String backupCreated(Object name) {
    return 'Backup criado: $name';
  }

  @override
  String backupCreateFailed(Object error) {
    return 'Falha ao criar backup: $error';
  }

  @override
  String backupValidateFailed(Object error) {
    return 'Falha ao validar backup: $error';
  }

  @override
  String get backupReplaceTitle => 'PERIGO: Substituição total dos dados';

  @override
  String backupReplaceConfirm(Object name) {
    return 'Tem certeza absoluta de que deseja restaurar de $name?';
  }

  @override
  String get backupReplaceWarning =>
      'AVISO: Isso vai SUBSTITUIR COMPLETAMENTE todos os seus dados atuais:';

  @override
  String get backupReplaceItemStats =>
      '• Todas as suas estatísticas atuais e histórico de reprodução';

  @override
  String get backupReplaceItemFavorites =>
      '• Todos os seus favoritos e playlists';

  @override
  String get backupReplaceItemHidden =>
      '• Todas as suas músicas ocultas e preferências';

  @override
  String get backupReplaceItemSettings =>
      '• Todas as suas configurações e estado atuais';

  @override
  String get backupReplaceItemLibrary =>
      '• Sua biblioteca de músicas escaneada';

  @override
  String get backupReplaceRekeyNote =>
      'As capas e os caminhos de arquivo são revinculados a este dispositivo automaticamente após a restauração. As faixas do backup cujos arquivos não estão neste dispositivo são removidas da biblioteca.';

  @override
  String get backupReplaceIrreversible =>
      'SEUS DADOS ATUAIS SERÃO PERDIDOS PERMANENTEMENTE!';

  @override
  String get backupReplaceNoUndo =>
      'Não há NENHUMA forma de desfazer esta ação.';

  @override
  String get backupReplaceConfirmAction => 'SIM, SUBSTITUIR TUDO';

  @override
  String get backupRestoringLabel => 'Restaurando dados…';

  @override
  String get backupRestoreSuccess =>
      'Todos os dados foram substituídos com sucesso!';

  @override
  String backupRestoreFailed(Object error) {
    return 'Falha ao restaurar backup: $error';
  }

  @override
  String get backupDeleteTitle => 'Excluir backup';

  @override
  String backupDeleteConfirm(Object name) {
    return 'Tem certeza de que deseja excluir $name?';
  }

  @override
  String get backupDeleteUpper => 'EXCLUIR';

  @override
  String get backupDeleted => 'Backup excluído';

  @override
  String backupDeleteFailed(Object error) {
    return 'Falha ao excluir backup: $error';
  }

  @override
  String backupExportedTo(Object path) {
    return 'Backup exportado para: $path';
  }

  @override
  String get backupNoOlderBackup => 'Não há backup mais antigo para comparar.';

  @override
  String get backupComparing => 'Comparando backups...';

  @override
  String backupComparisonTitle(int number) {
    return 'Comparação com #$number';
  }

  @override
  String get backupDiffStatsRows => 'Linhas de estatísticas';

  @override
  String get backupDiffSize => 'Tamanho';

  @override
  String get backupDiffDataAdded => 'Dados adicionados';

  @override
  String get backupCloseUpper => 'FECHAR';

  @override
  String backupCompareError(Object error) {
    return 'Erro ao comparar backups: $error';
  }

  @override
  String get backupNoChange => 'Sem alterações';

  @override
  String get backupManagementTitle => 'Gerenciamento de backups';

  @override
  String get backupCreating => 'Criando...';

  @override
  String get backupCreateAction => 'Criar backup';

  @override
  String get backupEmptyTitle => 'Nenhum backup ainda';

  @override
  String get backupEmptySubtitle =>
      'Crie seu primeiro backup para proteger seus dados';

  @override
  String backupSizeLabel(Object size) {
    return 'Tamanho: $size';
  }

  @override
  String get backupActionRestore => 'Restaurar';

  @override
  String get backupActionCompare => 'Comparar';

  @override
  String get backupRestartTitle => 'Reinicialização necessária';

  @override
  String get backupRestartMessage =>
      'A restauração do backup foi concluída com sucesso.\n\nO app precisa ser reiniciado para aplicar todas as alterações corretamente.';

  @override
  String get backupRestartNow => 'Reiniciar agora';

  @override
  String get backupSelectContentSubtitle => 'Selecione o conteúdo do backup';

  @override
  String get backupContentArtistArtCache => 'Cache de imagens de artistas';

  @override
  String get backupContentAlbumArtCache => 'Cache de capas de álbum';

  @override
  String get backupContentDescUserStats =>
      'Histórico de reprodução, estatísticas, grupos mesclados';

  @override
  String get backupContentDescUserData => 'Favoritos, playlists, preferências';

  @override
  String get backupContentDescUserSettings =>
      'Tema, ordem de classificação, preferências do app';

  @override
  String get backupContentDescCoverCache => 'Capas de álbum em cache';

  @override
  String get backupContentDescLibraryCache => 'Metadata em cache';

  @override
  String get backupContentDescSearchIndex => 'Banco de dados de busca';

  @override
  String get backupContentDescWaveformCache => 'Dados de forma de onda';

  @override
  String get backupContentDescColorCache => 'Paletas de cores';

  @override
  String get backupContentDescLyricsCache => 'Letras em cache';

  @override
  String get backupContentDescArtistArtCache => 'Imagens de artistas em cache';

  @override
  String get backupContentDescAlbumArtCache => 'Imagens de álbuns em cache';

  @override
  String get backupRestoringDataTitle => 'Restaurando dados';

  @override
  String get importSelectTitle => 'Selecione os dados a restaurar';

  @override
  String get importSectionCache => 'Cache';

  @override
  String get importOptionsTitle => 'Opções de restauração';

  @override
  String get importReplaceDatabases => 'Substituir bancos de dados';

  @override
  String get importReplaceDatabasesSubtitle =>
      'Limpar os dados existentes antes de restaurar';

  @override
  String get syncEnterPassword => 'Digite sua senha';

  @override
  String syncAuthUnexpectedError(String error) {
    return 'Algo deu errado: $error';
  }

  @override
  String get syncUsernameTaken => 'Esse nome de usuário já está em uso';

  @override
  String get syncModeRecover => 'Recuperar';

  @override
  String get syncUsername => 'Nome de usuário';

  @override
  String get syncEncryptionWarning =>
      'Seus dados são criptografados de ponta a ponta. Se você perder a senha e a chave de recuperação, eles não poderão ser recuperados.';

  @override
  String get syncSecuringAccount => 'Protegendo sua conta...';

  @override
  String get syncCreateAccount => 'Criar conta';

  @override
  String get syncLogIn => 'Entrar';

  @override
  String get syncRecoverAccount => 'Recuperar conta';

  @override
  String get syncHideAdvanced => 'Ocultar avançado';

  @override
  String get syncAdvanced => 'Avançado';

  @override
  String get syncRecoveryKeySaved => 'Chave de recuperação salva';

  @override
  String get syncCouldNotSaveFile => 'Não foi possível salvar o arquivo';

  @override
  String get syncRecoveryKeyRevealTitle => 'Sua chave de recuperação';

  @override
  String get syncRecoveryKeyRevealBody =>
      'Esta é a única forma de recuperar o acesso se você esquecer sua senha. Ela é mostrada uma única vez. Guarde-a em um lugar seguro.';

  @override
  String get syncCopied => 'Copiado';

  @override
  String get syncCopy => 'Copiar';

  @override
  String get syncSaveToFile => 'Salvar em arquivo';

  @override
  String get syncRecoveryKeySavedCheckbox =>
      'Salvei minha chave de recuperação';

  @override
  String get syncUploadTitle => 'Envie os dados da sua biblioteca';

  @override
  String get syncSetupDeviceTitle => 'Configurar este dispositivo';

  @override
  String get syncFreshAccountBody =>
      'A sincronização automática é ativada depois que seus dados são enviados uma vez.';

  @override
  String get syncChooseDeviceBody =>
      'Escolha como este dispositivo entra nos seus dados na nuvem. A sincronização automática é ativada depois desta etapa.';

  @override
  String get syncEverythingNow => 'Sincronizar tudo agora';

  @override
  String get syncMergeWithCloud => 'Mesclar este dispositivo com a nuvem';

  @override
  String get syncSetupNewDevice => 'Configurar como novo dispositivo';

  @override
  String get syncMergeExplanation =>
      'Mesclar mantém os dois lados. Configurar como novo dispositivo apaga primeiro os dados sincronizados deste dispositivo e é mais seguro se este dispositivo já guarda uma cópia mais antiga do mesmo histórico.';

  @override
  String get syncCloudReplacedTitle => 'Os dados na nuvem foram substituídos';

  @override
  String get syncCloudReplacedBody =>
      'Outro dispositivo sobrescreveu a nuvem. A sincronização está pausada neste dispositivo até você escolher.';

  @override
  String get syncMergeIntoCloud =>
      'Mesclar este dispositivo nos novos dados da nuvem';

  @override
  String get syncPhaseSigningIn => 'Entrando...';

  @override
  String get syncPhaseCheckingCloud => 'Verificando a nuvem...';

  @override
  String get syncPhaseDownloadingBackup => 'Baixando backup...';

  @override
  String get syncPhaseApplyingBackup => 'Aplicando backup...';

  @override
  String get syncPhaseDownloadingChanges => 'Baixando alterações...';

  @override
  String get syncPhaseMerging => 'Mesclando...';

  @override
  String get syncPhasePreparingUpload => 'Preparando o envio...';

  @override
  String get syncPhaseEncrypting => 'Criptografando...';

  @override
  String get syncPhaseUploading => 'Enviando...';

  @override
  String get syncPhaseFinishing => 'Finalizando...';

  @override
  String get syncPhaseError => 'Falha na sincronização';

  @override
  String get syncSyncing => 'Sincronizando...';

  @override
  String syncServerInfo(String name, String version) {
    return '$name - API v$version';
  }

  @override
  String syncServerInfoClosed(String name, String version) {
    return '$name - API v$version - registro fechado';
  }

  @override
  String get syncServerUnreachable => 'Não foi possível alcançar o servidor';

  @override
  String get syncInsecureHttpWarning =>
      'http simples: use apenas em uma rede privada confiável';

  @override
  String get syncServerUrl => 'URL do servidor';

  @override
  String get syncChecking => 'Verificando...';

  @override
  String get syncCheckServer => 'Verificar servidor';

  @override
  String get syncResetDefault => 'Restaurar padrão';

  @override
  String get autoBackupRunningTitle => 'Fazendo backup';

  @override
  String get autoBackupRunningSubtitle => 'Criando backup...';

  @override
  String get autoBackupCompleteTitle => 'Backup automático concluído';

  @override
  String get autoBackupSaved => 'Backup salvo';

  @override
  String get autoBackupFailedTitle => 'Falha no backup automático';

  @override
  String get autoBackupPermissionTitle => 'Permissão necessária';

  @override
  String get autoBackupPermissionSubtitle =>
      'O backup automático precisa de acesso ao armazenamento';

  @override
  String get autoBackupGrant => 'Conceder';

  @override
  String get downgradeTitle => 'Versão mais antiga detectada';

  @override
  String downgradeMessage(String previousVersion, String currentVersion) {
    return 'O wispie foi aberto pela última vez em $previousVersion, mas esta é a $currentVersion. Seus dados podem ter sido alterados por uma versão mais recente e podem quebrar ou se perder nesta.';
  }

  @override
  String get downgradeQuit => 'Sair';

  @override
  String get downgradeRiskIt => 'Arriscar';

  @override
  String get indexerSettingsGroupTitle => 'Configurações do indexador';

  @override
  String get indexerPreventDuplicatesTitle => 'Evitar faixas duplicadas';

  @override
  String get indexerPreventDuplicatesSubtitle =>
      'Ocultar músicas com o mesmo nome de arquivo em pastas diferentes';

  @override
  String get indexerExtractFeaturedTitle => 'Extrair artistas participantes';

  @override
  String get indexerExtractFeaturedSubtitle =>
      'Mover artistas com \"ft./feat.\" do título para o campo de artista';

  @override
  String get indexerDatabaseOpsGroupTitle => 'Operações de banco de dados';

  @override
  String get indexerWarnRestart =>
      'Esta operação exige reiniciar o app para aplicar as alterações.';

  @override
  String get indexerCoverSearchGroupTitle => 'Capa e busca';

  @override
  String get indexerWarnRepairLinks =>
      'As faixas cujos arquivos não estão mais neste dispositivo serão removidas da biblioteca. Favoritos, playlists e contagens de reprodução são mantidos e se reconectam se os arquivos voltarem.';

  @override
  String get indexerWarnSearchRestart =>
      'Talvez seja preciso reiniciar o app para que as alterações no índice de busca sejam aplicadas por completo.';

  @override
  String get indexerContentCachesGroupTitle => 'Caches de conteúdo';

  @override
  String get indexerRecommendationsGroupTitle => 'Recomendações';

  @override
  String get indexerTitle => 'Indexador';

  @override
  String indexerArtistsAlbumsProgress(String artists, String albums) {
    return 'Artistas $artists · Álbuns $albums...';
  }

  @override
  String indexerProcessing(String progress) {
    return 'Processando $progress...';
  }

  @override
  String get indexerUnknownError => 'Erro desconhecido';

  @override
  String get indexerCompleted => 'Concluído';

  @override
  String indexerCached(int processed, int total) {
    return '$processed/$total em cache';
  }

  @override
  String indexerCachedFailed(int processed, int total, int failed) {
    return '$processed/$total em cache ($failed com falha)';
  }

  @override
  String get indexerReadyToRebuild => 'Pronto para reconstruir';

  @override
  String indexerArtistsOnly(String progress) {
    return 'Artistas $progress';
  }

  @override
  String indexerAlbumsOnly(String progress) {
    return 'Álbuns $progress';
  }

  @override
  String indexerFailedItemsQuestion(int failed) {
    return 'Este cache tem $failed itens com falha. O que você deseja fazer?';
  }

  @override
  String indexerViewFailed(int failed) {
    return 'Ver $failed com falha';
  }

  @override
  String get indexerRetryFailed => 'Tentar novamente os que falharam';

  @override
  String get indexerForceRebuild => 'Forçar reconstrução';

  @override
  String indexerAlreadyCompleteQuestion(int processed, int total) {
    return 'Este cache já está completo ($processed/$total). Você quer forçar a reconstrução?';
  }

  @override
  String get indexerDoIt => 'Fazer isso';

  @override
  String indexerOptimizing(String name) {
    return 'Otimizando $name...';
  }

  @override
  String get indexerDoNotClose => 'Não feche o app';

  @override
  String get indexerRestartRequiredMessage =>
      'A operação foi concluída com sucesso.\n\nO app precisa ser reiniciado para aplicar todas as alterações corretamente.';

  @override
  String indexerFailedItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens com falha',
      one: '1 item com falha',
    );
    return '$_temp0';
  }

  @override
  String get indexerCouldNotProcess =>
      'Os itens a seguir não puderam ser processados:';

  @override
  String indexerWarningsTitle(String name) {
    return 'Avisos de $name';
  }

  @override
  String get indexerOk => 'OK';

  @override
  String get indexerJustMissing => 'Apenas ausentes';

  @override
  String get indexerForceAll => 'Forçar todos';

  @override
  String get beatSyncTitle => 'Sincronização de batida';

  @override
  String get beatPlayToCalibrate => 'Toque uma música para calibrar.';

  @override
  String get beatAnalyzing => 'Analisando batidas...';

  @override
  String get beatNoClearBeat => 'Não há batida clara nesta faixa.';

  @override
  String get beatDragInstruction =>
      'Arraste até as explosões de partículas caírem sobre os cliques.';

  @override
  String beatOffsetMs(int value) {
    return '$value ms';
  }

  @override
  String get beatResetToZero => 'Redefinir para 0 ms';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryFoldersTab => 'Pastas';

  @override
  String get libraryNoMusicFolderTitle => 'Nenhuma pasta de música ainda';

  @override
  String get libraryNoMusicFolderMessage =>
      'Selecione uma pasta de música em Início para preencher isto.';

  @override
  String get libraryFolderErrorTitle =>
      'Não foi possível encontrar sua pasta de música';

  @override
  String get libraryLoadErrorTitle => 'Não foi possível carregar a biblioteca';

  @override
  String get libraryOpenFolderErrorTitle => 'Não foi possível abrir a pasta';

  @override
  String get libraryNoMatchesTitle => 'Nenhum resultado';

  @override
  String libraryNoMatchesMessage(String query) {
    return 'Nada na sua biblioteca corresponde a \"$query\".';
  }

  @override
  String libraryFolderNoMatchesMessage(String query) {
    return 'Nada nesta pasta corresponde a \"$query\".';
  }

  @override
  String libraryCollectionNoMatchesMessage(String query) {
    return 'Nada aqui corresponde a \"$query\".';
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
  String get libraryCreateMergeGroupTooltip => 'Criar novo grupo de mesclagem';

  @override
  String get libraryDeletePlaylist => 'Excluir playlist';

  @override
  String get libraryPlaylistOptions => 'Opções da playlist';

  @override
  String get libraryFolderOptions => 'Opções da pasta';

  @override
  String get libraryFilterAllHint => 'Filtrar pastas, playlists, músicas...';

  @override
  String get libraryFilterSongsHint => 'Filtrar pastas, músicas...';

  @override
  String get libraryFilterCollectionsHint => 'Filtrar artistas, álbuns...';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Tudo';

  @override
  String get libraryShuffleFolderTooltip => 'Embaralhar pasta';

  @override
  String get libraryNoArtistsTitle => 'Nenhum artista ainda';

  @override
  String get libraryNoAlbumsTitle => 'Nenhum álbum ainda';

  @override
  String get libraryScanToFillMessage =>
      'Escaneie uma pasta de música para preencher isto.';

  @override
  String get actionClear => 'Limpar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionShuffleAll => 'Embaralhar tudo';

  @override
  String get actionSeeAll => 'Ver tudo';

  @override
  String homeQueueCardSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$date · $_temp0';
  }

  @override
  String homePlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return 'Tocando $_temp0';
  }

  @override
  String get homeOpenPlayer => 'Abrir player';

  @override
  String get homePlayNow => 'Tocar agora';

  @override
  String homePlayAfterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas vão tocar depois da música atual',
      one: '1 faixa vai tocar depois da música atual',
    );
    return '$_temp0';
  }

  @override
  String get homePlayAfterCurrent => 'Tocar depois da música atual';

  @override
  String get homeSaveToNewPlaylist => 'Salvar em nova playlist';

  @override
  String get homeUnpin => 'Desafixar';

  @override
  String get homePinRecommendation => 'Fixar recomendação';

  @override
  String get homeRenameRecommendation => 'Renomear recomendação';

  @override
  String get homeRenameRecommendationTitle => 'Renomear recomendação';

  @override
  String get homeRemoveRecommendation => 'Remover recomendação';

  @override
  String get homeRemoveRecommendationTitle => 'Remover recomendação?';

  @override
  String homeRemoveRecommendationMessage(String title) {
    return 'Tem certeza de que deseja remover \"$title\"?';
  }

  @override
  String get homeErrorTitle => 'Algo deu errado';

  @override
  String get homeTryAgain => 'Tentar novamente';

  @override
  String get homeNoSongsTitle => 'Nenhuma música encontrada';

  @override
  String get homeNoSongsMessage =>
      'Selecione sua pasta de música para começar a ouvir offline.';

  @override
  String get homeSelectFolder => 'Selecionar pasta de música';

  @override
  String get homeQuickPicks => 'Escolhas rápidas';

  @override
  String get homeRecentQueues => 'Filas recentes';

  @override
  String get homeForYou => 'Para você';

  @override
  String get mergedTitle => 'Músicas mescladas';

  @override
  String get mergedCreateGroupTooltip => 'Criar grupo de mesclagem';

  @override
  String mergedGroupsTab(int count) {
    return 'Grupos ($count)';
  }

  @override
  String mergedAutoFindTab(int count) {
    return 'Busca automática ($count)';
  }

  @override
  String mergedCreatedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas mescladas',
      one: '1 música mesclada',
    );
    return '$_temp0';
  }

  @override
  String get mergedEmptyTitle => 'Nenhuma música mesclada ainda';

  @override
  String get mergedEmptyBody =>
      'Agrupe versões diferentes da mesma música (remixes, versões ao vivo, acústicas) para que dividam um só lugar no aleatório.';

  @override
  String get mergedCreateGroupButton => 'Criar grupo de mesclagem';

  @override
  String mergedPrioritySet(String title) {
    return '\"$title\" definida como música prioritária';
  }

  @override
  String get mergedPriorityCleared => 'Prioridade removida';

  @override
  String get mergedNoCandidatesTitle => 'Nenhuma música candidata encontrada';

  @override
  String get mergedNoCandidatesBody =>
      'Nenhuma variante de música não mesclada (remixes, versões ao vivo, acústicas) foi detectada na sua biblioteca.';

  @override
  String mergedFoundGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encontrados $count grupos potenciais para mesclar',
      one: 'Encontrado 1 grupo potencial para mesclar',
    );
    return '$_temp0';
  }

  @override
  String get mergedMergeAll => 'Mesclar tudo';

  @override
  String get mergedMergeAllTitle => 'Mesclar todas as sugestões';

  @override
  String mergedMergeAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Criar $count grupos de mesclagem para as variantes de música detectadas?',
      one: 'Criar 1 grupo de mesclagem para as variantes de música detectadas?',
    );
    return '$_temp0';
  }

  @override
  String mergedCreatedGroupsSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grupos de mesclagem criados',
      one: '1 grupo de mesclagem criado',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeTitle => 'Desmesclar música';

  @override
  String mergedUnmergeConfirm(String title) {
    return 'Remover \"$title\" deste grupo de mesclagem?';
  }

  @override
  String get mergedUnmergeAction => 'Desmesclar';

  @override
  String mergedUnmergedSnack(String title) {
    return '\"$title\" desmesclada';
  }

  @override
  String get mergedDeleteGroupTitle => 'Excluir grupo de mesclagem';

  @override
  String get mergedDeleteGroupConfirm =>
      'Desmesclar todas as músicas deste grupo?';

  @override
  String get mergedUnmergeAllAction => 'Desmesclar tudo';

  @override
  String get mergedGroupDeleted => 'Grupo de mesclagem excluído';

  @override
  String get mergedGroupLabel => 'Grupo de mesclagem';

  @override
  String mergedVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versões',
      one: '1 versão',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeAllTooltip => 'Desmesclar tudo';

  @override
  String get mergedPriorityBadge => 'Prioridade';

  @override
  String get mergedPrioritySongTooltip => 'Música prioritária no aleatório';

  @override
  String get mergedSetPriorityTooltip => 'Definir como música prioritária';

  @override
  String get mergedUnmergeSongTooltip => 'Desmesclar música';

  @override
  String mergedSelectedCount(int selected, int total) {
    return '$selected/$total selecionadas';
  }

  @override
  String get mergedMergeAction => 'Mesclar';

  @override
  String get sleepTimerTitle => 'Temporizador de sono';

  @override
  String get sleepTimerModeLabel => 'Modo do temporizador';

  @override
  String get sleepTimerDurationLabel => 'Duração';

  @override
  String get sleepTimerMinSuffix => 'min';

  @override
  String get sleepTimerTracksLabel => 'Número de faixas';

  @override
  String get sleepTimerLoopTitle => 'Repetir a música atual';

  @override
  String get sleepTimerLoopSubtitle =>
      'Repetir a música atual por um tempo definido';

  @override
  String get sleepTimerPlayForTimeTitle => 'Tocar por um tempo';

  @override
  String get sleepTimerPlayForTimeSubtitle => 'Parar após uma duração definida';

  @override
  String get sleepTimerStopAfterCurrentTitle => 'Parar após a atual';

  @override
  String get sleepTimerStopAfterCurrentSubtitle =>
      'Parar quando a música atual terminar';

  @override
  String get sleepTimerStopAfterTracksTitle => 'Parar após faixas';

  @override
  String get sleepTimerStopAfterTracksSubtitle =>
      'Parar após tocar mais X músicas';

  @override
  String get sleepTimerNoSong => 'Nenhuma música está tocando no momento';

  @override
  String get sleepTimerCurrentSongLabel => 'Música atual';

  @override
  String get sleepTimerLetFinishTitle => 'Deixar a música atual terminar';

  @override
  String get sleepTimerLetFinishSubtitle =>
      'Esperar a música atual terminar antes de parar';

  @override
  String get sleepTimerStopImmediatelySubtitle =>
      'Parar imediatamente quando o temporizador terminar';

  @override
  String get sleepTimerStart => 'Iniciar temporizador';

  @override
  String get sleepTimerCancelActive => 'Cancelar temporizador ativo';

  @override
  String get sleepTimerCancelled => 'Temporizador de sono cancelado';

  @override
  String get sleepTimerFinished => 'Temporizador de sono concluído';

  @override
  String sleepTimerLoopingFor(int minutes) {
    return 'Repetindo a música atual por $minutes minutos';
  }

  @override
  String sleepTimerStopIn(int minutes) {
    return 'A música vai parar em $minutes minutos';
  }

  @override
  String get sleepTimerStopAfterCurrent =>
      'Vai parar quando a música atual terminar';

  @override
  String sleepTimerStopAfterTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vai parar após mais $count músicas',
      one: 'Vai parar após mais 1 música',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchHint => 'Buscar configurações';

  @override
  String get settingsValueNone => 'Nenhum';

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
  String get settingsGroupLookAndFeel => 'Aparência e estilo';

  @override
  String get settingsGroupData => 'Dados';

  @override
  String get settingsGroupApp => 'App';

  @override
  String get settingsGroupFilters => 'Filtros';

  @override
  String get settingsGroupMaintenance => 'Manutenção';

  @override
  String get settingsScanningLibrary => 'Escaneando a biblioteca…';

  @override
  String settingsResultsFor(String query) {
    return 'Resultados para \"$query\"';
  }

  @override
  String get settingsNoResultsTitle => 'Nenhuma configuração encontrada';

  @override
  String settingsNoResultsMessage(String query) {
    return 'Nada corresponde a \"$query\".';
  }

  @override
  String get homeSettingsGroupLists => 'Listas e navegação';

  @override
  String get homeSettingsAutoHideBarsSubtitle =>
      'O cabeçalho e a barra inferior se ocultam ao rolar para baixo e reaparecem ao rolar para cima';

  @override
  String get homeSettingsGroupHome => 'Tela inicial';

  @override
  String get playbackGroupTransitions => 'Transições';

  @override
  String get playbackGroupPlayPause => 'Reproduzir / Pausar';

  @override
  String get playbackGroupAudio => 'Áudio';

  @override
  String get playbackGapOff => 'Intervalo / Atraso (desativado)';

  @override
  String get playbackFadeOutOff => 'Fade de saída (desativado)';

  @override
  String get playbackFadeInOff => 'Fade de entrada (desativado)';

  @override
  String playbackSecondsValue(String seconds) {
    return '${seconds}s';
  }

  @override
  String get playbackValueOneSecond => '1,0 s';

  @override
  String playbackValueMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get bulkRenameTokenCurrentName => 'Nome atual';

  @override
  String get bulkRenameTokenNumber => 'Número';

  @override
  String get bulkRenameTokenYear => 'Ano';

  @override
  String bulkRenameAnalyzeError(String error) {
    return 'Não foi possível analisar a biblioteca: $error';
  }

  @override
  String bulkRenameRenameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Renomear $count músicas',
      one: 'Renomear 1 música',
    );
    return '$_temp0';
  }

  @override
  String get bulkRenameConfirmMessage =>
      'Os arquivos são renomeados no local. Estatísticas de reprodução, playlists e capas em cache vão junto com eles, e o banco de dados é mantido em sincronia conforme cada arquivo é movido.';

  @override
  String get bulkRenameNothingLeft => 'Não há mais nada para renomear';

  @override
  String get bulkRenamePhaseStarting => 'Iniciando';

  @override
  String get bulkRenameTitle => 'Renomeação em massa';

  @override
  String get bulkRenameFormatArtistTitle => 'Artista - Título';

  @override
  String get bulkRenameFormatArtistAlbumTitle => 'Artista - Álbum - Título';

  @override
  String get bulkRenameCustomSubtitle => 'Sua própria organização';

  @override
  String get bulkRenameSectionFormat => 'FORMATO';

  @override
  String get bulkRenameSectionArrange => 'ORGANIZAR';

  @override
  String get bulkRenameSectionPreview => 'PRÉVIA';

  @override
  String get bulkRenameEmptySegments =>
      'Adicione um campo abaixo para começar a montar um nome.';

  @override
  String get bulkRenameLiteralHint => 'Texto, ex.: \" - \"';

  @override
  String get bulkRenameTextChip => 'Texto';

  @override
  String get bulkRenameAnalyzing => 'Analisando a biblioteca';

  @override
  String bulkRenameCountToRename(int count) {
    return '$count para renomear';
  }

  @override
  String bulkRenameSkippedCount(int count) {
    return '$count ignoradas';
  }

  @override
  String bulkRenameAndMore(int count) {
    return 'e mais $count';
  }

  @override
  String bulkRenameChecking(int done, int total) {
    return 'Verificando nomes — $done de $total';
  }

  @override
  String get bulkRenameStop => 'Parar';

  @override
  String get bulkRenameStopping => 'Parando...';

  @override
  String get bulkRenamePleaseWait => 'Aguarde';

  @override
  String bulkRenameProgressCount(int done, int total) {
    return '$done de $total';
  }

  @override
  String bulkRenameStopped(int count) {
    return 'Parou após $count músicas. As estatísticas e as capas em cache foram movidas; as demais foram deixadas como estavam.';
  }

  @override
  String bulkRenameStoppedFailed(int count, int failed) {
    return 'Parou após $count músicas, $failed não puderam ser renomeadas.';
  }

  @override
  String bulkRenameCompleted(int count) {
    return '$count músicas renomeadas. Estatísticas e capas em cache foram movidas.';
  }

  @override
  String bulkRenameCompletedFailed(int count, int failed) {
    return '$count músicas renomeadas, $failed não puderam ser renomeadas.';
  }

  @override
  String get bulkRenameFinishedTitle => 'Renomeação concluída';

  @override
  String get bulkRenameSkipNoTitleText =>
      'Nenhum texto de título restou após a limpeza';

  @override
  String get bulkRenameSkipAlreadyNamed => 'Já estava nomeada assim';

  @override
  String bulkRenameSkipSameNameAs(String filename) {
    return 'Mesmo nome de \"$filename\" nesta pasta';
  }

  @override
  String get bulkRenameSkipAnotherSelected =>
      'Outra música selecionada tem esse nome';

  @override
  String get bulkRenameSkipFileExists =>
      'Já existe um arquivo com esse nome aqui';

  @override
  String get shuffleResetDone => 'Configurações restauradas para o padrão';

  @override
  String get shuffleSaved => 'Configurações salvas';

  @override
  String get shuffleUnsavedTitle => 'Alterações não salvas';

  @override
  String get shuffleUnsavedMessage => 'Deseja salvar suas alterações?';

  @override
  String get shuffleDiscard => 'Descartar';

  @override
  String get shuffleTitle => 'Configurações de aleatório personalizado';

  @override
  String get shuffleReset => 'Redefinir';

  @override
  String get shuffleNextQueueNote =>
      'As alterações serão aplicadas à próxima fila';

  @override
  String get shuffleBasicSettings => 'Configurações básicas';

  @override
  String get shuffleAvoidSongsTitle => 'Evitar repetir músicas';

  @override
  String get shuffleAvoidSongsSubtitle =>
      'Reduz a chance de tocar músicas reproduzidas recentemente';

  @override
  String get shuffleAvoidArtistsTitle => 'Evitar repetir artistas';

  @override
  String get shuffleAvoidArtistsSubtitle =>
      'Reduz a chance de tocar o mesmo artista em sequência';

  @override
  String get shuffleAvoidAlbumsTitle => 'Evitar repetir álbuns';

  @override
  String get shuffleAvoidAlbumsSubtitle =>
      'Reduz a chance de tocar o mesmo álbum em sequência';

  @override
  String get shuffleAdvancedTitle => 'Configurações avançadas';

  @override
  String get shuffleAdvancedSubtitle =>
      'Ajuste fino dos valores de peso individuais';

  @override
  String get shuffleWeightValuesTitle => 'Valores de peso (-99 a +99)';

  @override
  String get shuffleWeightValuesHint =>
      '0 = neutro, negativo = penalidade, positivo = impulso';

  @override
  String get shuffleWeightLeastPlayed => 'Músicas menos tocadas';

  @override
  String get shuffleWeightMostPlayed => 'Músicas mais tocadas';

  @override
  String get shuffleWeightSuggestLess =>
      'Músicas sugeridas com menos frequência';

  @override
  String get shuffleWeightPlaylistSongs => 'Músicas em playlists';

  @override
  String get lyricsGroupDisplayTiming => 'Exibição e sincronização';

  @override
  String get lyricsSimulateWordSyncTitle => 'Simular sincronização por palavra';

  @override
  String get lyricsSimulateWordSyncSubtitle =>
      'Gera a sincronização em nível de palavra a partir de letras sincronizadas por linha usando estimativa prosódica';

  @override
  String get lyricsDesktopSidebarTitle => 'Barra lateral de letras e fila';

  @override
  String get lyricsDesktopSidebarSubtitle =>
      'Mostra a alça de expansão ao passar o mouse para reabrir a barra lateral de letras e fila depois de ocultada';

  @override
  String get lyricsKeepScreenAwakeTitle => 'Manter a tela ligada nas letras';

  @override
  String get lyricsKeepScreenAwakeSubtitle =>
      'Impede a suspensão enquanto o painel de letras estiver aberto';

  @override
  String get lyricsGroupTranslation => 'Tradução';

  @override
  String get lyricsAutoTranslateTitle => 'Traduzir letras automaticamente';

  @override
  String get lyricsAutoTranslateSubtitle =>
      'Traduz as letras automaticamente usando o idioma de destino selecionado';

  @override
  String get lyricsTargetLanguageTitle => 'Idioma de destino';

  @override
  String get lyricsTranslationDisplayTitle => 'Exibição da tradução';

  @override
  String get lyricsTranslationModeReplaceSubtitle =>
      'Substituir as letras originais';

  @override
  String get lyricsTranslationModeSubtextSubtitle =>
      'Mostrar subtexto abaixo das letras';

  @override
  String get lyricsModeSubtext => 'Subtexto abaixo';

  @override
  String get lyricsModeReplace => 'Substituir base';

  @override
  String get lyricsTranslateTitle => 'Traduzir letras';

  @override
  String get lyricsDisplayMode => 'Modo de exibição';

  @override
  String get lyricsModeSubtextDescription => 'Mostrar a tradução sob as letras';

  @override
  String get lyricsModeReplaceDescription =>
      'Substituir as letras originais por completo';

  @override
  String get lyricsAutoTranslateAllTitle =>
      'Traduzir automaticamente todas as músicas';

  @override
  String get lyricsAutoTranslateAllSubtitle =>
      'Traduz as letras automaticamente usando o idioma selecionado';

  @override
  String get lyricsTargetLanguageLabel => 'Idioma de destino';

  @override
  String get lyricsSearchLanguageHint => 'Buscar idioma...';

  @override
  String get lyricsClearCache => 'Limpar cache';

  @override
  String get lyricsTranslateNow => 'Traduzir agora';

  @override
  String get lyricsFindTitle => 'Buscar letras';

  @override
  String get lyricsNoResults =>
      'Nenhuma letra encontrada. Tente outro título ou artista, ou verifique sua conexão.';

  @override
  String get lyricsInstrumentalWarning =>
      'Marcada como instrumental. Aplicar isso apaga qualquer letra armazenada no arquivo.';

  @override
  String get lyricsApplyUpper => 'APLICAR';

  @override
  String get lyricsPlainText => 'Texto simples';

  @override
  String get lyricsUnknownLength => 'Duração desconhecida';

  @override
  String lyricsDurationExactMatch(String duration) {
    return '$duration · correspondência exata';
  }

  @override
  String get lyricsBadgeWordSync => 'SINC. POR PALAVRA';

  @override
  String get lyricsBadgeLineSync => 'SINC. POR LINHA';

  @override
  String get lyricsBadgeInstrumental => 'INSTRUMENTAL';

  @override
  String get lyricsBadgePlain => 'SIMPLES';

  @override
  String get lyricsSaved => 'Letras salvas';

  @override
  String lyricsSaveError(Object error) {
    return 'Não foi possível salvar as letras: $error';
  }

  @override
  String get lyricsTranslationCleared => 'Tradução em cache removida';

  @override
  String get lyricsAlreadyTranslated =>
      'As letras já estão no idioma de destino';

  @override
  String get lyricsTranslated => 'Letras traduzidas';

  @override
  String get lyricsTranslateError => 'Não foi possível traduzir as letras';

  @override
  String lyricsTranslationFailed(Object error) {
    return 'Falha na tradução: $error';
  }

  @override
  String get lyricsHideTimingTooltip => 'Ocultar a sincronização da letra';

  @override
  String get lyricsAdjustTimingTooltip =>
      'Ajustar a sincronização da letra — segure para os controles de precisão';

  @override
  String get lyricsFindOnline => 'Buscar letras online';

  @override
  String get lyricsEmptyTitle => 'Sem letras';

  @override
  String get lyricsEmptySubtitle => 'Esta faixa não tem letras incorporadas.';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languageFrench => 'Francês';

  @override
  String get languageGerman => 'Alemão';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageJapanese => 'Japonês';

  @override
  String get languageChinese => 'Chinês';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageHindi => 'Híndi';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageDutch => 'Holandês';

  @override
  String get languagePolish => 'Polonês';

  @override
  String get languageTurkish => 'Turco';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get languageUkrainian => 'Ucraniano';

  @override
  String get languageSwedish => 'Sueco';

  @override
  String get languageIndonesian => 'Indonésio';

  @override
  String get languageThai => 'Tailandês';

  @override
  String get languageCzech => 'Tcheco';

  @override
  String get languageGreek => 'Grego';

  @override
  String get languageHungarian => 'Húngaro';

  @override
  String get languageRomanian => 'Romeno';

  @override
  String get languageDanish => 'Dinamarquês';

  @override
  String get languageFinnish => 'Finlandês';

  @override
  String get languageNorwegian => 'Norueguês';

  @override
  String get selectSongsTitle => 'Selecionar músicas';

  @override
  String get selectSongsWhatIsMerging => 'O que é mesclar?';

  @override
  String get selectSongsMergedExplanation =>
      'Músicas mescladas são versões diferentes da mesma música:';

  @override
  String get selectSongsBulletVersions =>
      'Como remixes, versões ao vivo ou versões com qualidade diferente';

  @override
  String get selectSongsBulletFavorites =>
      'Favoritos e \"sugerir menos\" são independentes por música';

  @override
  String get selectSongsBulletStats =>
      'Suas contagens de reprodução e estatísticas permanecem inalteradas';

  @override
  String get selectSongsBulletPriority =>
      'Selecione uma música prioritária (⭐) para priorizá-la no modo aleatório';

  @override
  String get selectSongsSearchHint => 'Buscar músicas...';

  @override
  String selectSongsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionadas',
      one: '1 selecionada',
    );
    return '$_temp0';
  }

  @override
  String get selectSongsReadyToMerge => 'Pronto para mesclar';

  @override
  String get selectSongsPrioritySongTooltip => 'Música prioritária';

  @override
  String get selectSongsSetPriorityTooltip => 'Definir como prioritária';

  @override
  String get selectSongsPriorityBadge => 'PRIORITÁRIA';

  @override
  String selectSongsMinSelection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selecione pelo menos $count músicas',
      one: 'Selecione pelo menos 1 música',
    );
    return '$_temp0';
  }

  @override
  String selectSongsMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mesclar $count músicas',
      one: 'Mesclar 1 música',
    );
    return '$_temp0';
  }

  @override
  String selectSongsSelectAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selecionar $count músicas',
      one: 'Selecionar 1 música',
    );
    return '$_temp0';
  }

  @override
  String get foldersAddedSnack => 'Pasta de músicas adicionada';

  @override
  String get foldersRemovedSnack => 'Pasta de músicas removida';

  @override
  String get foldersSubtitle =>
      'Selecione as pastas que contêm seus arquivos de música';

  @override
  String get foldersEmptyTitle => 'Nenhuma pasta adicionada ainda';

  @override
  String get foldersEmptyMessage =>
      'Adicione uma pasta para montar sua biblioteca.';

  @override
  String get foldersAddButton => 'Adicionar pasta';

  @override
  String get foldersShortcutInternalStorage => 'Armazenamento interno';

  @override
  String get foldersShortcutMusic => 'Música';

  @override
  String get foldersShortcutDownload => 'Download';

  @override
  String get foldersShortcutStorageRoot => 'Raiz do armazenamento';

  @override
  String get foldersShortcutDownloads => 'Downloads';

  @override
  String get foldersShortcutDocuments => 'Documentos';

  @override
  String get foldersDoesNotExist => 'A pasta não existe';

  @override
  String get foldersPermissionError =>
      'Permissão negada ou erro ao ler a pasta';

  @override
  String get foldersNewFolderTitle => 'Nova pasta';

  @override
  String get foldersFolderNameLabel => 'Nome da pasta';

  @override
  String get foldersFolderNameHint => 'Digite o nome da pasta';

  @override
  String foldersCreateError(String error) {
    return 'Erro ao criar a pasta: $error';
  }

  @override
  String get foldersGoUp => '.. (Subir)';

  @override
  String get foldersGoBack => '.. (Voltar)';

  @override
  String get foldersNoSubfolders =>
      'Nenhuma subpasta encontrada.\nSelecione esta pasta se ela contém suas músicas.';

  @override
  String get foldersSelectThisFolder => 'Selecionar esta pasta';

  @override
  String get foldersSelectDestination => 'Selecionar pasta de destino';

  @override
  String get foldersEmptyFolder =>
      'Pasta vazia. Você pode selecioná-la abaixo.';

  @override
  String foldersSelected(String name) {
    return 'Selecionada: $name';
  }

  @override
  String get foldersRoot => 'Raiz';

  @override
  String get foldersMoveFolder => 'Mover pasta';

  @override
  String foldersMovedTo(String name, String path) {
    return '$name movida para $path';
  }

  @override
  String foldersMoveError(String error) {
    return 'Erro ao mover a pasta: $error';
  }

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsSearchHint => 'Buscar playlists...';

  @override
  String get playlistsCreate => 'Criar playlist';

  @override
  String get playlistsNoMatches => 'Nenhuma playlist correspondente encontrada';

  @override
  String playlistsCreatedOn(String date) {
    return 'Criada em $date';
  }

  @override
  String get playlistsCreatedToday => 'hoje';

  @override
  String get playlistsCreatedYesterday => 'ontem';

  @override
  String playlistsDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String playlistsWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count semanas',
      one: 'há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String get playlistsEmptyTitle => 'Ainda não há playlists';

  @override
  String get playlistsEmptyMessage => 'Crie sua primeira playlist para começar';

  @override
  String get playlistsNameHint => 'Digite o nome da playlist';

  @override
  String get statsTitle => 'Audição';

  @override
  String get statsLoadErrorTitle =>
      'Não foi possível carregar suas estatísticas';

  @override
  String get statsReadingHistory => 'Lendo seu histórico de audição';

  @override
  String get statsEmptyTitle => 'Ainda não há histórico de audição';

  @override
  String get statsEmptyMessage =>
      'Toque algo e seus hábitos de audição aparecerão aqui.';

  @override
  String get statsSectionOverTime => 'Ao longo do tempo';

  @override
  String get statsSectionWhen => 'Quando você escuta';

  @override
  String get statsSectionTop => 'Seus mais ouvidos';

  @override
  String get statsSectionTaste => 'Gosto';

  @override
  String get statsByHour => 'POR HORA';

  @override
  String get statsByWeekday => 'POR DIA DA SEMANA';

  @override
  String get statsNoListening => 'Nenhuma audição registrada';

  @override
  String statsAcrossPlays(String time, String plays) {
    return '$time em $plays';
  }

  @override
  String get statsLibraryExplored => 'Biblioteca explorada';

  @override
  String get statsPlaysFavourites => 'Reproduções de favoritos';

  @override
  String get statsPlaysSkipped => 'Reproduções puladas';

  @override
  String get statsAvgPlay => 'REPRODUÇÃO MÉDIA';

  @override
  String get statsOnActiveDay => 'EM UM DIA ATIVO';

  @override
  String get statsPlaysPerActiveDay => 'REPRODUÇÕES POR DIA ATIVO';

  @override
  String get statsFirstListen => 'PRIMEIRA AUDIÇÃO';

  @override
  String statsShareOf(String share, String count) {
    return '$share de $count';
  }

  @override
  String get statsTopArtists => 'ARTISTAS MAIS OUVINTES';

  @override
  String get statsTopAlbums => 'ÁLBUNS MAIS OUVIDOS';

  @override
  String get statsTopTracks => 'FAIXAS MAIS OUVIDAS';

  @override
  String get statsTimeListened => 'TEMPO OUVINDO';

  @override
  String statsRangeWithDays(String range, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias com música',
      one: '1 dia com música',
    );
    return '$range · $_temp0';
  }

  @override
  String get statsPlays => 'REPRODUÇÕES';

  @override
  String get statsSkips => 'PULADAS';

  @override
  String get statsTracks => 'FAIXAS';

  @override
  String get statsStreak => 'SEQUÊNCIA';

  @override
  String statsStreakBest(int count) {
    return 'melhor $count';
  }

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias ativos',
      one: '1 dia ativo',
    );
    return '$_temp0';
  }

  @override
  String statsSummary(String duration, String plays, String days) {
    return '$duration · $plays · $days';
  }

  @override
  String get statsEmptyHint => 'Toque algo para começar seu histórico';

  @override
  String get statsLoadError => 'Não foi possível carregar suas estatísticas';

  @override
  String statsDurationMinutes(int minutes) {
    return '${minutes}min';
  }

  @override
  String statsDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get statsSameAsBefore => 'igual a antes';

  @override
  String statsHourTickAm(int hour) {
    return '${hour}a';
  }

  @override
  String statsHourTickPm(int hour) {
    return '${hour}p';
  }

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get actionRefresh => 'Atualizar';

  @override
  String get sessionDetailTitle => 'Detalhes da sessão';

  @override
  String sessionStartedAt(String time) {
    return 'Iniciada às $time';
  }

  @override
  String get sessionSongSingular => 'Música';

  @override
  String get sessionSongsPlayed => 'Músicas tocadas';

  @override
  String get sessionNoSongs => 'Nenhuma música registrada';

  @override
  String get sessionRepeatNow => 'Repetir fila agora';

  @override
  String get sessionNoSongsAvailable => 'Nenhuma música disponível para tocar';

  @override
  String sessionAfterCurrentSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas tocarão depois da música atual',
      one: '1 música tocará depois da música atual',
    );
    return '$_temp0';
  }

  @override
  String sessionPlayingSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tocando $count músicas desta sessão',
      one: 'Tocando 1 música desta sessão',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryTitle => 'Histórico de sessões';

  @override
  String get sessionLoadFailed => 'Falha ao carregar as sessões';

  @override
  String get sessionEmptyTitle => 'Ainda não há sessões';

  @override
  String get sessionEmptyMessage =>
      'Comece a escutar para montar seu histórico de sessões';

  @override
  String get playHistoryTitle => 'Histórico da música';

  @override
  String get playHistoryEmptyTitle => 'Ainda não há histórico de reprodução';

  @override
  String get playHistoryEmptyMessage =>
      'Comece a escutar para montar seu histórico.';

  @override
  String get playHistoryListen => 'Ouvir';

  @override
  String get playHistorySkip => 'Pular';

  @override
  String playHistorySummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
    );
    return '$_temp0 · $duration';
  }

  @override
  String playHistoryDate(String month, int day, int year) {
    return '$day de $month de $year';
  }

  @override
  String get monthShortJan => 'jan';

  @override
  String get monthShortFeb => 'fev';

  @override
  String get monthShortMar => 'mar';

  @override
  String get monthShortApr => 'abr';

  @override
  String get monthShortMay => 'mai';

  @override
  String get monthShortJun => 'jun';

  @override
  String get monthShortJul => 'jul';

  @override
  String get monthShortAug => 'ago';

  @override
  String get monthShortSep => 'set';

  @override
  String get monthShortOct => 'out';

  @override
  String get monthShortNov => 'nov';

  @override
  String get monthShortDec => 'dez';

  @override
  String get searchFieldHint => 'Buscar músicas, artistas, álbuns...';

  @override
  String get searchEmptyTitle => 'Busque na sua coleção de músicas';

  @override
  String get searchEmptyMessage =>
      'Encontre músicas, artistas, álbuns e letras.';

  @override
  String get searchFailed => 'Não foi possível buscar';

  @override
  String searchNoResults(String query) {
    return 'Nenhum resultado encontrado para \"$query\"';
  }

  @override
  String get searchNoResultsHint =>
      'Tente outras palavras-chave ou verifique seus filtros.';

  @override
  String searchArtistsSection(int count) {
    return 'Artistas ($count)';
  }

  @override
  String searchAlbumsSection(int count) {
    return 'Álbuns ($count)';
  }

  @override
  String searchSongsSection(int count) {
    return 'Músicas ($count)';
  }

  @override
  String searchAlbumSubtitle(String artist, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$artist · $_temp0';
  }

  @override
  String get quickActionSuggestMore => 'Sugerir com mais frequência';

  @override
  String get quickActionSuggestLess => 'Sugerir com menos frequência';

  @override
  String get quickActionGoToAlbum => 'Ir para o álbum';

  @override
  String get quickActionGoToArtist => 'Ir para o artista';

  @override
  String get aboutChecking => 'Verificando atualizações…';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Atualização disponível: $version';
  }

  @override
  String get aboutUpToDate => 'Você está atualizado';

  @override
  String get aboutCheckForUpdates => 'Verificar atualizações';

  @override
  String get aboutCheckingSubtitle =>
      'O wispie está verificando o GitHub Releases.';

  @override
  String get aboutUpdateAvailableSubtitle =>
      'Uma versão mais recente está disponível no GitHub.';

  @override
  String aboutLatestRelease(String version) {
    return 'Versão mais recente: $version';
  }

  @override
  String get aboutTapToCheck => 'Toque abaixo para verificar manualmente.';

  @override
  String aboutVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get aboutUnknown => 'Desconhecido';

  @override
  String get aboutCheckNow => 'Verificar agora';

  @override
  String get aboutViewRelease => 'Ver versão';

  @override
  String get aboutDebugGroup => 'Depuração';

  @override
  String get aboutPersistWrites => 'Persistir gravações';

  @override
  String get aboutPersistWritesSubtitle =>
      'Compilações de depuração mantêm as alterações em uma cópia descartável por padrão. Aplica-se na próxima inicialização.';

  @override
  String get appIconMoreSoon => 'Mais ícones em breve';

  @override
  String get appIconDesktopNote =>
      'Iniciadores e gerenciadores de arquivos do desktop mantêm o ícone padrão; o ícone da janela e do Dock segue sua escolha.';

  @override
  String get storageSettingsDiskGroup => 'Disco';

  @override
  String get storageSettingsIndexesGroup => 'Índices e caches';

  @override
  String get shellNavHome => 'Início';

  @override
  String get shellSearchTooltip => 'Buscar (Ctrl+K)';

  @override
  String get shellShowSidebar => 'Mostrar barra lateral';

  @override
  String get shellHideSidebar => 'Ocultar barra lateral';

  @override
  String get shellNothingUpNext => 'Nada a seguir';

  @override
  String get shellNextInQueue => 'Próxima na fila';

  @override
  String get shellPlayNext => 'Tocar em seguida';

  @override
  String get playerNothingPlaying => 'Nada tocando';

  @override
  String get playerPanePlayer => 'Reprodutor';

  @override
  String get playerPaneQueue => 'Fila';

  @override
  String get playerCloseEsc => 'Fechar (Esc)';

  @override
  String get playerSongOptions => 'Opções da música';

  @override
  String get playerShowArtwork => 'Mostrar capa';

  @override
  String get playerShowVideo => 'Mostrar vídeo';

  @override
  String get drawerQueueHistory => 'Histórico de filas';

  @override
  String get drawerTools => 'Ferramentas';

  @override
  String get nowPlayingBarShuffleTooltip =>
      'Aleatório (segure para um novo aleatório)';

  @override
  String get shuffleButtonAfterSong => 'Aleatório depois da música atual';

  @override
  String get shuffleButtonAfterQueue => 'Aleatório depois da fila atual';

  @override
  String shuffleButtonScanningTooltip(String percentage) {
    return 'Escaneando a biblioteca ($percentage%)';
  }

  @override
  String shuffleButtonScanningSemantics(String percentage) {
    return 'Escaneando a biblioteca, $percentage por cento concluído';
  }

  @override
  String shuffleButtonScanningMessage(String percentage) {
    return 'Escaneando a biblioteca: $percentage%';
  }

  @override
  String heartMenuRemoveFromPlaylist(String name) {
    return 'Remover de $name';
  }

  @override
  String heartMenuRemovedFromPlaylist(String name) {
    return 'Removida de $name';
  }

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortTitleAZ => 'Título (A-Z)';

  @override
  String get sortDateAdded => 'Data de adição';

  @override
  String get sortSongDateOldNew => 'Data da música (antiga - nova)';

  @override
  String get sortSongDateNewOld => 'Data da música (nova - antiga)';

  @override
  String get sortMostPlayed => 'Mais tocadas';

  @override
  String get sortRecentlyPlayed => 'Tocadas recentemente';

  @override
  String get sortRecommended => 'Recomendadas';

  @override
  String get searchFilterArtists => 'Artistas';

  @override
  String get playlistDialogAddTo => 'Adicionar a...';

  @override
  String get playlistDialogBulkAddTo => 'Adicionar em massa a...';

  @override
  String get playlistDialogUpdatedSelections => 'Seleções atualizadas';

  @override
  String get albumCardAllSongs => 'Todas as músicas';

  @override
  String dangerDialogTypeToConfirm(String text) {
    return 'Digite \"$text\" para confirmar';
  }

  @override
  String dangerDialogCountdown(String label, int seconds) {
    return '$label ($seconds)';
  }

  @override
  String get appDialogConfirm => 'Confirmar';

  @override
  String get appDialogEnterName => 'Digite o nome...';

  @override
  String get transportRepeatOff => 'Repetição desativada';

  @override
  String get transportRepeatAll => 'Repetir tudo';

  @override
  String get transportRepeatOne => 'Repetir uma';

  @override
  String durationSongsWithTotal(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0 • $duration';
  }

  @override
  String waveformDeltaMinutes(String minutes, String seconds) {
    return '${minutes}min ${seconds}s';
  }

  @override
  String waveformDeltaSeconds(String value) {
    return '${value}s';
  }

  @override
  String get waveformDeltaZero => '0s';

  @override
  String lyricsMatchContains(String line) {
    return 'contém \"$line\"';
  }

  @override
  String get lyricsMatchPrefix => 'contém \"';

  @override
  String get lyricsMatchAvailable => 'Letras disponíveis';

  @override
  String get lyricsResumeSync => 'Retomar sincronização';

  @override
  String get lyricsTimingTitle => 'Sincronização da letra';

  @override
  String get lyricsTimingLater => 'Mais tarde';

  @override
  String get lyricsTimingSyncToLine => 'Sincronizar com esta linha';

  @override
  String get lyricsTimingReset => 'Redefinir sincronização';

  @override
  String lyricsTimingSnapped(String value) {
    return 'Ajustado para $value';
  }

  @override
  String get lyricsTimingResetTooltip =>
      'Toque duas vezes para redefinir para 0,00';

  @override
  String get quickActionsTitle => 'Ações rápidas';

  @override
  String get quickActionsResetDone => 'Restaurado para o padrão';

  @override
  String quickActionsEnabledHeader(int count) {
    return 'ATIVADAS ($count)';
  }

  @override
  String quickActionsDisabledHeader(int count) {
    return 'DESATIVADAS ($count)';
  }

  @override
  String get quickActionsGoToAlbum => 'Ir para o álbum';

  @override
  String get quickActionsGoToArtist => 'Ir para o artista';

  @override
  String get updateAvailableTitle => 'Atualização disponível';

  @override
  String get updateCurrentLabel => 'Atual';

  @override
  String get updateAvailableBody =>
      'Uma versão mais recente do wispie está pronta para baixar.';

  @override
  String get updateSkipVersion => 'Pular esta versão';

  @override
  String get updateWhatsNew => 'Novidades?';

  @override
  String get externalOpenAddToLibrary => 'Adicionar à biblioteca';

  @override
  String get externalOpenDismiss => 'Dispensar';

  @override
  String get wideTrackTime => 'Tempo';

  @override
  String get floatingDockNext => 'Próxima';

  @override
  String get barSeekLabel => 'Buscar';
}

/// The translations for Portuguese, as used in Portugal (`pt_PT`).
class AppLocalizationsPtPt extends AppLocalizationsPt {
  AppLocalizationsPtPt() : super('pt_PT');

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Idioma do sistema';

  @override
  String get languageNativeName => 'Português (Portugal)';

  @override
  String get settingsTitle => 'Definições';

  @override
  String get settingsPageLibrarySubtitle =>
      'Pastas, filtros, pesquisa de ficheiros';

  @override
  String get settingsPagePlaybackTitle => 'Reprodução';

  @override
  String get settingsPagePlaybackSubtitle => 'Transições, fades, áudio';

  @override
  String get settingsPageLyricsTitle => 'Letras';

  @override
  String get settingsPageLyricsSubtitle =>
      'Sincronização por palavra, tradução, barra lateral';

  @override
  String get settingsPageAppearanceTitle => 'Aparência';

  @override
  String get settingsPageAppearanceSubtitle =>
      'A tocar agora, movimento, ícone da aplicação';

  @override
  String get settingsPageHomeNavigationTitle => 'Início e navegação';

  @override
  String get settingsPageHomeNavigationSubtitle =>
      'Secções do início, listas, ações rápidas';

  @override
  String get settingsPageSyncTitle => 'Sincronização';

  @override
  String get settingsPageSyncSubtitle =>
      'Sincronização encriptada entre dispositivos';

  @override
  String get settingsPageBackupRestoreTitle =>
      'Cópias de segurança e restauração';

  @override
  String get settingsPageBackupRestoreSubtitle =>
      'Exportar, importar, cópias de segurança automáticas';

  @override
  String get settingsPageStorageTitle => 'Armazenamento';

  @override
  String get settingsPageStorageSubtitle => 'Espaço em disco, índices, cache';

  @override
  String get settingsPageAboutTitle => 'Sobre';

  @override
  String get settingsPageAboutSubtitle =>
      'Versão, atualizações, notas de lançamento';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionCreate => 'Criar';

  @override
  String get actionDone => 'Concluído';

  @override
  String get actionChange => 'Alterar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionHide => 'Ocultar';

  @override
  String get actionDeletePermanently => 'Eliminar permanentemente';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get playlistNewTitle => 'Nova lista de reprodução';

  @override
  String get playlistNameHint => 'Nome da lista de reprodução';

  @override
  String playlistCreated(Object name) {
    return 'Lista de reprodução \"$name\" criada';
  }

  @override
  String songFavoriteRemoved(Object title) {
    return '$title removida dos favoritos';
  }

  @override
  String songFavoriteAdded(Object title) {
    return '$title adicionada aos favoritos';
  }

  @override
  String songWillSuggestMore(Object title) {
    return '$title será sugerida com mais frequência';
  }

  @override
  String songWillSuggestLess(Object title) {
    return '$title será sugerida com menos frequência';
  }

  @override
  String songAddedToNextUp(Object title) {
    return 'Adicionada a A seguir: $title';
  }

  @override
  String songShareText(Object artist, Object title) {
    return '$title de $artist';
  }

  @override
  String songAddedToPlaylist(Object name) {
    return 'Adicionada a $name';
  }

  @override
  String songRemovedFromPlaylist(Object title) {
    return '$title removida da lista de reprodução';
  }

  @override
  String songMovedTo(Object path, Object title) {
    return '$title movida para $path';
  }

  @override
  String songMoveError(Object error) {
    return 'Erro ao mover a música: $error';
  }

  @override
  String songRemovedFromLibrary(Object title) {
    return '$title removida da biblioteca';
  }

  @override
  String get songDeleteTitle => 'Eliminar música';

  @override
  String songDeleteConfirm(Object title) {
    return 'Tens a certeza de que queres eliminar permanentemente \'\'$title\'\' do teu dispositivo? Esta ação não pode ser desfeita.';
  }

  @override
  String songDeleted(Object title) {
    return '$title eliminada';
  }

  @override
  String songDeleteError(Object error) {
    return 'Erro ao eliminar o ficheiro: $error';
  }

  @override
  String get coverSearching =>
      'A procurar capas no Last.fm, Deezer e iTunes...';

  @override
  String get coverNoneFound => 'Nenhuma capa em falta foi encontrada online';

  @override
  String coverUpdated(Object source, Object title) {
    return 'Capa atualizada para \"$title\" ($source)';
  }

  @override
  String get coverDownloadFailed => 'Falha ao transferir a capa';

  @override
  String coverFetchError(Object error) {
    return 'Erro ao procurar a capa: $error';
  }

  @override
  String get metaResultsTitle => 'Resultados da pesquisa de metadata';

  @override
  String get metaFetchingTitle => 'A procurar metadata em falta';

  @override
  String get metaStatUpdated => 'Atualizado';

  @override
  String get metaStatNotFound => 'Não encontrado';

  @override
  String get metaStatSkipped => 'Ignorado';

  @override
  String get metaUndoAll => 'Desfazer tudo';

  @override
  String get metaUndoSong => 'Desfazer esta música';

  @override
  String metaRevertedCount(int count) {
    return 'Alterações de metadata revertidas em $count faixa(s)';
  }

  @override
  String metaViaSource(Object source) {
    return 'via $source';
  }

  @override
  String metaMoreItems(int count) {
    return '... e mais $count';
  }

  @override
  String get metaCouldNotFind => 'Não foi possível encontrar';

  @override
  String get metaUnknownArtist => 'Artista desconhecido';

  @override
  String metaAllHaveMetadata(int count) {
    return 'Todas as $count faixas já têm metadata';
  }

  @override
  String get metaNoMissingMetadata =>
      'Nenhuma música com metadata em falta foi encontrada';

  @override
  String metaSearchingBatch(int batch) {
    return 'A procurar o lote $batch...';
  }

  @override
  String metaCancelledSummary(int updated, int notFound) {
    return 'Pesquisa de metadata cancelada ($updated atualizadas, $notFound não encontradas)';
  }

  @override
  String get songMenuTitle => 'Opções da música';

  @override
  String get songMenuPlaybackHint =>
      'Ações de fila, lista de reprodução e partilha';

  @override
  String get songMenuLibraryHint => 'Mover música e editar metadata';

  @override
  String get songMenuPersonalize => 'Personalizar';

  @override
  String get songMenuPersonalizeHint =>
      'Definições de favoritos e recomendações';

  @override
  String get songMenuDanger => 'Zona de perigo';

  @override
  String get songMenuDangerHint =>
      'Remover da lista de reprodução ou eliminar a música';

  @override
  String get songMenuPlayNext => 'Tocar em seguida';

  @override
  String get songMenuPlayNextHint =>
      'Adicionar a música para tocar logo após a faixa atual';

  @override
  String get songMenuPlayNextDuplicate =>
      'Tocar em seguida (permitir duplicados)';

  @override
  String get songMenuPlayNextDuplicateHint =>
      'Adicionar de novo mesmo que já esteja na fila';

  @override
  String get songMenuAddToPlaylist => 'Adicionar à lista de reprodução';

  @override
  String get songMenuAddToPlaylistHint =>
      'Adicionar rapidamente à lista de reprodução mais recente';

  @override
  String get songMenuAddToNewPlaylist =>
      'Adicionar a uma nova lista de reprodução';

  @override
  String get songMenuAddToNewPlaylistHint =>
      'Criar uma lista de reprodução e adicionar esta música';

  @override
  String get songMenuShare => 'Partilhar';

  @override
  String get songMenuShareHint =>
      'Partilhar o ficheiro de áudio com outras aplicações';

  @override
  String get songMenuFetchCover => 'Procurar capa em falta';

  @override
  String get songMenuFetchCoverHint =>
      'Tentar procurar capas no Last.fm, Deezer e iTunes';

  @override
  String get songMenuFetchMetadata => 'Procurar metadata em falta';

  @override
  String get songMenuFetchMetadataHint =>
      'Procurar online título, artista, álbum e capa';

  @override
  String get songMenuMoveToFolder => 'Mover para pasta';

  @override
  String get songMenuMoveToFolderHint => 'Mover este ficheiro para outra pasta';

  @override
  String get songMenuManagePlaylists => 'Gerir listas de reprodução';

  @override
  String get songMenuManagePlaylistsHint =>
      'Adicionar ou remover de listas de reprodução';

  @override
  String get songMenuEditMetadata => 'Editar';

  @override
  String get songMenuEditMetadataHint => 'Abrir o editor de metadata';

  @override
  String get songMenuRemoveFavorite => 'Remover dos favoritos';

  @override
  String get songMenuAddFavorite => 'Adicionar aos favoritos';

  @override
  String get songMenuFavoritesHint =>
      'Ajustar a tua lista de músicas favoritas';

  @override
  String get songMenuSuggestMore => 'Sugerir mais';

  @override
  String get songMenuSuggestLess => 'Sugerir menos';

  @override
  String get songMenuSuggestHint =>
      'Ajustar com que frequência esta música aparece nas sugestões';

  @override
  String get songMenuRemoveFromPlaylist => 'Remover da lista atual';

  @override
  String get songMenuRemoveFromPlaylistHint =>
      'Manter o ficheiro, remover da lista de reprodução';

  @override
  String get songMenuRemoveFromLibrary => 'Remover da biblioteca';

  @override
  String get songMenuRemoveFromLibraryHint =>
      'Manter o ficheiro, mas ocultar da biblioteca';

  @override
  String get songMenuDeleteHint => 'Eliminar o ficheiro do dispositivo';

  @override
  String get bulkSelected => 'selecionadas';

  @override
  String get bulkSelectAll => 'Selecionar tudo';

  @override
  String get bulkFavorite => 'Favoritar';

  @override
  String get bulkUnfavorite => 'Desfavoritar';

  @override
  String bulkRemovedFromFavorites(int count) {
    return '$count músicas removidas dos favoritos';
  }

  @override
  String bulkAddedToFavorites(int count) {
    return '$count músicas adicionadas aos favoritos';
  }

  @override
  String get bulkPlaylist => 'Lista de reprodução';

  @override
  String bulkAddedToPlaylist(int count, Object name) {
    return '$count músicas adicionadas a $name';
  }

  @override
  String bulkSongsCount(int count) {
    return '$count músicas';
  }

  @override
  String get bulkMetadata => 'metadata';

  @override
  String get bulkHideTitle => 'Ocultar músicas';

  @override
  String bulkHideMessage(int count) {
    return 'Ocultar $count músicas selecionadas da biblioteca?';
  }

  @override
  String get bulkDeleteTitle => 'Eliminar ficheiros';

  @override
  String bulkDeleteMessage(int count) {
    return 'Eliminar permanentemente $count ficheiros do armazenamento? Esta ação não pode ser desfeita.';
  }

  @override
  String bulkAddedToQueue(int count) {
    return '$count músicas adicionadas à fila';
  }

  @override
  String get bulkMove => 'Mover';

  @override
  String bulkMovedTo(int count, Object path) {
    return '$count músicas movidas para $path';
  }

  @override
  String bulkMoveError(Object error) {
    return 'Erro ao mover as músicas: $error';
  }

  @override
  String bulkWillSuggestMore(int count) {
    return 'Serão sugeridas mais $count músicas';
  }

  @override
  String bulkWillSuggestLess(int count) {
    return 'Serão sugeridas menos $count músicas';
  }

  @override
  String get queueTabUpNext => 'A seguir';

  @override
  String get queueTabHistory => 'Histórico';

  @override
  String get queueActionMoveToTop => 'Mover para o topo';

  @override
  String get queueActionRemove => 'Remover';

  @override
  String get queueActionSongOptions => 'Opções da música…';

  @override
  String get queueClearDialogTitle => 'Limpar fila?';

  @override
  String get queueClearDialogMessage =>
      'Isto vai remover todas as músicas seguintes da fila atual.';

  @override
  String get queueClearAll => 'Limpar tudo';

  @override
  String get queueSectionPlayed => 'Já tocadas';

  @override
  String get queueSectionNowPlaying => 'A tocar agora';

  @override
  String get queueSectionUpNext => 'A seguir';

  @override
  String get queueSwipeAddToTop => 'Adicionar ao topo';

  @override
  String get queueShuffleUpcomingTooltip => 'Aleatorizar seguintes';

  @override
  String get queueClearUpcomingTooltip => 'Limpar seguintes';

  @override
  String queueSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0';
  }

  @override
  String queueRemainingSuffix(String remaining) {
    return '  ·  $remaining';
  }

  @override
  String get queueEmpty => 'A fila está vazia';

  @override
  String get queueRemoveFromQueueTooltip => 'Remover da fila';

  @override
  String queueRemovedTitle(String title) {
    return '$title removida';
  }

  @override
  String get queueUndo => 'Desfazer';

  @override
  String get historyClearDialogTitle => 'Limpar histórico?';

  @override
  String get historyClearDialogMessage =>
      'Isto vai eliminar todas as filas guardadas.';

  @override
  String historyRestoredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restauradas $count faixas',
      one: 'Restaurada 1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get historyLoadError => 'Não foi possível carregar o histórico';

  @override
  String get historyEmptyTitle => 'Não há filas anteriores';

  @override
  String get historyEmptyMessage =>
      'As filas que tocares são guardadas aqui automaticamente.';

  @override
  String historySavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filas guardadas',
      one: '1 fila guardada',
    );
    return '$_temp0';
  }

  @override
  String get historyClearAllTrailing => 'Limpar tudo';

  @override
  String get historyDayToday => 'Hoje';

  @override
  String get historyDayYesterday => 'Ontem';

  @override
  String get historyDayThisWeek => 'Esta semana';

  @override
  String get historyDayThisMonth => 'Este mês';

  @override
  String get historyDayEarlier => 'Anteriormente';

  @override
  String get snapshotShuffledQueue => 'Fila em ordem aleatória';

  @override
  String get snapshotSavedQueue => 'Fila guardada';

  @override
  String get snapshotEmptyTracks =>
      'Nenhuma destas faixas está ainda na tua biblioteca.';

  @override
  String snapshotMoreHidden(int count) {
    return '+$count a mais';
  }

  @override
  String snapshotMissingCount(int count) {
    return '$count em falta na biblioteca';
  }

  @override
  String get queueMetaSeparator => '  ·  ';

  @override
  String get songListShuffle => 'Aleatório';

  @override
  String get songListPlay => 'Reproduzir';

  @override
  String get songListPause => 'Pausar';

  @override
  String get songListResume => 'Continuar';

  @override
  String get songListFetchArtistCover => 'Procurar capa do artista online';

  @override
  String get songListFetchAlbumCover => 'Procurar capa do álbum online';

  @override
  String get songListFetchCover => 'Procurar capa online';

  @override
  String get songListPlaylistOptions => 'Opções da lista de reprodução';

  @override
  String get songListSelectSongsToMerge => 'Selecionar músicas para unir';

  @override
  String songListMergedSongs(int count) {
    return '$count músicas unidas';
  }

  @override
  String songListMergeError(Object error) {
    return 'Erro: $error';
  }

  @override
  String get songListMergeSongs => 'Unir músicas';

  @override
  String get songListEmpty => 'Não há músicas nesta lista';

  @override
  String get actionRename => 'Renomear';

  @override
  String get songListRenamePlaylist => 'Renomear lista de reprodução';

  @override
  String get songListDeletePlaylist => 'Eliminar lista de reprodução';

  @override
  String songListDeletePlaylistConfirm(Object title) {
    return 'Tens a certeza de que queres eliminar \"$title\"?';
  }

  @override
  String songListSearchingArtwork(Object name) {
    return 'A procurar online a capa de $name...';
  }

  @override
  String songListSelectArtwork(Object name) {
    return 'Selecionar capa para $name';
  }

  @override
  String get songListUseSongCoverGrid => 'Usar grelha de capas de música';

  @override
  String get songListRemoveCustomArtwork => 'Remover capa personalizada';

  @override
  String get songListChooseCustomImage => 'Escolher imagem personalizada';

  @override
  String get songListSelectFromDevice =>
      'Selecionar imagem do armazenamento do dispositivo';

  @override
  String songListArtworkFrom(Object source) {
    return 'Capa de $source';
  }

  @override
  String get songListNoOnlineArtwork =>
      'Nenhuma opção de capa online encontrada';

  @override
  String get songListResetArtwork =>
      'Restaurar para a grelha de capas de música';

  @override
  String songListArtworkUpdated(Object name) {
    return 'Capa atualizada para $name';
  }

  @override
  String get songListDownloadingArtwork => 'A transferir capa...';

  @override
  String get songListArtworkDownloadFailed => 'Falha ao transferir a capa';

  @override
  String get gradientDetailAlbums => 'Álbuns';

  @override
  String get gradientDetailSongs => 'Músicas';

  @override
  String get gradientDetailShowAll => 'Mostrar tudo';

  @override
  String gradientDetailAlbumCount(int count) {
    return '$count álbuns';
  }

  @override
  String get syncPlayStats => 'Estatísticas de reprodução';

  @override
  String get syncPlayStatsHint =>
      'Histórico de audição e contagem de reproduções';

  @override
  String get syncFavoritesHint => 'Músicas favoritas';

  @override
  String get syncSuggestLess => 'Sugerir menos';

  @override
  String get syncSuggestLessHint => 'Músicas que pediste para ver menos';

  @override
  String get syncHiddenSongs => 'Músicas ocultas';

  @override
  String get syncPlaylistsHint => 'Todas as listas de reprodução';

  @override
  String get syncMergedSongs => 'Músicas unidas';

  @override
  String get syncMergedSongsHint => 'Grupos de músicas unidas';

  @override
  String get syncAppSettings => 'Definições da aplicação';

  @override
  String get syncAppSettingsHint =>
      'Tema, reprodução e preferências de interface';

  @override
  String get syncArtistArt => 'Capa do artista';

  @override
  String get syncArtistArtHint => 'Opções de capa do artista online';

  @override
  String get syncAlbumArt => 'Capa do álbum';

  @override
  String get syncAlbumArtHint => 'Opções de capa do álbum online';

  @override
  String get syncPrivacy => 'Privacidade';

  @override
  String get syncEncryptedTitle => 'Encriptação de ponta a ponta';

  @override
  String get syncEncryptedBody =>
      'Os teus dados são encriptados neste dispositivo antes do envio. O servidor armazena apenas o texto cifrado e não consegue ler a tua biblioteca, o teu histórico nem as tuas definições.';

  @override
  String get syncRecoveryKeyTitle => 'Chave de recuperação';

  @override
  String get syncRecoveryKeyBody =>
      'Se te esqueceres da tua palavra-passe, apenas a tua chave de recuperação pode restaurar o acesso. Mais ninguém pode.';

  @override
  String get syncAccount => 'Conta';

  @override
  String get syncSignedIn => 'Sessão iniciada';

  @override
  String get syncConnected => 'Ligado';

  @override
  String get syncLogOut => 'Sair';

  @override
  String get syncLogOutBody =>
      'A sincronização para neste dispositivo. Os dados locais e na nuvem são mantidos.';

  @override
  String get syncLogOutAndChange => 'Sair e alterar';

  @override
  String get syncCloud => 'Nuvem';

  @override
  String get syncLastSynced => 'Última sincronização';

  @override
  String get syncNever => 'Nunca';

  @override
  String syncUsedOfQuota(Object used, Object quota) {
    return '$used de $quota usados';
  }

  @override
  String get syncJustNow => 'Agora mesmo';

  @override
  String syncMinutesAgo(int count) {
    return 'há $count min';
  }

  @override
  String syncHoursAgo(int count) {
    return 'há $count h';
  }

  @override
  String syncDaysAgo(int count) {
    return 'há $count d';
  }

  @override
  String get syncAutoSync => 'Sincronização automática';

  @override
  String get syncAutoSyncHint =>
      'Sincronizar em segundo plano enquanto a aplicação estiver aberta';

  @override
  String get syncNow => 'Sincronizar agora';

  @override
  String get syncMergeDeviceHint => 'Unir este dispositivo com a nuvem';

  @override
  String syncLastError(Object error) {
    return 'Último erro: $error';
  }

  @override
  String get syncWhatGetsSynced => 'O que é sincronizado';

  @override
  String get syncDeviceStatsAttribution =>
      'Atribuição de estatísticas por dispositivo';

  @override
  String get syncThisDevice => 'Este dispositivo';

  @override
  String get syncOtherDevices => 'Outros dispositivos';

  @override
  String get syncTotalLibraryStats => 'Estatísticas totais da biblioteca';

  @override
  String syncPlays(int count) {
    return '$count reproduções';
  }

  @override
  String get syncDangerZone => 'Zona de perigo';

  @override
  String get syncOverwriteCloudTile =>
      'Substituir a nuvem por este dispositivo';

  @override
  String get syncOverwriteCloudTileHint =>
      'Substituir todos os dados da nuvem pelos que estão neste dispositivo';

  @override
  String get syncReplaceDeviceTile => 'Substituir este dispositivo pela nuvem';

  @override
  String get syncReplaceDeviceTileHint =>
      'Apagar os dados sincronizados neste dispositivo e usar a cópia da nuvem';

  @override
  String get syncChangePassword => 'Alterar palavra-passe';

  @override
  String get syncNewRecoveryKey => 'Nova chave de recuperação';

  @override
  String get syncNewRecoveryKeyHint =>
      'A chave de recuperação antiga deixa de funcionar';

  @override
  String get syncChangeServer => 'Alterar servidor';

  @override
  String get syncChangeServerHint => 'É necessário sair primeiro';

  @override
  String get syncChangeServerBody =>
      'Vais sair do servidor atual primeiro. Os dados locais são mantidos.';

  @override
  String get syncDeleteCloudAccount => 'Eliminar conta na nuvem';

  @override
  String get syncDeleteCloudAccountHint =>
      'Remove os dados da nuvem permanentemente. Os dados locais são mantidos';

  @override
  String get syncDeleteCloudAccountBody =>
      'A tua conta na nuvem e todos os dados encriptados no servidor são eliminados permanentemente. Os dados neste dispositivo são mantidos.';

  @override
  String get syncOverwriteCloud => 'Substituir a nuvem';

  @override
  String get syncOverwriteCloudBody =>
      'Todos os dados na nuvem serão substituídos pelos deste dispositivo. Os outros dispositivos serão questionados sobre como continuar. Este dispositivo mantém os seus dados.';

  @override
  String get syncOverwriteCloudCheckbox =>
      'Entendo que os dados da nuvem serão perdidos';

  @override
  String get syncOverwrite => 'Substituir';

  @override
  String get syncReplaceDevice => 'Substituir este dispositivo';

  @override
  String get syncReplaceDeviceBody =>
      'Os dados sincronizados neste dispositivo (estatísticas, favoritos, listas de reprodução e assim por diante) serão apagados e substituídos pela cópia da nuvem. Os ficheiros de música não são alterados.';

  @override
  String get syncReplaceDeviceCheckbox =>
      'Entendo que os dados sincronizados locais serão perdidos';

  @override
  String get syncReplace => 'Substituir';

  @override
  String get syncCurrentPassword => 'Palavra-passe atual';

  @override
  String get syncNewPassword => 'Nova palavra-passe';

  @override
  String get syncPassword => 'Palavra-passe';

  @override
  String get syncPasswordChanged => 'Palavra-passe alterada';

  @override
  String get syncGenerate => 'Gerar';

  @override
  String get appearanceGroupNowPlaying => 'A tocar agora';

  @override
  String get appearanceVisualizerTitle => 'Visualizador de áudio';

  @override
  String get appearanceVisualizerSubtitle =>
      'Barras sobre a capa durante a reprodução — o modo sincronizado acompanha a música, com os graves à esquerda';

  @override
  String get appearanceVisualizerClassic => 'Clássico';

  @override
  String get appearanceVisualizerSynced => 'Sincronizado';

  @override
  String get appearanceProgressBarTitle => 'Estilo da barra de progresso';

  @override
  String get appearanceProgressBasicSubtitle =>
      'Barra de progresso de linha simples';

  @override
  String get appearanceProgressWaveformSubtitle =>
      'Forma de onda de áudio estática';

  @override
  String get appearanceProgressReactiveSubtitle =>
      'Forma de onda dinâmica reativa ao som, com espectro ao vivo e resposta à batida';

  @override
  String get appearanceProgressStandard => 'Padrão';

  @override
  String get appearanceProgressWaveform => 'Forma de onda';

  @override
  String get appearanceProgressSoundReactive => 'Reativo ao som';

  @override
  String get appearanceHapticsTitle =>
      'Retorno tátil ao arrastar a forma de onda';

  @override
  String get appearanceHapticsSubtitle =>
      'Retorno tátil para cada barra ao avançar na faixa';

  @override
  String get appearanceCoverSizingTitle => 'Dimensionamento da capa do player';

  @override
  String get appearanceCoverSizingSubtitle =>
      'Ajuste automático ou preservar a proporção do original';

  @override
  String get appearanceCoverAutoFit => 'Ajuste automático';

  @override
  String get appearanceCoverSourceSize => 'Tamanho original';

  @override
  String get appearanceImmersiveTitle => 'Design imersivo';

  @override
  String get appearanceImmersiveSubtitle =>
      'Capa do player em ecrã inteiro e ecrãs de detalhes com gradiente';

  @override
  String get appearanceGroupPlayerMotion => 'Movimento do player';

  @override
  String get appearanceBeatCoverTitle => 'Capa reativa à batida';

  @override
  String get appearanceBeatCoverUnavailable =>
      'Indisponível enquanto o design imersivo estiver ativo';

  @override
  String get appearanceBeatCoverSubtitle =>
      'A capa do álbum pulsa com a batida';

  @override
  String get appearanceCoverIntensityTitle => 'Intensidade da capa';

  @override
  String get appearanceCoverIntensitySubtitle =>
      'Com que intensidade a capa reage';

  @override
  String get appearanceSpinArtworkTitle => 'Girar a capa durante a reprodução';

  @override
  String get appearanceSpinArtworkSubtitle =>
      'A capa gira lentamente na barra inferior minimizada enquanto uma música toca';

  @override
  String get appearanceParticlesTitle => 'Partículas reativas à batida';

  @override
  String get appearanceParticlesSubtitle =>
      'Partículas flutuantes que vagam e respiram com a música';

  @override
  String get appearanceParticleDensityTitle => 'Densidade das partículas';

  @override
  String get appearanceParticleDensitySubtitle =>
      'Quantas partículas existem e quão vivas elas ficam';

  @override
  String get appearanceBeatOffsetTitle => 'Ajuste de sincronização da batida';

  @override
  String get appearanceBeatOffsetNone =>
      'Sem ajuste — aumenta se o pulso parecer adiantado';

  @override
  String appearanceBeatOffsetValue(int ms) {
    return '$ms ms';
  }

  @override
  String appearanceBeatOffsetBluetooth(int ms) {
    return '$ms ms (aumenta para Bluetooth)';
  }

  @override
  String get appearanceCalibrateTitle => 'Calibrar sincronização da batida';

  @override
  String get appearanceCalibrateSubtitle =>
      'Alinha as partículas com uma faixa de cliques de ouvido';

  @override
  String get appearanceAppIcon => 'Ícone da aplicação';

  @override
  String get appearanceIntensityMin => 'Mín';

  @override
  String get appearanceIntensitySubtle => 'Sutil';

  @override
  String get appearanceIntensityBalanced => 'Equilibrado';

  @override
  String get appearanceIntensityBold => 'Forte';

  @override
  String get appearanceIntensityMax => 'Máx';

  @override
  String get appearanceIntensityCustom => 'Personalizado';

  @override
  String get backupExportAppData => 'Exportar dados da aplicação';

  @override
  String get backupExportAppDataSubtitle =>
      'Faz uma cópia de segurança das tuas estatísticas, favoritos e listas de reprodução';

  @override
  String backupExportFailed(Object error) {
    return 'Falha na exportação: $error';
  }

  @override
  String get backupImportAppData => 'Importar dados da aplicação';

  @override
  String get backupImportAppDataSubtitle =>
      'Restaurar dados de uma cópia de segurança (substitui tudo)';

  @override
  String get backupManageBackups => 'Gerir cópias de segurança';

  @override
  String get backupManageBackupsSubtitle =>
      'Criar, restaurar e gerir cópias de segurança da aplicação';

  @override
  String get backupAutomaticBackups => 'Cópias de segurança automáticas';

  @override
  String get backupAutoBackup => 'Cópia de segurança automática';

  @override
  String get backupAutoBackupSubtitle =>
      'Com que frequência é feita uma cópia de segurança';

  @override
  String get backupAutoBackupContent =>
      'Conteúdo da cópia de segurança automática';

  @override
  String get backupAutoBackupContentSubtitle =>
      'Quais dados são incluídos nas cópias de segurança automáticas';

  @override
  String get backupAutoBackupContentDialogSubtitle =>
      'Seleciona o conteúdo das cópias de segurança automáticas';

  @override
  String get backupSave => 'Guardar';

  @override
  String get backupAutoDeleteOld =>
      'Eliminar cópias de segurança antigas automaticamente';

  @override
  String get backupAutoDeleteOldSubtitle =>
      'Descartar cópias de segurança mais antigas do que isso';

  @override
  String get backupFrequencyDisabled => 'Desativado';

  @override
  String get backupFrequencyEvery24Hours => 'A cada 24 horas';

  @override
  String get backupFrequencyEvery48Hours => 'A cada 48 horas';

  @override
  String get backupFrequencyEvery3Days => 'A cada 3 dias';

  @override
  String get backupFrequencyEvery7Days => 'A cada 7 dias';

  @override
  String backupDeleteAfterDays(int count) {
    return '$count dias';
  }

  @override
  String get backupExportOptionsTitle => 'Opções de exportação';

  @override
  String get backupExportSelectContent => 'Seleciona o conteúdo a exportar:';

  @override
  String get backupContentUserStats => 'Estatísticas do utilizador';

  @override
  String get backupContentUserStatsSubtitle =>
      'Contagem de reproduções, sessões, estatísticas divertidas';

  @override
  String get backupContentUserData => 'Dados do utilizador';

  @override
  String get backupContentUserDataSubtitle =>
      'Favoritos, músicas ocultas, listas de reprodução';

  @override
  String get backupContentUserSettings => 'Definições do utilizador';

  @override
  String get backupContentUserSettingsSubtitle =>
      'Tema, ordem de classificação, preferências';

  @override
  String get backupContentCoverCacheSubtitle => 'Imagens das capas dos álbuns';

  @override
  String get backupContentLibraryCacheSubtitle =>
      'Metadata de músicas em cache';

  @override
  String get backupContentSearchIndexSubtitle => 'Dados de pesquisa indexados';

  @override
  String get backupContentWaveformCacheSubtitle =>
      'Dados de forma de onda de áudio';

  @override
  String get backupContentColorCacheSubtitle => 'Temas de cor dos álbuns';

  @override
  String get backupContentLyricsCacheSubtitle => 'Dados de letras armazenados';

  @override
  String get backupCancelUpper => 'CANCELAR';

  @override
  String get backupExportUpper => 'EXPORTAR';

  @override
  String get backupContinueUpper => 'CONTINUAR';

  @override
  String get backupImportDataTitle => 'Importar dados';

  @override
  String get backupImportWarning =>
      'Isto vai substituir TODOS os dados existentes pelos dados importados.\n\nAs tuas estatísticas, os teus favoritos, as tuas listas de reprodução e as tuas definições atuais serão sobrescritos.\n\nEsta ação não pode ser desfeita.';

  @override
  String get backupImportingLabel => 'A importar…';

  @override
  String get backupImportingTitle => 'A importar dados';

  @override
  String get backupImportSuccess => 'Importação concluída com sucesso!';

  @override
  String backupImportFailed(Object error) {
    return 'Falha na importação: $error';
  }

  @override
  String get metadataCoverUpdated => 'Capa atualizada com sucesso';

  @override
  String metadataPickImageError(Object error) {
    return 'Erro ao selecionar a imagem: $error';
  }

  @override
  String get metadataRemoveCoverTitle => 'Remover capa';

  @override
  String get metadataRemoveCoverBody =>
      'Tens a certeza de que queres remover a capa?';

  @override
  String get metadataRemoveUpper => 'REMOVER';

  @override
  String get metadataCoverRemoved => 'Capa removida';

  @override
  String metadataRemoveCoverError(Object error) {
    return 'Erro ao remover a capa: $error';
  }

  @override
  String get metadataFixResultTitle => 'Resultado da correção da miniatura';

  @override
  String get metadataFixReviewBody => 'Revê as alterações abaixo:';

  @override
  String get metadataFixOriginal => 'Original';

  @override
  String get metadataFixNew => 'Nova';

  @override
  String metadataFixNewOption(int n) {
    return 'Nova (opção $n)';
  }

  @override
  String get metadataFixSeeAlternatives => 'Ver alternativas';

  @override
  String get metadataFixApply => 'Aplicar';

  @override
  String get metadataFixSuccess => 'Miniatura corrigida com sucesso';

  @override
  String metadataFixError(Object error) {
    return 'Erro ao corrigir a miniatura: $error';
  }

  @override
  String get metadataFixThumbnail => 'Corrigir miniatura';

  @override
  String get metadataFixHelpBody =>
      'Esta ferramenta melhora automaticamente a capa do álbum ao:\n\n1. Detetar e remover barras e bordas pretas (comuns em miniaturas do YouTube)\n2. Recortar a imagem num quadrado perfeito (proporção 1:1)\n\nIdeal para converter miniaturas 16:9 em capas de álbum adequadas.';

  @override
  String get metadataGotIt => 'Entendi';

  @override
  String get metadataExportCover => 'Exportar capa';

  @override
  String get metadataExport => 'Exportar';

  @override
  String metadataExportSuccess(Object uri) {
    return 'Capa exportada para $uri';
  }

  @override
  String metadataExportError(Object error) {
    return 'Erro ao exportar a capa: $error';
  }

  @override
  String get metadataReplaceSong => 'Substituir música';

  @override
  String get metadataReplaceHelpBody =>
      'Troca o ficheiro desta música por outra cópia da mesma música (rip melhor, sem perdas, codificação limpa).\n\nO histórico de reprodução, os favoritos, as listas de reprodução e a data na biblioteca passam para o novo ficheiro. A metadata é lida novamente do ficheiro, e tudo o que faltar aparece como desconhecido.\n\nO novo ficheiro precisa de estar fora das pastas da tua biblioteca e ter um nome de ficheiro diferente.';

  @override
  String metadataReplaced(Object filename) {
    return 'Substituída por $filename';
  }

  @override
  String metadataReplaceError(Object error) {
    return 'Não foi possível substituir o ficheiro: $error';
  }

  @override
  String metadataReplaceFilesBody(Object oldName, Object newName) {
    return '$oldName\nsubstituída por $newName';
  }

  @override
  String get metadataReplaceOriginalQuestion =>
      'O que deve acontecer com o original?';

  @override
  String get metadataReplaceRejectNoFile => 'Nenhum ficheiro foi selecionado.';

  @override
  String get metadataReplaceRejectUnsupported =>
      'Esse ficheiro não está num formato de áudio ou vídeo que esta biblioteca consegue ler.';

  @override
  String get metadataReplaceRejectSameFilename =>
      'A substituição precisa de um nome de ficheiro diferente. Alterar apenas a extensão já basta.';

  @override
  String get metadataReplaceRejectInsideLibrary =>
      'Esse ficheiro está dentro de uma das tuas pastas da biblioteca. Escolhe uma cópia de algum sítio fora da tua biblioteca.';

  @override
  String metadataReplaceRejectDestinationExists(String filename) {
    return 'Um ficheiro chamado \"$filename\" já está ao lado do original.';
  }

  @override
  String metadataReplaceRejectLibraryHasName(String filename) {
    return 'A tua biblioteca já tem uma música chamada \"$filename\".';
  }

  @override
  String get metadataKeepHideUpper => 'MANTER, OCULTAR';

  @override
  String get metadataDeleteItUpper => 'ELIMINAR';

  @override
  String get metadataSaved => 'Metadata atualizada com sucesso';

  @override
  String metadataSaveError(Object error) {
    return 'Erro ao guardar a metadata: $error';
  }

  @override
  String get metadataNoOnlineCover => 'Nenhuma capa encontrada online';

  @override
  String get metadataSelectCoverTitle => 'Selecionar capa';

  @override
  String metadataResultTitleArtist(Object title, Object artist) {
    return '$title - $artist';
  }

  @override
  String metadataSourceLabel(Object source) {
    return 'Fonte: $source';
  }

  @override
  String metadataCoverUpdatedFrom(Object source) {
    return 'Capa atualizada de $source';
  }

  @override
  String get metadataNoOnlineMatch =>
      'Nenhuma metadata correspondente encontrada online';

  @override
  String get metadataSelectMatchTitle => 'Selecionar correspondência online';

  @override
  String metadataResultDetail(Object artist, Object album, Object source) {
    return '$artist · $album ($source)';
  }

  @override
  String metadataLoadedFrom(Object source) {
    return 'Metadata e capa carregadas de $source';
  }

  @override
  String metadataFetchError(Object error) {
    return 'Erro ao obter a metadata: $error';
  }

  @override
  String get metadataSectionCover => 'Capa';

  @override
  String get metadataChangeCover => 'Alterar capa';

  @override
  String get metadataWhatDoesThisDo => 'O que isto faz?';

  @override
  String get metadataSectionFile => 'Informações do ficheiro';

  @override
  String get metadataFilenameLabel => 'Nome do ficheiro (sem a extensão)';

  @override
  String get metadataFilenameHelper =>
      'Renomear o ficheiro vai atualizá-lo localmente.';

  @override
  String get metadataSectionSong => 'Metadata da música';

  @override
  String get metadataFetchOnline => 'Obter online';

  @override
  String get metadataTitleLabel => 'Título';

  @override
  String get metadataArtistLabel => 'Artista';

  @override
  String get metadataAlbumLabel => 'Álbum';

  @override
  String get metadataSectionExtra => 'Conteúdo adicional';

  @override
  String get metadataEditLyrics => 'Editar letras';

  @override
  String get metadataEditLyricsSubtitle =>
      'Ver ou editar as letras incorporadas';

  @override
  String get metadataSaveUpper => 'GUARDAR';

  @override
  String metadataLyricsLoadError(Object error) {
    return 'Erro ao carregar as letras: $error';
  }

  @override
  String metadataLyricsSaveError(Object error) {
    return 'Erro ao guardar as letras: $error';
  }

  @override
  String get metadataLyricsLoaded =>
      'Letras carregadas — prime GUARDAR para aplicar';

  @override
  String get metadataSearchOnline => 'Pesquisar online';

  @override
  String get metadataLyricsHint =>
      'As letras estão incorporadas no ficheiro de áudio. Podes usar marcas de tempo [mm:ss.xx] para letras sincronizadas.';

  @override
  String get metadataLyricsFieldHint => 'Escreve as letras aqui...';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileAvatarFallback => 'U';

  @override
  String get profileDefaultName => 'Utilizador';

  @override
  String profileAppVersion(String version) {
    return 'wispie v$version';
  }

  @override
  String get profileHidden => 'Ocultas';

  @override
  String get profileSuggestLess => 'Sugerir menos';

  @override
  String get profileShuffleSection => 'Personalidade do aleatório';

  @override
  String get profileSmart => 'Inteligente';

  @override
  String get profileSmartSubtitle =>
      'Aprende o teu gosto, tendências e contexto. Recomendado';

  @override
  String get profileDefault => 'Predefinido';

  @override
  String get profileDefaultSubtitle => 'Mistura equilibrada com anti-repetição';

  @override
  String get profileExplorer => 'Explorador';

  @override
  String get profileExplorerSubtitle => 'Prioriza músicas novas e raras';

  @override
  String get profileConsistent => 'Consistente';

  @override
  String get profileConsistentSubtitle => 'Com muitos favoritos';

  @override
  String get profileCustomSubtitle => 'Configura o teu próprio aleatório';

  @override
  String get profileChangeName => 'Alterar o nome exibido';

  @override
  String get profileNewNameHint => 'Novo nome';

  @override
  String get profileUpdate => 'Atualizar';

  @override
  String get profileNameUpdated => 'Nome atualizado';

  @override
  String profileCurrentName(String name) {
    return 'Atual: $name';
  }

  @override
  String get profilePersonalitySaved => 'Personalidade guardada';

  @override
  String get profileAppliesNextQueue => 'Aplica-se à próxima fila';

  @override
  String get profileConfigureCustomShuffle =>
      'Configurar aleatório personalizado';

  @override
  String get profileConfigureCustomShuffleSubtitle =>
      'Ajustar as definições de comportamento do aleatório';

  @override
  String get profileThemeStorage => 'Tema e armazenamento';

  @override
  String get profileFamiliar => 'Familiar';

  @override
  String get profileDiscover => 'Descobrir';

  @override
  String get profileFamiliarToDiscover => 'Familiar até Descobrir';

  @override
  String get profileLegacyCaption =>
      'Legado: comportamento fixo, mantido por compatibilidade';

  @override
  String get storageManageTitle => 'Gerir armazenamento';

  @override
  String get storageRepairCardTitle => 'Reparar links da biblioteca';

  @override
  String get storageRepairCardBody =>
      'Capa em falta depois de uma restauração ou de um telemóvel novo? Isto volta a associar as capas e os caminhos dos ficheiros.';

  @override
  String get storageRepair => 'Reparar';

  @override
  String get storageRepairTitle => 'Reparar links da biblioteca?';

  @override
  String get storageRepairBody =>
      'Isto volta a associar as capas em cache e os caminhos dos ficheiros onde eles estão realmente neste dispositivo.\n\nAs faixas cujos ficheiros já não estão aqui serão removidas da biblioteca. Favoritos, listas de reprodução e contagens de reprodução são mantidos, e voltam a ligar-se automaticamente se esses ficheiros voltarem.';

  @override
  String storageRepairError(Object error) {
    return 'Erro ao reparar a biblioteca: $error';
  }

  @override
  String get storageDatabaseTitle => 'Base de dados';

  @override
  String get storageDatabaseSubtitle =>
      'Dados do utilizador, estatísticas e definições';

  @override
  String get storageCoverCacheTitle => 'Cache das capas';

  @override
  String get storageCoverCacheSubtitle => 'Capas de música em cache';

  @override
  String get storageBackupsTitle => 'Cópias de segurança';

  @override
  String get storageBackupsSubtitle => 'Ficheiros de cópia de segurança locais';

  @override
  String get storageLibraryCacheTitle => 'Cache da biblioteca';

  @override
  String get storageLibraryCacheSubtitle =>
      'Dados da biblioteca de músicas em cache';

  @override
  String get storageSearchIndexTitle => 'Índice de pesquisa';

  @override
  String get storageSearchIndexSubtitle =>
      'Índice de pesquisa para consultas rápidas';

  @override
  String get storageWaveformCacheTitle => 'Cache de formas de onda';

  @override
  String get storageWaveformCacheSubtitle =>
      'Formas de onda das músicas em cache para visualizadores';

  @override
  String get storageBeatAnalysisTitle => 'Análise de batidas';

  @override
  String get storageBeatAnalysisSubtitle =>
      'Mapas de batidas em cache para o player reativo';

  @override
  String get storageColorCacheTitle => 'Cache de cores';

  @override
  String get storageColorCacheSubtitle =>
      'Cores de tema em cache a partir das capas';

  @override
  String get storageLyricsCacheTitle => 'Cache de letras';

  @override
  String get storageLyricsCacheSubtitle =>
      'Disponibilidade e texto das letras em cache';

  @override
  String get storageBlurredCacheTitle => 'Cache de desfoque';

  @override
  String get storageBlurredCacheSubtitle => 'Fundos desfocados pré-gerados';

  @override
  String get storageClearCache => 'Limpar cache';

  @override
  String get storageClearDatabaseTitle => 'Limpar base de dados?';

  @override
  String get storageClearDatabaseBody =>
      'Isto vai eliminar permanentemente todos os teus dados de utilizador, incluindo:\n\n• Todas as listas de reprodução\n• Favoritos e músicas ocultas\n• Estatísticas de reprodução\n• Definições e preferências da aplicação\n\nA aplicação será redefinida. Esta ação não pode ser desfeita.';

  @override
  String get storageClearDatabaseAction => 'Limpar base de dados';

  @override
  String storageClearDatabaseError(Object error) {
    return 'Erro ao limpar a base de dados: $error';
  }

  @override
  String get storageClearCoversTitle => 'Limpar cache de capas?';

  @override
  String get storageClearCoversBody =>
      'Isto vai eliminar todas as capas em cache.\n\nAs capas serão reextraídas dos teus ficheiros de música na próxima vez que navegares pela biblioteca.';

  @override
  String get storageClearCoversAction => 'Limpar capas';

  @override
  String get storageClearCoversSuccess => 'Cache de capas limpo com sucesso';

  @override
  String storageClearCoversError(Object error) {
    return 'Erro ao limpar as capas: $error';
  }

  @override
  String get storageClearBackupsTitle => 'Limpar cópias de segurança?';

  @override
  String get storageClearBackupsBody =>
      'Isto vai eliminar todos os ficheiros de cópia de segurança locais.\n\nGarante que exportaste todas as cópias de segurança importantes antes de continuar.';

  @override
  String get storageClearBackupsAction => 'Limpar cópias de segurança';

  @override
  String get storageClearBackupsSuccess =>
      'Cópias de segurança limpas com sucesso';

  @override
  String storageClearBackupsError(Object error) {
    return 'Erro ao limpar as cópias de segurança: $error';
  }

  @override
  String get storageClearLibraryTitle => 'Limpar cache da biblioteca?';

  @override
  String get storageClearLibraryBody =>
      'Isto vai limpar o cache da biblioteca.\n\nA tua biblioteca de músicas será analisada novamente na próxima vez que abrires a aplicação.';

  @override
  String get storageClearLibrarySuccess =>
      'Cache da biblioteca limpo com sucesso';

  @override
  String storageClearLibraryError(Object error) {
    return 'Erro ao limpar o cache da biblioteca: $error';
  }

  @override
  String get storageClearSearchTitle => 'Limpar índice de pesquisa?';

  @override
  String get storageClearSearchBody =>
      'Isto vai eliminar o índice de pesquisa.\n\nO índice de pesquisa será reconstruído automaticamente quando analisares a tua biblioteca novamente.';

  @override
  String get storageClearSearchAction => 'Limpar índice';

  @override
  String get storageClearSearchSuccess =>
      'Índice de pesquisa limpo com sucesso';

  @override
  String storageClearSearchError(Object error) {
    return 'Erro ao limpar o índice de pesquisa: $error';
  }

  @override
  String get storageClearWaveformTitle => 'Limpar cache de formas de onda?';

  @override
  String get storageClearWaveformBody =>
      'Isto vai eliminar todas as formas de onda das músicas em cache.\n\nAs formas de onda serão regeneradas na próxima vez que abrires os detalhes de uma música.';

  @override
  String get storageClearWaveformSuccess =>
      'Cache de formas de onda limpo com sucesso';

  @override
  String storageClearWaveformError(Object error) {
    return 'Erro ao limpar o cache de formas de onda: $error';
  }

  @override
  String get storageClearBeatTitle => 'Limpar análise de batidas?';

  @override
  String get storageClearBeatBody =>
      'Isto vai eliminar os mapas de batidas em cache usados pelo player reativo às batidas.\n\nEles são reconstruídos automaticamente na próxima vez que cada música tocar.';

  @override
  String get storageClearBeatSuccess =>
      'Cache de análise de batidas limpo com sucesso';

  @override
  String storageClearBeatError(Object error) {
    return 'Erro ao limpar o cache de análise de batidas: $error';
  }

  @override
  String get storageClearColorTitle => 'Limpar cache de cores?';

  @override
  String get storageClearColorBody =>
      'Isto vai eliminar todas as cores de tema em cache.\n\nAs cores serão reextraídas das capas na próxima vez que as músicas tocarem.';

  @override
  String get storageClearColorSuccess => 'Cache de cores limpo com sucesso';

  @override
  String storageClearColorError(Object error) {
    return 'Erro ao limpar o cache de cores: $error';
  }

  @override
  String get storageClearLyricsTitle => 'Limpar cache de letras?';

  @override
  String get storageClearLyricsBody =>
      'Isto vai remover as pesquisas de letras em cache.\n\nAs letras serão lidas novamente da metadata da música quando necessário.';

  @override
  String get storageClearLyricsSuccess => 'Cache de letras limpo com sucesso';

  @override
  String storageClearLyricsError(Object error) {
    return 'Erro ao limpar o cache de letras: $error';
  }

  @override
  String get storageClearBlurredTitle => 'Limpar cache de fundos desfocados?';

  @override
  String get storageClearBlurredBody =>
      'Isto vai eliminar todos os fundos desfocados pré-gerados.\n\nEles serão regerados na próxima vez que acionares uma reconstrução no Indexador.';

  @override
  String get storageClearBlurredSuccess =>
      'Cache de fundos desfocados limpo com sucesso';

  @override
  String storageClearBlurredError(Object error) {
    return 'Erro ao limpar o cache de desfoque: $error';
  }

  @override
  String get storageClearAllTitle => 'Limpar todos os dados da aplicação?';

  @override
  String get storageClearAllBody =>
      'Esta ação é perigosa e não pode ser desfeita.\n\nEla vai eliminar permanentemente:\n• Todas as tuas preferências e definições\n• Estatísticas e histórico de reprodução\n• Capas de músicas em cache\n• Todas as cópias de segurança locais\n• Cache da biblioteca\n• Índice de pesquisa\n• Cache de formas de onda\n• Cache de letras\n\nA aplicação será redefinida.';

  @override
  String get storageClearAllAction => 'Limpar tudo';

  @override
  String storageClearAllError(Object error) {
    return 'Erro ao limpar os dados: $error';
  }

  @override
  String get storageClearAllTile => 'Limpar todos os dados do utilizador';

  @override
  String get storageClearAllTileSubtitle =>
      'Eliminar permanentemente todos os dados e redefinir a aplicação';

  @override
  String get storageFinalConfirmTitle => 'Confirmação final';

  @override
  String storageConfirmTypePrompt(Object word) {
    return 'Para confirmar, escreve \"$word\" abaixo:';
  }

  @override
  String get storageDeleteKeyword => 'ELIMINAR';

  @override
  String get storageConfirmUpper => 'CONFIRMAR';

  @override
  String get storageTypeExactly => 'Escreve o texto de confirmação exatamente.';

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
  String get settingsSearchIndexerSubtitle => 'Reconstruir índices e caches';

  @override
  String get settingsSearchMusicFoldersTitle => 'Pastas de música';

  @override
  String get settingsSearchMusicFoldersSubtitle =>
      'Gerir as pastas da biblioteca de músicas';

  @override
  String get settingsSearchRescanTitle => 'Analisar biblioteca agora';

  @override
  String get settingsSearchRescanSubtitle =>
      'Atualizar manualmente todas as músicas do disco';

  @override
  String get settingsSearchIncludeVideosTitle => 'Incluir vídeos';

  @override
  String get settingsSearchIncludeVideosSubtitle =>
      'Mostrar ficheiros de vídeo na tua biblioteca de músicas';

  @override
  String get settingsSearchMinFileSizeTitle => 'Tamanho mínimo do ficheiro';

  @override
  String get settingsSearchMinFileSizeSubtitle =>
      'Ignorar ficheiros menores que isso';

  @override
  String get settingsSearchMinDurationTitle => 'Duração mínima';

  @override
  String get settingsSearchMinDurationSubtitle =>
      'Ignorar faixas mais curtas que isso';

  @override
  String get settingsSearchManageFoldersTitle => 'Gerir pastas de música';

  @override
  String get settingsSearchManageFoldersSubtitle =>
      'Adicionar, remover e analisar pastas individuais';

  @override
  String get settingsSearchPullToRefreshTitle => 'Puxar para atualizar';

  @override
  String get settingsSearchPullToRefreshSubtitle =>
      'Deslizar para baixo para atualizar a biblioteca';

  @override
  String get settingsSearchAutoPauseMuteTitle => 'Pausar ao silenciar';

  @override
  String get settingsSearchAutoPauseMuteSubtitle =>
      'Pausar a reprodução quando o volume chegar a 0';

  @override
  String get settingsSearchAutoResumeUnmuteTitle => 'Retomar ao reativar o som';

  @override
  String get settingsSearchAutoResumeUnmuteSubtitle =>
      'Retomar a reprodução quando o volume for restaurado';

  @override
  String get settingsSearchGapTitle => 'Intervalo / Atraso';

  @override
  String get settingsSearchGapSubtitle => 'Silêncio entre as faixas';

  @override
  String get settingsSearchFadeOutTitle => 'Fade de saída';

  @override
  String get settingsSearchFadeOutSubtitle => 'Fade na faixa que sai';

  @override
  String get settingsSearchFadeInTitle => 'Fade de entrada';

  @override
  String get settingsSearchFadeInSubtitle => 'Fade na faixa que entra';

  @override
  String get settingsSearchFadePlayTitle => 'Fade ao tocar';

  @override
  String get settingsSearchFadePlaySubtitle =>
      'Aumentar o volume gradualmente quando a reprodução começa';

  @override
  String get settingsSearchFadePauseTitle => 'Fade ao pausar';

  @override
  String get settingsSearchFadePauseSubtitle =>
      'Diminuir o volume gradualmente quando a reprodução para';

  @override
  String get settingsSearchTargetLangSubtitle =>
      'Idioma para o qual traduzir as letras';

  @override
  String get settingsSearchTranslationModeSubtitle =>
      'Mostrar subtexto abaixo das letras ou substituir as letras base';

  @override
  String get settingsSearchVisualizerSubtitle =>
      'Desativado, barras clássicas ou barras sincronizadas com a música';

  @override
  String get settingsSearchLanguageSubtitle => 'Escolhe o idioma da aplicação';

  @override
  String get settingsSearchProgressBarSubtitle =>
      'Barra de progresso padrão, de forma de onda ou reativa ao som';

  @override
  String get settingsSearchSongDurationTitle => 'Mostrar duração da música';

  @override
  String get settingsSearchSongDurationSubtitle =>
      'Mostrar a duração nas listas de músicas';

  @override
  String get settingsSearchAutoHideBarsTitle =>
      'Ocultar barras automaticamente';

  @override
  String get settingsSearchAutoHideBarsSubtitle =>
      'O cabeçalho e a barra inferior ocultam-se ao deslocar para baixo';

  @override
  String get settingsSearchAppIconSubtitle => 'Escolhe qual ícone o wispie usa';

  @override
  String get settingsSearchBeatCoverSubtitle =>
      'A capa pulsa com a batida (apenas player clássico)';

  @override
  String get settingsSearchSpinArtworkSubtitle =>
      'A capa gira na barra inferior minimizada enquanto uma música toca';

  @override
  String get settingsSearchCoverIntensitySubtitle =>
      'Quão fortemente a capa reage à batida';

  @override
  String get settingsSearchParticleDensitySubtitle =>
      'Quantas partículas e quão vivas elas são';

  @override
  String get settingsSearchBeatOffsetSubtitle =>
      'Compensar a latência de saída do Bluetooth';

  @override
  String get settingsSearchQuickPicksSubtitle =>
      'Mostrar recomendações de escolhas rápidas';

  @override
  String get settingsSearchRecentQueuesSubtitle =>
      'Mostrar filas tocadas recentemente';

  @override
  String get settingsSearchForYouSubtitle =>
      'Mostrar listas de reprodução recomendadas';

  @override
  String get settingsSearchQuickActionsSubtitle =>
      'Personalizar ações de premir e manter premido';

  @override
  String get settingsSearchReorderQuickActionsTitle =>
      'Reordenar ações rápidas';

  @override
  String get settingsSearchReorderQuickActionsSubtitle =>
      'Escolher e ordenar as ações de premir e manter premido numa música';

  @override
  String get settingsSearchBulkRenameTitle => 'Renomear ficheiros em massa';

  @override
  String get settingsSearchBulkRenameSubtitle =>
      'Renomear toda a biblioteca a partir de um formato';

  @override
  String get settingsSearchManageStorageSubtitle =>
      'Uso de disco e gestão de dados';

  @override
  String get settingsSearchBackupsSubtitle =>
      'Navegar, restaurar e eliminar cópias de segurança guardadas';

  @override
  String get settingsSearchStorageUsageSubtitle =>
      'Uso de disco por capas, formas de onda, letras e caches';

  @override
  String get settingsCrumbStorage => 'Definições › Armazenamento';

  @override
  String get settingsCrumbLibrary => 'Definições › Biblioteca';

  @override
  String get settingsCrumbLibraryFilters => 'Definições › Biblioteca › Filtros';

  @override
  String get settingsCrumbLibraryFolders =>
      'Definições › Biblioteca › Pastas de música';

  @override
  String get settingsCrumbLibraryMaintenance =>
      'Definições › Biblioteca › Manutenção';

  @override
  String get settingsCrumbPlaybackAudio => 'Definições › Reprodução › Áudio';

  @override
  String get settingsCrumbPlaybackTransitions =>
      'Definições › Reprodução › Transições';

  @override
  String get settingsCrumbPlaybackPlayPause =>
      'Definições › Reprodução › Tocar / Pausar';

  @override
  String get settingsCrumbLyricsTiming =>
      'Definições › Letras › Exibição e sincronização';

  @override
  String get settingsCrumbLyricsTranslation => 'Definições › Letras › Tradução';

  @override
  String get settingsCrumbAppearanceLanguage =>
      'Definições › Aparência › Idioma';

  @override
  String get settingsCrumbAppearanceNowPlaying =>
      'Definições › Aparência › A tocar agora';

  @override
  String get settingsCrumbAppearanceAppIcon =>
      'Definições › Aparência › Ícone da aplicação';

  @override
  String get settingsCrumbAppearanceMotion =>
      'Definições › Aparência › Movimento do player';

  @override
  String get settingsCrumbAppearanceLists =>
      'Definições › Aparência › Listas e navegação';

  @override
  String get settingsCrumbHomeLists =>
      'Definições › Início e navegação › Listas e navegação';

  @override
  String get settingsCrumbHomeScreen =>
      'Definições › Início e navegação › Ecrã inicial';

  @override
  String get settingsCrumbBackup =>
      'Definições › Cópias de segurança e restauração';

  @override
  String get settingsCrumbAutoBackups =>
      'Definições › Cópias de segurança e restauração › Cópias de segurança automáticas';

  @override
  String get settingsCrumbManageBackups =>
      'Definições › Gestão de dados › Gerir cópias de segurança';

  @override
  String get settingsCrumbManageStorage =>
      'Definições › Gestão de dados › Gerir armazenamento';

  @override
  String get settingsCrumbProfileShuffle => 'Perfil › Aleatório';

  @override
  String get settingsKwLibrary => 'análise,pastas,filtros,músicas,biblioteca';

  @override
  String get settingsKwPlayback => 'áudio,som,transições,reprodução';

  @override
  String get settingsKwLyrics => 'letras,traduzir,karaoke,legendas';

  @override
  String get settingsKwHome => 'início,escolhas rápidas,gestos,barras,layout';

  @override
  String get settingsKwStorage => 'disco,espaço,cache,indexador,limpeza';

  @override
  String get settingsKwAppearance => 'tema,cor,exibição,visual,aparência';

  @override
  String get settingsKwSync => 'nuvem,conta,dispositivos,encriptado';

  @override
  String get settingsKwBackup =>
      'cópia de segurança,restaurar,exportar,importar,dados';

  @override
  String get settingsKwIndexer => 'índice,reconstruir,cache,reindexar';

  @override
  String get settingsKwAbout =>
      'versão,atualização,notas de lançamento,lançamento';

  @override
  String get settingsKwFolders => 'diretório,caminho,adicionar pasta,fontes';

  @override
  String get settingsKwRescan => 'atualizar,recarregar,sincronizar';

  @override
  String get settingsKwVideos => 'vídeo,mp4,clipes';

  @override
  String get settingsKwMinFileSize => 'tamanho,ignorar,pequeno,filtro';

  @override
  String get settingsKwMinDuration => 'duração,curto,ignorar,filtro,interlúdio';

  @override
  String get settingsKwManageFolders =>
      'pasta,diretório,armazenamento,cartão sd';

  @override
  String get settingsKwPullToRefresh => 'deslizar,gesto,recarregar';

  @override
  String get settingsKwMute => 'volume,silencioso,mudo';

  @override
  String get settingsKwUnmute => 'volume,ativar som,continuar';

  @override
  String get settingsKwGap => 'pausa,silêncio,entre,transição';

  @override
  String get settingsKwCrossfade =>
      'crossfade,sem intervalos,transição,mistura';

  @override
  String get settingsKwFadePlay => 'aumento gradual,volume,início';

  @override
  String get settingsKwFadePause => 'diminuição gradual,volume,parar';

  @override
  String get settingsKwRichSync =>
      'letras,richsync,karaoke,palavra,sincronização';

  @override
  String get settingsKwSidebar => 'barra lateral,painel,desktop,fila,letras';

  @override
  String get settingsKwKeepAwake => 'sono,manter ativo,ecrã,letras';

  @override
  String get settingsKwAutoTranslate =>
      'traduzir,tradução,idioma,letras,automático';

  @override
  String get settingsKwTargetLang => 'traduzir,idioma,espanhol,inglês,japonês';

  @override
  String get settingsKwTranslationMode =>
      'traduzir,modo,subtexto,substituir,exibição';

  @override
  String get settingsKwVisualizer =>
      'onda,animação,espectro,barras,sincronização,grave';

  @override
  String get settingsKwLanguage => 'idioma,região,tradução,inglês';

  @override
  String get settingsKwProgressBar =>
      'procurar,progresso,onda,reativo,espectro';

  @override
  String get settingsKwHaptics =>
      'vibrar,tátil,retorno,forma de onda,arrastar,procurar';

  @override
  String get settingsKwSongDuration => 'duração,tempo,listas';

  @override
  String get settingsKwAutoHide =>
      'navegação,dock,cabeçalho,deslocamento,ocultar';

  @override
  String get settingsKwCoverSizing => 'capa,arte do álbum,proporção,corte';

  @override
  String get settingsKwImmersive =>
      'imersivo,ecrã inteiro,player,detalhe,gradiente,capa,design';

  @override
  String get settingsKwAppIcon => 'ícone,logo,iniciador,dock,clássico,novo';

  @override
  String get settingsKwBeatCover => 'pulso,batida,capa,movimento';

  @override
  String get settingsKwSpinArtwork => 'girar,rotacionar,rodar,capa,dock,mini';

  @override
  String get settingsKwBeatParticles =>
      'partículas,flutuantes,batida,movimento';

  @override
  String get settingsKwCoverIntensity =>
      'capa,álbum,pulso,sutil,equilibrado,intenso';

  @override
  String get settingsKwParticleDensity =>
      'partículas,flutuantes,densidade,sutil,equilibrado,intenso';

  @override
  String get settingsKwBeatOffset =>
      'bluetooth,latência,atraso,sincronização,antecipado';

  @override
  String get settingsKwCalibrate =>
      'calibrar,sincronização,latência,deslocamento,teste,clique';

  @override
  String get settingsKwQuickPicks => 'início,recomendações,sugestões';

  @override
  String get settingsKwRecentQueues => 'início,histórico,fila';

  @override
  String get settingsKwForYou => 'início,mixes,recomendações';

  @override
  String get settingsKwQuickActions => 'premir e manter,menu,atalhos';

  @override
  String get settingsKwReorderQuickActions =>
      'premir e manter,ordem,menu,atalhos';

  @override
  String get settingsKwExport => 'cópia de segurança,guardar,exportar';

  @override
  String get settingsKwImport => 'restaurar,carregar,importar';

  @override
  String get settingsKwManageBackups => 'cópia de segurança,restaurar,eliminar';

  @override
  String get settingsKwBulkRename =>
      'renomear,nomes de ficheiro,lote,massa,formato,nomenclatura';

  @override
  String get settingsKwManageStorage => 'disco,espaço,cache,limpeza';

  @override
  String get settingsKwBackups => 'cópia de segurança,restaurar,ficheiro';

  @override
  String get settingsKwStorageUsage => 'disco,espaço,limpar cache,uso';

  @override
  String get settingsKwAutoBackup => 'agenda,frequência,automático';

  @override
  String get settingsKwAutoBackupContent => 'conteúdo,categorias,automático';

  @override
  String get settingsKwAutoDelete => 'poda,limpeza,retenção,antigo';

  @override
  String get settingsKwShuffle =>
      'aleatorizar,personalidade,pesos,aleatório,explorador';

  @override
  String get setupUnableToAccessFolder =>
      'Não foi possível aceder à pasta selecionada';

  @override
  String get setupStoragePermissionRequired =>
      'A permissão de armazenamento é necessária para analisar a tua biblioteca de músicas.';

  @override
  String get setupEnterDisplayName => 'Escreve um nome de exibição';

  @override
  String setupSetupError(String error) {
    return 'Erro de configuração: $error';
  }

  @override
  String get setupIntroTagline => 'A tua música fica no teu dispositivo.';

  @override
  String get setupGetStarted => 'Começar';

  @override
  String get setupPreviousStep => 'Etapa anterior';

  @override
  String get setupSettingThingsUp => 'A configurar tudo';

  @override
  String get setupStartListening => 'Começar a ouvir';

  @override
  String get setupContinue => 'Continuar';

  @override
  String get setupNameTitle => 'Como devemos chamar-te?';

  @override
  String get setupNameSubtitle =>
      'O wispie usa o teu nome para te cumprimentar e assinar o teu histórico de audição. Nada sai deste dispositivo de qualquer forma.';

  @override
  String get setupNameHint => 'O teu nome';

  @override
  String setupGreeting(String name) {
    return 'Prazer em conhecer-te, $name.';
  }

  @override
  String get setupAppearanceTitle => 'Deixa com a aparência que preferires.';

  @override
  String get setupAppearanceSubtitle =>
      'Tudo nesta página também fica nas Definições, então podes mudar quando quiseres.';

  @override
  String get setupImmersiveSubtitle =>
      'Um player de capa em ecrã inteiro e ecrãs de detalhes com gradiente.';

  @override
  String get setupVisualizerSubtitle =>
      'Barras sobre a capa enquanto ouves. Sincronizado acompanha a música em vez de um padrão aleatório.';

  @override
  String get setupBeatCoverSubtitle => 'A capa respira a cada batida.';

  @override
  String get setupParticlesSubtitle =>
      'Partículas flutuam pelo player, e cada batida impulsiona-as mais em vez de apenas as piscar.';

  @override
  String get setupProgressBarTitle => 'Barra de progresso';

  @override
  String get setupProgressBarSubtitle =>
      'Desenhe a própria música como uma forma de onda em vez de uma linha simples. O som reativo fá-la mexer-se enquanto toca.';

  @override
  String get setupFoldersTitle => 'Onde está a tua música?';

  @override
  String get setupFoldersSubtitle =>
      'Aponta o wispie para as pastas onde estão as tuas músicas. Ele apenas as lê, e podes adicionar quantas quiseres.';

  @override
  String get setupStoragePermissionTitle => 'Permissão de armazenamento';

  @override
  String get setupStoragePermissionSubtitle =>
      'O wispie precisa dela para encontrar ficheiros de áudio neste dispositivo.';

  @override
  String get setupOpenSystemSettings => 'Abrir definições do sistema';

  @override
  String get setupGrantPermission => 'Conceder permissão';

  @override
  String get setupNoFoldersTitle => 'Nenhuma pasta ainda';

  @override
  String get setupNoFoldersSubtitle =>
      'Adiciona a pasta que contém as tuas músicas.';

  @override
  String get setupRemoveFolderTooltip => 'Remover pasta';

  @override
  String get setupAddFolder => 'Adicionar uma pasta';

  @override
  String get setupSummaryMusicFolders => 'Pastas de música';

  @override
  String get setupReadyTitle => 'Tudo pronto.';

  @override
  String setupReadyTitleNamed(String name) {
    return 'Tudo pronto, $name.';
  }

  @override
  String get setupReadySubtitle =>
      'Aqui está o que configurámos. Podes alterar qualquer coisa depois nas Definições.';

  @override
  String get setupOn => 'Ativado';

  @override
  String get setupOff => 'Desativado';

  @override
  String backupLoadError(Object error) {
    return 'Erro ao carregar backups: $error';
  }

  @override
  String backupCreated(Object name) {
    return 'Backup criado: $name';
  }

  @override
  String backupCreateFailed(Object error) {
    return 'Falha ao criar backup: $error';
  }

  @override
  String backupValidateFailed(Object error) {
    return 'Falha ao validar backup: $error';
  }

  @override
  String get backupReplaceTitle => 'PERIGO: Substituição total dos dados';

  @override
  String backupReplaceConfirm(Object name) {
    return 'Tens a certeza absoluta de que queres restaurar de $name?';
  }

  @override
  String get backupReplaceWarning =>
      'AVISO: Isto vai SUBSTITUIR COMPLETAMENTE todos os teus dados atuais:';

  @override
  String get backupReplaceItemStats =>
      '• Todas as tuas estatísticas atuais e histórico de reprodução';

  @override
  String get backupReplaceItemFavorites =>
      '• Todos os teus favoritos e listas de reprodução';

  @override
  String get backupReplaceItemHidden =>
      '• Todas as tuas músicas ocultas e preferências';

  @override
  String get backupReplaceItemSettings =>
      '• Todas as tuas definições e estado atuais';

  @override
  String get backupReplaceItemLibrary =>
      '• A tua biblioteca de músicas analisada';

  @override
  String get backupReplaceRekeyNote =>
      'As capas e os caminhos de ficheiro são revinculados a este dispositivo automaticamente após a restauração. As faixas do backup cujos ficheiros não estão neste dispositivo são removidas da biblioteca.';

  @override
  String get backupReplaceIrreversible =>
      'OS TEUS DADOS ATUAIS SERÃO PERDIDOS PERMANENTEMENTE!';

  @override
  String get backupReplaceNoUndo =>
      'Não há NENHUMA forma de desfazer esta ação.';

  @override
  String get backupReplaceConfirmAction => 'SIM, SUBSTITUIR TUDO';

  @override
  String get backupRestoringLabel => 'A restaurar dados…';

  @override
  String get backupRestoreSuccess =>
      'Todos os dados foram substituídos com sucesso!';

  @override
  String backupRestoreFailed(Object error) {
    return 'Falha ao restaurar backup: $error';
  }

  @override
  String get backupDeleteTitle => 'Eliminar backup';

  @override
  String backupDeleteConfirm(Object name) {
    return 'Tens a certeza de que queres eliminar $name?';
  }

  @override
  String get backupDeleteUpper => 'ELIMINAR';

  @override
  String get backupDeleted => 'Backup eliminado';

  @override
  String backupDeleteFailed(Object error) {
    return 'Falha ao eliminar backup: $error';
  }

  @override
  String backupExportedTo(Object path) {
    return 'Backup exportado para: $path';
  }

  @override
  String get backupNoOlderBackup => 'Não há backup mais antigo para comparar.';

  @override
  String get backupComparing => 'A comparar backups...';

  @override
  String backupComparisonTitle(int number) {
    return 'Comparação com #$number';
  }

  @override
  String get backupDiffStatsRows => 'Linhas de estatísticas';

  @override
  String get backupDiffSize => 'Tamanho';

  @override
  String get backupDiffDataAdded => 'Dados adicionados';

  @override
  String get backupCloseUpper => 'FECHAR';

  @override
  String backupCompareError(Object error) {
    return 'Erro ao comparar backups: $error';
  }

  @override
  String get backupNoChange => 'Sem alterações';

  @override
  String get backupManagementTitle => 'Gestão de backups';

  @override
  String get backupCreating => 'A criar...';

  @override
  String get backupCreateAction => 'Criar backup';

  @override
  String get backupEmptyTitle => 'Nenhum backup ainda';

  @override
  String get backupEmptySubtitle =>
      'Cria o teu primeiro backup para proteger os teus dados';

  @override
  String backupSizeLabel(Object size) {
    return 'Tamanho: $size';
  }

  @override
  String get backupActionRestore => 'Restaurar';

  @override
  String get backupActionCompare => 'Comparar';

  @override
  String get backupRestartTitle => 'Reinicialização necessária';

  @override
  String get backupRestartMessage =>
      'A restauração do backup foi concluída com sucesso.\n\nA aplicação precisa de ser reiniciada para aplicar todas as alterações corretamente.';

  @override
  String get backupRestartNow => 'Reiniciar agora';

  @override
  String get backupSelectContentSubtitle => 'Seleciona o conteúdo do backup';

  @override
  String get backupContentArtistArtCache => 'Cache de imagens de artistas';

  @override
  String get backupContentAlbumArtCache => 'Cache de capas de álbum';

  @override
  String get backupContentDescUserStats =>
      'Histórico de reprodução, estatísticas, grupos unidos';

  @override
  String get backupContentDescUserData =>
      'Favoritos, listas de reprodução, preferências';

  @override
  String get backupContentDescUserSettings =>
      'Tema, ordem de classificação, preferências da aplicação';

  @override
  String get backupContentDescCoverCache => 'Capas de álbum em cache';

  @override
  String get backupContentDescLibraryCache => 'Metadados em cache';

  @override
  String get backupContentDescSearchIndex => 'Base de dados de pesquisa';

  @override
  String get backupContentDescWaveformCache => 'Dados de forma de onda';

  @override
  String get backupContentDescColorCache => 'Paletas de cores';

  @override
  String get backupContentDescLyricsCache => 'Letras em cache';

  @override
  String get backupContentDescArtistArtCache => 'Imagens de artistas em cache';

  @override
  String get backupContentDescAlbumArtCache => 'Imagens de álbuns em cache';

  @override
  String get backupRestoringDataTitle => 'A restaurar dados';

  @override
  String get importSelectTitle => 'Seleciona os dados a restaurar';

  @override
  String get importSectionCache => 'Cache';

  @override
  String get importOptionsTitle => 'Opções de restauração';

  @override
  String get importReplaceDatabases => 'Substituir bases de dados';

  @override
  String get importReplaceDatabasesSubtitle =>
      'Limpar os dados existentes antes de restaurar';

  @override
  String get syncEnterPassword => 'Introduz a tua palavra-passe';

  @override
  String syncAuthUnexpectedError(String error) {
    return 'Algo correu mal: $error';
  }

  @override
  String get syncUsernameTaken => 'Esse nome de utilizador já está em uso';

  @override
  String get syncModeRecover => 'Recuperar';

  @override
  String get syncUsername => 'Nome de utilizador';

  @override
  String get syncEncryptionWarning =>
      'Os teus dados são encriptados de ponta a ponta. Se perderes a palavra-passe e a chave de recuperação, não poderão ser recuperados.';

  @override
  String get syncSecuringAccount => 'A proteger a tua conta...';

  @override
  String get syncCreateAccount => 'Criar conta';

  @override
  String get syncLogIn => 'Entrar';

  @override
  String get syncRecoverAccount => 'Recuperar conta';

  @override
  String get syncHideAdvanced => 'Ocultar avançado';

  @override
  String get syncAdvanced => 'Avançado';

  @override
  String get syncRecoveryKeySaved => 'Chave de recuperação guardada';

  @override
  String get syncCouldNotSaveFile => 'Não foi possível guardar o ficheiro';

  @override
  String get syncRecoveryKeyRevealTitle => 'A tua chave de recuperação';

  @override
  String get syncRecoveryKeyRevealBody =>
      'Esta é a única forma de recuperar o acesso se te esqueceres da palavra-passe. É mostrada uma única vez. Guarda-a num lugar seguro.';

  @override
  String get syncCopied => 'Copiado';

  @override
  String get syncCopy => 'Copiar';

  @override
  String get syncSaveToFile => 'Guardar em ficheiro';

  @override
  String get syncRecoveryKeySavedCheckbox =>
      'Guardei a minha chave de recuperação';

  @override
  String get syncUploadTitle => 'Envia os dados da tua biblioteca';

  @override
  String get syncSetupDeviceTitle => 'Configurar este dispositivo';

  @override
  String get syncFreshAccountBody =>
      'A sincronização automática é ativada depois de os teus dados serem enviados uma vez.';

  @override
  String get syncChooseDeviceBody =>
      'Escolhe como este dispositivo entra nos teus dados na nuvem. A sincronização automática é ativada depois desta etapa.';

  @override
  String get syncEverythingNow => 'Sincronizar tudo agora';

  @override
  String get syncMergeWithCloud => 'Unir este dispositivo com a nuvem';

  @override
  String get syncSetupNewDevice => 'Configurar como novo dispositivo';

  @override
  String get syncMergeExplanation =>
      'Unir mantém os dois lados. Configurar como novo dispositivo apaga primeiro os dados sincronizados deste dispositivo e é mais seguro se este dispositivo já guarda uma cópia mais antiga do mesmo histórico.';

  @override
  String get syncCloudReplacedTitle => 'Os dados na nuvem foram substituídos';

  @override
  String get syncCloudReplacedBody =>
      'Outro dispositivo sobrescreveu a nuvem. A sincronização está pausada neste dispositivo até escolheres.';

  @override
  String get syncMergeIntoCloud =>
      'Unir este dispositivo aos novos dados da nuvem';

  @override
  String get syncPhaseSigningIn => 'A entrar...';

  @override
  String get syncPhaseCheckingCloud => 'A verificar a nuvem...';

  @override
  String get syncPhaseDownloadingBackup => 'A transferir o backup...';

  @override
  String get syncPhaseApplyingBackup => 'A aplicar o backup...';

  @override
  String get syncPhaseDownloadingChanges => 'A transferir alterações...';

  @override
  String get syncPhaseMerging => 'A unir...';

  @override
  String get syncPhasePreparingUpload => 'A preparar o envio...';

  @override
  String get syncPhaseEncrypting => 'A encriptar...';

  @override
  String get syncPhaseUploading => 'A enviar...';

  @override
  String get syncPhaseFinishing => 'A finalizar...';

  @override
  String get syncPhaseError => 'Falha na sincronização';

  @override
  String get syncSyncing => 'A sincronizar...';

  @override
  String syncServerInfo(String name, String version) {
    return '$name - API v$version';
  }

  @override
  String syncServerInfoClosed(String name, String version) {
    return '$name - API v$version - registo fechado';
  }

  @override
  String get syncServerUnreachable => 'Não foi possível alcançar o servidor';

  @override
  String get syncInsecureHttpWarning =>
      'http simples: usa apenas numa rede privada fiável';

  @override
  String get syncServerUrl => 'URL do servidor';

  @override
  String get syncChecking => 'A verificar...';

  @override
  String get syncCheckServer => 'Verificar servidor';

  @override
  String get syncResetDefault => 'Restaurar predefinição';

  @override
  String get autoBackupRunningTitle => 'A fazer backup';

  @override
  String get autoBackupRunningSubtitle => 'A criar o backup...';

  @override
  String get autoBackupCompleteTitle => 'Backup automático concluído';

  @override
  String get autoBackupSaved => 'Backup guardado';

  @override
  String get autoBackupFailedTitle => 'Falha no backup automático';

  @override
  String get autoBackupPermissionTitle => 'Permissão necessária';

  @override
  String get autoBackupPermissionSubtitle =>
      'O backup automático precisa de acesso ao armazenamento';

  @override
  String get autoBackupGrant => 'Conceder';

  @override
  String get downgradeTitle => 'Versão mais antiga detetada';

  @override
  String downgradeMessage(String previousVersion, String currentVersion) {
    return 'O wispie foi aberto pela última vez em $previousVersion, mas esta é a $currentVersion. Os teus dados podem ter sido alterados por uma versão mais recente e podem quebrar ou perder-se nesta.';
  }

  @override
  String get downgradeQuit => 'Sair';

  @override
  String get downgradeRiskIt => 'Arriscar';

  @override
  String get indexerSettingsGroupTitle => 'Definições do indexador';

  @override
  String get indexerPreventDuplicatesTitle => 'Evitar faixas duplicadas';

  @override
  String get indexerPreventDuplicatesSubtitle =>
      'Ocultar músicas com o mesmo nome de ficheiro em pastas diferentes';

  @override
  String get indexerExtractFeaturedTitle => 'Extrair artistas participantes';

  @override
  String get indexerExtractFeaturedSubtitle =>
      'Mover artistas com \"ft./feat.\" do título para o campo de artista';

  @override
  String get indexerDatabaseOpsGroupTitle => 'Operações de base de dados';

  @override
  String get indexerWarnRestart =>
      'Esta operação exige reiniciar a aplicação para aplicar as alterações.';

  @override
  String get indexerCoverSearchGroupTitle => 'Capa e pesquisa';

  @override
  String get indexerWarnRepairLinks =>
      'As faixas cujos ficheiros já não estão neste dispositivo serão removidas da biblioteca. Favoritos, listas de reprodução e contagens de reprodução são mantidos e voltam a ligar-se se os ficheiros voltarem.';

  @override
  String get indexerWarnSearchRestart =>
      'Talvez seja preciso reiniciar a aplicação para que as alterações no índice de pesquisa sejam aplicadas por completo.';

  @override
  String get indexerContentCachesGroupTitle => 'Caches de conteúdo';

  @override
  String get indexerRecommendationsGroupTitle => 'Recomendações';

  @override
  String get indexerTitle => 'Indexador';

  @override
  String indexerArtistsAlbumsProgress(String artists, String albums) {
    return 'Artistas $artists · Álbuns $albums...';
  }

  @override
  String indexerProcessing(String progress) {
    return 'A processar $progress...';
  }

  @override
  String get indexerUnknownError => 'Erro desconhecido';

  @override
  String get indexerCompleted => 'Concluído';

  @override
  String indexerCached(int processed, int total) {
    return '$processed/$total em cache';
  }

  @override
  String indexerCachedFailed(int processed, int total, int failed) {
    return '$processed/$total em cache ($failed com falha)';
  }

  @override
  String get indexerReadyToRebuild => 'Pronto para reconstruir';

  @override
  String indexerArtistsOnly(String progress) {
    return 'Artistas $progress';
  }

  @override
  String indexerAlbumsOnly(String progress) {
    return 'Álbuns $progress';
  }

  @override
  String indexerFailedItemsQuestion(int failed) {
    return 'Este cache tem $failed itens com falha. O que queres fazer?';
  }

  @override
  String indexerViewFailed(int failed) {
    return 'Ver $failed com falha';
  }

  @override
  String get indexerRetryFailed => 'Tentar novamente os que falharam';

  @override
  String get indexerForceRebuild => 'Forçar reconstrução';

  @override
  String indexerAlreadyCompleteQuestion(int processed, int total) {
    return 'Este cache já está completo ($processed/$total). Queres forçar a reconstrução?';
  }

  @override
  String get indexerDoIt => 'Fazer isso';

  @override
  String indexerOptimizing(String name) {
    return 'A otimizar $name...';
  }

  @override
  String get indexerDoNotClose => 'Não feches a aplicação';

  @override
  String get indexerRestartRequiredMessage =>
      'A operação foi concluída com sucesso.\n\nA aplicação precisa de ser reiniciada para aplicar todas as alterações corretamente.';

  @override
  String indexerFailedItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens com falha',
      one: '1 item com falha',
    );
    return '$_temp0';
  }

  @override
  String get indexerCouldNotProcess =>
      'Os itens a seguir não puderam ser processados:';

  @override
  String indexerWarningsTitle(String name) {
    return 'Avisos de $name';
  }

  @override
  String get indexerOk => 'OK';

  @override
  String get indexerJustMissing => 'Apenas ausentes';

  @override
  String get indexerForceAll => 'Forçar todos';

  @override
  String get beatSyncTitle => 'Sincronização de batida';

  @override
  String get beatPlayToCalibrate => 'Toca uma música para calibrar.';

  @override
  String get beatAnalyzing => 'A analisar batidas...';

  @override
  String get beatNoClearBeat => 'Não há batida clara nesta faixa.';

  @override
  String get beatDragInstruction =>
      'Arrasta até as explosões de partículas caírem sobre os cliques.';

  @override
  String beatOffsetMs(int value) {
    return '$value ms';
  }

  @override
  String get beatResetToZero => 'Redefinir para 0 ms';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get libraryFoldersTab => 'Pastas';

  @override
  String get libraryNoMusicFolderTitle => 'Nenhuma pasta de música ainda';

  @override
  String get libraryNoMusicFolderMessage =>
      'Seleciona uma pasta de música em Início para preencher isto.';

  @override
  String get libraryFolderErrorTitle =>
      'Não foi possível encontrar a tua pasta de música';

  @override
  String get libraryLoadErrorTitle => 'Não foi possível carregar a biblioteca';

  @override
  String get libraryOpenFolderErrorTitle => 'Não foi possível abrir a pasta';

  @override
  String get libraryNoMatchesTitle => 'Nenhum resultado';

  @override
  String libraryNoMatchesMessage(String query) {
    return 'Nada na tua biblioteca corresponde a \"$query\".';
  }

  @override
  String libraryFolderNoMatchesMessage(String query) {
    return 'Nada nesta pasta corresponde a \"$query\".';
  }

  @override
  String libraryCollectionNoMatchesMessage(String query) {
    return 'Nada aqui corresponde a \"$query\".';
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
  String get libraryCreateMergeGroupTooltip => 'Criar novo grupo de união';

  @override
  String get libraryDeletePlaylist => 'Eliminar lista de reprodução';

  @override
  String get libraryPlaylistOptions => 'Opções da lista de reprodução';

  @override
  String get libraryFolderOptions => 'Opções da pasta';

  @override
  String get libraryFilterAllHint =>
      'Filtrar pastas, listas de reprodução, músicas...';

  @override
  String get libraryFilterSongsHint => 'Filtrar pastas, músicas...';

  @override
  String get libraryFilterCollectionsHint => 'Filtrar artistas, álbuns...';

  @override
  String libraryTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get libraryAll => 'Tudo';

  @override
  String get libraryShuffleFolderTooltip =>
      'Reproduzir pasta em ordem aleatória';

  @override
  String get libraryNoArtistsTitle => 'Nenhum artista ainda';

  @override
  String get libraryNoAlbumsTitle => 'Nenhum álbum ainda';

  @override
  String get libraryScanToFillMessage =>
      'Analisa uma pasta de música para preencher isto.';

  @override
  String get actionClear => 'Limpar';

  @override
  String get actionSearch => 'Pesquisar';

  @override
  String get actionShuffleAll => 'Reproduzir tudo em ordem aleatória';

  @override
  String get actionSeeAll => 'Ver tudo';

  @override
  String homeQueueCardSubtitle(String date, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$date · $_temp0';
  }

  @override
  String homePlayingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return 'A tocar $_temp0';
  }

  @override
  String get homeOpenPlayer => 'Abrir player';

  @override
  String get homePlayNow => 'Tocar agora';

  @override
  String homePlayAfterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas vão tocar depois da música atual',
      one: '1 faixa vai tocar depois da música atual',
    );
    return '$_temp0';
  }

  @override
  String get homePlayAfterCurrent => 'Tocar depois da música atual';

  @override
  String get homeSaveToNewPlaylist => 'Guardar em nova lista de reprodução';

  @override
  String get homeUnpin => 'Desafixar';

  @override
  String get homePinRecommendation => 'Fixar recomendação';

  @override
  String get homeRenameRecommendation => 'Renomear recomendação';

  @override
  String get homeRenameRecommendationTitle => 'Renomear recomendação';

  @override
  String get homeRemoveRecommendation => 'Remover recomendação';

  @override
  String get homeRemoveRecommendationTitle => 'Remover recomendação?';

  @override
  String homeRemoveRecommendationMessage(String title) {
    return 'Tens a certeza de que queres remover \"$title\"?';
  }

  @override
  String get homeErrorTitle => 'Algo correu mal';

  @override
  String get homeTryAgain => 'Tentar novamente';

  @override
  String get homeNoSongsTitle => 'Nenhuma música encontrada';

  @override
  String get homeNoSongsMessage =>
      'Seleciona a tua pasta de música para começar a ouvir offline.';

  @override
  String get homeSelectFolder => 'Selecionar pasta de música';

  @override
  String get homeQuickPicks => 'Escolhas rápidas';

  @override
  String get homeRecentQueues => 'Filas recentes';

  @override
  String get homeForYou => 'Para ti';

  @override
  String get mergedTitle => 'Músicas unidas';

  @override
  String get mergedCreateGroupTooltip => 'Criar grupo de união';

  @override
  String mergedGroupsTab(int count) {
    return 'Grupos ($count)';
  }

  @override
  String mergedAutoFindTab(int count) {
    return 'Pesquisa automática ($count)';
  }

  @override
  String mergedCreatedSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas unidas',
      one: '1 música unida',
    );
    return '$_temp0';
  }

  @override
  String get mergedEmptyTitle => 'Nenhuma música unida ainda';

  @override
  String get mergedEmptyBody =>
      'Agrupe versões diferentes da mesma música (remixes, versões ao vivo, acústicas) para que dividam um só lugar no aleatório.';

  @override
  String get mergedCreateGroupButton => 'Criar grupo de união';

  @override
  String mergedPrioritySet(String title) {
    return '\"$title\" definida como música prioritária';
  }

  @override
  String get mergedPriorityCleared => 'Prioridade removida';

  @override
  String get mergedNoCandidatesTitle => 'Nenhuma música candidata encontrada';

  @override
  String get mergedNoCandidatesBody =>
      'Nenhuma variante de música não unida (remixes, versões ao vivo, acústicas) foi detetada na tua biblioteca.';

  @override
  String mergedFoundGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encontrados $count grupos potenciais para unir',
      one: 'Encontrado 1 grupo potencial para unir',
    );
    return '$_temp0';
  }

  @override
  String get mergedMergeAll => 'Unir tudo';

  @override
  String get mergedMergeAllTitle => 'Unir todas as sugestões';

  @override
  String mergedMergeAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Criar $count grupos de união para as variantes de música detetadas?',
      one: 'Criar 1 grupo de união para as variantes de música detetadas?',
    );
    return '$_temp0';
  }

  @override
  String mergedCreatedGroupsSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grupos de união criados',
      one: '1 grupo de união criado',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeTitle => 'Desunir música';

  @override
  String mergedUnmergeConfirm(String title) {
    return 'Remover \"$title\" deste grupo de união?';
  }

  @override
  String get mergedUnmergeAction => 'Desunir';

  @override
  String mergedUnmergedSnack(String title) {
    return '\"$title\" desunida';
  }

  @override
  String get mergedDeleteGroupTitle => 'Eliminar grupo de união';

  @override
  String get mergedDeleteGroupConfirm =>
      'Desunir todas as músicas deste grupo?';

  @override
  String get mergedUnmergeAllAction => 'Desunir tudo';

  @override
  String get mergedGroupDeleted => 'Grupo de união eliminado';

  @override
  String get mergedGroupLabel => 'Grupo de união';

  @override
  String mergedVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versões',
      one: '1 versão',
    );
    return '$_temp0';
  }

  @override
  String get mergedUnmergeAllTooltip => 'Desunir tudo';

  @override
  String get mergedPriorityBadge => 'Prioridade';

  @override
  String get mergedPrioritySongTooltip => 'Música prioritária no aleatório';

  @override
  String get mergedSetPriorityTooltip => 'Definir como música prioritária';

  @override
  String get mergedUnmergeSongTooltip => 'Desunir música';

  @override
  String mergedSelectedCount(int selected, int total) {
    return '$selected/$total selecionadas';
  }

  @override
  String get mergedMergeAction => 'Unir';

  @override
  String get sleepTimerTitle => 'Temporizador de sono';

  @override
  String get sleepTimerModeLabel => 'Modo do temporizador';

  @override
  String get sleepTimerDurationLabel => 'Duração';

  @override
  String get sleepTimerMinSuffix => 'min';

  @override
  String get sleepTimerTracksLabel => 'Número de faixas';

  @override
  String get sleepTimerLoopTitle => 'Repetir a música atual';

  @override
  String get sleepTimerLoopSubtitle =>
      'Repetir a música atual por um tempo definido';

  @override
  String get sleepTimerPlayForTimeTitle => 'Tocar por um tempo';

  @override
  String get sleepTimerPlayForTimeSubtitle => 'Parar após uma duração definida';

  @override
  String get sleepTimerStopAfterCurrentTitle => 'Parar após a atual';

  @override
  String get sleepTimerStopAfterCurrentSubtitle =>
      'Parar quando a música atual terminar';

  @override
  String get sleepTimerStopAfterTracksTitle => 'Parar após faixas';

  @override
  String get sleepTimerStopAfterTracksSubtitle =>
      'Parar após tocar mais X músicas';

  @override
  String get sleepTimerNoSong => 'Nenhuma música está a tocar no momento';

  @override
  String get sleepTimerCurrentSongLabel => 'Música atual';

  @override
  String get sleepTimerLetFinishTitle => 'Deixar a música atual terminar';

  @override
  String get sleepTimerLetFinishSubtitle =>
      'Esperar a música atual terminar antes de parar';

  @override
  String get sleepTimerStopImmediatelySubtitle =>
      'Parar imediatamente quando o temporizador terminar';

  @override
  String get sleepTimerStart => 'Iniciar temporizador';

  @override
  String get sleepTimerCancelActive => 'Cancelar temporizador ativo';

  @override
  String get sleepTimerCancelled => 'Temporizador de sono cancelado';

  @override
  String get sleepTimerFinished => 'Temporizador de sono concluído';

  @override
  String sleepTimerLoopingFor(int minutes) {
    return 'A repetir a música atual durante $minutes minutos';
  }

  @override
  String sleepTimerStopIn(int minutes) {
    return 'A música vai parar em $minutes minutos';
  }

  @override
  String get sleepTimerStopAfterCurrent =>
      'Vai parar quando a música atual terminar';

  @override
  String sleepTimerStopAfterTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vai parar após mais $count músicas',
      one: 'Vai parar após mais 1 música',
    );
    return '$_temp0';
  }

  @override
  String get settingsSearchHint => 'Pesquisar definições';

  @override
  String get settingsValueNone => 'Nenhum';

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
  String get settingsGroupLookAndFeel => 'Aparência e estilo';

  @override
  String get settingsGroupData => 'Dados';

  @override
  String get settingsGroupApp => 'App';

  @override
  String get settingsGroupFilters => 'Filtros';

  @override
  String get settingsGroupMaintenance => 'Manutenção';

  @override
  String get settingsScanningLibrary => 'A analisar a biblioteca…';

  @override
  String settingsResultsFor(String query) {
    return 'Resultados para \"$query\"';
  }

  @override
  String get settingsNoResultsTitle => 'Nenhuma definição encontrada';

  @override
  String settingsNoResultsMessage(String query) {
    return 'Nada corresponde a \"$query\".';
  }

  @override
  String get homeSettingsGroupLists => 'Listas e navegação';

  @override
  String get homeSettingsAutoHideBarsSubtitle =>
      'O cabeçalho e a barra inferior ocultam-se ao deslocar para baixo e reaparecem ao deslocar para cima';

  @override
  String get homeSettingsGroupHome => 'Ecrã inicial';

  @override
  String get playbackGroupTransitions => 'Transições';

  @override
  String get playbackGroupPlayPause => 'Reproduzir / Pausar';

  @override
  String get playbackGroupAudio => 'Áudio';

  @override
  String get playbackGapOff => 'Intervalo / Atraso (desativado)';

  @override
  String get playbackFadeOutOff => 'Fade de saída (desativado)';

  @override
  String get playbackFadeInOff => 'Fade de entrada (desativado)';

  @override
  String playbackSecondsValue(String seconds) {
    return '${seconds}s';
  }

  @override
  String get playbackValueOneSecond => '1,0 s';

  @override
  String playbackValueMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get bulkRenameTokenCurrentName => 'Nome atual';

  @override
  String get bulkRenameTokenNumber => 'Número';

  @override
  String get bulkRenameTokenYear => 'Ano';

  @override
  String bulkRenameAnalyzeError(String error) {
    return 'Não foi possível analisar a biblioteca: $error';
  }

  @override
  String bulkRenameRenameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Renomear $count músicas',
      one: 'Renomear 1 música',
    );
    return '$_temp0';
  }

  @override
  String get bulkRenameConfirmMessage =>
      'Os ficheiros são renomeados no local. As estatísticas de reprodução, as listas de reprodução e as capas em cache vão junto com eles, e a base de dados é mantida em sincronia conforme cada ficheiro é movido.';

  @override
  String get bulkRenameNothingLeft => 'Não há mais nada para renomear';

  @override
  String get bulkRenamePhaseStarting => 'A iniciar';

  @override
  String get bulkRenameTitle => 'Renomeação em massa';

  @override
  String get bulkRenameFormatArtistTitle => 'Artista - Título';

  @override
  String get bulkRenameFormatArtistAlbumTitle => 'Artista - Álbum - Título';

  @override
  String get bulkRenameCustomSubtitle => 'A tua própria organização';

  @override
  String get bulkRenameSectionFormat => 'FORMATO';

  @override
  String get bulkRenameSectionArrange => 'ORGANIZAR';

  @override
  String get bulkRenameSectionPreview => 'PRÉVIA';

  @override
  String get bulkRenameEmptySegments =>
      'Adicione um campo abaixo para começar a montar um nome.';

  @override
  String get bulkRenameLiteralHint => 'Texto, ex.: \" - \"';

  @override
  String get bulkRenameTextChip => 'Texto';

  @override
  String get bulkRenameAnalyzing => 'A analisar a biblioteca';

  @override
  String bulkRenameCountToRename(int count) {
    return '$count para renomear';
  }

  @override
  String bulkRenameSkippedCount(int count) {
    return '$count ignoradas';
  }

  @override
  String bulkRenameAndMore(int count) {
    return 'e mais $count';
  }

  @override
  String bulkRenameChecking(int done, int total) {
    return 'A verificar nomes — $done de $total';
  }

  @override
  String get bulkRenameStop => 'Parar';

  @override
  String get bulkRenameStopping => 'A parar...';

  @override
  String get bulkRenamePleaseWait => 'Aguarde';

  @override
  String bulkRenameProgressCount(int done, int total) {
    return '$done de $total';
  }

  @override
  String bulkRenameStopped(int count) {
    return 'Parou após $count músicas. As estatísticas e as capas em cache foram movidas; as demais foram deixadas como estavam.';
  }

  @override
  String bulkRenameStoppedFailed(int count, int failed) {
    return 'Parou após $count músicas, $failed não puderam ser renomeadas.';
  }

  @override
  String bulkRenameCompleted(int count) {
    return '$count músicas renomeadas. Estatísticas e capas em cache foram movidas.';
  }

  @override
  String bulkRenameCompletedFailed(int count, int failed) {
    return '$count músicas renomeadas, $failed não puderam ser renomeadas.';
  }

  @override
  String get bulkRenameFinishedTitle => 'Renomeação concluída';

  @override
  String get bulkRenameSkipNoTitleText =>
      'Nenhum texto de título restou após a limpeza';

  @override
  String get bulkRenameSkipAlreadyNamed => 'Já estava nomeada assim';

  @override
  String bulkRenameSkipSameNameAs(String filename) {
    return 'Mesmo nome de \"$filename\" nesta pasta';
  }

  @override
  String get bulkRenameSkipAnotherSelected =>
      'Outra música selecionada tem esse nome';

  @override
  String get bulkRenameSkipFileExists =>
      'Já existe um ficheiro com esse nome aqui';

  @override
  String get shuffleResetDone => 'Definições restauradas para a predefinição';

  @override
  String get shuffleSaved => 'Definições guardadas';

  @override
  String get shuffleUnsavedTitle => 'Alterações não guardadas';

  @override
  String get shuffleUnsavedMessage => 'Desejas guardar as tuas alterações?';

  @override
  String get shuffleDiscard => 'Descartar';

  @override
  String get shuffleTitle => 'Definições de aleatório personalizado';

  @override
  String get shuffleReset => 'Redefinir';

  @override
  String get shuffleNextQueueNote =>
      'As alterações serão aplicadas à próxima fila';

  @override
  String get shuffleBasicSettings => 'Definições básicas';

  @override
  String get shuffleAvoidSongsTitle => 'Evitar repetir músicas';

  @override
  String get shuffleAvoidSongsSubtitle =>
      'Reduz a chance de tocar músicas reproduzidas recentemente';

  @override
  String get shuffleAvoidArtistsTitle => 'Evitar repetir artistas';

  @override
  String get shuffleAvoidArtistsSubtitle =>
      'Reduz a chance de tocar o mesmo artista em sequência';

  @override
  String get shuffleAvoidAlbumsTitle => 'Evitar repetir álbuns';

  @override
  String get shuffleAvoidAlbumsSubtitle =>
      'Reduz a chance de tocar o mesmo álbum em sequência';

  @override
  String get shuffleAdvancedTitle => 'Definições avançadas';

  @override
  String get shuffleAdvancedSubtitle =>
      'Ajuste fino dos valores de peso individuais';

  @override
  String get shuffleWeightValuesTitle => 'Valores de peso (-99 a +99)';

  @override
  String get shuffleWeightValuesHint =>
      '0 = neutro, negativo = penalidade, positivo = impulso';

  @override
  String get shuffleWeightLeastPlayed => 'Músicas menos tocadas';

  @override
  String get shuffleWeightMostPlayed => 'Músicas mais tocadas';

  @override
  String get shuffleWeightSuggestLess =>
      'Músicas sugeridas com menos frequência';

  @override
  String get shuffleWeightPlaylistSongs => 'Músicas em listas de reprodução';

  @override
  String get lyricsGroupDisplayTiming => 'Exibição e sincronização';

  @override
  String get lyricsSimulateWordSyncTitle => 'Simular sincronização por palavra';

  @override
  String get lyricsSimulateWordSyncSubtitle =>
      'Gera a sincronização ao nível da palavra a partir de letras sincronizadas por linha usando estimativa prosódica';

  @override
  String get lyricsDesktopSidebarTitle => 'Barra lateral de letras e fila';

  @override
  String get lyricsDesktopSidebarSubtitle =>
      'Mostra a alça de expansão ao passar o rato para reabrir a barra lateral de letras e fila depois de ocultada';

  @override
  String get lyricsKeepScreenAwakeTitle => 'Manter o ecrã ligado nas letras';

  @override
  String get lyricsKeepScreenAwakeSubtitle =>
      'Impede a suspensão enquanto o painel de letras estiver aberto';

  @override
  String get lyricsGroupTranslation => 'Tradução';

  @override
  String get lyricsAutoTranslateTitle => 'Traduzir letras automaticamente';

  @override
  String get lyricsAutoTranslateSubtitle =>
      'Traduz as letras automaticamente usando o idioma de destino selecionado';

  @override
  String get lyricsTargetLanguageTitle => 'Idioma de destino';

  @override
  String get lyricsTranslationDisplayTitle => 'Exibição da tradução';

  @override
  String get lyricsTranslationModeReplaceSubtitle =>
      'Substituir as letras originais';

  @override
  String get lyricsTranslationModeSubtextSubtitle =>
      'Mostrar subtexto abaixo das letras';

  @override
  String get lyricsModeSubtext => 'Subtexto abaixo';

  @override
  String get lyricsModeReplace => 'Substituir base';

  @override
  String get lyricsTranslateTitle => 'Traduzir letras';

  @override
  String get lyricsDisplayMode => 'Modo de exibição';

  @override
  String get lyricsModeSubtextDescription => 'Mostrar a tradução sob as letras';

  @override
  String get lyricsModeReplaceDescription =>
      'Substituir as letras originais por completo';

  @override
  String get lyricsAutoTranslateAllTitle =>
      'Traduzir automaticamente todas as músicas';

  @override
  String get lyricsAutoTranslateAllSubtitle =>
      'Traduz as letras automaticamente usando o idioma selecionado';

  @override
  String get lyricsTargetLanguageLabel => 'Idioma de destino';

  @override
  String get lyricsSearchLanguageHint => 'Pesquisar idioma...';

  @override
  String get lyricsClearCache => 'Limpar cache';

  @override
  String get lyricsTranslateNow => 'Traduzir agora';

  @override
  String get lyricsFindTitle => 'Pesquisar letras';

  @override
  String get lyricsNoResults =>
      'Nenhuma letra encontrada. Tenta outro título ou artista, ou verifica a tua ligação.';

  @override
  String get lyricsInstrumentalWarning =>
      'Marcada como instrumental. Aplicar isso apaga qualquer letra armazenada no ficheiro.';

  @override
  String get lyricsApplyUpper => 'APLICAR';

  @override
  String get lyricsPlainText => 'Texto simples';

  @override
  String get lyricsUnknownLength => 'Duração desconhecida';

  @override
  String lyricsDurationExactMatch(String duration) {
    return '$duration · correspondência exata';
  }

  @override
  String get lyricsBadgeWordSync => 'SINC. POR PALAVRA';

  @override
  String get lyricsBadgeLineSync => 'SINC. POR LINHA';

  @override
  String get lyricsBadgeInstrumental => 'INSTRUMENTAL';

  @override
  String get lyricsBadgePlain => 'SIMPLES';

  @override
  String get lyricsSaved => 'Letras guardadas';

  @override
  String lyricsSaveError(Object error) {
    return 'Não foi possível guardar as letras: $error';
  }

  @override
  String get lyricsTranslationCleared => 'Tradução em cache removida';

  @override
  String get lyricsAlreadyTranslated =>
      'As letras já estão no idioma de destino';

  @override
  String get lyricsTranslated => 'Letras traduzidas';

  @override
  String get lyricsTranslateError => 'Não foi possível traduzir as letras';

  @override
  String lyricsTranslationFailed(Object error) {
    return 'Falha na tradução: $error';
  }

  @override
  String get lyricsHideTimingTooltip => 'Ocultar a sincronização da letra';

  @override
  String get lyricsAdjustTimingTooltip =>
      'Ajustar a sincronização da letra — mantenha premido para os controlos de precisão';

  @override
  String get lyricsFindOnline => 'Pesquisar letras online';

  @override
  String get lyricsEmptyTitle => 'Sem letras';

  @override
  String get lyricsEmptySubtitle => 'Esta faixa não tem letras incorporadas.';

  @override
  String get languageSpanish => 'Espanhol';

  @override
  String get languageEnglish => 'Inglês';

  @override
  String get languageFrench => 'Francês';

  @override
  String get languageGerman => 'Alemão';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageJapanese => 'Japonês';

  @override
  String get languageChinese => 'Chinês';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get languageDutch => 'Holandês';

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
  String get languageIndonesian => 'Indonésio';

  @override
  String get languageThai => 'Tailandês';

  @override
  String get languageCzech => 'Checo';

  @override
  String get languageGreek => 'Grego';

  @override
  String get languageHungarian => 'Húngaro';

  @override
  String get languageRomanian => 'Romeno';

  @override
  String get languageDanish => 'Dinamarquês';

  @override
  String get languageFinnish => 'Finlandês';

  @override
  String get languageNorwegian => 'Norueguês';

  @override
  String get selectSongsTitle => 'Selecionar músicas';

  @override
  String get selectSongsWhatIsMerging => 'O que é unir?';

  @override
  String get selectSongsMergedExplanation =>
      'Músicas unidas são versões diferentes da mesma música:';

  @override
  String get selectSongsBulletVersions =>
      'Como remixes, versões ao vivo ou versões com qualidade diferente';

  @override
  String get selectSongsBulletFavorites =>
      'Favoritos e \"sugerir menos\" são independentes por música';

  @override
  String get selectSongsBulletStats =>
      'As tuas contagens de reprodução e estatísticas permanecem inalteradas';

  @override
  String get selectSongsBulletPriority =>
      'Selecione uma música prioritária (⭐) para a priorizar no modo aleatório';

  @override
  String get selectSongsSearchHint => 'Pesquisar músicas...';

  @override
  String selectSongsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionadas',
      one: '1 selecionada',
    );
    return '$_temp0';
  }

  @override
  String get selectSongsReadyToMerge => 'Pronto para unir';

  @override
  String get selectSongsPrioritySongTooltip => 'Música prioritária';

  @override
  String get selectSongsSetPriorityTooltip => 'Definir como prioritária';

  @override
  String get selectSongsPriorityBadge => 'PRIORITÁRIA';

  @override
  String selectSongsMinSelection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selecione pelo menos $count músicas',
      one: 'Selecione pelo menos 1 música',
    );
    return '$_temp0';
  }

  @override
  String selectSongsMergeAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unir $count músicas',
      one: 'Unir 1 música',
    );
    return '$_temp0';
  }

  @override
  String selectSongsSelectAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selecionar $count músicas',
      one: 'Selecionar 1 música',
    );
    return '$_temp0';
  }

  @override
  String get foldersAddedSnack => 'Pasta de músicas adicionada';

  @override
  String get foldersRemovedSnack => 'Pasta de músicas removida';

  @override
  String get foldersSubtitle =>
      'Seleciona as pastas que contêm os teus ficheiros de música';

  @override
  String get foldersEmptyTitle => 'Nenhuma pasta adicionada ainda';

  @override
  String get foldersEmptyMessage =>
      'Adiciona uma pasta para montar a tua biblioteca.';

  @override
  String get foldersAddButton => 'Adicionar pasta';

  @override
  String get foldersShortcutInternalStorage => 'Armazenamento interno';

  @override
  String get foldersShortcutMusic => 'Música';

  @override
  String get foldersShortcutDownload => 'Download';

  @override
  String get foldersShortcutStorageRoot => 'Raiz do armazenamento';

  @override
  String get foldersShortcutDownloads => 'Downloads';

  @override
  String get foldersShortcutDocuments => 'Documentos';

  @override
  String get foldersDoesNotExist => 'A pasta não existe';

  @override
  String get foldersPermissionError =>
      'Permissão negada ou erro ao ler a pasta';

  @override
  String get foldersNewFolderTitle => 'Nova pasta';

  @override
  String get foldersFolderNameLabel => 'Nome da pasta';

  @override
  String get foldersFolderNameHint => 'Introduza o nome da pasta';

  @override
  String foldersCreateError(String error) {
    return 'Erro ao criar a pasta: $error';
  }

  @override
  String get foldersGoUp => '.. (Subir)';

  @override
  String get foldersGoBack => '.. (Voltar)';

  @override
  String get foldersNoSubfolders =>
      'Nenhuma subpasta encontrada.\nSeleciona esta pasta se contém as tuas músicas.';

  @override
  String get foldersSelectThisFolder => 'Selecionar esta pasta';

  @override
  String get foldersSelectDestination => 'Selecionar pasta de destino';

  @override
  String get foldersEmptyFolder => 'Pasta vazia. Podes selecioná-la abaixo.';

  @override
  String foldersSelected(String name) {
    return 'Selecionada: $name';
  }

  @override
  String get foldersRoot => 'Raiz';

  @override
  String get foldersMoveFolder => 'Mover pasta';

  @override
  String foldersMovedTo(String name, String path) {
    return '$name movida para $path';
  }

  @override
  String foldersMoveError(String error) {
    return 'Erro ao mover a pasta: $error';
  }

  @override
  String get playlistsTitle => 'Listas de reprodução';

  @override
  String get playlistsSearchHint => 'Pesquisar listas de reprodução...';

  @override
  String get playlistsCreate => 'Criar lista de reprodução';

  @override
  String get playlistsNoMatches =>
      'Nenhuma lista de reprodução correspondente encontrada';

  @override
  String playlistsCreatedOn(String date) {
    return 'Criada em $date';
  }

  @override
  String get playlistsCreatedToday => 'hoje';

  @override
  String get playlistsCreatedYesterday => 'ontem';

  @override
  String playlistsDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String playlistsWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count semanas',
      one: 'há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String get playlistsEmptyTitle => 'Ainda não há listas de reprodução';

  @override
  String get playlistsEmptyMessage =>
      'Cria a tua primeira lista de reprodução para começar';

  @override
  String get playlistsNameHint => 'Introduza o nome da lista de reprodução';

  @override
  String get statsTitle => 'Audição';

  @override
  String get statsLoadErrorTitle =>
      'Não foi possível carregar as tuas estatísticas';

  @override
  String get statsReadingHistory => 'A ler o teu histórico de audição';

  @override
  String get statsEmptyTitle => 'Ainda não há histórico de audição';

  @override
  String get statsEmptyMessage =>
      'Toca em algo e os teus hábitos de audição aparecerão aqui.';

  @override
  String get statsSectionOverTime => 'Ao longo do tempo';

  @override
  String get statsSectionWhen => 'Quando ouves';

  @override
  String get statsSectionTop => 'Os teus mais ouvidos';

  @override
  String get statsSectionTaste => 'Gosto';

  @override
  String get statsByHour => 'POR HORA';

  @override
  String get statsByWeekday => 'POR DIA DA SEMANA';

  @override
  String get statsNoListening => 'Nenhuma audição registada';

  @override
  String statsAcrossPlays(String time, String plays) {
    return '$time em $plays';
  }

  @override
  String get statsLibraryExplored => 'Biblioteca explorada';

  @override
  String get statsPlaysFavourites => 'Reproduções de favoritos';

  @override
  String get statsPlaysSkipped => 'Reproduções saltadas';

  @override
  String get statsAvgPlay => 'REPRODUÇÃO MÉDIA';

  @override
  String get statsOnActiveDay => 'NUM DIA ATIVO';

  @override
  String get statsPlaysPerActiveDay => 'REPRODUÇÕES POR DIA ATIVO';

  @override
  String get statsFirstListen => 'PRIMEIRA AUDIÇÃO';

  @override
  String statsShareOf(String share, String count) {
    return '$share de $count';
  }

  @override
  String get statsTopArtists => 'ARTISTAS MAIS OUVINTES';

  @override
  String get statsTopAlbums => 'ÁLBUNS MAIS OUVIDOS';

  @override
  String get statsTopTracks => 'FAIXAS MAIS OUVIDAS';

  @override
  String get statsTimeListened => 'TEMPO A OUVIR';

  @override
  String statsRangeWithDays(String range, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias com música',
      one: '1 dia com música',
    );
    return '$range · $_temp0';
  }

  @override
  String get statsPlays => 'REPRODUÇÕES';

  @override
  String get statsSkips => 'SALTADAS';

  @override
  String get statsTracks => 'FAIXAS';

  @override
  String get statsStreak => 'SEQUÊNCIA';

  @override
  String statsStreakBest(int count) {
    return 'melhor $count';
  }

  @override
  String statsPlaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
    );
    return '$_temp0';
  }

  @override
  String statsActiveDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias ativos',
      one: '1 dia ativo',
    );
    return '$_temp0';
  }

  @override
  String statsSummary(String duration, String plays, String days) {
    return '$duration · $plays · $days';
  }

  @override
  String get statsEmptyHint => 'Toca em algo para começares o teu histórico';

  @override
  String get statsLoadError => 'Não foi possível carregar as tuas estatísticas';

  @override
  String statsDurationMinutes(int minutes) {
    return '${minutes}min';
  }

  @override
  String statsDurationHours(int hours) {
    return '${hours}h';
  }

  @override
  String statsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}min';
  }

  @override
  String get statsSameAsBefore => 'igual a antes';

  @override
  String statsHourTickAm(int hour) {
    return '${hour}a';
  }

  @override
  String statsHourTickPm(int hour) {
    return '${hour}p';
  }

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get actionRefresh => 'Atualizar';

  @override
  String get sessionDetailTitle => 'Detalhes da sessão';

  @override
  String sessionStartedAt(String time) {
    return 'Iniciada às $time';
  }

  @override
  String get sessionSongSingular => 'Música';

  @override
  String get sessionSongsPlayed => 'Músicas tocadas';

  @override
  String get sessionNoSongs => 'Nenhuma música registada';

  @override
  String get sessionRepeatNow => 'Repetir fila agora';

  @override
  String get sessionNoSongsAvailable => 'Nenhuma música disponível para tocar';

  @override
  String sessionAfterCurrentSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas tocarão depois da música atual',
      one: '1 música tocará depois da música atual',
    );
    return '$_temp0';
  }

  @override
  String sessionPlayingSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A tocar $count músicas desta sessão',
      one: 'A tocar 1 música desta sessão',
    );
    return '$_temp0';
  }

  @override
  String get sessionHistoryTitle => 'Histórico de sessões';

  @override
  String get sessionLoadFailed => 'Falha ao carregar as sessões';

  @override
  String get sessionEmptyTitle => 'Ainda não há sessões';

  @override
  String get sessionEmptyMessage =>
      'Começa a escutar para montares o teu histórico de sessões';

  @override
  String get playHistoryTitle => 'Histórico da música';

  @override
  String get playHistoryEmptyTitle => 'Ainda não há histórico de reprodução';

  @override
  String get playHistoryEmptyMessage =>
      'Começa a escutar para montares o teu histórico.';

  @override
  String get playHistoryListen => 'Ouvir';

  @override
  String get playHistorySkip => 'Saltar';

  @override
  String playHistorySummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reproduções',
      one: '1 reprodução',
    );
    return '$_temp0 · $duration';
  }

  @override
  String playHistoryDate(String month, int day, int year) {
    return '$day de $month de $year';
  }

  @override
  String get monthShortJan => 'jan';

  @override
  String get monthShortFeb => 'fev';

  @override
  String get monthShortMar => 'mar';

  @override
  String get monthShortApr => 'abr';

  @override
  String get monthShortMay => 'mai';

  @override
  String get monthShortJun => 'jun';

  @override
  String get monthShortJul => 'jul';

  @override
  String get monthShortAug => 'ago';

  @override
  String get monthShortSep => 'set';

  @override
  String get monthShortOct => 'out';

  @override
  String get monthShortNov => 'nov';

  @override
  String get monthShortDec => 'dez';

  @override
  String get searchFieldHint => 'Pesquisar músicas, artistas, álbuns...';

  @override
  String get searchEmptyTitle => 'Pesquisa na tua coleção de músicas';

  @override
  String get searchEmptyMessage =>
      'Encontre músicas, artistas, álbuns e letras.';

  @override
  String get searchFailed => 'Não foi possível pesquisar';

  @override
  String searchNoResults(String query) {
    return 'Nenhum resultado encontrado para \"$query\"';
  }

  @override
  String get searchNoResultsHint =>
      'Tenta outras palavras-chave ou verifica os teus filtros.';

  @override
  String searchArtistsSection(int count) {
    return 'Artistas ($count)';
  }

  @override
  String searchAlbumsSection(int count) {
    return 'Álbuns ($count)';
  }

  @override
  String searchSongsSection(int count) {
    return 'Músicas ($count)';
  }

  @override
  String searchAlbumSubtitle(String artist, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$artist · $_temp0';
  }

  @override
  String get quickActionSuggestMore => 'Sugerir com mais frequência';

  @override
  String get quickActionSuggestLess => 'Sugerir com menos frequência';

  @override
  String get quickActionGoToAlbum => 'Ir para o álbum';

  @override
  String get quickActionGoToArtist => 'Ir para o artista';

  @override
  String get aboutChecking => 'A verificar atualizações…';

  @override
  String aboutUpdateAvailable(String version) {
    return 'Atualização disponível: $version';
  }

  @override
  String get aboutUpToDate => 'Estás atualizado';

  @override
  String get aboutCheckForUpdates => 'Verificar atualizações';

  @override
  String get aboutCheckingSubtitle =>
      'O wispie está a verificar o GitHub Releases.';

  @override
  String get aboutUpdateAvailableSubtitle =>
      'Uma versão mais recente está disponível no GitHub.';

  @override
  String aboutLatestRelease(String version) {
    return 'Versão mais recente: $version';
  }

  @override
  String get aboutTapToCheck => 'Toque abaixo para verificar manualmente.';

  @override
  String aboutVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get aboutUnknown => 'Desconhecido';

  @override
  String get aboutCheckNow => 'Verificar agora';

  @override
  String get aboutViewRelease => 'Ver versão';

  @override
  String get aboutDebugGroup => 'Depuração';

  @override
  String get aboutPersistWrites => 'Persistir gravações';

  @override
  String get aboutPersistWritesSubtitle =>
      'Compilações de depuração mantêm as alterações numa cópia descartável por predefinição. Aplica-se na próxima inicialização.';

  @override
  String get appIconMoreSoon => 'Mais ícones em breve';

  @override
  String get appIconDesktopNote =>
      'Iniciadores e gestores de ficheiros do desktop mantêm o ícone predefinido; o ícone da janela e do Dock segue a tua escolha.';

  @override
  String get storageSettingsDiskGroup => 'Disco';

  @override
  String get storageSettingsIndexesGroup => 'Índices e caches';

  @override
  String get shellNavHome => 'Início';

  @override
  String get shellSearchTooltip => 'Pesquisar (Ctrl+K)';

  @override
  String get shellShowSidebar => 'Mostrar barra lateral';

  @override
  String get shellHideSidebar => 'Ocultar barra lateral';

  @override
  String get shellNothingUpNext => 'Nada a seguir';

  @override
  String get shellNextInQueue => 'Próxima na fila';

  @override
  String get shellPlayNext => 'Tocar em seguida';

  @override
  String get playerNothingPlaying => 'Nada a tocar';

  @override
  String get playerPanePlayer => 'Reprodutor';

  @override
  String get playerPaneQueue => 'Fila';

  @override
  String get playerCloseEsc => 'Fechar (Esc)';

  @override
  String get playerSongOptions => 'Opções da música';

  @override
  String get playerShowArtwork => 'Mostrar capa';

  @override
  String get playerShowVideo => 'Mostrar vídeo';

  @override
  String get drawerQueueHistory => 'Histórico de filas';

  @override
  String get drawerTools => 'Ferramentas';

  @override
  String get nowPlayingBarShuffleTooltip =>
      'Aleatório (mantenha premido para um novo aleatório)';

  @override
  String get shuffleButtonAfterSong => 'Aleatório depois da música atual';

  @override
  String get shuffleButtonAfterQueue => 'Aleatório depois da fila atual';

  @override
  String shuffleButtonScanningTooltip(String percentage) {
    return 'A analisar a biblioteca ($percentage%)';
  }

  @override
  String shuffleButtonScanningSemantics(String percentage) {
    return 'A analisar a biblioteca, $percentage por cento concluído';
  }

  @override
  String shuffleButtonScanningMessage(String percentage) {
    return 'A analisar a biblioteca: $percentage%';
  }

  @override
  String heartMenuRemoveFromPlaylist(String name) {
    return 'Remover de $name';
  }

  @override
  String heartMenuRemovedFromPlaylist(String name) {
    return 'Removida de $name';
  }

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortTitleAZ => 'Título (A-Z)';

  @override
  String get sortDateAdded => 'Data de adição';

  @override
  String get sortSongDateOldNew => 'Data da música (antiga - nova)';

  @override
  String get sortSongDateNewOld => 'Data da música (nova - antiga)';

  @override
  String get sortMostPlayed => 'Mais tocadas';

  @override
  String get sortRecentlyPlayed => 'Tocadas recentemente';

  @override
  String get sortRecommended => 'Recomendadas';

  @override
  String get searchFilterArtists => 'Artistas';

  @override
  String get playlistDialogAddTo => 'Adicionar a...';

  @override
  String get playlistDialogBulkAddTo => 'Adicionar em massa a...';

  @override
  String get playlistDialogUpdatedSelections => 'Seleções atualizadas';

  @override
  String get albumCardAllSongs => 'Todas as músicas';

  @override
  String dangerDialogTypeToConfirm(String text) {
    return 'Introduza \"$text\" para confirmar';
  }

  @override
  String dangerDialogCountdown(String label, int seconds) {
    return '$label ($seconds)';
  }

  @override
  String get appDialogConfirm => 'Confirmar';

  @override
  String get appDialogEnterName => 'Introduza o nome...';

  @override
  String get transportRepeatOff => 'Repetição desativada';

  @override
  String get transportRepeatAll => 'Repetir tudo';

  @override
  String get transportRepeatOne => 'Repetir uma';

  @override
  String durationSongsWithTotal(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0 • $duration';
  }

  @override
  String waveformDeltaMinutes(String minutes, String seconds) {
    return '${minutes}min ${seconds}s';
  }

  @override
  String waveformDeltaSeconds(String value) {
    return '${value}s';
  }

  @override
  String get waveformDeltaZero => '0s';

  @override
  String lyricsMatchContains(String line) {
    return 'contém \"$line\"';
  }

  @override
  String get lyricsMatchPrefix => 'contém \"';

  @override
  String get lyricsMatchAvailable => 'Letras disponíveis';

  @override
  String get lyricsResumeSync => 'Retomar sincronização';

  @override
  String get lyricsTimingTitle => 'Sincronização da letra';

  @override
  String get lyricsTimingLater => 'Mais tarde';

  @override
  String get lyricsTimingSyncToLine => 'Sincronizar com esta linha';

  @override
  String get lyricsTimingReset => 'Redefinir sincronização';

  @override
  String lyricsTimingSnapped(String value) {
    return 'Ajustado para $value';
  }

  @override
  String get lyricsTimingResetTooltip =>
      'Toque duas vezes para redefinir para 0,00';

  @override
  String get quickActionsTitle => 'Ações rápidas';

  @override
  String get quickActionsResetDone => 'Restaurado para a predefinição';

  @override
  String quickActionsEnabledHeader(int count) {
    return 'ATIVADAS ($count)';
  }

  @override
  String quickActionsDisabledHeader(int count) {
    return 'DESATIVADAS ($count)';
  }

  @override
  String get quickActionsGoToAlbum => 'Ir para o álbum';

  @override
  String get quickActionsGoToArtist => 'Ir para o artista';

  @override
  String get updateAvailableTitle => 'Atualização disponível';

  @override
  String get updateCurrentLabel => 'Atual';

  @override
  String get updateAvailableBody =>
      'Uma versão mais recente do wispie está pronta para transferir.';

  @override
  String get updateSkipVersion => 'Saltar esta versão';

  @override
  String get updateWhatsNew => 'Novidades?';

  @override
  String get externalOpenAddToLibrary => 'Adicionar à biblioteca';

  @override
  String get externalOpenDismiss => 'Dispensar';

  @override
  String get wideTrackTime => 'Tempo';

  @override
  String get floatingDockNext => 'Próxima';

  @override
  String get barSeekLabel => 'Procurar';
}
