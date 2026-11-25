import 'dart:convert';
import 'dart:isolate';

import '../../domain/models/lrclib_result.dart';
import '../../domain/models/rich_lyrics.dart';
import '../../models/song.dart';
import 'native_command.dart';
import 'wispie_core.dart';

typedef LibraryChanges = ({int added, int changed, int deleted});

Future<LibraryChanges?> checkRustLibraryChanges({
  required String databasePath,
  required List<String> roots,
  required List<String> excludedFolders,
  required bool includeVideos,
  required int minFileSizeBytes,
  required bool preventDuplicateTracks,
}) =>
    Isolate.run(() {
      final reply = runCoreCommand('library_changes', {
        'databasePath': databasePath,
        'roots': roots,
        'excludedFolders': excludedFolders,
        'includeVideos': includeVideos,
        'minFileSizeBytes': minFileSizeBytes,
        'preventDuplicateTracks': preventDuplicateTracks,
      });
      final changes = reply['changes'] as Map<String, dynamic>?;
      if (changes == null) return null;
      return (
        added: changes['new'] as int,
        changed: changes['changed'] as int,
        deleted: changes['deleted'] as int,
      );
    });

/// Result attached to the end of every native task.
class RustTaskDone {
  const RustTaskDone({
    this.unreadable = 0,
    this.unreachable = const [],
    this.scanned = 0,
    this.cancelled = false,
  });

  final int unreadable;
  final List<String> unreachable;
  final int scanned;
  final bool cancelled;
}

class RustTaskError {
  const RustTaskError(this.message);

  final String message;
}

/// Parameters for one native task.
class RustTaskRequest {
  const RustTaskRequest({
    required this.command,
    this.roots = const [],
    this.excludedFolders = const [],
    this.coversDir = '',
    this.includeVideos = false,
    this.minFileSizeBytes = 0,
    this.fastMode = false,
    this.existingSongs = const [],
    this.playCounts = const {},
    this.batchSize = 200,
    this.songs = const [],
    this.paths = const [],
    this.force = false,
    this.lyricsRoots = const [],
  });

  final String command;
  final List<String> roots;
  final List<String> excludedFolders;
  final String coversDir;
  final bool includeVideos;
  final int minFileSizeBytes;
  final bool fastMode;
  final List<Song> existingSongs;
  final Map<String, int> playCounts;
  final int batchSize;
  final List<Song> songs;
  final List<String> paths;
  final bool force;

  /// Extra folders searched for `.lrc`/`.ttml` sidecars.
  final List<String> lyricsRoots;

  Map<String, Object?> toJson() {
    switch (command) {
      case 'scan':
        return {
          'command': command,
          'roots': roots,
          'excludedFolders': excludedFolders,
          'coversDir': coversDir,
          'includeVideos': includeVideos,
          'minFileSizeBytes': minFileSizeBytes,
          'fastMode': fastMode,
          'existing': [for (final song in existingSongs) song.toJson()],
          'playCounts': playCounts,
          'batchSize': batchSize,
          'lyricsRoots': lyricsRoots,
        };
      case 'read_facts':
        return {'command': command, 'paths': paths};
      default:
        return {
          'command': command,
          'coversDir': coversDir,
          'force': force,
          'songs': [for (final song in songs) song.toJson()],
        };
    }
  }
}

/// A `.lrc`/`.ttml` sidecar that matches one song's filename.
class LyricsFileLink {
  const LyricsFileLink({
    required this.filename,
    required this.path,
    required this.duplicates,
    this.text,
  });

  final String filename;

  /// The file the player uses.
  final String path;

  /// The other matches; the user can pick one of these in the lyrics sheet.
  final List<String> duplicates;

  /// LRC text, when the request asked for it and the file could be read.
  final String? text;

  /// Every match, best first.
  List<String> get paths => [path, ...duplicates];

  factory LyricsFileLink.fromJson(Map<String, dynamic> json) => LyricsFileLink(
        filename: json['filename'] as String? ?? '',
        path: json['path'] as String? ?? '',
        duplicates: [
          for (final path in json['duplicates'] as List<dynamic>? ?? const [])
            path as String,
        ],
        text: json['text'] as String?,
      );
}

class LyricsFileDetails {
  LyricsFileDetails.fromJson(Map<String, dynamic> json)
      : path = json['path'] as String,
        text = json['text'] as String?,
        duration = switch (json['durationMs']) {
          final int milliseconds => Duration(milliseconds: milliseconds),
          _ => null,
        },
        syncType = switch (json['syncType']) {
          'word' => LyricsSyncType.word,
          'line' => LyricsSyncType.line,
          _ => LyricsSyncType.plain,
        };

  final String path;
  final String? text;
  final Duration? duration;
  final LyricsSyncType syncType;
}

/// Runs library work on the native core, one background isolate per task.
///
/// Results come back exactly as the Dart scanners send them, so callers do not
/// need to know which implementation ran.
class RustLibraryTasks {
  RustLibraryTasks._();

  static bool get isAvailable => WispieCore.isAvailable;

  static Stream<Object> events(RustTaskRequest request) async* {
    final port = ReceivePort();
    try {
      await Isolate.spawn(
        _run,
        (request: request, port: port.sendPort),
        onExit: port.sendPort,
      );
      await for (final message in port) {
        if (message == null) {
          yield const RustTaskError('Native library worker exited early');
          return;
        }
        yield message;
        if (message is RustTaskDone || message is RustTaskError) return;
      }
    } finally {
      port.close();
    }
  }

  static void cancel() => WispieCore.cancel();

  /// Every media file under [root], walked on the native core.
  static Future<List<String>> listMedia(String root,
      {bool recursive = true}) async {
    final result = await _collectOnce({
      'command': 'list_media',
      'root': root,
      'recursive': recursive,
    });
    return [
      for (final path in result['paths'] as List<dynamic>? ?? const [])
        path as String,
    ];
  }

  /// Tags and length for [paths]; an unreadable file still comes back as a row.
  static Future<List<Map<String, dynamic>>> folderFacts(
    List<String> paths, {
    SendPort? progress,
  }) async {
    final result = await _collectOnce(
      {'command': 'read_facts', 'paths': paths},
      progress: progress,
    );
    return [
      for (final fact in result['facts'] as List<dynamic>? ?? const [])
        Map<String, dynamic>.from(fact as Map),
    ];
  }

  /// Rewrites legacy cover files under [coversDir], mapping old path to new.
  static Future<Map<String, String>> compactCovers(
    String coversDir,
    List<String> paths,
  ) async {
    final result = await _collectOnce({
      'command': 'compact_covers',
      'coversDir': coversDir,
      'paths': paths,
    });
    return Map<String, String>.from(
        result['compacted'] as Map? ?? const <String, String>{});
  }

  /// The cached cover for one file, extracting it when needed.
  ///
  /// Lazy tiles use this so a cover found on demand is produced by the same
  /// reader the scan uses, instead of a second implementation that can write
  /// bytes the scan would reject.
  static Future<String?> coverFor(
    String url,
    String filename, {
    required String coversDir,
    bool force = false,
  }) async {
    final result = await _collectOnce({
      'command': 'rebuild_covers',
      'coversDir': coversDir,
      'force': force,
      'songs': [
        {
          'title': '',
          'artist': '',
          'album': '',
          'filename': filename,
          'url': url,
        },
      ],
    });
    return (result['covers'] as Map?)?[url] as String?;
  }

  /// Sidecar `.lrc`/`.ttml` files that match [songs], keyed by filename.
  ///
  /// A song's own folder is always searched, so this works on a library that
  /// was never rescanned; [roots] adds the user's own lyrics folders.
  static Future<Map<String, LyricsFileLink>> lyricsLinks(
    List<Song> songs, {
    List<String> roots = const [],
    bool withText = false,
  }) async {
    if (songs.isEmpty) return const {};
    final result = await _collectOnce({
      'command': 'lyrics_link',
      'songs': [
        for (final song in songs) {'filename': song.filename, 'url': song.url},
      ],
      'roots': roots,
      'text': withText,
    });

    final links = <String, LyricsFileLink>{};
    for (final row in result['links'] as List<dynamic>? ?? const []) {
      final link = LyricsFileLink.fromJson(row as Map<String, dynamic>);
      if (link.path.isEmpty) continue;
      links[link.filename] = link;
    }
    return links;
  }

  static Future<List<LyricsFileDetails>> lyricsFileDetails(
    List<String> paths,
  ) async {
    if (paths.isEmpty) return const [];
    final result = await _collectOnce({
      'command': 'lyrics_link',
      'paths': paths.toSet().toList(),
    });
    return [
      for (final row in result['links'] as List<dynamic>? ?? const [])
        LyricsFileDetails.fromJson(row as Map<String, dynamic>),
    ];
  }

  static Future<LyricsChoice?> lyricsChoice(
    String path, {
    LyricsChoice? save,
  }) async {
    final result = await _collectOnce({
      'command': 'lyrics_choice',
      'path': path,
      if (save != null)
        'choice': {'text': save.text, 'richSync': save.richSync?.toJson()},
    });
    final choice = result['choice'] as Map<String, dynamic>?;
    if (choice == null || choice['text'] is! String) return null;
    return (
      text: choice['text'] as String,
      richSync: RichLyrics.fromJson(choice['richSync']),
    );
  }

  /// Renames sidecar files, mapping each existing path to the song's new stem.
  ///
  /// Returns the moves that landed, old path to new path.
  static Future<Map<String, String>> renameLyrics(
    Map<String, String> newStemByPath,
  ) async {
    if (newStemByPath.isEmpty) return const {};
    final result = await _collectOnce({
      'command': 'lyrics_rename',
      'items': [
        for (final entry in newStemByPath.entries)
          {
            'paths': [entry.key],
            'newStem': entry.value,
          },
      ],
    });

    final moved = <String, String>{};
    for (final row in result['renames'] as List<dynamic>? ?? const []) {
      final map = row as Map<String, dynamic>;
      final from = map['from'] as String?;
      final to = map['to'] as String?;
      if (from != null && to != null) moved[from] = to;
    }
    return moved;
  }

  /// Reads a whole row for one file: tags, duration, year, lyrics and cover.
  static Future<Song?> readSong(Song song, {required String coversDir}) async {
    final result = await _collectOnce({
      'command': 'read_song',
      'coversDir': coversDir,
      'songs': [song.toJson()],
    });
    final rows = result['songs'] as List<dynamic>? ?? const [];
    if (rows.isEmpty) return null;
    return Song.fromJson(rows.first as Map<String, dynamic>);
  }
}

void _run(({RustTaskRequest request, SendPort port}) job) {
  try {
    WispieCore.run(
      job.request.toJson(),
      onEvent: (kind, payload) {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        switch (kind) {
          case WispieCore.eventItems:
            _emitItems(decoded, job.port);
          case WispieCore.eventProgress:
            final total = (decoded['total'] as num?)?.toDouble() ?? 0;
            final done = (decoded['done'] as num?)?.toDouble() ?? 0;
            job.port.send(total <= 0 ? 1.0 : done / total);
          case WispieCore.eventDone:
            job.port.send(_done(decoded));
          case WispieCore.eventError:
            job.port.send(RustTaskError(
                decoded['message'] as String? ?? 'native core error'));
        }
      },
    );
  } catch (error) {
    job.port.send(RustTaskError('$error'));
  }
}

void _emitItems(Map<String, dynamic> decoded, SendPort port) {
  if (decoded['songs'] case final List<dynamic> songs) {
    port.send([
      for (final song in songs) Song.fromJson(song as Map<String, dynamic>),
    ]);
  } else if (decoded['covers'] case final Map<String, dynamic> covers) {
    port.send(Map<String, String>.from(covers));
  } else if (decoded['facts'] case final List<dynamic> facts) {
    port.send([
      for (final fact in facts) Map<String, dynamic>.from(fact as Map),
    ]);
  }
}

/// Runs a task whose whole result is wanted at once, not streamed.
///
/// Results are collected on the worker isolate, so the caller's isolate only
/// ever touches finished maps instead of decoding batches itself.
Future<Map<String, dynamic>> _collectOnce(
  Map<String, Object?> request, {
  SendPort? progress,
}) async {
  final port = ReceivePort();
  final isolate = await Isolate.spawn(
    _collect,
    _CollectJob(request, port.sendPort, progress),
  );
  try {
    final message = await port.first;
    if (message is RustTaskError) throw StateError(message.message);
    return Map<String, dynamic>.from(message as Map);
  } finally {
    isolate.kill(priority: Isolate.immediate);
    port.close();
  }
}

class _CollectJob {
  const _CollectJob(this.request, this.port, this.progress);

  final Map<String, Object?> request;
  final SendPort port;
  final SendPort? progress;
}

void _collect(_CollectJob job) {
  final paths = <String>[];
  final facts = <Map<String, dynamic>>[];
  final compacted = <String, String>{};
  final songs = <Map<String, dynamic>>[];
  final covers = <String, String>{};
  final links = <Map<String, dynamic>>[];
  final renames = <Map<String, dynamic>>[];
  final failures = <Map<String, dynamic>>[];
  Map<String, dynamic>? choice;

  try {
    WispieCore.run(job.request, onEvent: (kind, payload) {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      switch (kind) {
        case WispieCore.eventItems:
          if (decoded['paths'] case final List<dynamic> list) {
            paths.addAll(list.cast<String>());
          } else if (decoded['facts'] case final List<dynamic> list) {
            facts.addAll(list.cast<Map<String, dynamic>>());
          } else if (decoded['compacted'] case final Map<String, dynamic> map) {
            compacted.addAll(Map<String, String>.from(map));
          } else if (decoded['songs'] case final List<dynamic> list) {
            songs.addAll(list.cast<Map<String, dynamic>>());
          } else if (decoded['covers'] case final Map<String, dynamic> map) {
            covers.addAll(Map<String, String>.from(map));
          } else if (decoded['links'] case final List<dynamic> list) {
            links.addAll(list.cast<Map<String, dynamic>>());
          } else if (decoded['choice'] case final Map<String, dynamic> map) {
            choice = map;
          } else if (decoded['renames'] case final List<dynamic> list) {
            renames.addAll(list.cast<Map<String, dynamic>>());
          } else if (decoded['failures'] case final List<dynamic> list) {
            failures.addAll(list.cast<Map<String, dynamic>>());
          }
        case WispieCore.eventProgress:
          final total = (decoded['total'] as num?)?.toInt() ?? 0;
          final done = (decoded['done'] as num?)?.toInt() ?? 0;
          if (total > 0) job.progress?.send(done);
        case WispieCore.eventError:
          job.port.send(RustTaskError(
              decoded['message'] as String? ?? 'native core error'));
      }
    });
    job.port.send({
      'paths': paths,
      'facts': facts,
      'compacted': compacted,
      'songs': songs,
      'covers': covers,
      'links': links,
      'choice': choice,
      'renames': renames,
      'failures': failures,
    });
  } catch (error) {
    job.port.send(RustTaskError('$error'));
  }
}

RustTaskDone _done(Map<String, dynamic> decoded) => RustTaskDone(
      unreadable: (decoded['unreadable'] as num?)?.toInt() ?? 0,
      unreachable: [
        for (final root in decoded['unreachable'] as List<dynamic>? ?? const [])
          root as String,
      ],
      scanned: (decoded['scanned'] as num?)?.toInt() ?? 0,
      cancelled: decoded['cancelled'] == true,
    );
