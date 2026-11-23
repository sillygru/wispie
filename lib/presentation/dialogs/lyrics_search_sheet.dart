import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/rust/rust_library_tasks.dart';
import '../../domain/models/lrclib_result.dart';
import '../../l10n/l10n.dart';
import '../../domain/services/lrclib_match.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/lrclib_service.dart';
import '../../services/lyrics_files_service.dart';
import '../components/app_feedback.dart';
import '../components/app_sheet.dart';
import '../tokens/app_tokens.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

/// Opens the LRCLIB lyrics picker for [song].
///
/// Returns the confirmed lyrics and their timing payload, if available.
Future<LyricsChoice?> showLyricsSearchSheet(
  BuildContext context, {
  required Song song,
}) {
  return showAppSheet<LyricsChoice>(
    context,
    title: context.l10n.lyricsFindTitle,
    builder: (context) => _LyricsSearchSheet(song: song),
  );
}

class _LyricsSearchSheet extends ConsumerStatefulWidget {
  final Song song;

  const _LyricsSearchSheet({required this.song});

  @override
  ConsumerState<_LyricsSearchSheet> createState() => _LyricsSearchSheetState();
}

class _LyricsSearchSheetState extends ConsumerState<_LyricsSearchSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;

  List<LrclibResult>? _results;
  bool _searching = false;
  bool _preferPlain = false;
  String? _error;

  /// Drops results from a query the user has already moved on from.
  int _searchToken = 0;

  /// Sidecar files already on disk, primary first. Shown while the network
  /// search runs, so lyrics the user already has never wait on a provider.
  List<LyricsFileDetails> _localFiles = const [];

  @override
  void initState() {
    super.initState();
    // Start from the file's tags, but blank out the scanner's placeholders so
    // an untagged file shows an empty artist box rather than "Unknown Artist"
    // (which LRCLIB would treat as a filter that matches nothing).
    _titleController = TextEditingController(
        text: LrclibService.cleanTag(widget.song.title) ?? '');
    _artistController = TextEditingController(
        text: LrclibService.cleanTag(widget.song.artist) ?? '');
    _loadLocal();
    // The song's own tags are the best first guess, so search immediately
    // rather than making the user press a button to see the obvious query.
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  Future<void> _loadLocal() async {
    final links = await LyricsFilesService.instance.linksFor([widget.song]);
    final link = links[widget.song.filename];
    if (!mounted || link == null) return;
    final files = await LyricsFilesService.instance.detailsForPaths(link.paths);
    if (mounted) setState(() => _localFiles = files);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!mounted) return;
    final token = ++_searchToken;
    setState(() {
      _searching = true;
      _error = null;
    });

    // Never let a provider failure hold the spinner: without this the sheet
    // stayed disabled until the user backed out and came in again.
    List<LrclibResult>? results;
    Object? failure;
    try {
      results = await ref.read(lrclibServiceProvider).findFor(
            widget.song,
            titleOverride: _titleController.text,
            artistOverride: _artistController.text,
            preferPlain: _preferPlain,
          );
    } catch (error) {
      failure = error;
    }

    if (!mounted || token != _searchToken) return;

    setState(() {
      _searching = false;
      _results = results ?? const [];
      _error = failure != null
          ? context.l10n.lyricsSearchFailed('$failure')
          : (results!.isEmpty ? context.l10n.lyricsNoResults : null);
    });
  }

  Future<void> _preview(LrclibResult result) async {
    final choice = result.choiceFor(preferPlain: _preferPlain);
    if (choice == null) return;

    final confirmed = await _confirmPreview(
      result.trackName,
      result.instrumental
          ? context.l10n.lyricsInstrumentalWarning
          : _previewText(choice.text),
    );
    if (confirmed && mounted) {
      Navigator.pop(context, choice);
    }
  }

  /// Uses a sidecar file the user already has, previewed like a remote result.
  Future<void> _previewLocal(LyricsFileDetails file) async {
    final lyrics = file.text?.trim();
    if (lyrics == null || lyrics.isEmpty) {
      appSnack(context, context.l10n.lyricsFileUnreadable);
      return;
    }

    final confirmed = await _confirmPreview(
      p.basename(file.path),
      _previewText(lyrics),
    );
    if (confirmed && mounted) {
      Navigator.pop<LyricsChoice>(context, (text: lyrics, richSync: null));
    }
  }

  Future<bool> _confirmPreview(String title, String shown) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              shown,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.backupCancelUpper),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.lyricsApplyUpper),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// First few lines only — enough to tell two versions apart without turning
  /// the dialog into a full lyric sheet.
  static String _previewText(String lyrics) {
    final lines = lyrics.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 8) return lines.join('\n');
    return '${lines.take(8).join('\n')}\n…';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accentOf(context, ref);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _queryField(
                        _titleController,
                        l10n.metadataTitleLabel,
                      ),
                    ),
                    const SizedBox(width: AppTokens.s3),
                    Expanded(
                      child: _queryField(
                        _artistController,
                        l10n.metadataArtistLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s3),
                Row(
                  children: [
                    Expanded(
                      child: _PlainToggle(
                        value: _preferPlain,
                        accent: accent,
                        onChanged: (value) => setState(() {
                          _preferPlain = value;
                          if (_results != null) {
                            _results = rankLrclibResults(
                              _results!,
                              widget.song,
                              preferPlain: value,
                            );
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: AppTokens.s3),
                    FilledButton.icon(
                      onPressed: _searching ? null : _search,
                      icon: const AppIcon(AppIcons.search, size: 18),
                      label: Text(l10n.actionSearch),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.s3),
          Flexible(child: _buildBody(accent)),
        ],
      ),
    );
  }

  Widget _queryField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _search(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: InputBorder.none,
        filled: true,
      ),
    );
  }

  Widget _buildBody(Color accent) {
    final l10n = context.l10n;
    final children = <Widget>[];

    if (_localFiles.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.s5,
          0,
          AppTokens.s5,
          AppTokens.s2,
        ),
        child: Text(
          l10n.lyricsLocalFileSection,
          style: AppTokens.sectionLabel(context),
        ),
      ));
      for (final file in _localFiles) {
        children.add(_LocalFileRow(
          file: file,
          songDuration: widget.song.duration,
          accent: accent,
          onTap: () => _previewLocal(file),
        ));
      }
      children.add(const SizedBox(height: AppTokens.s3));
    }

    if (_searching) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.s6),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ));
    } else if (_error != null) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.s5,
          AppTokens.s4,
          AppTokens.s5,
          AppTokens.s6,
        ),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: AppTokens.rowSubtitle(context),
        ),
      ));
    } else {
      final results = _results ?? const <LrclibResult>[];
      for (final result in results) {
        children.add(_ResultRow(
          result: result,
          localDuration: widget.song.duration,
          preferPlain: _preferPlain,
          accent: accent,
          onTap: () => _preview(result),
        ));
      }
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: AppTokens.s4),
      children: children,
    );
  }
}

/// A lyric file that is already on disk, listed above the network results.
class _LocalFileRow extends StatelessWidget {
  final LyricsFileDetails file;
  final Duration? songDuration;
  final Color accent;
  final VoidCallback onTap;

  const _LocalFileRow({
    required this.file,
    required this.songDuration,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppTokens.s5),
      title: Text(p.basename(file.path), style: AppTokens.rowTitle(context)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.dirname(file.path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (file.text?.trim().isNotEmpty == true)
            Text(
              _durationLine(context.l10n, file.duration, songDuration),
              style: AppTokens.meta(context),
            )
          else
            Text(context.l10n.lyricsFileUnreadable),
        ],
      ),
      trailing: file.text?.trim().isNotEmpty == true
          ? _SyncBadge(type: file.syncType, accent: accent)
          : null,
    );
  }
}

/// Switches the whole list between synced and plain, rather than asking per
/// result — the choice is a preference, not a per-track decision.
class _PlainToggle extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _PlainToggle({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppTokens.brSm,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s1),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                activeColor: accent,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: AppTokens.s2),
            Flexible(
              child: Text(
                context.l10n.lyricsPlainText,
                style: AppTokens.rowSubtitle(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final LrclibResult result;
  final Duration? localDuration;
  final bool preferPlain;
  final Color accent;
  final VoidCallback onTap;

  const _ResultRow({
    required this.result,
    required this.localDuration,
    required this.preferPlain,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final available = result.isUsable;
    final syncType = preferPlain && result.hasPlain && !result.instrumental
        ? LyricsSyncType.plain
        : result.syncType;

    return Opacity(
      opacity: available ? 1 : 0.4,
      child: InkWell(
        onTap: available ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s5,
            vertical: AppTokens.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.trackName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.rowTitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTokens.rowSubtitle(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _durationLine(
                          context.l10n, result.duration, localDuration),
                      style: AppTokens.meta(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s3),
              _SyncBadge(type: syncType, accent: accent),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final artist = result.artistName.trim();
    final album = result.albumName.trim();
    if (artist.isEmpty) return album;
    if (album.isEmpty) return artist;
    return '$artist · $album';
  }
}

String _durationLine(
  AppLocalizations l10n,
  Duration? lyricsDuration,
  Duration? songDuration,
) {
  final local = songDuration?.inMilliseconds ?? 0;
  final remote = lyricsDuration?.inMilliseconds ?? 0;
  if (remote <= 0) {
    return local <= 0
        ? l10n.lyricsUnknownLength
        : l10n.lyricsUnknownLengthWithTrack(_formatDuration(local));
  }
  final formatted = _formatDuration(remote);
  if (local <= 0) return formatted;
  final delta = remote - local;
  if (delta == 0) return l10n.lyricsDurationExactMatch(formatted);
  final sign = delta > 0 ? '+' : '−';
  return l10n.lyricsDurationDifference(
    formatted,
    _formatDuration(local),
    '$sign${_formatDuration(delta.abs())}',
  );
}

String _formatDuration(int milliseconds) {
  final minutes = milliseconds ~/ Duration.millisecondsPerMinute;
  final seconds = (milliseconds ~/ 1000) % 60;
  final whole = '$minutes:${seconds.toString().padLeft(2, '0')}';
  final fraction = milliseconds % 1000;
  if (fraction == 0) return whole;
  return '$whole.${fraction.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '')}';
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.type, required this.accent});

  final LyricsSyncType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      LyricsSyncType.word => (context.l10n.lyricsBadgeWordSync, accent),
      LyricsSyncType.line => (context.l10n.lyricsBadgeLineSync, accent),
      LyricsSyncType.instrumental => (
          context.l10n.lyricsBadgeInstrumental,
          AppTokens.fgTertiary,
        ),
      LyricsSyncType.plain => (
          context.l10n.lyricsBadgePlain,
          AppTokens.fgTertiary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s2,
        vertical: AppTokens.s1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppTokens.brPill,
      ),
      child: Text(
        label,
        style: AppTokens.meta(context).copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
