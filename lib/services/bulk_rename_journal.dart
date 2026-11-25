import 'package:flutter/foundation.dart';

import '../data/rust/native_command.dart';

import 'wispie_paths.dart';

/// One rename that has landed on disk but whose filename-keyed rows have not
/// been moved yet.
class PendingRename {
  const PendingRename({
    required this.from,
    required this.to,
    required this.url,
    this.sidecars = const [],
  });

  /// The filename the database still knows the song by.
  final String from;

  /// The filename it now has on disk.
  final String to;

  /// Where the file sits now, so recovery can prove the rename really happened
  /// rather than take the journal's word for it.
  final String url;
  final List<String> sidecars;

  Map<String, Object?> toJson() => {
        'from': from,
        'to': to,
        'url': url,
        if (sidecars.isNotEmpty) 'sidecars': sidecars,
      };

  static PendingRename? fromJson(Map<String, Object?> json) {
    final from = json['from'];
    final to = json['to'];
    final url = json['url'];
    if (from is! String || to is! String || url is! String) return null;
    return PendingRename(
      from: from,
      to: to,
      url: url,
      sidecars:
          (json['sidecars'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// The record that lets an interrupted bulk rename be finished rather than
/// undone.
///
/// Every user-data table is keyed by filename, so a rename is two writes that
/// have to land together: the file moves, then the rows follow. A process death
/// between them leaves the library pointing at a name that does not exist, which
/// is worse than a rename that never happened at all — the song is not merely
/// un-renamed, it is unplayable and its stats are unreachable.
///
/// An entry is written *before* the file is touched, because only the entry that
/// pre-dates the write can cover a crash that happens during it. That also means
/// the journal holds songs whose rename never happened, which is why every entry
/// is verified against the filesystem on the way back in.
class BulkRenameJournal {
  BulkRenameJournal._();

  static final BulkRenameJournal instance = BulkRenameJournal._();

  Future<List<PendingRename>> load() async {
    try {
      return await _readEntries('read_rename_journal');
    } on StateError catch (error) {
      debugPrint('Could not read bulk rename journal: $error');
      return const [];
    }
  }

  Future<int> sliceLength() async =>
      (await _command('rename_slice_length'))['length'] as int;

  Future<List<PendingRename>> recoverableRenames(List<PendingRename> pending) =>
      _readEntries('recoverable_renames', {
        'entries': [for (final entry in pending) entry.toJson()],
      });

  Future<List<PendingRename>> _readEntries(String op,
      [Map<String, Object?> fields = const {}]) async {
    final reply = await _command(op, fields);
    return [
      for (final item in reply['entries'] as List)
        if (PendingRename.fromJson((item as Map).cast()) case final entry?)
          entry,
    ];
  }

  Future<void> moveSidecars(PendingRename entry) async {
    if (entry.sidecars.isEmpty) return;
    await _command('rename_sidecars', {
      'path': entry.url,
      'sidecars': entry.sidecars,
    });
  }

  Future<void> record(PendingRename entry) async {
    await _command('record_rename', {'entry': entry.toJson()});
  }

  Future<void> discard(PendingRename entry) => acknowledge([entry]);

  Future<void> acknowledge(Iterable<PendingRename> entries) async {
    if (entries.isEmpty) return;
    await _command('acknowledge_renames', {
      'entries': [for (final entry in entries) entry.toJson()],
    });
  }

  Future<Map<String, dynamic>> _command(
    String op, [
    Map<String, Object?> fields = const {},
  ]) async {
    final directory = await getWispieDirectory();
    return compute(
      (request) => runCoreCommand('file_workflow', request),
      {'op': op, 'path': directory.path, ...fields},
    );
  }
}
