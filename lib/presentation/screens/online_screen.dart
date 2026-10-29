// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/youtube_library.dart';
import '../../l10n/l10n.dart';
import '../../presentation/components/ambient_scaffold.dart';
import '../../presentation/components/app_icon.dart';
import '../../presentation/components/app_list_row.dart';
import '../../presentation/screens/youtube_account_screen.dart';
import '../../presentation/screens/youtube_artist_screen.dart';
import '../../presentation/screens/youtube_collection_screen.dart';
import '../../presentation/screens/youtube_playlist_preview_screen.dart';
import '../../presentation/tokens/app_icons.dart';
import '../../presentation/tokens/app_tokens.dart';
import '../../presentation/widgets/album_art_image.dart';
import '../../presentation/widgets/online_track_row.dart';
import '../../presentation/utils/youtube_error_message.dart';
import '../../providers/youtube_account_provider.dart';
import '../../services/online_music_service.dart';
import '../components/app_surface.dart';

/// The YouTube tab: a search field, a recommendations feed and the account's
/// playlists.
///
/// The feed is music from the YouTube Music catalogue, ranked by the artists
/// this device plays most. Signing in adds the account's music shelves as a
/// second pool; it never replaces the local taste profile.
class OnlineScreen extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const OnlineScreen({super.key, this.scrollController});

  @override
  ConsumerState<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends ConsumerState<OnlineScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  OnlineSearchResults _results = OnlineSearchResults.empty;
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
      _results = OnlineSearchResults.empty;
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
      final results = await OnlineMusicService.instance.searchAll(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
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

  void _openCollection(OnlineCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => switch (collection.kind) {
          OnlineCollectionKind.album => YouTubeCollectionScreen(
              kind: OnlineCollectionKind.album,
              id: collection.id,
              title: collection.title,
              subtitle: collection.subtitle,
              coverUrl: collection.coverUrl,
            ),
          OnlineCollectionKind.playlist => YouTubeCollectionScreen(
              kind: OnlineCollectionKind.playlist,
              id: collection.id,
              title: collection.title,
              subtitle: collection.subtitle,
              coverUrl: collection.coverUrl,
            ),
          OnlineCollectionKind.artist => YouTubeArtistScreen(
              id: collection.id,
              name: collection.title,
              coverUrl: collection.coverUrl,
            ),
        },
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

  Widget _trackRow(OnlineTrack track, List<OnlineTrack> queue) =>
      OnlineTrackRow(
        key: ValueKey('youtube-track-${track.id}'),
        track: track,
        queue: queue,
      );

  /// A place rather than a track: an album, a playlist or an artist.
  Widget _collectionRow(OnlineCollection collection) {
    return AppListRow(
      key: ValueKey('youtube-collection-${collection.id}'),
      tall: true,
      title: collection.title,
      titleMaxLines: 1,
      subtitle: collection.subtitle.isEmpty ? null : collection.subtitle,
      subtitleMaxLines: 1,
      onTap: () => _openCollection(collection),
      leading: AlbumArtImage(
        url: collection.coverUrl ?? '',
        width: 52,
        height: 52,
        borderRadius: AppTokens.rSm,
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.s4,
          AppTokens.s4,
          AppTokens.s4,
          AppTokens.s2,
        ),
        child: Text(label, style: AppTokens.sectionLabel(context)),
      );

  Widget _feedSection(
    AsyncValue<List<OnlineTrack>> feed,
    String Function(AppLocalizations l10n) label,
  ) {
    return feed.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.s6),
        child: Center(
          child: SizedBox(
            width: AppTokens.iconMd,
            height: AppTokens.iconMd,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s4,
          vertical: AppTokens.s2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YouTubeErrorMessage.forError(error, context.l10n),
              style: AppTokens.rowSubtitle(context),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(youtubeForYouTracksProvider.notifier).refresh(),
              child: Text(context.l10n.actionRetry),
            ),
          ],
        ),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s4,
              vertical: AppTokens.s2,
            ),
            child: Text(
              context.l10n.youtubeFeedEmpty,
              style: AppTokens.rowSubtitle(context),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(label(context.l10n)),
            for (final track in tracks) _trackRow(track, tracks),
          ],
        );
      },
    );
  }

  Widget _signInPrompt() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s3,
        AppTokens.s4,
        AppTokens.s1,
      ),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.youtubeFeedSignInTitle,
              style: AppTokens.screenTitle(context),
            ),
            const SizedBox(height: AppTokens.s2),
            Text(
              l10n.youtubeFeedSignInBody,
              style: AppTokens.rowSubtitle(context),
            ),
            const SizedBox(height: AppTokens.s3),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const YouTubeAccountScreen(),
                ),
              ),
              icon: const AppIcon(AppIcons.person),
              label: Text(l10n.youtubeFeedSignInAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlaylistFilter(List<YouTubeAccountPlaylist> items) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final hidden =
                ref.watch(youtubeHiddenPlaylistsProvider).asData?.value ??
                    YouTubeHiddenPlaylistsNotifier.defaults;
            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.s4,
                    0,
                    AppTokens.s4,
                    AppTokens.s2,
                  ),
                  child: Text(
                    l10n.youtubeFeedFilterPlaylists,
                    style: AppTokens.screenTitle(context),
                  ),
                ),
                for (final playlist in items)
                  CheckboxListTile(
                    value: !hidden.contains(playlist.id),
                    title: Text(
                      playlist.isLikedVideos
                          ? l10n.youtubeAccountLikedVideos
                          : playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (visible) => ref
                        .read(youtubeHiddenPlaylistsProvider.notifier)
                        .setHidden(playlist.id, visible != true),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _playlistsRail() {
    final playlists = ref.watch(youtubeAccountPlaylistsProvider);
    final hidden = ref.watch(youtubeHiddenPlaylistsProvider).asData?.value ??
        YouTubeHiddenPlaylistsNotifier.defaults;
    return playlists.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final visible =
            items.where((playlist) => !hidden.contains(playlist.id)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s4,
                AppTokens.s4,
                AppTokens.s2,
                AppTokens.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.youtubeFeedPlaylists,
                      style: AppTokens.sectionLabel(context),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.youtubeFeedFilterPlaylists,
                    onPressed: () => _showPlaylistFilter(items),
                    icon: const AppIcon(
                      AppIcons.filterList,
                      size: AppTokens.iconMd,
                    ),
                  ),
                ],
              ),
            ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s4,
                  vertical: AppTokens.s2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.youtubeFeedPlaylistsHidden,
                        style: AppTokens.rowSubtitle(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showPlaylistFilter(items),
                      child: Text(context.l10n.youtubeFeedFilterPlaylists),
                    ),
                  ],
                ),
              ),
            if (visible.isNotEmpty)
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s4,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppTokens.s3),
                  itemBuilder: (context, index) {
                    final playlist = visible[index];
                    final title = playlist.isLikedVideos
                        ? context.l10n.youtubeAccountLikedVideos
                        : playlist.title;
                    return SizedBox(
                      width: 132,
                      child: InkWell(
                        borderRadius: AppTokens.brMd,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => YouTubePlaylistPreviewScreen(
                              playlist: playlist,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AlbumArtImage(
                              url: playlist.thumbnailUrl ?? '',
                              width: 132,
                              height: 132,
                              borderRadius: AppTokens.rSm,
                            ),
                            const SizedBox(height: AppTokens.s2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTokens.rowTitle(context),
                            ),
                            if (playlist.itemCount != null)
                              Text(
                                context.l10n.youtubeAccountPlaylistTracks(
                                  playlist.itemCount!,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTokens.rowSubtitle(context),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHome(bool signedIn) {
    final feed = ref.watch(youtubeForYouTracksProvider);

    // Pulling refreshes the feed in place; the cached list stays on screen while
    // the new pools are fetched, so the indicator is the only thing that moves.
    return RefreshIndicator(
      onRefresh: () => ref.read(youtubeForYouTracksProvider.notifier).refresh(),
      child: ListView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
        children: [
          if (!signedIn) _signInPrompt(),
          _feedSection(
            feed,
            (l10n) =>
                signedIn ? l10n.youtubeFeedForYou : l10n.youtubeFeedFromLibrary,
          ),
          if (signedIn) _playlistsRail(),
        ],
      ),
    );
  }

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
        YouTubeErrorMessage.forError(_error!, context.l10n),
      );
    }
    final results = _results;
    if (results.isEmpty) {
      return _message(AppIcons.musicNote, context.l10n.onlineNoResults);
    }

    // Order follows how far a tap reaches: the songs first, then the album or
    // playlist the query named, then the artist it named.
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: AppTokens.s2, bottom: AppTokens.s6),
      children: [
        if (results.tracks.isNotEmpty) ...[
          _sectionHeader(context.l10n.youtubeSearchSongs),
          for (final track in results.tracks) _trackRow(track, results.tracks),
        ],
        if (results.albums.isNotEmpty) ...[
          _sectionHeader(context.l10n.youtubeSearchAlbums),
          for (final album in results.albums) _collectionRow(album),
        ],
        if (results.playlists.isNotEmpty) ...[
          _sectionHeader(context.l10n.youtubeSearchPlaylists),
          for (final playlist in results.playlists) _collectionRow(playlist),
        ],
        if (results.artists.isNotEmpty) ...[
          _sectionHeader(context.l10n.youtubeSearchArtists),
          for (final artist in results.artists) _collectionRow(artist),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(youtubeAccountProvider).asData?.value;
    final signedIn = account?.signedIn ?? false;
    final searching = _text.trim().isNotEmpty;

    return AmbientScaffold(
      appBar: AppBar(
        title: Text(context.l10n.onlineTab),
        actions: [
          IconButton(
            tooltip: context.l10n.youtubeAccountTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const YouTubeAccountScreen(),
              ),
            ),
            icon: AppIcon(
              AppIcons.person,
              size: AppTokens.iconMd,
              color: signedIn ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
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
          Expanded(
            child: searching ? _buildResults() : _buildHome(signedIn),
          ),
        ],
      ),
    );
  }
}
