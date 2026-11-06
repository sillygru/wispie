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

/// Fetches one artist's catalogue page, then opens the shared artist screen.
///
/// The row list is the app's own [Song] list, so the immersive artist layout
/// (grouped by album, sorted locally) draws a YouTube artist too.
class YouTubeArtistScreen extends ConsumerStatefulWidget {
  final String id;

  /// What the catalogue row already knew, shown while the page loads.
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
  List<Song>? _songs;
  String _name = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final artist = await OnlineMusicService.instance.artist(widget.id);
      if (!mounted) return;
      final songs = [for (final track in artist.tracks) track.toSong()];
      // A selected or favorited track needs its catalogue row behind it.
      unawaited(ref.read(userDataProvider.notifier).cacheRemoteSongs(songs));
      setState(() {
        _songs = songs;
        _name = artist.name;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  String get _title => _name.isEmpty ? widget.name : _name;

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    if (songs != null && songs.isNotEmpty) {
      return GradientDetailScreen(
        title: _title,
        songs: songs,
        fromCatalogue: true,
        isArtist: true,
        artistName: _title,
      );
    }

    final error = _error;
    return AmbientScaffold(
      appBar: AppBar(
        title: Text(
          _title.isEmpty ? context.l10n.onlineTab : _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: error == null && songs == null
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
                      error == null
                          ? context.l10n.youtubeCollectionEmpty
                          : YouTubeErrorMessage.forError(error, context.l10n),
                      textAlign: TextAlign.center,
                      style: AppTokens.rowSubtitle(context),
                    ),
                    if (error != null)
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
