import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../data/rust/native_command.dart';
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

  Object? _transport(String op, Map<String, Object?> values) =>
      runCoreCommand('sync_transport', {'op': op, ...values})['result'];

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

      final action = _transport('error', {
        'status': res.statusCode,
        'can_refresh': auth && bearer == null && tokens?.refresh != null,
        'refreshed': refreshed,
        'retry_after': err.retryAfter,
        'attempt': attempt,
      });
      if (action == 'refresh') {
        refreshed = true;
        await _refreshSingleFlight();
        continue;
      }
      if (action == 'wait') {
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

  ({String method, String path, bool auth}) _route(
      String endpoint, String? id) {
    final route = _transport('route', {'endpoint': endpoint, 'id': id}) as Map;
    return (
      method: route['method'] as String,
      path: route['path'] as String,
      auth: route['auth'] as bool,
    );
  }

  Future<HttpClientResponse> _sendRoute(
    String endpoint, {
    String? id,
    Map<String, String>? query,
    List<int>? body,
    Map<String, String>? headers,
    ByteProgress? onSendProgress,
  }) {
    final route = _route(endpoint, id);
    return _send(
      route.method,
      route.path,
      auth: route.auth,
      query: query,
      body: body,
      headers: headers,
      onSendProgress: onSendProgress,
    );
  }

  Future<Map<String, dynamic>> _json(
    String endpoint, {
    String? id,
    Object? json,
    String? bearer,
  }) async {
    final route = _route(endpoint, id);
    final res = await _send(
      route.method,
      route.path,
      json: json ?? (route.method == 'GET' ? null : const <String, dynamic>{}),
      bearer: bearer,
      auth: route.auth,
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
          'refresh',
          json: {'refresh_token': refresh},
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
    final j = await _json('info');
    if (j['name'] != 'wispie-sync') {
      throw const SyncApiException(0, 'not_wispie', 'Not a wispie sync server');
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
      'prelogin',
      json: {'username': username},
    );
    return (
      salt: _b64(j['salt'] as String),
      kdf: j['kdf'] as Map<String, dynamic>
    );
  }

  Future<RegisterBegin> registerBegin(String username) async {
    final j = await _json(
      'register_begin',
      json: {'username': username},
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
      'register_finish',
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
      'login',
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
      await _json('logout');
    } finally {
      await _setTokens(null);
    }
  }

  Future<({String accountId, Uint8List wrappedByRk, String recoverToken})>
      recoverBegin(String username, Uint8List recoveryAuth) async {
    final j = await _json(
      'recover_begin',
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
      'recover_finish',
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
        'change_password',
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
        'replace_recovery',
        json: {
          'current_auth_key': _enc(currentAuthKey),
          'recovery_auth': _enc(recoveryAuth),
          'wrapped_by_rk': _enc(wrappedByRk),
        },
      );

  Future<Map<String, dynamic>> account() => _json('account');

  Future<void> deleteAccount(Uint8List authKey) async {
    await _json('delete_account', json: {'auth_key': _enc(authKey)});
    await _setTokens(null);
  }

  // ---- sync ----

  Future<SyncState> state() async => SyncState.fromJson(await _json('state'));

  /// Throws [SyncApiException] with `isGone` when [after] is no longer retained.
  Future<DeltaPage> pullDeltas(
    int after, {
    int maxBytes = 8 * 1024 * 1024,
    ByteProgress? onProgress,
  }) async {
    final res = await _sendRoute(
      'pull_deltas',
      query: {'after': '$after', 'max_bytes': '$maxBytes'},
    );
    final total = res.contentLength;
    final b = BytesBuilder(copy: false);
    await for (final c in res) {
      b.add(c);
      onProgress?.call(b.length, total < 0 ? b.length : total);
    }
    final data = b.takeBytes();
    final List<dynamic> frameOffsets;
    try {
      frameOffsets = runCoreCommand(
        'sync_transport',
        {'op': 'delta_frames'},
        bytes: data,
      )['result'] as List<dynamic>;
    } on StateError catch (error) {
      throw SyncApiException(0, 'bad_stream', error.message);
    }
    final frames = [
      for (final frame in frameOffsets.cast<Map>())
        DeltaFrame(
          frame['seq'] as int,
          Uint8List.sublistView(
              data, frame['start'] as int, frame['end'] as int),
        ),
    ];
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
    final res = await _sendRoute(
      'push_delta',
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
      final range = _transport('range', {'have': have}) as String?;
      res = await _sendRoute(
        'snapshot',
        headers: range == null ? null : {'Range': range},
      );
    } on SyncApiException catch (e) {
      if (e.status != 416) rethrow;
      await dest.delete();
      have = 0;
      res = await _sendRoute('snapshot');
    }
    final download = _transport('download', {
      'have': have,
      'status': res.statusCode,
      'length': res.contentLength,
    }) as Map;
    final total = download['total'] as int?;
    final sink = dest.openWrite(
      mode: download['append'] == true ? FileMode.append : FileMode.write,
    );
    var done = download['offset'] as int;
    try {
      await for (final c in res) {
        sink.add(c);
        done += c.length;
        onProgress?.call(done, total ?? done);
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
      'upload_init',
      json: {'kind': kind, 'size': size, 'epoch': epoch, 'base_seq': baseSeq},
    );
    return (id: j['upload_id'] as String, chunkBytes: j['chunk_bytes'] as int);
  }

  Future<int> uploadStatus(String id) async =>
      (await _json('upload_status', id: id))['received'] as int;

  Future<int> uploadChunk(String id, int offset, List<int> chunk) async {
    final res = await _sendRoute(
      'upload_chunk',
      id: id,
      query: {'offset': '$offset'},
      body: chunk,
    );
    final j = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    return j['received'] as int;
  }

  Future<SyncState> uploadCommit(String id) async =>
      SyncState.fromJson(await _json('upload_commit', id: id));

  Future<void> uploadAbort(String id) => _json('upload_abort', id: id);

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
    while (true) {
      final plan = _transport('upload_step', {
        'offset': offset,
        'size': blob.length,
        'chunk': chunk,
      }) as Map;
      if (plan['step'] == 'commit') return uploadCommit(id);
      if (plan['step'] != 'send') {
        throw const SyncApiException(
            0, 'invalid_upload_range', 'Invalid upload range');
      }
      final start = plan['start'] as int;
      final end = plan['end'] as int;
      try {
        offset = await uploadChunk(
            id, start, Uint8List.sublistView(blob, start, end));
      } on SyncApiException catch (e) {
        final corrected = _transport('upload_conflict', {
          'status': e.status,
          'received': e.extra['received'] is int ? e.extra['received'] : null,
          'size': blob.length,
        }) as int?;
        if (corrected != null) {
          offset = corrected;
          continue;
        }
        rethrow;
      }
      onProgress?.call(offset, blob.length);
    }
  }

  static String _enc(List<int> b) => base64Url.encode(b).replaceAll('=', '');
  static Uint8List _b64(String s) {
    final pad = (4 - s.length % 4) % 4;
    return Uint8List.fromList(base64Url.decode(s + '=' * pad));
  }
}
