import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/models/rich_lyrics.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/presentation/screens/player/lyrics_pane.dart';

void main() {
  test('real word sync survives timestamp drift from local lyrics', () {
    const local = [
      LyricLine(
        time: Duration(seconds: 1),
        text: 'Привет мир',
        isSynced: true,
      ),
    ];
    const rich = RichLyrics(
      lines: [
        RichLyricLine(
          start: Duration(seconds: 8),
          end: Duration(seconds: 10),
          text: 'Привет мир',
          words: [
            RichLyricWord(
              start: Duration(seconds: 8),
              end: Duration(seconds: 9),
              text: 'Привет',
            ),
            RichLyricWord(
              start: Duration(seconds: 9),
              end: Duration(seconds: 10),
              text: 'мир',
            ),
          ],
        ),
      ],
    );

    final aligned = LyricsPane.alignRichLyrics(local, rich);

    expect(aligned.single, same(rich.lines.single));
  });

  test('disabling simulated sync does not hide real word sync', () {
    const real = RichLyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'Real',
      words: [
        RichLyricWord(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'Real',
        ),
      ],
    );
    const simulated = RichLyricLine(
      start: Duration.zero,
      end: Duration(seconds: 2),
      text: 'Generated',
      isSimulated: true,
      words: [
        RichLyricWord(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'Generated',
        ),
      ],
    );

    expect(LyricsPane.effectiveWordLine(real, false), same(real));
    expect(LyricsPane.effectiveWordLine(simulated, false), isNull);
  });
}
