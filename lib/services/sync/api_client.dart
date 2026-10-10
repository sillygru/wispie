import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../shared_http_client.dart';

typedef ByteProgress = void Function(int done, int total);

class SyncApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final int? retryAfter;
  final Map<String, dynamic> extra;

  const SyncApiException(
    this.status,
    this.code,
    this.message, {
    this.retryAfter,
    this.extra = const {},
  });

  bool get isHeadMoved => status == 409 && code == 'head_moved';
  bool get isEpochChanged => status == 412 && code == 'epoch_changed';
  bool get isGone => status == 410;
  bool get isQuota => status == 507;
  bool get isNetwork => status == 0;

  @override
  String toString() => 'SyncApiException($status $code: $message)';
}

class SyncTokens {
  final String access;
  final String refresh;
  const SyncTokens(this.access, this.refresh);
}

class SyncServerInfo {
  final bool registrationOpen;
  final int powBits;
  final int maxDeltaBytes;
  final int chunkBytes;
  final int quotaBytes;
  final String name;
  final int apiVersion;
  const SyncServerInfo({
    this.name = 'wispie-sync',
    this.apiVersion = 1,
    required this.registrationOpen,
    required this.powBits,
    required this.maxDeltaBytes,
    required this.chunkBytes,
    required this.quotaBytes,
  });
}

class SyncState {
  final int epoch;
  final int headSeq;
  final String? snapshotId;
  final int snapshotBaseSeq;
  final int snapshotSize;
  final int deltasSinceSnapshot;
  final int bytesSinceSnapshot;
  final bool compactionRecommended;
  final int usageBytes;
  final int quotaBytes;

  const SyncState({
    required this.epoch,
    required this.headSeq,
    required this.snapshotId,
    required this.snapshotBaseSeq,
    required this.snapshotSize,
    required this.deltasSinceSnapshot,
    required this.bytesSinceSnapshot,
    required this.compactionRecommended,
    required this.usageBytes,
    required this.quotaBytes,
  });

  bool get hasSnapshot => snapshotId != null;

  factory SyncState.fromJson(Map<String, dynamic> j) {
    final snap = j['snapshot'] as Map<String, dynamic>?;
    return SyncState(
      epoch: j['epoch'] as int,
      headSeq: j['head_seq'] as int,
      snapshotId: snap?['id'] as String?,
      snapshotBaseSeq: (snap?['base_seq'] as int?) ?? 0,
      snapshotSize: (snap?['size'] as int?) ?? 0,
      deltasSinceSnapshot: j['deltas_since_snapshot'] as int,
      bytesSinceSnapshot: j['bytes_since_snapshot'] as int,
      compactionRecommended: j['compaction_recommended'] as bool,
      usageBytes: j['usage_bytes'] as int,
      quotaBytes: j['quota_bytes'] as int,
    );
  }
}

class DeltaFrame {
  final int seq;
  final Uint8List blob;
  const DeltaFrame(this.seq, this.blob);
}

class DeltaPage {
  final List<DeltaFrame> frames;
  final int head;
  final bool more;
  const DeltaPage(this.frames, this.head, this.more);
}

class SnapshotMeta {
  final String id;
  final int baseSeq;
  final int epoch;
  const SnapshotMeta(this.id, this.baseSeq, this.epoch);
}

class LoginResult {
  final String accountId;
  final Uint8List? wrappedByPw;
  final SyncTokens tokens;
  const LoginResult(this.accountId, this.wrappedByPw, this.tokens);
}

class RegisterBegin {
  final String accountId;
  final String challenge;
  final int bits;
  const RegisterBegin(this.accountId, this.challenge, this.bits);
}

/// Typed client for the `/v1` sync API (plan_sync.md section 1.7).
class SyncApiClient {
  SyncApiClient({
    required String baseUrl,
    this.tokens,
    this.onTokensChanged,
    HttpClient? httpClient,
    Future<void> Function(Duration)? sleep,
  })  : baseUri = parseBaseUrl(baseUrl),
        _http = httpClient ?? SharedHttpClient.instance,
        _sleep = sleep ?? Future.delayed;

  final Uri baseUri;
  final HttpClient _http;
  final Future<void> Function(Duration) _sleep;
  SyncTokens? tokens;

  /// Persist rotated tokens; called with null when the session is dead.
  final Future<void> Function(SyncTokens?)? onTokensChanged;

  Future<void>? _refreshing;

  static const int _maxRetries = 2;
  static const int _maxAutoRetryAfter = 30;

  /// True for hosts where plain http is tolerated (loopback / private ranges).
  static bool isPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' ||
        h.endsWith('.localhost') ||
        h.endsWith('.local') ||
        h.endsWith('.ts.net')) {
      return true;
    }
    final ip = InternetAddress.tryParse(h);
    if (ip == null) return false;
    if (ip.isLoopback || ip.isLinkLocal) return true;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      return b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168) ||
          // RFC 6598 shared address space. Excluded from the RFC 1918 list
          // because carriers use it for subscriber NAT, but Tailscale assigns
          // tailnet nodes here and the range is not publicly routable.
          (b[0] == 100 && b[1] >= 64 && b[1] <= 127);
    }
    return (b[0] & 0xfe) == 0xfc;
  }

  /// https always; http only for private hosts. Callers should warn for http.
  static Uri parseBaseUrl(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null || !u.hasAuthority || u.host.isEmpty) {
      throw const SyncApiException(0, 'bad_url', 'Invalid server URL');
    }
    if (u.scheme == 'https') return _trim(u);
    if (u.scheme == 'http' && isPrivateHost(u.host)) return _trim(u);
    throw const SyncApiException(
      0,
      'insecure_url',
      'Plain http is only allowed for localhost and private network hosts',
    );
  }

  static bool isInsecure(String url) =>
      Uri.tryParse(url.trim())?.scheme == 'http';

  static Uri _trim(Uri u) {
    var path = u.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return u.replace(path: path, query: '', fragment: '');
  }

  Uri _uri(String path, [Map<String, String>? query]) => baseUri.replace(
        path: '${baseUri.path}/v1$path',
        queryParameters: query,
      );

  // ---- core ----

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? json,
    List<int>? body,
    Map<String, String>? headers,
    String? bearer,
    bool auth = true,
    ByteProgress? onSendProgress,
  }) async {
    var attempt = 0;
    var refreshed = false;
    while (true) {
      HttpClientResponse res;
      try {
        final req = await _http.openUrl(method, _uri(path, query));
        headers?.forEach(req.headers.set);
        final token = bearer ?? (auth ? tokens?.access : null);
        if (token != null) {
          req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
        List<int>? payload = body;
        if (json != null) {
          req.headers.contentType = ContentType.json;
          payload = utf8.encode(jsonEncode(json));
        } else if (body != null) {
          req.headers.contentType = ContentType.binary;
        }
        if (payload != null) {
          req.contentLength = payload.length;
          const slice = 64 * 1024;
          for (var i = 0; i < payload.length; i += slice) {
            final end = i + slice > payload.length ? payload.length : i + slice;
            req.add(payload.sublist(i, end));
            if (onSendProgress != null) {
              await req.flush();
              onSendProgress(end, payload.length);
            }
          }
        }
        res = await req.close();
      } on SocketException catch (e) {
        throw SyncApiException(0, 'network', e.message);
      } on HttpException catch (e) {
        throw SyncApiException(0, 'network', e.message);
      } on TlsException catch (e) {
        throw SyncApiException(0, 'tls', e.message);
      } on TimeoutException {
        throw const SyncApiException(0, 'timeout', 'Request timed out');
      }

      if (res.statusCode < 400) return res;
      final err = await _readError(res);

      if (res.statusCode == 401 &&
          auth &&
          bearer == null &&
          !refreshed &&
          tokens?.refresh != null) {
        refreshed = true;
        await _refreshSingleFlight();
        continue;
      }
      final retryable = res.statusCode == 429 || res.statusCode == 503;
      if (retryable &&
          attempt < _maxRetries &&
          err.retryAfter != null &&
          err.retryAfter! <= _maxAutoRetryAfter) {
        attempt++;
        await _sleep(Duration(seconds: err.retryAfter!));
        continue;
      }
      throw err;
    }
  }

  Future<SyncApiException> _readError(HttpClientResponse res) async {
    final text = await utf8.decodeStream(res);
    var code = 'http_${res.statusCode}';
    var message = text;
    int? retry = int.tryParse(res.headers.value('retry-after') ?? '');
    var extra = <String, dynamic>{};
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      code = (j['error'] as String?) ?? code;
      message = (j['message'] as String?) ?? message;
      retry = (j['retry_after'] as int?) ?? retry;
      extra = Map.of(j)
        ..remove('error')
        ..remove('message')
        ..remove('retry_after');
    } catch (_) {}
    return SyncApiException(
      res.statusCode,
      code,
      message,
      retryAfter: retry,
      extra: extra,
    );
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Object? json,
    Map<String, String>? query,
    String? bearer,
    bool auth = true,
  }) async {
    final res = await _send(
      method,
      path,
      json: json ?? (method == 'GET' ? null : const <String, dynamic>{}),
      query: query,
      bearer: bearer,
      auth: auth,
    );
    final text = await utf8.decodeStream(res);
    return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> _refreshSingleFlight() {
    return _refreshing ??= () async {
      try {
        final refresh = tokens?.refresh;
        if (refresh == null) {
          throw const SyncApiException(401, 'unauthorized', 'Not logged in');
        }
        final j = await _json(
          'POST',
          '/auth/refresh',
          json: {'refresh_token': refresh},
          auth: false,
        );
        await _setTokens(_tokensFrom(j));
      } on SyncApiException catch (e) {
        if (e.status == 401 || e.status == 400) {
          await _setTokens(null);
          throw const SyncApiException(
            401,
            'session_expired',
            'Session expired, log in again',
          );
        }
        rethrow;
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<void> _setTokens(SyncTokens? t) async {
    tokens = t;
    await onTokensChanged?.call(t);
  }

  SyncTokens _tokensFrom(Map<String, dynamic> j) =>
      SyncTokens(j['access_token'] as String, j['refresh_token'] as String);

  // ---- info + auth ----

  Future<SyncServerInfo> info() async {
    final j = await _json('GET', '/info', auth: false);
    if (j['name'] != 'wispie-sync') {
      throw const SyncApiException(0, 'not_wispie', 'Not a Wispie sync server');
    }
    final l = j['limits'] as Map<String, dynamic>;
    return SyncServerInfo(
      apiVersion: (j['api'] as num?)?.toInt() ?? 1,
      registrationOpen: j['registration_open'] as bool,
      powBits: j['pow_bits'] as int,
      maxDeltaBytes: l['max_delta_bytes'] as int,
      chunkBytes: l['chunk_bytes'] as int,
      quotaBytes: l['quota_bytes'] as int,
    );
  }

  Future<({Uint8List salt, Map<String, dynamic> kdf})> prelogin(
    String username,
  ) async {
    final j = await _json(
      'POST',
      '/auth/prelogin',
      json: {'username': username},
      auth: false,
    );
    return (
      salt: _b64(j['salt'] as String),
      kdf: j['kdf'] as Map<String, dynamic>
    );
  }

  Future<RegisterBegin> registerBegin(String username) async {
    final j = await _json(
      'POST',
      '/auth/register/begin',
      json: {'username': username},
      auth: false,
    );
    final pow = j['pow'] as Map<String, dynamic>;
    return RegisterBegin(
      j['account_id'] as String,
      pow['challenge'] as String,
      pow['bits'] as int,
    );
  }

  Future<void> registerFinish({
    required String accountId,
    required String username,
    required String powNonce,
    required String powChallenge,
    required Uint8List salt,
    required Map<String, dynamic> kdf,
    required Uint8List authKey,
    required Uint8List recoveryAuth,
    required Uint8List wrappedByPw,
    required Uint8List wrappedByRk,
    String? deviceLabel,
  }) async {
    final j = await _json(
      'POST',
      '/auth/register/finish',
      auth: false,
      json: {
        'account_id': accountId,
        'username': username,
        'pow_nonce': powNonce,
        'pow_challenge': powChallenge,
        'salt': _enc(salt),
        'kdf': kdf,
        'auth_key': _enc(authKey),
        'recovery_auth': _enc(recoveryAuth),
        'wrapped_by_pw': _enc(wrappedByPw),
        'wrapped_by_rk': _enc(wrappedByRk),
        if (deviceLabel != null) 'device_label': deviceLabel,
      },
    );
    await _setTokens(_tokensFrom(j));
  }

  Future<LoginResult> login(String username, Uint8List authKey) async {
    final j = await _json(
      'POST',
      '/auth/login',
      auth: false,
      json: {'username': username, 'auth_key': _enc(authKey)},
    );
    final t = _tokensFrom(j);
    await _setTokens(t);
    return LoginResult(
      j['account_id'] as String,
      _b64(j['wrapped_by_pw'] as String),
      t,
    );
  }

  Future<void> logout() async {
    try {
      await _json('POST', '/auth/logout');
    } finally {
      await _setTokens(null);
    }
  }

  Future<({String accountId, Uint8List wrappedByRk, String recoverToken})>
      recoverBegin(String username, Uint8List recoveryAuth) async {
    final j = await _json(
      'POST',
      '/auth/recover/begin',
      auth: false,
      json: {'username': username, 'recovery_auth': _enc(recoveryAuth)},
    );
    return (
      accountId: j['account_id'] as String,
      wrappedByRk: _b64(j['wrapped_by_rk'] as String),
      recoverToken: j['recover_token'] as String,
    );
  }

  Future<void> recoverFinish({
    required String recoverToken,
    required Uint8List salt,
    required Map<String, dynamic> kdf,
    required Uint8List authKey,
    required Uint8List wrappedByPw,
  }) async {
    final j = await _json(
      'POST',
      '/auth/recover/finish',
      bearer: recoverToken,
      json: {
        'salt': _enc(salt),
        'kdf': kdf,
        'auth_key': _enc(authKey),
        'wrapped_by_pw': _enc(wrappedByPw),
      },
    );
    await _setTokens(_tokensFrom(j));
  }

  Future<void> changePassword({
    required Uint8List currentAuthKey,
    required Uint8List salt,
    required Map<String, dynamic> kdf,
    required Uint8List authKey,
    required Uint8List wrappedByPw,
  }) =>
      _json(
        'POST',
        '/account/password',
        json: {
          'current_auth_key': _enc(currentAuthKey),
          'salt': _enc(salt),
          'kdf': kdf,
          'auth_key': _enc(authKey),
          'wrapped_by_pw': _enc(wrappedByPw),
        },
      );

  Future<void> replaceRecoveryKey({
    required Uint8List currentAuthKey,
    required Uint8List recoveryAuth,
    required Uint8List wrappedByRk,
  }) =>
      _json(
        'POST',
        '/account/recovery-key',
        json: {
          'current_auth_key': _enc(currentAuthKey),
          'recovery_auth': _enc(recoveryAuth),
          'wrapped_by_rk': _enc(wrappedByRk),
        },
      );

  Future<Map<String, dynamic>> account() => _json('GET', '/account');

  Future<void> deleteAccount(Uint8List authKey) async {
    await _json('DELETE', '/account', json: {'auth_key': _enc(authKey)});
    await _setTokens(null);
  }

  // ---- sync ----

  Future<SyncState> state() async =>
      SyncState.fromJson(await _json('GET', '/sync/state'));

  /// Throws [SyncApiException] with `isGone` when [after] is no longer retained.
  Future<DeltaPage> pullDeltas(
    int after, {
    int maxBytes = 8 * 1024 * 1024,
    ByteProgress? onProgress,
  }) async {
    final res = await _send(
      'GET',
      '/sync/deltas',
      query: {'after': '$after', 'max_bytes': '$maxBytes'},
    );
    final total = res.contentLength;
    final b = BytesBuilder(copy: false);
    await for (final c in res) {
      b.add(c);
      onProgress?.call(b.length, total < 0 ? b.length : total);
    }
    final data = b.takeBytes();
    final bd = ByteData.sublistView(data);
    final frames = <DeltaFrame>[];
    var o = 0;
    while (o < data.length) {
      if (o + 12 > data.length) {
        throw const SyncApiException(0, 'bad_stream', 'Truncated delta stream');
      }
      final seq = bd.getUint64(o);
      final len = bd.getUint32(o + 8);
      o += 12;
      if (o + len > data.length) {
        throw const SyncApiException(0, 'bad_stream', 'Truncated delta frame');
      }
      frames.add(DeltaFrame(seq, Uint8List.sublistView(data, o, o + len)));
      o += len;
    }
    return DeltaPage(
      frames,
      int.parse(res.headers.value('x-wispie-head') ?? '0'),
      res.headers.value('x-wispie-more') == '1',
    );
  }

  /// Returns the assigned seq. 409/412/413/507 surface as [SyncApiException].
  Future<int> pushDelta(
    Uint8List blob, {
    required int epoch,
    required int expectHead,
    ByteProgress? onProgress,
  }) async {
    final res = await _send(
      'POST',
      '/sync/deltas',
      body: blob,
      headers: {
        'X-Wispie-Epoch': '$epoch',
        'X-Wispie-Expect-Head': '$expectHead',
      },
      onSendProgress: onProgress,
    );
    final j = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    return j['seq'] as int;
  }

  /// Downloads the current snapshot into [dest], resuming a partial file via
  /// Range. The caller must delete [dest] if the snapshot id changed.
  Future<SnapshotMeta> downloadSnapshot(
    File dest, {
    ByteProgress? onProgress,
  }) async {
    var have = await dest.exists() ? await dest.length() : 0;
    HttpClientResponse res;
    try {
      res = await _send(
        'GET',
        '/sync/snapshot',
        headers: have > 0 ? {'Range': 'bytes=$have-'} : null,
      );
    } on SyncApiException catch (e) {
      if (e.status != 416) rethrow;
      await dest.delete();
      have = 0;
      res = await _send('GET', '/sync/snapshot');
    }
    final resumed = res.statusCode == 206;
    if (!resumed) have = 0;
    final total = res.contentLength < 0 ? -1 : res.contentLength + have;
    final sink = dest.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    var done = have;
    try {
      await for (final c in res) {
        sink.add(c);
        done += c.length;
        onProgress?.call(done, total < 0 ? done : total);
      }
    } finally {
      await sink.close();
    }
    return SnapshotMeta(
      res.headers.value('x-wispie-snapshot-id') ?? '',
      int.parse(res.headers.value('x-wispie-base-seq') ?? '0'),
      int.parse(res.headers.value('x-wispie-epoch') ?? '0'),
    );
  }

  Future<({String id, int chunkBytes})> uploadInit({
    required String kind,
    required int size,
    required int epoch,
    required int baseSeq,
  }) async {
    final j = await _json(
      'POST',
      '/sync/uploads',
      json: {'kind': kind, 'size': size, 'epoch': epoch, 'base_seq': baseSeq},
    );
    return (id: j['upload_id'] as String, chunkBytes: j['chunk_bytes'] as int);
  }

  Future<int> uploadStatus(String id) async =>
      (await _json('GET', '/sync/uploads/$id'))['received'] as int;

  Future<int> uploadChunk(String id, int offset, List<int> chunk) async {
    final res = await _send(
      'PUT',
      '/sync/uploads/$id',
      query: {'offset': '$offset'},
      body: chunk,
    );
    final j = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    return j['received'] as int;
  }

  Future<SyncState> uploadCommit(String id) async =>
      SyncState.fromJson(await _json('POST', '/sync/uploads/$id/commit'));

  Future<void> uploadAbort(String id) => _json('DELETE', '/sync/uploads/$id');

  /// Init + chunked PUT + commit. Pass [resumeId] to continue an interrupted
  /// upload of the same blob; an offset mismatch resyncs from the server.
  Future<SyncState> uploadBlob(
    Uint8List blob, {
    required String kind,
    required int epoch,
    required int baseSeq,
    String? resumeId,
    ByteProgress? onProgress,
    void Function(String uploadId)? onInit,
  }) async {
    String id;
    int chunk;
    var offset = 0;
    if (resumeId != null) {
      id = resumeId;
      chunk = (await info()).chunkBytes;
      offset = await uploadStatus(id);
    } else {
      final init = await uploadInit(
        kind: kind,
        size: blob.length,
        epoch: epoch,
        baseSeq: baseSeq,
      );
      id = init.id;
      chunk = init.chunkBytes;
      onInit?.call(id);
    }
    while (offset < blob.length) {
      final end = offset + chunk > blob.length ? blob.length : offset + chunk;
      try {
        offset = await uploadChunk(
            id, offset, Uint8List.sublistView(blob, offset, end));
      } on SyncApiException catch (e) {
        if (e.status == 409 && e.extra['received'] is int) {
          offset = e.extra['received'] as int;
          continue;
        }
        rethrow;
      }
      onProgress?.call(offset, blob.length);
    }
    return uploadCommit(id);
  }

  static String _enc(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  static Uint8List _b64(String s) {
    final pad = (4 - s.length % 4) % 4;
    return Uint8List.fromList(base64Url.decode(s + '=' * pad));
  }
}
