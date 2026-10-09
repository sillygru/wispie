import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/models/rich_lyrics.dart';
import '../tokens/player_tokens.dart';

/// Lyric ink is tinted from the cover accent so the text belongs to the
/// cover-derived theme: lit text is the accent lifted toward white for
/// legibility, resting text a pale wash of it.
Color lyricsLitInk(Color accent) => Color.lerp(accent, Colors.white, 0.35)!;
Color lyricsDimInk(Color accent) => Color.lerp(Colors.white, accent, 0.5)!;

/// Vocal voice alignment for lead, backing, or multi-singer lines.
enum LyricsVoiceAlignment {
  lead,
  backing,
  duet,
}

/// Renders one lyric line with dynamic scale, vocal alignment, and smooth
/// word-level karaoke highlighting and wobble physics.
class LyricsLine extends StatelessWidget {
  final String text;
  final String? translatedText;
  final String? translationMode;
  final bool isActive;
  final bool isPlayed;
  final bool hasTime;
  final Color activeColor;
  final double glowIntensity;
  final Duration playbackPosition;
  final RichLyricLine? wordLine;
  final VoidCallback? onTap;

  /// Signed line distance from the active line; drives the opacity falloff.
  final int distance;

  /// Sidebar sizing: smaller type and tighter rows.
  final bool compact;

  double get _fontSize => compact
      ? PlayerTokens.lyricsFontSizeCompact
      : PlayerTokens.lyricsFontSize;

  const LyricsLine({
    super.key,
    required this.text,
    this.translatedText,
    this.translationMode,
    required this.isActive,
    required this.isPlayed,
    required this.hasTime,
    required this.activeColor,
    required this.glowIntensity,
    this.playbackPosition = Duration.zero,
    this.wordLine,
    this.onTap,
    this.distance = 0,
    this.compact = false,
  });

  static LyricsVoiceAlignment detectAlignment(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return LyricsVoiceAlignment.lead;

    if (trimmed.startsWith('(Both)') ||
        trimmed.startsWith('(All)') ||
        trimmed.startsWith('[Both]') ||
        trimmed.startsWith('[All]')) {
      return LyricsVoiceAlignment.duet;
    }

    if ((trimmed.startsWith('(') && trimmed.endsWith(')')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return LyricsVoiceAlignment.backing;
    }

    return LyricsVoiceAlignment.lead;
  }

  @override
  Widget build(BuildContext context) {
    final translation = translatedText?.trim();
    final showSubtext = translationMode == 'subtext' &&
        translation != null &&
        translation.isNotEmpty;
    final isReplace = translationMode == 'replace' &&
        translation != null &&
        translation.isNotEmpty;
    final primaryText = isReplace ? translation : text;
    final double baseOpacity = isPlayed
        ? PlayerTokens.lyricsPlayedOpacity
        : PlayerTokens.lyricsInactiveOpacity;
    final double targetOpacity = isActive
        ? PlayerTokens.lyricsActiveOpacity
        : (baseOpacity -
                PlayerTokens.lyricsDistanceFalloff *
                    math.max(0, distance.abs() - 1))
            .clamp(PlayerTokens.lyricsMinOpacity, 1.0);

    final alignment = detectAlignment(primaryText);
    final textAlign = switch (alignment) {
      LyricsVoiceAlignment.lead => TextAlign.left,
      LyricsVoiceAlignment.backing => TextAlign.right,
      LyricsVoiceAlignment.duet => TextAlign.center,
    };
    final crossAxisAlignment = switch (alignment) {
      LyricsVoiceAlignment.lead => CrossAxisAlignment.start,
      LyricsVoiceAlignment.backing => CrossAxisAlignment.end,
      LyricsVoiceAlignment.duet => CrossAxisAlignment.center,
    };
    final scaleAlignment = switch (alignment) {
      LyricsVoiceAlignment.lead => Alignment.centerLeft,
      LyricsVoiceAlignment.backing => Alignment.centerRight,
      LyricsVoiceAlignment.duet => Alignment.center,
    };

    // Focus is carried by the opacity ladder alone: blurring unfocused lines
    // cost a saveLayer per line inside a scrolling list for a cue opacity
    // already gives. The opacity is tweened rather than a layer so word spans,
    // which bake it into their colours, ease along with plain text.
    // Farther lines settle a beat later, so a line change ripples outward
    // from the active line instead of every row snapping in unison.
    final Duration ripple = PlayerTokens.dLyricsLine +
        PlayerTokens.dLyricsLineRipple * math.min(distance.abs(), 6);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetOpacity),
      duration: ripple,
      curve: PlayerTokens.cLyricsLine,
      builder: (context, lineOpacity, _) => AnimatedSlide(
        offset: isActive ? const Offset(0, -0.04) : Offset.zero,
        duration: ripple,
        curve: PlayerTokens.cLyricsLine,
        child: AnimatedScale(
          scale: isActive
              ? PlayerTokens.lyricsActiveScale
              : PlayerTokens.lyricsInactiveScale,
          alignment: scaleAlignment,
          duration: ripple,
          curve: PlayerTokens.cLyricsLine,
          child: AnimatedContainer(
            duration: PlayerTokens.dLyricsLine,
            curve: PlayerTokens.cLyricsLine,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? PlayerTokens.s2 : PlayerTokens.s4,
              vertical: compact ? PlayerTokens.s1 : PlayerTokens.s3,
            ),
            child: InkWell(
              onTap: hasTime ? onTap : null,
              borderRadius: PlayerTokens.brMd,
              child: AnimatedDefaultTextStyle(
                duration: ripple,
                curve: PlayerTokens.cLyricsLine,
                style: TextStyle(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w800,
                  color: (isActive
                          ? lyricsLitInk(activeColor)
                          : lyricsDimInk(activeColor))
                      .withValues(alpha: lineOpacity),
                  height: 1.28,
                  letterSpacing: -0.4,
                  shadows: [
                    Shadow(
                      color: activeColor.withValues(
                        alpha: 0.35 * glowIntensity,
                      ),
                      blurRadius: 18 * glowIntensity,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: crossAxisAlignment,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._buildLyricLines(primaryText, lineOpacity, textAlign),
                      if (showSubtext) ...[
                        const SizedBox(height: PlayerTokens.s1),
                        Text(
                          translation,
                          textAlign: textAlign,
                          style: TextStyle(
                            fontSize:
                                _fontSize * PlayerTokens.lyricsTranslationScale,
                            fontWeight: FontWeight.w500,
                            color: isActive
                                ? activeColor.withValues(alpha: 0.88)
                                : lyricsDimInk(activeColor).withValues(
                                    alpha: isPlayed ? 0.50 : 0.30,
                                  ),
                            height: 1.22,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLyricLines(
    String primaryText,
    double lineOpacity,
    TextAlign textAlign,
  ) {
    final isDuetTag = primaryText.trim().startsWith('(Both)') ||
        primaryText.trim().startsWith('(All)') ||
        primaryText.trim().startsWith('[Both]') ||
        primaryText.trim().startsWith('[All]');

    final timedLine = wordLine;
    final translation = translatedText?.trim();
    final isReplace = translationMode == 'replace' &&
        translation != null &&
        translation.isNotEmpty;

    if (!isReplace && timedLine != null && timedLine.words.isNotEmpty) {
      if (!isDuetTag &&
          primaryText.contains('(') &&
          primaryText.contains(')')) {
        final mainWords = <RichLyricWord>[];
        final backingWords = <RichLyricWord>[];
        var inParen = false;

        for (final word in timedLine.words) {
          final hasOpen = word.text.contains('(');
          final hasClose = word.text.contains(')');

          if (hasOpen && !hasClose) {
            inParen = true;
            backingWords.add(word);
          } else if (hasClose && inParen) {
            backingWords.add(word);
            inParen = false;
          } else if (inParen || (hasOpen && hasClose)) {
            backingWords.add(word);
          } else {
            mainWords.add(word);
          }
        }

        if (mainWords.isNotEmpty && backingWords.isNotEmpty) {
          return [
            _buildWordSpans(mainWords, lineOpacity, textAlign,
                isBacking: false),
            const SizedBox(height: PlayerTokens.s1),
            _buildWordSpans(backingWords, lineOpacity * 0.88, textAlign,
                isBacking: true),
          ];
        } else if (mainWords.isEmpty && backingWords.isNotEmpty) {
          return [
            _buildWordSpans(backingWords, lineOpacity * 0.88, textAlign,
                isBacking: true),
          ];
        }
      }

      return [
        _buildWordSpans(timedLine.words, lineOpacity, textAlign,
            isBacking: false),
      ];
    }

    // Static text path
    if (!isDuetTag && primaryText.contains('(') && primaryText.contains(')')) {
      final backingMatches = RegExp(r'\([^)]+\)').allMatches(primaryText);
      if (backingMatches.isNotEmpty) {
        final backingText = backingMatches.map((m) => m.group(0)!).join(' ');
        final mainText =
            primaryText.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), ' ').trim();

        final backingStyle = TextStyle(
          fontSize: _fontSize * 0.72,
          fontWeight: FontWeight.w600,
          color:
              lyricsDimInk(activeColor).withValues(alpha: lineOpacity * 0.88),
          height: 1.25,
          letterSpacing: -0.2,
        );

        if (mainText.isNotEmpty && backingText.isNotEmpty) {
          return [
            Text(mainText, textAlign: textAlign),
            const SizedBox(height: PlayerTokens.s1),
            Text(backingText, textAlign: textAlign, style: backingStyle),
          ];
        } else if (mainText.isEmpty && backingText.isNotEmpty) {
          return [
            Text(backingText, textAlign: textAlign, style: backingStyle),
          ];
        }
      }
    }

    return [
      Text(primaryText, textAlign: textAlign),
    ];
  }

  Widget _buildWordSpans(
    List<RichLyricWord> words,
    double lineOpacity,
    TextAlign textAlign, {
    required bool isBacking,
  }) {
    final style = isBacking
        ? TextStyle(
            fontSize: _fontSize * 0.72,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.2,
            color: lyricsDimInk(activeColor).withValues(alpha: lineOpacity),
          )
        : TextStyle(
            fontSize: _fontSize,
            fontWeight: FontWeight.w800,
            height: 1.28,
            letterSpacing: -0.4,
            color: lyricsDimInk(activeColor).withValues(alpha: lineOpacity),
          );

    // Focus eases the lit layer out when the line hands off, so sung words
    // fade back into the resting ink instead of snapping off.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isActive ? 1.0 : 0.0),
      duration: isActive ? PlayerTokens.dFast : PlayerTokens.dLyricsLine,
      curve: PlayerTokens.cLyricsLine,
      builder: (context, focus, _) {
        final position = playbackPosition;
        final spans = <InlineSpan>[];

        for (var index = 0; index < words.length; index++) {
          final word = words[index];
          final wordSuffix = index < words.length - 1
              ? (word.text.endsWith('-') ? '' : ' ')
              : '';

          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _LyricWordWidget(
                word: word,
                position: position,
                activeColor: activeColor,
                lineOpacity: lineOpacity,
                focus: focus,
                wordSuffix: wordSuffix,
                textStyle: style,
              ),
            ),
          );
        }

        return Text.rich(
          TextSpan(children: spans),
          textAlign: textAlign,
        );
      },
    );
  }
}

class _LyricWordWidget extends StatelessWidget {
  final RichLyricWord word;
  final Duration position;
  final Color activeColor;
  final double lineOpacity;
  final double focus;
  final String wordSuffix;
  final TextStyle textStyle;

  const _LyricWordWidget({
    required this.word,
    required this.position,
    required this.activeColor,
    required this.lineOpacity,
    required this.focus,
    required this.wordSuffix,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final durationUs = word.duration.inMicroseconds.toDouble();

    double progress = 0.0;
    if (durationUs > 0) {
      final elapsedUs = (position - word.start).inMicroseconds.toDouble();
      progress = (elapsedUs / durationUs).clamp(0.0, 1.0);
    } else {
      progress = position >= word.start ? 1.0 : 0.0;
    }

    final displayText = '${word.text}$wordSuffix';
    final double fontSize = textStyle.fontSize ?? PlayerTokens.lyricsFontSize;

    // Unsung words in the focused line rest at a fixed dim level; the sung
    // layer is drawn at full strength rather than faded in with the line, so
    // the wipe reads as light travelling across the text, not a fade.
    final Widget base = Text(
      displayText,
      style: textStyle.copyWith(
        color: lyricsDimInk(activeColor).withValues(
          alpha:
              lerpDouble(lineOpacity, PlayerTokens.lyricsUnsungOpacity, focus),
        ),
        shadows: null,
      ),
    );
    if (focus <= 0.0 || progress <= 0.0) return base;

    if (word.duration >= PlayerTokens.dLyricsSustainThreshold &&
        word.text.trim().characters.length > 1) {
      return _buildSustained(progress, fontSize);
    }

    Widget lit = Text(
      displayText,
      style: textStyle.copyWith(
        color: lyricsLitInk(activeColor).withValues(alpha: focus),
        shadows: [
          Shadow(
            color: activeColor.withValues(alpha: 0.3 * focus),
            blurRadius: PlayerTokens.lyricsWordGlowBlur * 0.7,
          ),
        ],
      ),
    );

    if (progress < 1.0) {
      // The soft edge has a fixed pixel width and sweeps at a constant speed
      // from fully off the word to fully past it, so a long word shows a real
      // wipe instead of a whole-word fade. Only the word being sung pays for
      // the mask.
      final double feather = fontSize * PlayerTokens.lyricsWipeFeatherEm;
      lit = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final double tail = progress * (bounds.width + feather) - feather;
          return ui.Gradient.linear(
            Offset(bounds.left + tail, 0),
            Offset(bounds.left + tail + feather, 0),
            const [
              Color(0xFFFFFFFF),
              Color(0xD6FFFFFF),
              Color(0x80FFFFFF),
              Color(0x29FFFFFF),
              Color(0x00FFFFFF),
            ],
            const [0.0, 0.25, 0.5, 0.75, 1.0],
          );
        },
        child: lit,
      );
    }

    // Slow, eased float that holds until the line hands off (focus then eases
    // it back). Its length is independent of the word's, so quick words rise
    // as gently as held ones instead of stepping up.
    final double floatUs = math
        .max(
          PlayerTokens.dLyricsWordFloat.inMicroseconds,
          word.duration.inMicroseconds,
        )
        .toDouble();
    final double floatT =
        ((position - word.start).inMicroseconds / floatUs).clamp(0.0, 1.0);
    final double lift = -fontSize *
        PlayerTokens.lyricsWordWobbleShiftEm *
        Curves.easeOutCubic.transform(floatT) *
        focus;

    return Transform.translate(
      offset: Offset(0, lift),
      child: Stack(children: [base, lit]),
    );
  }

  /// Apple-style held word: letters light one after another, each swelling,
  /// rising and blooming as the note carries, then the whole word settles
  /// back together once the note is released.
  Widget _buildSustained(double progress, double fontSize) {
    final chars = word.text.characters.toList();
    final n = chars.length;
    const spread = PlayerTokens.lyricsSustainSpread;

    final sinceEndUs = (position - word.end).inMicroseconds;
    final releaseT = sinceEndUs <= 0
        ? 0.0
        : (sinceEndUs / PlayerTokens.dLyricsSustainRelease.inMicroseconds)
            .clamp(0.0, 1.0);
    final envelope = (1 - Curves.easeInOutCubic.transform(releaseT)) * focus;

    final dim = lyricsDimInk(activeColor).withValues(
      alpha: lerpDouble(lineOpacity, PlayerTokens.lyricsUnsungOpacity, focus),
    );
    final litInk = lyricsLitInk(activeColor).withValues(alpha: focus);
    final glowInk = Color.lerp(activeColor, Colors.white, 0.55)!;

    // The motion wave is several letters wide and shaped with smoothstep, so
    // neighbouring letters travel together as one swell instead of each
    // popping on its own. Colour is not per letter at all: a single feathered
    // wipe runs across the whole word on top.
    final waveWidth = math.max(spread, n * 0.45);
    final front = progress * (n + waveWidth);
    double swellAt(int i) {
      final t = ((front - i) / waveWidth).clamp(0.0, 1.0);
      return t * t * t * (t * (t * 6 - 15) + 10) * envelope;
    }

    Widget row(Color color, {required bool glow}) {
      final children = <Widget>[];
      for (var i = 0; i < n; i++) {
        final swell = swellAt(i);
        final scale = 1 + PlayerTokens.lyricsSustainScale * swell;
        children.add(
          Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.translationValues(
              0,
              -fontSize * PlayerTokens.lyricsSustainLiftEm * swell,
              0,
            )..scaleByDouble(scale, scale, 1, 1),
            child: Text(
              chars[i],
              style: textStyle.copyWith(
                color: color,
                shadows: !glow || swell <= 0.01
                    ? null
                    : [
                        Shadow(
                          color: glowInk.withValues(alpha: 0.7 * swell),
                          blurRadius:
                              PlayerTokens.lyricsSustainGlowBlur * swell,
                        ),
                      ],
              ),
            ),
          ),
        );
      }
      if (wordSuffix.isNotEmpty) {
        children.add(Text(wordSuffix, style: textStyle.copyWith(color: color)));
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: children,
      );
    }

    final base = row(dim, glow: false);
    if (progress >= 1.0) {
      return Stack(children: [base, row(litInk, glow: true)]);
    }

    // Wider than the normal wipe so the lit front reads as light spilling
    // across the held note rather than a hard edge stepping between letters.
    final feather = fontSize * PlayerTokens.lyricsWipeFeatherEm * 2.4;
    final lit = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final tail = progress * (bounds.width + feather) - feather;
        return ui.Gradient.linear(
          Offset(bounds.left + tail, 0),
          Offset(bounds.left + tail + feather, 0),
          const [
            Color(0xFFFFFFFF),
            Color(0xC0FFFFFF),
            Color(0x70FFFFFF),
            Color(0x24FFFFFF),
            Color(0x00FFFFFF),
          ],
          const [0.0, 0.3, 0.55, 0.8, 1.0],
        );
      },
      child: row(litInk, glow: true),
    );
    return Stack(children: [base, lit]);
  }
}
