import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Outcome of a music-utils request, so callers can tell a definitive
/// "no results" (404) apart from a transient failure (timeout, 5xx, offline)
/// that should be retried on the next app open.
enum MusicUtilsStatus {
  ok,
  notFound,
  transient,
}

class MusicUtilsResult {
  final Object? json;
  final MusicUtilsStatus status;

  const MusicUtilsResult(this.json, this.status);
}

/// Small JSON client for the unified music-utils service.
///
/// The service returns metadata and cover CDN URLs. Wispie remains responsible
/// for downloading artwork bytes into its local cover cache.
class MusicUtilsApiClient {
  static final MusicUtilsApiClient instance = MusicUtilsApiClient._internal();

  MusicUtilsApiClient._internal();

  static const String _defaultBaseUrl = 'https://music.gru0.dev/api';
  static const Duration _timeout = Duration(seconds: 8);

  static String? _userAgent;

  String get baseUrl =>
      const String.fromEnvironment('WISPIE_MUSIC_UTILS_BASE_URL',
          defaultValue: _defaultBaseUrl);

  Future<Object?> getJson(
    String endpoint,
    Map<String, String> params,
  ) async {
    final result = await getJsonResult(endpoint, params);
    return result.status == MusicUtilsStatus.ok ? result.json : null;
  }

  Future<MusicUtilsResult> getJsonResult(
    String endpoint,
    Map<String, String> params,
  ) async {
    final client = HttpClient();
    try {
      final base = Uri.parse(baseUrl);
      final uri = base.replace(
        path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$endpoint',
        queryParameters: params,
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        await _resolveUserAgent(),
      );

      final response = await request.close().timeout(_timeout);
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return const MusicUtilsResult(null, MusicUtilsStatus.notFound);
      }
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        await response.drain<void>();
        return const MusicUtilsResult(null, MusicUtilsStatus.transient);
      }

      final body = await response.transform(utf8.decoder).join();
      return MusicUtilsResult(jsonDecode(body), MusicUtilsStatus.ok);
    } on SocketException catch (_) {
      return const MusicUtilsResult(null, MusicUtilsStatus.transient);
    } on TimeoutException catch (_) {
      return const MusicUtilsResult(null, MusicUtilsStatus.transient);
    } on HttpException catch (_) {
      return const MusicUtilsResult(null, MusicUtilsStatus.transient);
    } on FormatException catch (_) {
      return const MusicUtilsResult(null, MusicUtilsStatus.transient);
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _resolveUserAgent() async {
    final cached = _userAgent;
    if (cached != null) return cached;

    var version = 'dev';
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
    } on Object catch (_) {
      // A descriptive development user agent is still better than the default.
    }

    return _userAgent = 'Wispie/$version (https://github.com/sillygru/wispie)';
  }
}
