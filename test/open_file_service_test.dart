import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/models/song.dart';
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

    test('parses byte size when present and sane', () {
      final files = parseOpenedAudioFiles([
        {
          'path': '/cache/open-with/song.mp3',
          'displayName': 'song.mp3',
          'sizeBytes': 12345,
        },
        {
          'path': '/cache/open-with/other.mp3',
          'displayName': 'other.mp3',
          'sizeBytes': -7,
        },
        {
          'path': '/cache/open-with/third.mp3',
          'displayName': 'third.mp3',
          'sizeBytes': 'huge',
        },
      ]);
      expect(files, hasLength(3));
      expect(files[0].sizeBytes, 12345);
      expect(files[1].sizeBytes, isNull);
      expect(files[2].sizeBytes, isNull);
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

  group('matchLibrarySong', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('wispie_open_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Song librarySong(String name) {
      final file = File('${tempDir.path}/$name')
        ..writeAsBytesSync([1, 2, 3, 4]);
      return Song(
        title: name,
        artist: 'Artist',
        album: 'Album',
        filename: name,
        url: file.path,
      );
    }

    test('matches same name and size', () {
      final song = librarySong('track.mp3');
      final size = File(song.url).lengthSync();
      final file = OpenedAudioFile(
        path: '/cache/open-with/track.mp3',
        displayName: 'track.mp3',
        sizeBytes: size,
      );
      expect(matchLibrarySong(file, [song]), song);
    });

    test('matches by name when no size is known', () {
      final song = librarySong('track.mp3');
      const file = OpenedAudioFile(
        path: '/cache/open-with/track.mp3',
        displayName: 'TRACK.MP3',
      );
      expect(matchLibrarySong(file, [song]), song);
    });

    test('size mismatch falls back to transient', () {
      final song = librarySong('track.mp3');
      const file = OpenedAudioFile(
        path: '/cache/open-with/track.mp3',
        displayName: 'track.mp3',
        sizeBytes: 999999,
      );
      expect(matchLibrarySong(file, [song]), isNull);
    });

    test('missing library file falls back to transient', () {
      final song = librarySong('track.mp3');
      File(song.url).deleteSync();
      const file = OpenedAudioFile(
        path: '/cache/open-with/track.mp3',
        displayName: 'track.mp3',
      );
      expect(matchLibrarySong(file, [song]), isNull);
    });

    test('remote streams never match', () {
      final song = librarySong('live.mp3');
      const file = OpenedAudioFile(
        remoteUrl: 'https://example.com/live.mp3',
        displayName: 'live.mp3',
      );
      expect(matchLibrarySong(file, [song]), isNull);
    });

    test('unknown names do not match', () {
      final song = librarySong('other.mp3');
      const file = OpenedAudioFile(
        path: '/cache/open-with/track.mp3',
        displayName: 'track.mp3',
      );
      expect(matchLibrarySong(file, [song]), isNull);
    });
  });
}
