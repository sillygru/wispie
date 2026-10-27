// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/models/youtube_playlist_link.dart';
import '../../domain/services/youtube_library.dart';
import '../../l10n/l10n.dart';
import '../../providers/youtube_account_provider.dart';
import '../../services/youtube_account_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_section_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_account_error_message.dart';
import '../widgets/album_art_image.dart';
import 'youtube_cookie_import_screen.dart';
import 'youtube_web_signin_screen.dart';

/// Sign in to the Google account behind YouTube, then pull its playlists into
/// the library.
///
/// The account is optional on purpose: search, playback, favorites and
/// statistics never need it. This screen is the only place that asks for it,
/// and it says plainly where the session comes from.
class YouTubeAccountScreen extends ConsumerStatefulWidget {
  const YouTubeAccountScreen({super.key});

  @override
  ConsumerState<YouTubeAccountScreen> createState() =>
      _YouTubeAccountScreenState();
}

class _YouTubeAccountScreenState extends ConsumerState<YouTubeAccountScreen> {
  bool _signingIn = false;
  String? _busyRemoteId;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final account = ref.read(youtubeAccountProvider).asData?.value;
      if (account != null && account.signedIn && account.profile == null) {
        ref.read(youtubeAccountProvider.notifier).refreshProfile();
      }
    });
  }

  Future<void> _signIn({bool importCookies = false}) async {
    setState(() {
      _error = null;
      _signingIn = true;
    });
    try {
      final useWebView = !importCookies && YouTubeWebSignInScreen.isSupported;
      if (!useWebView) {
        // The import screen validates and signs in itself, so its result only
        // tells us whether to keep showing the signed-out card.
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => const YouTubeCookieImportScreen(),
          ),
        );
        return;
      }
      final cookies = await Navigator.push<Map<String, String>>(
        context,
        MaterialPageRoute(
          builder: (_) => const YouTubeWebSignInScreen(),
        ),
      );
      if (!mounted || cookies == null) return;
      // Proving the jar works is a network round-trip; the account card shows
      // the spinner until it answers.
      await ref.read(youtubeAccountProvider.notifier).signIn(cookies);
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = YouTubeAccountErrorMessage.forError(error, context.l10n),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _openYouTube() async {
    try {
      await launchUrl(
        Uri.parse('https://www.youtube.com/'),
        mode: LaunchMode.externalApplication,
      );
    } on Object catch (error) {
      debugPrint('YouTube: could not open the sign-in page: $error');
    }
  }

  Future<void> _signOut() async {
    await ref.read(youtubeAccountProvider.notifier).signOut();
    // The WebView keeps a jar of its own; leaving it behind would sign the
    // press straight back in with the same account.
    await YouTubeWebSignInScreen.clearBrowserCookies();
    if (!mounted) return;
    setState(() => _error = null);
  }

  Future<void> _runPlaylistAction(
    YouTubeAccountPlaylist playlist,
    YouTubePlaylistLink? link,
  ) async {
    final l10n = context.l10n;
    setState(() {
      _busyRemoteId = playlist.id;
      _error = null;
    });
    final notifier = ref.read(youtubeAccountProvider.notifier);
    try {
      final summary = link == null
          ? await notifier.importPlaylist(
              playlist,
              localName: _displayName(playlist, l10n),
            )
          : await notifier.syncPlaylist(link);
      if (!mounted) return;
      _report(summary, l10n);
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = YouTubeAccountErrorMessage.forError(error, l10n),
      );
    } finally {
      if (mounted) setState(() => _busyRemoteId = null);
    }
  }

  Future<void> _syncAll(AppLocalizations l10n) async {
    setState(() {
      _busyRemoteId = 'all';
      _error = null;
    });
    try {
      final summaries =
          await ref.read(youtubeAccountProvider.notifier).syncAll();
      if (!mounted) return;
      final added = summaries
          .where((summary) => !summary.failed)
          .fold<int>(0, (sum, summary) => sum + summary.added);
      final failed = summaries.where((summary) => summary.failed).length;
      if (failed > 0) {
        appSnack(
          context,
          l10n.youtubeAccountErrorGeneric,
          tone: AppTone.danger,
        );
      } else if (added == 0) {
        appSnack(context, l10n.youtubeAccountSyncUpToDate(l10n.onlineTab));
      } else {
        appSnack(
          context,
          l10n.youtubeAccountSyncDone(added, l10n.onlineTab),
          tone: AppTone.success,
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _error = YouTubeAccountErrorMessage.forError(error, l10n),
      );
    } finally {
      if (mounted) setState(() => _busyRemoteId = null);
    }
  }

  void _report(YouTubePlaylistSyncSummary summary, AppLocalizations l10n) {
    if (summary.failed) {
      appSnack(
        context,
        l10n.youtubeAccountErrorGeneric,
        tone: AppTone.danger,
      );
      return;
    }
    if (summary.skippedForLimit > 0) {
      appSnack(
        context,
        l10n.youtubeAccountSyncLimited(summary.skippedForLimit),
        tone: AppTone.warning,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    if (summary.created) {
      appSnack(
        context,
        l10n.youtubeAccountImportDone(summary.added, summary.playlistName),
        tone: AppTone.success,
      );
      return;
    }
    if (summary.added == 0) {
      appSnack(context, l10n.youtubeAccountSyncUpToDate(summary.playlistName));
      return;
    }
    appSnack(
      context,
      l10n.youtubeAccountSyncDone(summary.added, summary.playlistName),
      tone: AppTone.success,
    );
  }

  static String _displayName(
    YouTubeAccountPlaylist playlist,
    AppLocalizations l10n,
  ) {
    return playlist.isLikedVideos
        ? l10n.youtubeAccountLikedVideos
        : playlist.title;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountAsync = ref.watch(youtubeAccountProvider);
    final signedIn = accountAsync.asData?.value.signedIn ?? false;

    return AmbientScaffold(
      appBar: AppTopBar(
        title: l10n.youtubeAccountTitle,
        actions: [
          if (signedIn)
            IconButton(
              tooltip: l10n.actionRefresh,
              onPressed: () {
                ref.invalidate(youtubeAccountPlaylistsProvider);
                ref.read(youtubeAccountProvider.notifier).refreshProfile();
              },
              icon: const AppIcon(AppIcons.refresh),
            ),
        ],
      ),
      body: accountAsync.when(
        loading: () => Center(
          child: Semantics(
            label: l10n.youtubeAccountLoading,
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => AppEmptyState(
          icon: AppIcons.error,
          title: l10n.youtubeAccountLoadFailed,
          message: YouTubeAccountErrorMessage.forError(error, l10n),
          tone: AppTone.danger,
          actionLabel: l10n.youtubeAccountTryAgain,
          onAction: () => ref.invalidate(youtubeAccountProvider),
        ),
        data: (account) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s4,
            AppTokens.s2,
            AppTokens.s4,
            AppTokens.scrollBottomInset,
          ),
          children: [
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: AppTokens.s3),
            ],
            if (account.sessionExpired && !_signingIn)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.s3),
                child: AppSurface(
                  accentTint: AppTokens.warning,
                  child: Row(
                    children: [
                      const AppIcon(
                        AppIcons.warning,
                        size: AppTokens.iconSm,
                        color: AppTokens.warning,
                      ),
                      const SizedBox(width: AppTokens.s3),
                      Expanded(
                        child: Text(
                          l10n.youtubeAccountSessionExpired,
                          style: AppTokens.rowSubtitle(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!account.signedIn)
              _SignInCard(
                busy: _signingIn,
                onSignIn: _signingIn ? null : () => _signIn(),
                onImportCookies:
                    _signingIn ? null : () => _signIn(importCookies: true),
                onOpenYouTube: _signingIn ? null : _openYouTube,
              ),
            if (account.signedIn) ...[
              _AccountCard(
                account: account,
                onSignOut: _signOut,
              ),
              const SizedBox(height: AppTokens.s4),
              _PlaylistsSection(
                busyId: _busyRemoteId,
                onAction: _runPlaylistAction,
                onSyncAll: () => _syncAll(l10n),
                onRetry: () => ref.invalidate(youtubeAccountPlaylistsProvider),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      accentTint: AppTokens.danger,
      child: Row(
        children: [
          const AppIcon(
            AppIcons.error,
            size: AppTokens.iconSm,
            color: AppTokens.danger,
          ),
          const SizedBox(width: AppTokens.s3),
          Expanded(
            child: Text(message, style: AppTokens.rowSubtitle(context)),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  final bool busy;
  final VoidCallback? onSignIn;
  final VoidCallback? onImportCookies;
  final VoidCallback? onOpenYouTube;

  const _SignInCard({
    required this.busy,
    required this.onSignIn,
    required this.onImportCookies,
    required this.onOpenYouTube,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final webView = YouTubeWebSignInScreen.isSupported;
    // Only offer the in-app form first where Google accepts it.
    final cookieFirst = !webView || YouTubeWebSignInScreen.prefersCookieImport;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.youtubeAccountSignedOutTitle,
            style: AppTokens.screenTitle(context),
          ),
          const SizedBox(height: AppTokens.s2),
          Text(
            l10n.youtubeAccountSignedOutBody,
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          Text(
            cookieFirst
                ? l10n.youtubeAccountSignInHintManual
                : l10n.youtubeAccountSignInHint,
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s4),
          if (busy)
            const Center(
              child: SizedBox(
                width: AppTokens.iconMd,
                height: AppTokens.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            if (cookieFirst)
              FilledButton.icon(
                onPressed: onImportCookies,
                icon: const AppIcon(AppIcons.download),
                label: Text(l10n.youtubeAccountCookiesImport),
              )
            else
              FilledButton.icon(
                onPressed: onSignIn,
                icon: const AppIcon(AppIcons.person),
                label: Text(l10n.youtubeAccountSignIn),
              ),
            const SizedBox(height: AppTokens.s1),
            if (!webView)
              TextButton.icon(
                onPressed: onOpenYouTube,
                icon: const AppIcon(AppIcons.openInNew),
                label: Text(l10n.youtubeAccountOpenYouTube),
              )
            else if (cookieFirst)
              TextButton(
                onPressed: onSignIn,
                child: Text(l10n.youtubeAccountSignInTryWeb),
              )
            else
              TextButton(
                onPressed: onImportCookies,
                child: Text(l10n.youtubeAccountWebTrouble),
              ),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final YouTubeAccountSnapshot account;
  final VoidCallback onSignOut;

  const _AccountCard({required this.account, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = account.profile;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AlbumArtImage(
                url: profile?.avatarUrl ?? '',
                width: 48,
                height: 48,
                borderRadius: AppTokens.rSm,
              ),
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: Text(
                  profile == null
                      ? l10n.youtubeAccountTitle
                      : l10n.youtubeAccountSignedInAs(profile.title),
                  style: AppTokens.rowTitle(context),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSignOut,
              child: Text(l10n.youtubeAccountSignOut),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistsSection extends ConsumerWidget {
  final String? busyId;
  final void Function(YouTubeAccountPlaylist, YouTubePlaylistLink?) onAction;
  final VoidCallback onSyncAll;
  final VoidCallback onRetry;

  const _PlaylistsSection({
    required this.busyId,
    required this.onAction,
    required this.onSyncAll,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final playlistsAsync = ref.watch(youtubeAccountPlaylistsProvider);
    final links = ref.watch(youtubePlaylistLinksProvider).asData?.value ??
        const <String, YouTubePlaylistLink>{};

    if (playlistsAsync.hasError) {
      return AppEmptyState(
        icon: AppIcons.error,
        title: l10n.youtubeAccountLoadFailed,
        message: YouTubeAccountErrorMessage.forError(
          playlistsAsync.error!,
          l10n,
        ),
        tone: AppTone.danger,
        actionLabel: l10n.youtubeAccountTryAgain,
        onAction: onRetry,
      );
    }

    final playlists = playlistsAsync.asData?.value;
    final hasLinks = links.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          label: l10n.youtubeAccountPlaylistsTitle,
          actionLabel: hasLinks ? l10n.youtubeAccountSyncAll : null,
          onActionTap: onSyncAll,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s4,
            0,
            AppTokens.s4,
            AppTokens.s2,
          ),
          child: Text(
            l10n.youtubeAccountSyncHint,
            style: AppTokens.rowSubtitle(context),
          ),
        ),
        if (playlists == null)
          Padding(
            padding: const EdgeInsets.all(AppTokens.s4),
            child: Center(
              child: SizedBox(
                width: AppTokens.iconMd,
                height: AppTokens.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: l10n.youtubeAccountLoading,
                ),
              ),
            ),
          )
        else
          AppSurfaceGroup(
            children: [
              for (final playlist in playlists)
                _playlistRow(context, l10n, playlist, links),
            ],
          ),
      ],
    );
  }

  Widget _playlistRow(
    BuildContext context,
    AppLocalizations l10n,
    YouTubeAccountPlaylist playlist,
    Map<String, YouTubePlaylistLink> links,
  ) {
    final link = links.values
        .where((candidate) => candidate.remotePlaylistId == playlist.id)
        .firstOrNull;
    final busy = busyId == playlist.id;
    final count = playlist.itemCount;

    return AppListRow(
      key: ValueKey('youtube-playlist-${playlist.id}'),
      tall: true,
      leading: AlbumArtImage(
        url: playlist.thumbnailUrl ?? '',
        width: 48,
        height: 48,
        borderRadius: AppTokens.rSm,
      ),
      title: playlist.isLikedVideos
          ? l10n.youtubeAccountLikedVideos
          : playlist.title,
      titleMaxLines: 1,
      subtitle: count == null ? null : l10n.youtubeAccountPlaylistTracks(count),
      subtitleMaxLines: 1,
      trailing: busy
          ? const SizedBox(
              width: AppTokens.iconMd,
              height: AppTokens.iconMd,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : link == null
              ? TextButton(
                  onPressed: () => onAction(playlist, null),
                  child: Text(l10n.youtubeAccountImport),
                )
              : IconButton(
                  tooltip: l10n.youtubeAccountSync,
                  onPressed: () => onAction(playlist, link),
                  icon: const AppIcon(AppIcons.syncAlt),
                ),
    );
  }
}
