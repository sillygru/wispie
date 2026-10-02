import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/cover_path.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/services/library_logic.dart';

Song _song({
  required String name,
  String? cover,
  int playCount = 0,
}) {
  return Song(
    title: name,
    artist: 'Artist',
    album: 'Album',
    filename: '/music/$name.mp3',
    url: '/music/$name.mp3',
    coverUrl: cover,
    playCount: playCount,
  );
}

void main() {
  group('CoverPath', () {
    test('accepts local forms and rejects remote ones', () {
      expect(CoverPath.isLocal('/covers/a.jpg'), isTrue);
      expect(CoverPath.isLocal('C:\\covers\\a.jpg'), isTrue);
      expect(CoverPath.isLocal('file:///covers/a.jpg'), isTrue);
      expect(CoverPath.isLocal('content://media/1'), isTrue);
      expect(CoverPath.isLocal('  /covers/a.jpg  '), isTrue);

      expect(CoverPath.isLocal(null), isFalse);
      expect(CoverPath.isLocal(''), isFalse);
      expect(CoverPath.isLocal('   '), isFalse);
      expect(CoverPath.isLocal('https://cdn.test/a.jpg'), isFalse);
    });

    test('toLocalPath strips file:// but has no path for content://', () {
      expect(
        CoverPath.toLocalPath('file:///music/a%20b/cover.jpg'),
        '/music/a b/cover.jpg',
      );
      expect(CoverPath.toLocalPath('/covers/a.jpg'), '/covers/a.jpg');
      expect(CoverPath.toLocalPath('content://media/1'), isNull);
      expect(CoverPath.toLocalPath('https://cdn.test/a.jpg'), isNull);
      expect(CoverPath.toLocalPath(null), isNull);
    });

    test('normalize matches the URI scheme case-insensitively', () {
      expect(CoverPath.normalize('FILE:///covers/a.jpg'), '/covers/a.jpg');
      expect(
          CoverPath.normalize('file:///covers/a%20b.jpg'), '/covers/a b.jpg');
      expect(CoverPath.normalize('/covers/a.jpg'), '/covers/a.jpg');
      expect(CoverPath.normalize('content://media/1'), 'content://media/1');
    });
  });

  group('LibraryLogic.pickCoverSong', () {
    test('picks the most-listened song', () {
      final songs = [
        _song(name: 'Alpha', cover: '/covers/a.jpg', playCount: 3),
        _song(name: 'Bravo', cover: '/covers/b.jpg', playCount: 41),
        _song(name: 'Charlie', cover: '/covers/c.jpg', playCount: 7),
      ];

      expect(LibraryLogic.pickCoverSong(songs)?.title, 'Bravo');
    });

    test('falls back to title order when nothing has been played', () {
      final songs = [
        _song(name: 'Zulu', cover: '/covers/z.jpg'),
        _song(name: 'Alpha', cover: '/covers/a.jpg'),
        _song(name: 'Mike', cover: '/covers/m.jpg'),
      ];

      expect(LibraryLogic.pickCoverSong(songs)?.title, 'Alpha');
    });

    test('prefers live play counts over the snapshot', () {
      final songs = [
        _song(name: 'Alpha', cover: '/covers/a.jpg', playCount: 99),
        _song(name: 'Bravo', cover: '/covers/b.jpg', playCount: 1),
      ];

      final picked = LibraryLogic.pickCoverSong(
        songs,
        playCounts: {'/music/Alpha.mp3': 0, '/music/Bravo.mp3': 500},
      );

      expect(picked?.title, 'Bravo');
    });

    test('skips songs whose cover is missing or not local', () {
      final songs = [
        _song(name: 'Alpha', cover: null, playCount: 100),
        _song(name: 'Bravo', cover: 'https://cdn.test/b.jpg', playCount: 90),
        _song(name: 'Charlie', cover: '/covers/c.jpg', playCount: 1),
      ];

      expect(LibraryLogic.pickCoverSong(songs)?.title, 'Charlie');
    });

    test('unwraps a file:// cover instead of skipping it', () {
      final picked = LibraryLogic.pickCoverSong([
        _song(name: 'Alpha', cover: 'file:///covers/a.jpg', playCount: 2),
      ]);

      expect(picked?.coverUrl, 'file:///covers/a.jpg');
    });

    test('returns null when no song has a usable cover', () {
      expect(LibraryLogic.pickCoverSong(const []), isNull);
      expect(
        LibraryLogic.pickCoverSong([
          _song(name: 'Alpha', playCount: 5),
          _song(name: 'Bravo', cover: 'https://cdn.test/b.jpg', playCount: 9),
        ]),
        isNull,
      );
    });
  });
}
