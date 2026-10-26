// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../presentation/components/ambient_scaffold.dart';
import '../../presentation/components/app_icon.dart';
import '../../presentation/components/app_list_row.dart';
import '../../presentation/tokens/app_icons.dart';
import '../../presentation/tokens/app_tokens.dart';
import '../../presentation/utils/audius_error_message.dart';
import '../../presentation/widgets/album_art_image.dart';
import '../../presentation/widgets/playlist_selector_dialog.dart';
import '../../providers/providers.dart';
import '../../services/audius_service.dart';

class OnlineScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const OnlineScreen({super.key, this.scrollController});

  @override
  ConsumerState<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends ConsumerState<OnlineScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<AudiusTrack> _tracks = const [];
  String _text = '';
  int _generation = 0;
  bool _loading = false;
  Object? _error;

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    final generation = ++_generation;
    setState(() {
      _text = value;
      _tracks = const [];
      _error = null;
      _loading = query.isNotEmpty;
    });
    if (query.isEmpty) return;

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query, generation);
    });
  }

  Future<void> _search(String query, int generation) async {
    try {
      final tracks = await AudiusService.instance.searchTracks(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Song _toSong(AudiusTrack track) => Song.audius(
        trackId: track.id,
        title: track.title,
        artist: track.artist,
        coverUrl: track.artworkUrl,
        duration: track.duration,
      );

  Future<void> _play(AudiusTrack track) async {
    try {
      await ref.read(userDataProvider.notifier).cacheRemoteSong(_toSong(track));
      await ref.read(audioPlayerManagerProvider).playSong(
            _toSong(track),
            contextQueue: _tracks.map(_toSong).toList(),
          );
    } on Object catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _playNext(AudiusTrack track) async {
    try {
      await ref.read(userDataProvider.notifier).cacheRemoteSong(_toSong(track));
      await ref.read(audioPlayerManagerProvider).playNext(_toSong(track));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.songAddedToNextUp(track.title))),
      );
    } on Object catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _addToQueue(AudiusTrack track) async {
    try {
      await ref.read(userDataProvider.notifier).cacheRemoteSong(_toSong(track));
      await ref.read(audioPlayerManagerProvider).addToQueue(_toSong(track));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.onlineSongQueued(track.title))),
      );
    } on Object catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _addToPlaylist(AudiusTrack track) async {
    final song = _toSong(track);
    await ref.read(userDataProvider.notifier).cacheRemoteSong(song);
    if (!mounted) return;
    showPlaylistSelector(context, ref, song.filename);
  }

  void _showPlaybackError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AudiusErrorMessage.forError(error, context.l10n)),
      ),
    );
  }

  Widget _message(AppIconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 32, color: AppTokens.fgTertiary),
              const SizedBox(height: AppTokens.s3),
              Text(
                text,
                textAlign: TextAlign.center,
                style: AppTokens.rowSubtitle(context),
              ),
            ],
          ),
        ),
      );

  Widget _buildResults() {
    if (_loading) {
      return Center(
        child: Semantics(
          label: context.l10n.onlineLoading,
          child: const CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _message(
        AppIcons.search,
        AudiusErrorMessage.forError(_error!, context.l10n),
      );
    }
    if (_text.trim().isEmpty) {
      return _message(AppIcons.search, context.l10n.onlineSearchPrompt);
    }
    if (_tracks.isEmpty) {
      return _message(AppIcons.musicNote, context.l10n.onlineNoResults);
    }

    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: AppTokens.s2, bottom: AppTokens.s6),
      itemCount: _tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s1),
      itemBuilder: (context, index) {
        final track = _tracks[index];
        final song = _toSong(track);
        final isFavorite = ref.watch(
          userDataProvider.select((state) => state.isFavorite(song.filename)),
        );
        return AppListRow(
          key: ValueKey(track.id),
          tall: true,
          title: track.title,
          titleMaxLines: 1,
          subtitle: track.artist,
          subtitleMaxLines: 1,
          onTap: () => _play(track),
          leading: AlbumArtImage(
            url: track.artworkUrl ?? '',
            width: 52,
            height: 52,
            borderRadius: AppTokens.rSm,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: isFavorite
                    ? context.l10n.songMenuRemoveFavorite
                    : context.l10n.songMenuAddFavorite,
                onPressed: () => ref
                    .read(userDataProvider.notifier)
                    .toggleFavorite(song.filename, remoteSong: song),
                icon: AppIcon(
                  AppIcons.favorite,
                  size: AppTokens.iconMd,
                  color: isFavorite ? AppTokens.danger : null,
                ),
              ),
              IconButton(
                tooltip: context.l10n.songMenuTitle,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const AppIcon(AppIcons.queuePlayNext),
                          title: Text(context.l10n.songMenuPlayNext),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _playNext(track);
                          },
                        ),
                        ListTile(
                          leading: const AppIcon(AppIcons.playlistAdd),
                          title: Text(context.l10n.onlineAddToQueue),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _addToQueue(track);
                          },
                        ),
                        ListTile(
                          leading: const AppIcon(AppIcons.playlistAdd),
                          title: Text(context.l10n.onlineAddToPlaylist),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _addToPlaylist(track);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                icon: const AppIcon(AppIcons.moreVert, size: AppTokens.iconMd),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      appBar: AppBar(title: Text(context.l10n.onlineTab)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.s3,
              AppTokens.s2,
              AppTokens.s3,
              AppTokens.s2,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTokens.surface(1),
                borderRadius: AppTokens.brMd,
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: context.l10n.onlineSearchHint,
                  prefixIcon: const AppIcon(AppIcons.search),
                  suffixIcon: _text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.actionClose,
                          onPressed: _clearSearch,
                          icon: const AppIcon(AppIcons.close),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTokens.s3,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }
}
