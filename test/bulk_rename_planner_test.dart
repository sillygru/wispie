import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/bulk_rename_planner.dart';
import 'package:wispie/models/song.dart';

/// The planner is pure, so the whole rename policy can be pinned without a
/// library, a database or a filesystem. What matters is that the user's chosen
/// format turns into the name they expect, that a name no filesystem would
/// accept never reaches disk, and — the part that actually destroys data —
/// that two songs can never be sent at the same target.
void main() {
  Song song(
    String filename, {
    String title = 'Only You',
    String artist = 'The Weeknd',
    String album = 'After Hours',
    double? year,
    String folder = '/music',
  }) =>
      Song(
        title: title,
        artist: artist,
        album: album,
        filename: filename,
        url: '$folder/$filename',
        songDateEpochSec: year,
      );

  List<BulkRenamePlan> planFor(
    List<Song> songs,
    List<BulkRenameSegment> segments,
  ) =>
      BulkRenamePlanner.plan(songs: songs, segments: segments);

  group('presets', () {
    test('each built-in format renders the name it advertises', () {
      expect(
        [
          for (final preset in BulkRenameSegment.presets)
            planFor([song('01 - Only You.mp3')], preset).single.newFilename,
        ],
        [
          'Only You.mp3',
          'The Weeknd - Only You.mp3',
          'The Weeknd - After Hours - Only You.mp3',
        ],
      );
    });
  });

  group('sanitize', () {
    // One function, one table. Each row is a name a real library contains that
    // some filesystem will refuse, or mangle, as written.
    test('a name that no filesystem accepts is made acceptable', () {
      const cases = <(String, String)>[
        // Separators become spaces rather than vanishing, so "AC/DC" still
        // reads as two words instead of "ACDC".
        ('AC/DC', 'AC DC'),
        (r'a\b', 'a b'),
        (r'Who? What: *Here* <Yes> |No|', 'Who What Here Yes No'),
        ('a\x00b\x1Fc', 'a b c'),
        // A field that rendered empty leaves its separators behind.
        ('The Weeknd -  - Only You', 'The Weeknd - Only You'),
        ('- Only You', 'Only You'),
        // Windows silently drops trailing dots and spaces.
        ('Only You. ', 'Only You'),
        // A dash inside a title is not a separator.
        ('AC - DC', 'AC - DC'),
      ];

      for (final (raw, expected) in cases) {
        expect(BulkRenamePlanner.sanitize(raw), expected, reason: raw);
      }
    });
  });

  group('empty fields', () {
    test('an empty album does not leave a double separator behind', () {
      final plans = planFor(
        [song('01.mp3', album: '')],
        BulkRenameSegment.presets[2],
      );
      expect(plans.single.newFilename, 'The Weeknd - Only You.mp3');
    });

    test('a song with nothing left to say is skipped, not renamed to nothing',
        () {
      final plans = planFor(
        [song('01.mp3', title: '', artist: '', album: '')],
        BulkRenameSegment.presets[2],
      );
      expect(plans.single.willRename, isFalse);
      expect(plans.single.skipReason, isNotNull);
    });
  });

  group('tokens', () {
    test('number counts the batch position', () {
      final plans = planFor(
        [song('a.mp3'), song('b.mp3'), song('c.mp3')],
        [BulkRenameSegment.token(BulkRenameToken.track)],
      );
      expect(plans.map((p) => p.newFilename), ['1.mp3', '2.mp3', '3.mp3']);
    });

    test('current name keeps the existing filename stem', () {
      final plans = planFor(
        [song('01 - Only You.mp3')],
        const [
          BulkRenameSegment.literal('[Live] '),
          BulkRenameSegment.token(BulkRenameToken.stem),
        ],
      );
      expect(plans.single.newFilename, '[Live] 01 - Only You.mp3');
    });

    test('year reads the release date', () {
      // 2020-06-01T00:00:00Z in epoch seconds.
      final plans = planFor(
        [song('a.mp3', year: 1590969600)],
        [BulkRenameSegment.token(BulkRenameToken.year)],
      );
      expect(plans.single.newFilename, '2020.mp3');
    });

    test('a song with no release date contributes no year', () {
      final plans = planFor(
        [song('a.mp3')],
        [
          BulkRenameSegment.token(BulkRenameToken.artist),
          BulkRenameSegment.literal(' - '),
          BulkRenameSegment.token(BulkRenameToken.year),
          BulkRenameSegment.literal(' - '),
          BulkRenameSegment.token(BulkRenameToken.title),
        ],
      );
      expect(plans.single.newFilename, 'The Weeknd - Only You.mp3');
    });
  });

  group('collisions', () {
    test('two songs that would land on one name: the second is skipped', () {
      final plans = planFor(
        [
          song('track.mp3', title: 'T'),
          song('other.mp3', title: 'T', folder: '/music'),
        ],
        BulkRenameSegment.presets[0],
      );

      expect(plans[0].willRename, isTrue);
      expect(plans[1].willRename, isFalse);
      expect(plans[1].skipReason, contains('track.mp3'));
    });

    test('the same title in different folders is not a collision', () {
      final plans = planFor(
        [
          song('a.mp3', title: 'T', folder: '/music/one'),
          song('b.mp3', title: 'T', folder: '/music/two'),
        ],
        BulkRenameSegment.presets[0],
      );

      expect(plans.every((p) => p.willRename), isTrue);
      expect(plans[0].newUrl, '/music/one/T.mp3');
      expect(plans[1].newUrl, '/music/two/T.mp3');
    });

    test('a target that differs only by case is still a collision', () {
      final plans = planFor(
        [
          song('a.mp3', title: 'Song', folder: '/music'),
          song('b.mp3', title: 'song', folder: '/music'),
        ],
        BulkRenameSegment.presets[0],
      );

      expect(plans[0].willRename, isTrue);
      expect(plans[1].willRename, isFalse);
    });

    test(
        'a song already named correctly is skipped rather than renamed to itself',
        () {
      final plans = planFor(
        [song('Only You.mp3')],
        BulkRenameSegment.presets[0],
      );

      expect(plans.single.willRename, isFalse);
      expect(plans.single.skipReason, 'Already named this');
    });

    test('the extension survives every format', () {
      final plans = planFor(
        [song('a.flac')],
        BulkRenameSegment.presets[1],
      );
      expect(plans.single.newFilename, 'The Weeknd - Only You.flac');
    });
  });

  group('applyRenames', () {
    // The library is keyed by a song's current name; the replacement map is
    // keyed by the name it had before. Getting those two the wrong way round
    // empties the library instead of renaming it, so it is worth pinning.
    test('a renamed song is replaced, not dropped', () {
      final library = [
        song('Only You.mp3'),
        song('Untouched.mp3'),
      ];
      final renamed = song('The Weeknd - Only You.mp3');

      final result = BulkRenamePlanner.applyRenames(library, {
        'Only You.mp3': renamed,
      });

      expect(result.length, 2);
      expect(
        result.map((s) => s.filename),
        ['The Weeknd - Only You.mp3', 'Untouched.mp3'],
      );
    });
  });

  group('excludeExistingTargets', () {
    test('a name already on disk is not overwritten', () async {
      final plans = planFor(
        [song('a.mp3')],
        BulkRenameSegment.presets[0],
      );

      final checked = await BulkRenamePlanner.excludeExistingTargets(
        plans,
        exists: (path) async => path == '/music/Only You.mp3',
      );

      expect(checked.single.willRename, isFalse);
      expect(
          checked.single.skipReason, 'A file with that name is already here');
    });

    test(
        'a name held by another selected song is refused even though that '
        'song is also being renamed', () async {
      // Swapping two names would mean overwriting one file with the other
      // depending on the order the batch happens to run in.
      final plans = planFor(
        [
          song('a.mp3', title: 'A'),
          song('b.mp3', title: 'B'),
        ],
        [
          BulkRenameSegment.token(BulkRenameToken.title),
          BulkRenameSegment.token(BulkRenameToken.title),
        ],
      );
      final targets = {for (final p in plans) p.song.url: p.newUrl};

      final checked = await BulkRenamePlanner.excludeExistingTargets(
        plans,
        exists: (path) async => targets.containsValue(path),
      );

      // Each song wants to become the other one's file. Both are refused.
      expect(checked.every((p) => !p.willRename), isTrue);
    });

    test('a free name passes through', () async {
      final plans = planFor(
        [song('a.mp3')],
        BulkRenameSegment.presets[0],
      );

      final checked = await BulkRenamePlanner.excludeExistingTargets(
        plans,
        exists: (_) async => false,
      );

      expect(checked.single.willRename, isTrue);
    });

    test('already-skipped entries keep their original reason', () async {
      final plans = planFor(
        [song('Only You.mp3')],
        BulkRenameSegment.presets[0],
      );

      final checked = await BulkRenamePlanner.excludeExistingTargets(
        plans,
        exists: (_) async => true,
      );

      expect(checked.single.skipReason, 'Already named this');
    });

    /// This is the check a large library spends its time in: one filesystem call
    /// per song, and on removable storage a long time doing it. It reports
    /// progress, can be stopped, and never asks the filesystem about a name that
    /// is already spoken for.
    group('reporting and stopping', () {
      List<BulkRenamePlan> manyPlans(int count) => planFor(
            [
              for (var i = 0; i < count; i++)
                song('a$i.mp3', title: 'Title $i'),
            ],
            BulkRenameSegment.presets[0],
          );

      test('progress climbs to the number of names actually probed', () async {
        final plans = manyPlans(25);
        final steps = <(int, int)>[];

        await BulkRenamePlanner.excludeExistingTargets(
          plans,
          exists: (_) async => false,
          concurrency: 4,
          onProgress: (done, total) => steps.add((done, total)),
        );

        expect(steps.first, (0, 25));
        expect(steps.last, (25, 25));
        expect(
          steps.map((s) => s.$1),
          orderedEquals(List.of(steps.map((s) => s.$1))..sort()),
          reason: 'monotonic, so the bar never jumps backwards',
        );
        expect(steps.every((s) => s.$2 == 25), isTrue,
            reason: 'the denominator must not shift under the bar');
      });

      test('names the planner already refused are never looked up', () async {
        // Otherwise the cost is paid twice over on exactly the songs that were
        // already known to be problems.
        final plans = planFor(
          [
            song('Only You.mp3'),
            song('b.mp3', title: 'Bee'),
          ],
          BulkRenameSegment.presets[0],
        );
        expect(plans.first.skipReason, 'Already named this');
        expect(plans.last.willRename, isTrue);
        final probed = <String>[];

        await BulkRenamePlanner.excludeExistingTargets(
          plans,
          exists: (path) async {
            probed.add(path);
            return false;
          },
        );

        expect(probed, ['/music/Bee.mp3'],
            reason: 'only the name that still needed checking was looked up');
      });

      test('stopping leaves unchecked names alone rather than taken', () async {
        // A name nobody looked at has not been shown to be occupied. Treating it
        // as taken would report skips the app never found, and treating it as
        // free is safe because the confirm step checks again before writing.
        final plans = manyPlans(40);
        var seen = 0;
        var stop = false;

        final checked = await BulkRenamePlanner.excludeExistingTargets(
          plans,
          exists: (_) async {
            seen++;
            if (seen >= 8) stop = true;
            return true;
          },
          concurrency: 2,
          isCancelled: () => stop,
        );

        expect(seen, lessThan(40), reason: 'it should have stopped early');
        expect(checked, hasLength(40), reason: 'the list is still in full');
        expect(checked.take(8).where((p) => !p.willRename), isNotEmpty);
        expect(
          checked.skip(8).every((p) => p.willRename),
          isTrue,
          reason: 'an unchecked name must not be reported as a collision',
        );
      });

      test('no more than the stated number of lookups are in flight', () async {
        final plans = manyPlans(50);
        var inFlight = 0;
        var peak = 0;

        await BulkRenamePlanner.excludeExistingTargets(
          plans,
          exists: (_) async {
            inFlight++;
            peak = peak > inFlight ? peak : inFlight;
            // Yield so overlapping calls would actually be observed as such.
            await Future<void>.delayed(Duration.zero);
            inFlight--;
            return false;
          },
          concurrency: 3,
        );

        expect(peak, lessThanOrEqualTo(3));
        expect(peak, greaterThan(1),
            reason: 'otherwise the bound is not buying any wall clock back');
      });
    });
  });
}
