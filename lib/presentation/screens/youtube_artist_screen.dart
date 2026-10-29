// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../services/online_music_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_chip.dart';
import '../components/app_list_row.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_error_message.dart';
import '../widgets/album_art_image.dart';
import '../widgets/online_track_row.dart';
import 'youtube_collection_screen.dart';

/// One artist, as YouTube Music ranks them.
///
/// The order is never invented here: the page arrives with its own sort chips
/// (popularity, release date, ...) and tapping one asks YouTube for that order
/// again. That is the only way to sort by popularity honestly, since a song row
/// carries no year and its play count is printed text rather than a number.
class YouTubeArtistScreen extends ConsumerStatefulWidget {
  final String id;

  /// What the search row already knew, shown while the page loads.
  final String name;
  final String? coverUrl;

  const YouTubeArtistScreen({
    super.key,
    required this.id,
    this.name = '',
    this.coverUrl,
  });

  @override
  ConsumerState<YouTubeArtistScreen> createState() =>
      _YouTubeArtistScreenState();
}

class _YouTubeArtistScreenState extends ConsumerState<YouTubeArtistScreen> {
  OnlineArtist? _artist;
  Object? _error;
  String _sortParams = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? params}) async {
    final target = params ?? _sortParams;
    setState(() {
      _loading = true;
      _error = null;
      _sortParams = target;
    });
    try {
      final artist = await OnlineMusicService.instance.artist(
        widget.id,
        params: target.isEmpty ? null : target,
      );
      if (!mounted) return;
      setState(() {
        _artist = artist;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  String get _name {
    final loaded = _artist?.name ?? '';
    return loaded.isNotEmpty ? loaded : widget.name;
  }

  void _openAlbum(OnlineCollection album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeCollectionScreen(
          kind: OnlineCollectionKind.album,
          id: album.id,
          title: album.title,
          subtitle: album.subtitle,
          coverUrl: album.coverUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artist = _artist;
    final l10n = context.l10n;

    return AmbientScaffold(
      appBar: AppBar(
        title: Text(
          _name.isEmpty ? l10n.onlineTab : _name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: artist == null
          ? _placeholder(context)
          : ListView(
              padding:
                  const EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
              children: [
                _header(context, artist),
                if (artist.sorts.length > 1) _sortChips(context, artist),
                if (artist.tracks.isNotEmpty) ...[
                  _sectionLabel(context, l10n.youtubeArtistSongsTitle),
                  for (final track in artist.tracks)
                    OnlineTrackRow(track: track, queue: artist.tracks),
                ],
                if (artist.albums.isNotEmpty) ...[
                  _sectionLabel(context, l10n.youtubeArtistAlbumsTitle),
                  for (final album in artist.albums)
                    AppListRow(
                      key: ValueKey('artist-album-${album.id}'),
                      title: album.title,
                      titleMaxLines: 1,
                      subtitle: album.subtitle,
                      subtitleMaxLines: 1,
                      onTap: () => _openAlbum(album),
                      leading: AlbumArtImage(
                        url: album.coverUrl ?? '',
                        width: 52,
                        height: 52,
                        borderRadius: AppTokens.rSm,
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _placeholder(BuildContext context) {
    if (_loading) {
      return Center(
        child: Semantics(
          label: context.l10n.onlineLoading,
          child: const CircularProgressIndicator(),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              YouTubeErrorMessage.forError(_error!, context.l10n),
              textAlign: TextAlign.center,
              style: AppTokens.rowSubtitle(context),
            ),
            TextButton(
              onPressed: () => _load(),
              child: Text(context.l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, OnlineArtist artist) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s2,
        AppTokens.s4,
        AppTokens.s2,
      ),
      child: Row(
        children: [
          ClipOval(
            child: AlbumArtImage(
              url: artist.coverUrl ?? widget.coverUrl ?? '',
              width: 72,
              height: 72,
            ),
          ),
          const SizedBox(width: AppTokens.s4),
          Expanded(
            child: Text(
              _name.isEmpty ? context.l10n.onlineTab : _name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.screenTitle(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChips(BuildContext context, OnlineArtist artist) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
        itemCount: artist.sorts.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppTokens.s2),
        itemBuilder: (context, index) {
          final sort = artist.sorts[index];
          final selected =
              sort.params == _sortParams || (_sortParams.isEmpty && index == 0);
          return Center(
            child: AppChip(
              label: sort.label,
              selected: selected,
              onTap: () {
                if (selected) return;
                _load(params: sort.params);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s4,
        AppTokens.s4,
        AppTokens.s2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTokens.sectionLabel(context)),
          ),
          if (_loading)
            const SizedBox(
              width: AppTokens.iconSm,
              height: AppTokens.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
