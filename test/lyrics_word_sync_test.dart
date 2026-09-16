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

  test('aligns 1-to-many line split without leaving sibling lines blank', () {
    const local = [
      LyricLine(
        time: Duration(seconds: 11),
        text: 'Bad, bad boy',
        isSynced: true,
      ),
      LyricLine(
        time: Duration(seconds: 12),
        text: 'Shiny toy with a price',
        isSynced: true,
      ),
    ];
    const rich = RichLyrics(
      lines: [
        RichLyricLine(
          start: Duration(milliseconds: 11511),
          end: Duration(milliseconds: 13947),
          text: 'Bad, bad boy, shiny toy with a price',
          words: [
            RichLyricWord(
              start: Duration(milliseconds: 11511),
              end: Duration(milliseconds: 11796),
              text: 'Bad,',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 11796),
              end: Duration(milliseconds: 12161),
              text: 'bad',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 12161),
              end: Duration(milliseconds: 12562),
              text: 'boy,',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 12562),
              end: Duration(milliseconds: 12878),
              text: 'shiny',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 12878),
              end: Duration(milliseconds: 13247),
              text: 'toy',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 13247),
              end: Duration(milliseconds: 13395),
              text: 'with',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 13395),
              end: Duration(milliseconds: 13566),
              text: 'a',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 13566),
              end: Duration(milliseconds: 13947),
              text: 'price',
            ),
          ],
        ),
      ],
    );

    final aligned = LyricsPane.alignRichLyrics(local, rich);

    expect(aligned, hasLength(2));
    final line1 = aligned[0];
    final line2 = aligned[1];

    expect(line1, isNotNull);
    expect(line1!.words.map((w) => w.text).toList(), ['Bad,', 'bad', 'boy,']);
    expect(line1.start, const Duration(milliseconds: 11511));
    expect(line1.end, const Duration(milliseconds: 12562));

    expect(line2, isNotNull);
    expect(
      line2!.words.map((w) => w.text).toList(),
      ['shiny', 'toy', 'with', 'a', 'price'],
    );
    expect(line2.start, const Duration(milliseconds: 12562));
    expect(line2.end, const Duration(milliseconds: 13947));
  });

  test('aligns words spanning across rich line boundaries', () {
    const local = [
      LyricLine(
        time: Duration(seconds: 28),
        text: "And it's new, the shape of your body",
        isSynced: true,
      ),
      LyricLine(
        time: Duration(seconds: 31),
        text: "It's blue, the feeling I've got",
        isSynced: true,
      ),
    ];
    const rich = RichLyrics(
      lines: [
        RichLyricLine(
          start: Duration(seconds: 28),
          end: Duration(seconds: 32),
          text: "And it's new, the shape of your body, it's blue",
          words: [
            RichLyricWord(
              start: Duration(seconds: 28),
              end: Duration(milliseconds: 28500),
              text: 'And',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 28500),
              end: Duration(seconds: 29),
              text: "it's",
            ),
            RichLyricWord(
              start: Duration(seconds: 29),
              end: Duration(milliseconds: 29500),
              text: 'new,',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 29500),
              end: Duration(seconds: 30),
              text: 'the',
            ),
            RichLyricWord(
              start: Duration(seconds: 30),
              end: Duration(milliseconds: 30300),
              text: 'shape',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 30300),
              end: Duration(milliseconds: 30500),
              text: 'of',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 30500),
              end: Duration(milliseconds: 30800),
              text: 'your',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 30800),
              end: Duration(seconds: 31),
              text: 'body,',
            ),
            RichLyricWord(
              start: Duration(seconds: 31),
              end: Duration(milliseconds: 31500),
              text: "it's",
            ),
            RichLyricWord(
              start: Duration(milliseconds: 31500),
              end: Duration(seconds: 32),
              text: 'blue',
            ),
          ],
        ),
        RichLyricLine(
          start: Duration(seconds: 32),
          end: Duration(seconds: 36),
          text: "The feeling I got, and it's, ooh, whoa-oh",
          words: [
            RichLyricWord(
              start: Duration(seconds: 32),
              end: Duration(milliseconds: 32500),
              text: 'The',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 32500),
              end: Duration(seconds: 33),
              text: 'feeling',
            ),
            RichLyricWord(
              start: Duration(seconds: 33),
              end: Duration(milliseconds: 33300),
              text: 'I',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 33300),
              end: Duration(milliseconds: 33500),
              text: 'got,',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 33500),
              end: Duration(seconds: 34),
              text: 'and',
            ),
            RichLyricWord(
              start: Duration(seconds: 34),
              end: Duration(seconds: 35),
              text: "it's,",
            ),
          ],
        ),
      ],
    );

    final aligned = LyricsPane.alignRichLyrics(local, rich);

    expect(aligned, hasLength(2));
    final line1 = aligned[0];
    final line2 = aligned[1];

    expect(line1, isNotNull);
    expect(line1!.words, hasLength(8));
    expect(line1.words.last.text, 'body,');

    expect(line2, isNotNull);
    expect(line2!.words.map((w) => w.text).toList(), [
      "it's",
      'blue',
      'The',
      'feeling',
      'I',
      'got,',
    ]);
  });

  test('tolerates parenthetical ad-libs in local lines', () {
    const local = [
      LyricLine(
        time: Duration(seconds: 50),
        text: "Sin City's cold and empty (oh)",
        isSynced: true,
      ),
    ];
    const rich = RichLyrics(
      lines: [
        RichLyricLine(
          start: Duration(seconds: 50),
          end: Duration(seconds: 53),
          text: "Sin City's cold and empty",
          words: [
            RichLyricWord(
              start: Duration(seconds: 50),
              end: Duration(milliseconds: 50500),
              text: 'Sin',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 50500),
              end: Duration(seconds: 51),
              text: "City's",
            ),
            RichLyricWord(
              start: Duration(seconds: 51),
              end: Duration(milliseconds: 51500),
              text: 'cold',
            ),
            RichLyricWord(
              start: Duration(milliseconds: 51500),
              end: Duration(seconds: 52),
              text: 'and',
            ),
            RichLyricWord(
              start: Duration(seconds: 52),
              end: Duration(seconds: 53),
              text: 'empty',
            ),
          ],
        ),
      ],
    );

    final aligned = LyricsPane.alignRichLyrics(local, rich);

    expect(aligned.single, isNotNull);
    expect(aligned.single!.words, hasLength(5));
    expect(aligned.single!.words.first.text, 'Sin');
    expect(aligned.single!.words.last.text, 'empty');
  });
}
