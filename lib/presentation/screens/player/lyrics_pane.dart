import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/rich_lyrics.dart';
import '../../../domain/services/lyrics_session.dart';
import '../../../models/song.dart';
import '../../../providers/providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/database_service.dart';
import '../../../services/display_refresh_service.dart';
import '../../../services/lingva_translate_service.dart';
import '../../../services/lrclib_service.dart';
import '../../components/app_feedback.dart';
import '../../dialogs/lyrics_search_sheet.dart';
import '../../dialogs/lyrics_translation_sheet.dart';
import '../../models/lyrics_gap_loader_state.dart';
import '../../tokens/player_tokens.dart';
import '../../widgets/lyrics_gap_loader.dart';
import '../../widgets/lyrics_line.dart';
import '../../widgets/lyrics_resume_button.dart';

/// Left pane. Content only — the shell owns the backdrop, header, pill and
/// transport dock. Do not add a Scaffold, AppBar or background here.
class LyricsPane extends ConsumerStatefulWidget {
  final Song song;
  final Color accent;
  final ValueListenable<bool> paneVisible;

  const LyricsPane({
    super.key,
    required this.song,
    required this.accent,
    required this.paneVisible,
  });

  @override
  ConsumerState<LyricsPane> createState() => _LyricsPaneState();

  /// Where to put the lyrics viewport on [attempt] while line [index] is still
  /// being waited on.
  ///
  /// A lazy list does not lay a line out until it is near the viewport, so a
  /// far-off active line has no measured offset. The base term places the line
  /// near the anchor on the assumption that every line is [estimatedLineHeight]
  /// tall; the retry term walks the viewport down past that, so a line that is
  /// taller than the estimate (subtext translations, wrapped lines) still comes
  /// into build range instead of the caller re-requesting the same fallen-short
  /// offset forever. The result is clamped to the scroll range.
  @visibleForTesting
  static double scrollAttemptOffset({
    required int index,
    required int attempt,
    required double actionStripHeight,
    required double estimatedLineHeight,
    required double activeLineAnchor,
    required double retryViewportStep,
    required double viewport,
    required double minExtent,
    required double maxExtent,
  }) {
    final estimate = actionStripHeight +
        index * estimatedLineHeight -
        viewport * activeLineAnchor;
    return (estimate + viewport * retryViewportStep * attempt)
        .clamp(minExtent, maxExtent);
  }

  /// A simulated line renders karaoke only when the toggle is on; a true
  /// network line always renders. Centralises the distinction so the setting
  /// can never hide genuine word-sync.
  @visibleForTesting
  static RichLyricLine? effectiveWordLine(
    RichLyricLine? line,
    bool simulateEnabled,
  ) {
    if (line == null || line.words.isEmpty) return null;
    if (!line.isSimulated) return line;
    return simulateEnabled ? line : null;
  }

  /// True word-sync is present when any line carries real (non-simulated)
  /// word timings.
  @visibleForTesting
  static bool hasTrueWordSync(Iterable<RichLyricLine?> lines) {
    return lines.any(
      (line) => line != null && line.words.isNotEmpty && !line.isSimulated,
    );
  }

  @visibleForTesting
  static String normalizeLyricText(String value) {
    final lower = value.replaceAll('’', "'").replaceAll('‘', "'").toLowerCase();
    final cleaned = lower.replaceAll(
      RegExp(r'[^\p{L}\p{N}\s]', unicode: true),
      '',
    );
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Normalised equality or containment. Short fragments (< 3 chars) must
  /// match exactly so single characters cannot align unrelated lines.
  @visibleForTesting
  static bool lyricTextsMatch(String a, String b) {
    final normA = normalizeLyricText(a);
    final normB = normalizeLyricText(b);
    if (normA.isEmpty || normB.isEmpty) return normA == normB;
    if (normA == normB) return true;
    if (normA.contains(normB) || normB.contains(normA)) return true;

    // Check core text without parenthetical ad-libs
    final coreA = normalizeLyricText(a.replaceAll(RegExp(r'\([^)]*\)'), ' '));
    final coreB = normalizeLyricText(b.replaceAll(RegExp(r'\([^)]*\)'), ' '));
    if (coreA.isNotEmpty && coreB.isNotEmpty) {
      if (coreA == coreB) return true;
      if (coreA.length >= 3 && coreB.length >= 3) {
        if (coreA.contains(coreB) || coreB.contains(coreA)) return true;
      }
    }

    if (normA.length < 3 || normB.length < 3) return false;
    return false;
  }

  static String _cleanWord(String text) {
    final clean = text
        .replaceAll('’', '')
        .replaceAll('‘', '')
        .replaceAll("'", '')
        .toLowerCase();
    return clean.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
  }

  static List<String> _wordsOf(String text) {
    final clean = text
        .replaceAll('’', '')
        .replaceAll('‘', '')
        .replaceAll("'", '')
        .toLowerCase();
    final withSpaces =
        clean.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    return withSpaces.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  /// Aligns network rich lines to local rows. Supports 1-to-many line splitting,
  /// many-to-1 combining, and word-level slicing so split lines receive their
  /// exact word timings rather than being locked or marked null.
  @visibleForTesting
  static List<RichLyricLine?> alignRichLyrics(
    List<LyricLine> local,
    RichLyrics rich,
  ) {
    final richLines = rich.lines
        .where(
          (line) =>
              line.text.trim().isNotEmpty && !containsMusicalSymbol(line.text),
        )
        .toList();

    if (richLines.isEmpty) {
      return List<RichLyricLine?>.filled(local.length, null);
    }

    final cursors = richLines.map((l) => _RichCursor(l)).toList();
    final aligned = <RichLyricLine?>[];
    var rIdx = 0;

    for (var localIdx = 0; localIdx < local.length; localIdx++) {
      final localLine = local[localIdx];
      if (!localLine.isSynced) {
        aligned.add(null);
        continue;
      }

      final targetWords = _wordsOf(localLine.text);
      if (targetWords.isEmpty) {
        aligned.add(null);
        continue;
      }

      List<RichLyricWord>? matchedWords;
      RichLyricLine? exactLine;
      var found = false;

      final searchLimit =
          (rIdx + 4 < cursors.length) ? rIdx + 4 : cursors.length;
      final searchStart =
          (rIdx > 0 && cursors[rIdx - 1].remainingWords.isNotEmpty)
              ? rIdx - 1
              : rIdx;

      for (var searchR = searchStart; searchR < searchLimit; searchR++) {
        final rc = cursors[searchR];
        final remWords = rc.remainingWords;
        if (remWords.isEmpty) continue;

        final remNorms = remWords.map((w) => _cleanWord(w.text)).toList();

        var overlap = 0;
        var targetPtr = 0;
        var remPtr = 0;
        while (targetPtr < targetWords.length && remPtr < remNorms.length) {
          final tw = targetWords[targetPtr];
          final rw = remNorms[remPtr];
          if (tw == rw ||
              (tw.length >= 3 && (tw.contains(rw) || rw.contains(tw)))) {
            overlap++;
            targetPtr++;
            remPtr++;
          } else {
            // Look ahead 1 word in either stream to skip minor transcription variants
            if (remPtr + 1 < remNorms.length &&
                (targetWords[targetPtr] == remNorms[remPtr + 1] ||
                    (targetWords[targetPtr].length >= 3 &&
                        (targetWords[targetPtr]
                                .contains(remNorms[remPtr + 1]) ||
                            remNorms[remPtr + 1]
                                .contains(targetWords[targetPtr]))))) {
              remPtr++;
            } else if (targetPtr + 1 < targetWords.length &&
                (targetWords[targetPtr + 1] == remNorms[remPtr] ||
                    (targetWords[targetPtr + 1].length >= 3 &&
                        (targetWords[targetPtr + 1]
                                .contains(remNorms[remPtr]) ||
                            remNorms[remPtr]
                                .contains(targetWords[targetPtr + 1]))))) {
              targetPtr++;
            } else {
              targetPtr++;
              remPtr++;
            }
          }
        }

        final isSignificant = overlap >= 2 ||
            overlap == targetWords.length ||
            (targetWords.isNotEmpty && overlap / targetWords.length >= 0.4);

        if (overlap > 0 && isSignificant) {
          final assigned = remWords.sublist(0, remPtr);
          rc.cursor += remPtr;
          matchedWords = List.of(assigned);

          // Check if remaining target words continue into next rich line
          final remTarget = targetWords.sublist(
            targetPtr < targetWords.length ? targetPtr : targetWords.length,
          );
          if (remTarget.isNotEmpty && searchR + 1 < cursors.length) {
            final nextRc = cursors[searchR + 1];
            final nextRem = nextRc.remainingWords;
            final nextNorms = nextRem.map((w) => _cleanWord(w.text)).toList();
            var nextMatch = 0;
            while (
                nextMatch < remTarget.length && nextMatch < nextNorms.length) {
              final tw = remTarget[nextMatch];
              final nn = nextNorms[nextMatch];
              if (tw == nn ||
                  (tw.length >= 3 && (tw.contains(nn) || nn.contains(tw)))) {
                nextMatch++;
              } else {
                break;
              }
            }
            if (nextMatch > 0) {
              matchedWords.addAll(nextRem.sublist(0, nextMatch));
              nextRc.cursor += nextMatch;
            }
          }

          if (remPtr == rc.line.words.length &&
              matchedWords.length == rc.line.words.length &&
              lyricTextsMatch(rc.line.text, localLine.text)) {
            exactLine = rc.line;
          } else if (rc.remainingWords.isNotEmpty) {
            // If the next local line doesn't match the remaining words,
            // this line was a 1-to-1 match with transcription differences.
            var nextLineMatchesRemaining = false;
            if (localIdx + 1 < local.length) {
              final nextLocalWords = _wordsOf(local[localIdx + 1].text);
              if (nextLocalWords.isNotEmpty) {
                final remRemainingNorms =
                    rc.remainingWords.map((w) => _cleanWord(w.text)).toList();
                var checkMatch = 0;
                while (checkMatch < nextLocalWords.length &&
                    checkMatch < remRemainingNorms.length) {
                  final tw = nextLocalWords[checkMatch];
                  final rw = remRemainingNorms[checkMatch];
                  if (tw == rw ||
                      (tw.length >= 3 &&
                          (tw.contains(rw) || rw.contains(tw)))) {
                    checkMatch++;
                  } else {
                    break;
                  }
                }
                if (checkMatch > 0) {
                  nextLineMatchesRemaining = true;
                }
              }
            }

            if (!nextLineMatchesRemaining) {
              matchedWords.addAll(rc.remainingWords);
              rc.cursor = rc.line.words.length;
            }
          }

          rIdx = searchR;
          if (rc.remainingWords.isEmpty) {
            rIdx = searchR + 1;
          }
          found = true;
          break;
        }
      }

      if (!found) {
        final fbLimit = (rIdx + 5 < cursors.length) ? rIdx + 5 : cursors.length;
        final fbStart = (rIdx >= 2) ? rIdx - 2 : 0;
        for (var searchR = fbStart; searchR < fbLimit; searchR++) {
          final rc = cursors[searchR];
          if (rc.cursor > 0) continue;
          final delta = (rc.line.start - localLine.time).abs();
          final textMatch = lyricTextsMatch(rc.line.text, localLine.text);

          if (textMatch && delta <= const Duration(seconds: 4)) {
            exactLine = rc.line;
            matchedWords = rc.line.words;
            rc.cursor = rc.line.words.length;
            rIdx = searchR + 1;
            found = true;
            break;
          }
        }
      }

      if (exactLine != null) {
        aligned.add(exactLine);
      } else if (matchedWords != null && matchedWords.isNotEmpty) {
        aligned.add(RichLyricLine(
          start: matchedWords.first.start,
          end: matchedWords.last.end,
          text: localLine.text,
          words: matchedWords,
          isSimulated: false,
        ));
      } else {
        aligned.add(null);
      }
    }

    return aligned;
  }

  /// True lines win wherever present; simulated lines only fill gaps when the
  /// toggle is on. Wordless true rows fall through to the simulated fallback.
  @visibleForTesting
  static List<RichLyricLine?> mergeWordLines({
    required List<LyricLine> local,
    required List<RichLyricLine?> trueAligned,
    required List<RichLyricLine?> simulatedFallback,
    required bool simulateEnabled,
  }) {
    final merged = <RichLyricLine?>[];
    for (var i = 0; i < local.length; i++) {
      final trueLine = i < trueAligned.length ? trueAligned[i] : null;
      if (trueLine != null && trueLine.words.isNotEmpty) {
        merged.add(trueLine);
        continue;
      }
      if (simulateEnabled) {
        final simulated =
            i < simulatedFallback.length ? simulatedFallback[i] : null;
        merged.add(
          simulated != null && simulated.words.isNotEmpty ? simulated : null,
        );
      } else {
        merged.add(null);
      }
    }
    return merged;
  }
}

class _LyricsPaneState extends ConsumerState<LyricsPane>
    with AutomaticKeepAliveClientMixin {
  /// How far down the viewport the active line sits while auto-scrolling.
  static const double _activeLineAnchor = PlayerTokens.lyricsScrollPosRatio;

  /// Auto-scroll stays out of the way for this long after a manual scroll.
  static const Duration _manualScrollGrace = Duration(milliseconds: 2500);

  /// The gap loader only earns its place once the silence is long enough to
  /// read as a real instrumental break.
  static const Duration _gapLoaderDelay = Duration(seconds: 5);

  /// Below this the loader would barely finish appearing, so it stays away.
  static const Duration _minimumGapLoaderWindow = Duration(seconds: 3);

  /// Vertical space the find-lyrics button occupies at the top of the pane —
  /// its 48pt touch target plus the inset above it. The lyrics list pads by
  /// this much so a line never scrolls under the button.
  static const double _actionStripHeight = 48 + PlayerTokens.s1;

  /// Height assumed for a line that has not been laid out yet. Plain lines are
  /// ~68px; translated subtext or wrapped lines are taller, so alignment must
  /// not trust this estimate — see [_alignToLine].
  static const double _estimatedLineHeight = 72;

  /// How far past a fallen-short estimate each retry pushes the viewport.
  static const double _alignRetryViewportStep = 0.5;

  /// Upper bound on not-yet-built retries, so a line that keeps eluding the
  /// estimate can never keep the pane in an endless post-frame loop. The list
  /// then sits close enough that the next line change re-aligns it.
  static const int _maxAlignAttempts = 5;

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  final LyricsSession _lyricsSession = LyricsSession();
  final LrclibService _lrclibService = LrclibService();

  List<LyricLine>? _lyrics;
  List<RichLyricLine?> _wordLines = const [];
  bool _richSyncAvailable = false;
  String? _rawLyricsContent;
  List<LyricLine?>? _translatedLyrics;
  bool _translating = false;
  bool _hasCachedTranslation = false;
  bool _isSameLanguage = false;
  bool _loading = true;
  bool _hasSynced = false;
  String? _loadedFilename;

  /// The playhead is followed off a subscription rather than a `StreamBuilder`
  /// around the list.
  ///
  /// `positionStream` emits about five times a second for as long as anything is
  /// playing, and wrapping the `ListView` in it rebuilt every lyric in the song —
  /// on every screen this pane is alive behind, whether or not anything visible
  /// had changed. What the list actually depends on is the *active line*, which
  /// changes every few seconds. Splitting the two means the ticks land on three
  /// small notifiers and the list rebuilds when the singing moves on.
  final ValueNotifier<int> _activeLine = ValueNotifier(-1);
  final ValueNotifier<Duration> _playbackPosition =
      ValueNotifier(Duration.zero);

  /// Index the gap loader is inserted before, or -1 when it is hidden. Changes
  /// once per instrumental break.
  final ValueNotifier<int> _gapSlot = ValueNotifier(-1);

  /// The loader's fill. This is the one thing here that genuinely wants every
  /// tick, so it is scoped to the loader widget alone.
  final ValueNotifier<double> _gapProgress = ValueNotifier(0);

  /// True when manual scroll paused autoscroll, revealing the resume pill.
  final ValueNotifier<bool> _autoscrollPaused = ValueNotifier(false);

  /// After the gap ends we keep the slot for one collapse animation so the
  /// reserved space can AnimatedSize shut instead of vanishing in a frame.
  Timer? _gapCollapseTimer;
  static const Duration _gapCollapseHold = PlayerTokens.dLyricsLoaderTransition;

  StreamSubscription<Duration>? _positionSub;
  double _lyricsTimingOffset = 0;
  Timer? _lyricsTimingSaveTimer;
  bool _timingControlVisible = false;
  DateTime? _lastManualScroll;
  bool _positionSubscriptionActive = false;

  /// Set while we drive the scroll ourselves, so our own motion is not
  /// mistaken for the user taking over.
  bool _autoScrolling = false;

  /// Bumped on every auto-scroll request so a newer active line cancels any
  /// still-pending alignment from an older one instead of two chains fighting
  /// over the scroll position.
  int _scrollRequestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onUserScroll);
    widget.paneVisible.addListener(_syncPositionSubscription);
    _syncPositionSubscription();
    _load();
  }

  @override
  void didUpdateWidget(LyricsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paneVisible != widget.paneVisible) {
      oldWidget.paneVisible.removeListener(_syncPositionSubscription);
      widget.paneVisible.addListener(_syncPositionSubscription);
      _syncPositionSubscription();
    }
    if (oldWidget.song.filename != widget.song.filename) _load();
  }

  void _syncPositionSubscription() {
    final wanted = widget.paneVisible.value;
    if (wanted == _positionSubscriptionActive) return;
    _positionSubscriptionActive = wanted;

    if (!wanted) {
      _positionSub?.cancel();
      _positionSub = null;
      return;
    }

    _positionSub = ref
        .read(audioPlayerManagerProvider)
        .player
        .positionStream
        .listen(_onPosition);
    _onPosition(ref.read(audioPlayerManagerProvider).player.position);
  }

  @override
  void dispose() {
    _gapCollapseTimer?.cancel();
    _lyricsTimingSaveTimer?.cancel();
    widget.paneVisible.removeListener(_syncPositionSubscription);
    _positionSub?.cancel();
    _scrollController.removeListener(_onUserScroll);
    _scrollController.dispose();
    _activeLine.dispose();
    _playbackPosition.dispose();
    _gapSlot.dispose();
    _gapProgress.dispose();
    _autoscrollPaused.dispose();
    super.dispose();
  }

  /// Turns a playhead tick into the three things the pane actually renders from.
  /// Runs off the widget tree entirely: nothing here rebuilds unless one of the
  /// values changed.
  void _onPosition(Duration position) {
    final offset = _lyricsTimingOffset;
    final adjustedPosition = position -
        Duration(
          microseconds: (offset * Duration.microsecondsPerSecond).round(),
        );
    _playbackPosition.value = adjustedPosition;
    final lyrics = _lyrics;
    if (lyrics == null || lyrics.isEmpty || !_hasSynced) return;

    final active = _activeIndexFor(lyrics, adjustedPosition);
    if (active != _activeLine.value) {
      _activeLine.value = active;
      if (active >= 0) _maybeAutoScroll(active);
    }

    final gap = computeLyricsGapLoaderState(
      lyrics: lyrics,
      position: adjustedPosition,
      delay: _gapLoaderDelay,
      minimumWindow: _minimumGapLoaderWindow,
    );

    if (gap.shouldShow) {
      _gapCollapseTimer?.cancel();
      _gapCollapseTimer = null;
      _gapSlot.value = gap.insertBeforeLyricIndex;
      _gapProgress.value = gap.progress;
    } else if (_gapSlot.value >= 0 && _gapCollapseTimer == null) {
      // Drive the loader's own exit to completion, then clear the slot so
      // AnimatedSize can collapse the row height.
      _gapProgress.value = 1;
      _gapCollapseTimer = Timer(_gapCollapseHold, () {
        if (!mounted) return;
        _gapSlot.value = -1;
        _gapProgress.value = 0;
        _gapCollapseTimer = null;
      });
    }
  }

  void _onUserScroll() {
    // Only a user drag should suppress auto-scroll; our own motion must not.
    if (_autoScrolling || !_scrollController.hasClients) return;
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      DisplayRefreshService.instance.boost120();
      _lastManualScroll = DateTime.now();
      if (!_autoscrollPaused.value) {
        _autoscrollPaused.value = true;
      }
    }
  }

  void _resumeAutoscroll() {
    _lastManualScroll = null;
    _autoscrollPaused.value = false;
    final active = _activeLine.value;
    if (active >= 0) {
      _maybeAutoScroll(active);
    }
  }

  Future<void> _load() async {
    final filename = widget.song.filename;
    _gapCollapseTimer?.cancel();
    _gapCollapseTimer = null;
    setState(() {
      _loading = true;
      _lyrics = null;
      _wordLines = const [];
      _richSyncAvailable = false;
      _hasSynced = false;
      _loadedFilename = filename;
      _lineKeys.clear();
    });
    _activeLine.value = -1;
    _gapSlot.value = -1;
    _gapProgress.value = 0;
    _autoscrollPaused.value = false;
    _lyricsTimingSaveTimer?.cancel();
    _lyricsTimingOffset =
        await DatabaseService.instance.getLyricsTimingOffset(filename);
    if (!mounted || _loadedFilename != filename) return;

    // The repository caches to disk, so re-entering the pane is cheap.
    final content = await ref.read(songRepositoryProvider).getLyrics(
          widget.song,
        );

    if (!mounted || _loadedFilename != filename) return;

    final rawParsed = (content == null || content.trim().isEmpty)
        ? const <LyricLine>[]
        : LyricLine.parse(content);
    final parsed = filterMusicalSymbolLines(rawParsed);

    final settings = ref.read(settingsProvider);
    final List<RichLyricLine?> generatedWordLines;
    if (settings.lyricsSimulatedRichSyncEnabled) {
      final generatedWords = RichLyrics.fromLyricLines(
        parsed,
        songDuration: widget.song.duration,
        song: widget.song,
      );
      generatedWordLines = generatedWords.lines;
    } else {
      generatedWordLines = const [];
    }

    setState(() {
      _lyrics = parsed;
      _wordLines = generatedWordLines;
      _richSyncAvailable = false;
      _rawLyricsContent = content;
      _translatedLyrics = null;
      _hasCachedTranslation = false;
      _isSameLanguage = false;
      _translating = false;
      _hasSynced = parsed.any((l) => l.isSynced);
      _loading = false;
    });

    _lyricsSession.load(
      filename: filename,
      content: content,
      duration: widget.song.duration,
      song: widget.song,
      parsedLyrics: parsed,
    );

    unawaited(_loadRichSync(filename, parsed));

    if (parsed.isNotEmpty) {
      final settings = ref.read(settingsProvider);
      final cached = await DatabaseService.instance.getTranslatedLyrics(
        filename,
        settings.lyricsTargetLanguage,
        sourceContent: content,
      );

      if (!mounted || _loadedFilename != filename) return;

      if (cached == '[SAME_LANG]' &&
          LingvaTranslateService.lyricsNeedTranslation(
            content ?? '',
            settings.lyricsTargetLanguage,
          )) {
        await DatabaseService.instance.deleteTranslatedLyrics(
          filename,
          settings.lyricsTargetLanguage,
        );
        if (!mounted || _loadedFilename != filename) return;
        if (settings.lyricsAutoTranslate) {
          unawaited(
            _performTranslation(settings.lyricsTargetLanguage, silent: true),
          );
        }
      } else if (cached == '[SAME_LANG]') {
        setState(() {
          _translatedLyrics = null;
          _hasCachedTranslation = false;
          _isSameLanguage = true;
        });
      } else if (cached != null &&
          cached.trim().isNotEmpty &&
          cached.trim() != content?.trim()) {
        setState(() {
          _translatedLyrics = LyricLine.alignTranslation(
            parsed,
            LyricLine.parse(cached),
          );
          _hasCachedTranslation = true;
          _isSameLanguage = false;
        });
      } else {
        if (cached != null && cached.trim() == content?.trim()) {
          await DatabaseService.instance
              .deleteTranslatedLyrics(filename, settings.lyricsTargetLanguage);
          // Stale entry that duplicates the source blocks the translation UI
          // from rebuilding through the revision notifier.
          if (!mounted) return;
          ref.read(translationRevisionProvider.notifier).bump();
        }
        if (settings.lyricsAutoTranslate &&
            content != null &&
            content.trim().isNotEmpty) {
          _performTranslation(settings.lyricsTargetLanguage, silent: true);
        } else {
          // No cache and not auto-translating — ensure the button is visible
          // until an API round-trip proves the lyrics are already in target.
          if (mounted && _loadedFilename == filename) {
            setState(() {
              _isSameLanguage = false;
            });
          }
        }
      }
    }

    if (!mounted) return;
    // Land on the right line straight away rather than waiting for the next
    // playhead tick.
    _onPosition(ref.read(audioPlayerManagerProvider).player.position);
  }

  Future<void> _loadRichSync(String filename, List<LyricLine> local) async {
    final rich = await _lrclibService.getRichSync(widget.song);
    if (!mounted || _loadedFilename != filename || rich == null) return;

    if (local.isEmpty) {
      final filteredRich = rich.lines
          .where((line) =>
              line.text.trim().isNotEmpty && !containsMusicalSymbol(line.text))
          .toList();
      if (filteredRich.isEmpty) return;
      final onlineLines = filteredRich
          .map((line) => LyricLine(
                time: line.start,
                text: line.text,
                isSynced: true,
              ))
          .toList();
      final hasTrue = LyricsPane.hasTrueWordSync(filteredRich);
      final List<RichLyricLine?> wordLines;
      if (hasTrue) {
        wordLines = filteredRich;
      } else if (ref.read(settingsProvider).lyricsSimulatedRichSyncEnabled) {
        wordLines = RichLyrics.fromLyricLines(
          onlineLines,
          songDuration: widget.song.duration,
          song: widget.song,
        ).lines;
      } else {
        wordLines = filteredRich;
      }
      setState(() {
        _lyrics = onlineLines;
        _wordLines = wordLines;
        _richSyncAvailable = hasTrue;
        _hasSynced = true;
        _loading = false;
      });
      _onPosition(ref.read(audioPlayerManagerProvider).player.position);
      return;
    }

    final aligned = LyricsPane.alignRichLyrics(local, rich);
    if (aligned.whereType<RichLyricLine>().isEmpty) return;
    final merged = LyricsPane.mergeWordLines(
      local: local,
      trueAligned: aligned,
      simulatedFallback: _wordLines,
      simulateEnabled:
          ref.read(settingsProvider).lyricsSimulatedRichSyncEnabled,
    );
    // A line-only payload or a full mismatch must not wipe the simulated
    // first paint.
    if (!LyricsPane.hasTrueWordSync(merged)) return;

    setState(() {
      _wordLines = merged;
      _richSyncAvailable = true;
    });

    _onPosition(ref.read(audioPlayerManagerProvider).player.position);
  }

  /// Looks lyrics up on LRCLIB and writes the chosen result into the file.
  ///
  /// The write bumps `lyricsRevisionProvider`, which is what reloads this pane —
  /// no explicit reload here, so applying from anywhere else refreshes it too.
  Future<void> _findLyricsOnline() async {
    final chosen = await showLyricsSearchSheet(context, song: widget.song);
    if (chosen == null || !mounted) return;

    try {
      await ref.read(songsProvider.notifier).updateLyrics(widget.song, chosen);
      if (mounted) appSnack(context, 'Lyrics saved', tone: AppTone.success);
    } catch (e) {
      if (mounted) {
        appSnack(context, 'Could not save lyrics: $e', tone: AppTone.danger);
      }
    }
  }

  Future<void> _openTranslationSheet() async {
    final filename = widget.song.filename;
    final config = await showLyricsTranslationSheet(
      context,
      currentSongTitle: widget.song.title,
      hasCachedTranslation: _hasCachedTranslation,
    );

    if (config == null || !mounted || _loadedFilename != filename) return;

    if (config.clearCache) {
      await DatabaseService.instance.deleteTranslatedLyrics(filename);
      if (!mounted || _loadedFilename != filename) return;
      setState(() {
        _translatedLyrics = null;
        _hasCachedTranslation = false;
        _isSameLanguage = false;
      });
      if (!mounted) return;
      ref.read(translationRevisionProvider.notifier).bump();
      if (mounted) {
        appSnack(context, 'Cached translation cleared', tone: AppTone.info);
      }
      return;
    }

    if (config.translateNow) {
      await _performTranslation(config.targetLanguage);
    } else {
      // Language/mode changed without explicit translate — refresh cached
      // translation for the new target so subtext/replace switches instantly.
      await _reloadTranslation();
    }
  }

  Future<void> _reloadTranslation() async {
    final filename = widget.song.filename;
    final content = _rawLyricsContent;
    if (content == null || content.trim().isEmpty || _lyrics == null) return;
    if (!mounted) return;
    final targetLang = ref.read(settingsProvider).lyricsTargetLanguage;
    final cached = await DatabaseService.instance.getTranslatedLyrics(
      filename,
      targetLang,
      sourceContent: content,
    );
    if (!mounted || _loadedFilename != filename) return;
    if (cached == '[SAME_LANG]') {
      if (!LingvaTranslateService.lyricsNeedTranslation(content, targetLang)) {
        setState(() {
          _translatedLyrics = null;
          _hasCachedTranslation = false;
          _isSameLanguage = true;
        });
        return;
      }
      await DatabaseService.instance.deleteTranslatedLyrics(
        filename,
        targetLang,
      );
    }
    if (cached == null ||
        cached.trim().isEmpty ||
        cached.trim() == content.trim()) {
      if (cached != null && cached.trim() == content.trim()) {
        await DatabaseService.instance
            .deleteTranslatedLyrics(filename, targetLang);
        if (!mounted) return;
        ref.read(translationRevisionProvider.notifier).bump();
      }
      if (!mounted) return;
      setState(() {
        _translatedLyrics = null;
        _hasCachedTranslation = false;
        _isSameLanguage = false;
      });
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      if (settings.lyricsAutoTranslate) {
        _performTranslation(targetLang, silent: true);
      }
      return;
    }
    setState(() {
      _translatedLyrics = LyricLine.alignTranslation(
        _lyrics ?? const <LyricLine>[],
        LyricLine.parse(cached),
      );
      _hasCachedTranslation = true;
      _isSameLanguage = false;
    });
  }

  Future<void> _performTranslation(String targetLang,
      {bool silent = false}) async {
    final filename = widget.song.filename;
    final content = _rawLyricsContent;
    if (content == null || content.trim().isEmpty) return;

    final cached = await DatabaseService.instance.getTranslatedLyrics(
      filename,
      targetLang,
      sourceContent: content,
    );
    if (!mounted || _loadedFilename != filename) return;

    if (cached == '[SAME_LANG]') {
      if (!LingvaTranslateService.lyricsNeedTranslation(content, targetLang)) {
        if (!mounted) return;
        setState(() {
          _translatedLyrics = null;
          _hasCachedTranslation = false;
          _isSameLanguage = true;
        });
        return;
      }
      await DatabaseService.instance.deleteTranslatedLyrics(
        filename,
        targetLang,
      );
    }

    if (cached != null &&
        cached.trim().isNotEmpty &&
        cached.trim() != content.trim()) {
      if (!mounted) return;
      setState(() {
        _translatedLyrics = LyricLine.alignTranslation(
          _lyrics ?? const <LyricLine>[],
          LyricLine.parse(cached),
        );
        _hasCachedTranslation = true;
        _isSameLanguage = false;
      });
      return;
    }

    setState(() {
      _translating = true;
    });

    try {
      // Deep module: per-line cap (3s) so fallback does not stall.
      final result = await _lyricsSession.translate(
        filename: filename,
        targetLang: targetLang,
        content: content,
        lyrics: _lyrics,
        perLineCap: const Duration(seconds: 3),
      );
      if (!mounted || _loadedFilename != filename) return;

      if (result.isSameLanguage) {
        if (!silent) {
          appSnack(context, 'Lyrics are already in target language',
              tone: AppTone.info);
        }
        setState(() {
          _translatedLyrics = null;
          _hasCachedTranslation = false;
          _isSameLanguage = true;
        });
        if (!mounted) return;
        ref.read(translationRevisionProvider.notifier).bump();
      } else if (result.lines != null) {
        setState(() {
          _translatedLyrics = result.lines;
          _hasCachedTranslation = result.isCached || true;
          _isSameLanguage = false;
        });
        if (!mounted) return;
        ref.read(translationRevisionProvider.notifier).bump();
        if (!silent) {
          appSnack(context, 'Lyrics translated', tone: AppTone.success);
        }
      } else {
        if (!silent) {
          appSnack(context, 'Could not translate lyrics', tone: AppTone.danger);
        }
      }
    } catch (e) {
      if (mounted) {
        final lang = targetLang;
        appSnack(
          context,
          'Translation failed: $e',
          tone: AppTone.danger,
          actionLabel: 'Retry',
          onAction: () => _performTranslation(lang),
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _translating = false;
        });
      }
    }
  }

  int _activeIndexFor(List<LyricLine> lyrics, Duration position) {
    var active = -1;
    for (var i = 0; i < lyrics.length; i++) {
      if (!lyrics[i].isSynced) continue;
      if (lyrics[i].time <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }

  void _openTimingOffset() {
    setState(() => _timingControlVisible = !_timingControlVisible);
  }

  void _setLyricsTimingOffset(double value) {
    if (!mounted) return;
    setState(() {
      _lyricsTimingOffset = value.clamp(-60.0, 60.0);
    });
    _onPosition(ref.read(audioPlayerManagerProvider).player.position);
    _lyricsTimingSaveTimer?.cancel();
    _lyricsTimingSaveTimer = Timer(const Duration(seconds: 2), () {
      DatabaseService.instance.setLyricsTimingOffset(
        widget.song.filename,
        _lyricsTimingOffset,
      );
    });
  }

  String _formatTimingOffset(double value) => value.toStringAsFixed(1);

  void _seekToLyric(Duration lyricTime) {
    final offset = Duration(
      microseconds:
          (_lyricsTimingOffset * Duration.microsecondsPerSecond).round(),
    );
    ref.read(audioPlayerManagerProvider).player.seek(lyricTime + offset);
  }

  void _maybeAutoScroll(int index) {
    final since = _lastManualScroll;
    if (since != null) {
      if (DateTime.now().difference(since) < _manualScrollGrace) {
        return;
      }
      _lastManualScroll = null;
      _autoscrollPaused.value = false;
    }

    final requestId = ++_scrollRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _alignToLine(index, requestId, attempt: 0);
    });
  }

  /// Scrolls the active line to the anchor.
  ///
  /// Lines further off-screen are not laid out yet by the lazy [ListView], so
  /// their [GlobalKey] has no context. In that case the line's offset is only
  /// known approximately: [LyricsLine] is ~54px but subtext translations and
  /// wrapped lines are taller, so a fixed estimate always runs short of the
  /// real position. Each retry therefore pushes the viewport further down
  /// rather than re-requesting the same spot (which would stall forever), and
  /// the attempt budget bounds the whole thing. Once the line is actually
  /// built, [RenderAbstractViewport.getOffsetToReveal] pins it exactly.
  Future<void> _alignToLine(
    int index,
    int requestId, {
    required int attempt,
  }) async {
    if (!mounted ||
        !_scrollController.hasClients ||
        requestId != _scrollRequestId) {
      return;
    }

    final ctx = _lineKeys[index]?.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);

    if (box == null || viewport == null) {
      if (attempt >= _maxAlignAttempts) return;
      final pos = _scrollController.position;
      final target = LyricsPane.scrollAttemptOffset(
        index: index,
        attempt: attempt,
        actionStripHeight: _actionStripHeight,
        estimatedLineHeight: _estimatedLineHeight,
        activeLineAnchor: _activeLineAnchor,
        retryViewportStep: _alignRetryViewportStep,
        viewport: pos.viewportDimension,
        minExtent: pos.minScrollExtent,
        maxExtent: pos.maxScrollExtent,
      );
      if ((target - pos.pixels).abs() >= 1) pos.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _alignToLine(index, requestId, attempt: attempt + 1);
      });
      return;
    }

    // Deliberately not Scrollable.ensureVisible: it walks *every* enclosing
    // scrollable, so from inside the shell's PageView it would drag the user
    // back to this pane whenever a line changed while they were on another.
    // RenderAbstractViewport.maybeOf stops at our own ListView.
    final position = _scrollController.position;
    final target = viewport
        .getOffsetToReveal(box, _activeLineAnchor)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((target - position.pixels).abs() < 1) return;

    _autoScrolling = true;
    try {
      await _scrollController.animateTo(
        target,
        duration: PlayerTokens.dLyricsScroll,
        curve: PlayerTokens.cLyricsScroll,
      );
    } finally {
      _autoScrolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Lyrics live in the audio file, not in provider state, so a write
    // elsewhere is invisible from here. The revision counter is the signal.
    ref.listen(lyricsRevisionProvider, (_, __) => _load());
    ref.listen(translationRevisionProvider, (_, __) => _reloadTranslation());
    ref.listen(
      settingsProvider.select((s) => s.lyricsTargetLanguage),
      (_, __) => _reloadTranslation(),
    );

    ref.listen(
      settingsProvider.select((s) => s.lyricsSimulatedRichSyncEnabled),
      (_, enabled) {
        // Disabling needs no state change: the build filters simulated lines
        // out while true lines keep rendering. Enabling fills only the gaps
        // so true word-sync is never replaced by estimation.
        if (!enabled) return;
        final lyrics = _lyrics;
        if (lyrics == null || lyrics.isEmpty) return;
        var needsFill = false;
        for (var i = 0; i < lyrics.length; i++) {
          if (!lyrics[i].isSynced) continue;
          final current = i < _wordLines.length ? _wordLines[i] : null;
          if (current == null || current.words.isEmpty) {
            needsFill = true;
            break;
          }
        }
        if (!needsFill) return;
        final generated = RichLyrics.fromLyricLines(
          lyrics,
          songDuration: widget.song.duration,
          song: widget.song,
        );
        setState(() {
          final merged = <RichLyricLine?>[];
          for (var i = 0; i < lyrics.length; i++) {
            final current = i < _wordLines.length ? _wordLines[i] : null;
            if (current != null &&
                current.words.isNotEmpty &&
                !current.isSimulated) {
              merged.add(current);
              continue;
            }
            final simulated =
                i < generated.lines.length ? generated.lines[i] : null;
            merged.add(
              simulated != null && simulated.words.isNotEmpty
                  ? simulated
                  : current,
            );
          }
          _wordLines = merged;
        });
      },
    );

    final hasContent =
        _rawLyricsContent != null && _rawLyricsContent!.trim().isNotEmpty;
    // Show the button whenever we have lyrics, except when an API round-trip
    // proved the whole file is already in the target language (SAME_LANG).
    // For mixed-language lyrics we keep the button and splice per-line.
    final showTranslateButton =
        _hasCachedTranslation || (hasContent && !_isSameLanguage);

    return Stack(
      children: [
        Positioned.fill(child: _buildContent(context)),
        // Kept inside the pane rather than in the shell header: the shell owns
        // the chrome, and this action belongs to the lyrics view alone. The
        // list reserves [_actionStripHeight] at the top so no lyric ever passes
        // underneath it.
        Positioned(
          top: PlayerTokens.s1,
          right: PlayerTokens.s3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_richSyncAvailable)
                Padding(
                  padding: const EdgeInsets.only(right: PlayerTokens.s1),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.16),
                      borderRadius: PlayerTokens.brPill,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PlayerTokens.s2,
                        vertical: PlayerTokens.s1,
                      ),
                      child: Text(
                        'WORD SYNC',
                        style: PlayerTokens.meta(context).copyWith(
                          color: widget.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showTranslateButton)
                IconButton(
                  icon: _translating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _hasCachedTranslation
                              ? Icons.g_translate_rounded
                              : Icons.translate_rounded,
                        ),
                  color: _hasCachedTranslation
                      ? widget.accent
                      : Colors.white.withValues(alpha: PlayerTokens.aSecondary),
                  tooltip: 'Translate lyrics',
                  onPressed: _translating ? null : _openTranslationSheet,
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _timingControlVisible
                          ? Icons.close_rounded
                          : Icons.tune_rounded,
                    ),
                    color: _lyricsTimingOffset == 0
                        ? Colors.white
                            .withValues(alpha: PlayerTokens.aSecondary)
                        : widget.accent,
                    tooltip: _timingControlVisible
                        ? 'Hide lyric timing'
                        : 'Adjust lyric timing',
                    onPressed: _openTimingOffset,
                  ),
                  AnimatedSize(
                    duration: PlayerTokens.dFast,
                    curve: PlayerTokens.cStandard,
                    child: _timingControlVisible
                        ? Container(
                            width: 190,
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                              horizontal: PlayerTokens.s2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.accent.withValues(alpha: 0.14),
                              borderRadius: PlayerTokens.brPill,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: widget.accent,
                                      thumbColor: widget.accent,
                                      trackHeight: 3,
                                    ),
                                    child: Slider(
                                      value: _lyricsTimingOffset,
                                      min: -60,
                                      max: 60,
                                      divisions: 1200,
                                      label: _formatTimingOffset(
                                        _lyricsTimingOffset,
                                      ),
                                      onChanged: _setLyricsTimingOffset,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_lyricsTimingOffset >= 0 ? '+' : ''}${_lyricsTimingOffset.toStringAsFixed(1)}',
                                  style: PlayerTokens.meta(context).copyWith(
                                    color: widget.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.travel_explore_rounded),
                color: Colors.white.withValues(alpha: PlayerTokens.aSecondary),
                tooltip: 'Find lyrics online',
                onPressed: _findLyricsOnline,
              ),
            ],
          ),
        ),
        Positioned(
          bottom: PlayerTokens.s4,
          left: 0,
          right: 0,
          child: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: _autoscrollPaused,
              builder: (context, paused, _) => LyricsResumeButton(
                visible: paused && _hasSynced,
                accent: widget.accent,
                onTap: _resumeAutoscroll,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    final lyrics = _lyrics ?? const <LyricLine>[];
    if (lyrics.isEmpty) return _buildEmptyState(context);

    final settings = ref.watch(settingsProvider);
    final blurEnabled = settings.lyricsBlurOverlayEnabled;
    final simulateEnabled = settings.lyricsSimulatedRichSyncEnabled;
    final hasSynced = _hasSynced;

    // Rebuilds when the singing moves on or a gap opens — not on every tick of
    // the playhead.
    return ListenableBuilder(
      listenable: Listenable.merge([_activeLine, _gapSlot]),
      builder: (context, _) {
        final active = _activeLine.value;
        final gapSlot = _gapSlot.value;

        return ListView.builder(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          // Top padding is deliberately small: the first lines belong near the
          // top of the pane, not floating mid-screen. It only clears the
          // find-lyrics button. The tall bottom padding is what lets the last
          // lines still scroll up to the anchor.
          padding: EdgeInsets.only(
            top: _actionStripHeight,
            bottom: MediaQuery.of(context).size.height * 0.22,
          ),
          itemCount: lyrics.length,
          itemBuilder: (context, index) {
            final line = lyrics[index];
            final key = _lineKeys.putIfAbsent(index, () => GlobalKey());

            String? lineTranslation;
            if (_translatedLyrics != null &&
                index < _translatedLyrics!.length) {
              final translated = _translatedLyrics![index];
              // Lines the service left untouched (already in the target
              // language) carry their original text as "translation" — do not
              // duplicate it as subtext underneath itself.
              if (translated != null &&
                  translated.text.trim().isNotEmpty &&
                  translated.text.trim() != line.text.trim()) {
                lineTranslation = translated.text;
              }
            }

            final wordLine = LyricsPane.effectiveWordLine(
              index < _wordLines.length ? _wordLines[index] : null,
              simulateEnabled,
            );
            final lineContent = LyricsLine(
              text: line.text,
              translatedText: lineTranslation,
              translationMode: settings.lyricsTranslationMode,
              isActive: index == active,
              isPlayed: active >= 0 && index <= active,
              hasTime: line.isSynced,
              blurSigma: _blurFor(
                index: index,
                active: active,
                enabled: blurEnabled && hasSynced,
              ),
              activeColor: widget.accent,
              glowIntensity: index == active ? 1.0 : 0.0,
              playbackPosition: _playbackPosition.value,
              wordLine: wordLine,
              onTap: () => _seekToLyric(line.time),
            );

            final lyricWidget = KeyedSubtree(
              key: key,
              child: index == active &&
                      wordLine != null &&
                      wordLine.words.isNotEmpty
                  ? ValueListenableBuilder<Duration>(
                      valueListenable: _playbackPosition,
                      builder: (context, position, _) => LyricsLine(
                        text: line.text,
                        translatedText: lineTranslation,
                        translationMode: settings.lyricsTranslationMode,
                        isActive: true,
                        isPlayed: true,
                        hasTime: line.isSynced,
                        blurSigma: 0,
                        activeColor: widget.accent,
                        glowIntensity: 1.0,
                        playbackPosition: position,
                        wordLine: wordLine,
                        onTap: () => _seekToLyric(line.time),
                      ),
                    )
                  : lineContent,
            );

            // AnimatedSize on every row so opening/closing a gap grows and
            // shrinks the reserved space instead of popping the list.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: PlayerTokens.dLyricsLoaderTransition,
                  curve: PlayerTokens.cLyricsLoader,
                  alignment: Alignment.topCenter,
                  child: gapSlot == index
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PlayerTokens.s5,
                            vertical: PlayerTokens.s3,
                          ),
                          // The only thing in the pane that follows the
                          // playhead continuously, and it rebuilds nothing
                          // but itself.
                          child: ValueListenableBuilder<double>(
                            valueListenable: _gapProgress,
                            builder: (context, progress, _) => LyricsGapLoader(
                              progress: progress,
                              accent: widget.accent,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                lyricWidget,
              ],
            );
          },
        );
      },
    );
  }

  /// Unfocused lines blur out with distance from the active line, so the eye
  /// lands on the line being sung.
  double _blurFor({
    required int index,
    required int active,
    required bool enabled,
  }) {
    if (!enabled || active < 0 || index == active) return 0;
    final distance = (index - active).abs();
    return (distance * 0.9).clamp(0.0, 3.2);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PlayerTokens.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: PlayerTokens.aTertiary),
            ),
            const SizedBox(height: PlayerTokens.s3),
            Text('No lyrics', style: PlayerTokens.paneTitle(context)),
            const SizedBox(height: PlayerTokens.s1),
            Text(
              'This track has no embedded lyrics.',
              textAlign: TextAlign.center,
              style: PlayerTokens.trackSubtitle(context),
            ),
            const SizedBox(height: PlayerTokens.s5),
            FilledButton.icon(
              onPressed: _findLyricsOnline,
              icon: const Icon(Icons.travel_explore_rounded, size: 18),
              label: const Text('Find lyrics online'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: PlayerTokens.onAccent(widget.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsTimingOffsetSheet extends StatefulWidget {
  final double initialValue;
  final Color accent;
  final ValueChanged<double> onChanged;

  const _LyricsTimingOffsetSheet({
    required this.initialValue,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<_LyricsTimingOffsetSheet> createState() =>
      _LyricsTimingOffsetSheetState();
}

class _LyricsTimingOffsetSheetState extends State<_LyricsTimingOffsetSheet> {
  late double _value = widget.initialValue;

  String get _label {
    if (_value.abs() < 0.05) return 'In sync';
    final sign = _value > 0 ? '+' : '−';
    return '$sign${_value.abs().toStringAsFixed(1)} s';
  }

  void _set(double value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PlayerTokens.s5,
          PlayerTokens.s2,
          PlayerTokens.s5,
          PlayerTokens.s5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Lyric timing', style: PlayerTokens.paneTitle(context)),
            const SizedBox(height: PlayerTokens.s1),
            Text(
              'Move the words forward or backward to match the music.',
              style: PlayerTokens.trackSubtitle(context),
            ),
            const SizedBox(height: PlayerTokens.s4),
            Center(
              child: Text(
                _label,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: widget.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: widget.accent,
                thumbColor: widget.accent,
                overlayColor: widget.accent.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: _value,
                min: -60,
                max: 60,
                divisions: 1200,
                label: _label,
                onChanged: _set,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Earlier', style: PlayerTokens.meta(context)),
                Text('Later', style: PlayerTokens.meta(context)),
              ],
            ),
            const SizedBox(height: PlayerTokens.s3),
            FilledButton.tonalIcon(
              onPressed: () => _set(0),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset timing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RichCursor {
  final RichLyricLine line;
  int cursor = 0;
  _RichCursor(this.line);

  List<RichLyricWord> get remainingWords =>
      cursor < line.words.length ? line.words.sublist(cursor) : const [];
}
