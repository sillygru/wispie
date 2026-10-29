// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../services/online_music_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_error_message.dart';
import '../widgets/album_art_image.dart';
import '../widgets/online_track_row.dart';

/// The tracks of one album or one playlist.
///
/// Both are the same list of playable rows; only the id they were opened with
/// and the header differ, so the screen takes whichever the catalogue row named.
class YouTubeCollectionScreen extends ConsumerStatefulWidget {
  final OnlineCollectionKind kind;
  final String id;

  /// What the row already knew, shown while the page loads.
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
  OnlineCollectionTracks? _page;
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
      setState(() {
        _page = page;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<void> _playAll() async {
    final tracks = _page?.tracks ?? const <OnlineTrack>[];
    if (tracks.isEmpty) return;
    await OnlineTrackRow.play(context, ref, tracks.first, tracks);
  }

  String get _title {
    final loaded = _page?.title ?? '';
    return loaded.isNotEmpty ? loaded : widget.title;
  }

  String get _subtitle {
    final loaded = _page?.artist ?? '';
    return loaded.isNotEmpty ? loaded : widget.subtitle;
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _page?.tracks ?? const <OnlineTrack>[];
    final cover = _page?.coverUrl ?? widget.coverUrl;
    final loading = _page == null && _error == null;

    return AmbientScaffold(
      appBar: AppBar(
        title: Text(
          _title.isEmpty ? context.l10n.onlineTab : _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: loading
          ? Center(
              child: Semantics(
                label: context.l10n.onlineLoading,
                child: const CircularProgressIndicator(),
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
              itemCount: tracks.isEmpty ? 1 : tracks.length + 1,
              itemBuilder: (context, index) {
                if (index > 0) {
                  return OnlineTrackRow(
                      track: tracks[index - 1], queue: tracks);
                }
                return _header(context, cover: cover, tracks: tracks);
              },
            ),
    );
  }

  Widget _header(
    BuildContext context, {
    required String? cover,
    required List<OnlineTrack> tracks,
  }) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s2,
        AppTokens.s4,
        AppTokens.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AlbumArtImage(
                url: cover ?? '',
                width: 96,
                height: 96,
                borderRadius: AppTokens.rSm,
              ),
              const SizedBox(width: AppTokens.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.isEmpty ? l10n.onlineTab : _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.screenTitle(context),
                    ),
                    if (_subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.s1),
                      Text(
                        _subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.rowSubtitle(context),
                      ),
                    ],
                    if (tracks.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.s3),
                      FilledButton.icon(
                        onPressed: _playAll,
                        icon: const AppIcon(AppIcons.play),
                        label: Text(l10n.youtubePreviewPlayAll),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s3),
          if (tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s5),
              child: Text(
                _error == null
                    ? l10n.youtubeCollectionEmpty
                    : YouTubeErrorMessage.forError(_error!, l10n),
                style: AppTokens.rowSubtitle(context),
              ),
            ),
        ],
      ),
    );
  }
}
