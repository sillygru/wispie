import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/services/sync/blob_codec.dart';
import 'package:wispie/services/sync/crypto.dart';

const _acct = '00112233445566778899aabbccddeeff';
// Tiny Argon2 params keep tests fast; production uses KdfParams().
const _kdf = KdfParams(memoryKib: 16, iterations: 1);

Uint8List _bytes(int n, [int seed = 1]) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

Future<Uint8List> _blob(
  Uint8List key,
  List<int> payload, {
  BlobKind kind = BlobKind.delta,
  int epoch = 1,
}) =>
    BlobCodec.encode(
      dataKey: key,
      accountIdHex: _acct,
      kind: kind,
      epoch: epoch,
      payloadJson: payload,
    );

Future<Uint8List> _dec(
  Uint8List key,
  Uint8List blob, {
  String acct = _acct,
  BlobKind kind = BlobKind.delta,
  int epoch = 1,
}) =>
    BlobCodec.decode(
      dataKey: key,
      accountIdHex: acct,
      expectedKind: kind,
      expectedEpoch: epoch,
      input: Stream.value(blob),
    );

void main() {
  group('derivations', () {
    test('argon2 is deterministic and salt dependent', () async {
      final salt = Uint8List(16);
      final a = await SyncCrypto.deriveMasterKey('pw-pw-pw-pw', salt, _kdf);
      final b = await SyncCrypto.deriveMasterKey('pw-pw-pw-pw', salt, _kdf);
      final c = await SyncCrypto.deriveMasterKey(
        'pw-pw-pw-pw',
        Uint8List(16)..[0] = 1,
        _kdf,
      );
      expect(a, b);
      expect(a, isNot(c));
      expect(a.length, 32);
    });

    test('NFKC makes composed and compatibility forms equal', () {
      expect(
        SyncCrypto.passwordBytes('\u00e9\uff21'),
        SyncCrypto.passwordBytes('e\u0301A'),
      );
      expect(SyncCrypto.normalizeUsername(' Bob '), 'bob');
    });

    test('contexts are domain separated', () async {
      final k = _bytes(32);
      final all = {
        await SyncCrypto.authKey(k),
        await SyncCrypto.kek(k),
        await SyncCrypto.dataKey(k),
        await SyncCrypto.recoveryAuth(k),
        await SyncCrypto.recoveryKek(k),
      }.map((e) => e.join(',')).toSet();
      expect(all.length, 5);
      expect(await SyncCrypto.authKey(k), await SyncCrypto.authKey(k));
    });
  });

  group('wrap', () {
    test('roundtrip, wrong key, wrong account, wrong wrapper', () async {
      final kek = _bytes(32), ak = _bytes(32, 2);
      final w = await SyncCrypto.wrapAccountKey(kek, ak, _acct);
      expect(await SyncCrypto.unwrapAccountKey(kek, w, _acct), ak);
      expect(
        () => SyncCrypto.unwrapAccountKey(_bytes(32, 3), w, _acct),
        throwsA(isA<SyncCryptoException>()),
      );
      expect(
        () => SyncCrypto.unwrapAccountKey(kek, w, 'ff$_acct'),
        throwsA(isA<SyncCryptoException>()),
      );
      expect(
        () => SyncCrypto.unwrapAccountKeyByRecovery(kek, w, _acct),
        throwsA(isA<SyncCryptoException>()),
      );
    });

    test('wraps are randomized', () async {
      final kek = _bytes(32), ak = _bytes(32, 2);
      expect(
        await SyncCrypto.wrapAccountKey(kek, ak, _acct),
        isNot(await SyncCrypto.wrapAccountKey(kek, ak, _acct)),
      );
    });
  });

  group('recovery key', () {
    test('roundtrip and formatting', () {
      final k = RecoveryKey.generate();
      final s = RecoveryKey.encode(k);
      expect(s.replaceAll('-', '').length, 33);
      expect(s.split('-').length, 7);
      expect(RecoveryKey.decode(s), k);
      expect(RecoveryKey.decode(s.toLowerCase().replaceAll('-', ' ')), k);
    });

    test('checksum rejects single-char errors', () {
      final s = RecoveryKey.encode(_bytes(20));
      for (var i = 0; i < s.length; i++) {
        if (s[i] == '-') continue;
        final repl = s[i] == '2' ? '3' : '2';
        final bad = s.replaceRange(i, i + 1, repl);
        expect(
            () => RecoveryKey.decode(bad), throwsA(isA<SyncCryptoException>()));
      }
      expect(
          () => RecoveryKey.decode('ABC'), throwsA(isA<SyncCryptoException>()));
      expect(() => RecoveryKey.decode('U' * 33),
          throwsA(isA<SyncCryptoException>()));
    });
  });

  test('proof of work meets the difficulty', () async {
    const challenge = 'abc.def.ghi';
    final nonce = await SyncCrypto.solvePow(challenge, 12);
    final h = (await Future.value(SyncCrypto.solvePowSync(challenge, 12)));
    expect(h, nonce);
    expect(SyncCrypto.leadingZeroBits([0, 0x1f]), 11);
  });

  group('padme', () {
    test('known values and bounds', () {
      expect(padmeLength(9), 10);
      expect(padmeLength(100), 104);
      expect(padmeLength(1000), 1024);
      for (final l in [8, 33, 1234, 65536, 1000000, 123456789]) {
        final p = padmeLength(l);
        expect(p, greaterThanOrEqualTo(l));
        expect(p, lessThanOrEqualTo(l + l ~/ 8 + 1));
        expect(padmeLength(p), p);
      }
    });
  });

  group('blob codec', () {
    final key = _bytes(32, 9);

    test('roundtrip across chunk boundaries', () async {
      for (final n in [0, 10, 65536 - 8 - 40, 65536, 200000]) {
        final payload = _bytes(n, n + 1);
        final blob = await _blob(key, payload);
        expect(await _dec(key, blob), payload, reason: 'n=$n');
      }
    });

    test('decodes from arbitrary stream splits', () async {
      final payload = _bytes(150000);
      final blob = await _blob(key, payload);
      final parts = [
        for (var i = 0; i < blob.length; i += 7777)
          blob.sublist(i, min(i + 7777, blob.length)),
      ];
      final out = await BlobCodec.decode(
        dataKey: key,
        accountIdHex: _acct,
        expectedKind: BlobKind.delta,
        expectedEpoch: 1,
        input: Stream.fromIterable(parts),
      );
      expect(out, payload);
    });

    test('wrong key, account, kind, epoch are rejected', () async {
      final blob = await _blob(key, _bytes(1000));
      expect(
        () => _dec(_bytes(32, 5), blob),
        throwsA(isA<SyncCryptoException>()),
      );
      expect(
        () => _dec(key, blob, acct: 'ff${_acct.substring(2)}'),
        throwsA(isA<SyncCryptoException>()),
      );
      expect(
        () => _dec(key, blob, kind: BlobKind.snapshot),
        throwsA(isA<BlobFormatException>()),
      );
      expect(
          () => _dec(key, blob, epoch: 2), throwsA(isA<BlobFormatException>()));
    });

    test('tampering any byte of header, body or tag is rejected', () async {
      final blob = await _blob(key, _bytes(3000));
      for (var i = 0; i < blob.length; i += 1) {
        if (i > 80 && i % 97 != 0 && i != blob.length - 1) continue;
        final t = Uint8List.fromList(blob)..[i] ^= 1;
        await expectLater(
          _dec(key, t),
          throwsA(anything),
          reason: 'byte $i',
        );
      }
    });

    test('blob id swap (header bytes 10..26) fails authentication', () async {
      final blob = await _blob(key, _bytes(500));
      final t = Uint8List.fromList(blob)..[12] ^= 0xff;
      expect(() => _dec(key, t), throwsA(isA<SyncCryptoException>()));
    });

    test('chunk reorder, truncation and trailing data are rejected', () async {
      final payload = _bytes(200000, 4);
      final blob = await _blob(key, payload);
      const h = BlobCodec.headerLen, c = BlobCodec.cipherChunk;
      final c0 = blob.sublist(h, h + c), c1 = blob.sublist(h + c, h + 2 * c);
      final rest = blob.sublist(h + 2 * c);
      final swapped = Uint8List.fromList([
        ...blob.sublist(0, h),
        ...c1,
        ...c0,
        ...rest,
      ]);
      await expectLater(
          _dec(key, swapped), throwsA(isA<SyncCryptoException>()));
      // Drop the final chunk exactly at a boundary.
      final cut = blob.sublist(0, h + 3 * c);
      await expectLater(_dec(key, cut), throwsA(isA<SyncCryptoException>()));
      await expectLater(
        _dec(key, blob.sublist(0, blob.length - 5)),
        throwsA(anything),
      );
      await expectLater(
        _dec(key, Uint8List.fromList([...blob, 0])),
        throwsA(anything),
      );
      await expectLater(
          _dec(key, blob.sublist(0, 30)), throwsA(isA<BlobFormatException>()));
    });

    test('bad magic and version are rejected', () async {
      final blob = await _blob(key, _bytes(10));
      await expectLater(
        _dec(key, Uint8List.fromList(blob)..[0] = 0),
        throwsA(isA<BlobFormatException>()),
      );
      await expectLater(
        _dec(key, Uint8List.fromList(blob)..[4] = 2),
        throwsA(isA<BlobFormatException>()),
      );
    });

    test('ciphertext is padded to padme length', () async {
      final blob = await _blob(key, _bytes(5000));
      final body = blob.length - BlobCodec.headerLen - BlobCodec.tagBytes;
      expect(body, padmeLength(body));
    });
  });
}
