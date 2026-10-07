import 'dart:math' as math;

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
            padding: const EdgeInsets.symmetric(
              horizontal: PlayerTokens.s4,
              vertical: PlayerTokens.s3,
            ),
            child: InkWell(
              onTap: hasTime ? onTap : null,
              borderRadius: PlayerTokens.brMd,
              child: AnimatedDefaultTextStyle(
                duration: ripple,
                curve: PlayerTokens.cLyricsLine,
                style: TextStyle(
                  fontSize: PlayerTokens.lyricsFontSize,
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
                            fontSize: PlayerTokens.lyricsFontSize *
                                PlayerTokens.lyricsTranslationScale,
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
          fontSize: PlayerTokens.lyricsFontSize * 0.72,
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
            fontSize: PlayerTokens.lyricsFontSize * 0.72,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.2,
            color: lyricsDimInk(activeColor).withValues(alpha: lineOpacity),
          )
        : TextStyle(
            fontSize: PlayerTokens.lyricsFontSize,
            fontWeight: FontWeight.w800,
            height: 1.28,
            letterSpacing: -0.4,
            color: lyricsDimInk(activeColor).withValues(alpha: lineOpacity),
          );

    // Focus eases the lit layer out when the line hands off, so sung words
    // fade back into the resting ink instead of snapping off.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isActive ? 1.0 : 0.0),
      duration: PlayerTokens.dLyricsLine,
      curve: PlayerTokens.cLyricsLine,
      builder: (context, focus, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: playbackPosition.inMicroseconds.toDouble()),
        duration: PlayerTokens.dLyricsWordProgress,
        curve: Curves.linear,
        builder: (context, animatedMicros, _) {
          final position = Duration(microseconds: animatedMicros.round());
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
      ),
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
    final Color activeTextColor =
        lyricsLitInk(activeColor).withValues(alpha: lineOpacity);

    final Widget base = Text(
      displayText,
      style: textStyle.copyWith(
        color: lyricsDimInk(activeColor).withValues(
          alpha: lineOpacity * (1.0 - 0.68 * focus),
        ),
        shadows: null,
      ),
    );
    if (focus <= 0.0 || progress <= 0.0) return base;

    // Glow blooms while the word is sung and decays shortly after, so the
    // light travels with the voice instead of piling up across the line.
    final double sinceEnd = (position - word.end).inMicroseconds /
        PlayerTokens.dLyricsWordGlowDecay.inMicroseconds;
    final double glow = progress < 1.0
        ? Curves.easeOut.transform(progress)
        : (1.0 - sinceEnd).clamp(0.0, 1.0);
    final TextStyle litStyle = textStyle.copyWith(
      color: activeTextColor.withValues(alpha: activeTextColor.a * focus),
      shadows: glow * focus > 0.01
          ? [
              Shadow(
                color: activeColor.withValues(alpha: 0.75 * glow * focus),
                blurRadius: PlayerTokens.lyricsWordGlowBlur * glow,
              ),
            ]
          : null,
    );

    Widget lit = Text(displayText, style: litStyle);
    if (progress < 1.0) {
      // Feathered wipe edge: one ShaderMask, and only on the word currently
      // being sung, keeps the saveLayer count at about one per frame.
      lit = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final double feather = bounds.width <= 0
              ? 0.0
              : (fontSize * 0.6 / bounds.width).clamp(0.0, 0.5);
          final double edge = progress * (1 + 2 * feather) - feather;
          return LinearGradient(
            colors: const [Colors.white, Colors.transparent],
            stops: [
              (edge - feather).clamp(0.0, 1.0),
              (edge + feather).clamp(0.0, 1.0),
            ],
          ).createShader(bounds);
        },
        child: lit,
      );
    }

    // Sung words rise and stay risen; long held words also swell gently.
    final double eased = Curves.easeOutCubic.transform(progress);
    final double lift =
        -fontSize * PlayerTokens.lyricsWordWobbleShiftEm * 1.2 * eased * focus;
    final bool isLong =
        word.duration.inMilliseconds >= PlayerTokens.lyricsLongWordThresholdMs;
    final double swell = isLong
        ? 1 + PlayerTokens.lyricsWordWobbleScale * math.sin(progress * math.pi)
        : 1.0;

    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.translationValues(0, lift, 0)
        ..scaleByDouble(swell, swell, 1, 1),
      child: Stack(children: [base, lit]),
    );
  }
}
