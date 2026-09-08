import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/services/open_file_service.dart';

void main() {
  group('parseOpenedAudioFiles', () {
    test('parses staged local files', () {
      final files = parseOpenedAudioFiles([
        {
          'path': '/cache/open-with/song.mp3',
          'displayName': 'song.mp3',
          'mimeType': 'audio/mpeg',
        },
      ]);
      expect(files, hasLength(1));
      expect(files.first.path, '/cache/open-with/song.mp3');
      expect(files.first.displayName, 'song.mp3');
      expect(files.first.isRemote, isFalse);
    });

    test('parses streamed links', () {
      final files = parseOpenedAudioFiles([
        {
          'remoteUrl': 'https://example.com/track.mp3',
          'displayName': 'track.mp3',
          'mimeType': 'audio/mpeg',
        },
      ]);
      expect(files, hasLength(1));
      expect(files.first.isRemote, isTrue);
      expect(files.first.playableUrl, 'https://example.com/track.mp3');
    });

    test('skips malformed and unsupported entries, keeps the rest', () {
      final files = parseOpenedAudioFiles([
        {'path': '/cache/a.mp3', 'displayName': 'a.mp3'},
        {'path': '/cache/b.mp3', 'displayName': ''},
        {'path': '/cache/c.txt', 'displayName': 'c.txt'},
        {'displayName': 'd.mp3'},
        'not-a-map',
        null,
      ]);
      expect(files, hasLength(1));
      expect(files.first.displayName, 'a.mp3');
    });

    test('rejects non-list payloads', () {
      expect(parseOpenedAudioFiles(null), isEmpty);
      expect(parseOpenedAudioFiles('song.mp3'), isEmpty);
      expect(parseOpenedAudioFiles({'path': 'x.mp3'}), isEmpty);
    });
  });

  group('transientSongForOpenedFile', () {
    test('falls back to filename when tags are unreadable', () {
      const file = OpenedAudioFile(
        path: '/nonexistent/open-with/mystery-track.mp3',
        displayName: 'mystery-track.mp3',
      );
      final song = transientSongForOpenedFile(file);
      expect(song.title, 'mystery-track');
      expect(song.url, '/nonexistent/open-with/mystery-track.mp3');
      expect(song.filename, startsWith('external::'));
      expect(song.hasVideo, isFalse);
    });

    test('remote files use the stream URL without touching disk', () {
      const file = OpenedAudioFile(
        remoteUrl: 'https://example.com/live.mp3',
        displayName: 'live.mp3',
      );
      final song = transientSongForOpenedFile(file);
      expect(song.title, 'live');
      expect(song.url, 'https://example.com/live.mp3');
    });
  });

  group('OpenedAudioFile.isPlayable', () {
    test('remote entries are playable without a local file', () {
      const file = OpenedAudioFile(
        remoteUrl: 'https://example.com/live.mp3',
        displayName: 'live.mp3',
      );
      expect(file.isPlayable, isTrue);
    });

    test('missing staged copies are not playable', () {
      const file = OpenedAudioFile(
        path: '/nonexistent/open-with/gone.mp3',
        displayName: 'gone.mp3',
      );
      expect(file.isPlayable, isFalse);
    });
  });
}
