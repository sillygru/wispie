import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/selection_provider.dart';
import '../tokens/app_tokens.dart';
import '../tokens/app_icons.dart';
import 'app_icon.dart';
import '../widgets/album_art_image.dart';
import '../widgets/duration_display.dart';
import '../widgets/song_options_menu.dart';
import '../components/pop_icon.dart';

/// Wide-window track table shared by browse surfaces.
///
/// Single-column header plus dense rows with title / artist / album /
/// duration and hover actions. Phone lists stay on [SongListItem]; this
/// is desktop-only vocabulary.
class WideTrackTable extends StatelessWidget {
  final List<Song> songs;
  final void Function(Song song) onTapSong;
  final String heroTagPrefix;
  final bool showAlbum;
  final bool showHeader;
  final String? playlistId;

  const WideTrackTable({
    super.key,
    required this.songs,
    required this.onTapSong,
    required this.heroTagPrefix,
    this.showAlbum = true,
    this.showHeader = true,
    this.playlistId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader && songs.isNotEmpty)
          WideTrackTableHeader(showAlbum: showAlbum),
        for (final song in songs)
          WideTrackRow(
            song: song,
            heroTagPrefix: heroTagPrefix,
            showAlbum: showAlbum,
            playlistId: playlistId,
            onTap: () => onTapSong(song),
          ),
      ],
    );
  }
}

class WideTrackTableHeader extends StatelessWidget {
  final bool showAlbum;

  const WideTrackTableHeader({super.key, this.showAlbum = true});

  @override
  Widget build(BuildContext context) {
    final style = AppTokens.meta(context).copyWith(
      color: AppTokens.fgTertiary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s3 + 48 + AppTokens.s3,
        AppTokens.s2,
        AppTokens.s3,
        AppTokens.s1,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Title', style: style)),
          const SizedBox(width: AppTokens.s3),
          Expanded(flex: 2, child: Text('Artist', style: style)),
          if (showAlbum) ...[
            const SizedBox(width: AppTokens.s3),
            Expanded(flex: 2, child: Text('Album', style: style)),
          ],
          const SizedBox(width: AppTokens.s3),
          SizedBox(
            width: 52,
            child: Text('Time', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 76),
        ],
      ),
    );
  }
}

class WideTrackRow extends ConsumerStatefulWidget {
  final Song song;
  final String heroTagPrefix;
  final bool showAlbum;
  final String? playlistId;
  final VoidCallback onTap;

  const WideTrackRow({
    super.key,
    required this.song,
    required this.heroTagPrefix,
    required this.onTap,
    this.showAlbum = true,
    this.playlistId,
  });

  @override
  ConsumerState<WideTrackRow> createState() => _WideTrackRowState();
}

class _WideTrackRowState extends ConsumerState<WideTrackRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final selectionState = ref.watch(selectionProvider);
    final accent = AppTokens.accentOf(context, ref);
    final song = widget.song;

    final isFavorite = userData.isFavorite(song.filename);
    final isSelected = selectionState.selectedFilenames.contains(song.filename);

    return ValueListenableBuilder<Song?>(
      valueListenable: audioManager.currentSongNotifier,
      builder: (context, currentSong, _) {
        final isPlaying = currentSong?.filename == song.filename;
        final isActive = isPlaying || isSelected;
        final titleColor = isActive ? accent : AppTokens.fg(AppTokens.aPrimary);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: selectionState.isSelectionMode
                ? () => ref
                    .read(selectionProvider.notifier)
                    .toggleSelection(song.filename)
                : widget.onTap,
            onLongPress: () {
              if (!selectionState.isSelectionMode) {
                ref
                    .read(selectionProvider.notifier)
                    .enterSelectionMode(song.filename);
                HapticFeedback.heavyImpact();
              }
            },
            onSecondaryTap: () {
              if (!mounted) return;
              showSongOptionsMenu(
                context,
                ref,
                song.filename,
                song.title,
                song: song,
                playlistId: widget.playlistId,
              );
            },
            child: AnimatedContainer(
              duration: AppTokens.dFast,
              curve: AppTokens.cStandard,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s3,
                vertical: AppTokens.s2,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? accent.withValues(alpha: AppTokens.accentWashAlpha)
                    : (_hovering ? AppTokens.surface(2) : Colors.transparent),
                borderRadius: AppTokens.brMd,
              ),
              child: Row(
                children: [
                  Hero(
                    tag: '${widget.heroTagPrefix}_${song.filename}',
                    child: AppRowArtSmall(child: _RowArt(song: song)),
                  ),
                  const SizedBox(width: AppTokens.s3),
                  Expanded(
                    flex: 3,
                    child: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.rowTitle(context).copyWith(
                        color: titleColor,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.s3),
                  Expanded(
                    flex: 2,
                    child: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.rowSubtitle(context),
                    ),
                  ),
                  if (widget.showAlbum) ...[
                    const SizedBox(width: AppTokens.s3),
                    Expanded(
                      flex: 2,
                      child: Text(
                        song.album,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.rowSubtitle(context),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppTokens.s3),
                  SizedBox(
                    width: 52,
                    child: Text(
                      DurationFormatter.format(song.duration),
                      textAlign: TextAlign.right,
                      style: AppTokens.meta(context).copyWith(
                        color: AppTokens.fgTertiary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Opacity(
                          opacity:
                              (_hovering || isFavorite || isActive) ? 1 : 0,
                          child: PopIcon(
                            isActive: isFavorite,
                            activeColor: accent,
                            inactiveColor: AppTokens.fgTertiary,
                            size: 18,
                            onTap: () => ref
                                .read(userDataProvider.notifier)
                                .toggleFavorite(song.filename),
                          ),
                        ),
                        Builder(
                          builder: (btnContext) => IconButton(
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: AppIcon(
                              AppIcons.moreVert,
                              color: AppTokens.fgSecondary,
                            ),
                            onPressed: () {
                              showSongOptionsMenu(
                                context,
                                ref,
                                song.filename,
                                song.title,
                                song: song,
                                playlistId: widget.playlistId,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RowArt extends StatelessWidget {
  final Song song;

  const _RowArt({required this.song});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppTokens.brSm,
      child: AlbumArtImage(
        url: song.coverUrl ?? '',
        filename: song.filename,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        memCacheWidth: 104,
        memCacheHeight: 104,
      ),
    );
  }
}

class AppRowArtSmall extends StatelessWidget {
  final Widget child;

  const AppRowArtSmall({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 40, height: 40, child: child);
  }
}
