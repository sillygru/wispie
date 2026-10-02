import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/song_replacement_rules.dart';
import 'package:wispie/models/song.dart';

Song _song({String filename = 'Only You.mp3', String? url}) {
  return Song(
    title: 'Only You',
    artist: 'The Weeknd',
    album: 'After Hours',
    filename: filename,
    url: url ?? '/Users/me/Music/Only You/$filename',
  );
}

ReplacementCheck _check({
  required Song original,
  required String sourcePath,
  bool isSupportedMediaFile = true,
  List<String> trackedFolders = const ['/Users/me/Music'],
  List<String> libraryFilenames = const ['Only You.mp3'],
  bool destinationExists = false,
}) {
  return SongReplacementRules.check(
    original: original,
    sourcePath: sourcePath,
    isSupportedMediaFile: isSupportedMediaFile,
    trackedFolders: trackedFolders,
    libraryFilenames: libraryFilenames,
    destinationExists: destinationExists,
  );
}

void main() {
  group('SongReplacementRules.destinationFor', () {
    test('keeps the original directory and takes the replacement name', () {
      expect(
        SongReplacementRules.destinationFor(
          _song(url: '/Users/me/Music/Only You/Only You.mp3'),
          '/Users/me/Downloads/Only You.flac',
        ),
        '/Users/me/Music/Only You/Only You.flac',
      );
    });
  });

  group('SongReplacementRules.check accepts', () {
    test('a differently-named file from outside the library', () {
      final result = _check(
        original: _song(),
        sourcePath: '/Users/me/Downloads/Only You.flac',
      );

      expect(result, isA<ReplacementAccepted>());
      final accepted = result as ReplacementAccepted;
      expect(accepted.newFilename, 'Only You.flac');
      expect(
          accepted.destinationPath, '/Users/me/Music/Only You/Only You.flac');
      expect(accepted.sourcePath, '/Users/me/Downloads/Only You.flac');
    });

    test('an extension-only change, which is the whole point of the feature',
        () {
      final result = _check(
        original: _song(),
        sourcePath: '/tmp/Only You.flac',
      );

      expect((result as ReplacementAccepted).newFilename, 'Only You.flac');
    });

    test('a file in a folder that merely shares a name prefix', () {
      // "/Users/me/Music Backup" must not count as inside "/Users/me/Music".
      final result = _check(
        original: _song(),
        sourcePath: '/Users/me/Music Backup/Only You.flac',
      );

      expect(result, isA<ReplacementAccepted>());
    });
  });

  group('SongReplacementRules.check rejects', () {
    test('an empty selection', () {
      final result = _check(original: _song(), sourcePath: '   ');

      expect((result as ReplacementRejected).reason, contains('No file'));
    });

    test('a format the library cannot read', () {
      final result = _check(
        original: _song(),
        sourcePath: '/tmp/Only You.txt',
        isSupportedMediaFile: false,
      );

      expect((result as ReplacementRejected).reason,
          contains('not an audio or video format'));
    });

    test('the identical filename', () {
      final result = _check(
        original: _song(),
        sourcePath: '/tmp/Only You.mp3',
      );

      expect((result as ReplacementRejected).reason,
          contains('different filename'));
    });

    test('the identical filename in a different case', () {
      // The filesystems most users run on are case-insensitive, so these are
      // one file and replacing one with the other would change nothing.
      final result = _check(
        original: _song(filename: 'Only You.mp3'),
        sourcePath: '/tmp/ONLY YOU.MP3',
      );

      expect((result as ReplacementRejected).reason,
          contains('different filename'));
    });

    test('a file already inside a tracked library folder', () {
      final result = _check(
        original: _song(),
        sourcePath: '/Users/me/Music/Only You.flac',
      );

      expect((result as ReplacementRejected).reason,
          contains('inside one of your library folders'));
    });

    test('a file nested deep inside a tracked library folder', () {
      final result = _check(
        original: _song(),
        sourcePath: '/Users/me/Music/Unsorted/Inbox/Only You.flac',
      );

      expect((result as ReplacementRejected).reason,
          contains('inside one of your library folders'));
    });

    test('a file that would land on an existing file', () {
      final result = _check(
        original: _song(),
        sourcePath: '/tmp/Only You.flac',
        destinationExists: true,
      );

      expect((result as ReplacementRejected).reason,
          contains('already sits next to the original'));
    });

    test('a filename the library already tracks under other casing', () {
      // Without this the migration would fuse two unrelated songs together.
      final result = _check(
        original: _song(),
        sourcePath: '/tmp/only you.flac',
        libraryFilenames: const ['Only You.mp3', 'only you.flac'],
      );

      expect((result as ReplacementRejected).reason,
          contains('already has a song named'));
    });
  });

  group('OriginalFileDisposition', () {
    test('offers exactly delete and hide', () {
      expect(OriginalFileDisposition.values,
          [OriginalFileDisposition.delete, OriginalFileDisposition.hide]);
    });
  });
}
