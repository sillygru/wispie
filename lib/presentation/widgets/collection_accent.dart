import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/services/cover_path.dart';
import '../../models/song.dart';
import '../../services/color_extraction_service.dart';
import '../../services/library_logic.dart';
import '../../theme/app_theme.dart';
import 'collection_accent_scope.dart';

/// Tints a page from the artwork of the collection it is showing, instead of
/// from whatever song happens to be playing.
///
/// Installs two things for [child]: a [Theme] seeded with the collection's
/// accent, so every themed widget (filled buttons, chips, sliders) follows it,
/// and a [CollectionAccentScope] so the widgets that read the accent directly
/// via `AppTokens.accentOf` follow it too.
///
/// Extraction is asynchronous and cached by [ColorExtractionService], so the
/// page renders on the app accent for a frame or two and then settles. Until
/// [fallback] resolves — no local cover, an unreadable file — nothing is
/// installed and the page keeps the app theme rather than flashing a hue the
/// artwork never had.
class CollectionAccent extends StatefulWidget {
  /// Cached artist/album artwork. Wins over the songs' own covers.
  final String? artworkPath;

  /// Backs the accent when there is no custom artwork: the collection's
  /// most-listened local cover.
  final List<Song> songs;

  /// Used until extraction lands, and left in place if it never does.
  final Color? fallback;

  final Widget child;

  const CollectionAccent({
    super.key,
    required this.artworkPath,
    required this.songs,
    required this.child,
    this.fallback,
  });

  @override
  State<CollectionAccent> createState() => _CollectionAccentState();
}

class _CollectionAccentState extends State<CollectionAccent> {
  Color? _accent;
  bool _isNeutral = false;
  String _key = '';

  /// The file the palette is read from, and the cache identity for it.
  String? get _source {
    final custom = widget.artworkPath;
    if (custom != null && custom.isNotEmpty) return custom;
    final cover = LibraryLogic.pickCoverSong(widget.songs)?.coverUrl;
    if (cover == null || cover.isEmpty) return null;
    if (!CoverPath.isLocal(cover)) return null;
    return cover;
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CollectionAccent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the custom artwork is re-resolved. [songs] is a freshly sorted list
    // on every build, so comparing it would re-sort the whole collection just
    // to answer "did the cover change" — and it never did for this page.
    if (oldWidget.artworkPath != widget.artworkPath) _resolve();
  }

  Future<void> _resolve() async {
    final source = _source;
    if (source == null || source == _key) return;
    _key = source;
    try {
      final palette = await ColorExtractionService.extractPalette(source);
      if (!mounted || palette == null) return;
      setState(() {
        _accent = palette.color;
        _isNeutral = palette.isNeutral;
      });
    } on FileSystemException {
      // Artwork vanished under us (removed or moved mid-open). The fallback
      // accent already on screen stays put.
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent ?? widget.fallback;
    if (accent == null) return widget.child;

    return Theme(
      data: AppTheme.forAccent(accent, isNeutral: _isNeutral),
      child: CollectionAccentScope(
        accent: accent,
        isNeutral: _isNeutral,
        child: widget.child,
      ),
    );
  }
}
