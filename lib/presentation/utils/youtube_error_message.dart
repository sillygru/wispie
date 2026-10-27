// SPDX-License-Identifier: GPL-3.0-only
import '../../domain/services/youtube_library.dart';
import '../../l10n/app_localizations.dart';
import '../../services/youtube_service.dart';

/// YouTube failures, including the ones that are not the user's fault.
///
/// The same wording used to be shown for a 429, a removed video and a dead
/// connection, which sent people looking in the wrong place. Each kind now maps
/// to an action the user can take.
class YouTubeErrorMessage {
  const YouTubeErrorMessage._();

  static String forError(Object error, AppLocalizations l10n) {
    if (error is YouTubeLibraryException) {
      return switch (error.kind) {
        YouTubeLibraryErrorKind.unauthorized =>
          l10n.youtubeAccountSessionExpired,
        YouTubeLibraryErrorKind.network => l10n.onlineYoutubeErrorNetwork,
        YouTubeLibraryErrorKind.rateLimited =>
          l10n.onlineYoutubeErrorRateLimited,
        YouTubeLibraryErrorKind.notFound => l10n.onlineYoutubeErrorUnavailable,
        YouTubeLibraryErrorKind.invalidResponse =>
          l10n.onlineYoutubeErrorResponse,
        YouTubeLibraryErrorKind.other => l10n.onlineYoutubeError,
      };
    }
    if (error is YouTubeApiException) {
      return switch (error.kind) {
        YouTubeErrorKind.network => l10n.onlineYoutubeErrorNetwork,
        YouTubeErrorKind.rateLimited => l10n.onlineYoutubeErrorRateLimited,
        YouTubeErrorKind.unavailable => l10n.onlineYoutubeErrorUnavailable,
        YouTubeErrorKind.blocked => l10n.onlineYoutubeErrorBlocked,
        YouTubeErrorKind.invalidResponse => l10n.onlineYoutubeErrorResponse,
        YouTubeErrorKind.other => l10n.onlineYoutubeError,
      };
    }
    return l10n.onlineYoutubeError;
  }
}
