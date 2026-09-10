import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/services/library_logic.dart';

Song _song(
  String filename, {
  String title = 'Title',
  String album = 'Album',
  int playCount = 0,
}) {
  return Song(
    title: title,
    artist: 'Artist',
    album: album,
    filename: filename,
    url: '/music/$filename',
    playCount: playCount,
  );
}

void main() {
  group('groupSongsByAlbum', () {
    test('groups by album and collapses blank to Unknown Album', () {
      final songs = [
        _song('a.mp3', album: 'Blue'),
        _song('b.mp3', album: 'Blue'),
        _song('c.mp3', album: ''),
        _song('d.mp3', album: '  '),
      ];

      final groups = LibraryLogic.groupSongsByAlbum(songs);

      expect(groups.keys, unorderedEquals(['Blue', 'Unknown Album']));
      expect(groups['Blue']!.length, 2);
      expect(groups['Unknown Album']!.length, 2);
    });

    test('dedupes case-insensitively keeping first-seen casing', () {
      final songs = [
        _song('a.mp3', album: 'Blue'),
        _song('b.mp3', album: 'blue'),
        _song('c.mp3', album: 'BLUE '),
      ];

      final groups = LibraryLogic.groupSongsByAlbum(songs);

      expect(groups.keys, ['Blue']);
      expect(groups['Blue']!.length, 3);
    });
  });

  group('hasMultipleAlbums', () {
    test('false for empty, single song, and single album', () {
      expect(LibraryLogic.hasMultipleAlbums([]), isFalse);
      expect(LibraryLogic.hasMultipleAlbums([_song('a.mp3')]), isFalse);
      expect(
        LibraryLogic.hasMultipleAlbums([
          _song('a.mp3', album: 'Blue'),
          _song('b.mp3', album: 'blue'),
        ]),
        isFalse,
      );
    });

    test('false when everything is Unknown Album', () {
      expect(
        LibraryLogic.hasMultipleAlbums([
          _song('a.mp3', album: ''),
          _song('b.mp3', album: '  '),
        ]),
        isFalse,
      );
    });

    test('true when two distinct albums are present', () {
      expect(
        LibraryLogic.hasMultipleAlbums([
          _song('a.mp3', album: 'Blue'),
          _song('b.mp3', album: 'Red'),
        ]),
        isTrue,
      );
    });
  });

  group('sortAlbumsByTotalPlays', () {
    test('orders by total plays descending', () {
      final groups = {
        'Small': [_song('s1.mp3', playCount: 1), _song('s2.mp3', playCount: 1)],
        'Big': [_song('b1.mp3', playCount: 10)],
        'Mid': [_song('m1.mp3', playCount: 5)],
      };

      expect(
        LibraryLogic.sortAlbumsByTotalPlays(groups),
        ['Big', 'Mid', 'Small'],
      );
    });

    test('prefers live playCounts over song snapshots', () {
      final groups = {
        'A': [_song('a.mp3', playCount: 100)],
        'B': [_song('b.mp3', playCount: 0)],
      };

      expect(
        LibraryLogic.sortAlbumsByTotalPlays(groups, playCounts: {
          'a.mp3': 0,
          'b.mp3': 50,
        }),
        ['B', 'A'],
      );
    });

    test('breaks ties by track count then name', () {
      final groups = {
        'Beta': [_song('b1.mp3', playCount: 5)],
        'Alpha': [_song('a1.mp3', playCount: 5)],
        'Many': [
          _song('m1.mp3', playCount: 2),
          _song('m2.mp3', playCount: 3),
        ],
      };

      // Many and the singles tie at 5 plays; Many wins on track count,
      // then Alpha before Beta alphabetically.
      expect(
        LibraryLogic.sortAlbumsByTotalPlays(groups),
        ['Many', 'Alpha', 'Beta'],
      );
    });
  });

  group('sortSongsByPlayCount', () {
    test('orders by plays descending with title tiebreak', () {
      final songs = [
        _song('c.mp3', title: 'Charlie', playCount: 0),
        _song('a.mp3', title: 'Alpha', playCount: 3),
        _song('b.mp3', title: 'Bravo', playCount: 10),
        _song('d.mp3', title: 'Delta', playCount: 0),
      ];

      final sorted = LibraryLogic.sortSongsByPlayCount(songs);

      expect(
        sorted.map((s) => s.filename),
        ['b.mp3', 'a.mp3', 'c.mp3', 'd.mp3'],
      );
    });

    test('prefers live playCounts over song snapshots', () {
      final songs = [
        _song('a.mp3', title: 'Alpha', playCount: 100),
        _song('b.mp3', title: 'Bravo', playCount: 0),
      ];

      final sorted = LibraryLogic.sortSongsByPlayCount(
        songs,
        playCounts: {'a.mp3': 1, 'b.mp3': 2},
      );

      expect(sorted.map((s) => s.filename), ['b.mp3', 'a.mp3']);
    });
  });
}
