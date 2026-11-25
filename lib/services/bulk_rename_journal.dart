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
  });

  /// The filename the database still knows the song by.
  final String from;

  /// The filename it now has on disk.
  final String to;

  /// Where the file sits now, so recovery can prove the rename really happened
  /// rather than take the journal's word for it.
  final String url;

  Map<String, Object?> toJson() => {'from': from, 'to': to, 'url': url};

  static PendingRename? fromJson(Map<String, Object?> json) {
    final from = json['from'];
    final to = json['to'];
    final url = json['url'];
    if (from is! String || to is! String || url is! String) return null;
    return PendingRename(from: from, to: to, url: url);
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

  final List<PendingRename> _entries = [];
  Future<void>? _loading;

  List<PendingRename> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Reads the journal off disk once per process.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final reply = await _command('read_rename_journal');
      for (final item in reply['entries'] as List) {
        final entry = PendingRename.fromJson((item as Map).cast());
        if (entry != null) _entries.add(entry);
      }
    } on StateError catch (error) {
      debugPrint('Could not read bulk rename journal: $error');
    }
  }

  /// Notes a rename that is about to be attempted.
  Future<void> record(PendingRename entry) async {
    await load();
    _entries.add(entry);
    await _flush();
  }

  /// Retracts an entry whose rename never happened, so a later recovery cannot
  /// act on a name that was never written.
  Future<void> discard(PendingRename entry) async {
    await load();
    if (!_entries.remove(entry)) return;
    await _flush();
  }

  /// Forgets everything. Only correct once the rows have actually moved.
  Future<void> clear() async {
    await load();
    if (_entries.isEmpty) return;
    _entries.clear();
    await _flush();
  }

  Future<void> _flush() async {
    await _command('write_rename_journal', {
      'entries': [for (final entry in _entries) entry.toJson()],
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
