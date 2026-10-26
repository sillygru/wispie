// SPDX-License-Identifier: GPL-3.0-only
import '../../l10n/app_localizations.dart';
import '../../services/audius_service.dart';
import '../../services/youtube_service.dart';

/// One place that turns an Audius failure into something the user can act on.
///
/// The old code showed the same "check your connection and API key" message
/// for a 429, a deleted track and a dead network, which sent people looking in
/// the wrong place.
class AudiusErrorMessage {
  const AudiusErrorMessage._();

  static String forError(Object error, AppLocalizations l10n) {
    if (error is! AudiusApiException) return l10n.onlineError;

    final status = error.statusCode;
    return switch (error.kind) {
      AudiusErrorKind.network => l10n.onlineErrorNetwork,
      AudiusErrorKind.unauthorized => l10n.onlineErrorAuth(status ?? 401),
      AudiusErrorKind.rateLimited => l10n.onlineErrorRateLimited,
      AudiusErrorKind.unavailable => l10n.onlineUnavailable,
      AudiusErrorKind.server => l10n.onlineErrorServer(status ?? 503),
      AudiusErrorKind.invalidResponse => l10n.onlineErrorResponse,
      AudiusErrorKind.other => l10n.onlineError,
    };
  }
}

/// YouTube failures, including the ones that are not the user's fault.
class YouTubeErrorMessage {
  const YouTubeErrorMessage._();

  static String forError(Object error, AppLocalizations l10n) {
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
    if (error is AudiusApiException) {
      return AudiusErrorMessage.forError(error, l10n);
    }
    return l10n.onlineYoutubeError;
  }
}
