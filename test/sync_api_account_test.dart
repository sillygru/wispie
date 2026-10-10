import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wispie/services/sync/account_service.dart';
import 'package:wispie/services/sync/api_client.dart';
import 'package:wispie/services/sync/blob_codec.dart';
import 'package:wispie/services/sync/crypto.dart';

const _kdf = KdfParams(memoryKib: 16, iterations: 1);

/// Minimal in-memory implementation of the parts of API v1 the client uses.
class FakeServer {
  late HttpServer http;
  String get url => 'http://127.0.0.1:${http.port}';

  final accounts = <String, Map<String, dynamic>>{}; // username -> account
  final tokens = <String, String>{}; // access -> account id
  final refreshes = <String, String>{}; // refresh -> account id
  final recoverTokens = <String, String>{};
  final deltas = <int, Uint8List>{};
  final uploads = <String, BytesBuilder>{};
  Uint8List? snapshot;
  int epoch = 0, tokenCounter = 0, refreshCalls = 0, rateLimitedOnce = 0;
  int expireAccessAfter = -1;
  int infoCalls = 0;

  Future<void> start() async {
    http = await HttpServer.bind('127.0.0.1', 0);
    http.listen((r) async {
      try {
        await _handle(r);
      } catch (e) {
        r.response
          ..statusCode = 500
          ..write('$e');
        await r.response.close();
      }
    });
  }

  Future<void> stop() => http.close(force: true);

  String _tok(String acct, bool refresh) {
    final t = b64u(utf8.encode('t${tokenCounter++}'));
    (refresh ? refreshes : tokens)[t] = acct;
    return t;
  }

  Map<String, dynamic> _issue(String acct) => {
        'account_id': acct,
        'access_token': _tok(acct, false),
        'refresh_token': _tok(acct, true),
        'expires_in': 900,
      };

  Future<void> _json(HttpRequest r, int status, Object body) async {
    r.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await r.response.close();
  }

  Future<void> _err(HttpRequest r, int s, String code,
          [Map<String, dynamic>? x]) =>
      _json(r, s, {'error': code, 'message': code, ...?x});

  String? _auth(HttpRequest r) {
    final h = r.headers.value('authorization') ?? '';
    return tokens[h.replaceFirst('Bearer ', '')];
  }

  Future<void> _handle(HttpRequest r) async {
    final path = r.uri.path.replaceFirst('/v1', '');
    final body = BytesBuilder();
    await for (final c in r) {
      body.add(c);
    }
    final bytes = body.takeBytes();
    Map<String, dynamic> j() => bytes.isEmpty
        ? {}
        : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final m = r.method;

    if (path == '/info') {
      infoCalls++;
      return _json(r, 200, {
        'name': 'wispie-sync',
        'api': 1,
        'registration_open': true,
        'pow_bits': 8,
        'limits': {
          'max_delta_bytes': 4194304,
          'chunk_bytes': 100,
          'quota_bytes': 1 << 30
        },
      });
    }
    if (path == '/auth/prelogin') {
      final a = accounts[j()['username']];
      return _json(r, 200, {
        'salt': a?['salt'] ?? b64u(Uint8List(16)),
        'kdf': a?['kdf'] ?? _kdf.toJson(),
      });
    }
    if (path == '/auth/register/begin') {
      if (accounts.containsKey(j()['username'])) {
        return _err(r, 409, 'username_taken');
      }
      return _json(r, 200, {
        'account_id': '00112233445566778899aabbccddeeff',
        'pow': {'challenge': 'chal.1.mac', 'bits': 8, 'expires': 0},
      });
    }
    if (path == '/auth/register/finish') {
      final b = j();
      final ok = SyncCrypto.leadingZeroBits(
            sha256Of('${b['pow_challenge']}${b['pow_nonce']}'),
          ) >=
          8;
      if (!ok) return _err(r, 400, 'bad_pow');
      accounts[b['username']] = {...b};
      return _json(r, 200, _issue(b['account_id']));
    }
    if (path == '/auth/login') {
      final a = accounts[j()['username']];
      if (a == null || a['auth_key'] != j()['auth_key']) {
        return _err(r, 401, 'invalid_credentials');
      }
      return _json(r, 200,
          {..._issue(a['account_id']), 'wrapped_by_pw': a['wrapped_by_pw']});
    }
    if (path == '/auth/refresh') {
      refreshCalls++;
      final acct = refreshes.remove(j()['refresh_token']);
      if (acct == null) return _err(r, 401, 'unauthorized');
      return _json(r, 200, _issue(acct));
    }
    if (path == '/auth/recover/begin') {
      final a = accounts[j()['username']];
      if (a == null || a['recovery_auth'] != j()['recovery_auth']) {
        return _err(r, 401, 'invalid_credentials');
      }
      final t = b64u(utf8.encode('rec${tokenCounter++}'));
      recoverTokens[t] = j()['username'];
      return _json(r, 200, {
        'account_id': a['account_id'],
        'wrapped_by_rk': a['wrapped_by_rk'],
        'recover_token': t,
      });
    }
    if (path == '/auth/recover/finish') {
      final u = recoverTokens.remove(
        (r.headers.value('authorization') ?? '').replaceFirst('Bearer ', ''),
      );
      if (u == null) return _err(r, 401, 'unauthorized');
      accounts[u]!.addAll(j());
      tokens.clear();
      refreshes.clear();
      return _json(r, 200, _issue(accounts[u]!['account_id']));
    }

    final acct = _auth(r);
    if (acct == null || (expireAccessAfter == 0)) {
      if (expireAccessAfter == 0) {
        expireAccessAfter = -1;
        tokens.clear();
      }
      return _err(r, 401, 'unauthorized');
    }

    if (path == '/auth/logout') return _json(r, 200, {});
    if (path == '/account/password') {
      final a = accounts.values.firstWhere((a) => a['account_id'] == acct);
      if (a['auth_key'] != j()['current_auth_key']) {
        return _err(r, 401, 'invalid_credentials');
      }
      a
        ..['salt'] = j()['salt']
        ..['auth_key'] = j()['auth_key']
        ..['wrapped_by_pw'] = j()['wrapped_by_pw'];
      return _json(r, 200, {});
    }
    if (path == '/account/recovery-key') {
      final a = accounts.values.firstWhere((a) => a['account_id'] == acct);
      if (a['auth_key'] != j()['current_auth_key']) {
        return _err(r, 401, 'invalid_credentials');
      }
      a
        ..['recovery_auth'] = j()['recovery_auth']
        ..['wrapped_by_rk'] = j()['wrapped_by_rk'];
      return _json(r, 200, {});
    }
    if (path == '/sync/state') return _json(r, 200, _state());
    if (path == '/sync/deltas' && m == 'GET') {
      if (rateLimitedOnce > 0) {
        rateLimitedOnce--;
        r.response.headers.set('Retry-After', '1');
        return _err(r, 429, 'rate_limited', {'retry_after': 1});
      }
      final after = int.parse(r.uri.queryParameters['after']!);
      final out = BytesBuilder();
      for (final e in deltas.entries.where((e) => e.key > after)) {
        final h = ByteData(12)
          ..setUint64(0, e.key)
          ..setUint32(8, e.value.length);
        out
          ..add(h.buffer.asUint8List())
          ..add(e.value);
      }
      r.response.headers
        ..set('X-Wispie-Head', '${deltas.length}')
        ..set('X-Wispie-More', '0');
      r.response.add(out.takeBytes());
      return r.response.close();
    }
    if (path == '/sync/deltas' && m == 'POST') {
      final head = int.parse(r.headers.value('x-wispie-expect-head')!);
      if (head != deltas.length) {
        return _err(r, 409, 'head_moved', {'head': deltas.length});
      }
      if (int.parse(r.headers.value('x-wispie-epoch')!) != epoch) {
        return _err(r, 412, 'epoch_changed', {'epoch': epoch});
      }
      deltas[head + 1] = bytes;
      return _json(r, 200, {'seq': head + 1});
    }
    if (path == '/sync/snapshot') {
      final s = snapshot!;
      r.response.headers
        ..set('X-Wispie-Snapshot-Id', 'snap1')
        ..set('X-Wispie-Base-Seq', '0')
        ..set('X-Wispie-Epoch', '$epoch');
      final range = r.headers.value('range');
      if (range != null) {
        final from =
            int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        if (from >= s.length) return _err(r, 416, 'range');
        r.response.statusCode = 206;
        r.response.add(s.sublist(from));
      } else {
        r.response.add(s);
      }
      return r.response.close();
    }
    if (path == '/sync/uploads' && m == 'POST') {
      uploads['up1'] = BytesBuilder();
      return _json(r, 200, {'upload_id': 'up1', 'chunk_bytes': 100});
    }
    if (path.startsWith('/sync/uploads/')) {
      final id = path.split('/')[3];
      final u = uploads[id];
      if (u == null) return _err(r, 404, 'not_found');
      if (path.endsWith('/commit')) {
        snapshot = u.takeBytes();
        epoch++;
        return _json(r, 200, _state());
      }
      if (m == 'GET') return _json(r, 200, {'received': u.length});
      if (m == 'PUT') {
        if (int.parse(r.uri.queryParameters['offset']!) != u.length) {
          return _err(r, 409, 'offset_mismatch', {'received': u.length});
        }
        u.add(bytes);
        return _json(r, 200, {'received': u.length});
      }
    }
    return _err(r, 404, 'not_found');
  }

  Map<String, dynamic> _state() => {
        'epoch': epoch,
        'head_seq': deltas.length,
        'snapshot': snapshot == null
            ? null
            : {'id': 'snap1', 'base_seq': 0, 'size': snapshot!.length},
        'deltas_since_snapshot': deltas.length,
        'bytes_since_snapshot': 0,
        'compaction_recommended': false,
        'usage_bytes': 0,
        'quota_bytes': 1 << 30,
      };
}

List<int> sha256Of(String s) => _sha(utf8.encode(s));
List<int> _sha(List<int> b) => sha256.convert(b).bytes;

void main() {
  late FakeServer server;
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
    await server.start();
    tmp = await Directory.systemTemp.createTemp('wispie_api');
  });
  tearDown(() async {
    await server.stop();
    await tmp.delete(recursive: true);
  });

  AccountService svc([MemorySecretStore? s]) =>
      AccountService(secrets: s ?? MemorySecretStore(), kdf: _kdf);

  group('url rules', () {
    test('http only for private hosts', () {
      for (final u in [
        'http://localhost:8080',
        'http://127.0.0.1',
        'http://192.168.1.4',
        'http://10.0.0.2',
        'http://172.20.0.1',
        'http://nas.local',
        'http://box.tailnet.ts.net',
        'http://100.92.244.20',
        'http://100.64.0.1',
        'http://100.127.255.255',
        'https://sync.example.com',
      ]) {
        expect(() => SyncApiClient.parseBaseUrl(u), returnsNormally, reason: u);
      }
      for (final u in [
        'http://example.com',
        'http://172.32.0.1',
        'http://100.63.0.1',
        'http://100.128.0.1',
        'http://notts.net',
        'http://evil.com/ts.net',
        'http://8.8.8.8',
        'ftp://x',
        'nope'
      ]) {
        expect(() => SyncApiClient.parseBaseUrl(u),
            throwsA(isA<SyncApiException>()),
            reason: u);
      }
    });
  });

  group('account flows', () {
    test('register, login on another device, same data key', () async {
      final a = svc();
      final reg = await a.register(
        serverUrl: server.url,
        username: 'Alice',
        password: 'correct horse battery',
      );
      expect(RecoveryKey.decode(reg.recoveryKey), hasLength(20));
      expect(a.isLoggedIn, isTrue);

      final secrets = MemorySecretStore();
      final b = svc(secrets);
      await b.login(
        serverUrl: server.url,
        username: 'alice',
        password: 'correct horse battery',
      );
      expect(await b.dataKey(), await a.dataKey());

      final restored = svc(secrets);
      expect((await restored.load())?.username, 'alice');
      expect(await restored.dataKey(), await a.dataKey());
      expect((await restored.client.state()).epoch, 0);
    });

    test('wrong password and weak inputs are rejected', () async {
      final a = svc();
      await a.register(
          serverUrl: server.url, username: 'bob', password: 'longenoughpass1');
      await expectLater(
        svc().login(
            serverUrl: server.url,
            username: 'bob',
            password: 'wrong-wrong-wrong'),
        throwsA(isA<SyncApiException>().having((e) => e.status, 'status', 401)),
      );
      await expectLater(
        svc().register(
            serverUrl: server.url, username: 'carl', password: 'short'),
        throwsA(isA<SyncApiException>()
            .having((e) => e.code, 'code', 'weak_password')),
      );
      await expectLater(
        svc().register(
            serverUrl: server.url,
            username: 'A b',
            password: 'longenoughpass1'),
        throwsA(isA<SyncApiException>()
            .having((e) => e.code, 'code', 'bad_username')),
      );
    });

    test('recovery, password change, new recovery key', () async {
      final a = svc();
      final reg = await a.register(
          serverUrl: server.url,
          username: 'dana',
          password: 'first-password-1');
      final key = await a.dataKey();

      await a.changePassword(
          currentPassword: 'first-password-1',
          newPassword: 'second-password-2');
      final b = svc();
      await b.login(
          serverUrl: server.url,
          username: 'dana',
          password: 'second-password-2');
      expect(await b.dataKey(), key);

      final c = svc();
      await c.recover(
        serverUrl: server.url,
        username: 'dana',
        recoveryKey: reg.recoveryKey,
        newPassword: 'third-password-3',
      );
      expect(await c.dataKey(), key);

      final fresh = await c.generateRecoveryKey('third-password-3');
      expect(fresh, isNot(reg.recoveryKey));
      await expectLater(
        svc().recover(
            serverUrl: server.url,
            username: 'dana',
            recoveryKey: reg.recoveryKey,
            newPassword: 'fourth-password-4'),
        throwsA(isA<SyncApiException>()),
      );
      await svc().recover(
          serverUrl: server.url,
          username: 'dana',
          recoveryKey: fresh,
          newPassword: 'fourth-password-4');
    });

    test('logout clears local credentials even if offline', () async {
      final secrets = MemorySecretStore();
      final a = svc(secrets);
      await a.register(
          serverUrl: server.url, username: 'erin', password: 'longenoughpass1');
      await server.stop();
      await a.logout();
      expect(a.isLoggedIn, isFalse);
      expect(secrets.data, isEmpty);
      server = FakeServer();
      await server.start();
    });
  });

  group('api client', () {
    Future<AccountService> loggedIn() async {
      final a = svc();
      await a.register(
          serverUrl: server.url, username: 'sync', password: 'longenoughpass1');
      return a;
    }

    test('delta push/pull roundtrip with encrypted blobs', () async {
      final a = await loggedIn();
      final key = await a.dataKey();
      const id = '00112233445566778899aabbccddeeff';
      final blob = await BlobCodec.encode(
        dataKey: key,
        accountIdHex: id,
        kind: BlobKind.delta,
        epoch: 0,
        payloadJson: utf8.encode('{"v":1}'),
      );
      final seq = await a.client.pushDelta(blob, epoch: 0, expectHead: 0);
      expect(seq, 1);
      final page = await a.client.pullDeltas(0);
      expect(page.frames.single.seq, 1);
      expect(page.frames.single.blob, blob);
      final out = await BlobCodec.decode(
        dataKey: key,
        accountIdHex: id,
        expectedKind: BlobKind.delta,
        expectedEpoch: 0,
        input: Stream.value(page.frames.single.blob),
      );
      expect(utf8.decode(out), '{"v":1}');
    });

    test('typed errors: head moved and epoch changed', () async {
      final a = await loggedIn();
      final blob = Uint8List.fromList([1, 2, 3]);
      await a.client.pushDelta(blob, epoch: 0, expectHead: 0);
      await expectLater(
        a.client.pushDelta(blob, epoch: 0, expectHead: 0),
        throwsA(isA<SyncApiException>()
            .having((e) => e.isHeadMoved, 'headMoved', true)
            .having((e) => e.extra['head'], 'head', 1)),
      );
      await expectLater(
        a.client.pushDelta(blob, epoch: 5, expectHead: 1),
        throwsA(isA<SyncApiException>()
            .having((e) => e.isEpochChanged, 'epoch', true)),
      );
    });

    test('expired access token refreshes once for concurrent calls', () async {
      final a = await loggedIn();
      server.expireAccessAfter = 0;
      final before = server.refreshCalls;
      final rs = await Future.wait(
          [a.client.state(), a.client.state(), a.client.state()]);
      expect(rs, hasLength(3));
      expect(server.refreshCalls - before, 1);
    });

    test('dead refresh token reports session_expired and clears tokens',
        () async {
      final a = await loggedIn();
      server.tokens.clear();
      server.refreshes.clear();
      await expectLater(
        a.client.state(),
        throwsA(isA<SyncApiException>()
            .having((e) => e.code, 'code', 'session_expired')),
      );
      expect(a.client.tokens, isNull);
    });

    test('429 Retry-After is honoured automatically', () async {
      final a = await loggedIn();
      server.rateLimitedOnce = 1;
      final slept = <Duration>[];
      final c = SyncApiClient(
        baseUrl: server.url,
        tokens: a.client.tokens,
        sleep: (d) async => slept.add(d),
      );
      final page = await c.pullDeltas(0);
      expect(page.frames, isEmpty);
      expect(slept, [const Duration(seconds: 1)]);
    });

    test('snapshot download resumes with Range', () async {
      final a = await loggedIn();
      server.snapshot = Uint8List.fromList(List.generate(5000, (i) => i % 251));
      final f = File('${tmp.path}/snap.bin');
      await f.writeAsBytes(server.snapshot!.sublist(0, 1234));
      final progress = <int>[];
      final meta = await a.client
          .downloadSnapshot(f, onProgress: (d, t) => progress.add(d));
      expect(meta.id, 'snap1');
      expect(await f.readAsBytes(), server.snapshot);
      expect(progress.last, 5000);

      // Already complete file -> 416 -> restart from scratch.
      await a.client.downloadSnapshot(f);
      expect(await f.readAsBytes(), server.snapshot);
    });

    test('chunked upload commits and resumes after interruption', () async {
      final a = await loggedIn();
      final blob = Uint8List.fromList(List.generate(950, (i) => i % 200));
      final progress = <int>[];
      final st = await a.client.uploadBlob(
        blob,
        kind: 'reset',
        epoch: 1,
        baseSeq: 0,
        onProgress: (d, t) => progress.add(d),
      );
      expect(st.epoch, 1);
      expect(server.snapshot, blob);
      expect(progress.last, 950);

      // Simulate a partial upload, then resume by id.
      server.uploads['up1'] = BytesBuilder()..add(blob.sublist(0, 300));
      await a.client.uploadBlob(blob,
          kind: 'reset', epoch: 2, baseSeq: 0, resumeId: 'up1');
      expect(server.snapshot, blob);
    });
  });
}
