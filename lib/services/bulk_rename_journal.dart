import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

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

  static const String _fileName = 'bulk_rename_journal.json';

  final List<PendingRename> _entries = [];
  bool _loaded = false;

  List<PendingRename> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Reads the journal off disk once per process.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file();
      if (!await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        final entry = PendingRename.fromJson(item.cast<String, Object?>());
        if (entry != null) _entries.add(entry);
      }
    } on FormatException catch (e) {
      // A half-written file is the expected shape of a crash mid-append, and the
      // scan it was serving is about to run anyway.
      _entries.clear();
      debugPrint('Bulk rename journal unreadable, starting a new one: $e');
    } on FileSystemException catch (e) {
      debugPrint('Could not read bulk rename journal: $e');
    }
  }

  /// Notes a rename that is about to be attempted.
  Future<void> record(PendingRename entry) async {
    _entries.add(entry);
    await _flush();
  }

  /// Retracts an entry whose rename never happened, so a later recovery cannot
  /// act on a name that was never written.
  Future<void> discard(PendingRename entry) async {
    if (!_entries.remove(entry)) return;
    await _flush();
  }

  /// Forgets everything. Only correct once the rows have actually moved.
  Future<void> clear() async {
    if (_entries.isEmpty) return;
    _entries.clear();
    await _flush();
  }

  Future<void> _flush() async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode([for (final entry in _entries) entry.toJson()]),
      flush: true,
    );
  }

  Future<File> _file() async =>
      File(p.join((await getWispieDirectory()).path, _fileName));
}
