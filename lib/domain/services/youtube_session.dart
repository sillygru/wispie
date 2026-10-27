// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A signed-in YouTube *web* session, expressed as the cookies a browser holds
/// after logging in at youtube.com.
///
/// This is deliberately not OAuth: it needs no developer client, no consent
/// screen and no per-app API quota. Requests are signed the same way the
/// YouTube web client signs them, with `SAPISIDHASH` over the session's
/// `SAPISID`, so Google treats them as an ordinary signed-in browser.
class YouTubeWebSession {
  /// Cookie name -> value, in the order they were collected so a header stays
  /// stable between requests.
  final Map<String, String> cookies;

  /// Which Google account in this browser session to act as. `X-Goog-AuthUser`
  /// indexes the account switcher; 0 is the default account.
  final int authUser;

  const YouTubeWebSession({required this.cookies, this.authUser = 0});

  /// The origin the hash is bound to. YouTube's own web client uses its www
  /// origin, and a hash minted for another origin is rejected. YouTube Music is
  /// a separate origin whose client needs a hash over its own URL.
  static const String origin = 'https://www.youtube.com';
  static const String musicOrigin = 'https://music.youtube.com';

  /// Cookies that can sign a request. `SAPISID` is present on youtube.com
  /// sessions; `__Secure-3PAPISID` is the same secret under the 3P cookie set.
  static const List<String> authCookieNames = [
    'SAPISID',
    '__Secure-3PAPISID',
  ];

  /// Builds a session from a bag of cookies, or returns null when the bag
  /// cannot sign anything (the user is not actually signed in to YouTube).
  static YouTubeWebSession? fromCookies(
    Map<String, String> cookies, {
    int authUser = 0,
  }) {
    final cleaned = <String, String>{};
    for (final entry in cookies.entries) {
      final name = entry.key.trim();
      final value = entry.value.trim();
      if (name.isEmpty || value.isEmpty) continue;
      cleaned[name] = value;
    }
    if (!cleaned.keys.any(authCookieNames.contains)) return null;
    return YouTubeWebSession(cookies: cleaned, authUser: authUser);
  }

  /// The secret the signature is derived from.
  String? get secret {
    for (final name in authCookieNames) {
      final value = cookies[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  bool get isUsable => secret != null;

  /// `name=value; name=value` for the `Cookie` header.
  String get cookieHeader =>
      cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');

  /// `SAPISIDHASH <seconds>_<sha1("<seconds> <secret> <origin>")>`.
  ///
  /// The timestamp is part of the hash, so this is minted per request batch
  /// rather than stored.
  String authorizationHeader(DateTime now, {String origin = origin}) {
    final secret = this.secret;
    if (secret == null) return '';
    final seconds = now.millisecondsSinceEpoch ~/ 1000;
    final digest = sha1.convert(utf8.encode('$seconds $secret $origin'));
    return 'SAPISIDHASH ${seconds}_$digest';
  }

  /// Headers that make a request act as this account. The transport adds its
  /// own client identity on top.
  Map<String, String> authHeaders(DateTime now, {String origin = origin}) {
    final authorization = authorizationHeader(now, origin: origin);
    return {
      if (authorization.isNotEmpty) 'Authorization': authorization,
      'X-Goog-AuthUser': '$authUser',
      'Cookie': cookieHeader,
    };
  }

  Map<String, Object?> toJson() => {
        'cookies': cookies,
        'authUser': authUser,
      };

  static YouTubeWebSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final raw = json['cookies'];
    if (raw is! Map) return null;
    final cookies = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is String) cookies['${entry.key}'] = value;
    }
    final authUser = json['authUser'];
    return fromCookies(
      cookies,
      authUser: authUser is int ? authUser : int.tryParse('$authUser') ?? 0,
    );
  }

  /// Merges [other] on top of this session. Used when a later harvest finds a
  /// rotated cookie without having re-read the whole jar.
  YouTubeWebSession merge(YouTubeWebSession other) {
    return YouTubeWebSession(
      cookies: {...cookies, ...other.cookies},
      authUser: other.authUser,
    );
  }
}

/// Reads cookies out of the shapes people actually have on hand: a `Cookie`
/// request header copied from devtools, a Netscape `cookies.txt` export, or a
/// JSON list from a cookie-export extension.
///
/// Browsers keep the sign-in cookies HttpOnly, so they never appear in
/// `document.cookie`; a `Cookie` header from a network request or an exported
/// jar is the only way to get them. That is also why this parser exists at all
/// on desktop, where no WebView is available to read the jar directly.
class YouTubeCookieParser {
  const YouTubeCookieParser._();

  /// Cookie attributes that can appear after a `Cookie:` header was
  /// mistakenly pasted from a `Set-Cookie` line.
  static const Set<String> _attributes = {
    'path',
    'domain',
    'expires',
    'max-age',
    'secure',
    'httponly',
    'samesite',
    'priority',
    'version',
    'comment',
  };

  /// YouTube scopes its sign-in cookies to `.youtube.com`; a jar for another
  /// site is not a YouTube session even if it has a cookie named `SAPISID`.
  static bool isYouTubeDomain(String domain) {
    final value = domain.trim().toLowerCase().replaceFirst('#httponly_', '');
    return value == 'youtube.com' || value.endsWith('.youtube.com');
  }

  /// Every cookie found in [raw], or an empty map when nothing parses.
  static Map<String, String> parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const {};
    if (text.startsWith('[') || text.startsWith('{')) {
      final json = _parseJson(text);
      if (json.isNotEmpty) return json;
    }
    if (_looksNetscape(text)) {
      final netscape = _parseNetscape(text);
      if (netscape.isNotEmpty) return netscape;
    }
    return _parseHeader(text);
  }

  static Map<String, String> _parseHeader(String text) {
    var value = text;
    final lower = value.toLowerCase();
    if (lower.startsWith('cookie:')) {
      value = value.substring(value.indexOf(':') + 1);
    }
    final result = <String, String>{};
    for (final part in value.split(';')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final equals = trimmed.indexOf('=');
      if (equals <= 0) continue;
      final name = trimmed.substring(0, equals).trim();
      final cookieValue = trimmed.substring(equals + 1).trim();
      if (name.isEmpty || cookieValue.isEmpty) continue;
      if (_attributes.contains(name.toLowerCase())) continue;
      result[name] = cookieValue;
    }
    return result;
  }

  static bool _looksNetscape(String text) {
    for (final line in const LineSplitter().convert(text)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Comment lines precede the jar; `#HttpOnly_` marks a real row.
      if (trimmed.startsWith('#') && !trimmed.startsWith('#HttpOnly_')) {
        continue;
      }
      return line.split('\t').length >= 7;
    }
    return false;
  }

  static Map<String, String> _parseNetscape(String text) {
    final result = <String, String>{};
    for (final line in const LineSplitter().convert(text)) {
      var row = line;
      if (row.trim().isEmpty) continue;
      if (row.startsWith('#HttpOnly_')) {
        row = row.substring('#HttpOnly_'.length);
      } else if (row.startsWith('#')) {
        continue;
      }
      final fields = row.split('\t');
      if (fields.length < 7) continue;
      if (!isYouTubeDomain(fields[0])) continue;
      final name = fields[5].trim();
      final value = fields[6].trim();
      if (name.isEmpty || value.isEmpty) continue;
      result[name] = value;
    }
    return result;
  }

  static Map<String, String> _parseJson(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return const {};
    }
    final entries = decoded is List
        ? decoded
        : decoded is Map && decoded['cookies'] is List
            ? decoded['cookies'] as List
            : const [];
    final result = <String, String>{};
    for (final entry in entries) {
      if (entry is! Map) continue;
      final name = entry['name']?.toString().trim() ?? '';
      final value = entry['value']?.toString().trim() ?? '';
      if (name.isEmpty || value.isEmpty) continue;
      final domain = entry['domain']?.toString();
      if (domain != null && domain.isNotEmpty && !isYouTubeDomain(domain)) {
        continue;
      }
      result[name] = value;
    }
    return result;
  }
}
