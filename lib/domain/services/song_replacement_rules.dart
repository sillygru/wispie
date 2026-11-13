import '../../models/song.dart';
import 'native_accel.dart';

/// What happens to the original file once its replacement is in place.
enum OriginalFileDisposition {
  /// Delete the original from disk and drop its library row.
  delete,

  /// Keep the file on disk but take the song out of the library.
  hide,
}

/// How the new file reaches the library.
///
/// Separate from [OriginalFileDisposition] on purpose: one decides what happens
/// to the file coming in, the other what happens to the file going out, and a
/// replacement is any combination of the two.
enum ReplacementTransport {
  /// The new file is copied in and the source folder keeps its copy.
  copy,

  /// The new file is moved in, leaving nothing behind in the source folder.
  move,
}

/// One song to replace with one file.
class ReplacementRequest {
  /// The library song, under the identity it still has.
  final Song song;
  final String sourcePath;

  const ReplacementRequest({required this.song, required this.sourcePath});

  /// The filename the replacement will carry, which is the identity every
  /// filename-keyed record gets re-pointed at.
  String get newFilename => NativeAccel.replacementFilename(sourcePath);

  /// Where the replacement is written: the song's own directory.
  String get destinationPath =>
      SongReplacementRules.destinationFor(song, sourcePath);
}

/// Why one file of a run did not make it, in the two shapes a run can fail in:
/// a rule said no before anything was touched, or a filesystem operation threw.
class ReplacementFailure {
  final ReplacementRequest request;
  final ReplacementRejectReason? rejection;
  final Object? error;

  const ReplacementFailure({
    required this.request,
    this.rejection,
    this.error,
  });

  /// The library song's filename as it was when the run started.
  String get filename => request.song.filename;
}

/// What a run did.
///
/// [stoppedEarly] means the user cancelled; the lists are still whole, covering
/// exactly what happened before that.
class ReplacementOutcome {
  final List<Song> replaced;
  final List<ReplacementFailure> failures;
  final bool stoppedEarly;

  const ReplacementOutcome({
    required this.replaced,
    required this.failures,
    this.stoppedEarly = false,
  });

  bool get allSucceeded => failures.isEmpty && !stoppedEarly;
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

  /// Whether a file already occupies [destinationPath] and was accepted only
  /// because the caller said it may be overwritten.
  final bool overwritesDestination;

  const ReplacementAccepted({
    required this.sourcePath,
    required this.newFilename,
    required this.destinationPath,
    this.overwritesDestination = false,
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
    return NativeAccel.replacementDestination(
      originalUrl: original.url,
      sourcePath: sourcePath,
    );
  }

  /// Decides whether [sourcePath] may replace [original].
  ///
  /// [trackedFolders] are the roots the scanner walks, [libraryFilenames] every
  /// filename currently in the library, and [destinationExists] whether a file
  /// already sits at the destination. [overwriteDestination] accepts that file
  /// being replaced rather than refusing the candidate; only a caller that has
  /// asked the user may pass it.
  static ReplacementCheck check({
    required Song original,
    required String sourcePath,
    required bool isSupportedMediaFile,
    required Iterable<String> trackedFolders,
    required Iterable<String> libraryFilenames,
    required bool destinationExists,
    bool overwriteDestination = false,
  }) {
    final response = NativeAccel.replacementCheck(
      originalUrl: original.url,
      originalFilename: original.filename,
      sourcePath: sourcePath,
      isSupportedMediaFile: isSupportedMediaFile,
      trackedFolders: trackedFolders.toList(growable: false),
      libraryFilenames: libraryFilenames.toList(growable: false),
      destinationExists: destinationExists,
      overwriteDestination: overwriteDestination,
    );
    if (response['accepted'] == true) {
      return ReplacementAccepted(
        sourcePath: response['sourcePath'] as String,
        newFilename: response['newFilename'] as String,
        destinationPath: response['destinationPath'] as String,
        overwritesDestination: response['overwritesDestination'] as bool,
      );
    }
    final reasonName = response['reason'] as String;
    final reason = ReplacementRejectReason.values
        .firstWhere((candidate) => candidate.name == reasonName);
    return ReplacementRejected(
      reason,
      filename: response['filename'] as String?,
    );
  }
}
