// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/services/youtube_library.dart';
import '../domain/services/youtube_session.dart';
import 'shared_http_client.dart';
import 'sync/account_service.dart'
    show SecretStore, SecretStoreException, SecureSecretStore;

/// What the app knows about the YouTube account right now.
class YouTubeAccountSnapshot {
  final bool signedIn;
  final YouTubeAccountProfile? profile;

  /// Set when the stored cookies stopped working and the user has to sign in
  /// again — a revoked session or a cleared browser jar, not a network hiccup.
  final bool sessionExpired;

  const YouTubeAccountSnapshot({
    required this.signedIn,
    this.profile,
    this.sessionExpired = false,
  });

  static const YouTubeAccountSnapshot empty = YouTubeAccountSnapshot(
    signedIn: false,
  );
}

/// Raised when an account operation needs a session and there is none.
class YouTubeAccountSignedOutException implements Exception {
  const YouTubeAccountSignedOutException();
  @override
  String toString() => 'YouTubeAccountSignedOutException';
}

/// Cookie session lifecycle for the signed-in YouTube account.
///
/// Signing in happens in a WebView (or by pasting an exported cookie jar); what
/// this class owns is the part after that: keeping the cookies, proving they
/// still sign requests, and telling the UI when they do not. There is no token
/// refresh to manage — the signature is derived from `SAPISID` on every
/// request — so the only failure mode is the session itself going away.
///
/// Cookies live in secure storage, are never written to settings, and never
/// leave the device except as a `Cookie` header to youtube.com.
class YouTubeAccountService {
  YouTubeAccountService({
    SecretStore? secrets,
    HttpClient? client,
    DateTime Function()? clock,
  })  : _secrets = secrets ?? SecureSecretStore(),
        _client = client,
        _clock = clock ?? DateTime.now;

  static final YouTubeAccountService instance = YouTubeAccountService();

  static const String _sessionKey = 'youtube.web.session';
  static const String _profileKey = 'youtube.web.profile';

  final SecretStore _secrets;
  final HttpClient? _client;
  final DateTime Function() _clock;

  YouTubeWebSession? _session;
  YouTubeAccountProfile? _profile;
  YouTubeLibraryApi? _api;
  bool _sessionExpired = false;

  YouTubeAccountProfile? get cachedProfile => _profile;

  bool get isSignedIn => _session != null && !_sessionExpired;

  YouTubeAccountSnapshot get snapshot => YouTubeAccountSnapshot(
        signedIn: isSignedIn,
        profile: _profile,
        sessionExpired: _sessionExpired,
      );

  /// Loads the stored session and profile. Safe to call twice.
  Future<YouTubeAccountSnapshot> load() async {
    _session ??= await _readSession();
    _profile ??= await _readProfile();
    return snapshot;
  }

  /// Accepts a harvested cookie jar, proves it signs a real request, then
  /// stores it.
  ///
  /// Validation is the point: a browser can hold youtube.com cookies for a
  /// signed-out visitor, and importing those would leave the UI offering
  /// playlist actions that always fail.
  Future<YouTubeAccountProfile?> signIn(Map<String, String> cookies) async {
    final session = YouTubeWebSession.fromCookies(cookies);
    if (session == null) {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.unauthorized,
        'Those cookies do not include a YouTube sign-in.',
      );
    }

    final previousSession = _session;
    final previousExpired = _sessionExpired;
    _session = session;
    _sessionExpired = false;
    try {
      final profile = await libraryApi().account();
      if (profile == null) {
        throw const YouTubeLibraryException(
          YouTubeLibraryErrorKind.unauthorized,
          'YouTube did not recognise those cookies as a signed-in session.',
        );
      }
      await _storeSession(session);
      await _storeProfile(profile);
      _profile = profile;
      return profile;
    } on Object {
      _session = previousSession;
      _sessionExpired = previousExpired;
      rethrow;
    }
  }

  /// The session to sign a request with, or null when there is none left.
  Future<YouTubeWebSession?> session() async {
    final session = _session ?? await _readSession();
    _session = session;
    if (_sessionExpired) return null;
    return session;
  }

  /// Drops a session YouTube stopped accepting, so the UI offers sign-in again.
  ///
  /// Imported playlists are ordinary local playlists, so this deliberately
  /// touches nothing else: signing out must never cost the user their library.
  Future<void> forgetSession({bool expired = true}) async {
    _session = null;
    _sessionExpired = expired;
    try {
      await _secrets.delete(_sessionKey);
    } on SecretStoreException catch (error) {
      debugPrint('YouTube: could not clear the stored session: $error');
    }
  }

  Future<void> signOut() async {
    await forgetSession(expired: false);
    _profile = null;
    try {
      await _secrets.delete(_profileKey);
    } on SecretStoreException catch (error) {
      debugPrint('YouTube: could not clear the stored profile: $error');
    }
  }

  /// Refreshes the channel name and avatar. A failure leaves the old one.
  Future<void> fetchProfile() async {
    final api = libraryApi();
    final profile = await api.account();
    if (profile == null) {
      throw const YouTubeAccountSignedOutException();
    }
    _profile = profile;
    await _storeProfile(profile);
  }

  /// InnerTube client wired to this service's session.
  YouTubeLibraryApi libraryApi() {
    return _api ??= YouTubeLibraryApi(
      session: session,
      client: _client ?? SharedHttpClient.instance,
      clock: _clock,
    );
  }

  Future<void> _storeSession(YouTubeWebSession session) async {
    await _secrets.write(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> _storeProfile(YouTubeAccountProfile profile) async {
    try {
      await _secrets.write(
        _profileKey,
        jsonEncode({
          'channelId': profile.channelId,
          'title': profile.title,
          'avatarUrl': profile.avatarUrl,
        }),
      );
    } on SecretStoreException catch (error) {
      // A missing name on the signed-in card is not worth failing over.
      debugPrint('YouTube: could not store the account profile: $error');
    }
  }

  Future<YouTubeWebSession?> _readSession() async {
    try {
      final raw = await _secrets.read(_sessionKey);
      if (raw == null || raw.isEmpty) return null;
      return YouTubeWebSession.fromJson(jsonDecode(raw));
    } on Object catch (error) {
      debugPrint('YouTube: could not read the stored session: $error');
      return null;
    }
  }

  Future<YouTubeAccountProfile?> _readProfile() async {
    try {
      final raw = await _secrets.read(_profileKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final title = json['title']?.toString() ?? '';
      if (title.isEmpty) return null;
      return YouTubeAccountProfile(
        channelId: json['channelId']?.toString() ?? '',
        title: title,
        avatarUrl: json['avatarUrl']?.toString(),
      );
    } on Object {
      return null;
    }
  }
}
