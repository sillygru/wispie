// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../domain/services/youtube_library.dart' show kYouTubeWebUserAgent;
import '../../domain/services/youtube_session.dart';
import '../../l10n/l10n.dart';
import '../components/app_icon.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import 'youtube_cookie_import_screen.dart';

/// Google's own sign-in page in a WebView, harvested for the YouTube session
/// cookies afterwards.
///
/// This is how a browser signs in, and it is the reason this integration needs
/// no developer client of its own: the user authenticates with Google directly
/// and the app only ever sees the resulting cookies. They are HttpOnly, so no
/// JavaScript on the page could read them; the platform cookie store can.
///
/// Linux has no WebView plugin, and Google occasionally refuses to sign in
/// inside an embedded browser, so [YouTubeCookieImportScreen] is offered from
/// here as an equivalent route to the same session.
class YouTubeWebSignInScreen extends StatefulWidget {
  const YouTubeWebSignInScreen({super.key});

  /// WebViews are implemented for Android, iOS, macOS and Windows. Linux has no
  /// plugin that exposes the platform cookie jar, which is what makes this
  /// approach work at all.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Google rejects its login form in WKWebView on macOS almost every time
  /// ("this browser or app may not be secure"), so the account screen leads with
  /// the cookie import there and keeps this screen as a fallback.
  static bool get prefersCookieImport =>
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Drops the WebView's cookies. Called on sign-out so the next sign-in shows
  /// Google's account picker instead of silently reusing the last account.
  static Future<void> clearBrowserCookies() async {
    if (!isSupported) return;
    try {
      await CookieManager.instance().deleteAllCookies();
    } on Object catch (error) {
      debugPrint('YouTube: could not clear the WebView cookies: $error');
    }
  }

  @override
  State<YouTubeWebSignInScreen> createState() => _YouTubeWebSignInScreenState();
}

class _YouTubeWebSignInScreenState extends State<YouTubeWebSignInScreen> {
  static const String _signInUrl = 'https://accounts.google.com/ServiceLogin'
      '?service=youtube'
      '&continue=https%3A%2F%2Fwww.youtube.com%2F'
      '&hl=en';

  /// This engine has no authenticator: Android bridges WebAuthn to Credential
  /// Manager only for a site the app owns (digital asset links), and WKWebView
  /// needs Apple's web-browser entitlement. Reporting that to the page is
  /// accurate, and stops Google from leading with a step that cannot finish.
  static const String kNoWebAuthnScript = '''
(function () {
  try {
    Object.defineProperty(navigator, 'credentials', {
      configurable: true,
      get: function () { return undefined; }
    });
  } catch (e) {}
  try { delete window.PublicKeyCredential; } catch (e) {}
})();
''';

  static const String _clickTryAnotherWayScript = '''
(function () {
  var nodes = document.querySelectorAll('button, a, [role="button"]');
  for (var i = 0; i < nodes.length; i++) {
    var text = (nodes[i].innerText || '').toLowerCase();
    if (text.indexOf('try another way') !== -1) {
      nodes[i].click();
      return true;
    }
  }
  return false;
})();
''';

  Timer? _poll;
  InAppWebViewController? _activeController;
  bool _looking = false;
  bool _finished = false;
  bool _failed = false;
  bool _blockedNoticeShown = false;
  bool _passkeyPage = false;
  bool _autoSkippedPasskey = false;

  @override
  void initState() {
    super.initState();
    // The cookie jar is the source of truth, not the navigation events: the
    // sign-in form posts to several origins before youtube.com loads, and the
    // final load event can be missed entirely.
    _poll = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _harvest(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _harvest() async {
    if (_looking || _finished || !mounted) return;
    _looking = true;
    try {
      final cookies = await _readCookies();
      if (!mounted || _finished) return;
      if (YouTubeWebSession.fromCookies(cookies) == null) return;
      _finished = true;
      _poll?.cancel();
      Navigator.of(context).pop(cookies);
    } on Object catch (error) {
      debugPrint('YouTube: could not read the WebView cookies: $error');
    } finally {
      _looking = false;
    }
  }

  Future<Map<String, String>> _readCookies() async {
    final manager = CookieManager.instance();
    final result = <String, String>{};
    for (final url in const [
      'https://www.youtube.com',
      'https://m.youtube.com',
    ]) {
      final cookies = await manager.getCookies(url: WebUri(url));
      for (final cookie in cookies) {
        final domain = cookie.domain;
        if (domain != null &&
            domain.isNotEmpty &&
            !YouTubeCookieParser.isYouTubeDomain(domain)) {
          continue;
        }
        final value = cookie.value?.toString() ?? '';
        if (cookie.name.isEmpty || value.isEmpty) continue;
        result[cookie.name] = value;
      }
    }
    return result;
  }

  /// Google answers the sign-in form with "This browser or app may not be
  /// secure" for embedded browsers. It is a policy block, not something the
  /// page can be talked out of, so the only useful response is to say so and
  /// hand over the cookie path immediately instead of letting the user retype
  /// a password that will never be accepted.
  Future<void> _checkForBlockedSignIn(InAppWebViewController controller) async {
    if (_finished || !mounted) return;
    try {
      final raw = await controller.evaluateJavascript(
        source: 'document.body ? document.body.innerText.slice(0, 600) : ""',
      );
      final text = raw?.toString().toLowerCase() ?? '';
      final blocked = text.contains('may not be secure') ||
          text.contains('try using a different browser');
      if (!mounted) return;
      if (blocked) {
        await _showBlockedNotice();
        return;
      }
      // Only the challenge itself, not the method list that follows it, which
      // also mentions passkeys.
      final passkey = text.contains('use your passkey') ||
          (text.contains('passkey') && text.contains('fingerprint'));
      if (passkey != _passkeyPage) setState(() => _passkeyPage = passkey);
      if (!passkey) {
        _autoSkippedPasskey = false;
      } else if (!_autoSkippedPasskey) {
        _autoSkippedPasskey = true;
        await _usePasswordInstead();
      }
    } on Object catch (error) {
      debugPrint('YouTube: could not inspect the sign-in page: $error');
    }
  }

  Future<void> _showBlockedNotice() async {
    if (_blockedNoticeShown || !mounted) return;
    _blockedNoticeShown = true;
    final l10n = context.l10n;
    final useCookies = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.youtubeAccountWebBlockedTitle),
        content: Text(l10n.youtubeAccountWebBlockedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.youtubeAccountWebTroubleAction),
          ),
        ],
      ),
    );
    if (useCookies == true) await _useCookies();
  }

  /// Google offers a passkey before the password. WebAuthn cannot work here:
  /// Android only bridges it to Credential Manager for a site the app owns, and
  /// WKWebView needs Apple's web-browser entitlement, so `accounts.google.com`
  /// is out of reach on both. [kNoWebAuthnScript] therefore reports the truth
  /// to the page, and this opens the password route behind "Try another way"
  /// for the case where Google shows the passkey step anyway.
  Future<void> _usePasswordInstead() async {
    final controller = _activeController;
    if (controller == null) return;
    try {
      final clicked = await controller.evaluateJavascript(
        source: _clickTryAnotherWayScript,
      );
      if (clicked == true && mounted) {
        setState(() => _passkeyPage = false);
      }
    } on Object catch (error) {
      debugPrint('YouTube: could not open the password option: $error');
    }
  }

  Future<void> _useCookies() async {
    // The import screen signs in itself; a true result means the account screen
    // behind this one is already happy, so this screen has nothing left to do.
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const YouTubeCookieImportScreen(),
      ),
    );
    if (!mounted || imported != true) return;
    _finished = true;
    _poll?.cancel();
    Navigator.of(context).pop();
  }

  /// The UA has to describe the engine the page is actually running on. A
  /// Chrome UA over WebKit (Apple platforms) is a fingerprint mismatch Google
  /// rejects outright, so Apple gets a Safari UA and Chromium platforms keep a
  /// Chrome-family one.
  ///
  /// Android prefers the engine's own UA minus the `wv` token ([_prepare]): a
  /// hand-written one pins a browser version that goes stale, and Google treats
  /// both a stale version and the `wv` marker as unsupported.
  static String get _userAgent {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return kYouTubeWebUserAgent;
      case TargetPlatform.iOS:
        return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
            'Mobile/15E148 Safari/604.1';
      case TargetPlatform.macOS:
        return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
            'Safari/605.1.15';
      default:
        return kYouTubeWebUserAgent;
    }
  }

  /// Must run before the first load: the sign-in screen has to start from a
  /// clean jar, otherwise a half-finished earlier attempt is presented to
  /// Google as a corrupt session and the form loops instead of loading.
  Future<void> _prepare(InAppWebViewController controller) async {
    _activeController = controller;
    try {
      await controller.addUserScript(
        userScript: UserScript(
          source: kNoWebAuthnScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    } on Object catch (error) {
      debugPrint('YouTube: could not configure WebAuthn reporting: $error');
    }
    try {
      await CookieManager.instance().deleteAllCookies();
    } on Object catch (error) {
      debugPrint('YouTube: could not reset the WebView cookies: $error');
    }
    final settings = _settings(await _resolvedUserAgent());
    try {
      await controller.setSettings(settings: settings);
    } on Object catch (error) {
      debugPrint('YouTube: could not apply the WebView settings: $error');
    }
    if (!mounted) return;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(_signInUrl)));
  }

  Future<String> _resolvedUserAgent() async {
    if (defaultTargetPlatform != TargetPlatform.android) return _userAgent;
    try {
      final raw = await InAppWebViewController.getDefaultUserAgent();
      if (raw.trim().isNotEmpty) return _withoutWebViewMarkers(raw);
    } on Object catch (error) {
      debugPrint('YouTube: could not read the WebView user agent: $error');
    }
    return _userAgent;
  }

  /// Android's WebView UA is the bundled Chrome UA plus `; wv` and a
  /// `Version/x` token. Both are explicit "embedded browser" signals, so this
  /// leaves what a plain Chrome reports on the same device.
  static String _withoutWebViewMarkers(String userAgent) => userAgent
      .replaceAll(RegExp(r';\s*wv\b'), '')
      .replaceAll(RegExp(r'\s*Version/[\d.]+'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  static InAppWebViewSettings _settings(String userAgent) =>
      InAppWebViewSettings(
        userAgent: userAgent,
        javaScriptEnabled: true,
        thirdPartyCookiesEnabled: true,
        sharedCookiesEnabled: true,
        isInspectable: false,
        useShouldOverrideUrlLoading: false,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
      );

  /// Google's account flow opens windows (the account chooser, some MFA
  /// prompts). Without supportMultipleWindows those clicks silently do nothing
  /// and the form spins forever, so the popup is loaded in place.
  Future<bool?> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final url = action.request.url;
    if (url == null) return false;
    await controller.loadUrl(urlRequest: URLRequest(url: url));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppTopBar(
        title: l10n.youtubeAccountWebTitle,
        actions: [
          IconButton(
            tooltip: l10n.youtubeAccountWebTroubleAction,
            onPressed: _useCookies,
            icon: const AppIcon(AppIcons.download, size: AppTokens.iconMd),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s4,
                AppTokens.s2,
                AppTokens.s4,
                AppTokens.s2,
              ),
              child: Text(
                l10n.youtubeAccountWebFailed,
                style: AppTokens.rowSubtitle(context),
              ),
            ),
          if (_passkeyPage)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s4,
                AppTokens.s2,
                AppTokens.s4,
                0,
              ),
              child: AppSurface(
                accentTint: AppTokens.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.youtubeAccountWebPasskeyTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppTokens.s1),
                    Text(
                      l10n.youtubeAccountWebPasskeyBody,
                      style: AppTokens.rowSubtitle(context),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _usePasswordInstead,
                        child: Text(l10n.youtubeAccountWebPasskeyAction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: !YouTubeWebSignInScreen.isSupported
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTokens.s5),
                      child: Text(
                        l10n.youtubeAccountWebUnsupported,
                        textAlign: TextAlign.center,
                        style: AppTokens.rowSubtitle(context),
                      ),
                    ),
                  )
                : InAppWebView(
                    onWebViewCreated: _prepare,
                    onCreateWindow: _onCreateWindow,
                    onLoadStop: (controller, url) {
                      if (mounted && _failed) setState(() => _failed = false);
                      _harvest();
                      // Only the block page matters; probing every navigation
                      // costs a round trip per redirect in the sign-in chain.
                      final path = url?.path ?? '';
                      if (path.contains('signin') ||
                          path.contains('challenge')) {
                        _checkForBlockedSignIn(controller);
                      }
                    },
                    onReceivedError: (controller, request, error) {
                      if (!mounted) return;
                      if (request.isForMainFrame ?? false) {
                        setState(() => _failed = true);
                      }
                    },
                    onReceivedHttpError: (controller, request, error) {
                      if (!mounted) return;
                      if (request.isForMainFrame ?? false) {
                        setState(() => _failed = true);
                      }
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s4,
                AppTokens.s1,
                AppTokens.s4,
                AppTokens.s2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    onPressed: _useCookies,
                    child: Text(l10n.youtubeAccountWebTrouble),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
