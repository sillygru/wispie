import '../../domain/services/song_replacement_rules.dart';
import '../../l10n/app_localizations.dart';

/// How a rejected replacement explains itself.
///
/// Shared rather than private to one screen: the single-song picker and the
/// batch screen report the same rejection reasons, and two mappings that drift
/// apart would describe the same failure two ways.
///
/// Keyed on the reason, because a batch reports the reason it recorded long
/// after the check that produced it is gone; [filename] is whatever the message
/// needs to name.
extension ReplacementRejectLabel on ReplacementRejectReason {
  String label(AppLocalizations l10n, {String filename = ''}) => switch (this) {
        ReplacementRejectReason.noFileSelected =>
          l10n.metadataReplaceRejectNoFile,
        ReplacementRejectReason.unsupportedFormat =>
          l10n.metadataReplaceRejectUnsupported,
        ReplacementRejectReason.sameFilename =>
          l10n.metadataReplaceRejectSameFilename,
        ReplacementRejectReason.insideLibrary =>
          l10n.metadataReplaceRejectInsideLibrary,
        ReplacementRejectReason.destinationExists =>
          l10n.metadataReplaceRejectDestinationExists(filename),
        ReplacementRejectReason.libraryHasName =>
          l10n.metadataReplaceRejectLibraryHasName(filename),
      };
}

/// The same wording for a whole rejected check, which knows its own filename.
extension ReplacementCheckLabel on ReplacementRejected {
  String label(AppLocalizations l10n) =>
      reason.label(l10n, filename: filename ?? '');
}
