import '../../domain/services/youtube_library.dart';
import '../../l10n/app_localizations.dart';
import '../../services/sync/account_service.dart' show SecretStoreException;
import '../../services/youtube_account_service.dart';

/// Turns an account failure into a sentence the user can act on.
///
/// Sign-in and browsing fail for different reasons: a rejected cookie jar means
/// signing in again, while a network or throttling failure only means waiting.
class YouTubeAccountErrorMessage {
  const YouTubeAccountErrorMessage._();

  static String forError(Object error, AppLocalizations l10n) {
    if (error is YouTubeLibraryException) {
      return switch (error.kind) {
        YouTubeLibraryErrorKind.unauthorized =>
          l10n.youtubeAccountErrorUnauthorized,
        YouTubeLibraryErrorKind.network => l10n.youtubeAccountErrorNetwork,
        YouTubeLibraryErrorKind.invalidResponse =>
          l10n.youtubeAccountErrorResponse,
        YouTubeLibraryErrorKind.rateLimited =>
          l10n.youtubeAccountErrorRateLimited,
        YouTubeLibraryErrorKind.notFound => l10n.youtubeAccountPlaylistEmpty,
        YouTubeLibraryErrorKind.other => l10n.youtubeAccountErrorGeneric,
      };
    }
    if (error is SecretStoreException) return l10n.youtubeAccountErrorStorage;
    if (error is YouTubeAccountSignedOutException) {
      return l10n.youtubeAccountErrorUnauthorized;
    }
    return l10n.youtubeAccountErrorGeneric;
  }
}
