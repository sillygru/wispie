// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/online_music_service.dart';
import '../components/ambient_scaffold.dart';
import '../cover_gradient/gradient_detail_screen.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_error_message.dart';

/// Fetches one album or playlist, then hands it to the shared detail screen.
///
/// There is no online-only layout: the tracks are the same [Song] rows the rest
/// of the app draws, so the immersive album screen renders them as-is.
class YouTubeCollectionScreen extends ConsumerStatefulWidget {
  final OnlineCollectionKind kind;
  final String id;

  /// What the catalogue row already knew, shown while the page loads.
  final String title;
  final String subtitle;
  final String? coverUrl;

  const YouTubeCollectionScreen({
    super.key,
    required this.kind,
    required this.id,
    this.title = '',
    this.subtitle = '',
    this.coverUrl,
  });

  @override
  ConsumerState<YouTubeCollectionScreen> createState() =>
      _YouTubeCollectionScreenState();
}

class _YouTubeCollectionScreenState
    extends ConsumerState<YouTubeCollectionScreen> {
  List<Song>? _songs;
  String _title = '';
  String _artist = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = OnlineMusicService.instance;
    try {
      final page = widget.kind == OnlineCollectionKind.album
          ? await service.album(widget.id)
          : await service.playlist(widget.id);
      if (!mounted) return;
      final songs = [for (final track in page.tracks) track.toSong()];
      // A selected or favorited track needs its catalogue row behind it.
      unawaited(ref.read(userDataProvider.notifier).cacheRemoteSongs(songs));
      setState(() {
        _songs = songs;
        _title = page.title;
        _artist = page.artist;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    if (songs != null && songs.isNotEmpty) {
      final isAlbum = widget.kind == OnlineCollectionKind.album;
      final title = _title.isEmpty ? widget.title : _title;
      return GradientDetailScreen(
        title: title,
        songs: songs,
        fromCatalogue: true,
        isAlbum: isAlbum,
        artistName: _artist,
        albumName: isAlbum ? title : null,
      );
    }
    if (songs != null) {
      return _statusScaffold(
        context,
        context.l10n.youtubeCollectionEmpty,
        retry: false,
      );
    }
    return _statusScaffold(context, null);
  }

  Widget _statusScaffold(
    BuildContext context,
    String? message, {
    bool retry = true,
  }) {
    final error = _error;
    return AmbientScaffold(
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? context.l10n.onlineTab : widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: error == null && message == null
            ? Semantics(
                label: context.l10n.onlineLoading,
                child: const CircularProgressIndicator(),
              )
            : Padding(
                padding: const EdgeInsets.all(AppTokens.s6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message ??
                          YouTubeErrorMessage.forError(error!, context.l10n),
                      textAlign: TextAlign.center,
                      style: AppTokens.rowSubtitle(context),
                    ),
                    if (retry && error != null)
                      TextButton(
                        onPressed: _load,
                        child: Text(context.l10n.actionRetry),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
