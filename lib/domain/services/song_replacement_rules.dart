import 'package:path/path.dart' as p;

import '../../models/song.dart';

/// What happens to the original file once its replacement is in place.
enum OriginalFileDisposition {
  /// Delete the original from disk and drop its library row.
  delete,

  /// Keep the file on disk but take the song out of the library.
  hide,
}

/// Result of validating a candidate replacement file.
sealed class ReplacementCheck {
  const ReplacementCheck();
}

/// The candidate can replace the original. [destinationPath] is where the file
/// must be written, and [newFilename] is the identity every filename-keyed
/// record has to move to.
class ReplacementAccepted extends ReplacementCheck {
  final String sourcePath;
  final String newFilename;
  final String destinationPath;

  const ReplacementAccepted({
    required this.sourcePath,
    required this.newFilename,
    required this.destinationPath,
  });
}

/// Why a candidate replacement cannot be used.
enum ReplacementRejectReason {
  noFileSelected,
  unsupportedFormat,
  sameFilename,
  insideLibrary,
  destinationExists,
  libraryHasName,
}

/// The candidate cannot be used. [reason] and [filename] are rendered for the
/// user by the presentation layer.
class ReplacementRejected extends ReplacementCheck {
  final ReplacementRejectReason reason;

  /// The filename the message refers to, when the rejection has one.
  final String? filename;

  const ReplacementRejected(this.reason, {this.filename});
}

/// The rules a replacement file has to satisfy.
///
/// Pure: everything the decision depends on arrives as an argument. That keeps
/// the rules — the part that decides whether a user's data gets rewritten —
/// testable without a filesystem, a database, or a picked file.
class SongReplacementRules {
  const SongReplacementRules._();

  /// Where [sourcePath] would be written for [original]: the original's own
  /// directory, under the replacement's own name.
  ///
  /// Only the directory travels, never the name. The replacement is a
  /// different file with a different name, and the whole feature exists to
  /// re-key user data onto that name — so the name has to come from the file
  /// the user chose, not from the row being replaced.
  static String destinationFor(Song original, String sourcePath) {
    return p.join(p.dirname(original.url), p.basename(sourcePath));
  }

  /// Whether two library filenames denote the same file.
  ///
  /// Case-insensitive on purpose: the app stores names verbatim, but the
  /// filesystems most users run on are not case-sensitive, so `Only You.flac`
  /// and `only you.flac` are one file and must never both reach the library.
  static bool _sameFile(String a, String b) =>
      a.toLowerCase() == b.toLowerCase();

  /// Whether [path] sits inside one of the folders the library tracks.
  ///
  /// Deliberately local rather than reusing `LibraryLogic.isUnder`: that class
  /// reaches into the user-data provider, and this file stays import-free of
  /// state management so it can be exercised on its own.
  static bool _isInsideTrackedFolder(
      String path, Iterable<String> trackedFolders) {
    final normalized = p.normalize(path.trim());
    if (normalized.isEmpty) return false;
    for (final folder in trackedFolders) {
      final root = p.normalize(folder.trim());
      if (root.isEmpty) continue;
      if (p.equals(root, normalized) || p.isWithin(root, normalized)) {
        return true;
      }
    }
    return false;
  }

  /// Decides whether [sourcePath] may replace [original].
  ///
  /// [trackedFolders] are the roots the scanner walks, [libraryFilenames] every
  /// filename currently in the library, and [destinationExists] whether a file
  /// already sits at the destination.
  static ReplacementCheck check({
    required Song original,
    required String sourcePath,
    required bool isSupportedMediaFile,
    required Iterable<String> trackedFolders,
    required Iterable<String> libraryFilenames,
    required bool destinationExists,
  }) {
    final trimmedSource = sourcePath.trim();
    if (trimmedSource.isEmpty) {
      return const ReplacementRejected(
        ReplacementRejectReason.noFileSelected,
      );
    }

    if (!isSupportedMediaFile) {
      return const ReplacementRejected(
        ReplacementRejectReason.unsupportedFormat,
      );
    }

    final newFilename = p.basename(trimmedSource);
    if (newFilename.isEmpty || _sameFile(newFilename, original.filename)) {
      return const ReplacementRejected(ReplacementRejectReason.sameFilename);
    }

    if (_isInsideTrackedFolder(trimmedSource, trackedFolders)) {
      return const ReplacementRejected(ReplacementRejectReason.insideLibrary);
    }

    final destination = destinationFor(original, trimmedSource);

    if (destinationExists) {
      return ReplacementRejected(
        ReplacementRejectReason.destinationExists,
        filename: newFilename,
      );
    }

    if (libraryFilenames.any((f) => _sameFile(f, newFilename))) {
      return ReplacementRejected(
        ReplacementRejectReason.libraryHasName,
        filename: newFilename,
      );
    }

    return ReplacementAccepted(
      sourcePath: trimmedSource,
      newFilename: newFilename,
      destinationPath: destination,
    );
  }
}
