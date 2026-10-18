import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Thrown when a wrap/unwrap or key decode fails authentication.
class SyncCryptoException implements Exception {
  final String message;
  const SyncCryptoException(this.message);
  @override
  String toString() => 'SyncCryptoException: $message';
}

class KdfParams {
  final String alg;
  final int memoryKib;
  final int iterations;
  final int parallelism;

  const KdfParams({
    this.alg = 'argon2id',
    this.memoryKib = 64 * 1024,
    this.iterations = 3,
    this.parallelism = 1,
  });

  factory KdfParams.fromJson(Map<String, dynamic> j) => KdfParams(
        alg: j['alg'] as String,
        memoryKib: j['m_kib'] as int,
        iterations: j['t'] as int,
        parallelism: j['p'] as int,
      );

  Map<String, dynamic> toJson() => {
        'alg': alg,
        'm_kib': memoryKib,
        't': iterations,
        'p': parallelism,
      };
}

/// Key hierarchy of plan_sync.md section 1.2.
///
/// Deviation from the plan: implemented on the pure-Dart `cryptography`
/// package (no native libsodium), and
/// the keyed BLAKE2b derivations are HMAC-SHA256 with the same context strings.
class SyncCrypto {
  SyncCrypto._();

  static final _aead = Xchacha20.poly1305Aead();
  static final _hmac = Hmac.sha256();
  static final _rng = Random.secure();

  static const ctxAuth = 'wispie/auth/v1';
  static const ctxKek = 'wispie/kek/v1';
  static const ctxData = 'wispie/data/v1';
  static const ctxRecoveryAuth = 'wispie/rauth/v1';
  static const ctxRecoveryKek = 'wispie/rkek/v1';
  static const aadAccountKey = 'wispie/ak/v1|';
  static const aadAccountKeyRecovery = 'wispie/ak-rk/v1|';

  static Uint8List randomBytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));

  /// NFKC + lowercase, used for usernames on both sides.
  static String normalizeUsername(String s) =>
      unorm.nfkc(s.trim()).toLowerCase();

  static List<int> passwordBytes(String p) => utf8.encode(unorm.nfkc(p));

  /// Argon2id off the UI isolate. [kdf] is validated against the server's bounds.
  static Future<Uint8List> deriveMasterKey(
    String password,
    Uint8List salt,
    KdfParams kdf,
  ) {
    final pw = passwordBytes(password);
    return Isolate.run(() async {
      final algo = Argon2id(
        memory: kdf.memoryKib,
        parallelism: kdf.parallelism,
        iterations: kdf.iterations,
        hashLength: 32,
      );
      final key = await algo.deriveKey(
        secretKey: SecretKey(pw),
        nonce: salt,
      );
      return Uint8List.fromList(await key.extractBytes());
    });
  }

  static Future<Uint8List> derive(List<int> key, String context) async {
    final mac = await _hmac.calculateMac(
      utf8.encode(context),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(mac.bytes);
  }

  static Future<Uint8List> authKey(Uint8List masterKey) =>
      derive(masterKey, ctxAuth);
  static Future<Uint8List> kek(Uint8List masterKey) =>
      derive(masterKey, ctxKek);
  static Future<Uint8List> dataKey(Uint8List accountKey) =>
      derive(accountKey, ctxData);
  static Future<Uint8List> recoveryAuth(Uint8List recoveryKey) =>
      derive(recoveryKey, ctxRecoveryAuth);
  static Future<Uint8List> recoveryKek(Uint8List recoveryKey) =>
      derive(recoveryKey, ctxRecoveryKek);

  /// Output: nonce(24) || ciphertext || tag(16).
  static Future<Uint8List> seal(
    List<int> key,
    List<int> plain,
    List<int> aad,
  ) async {
    final box = await _aead.encrypt(plain, secretKey: SecretKey(key), aad: aad);
    return Uint8List.fromList(box.concatenation());
  }

  static Future<Uint8List> open(
    List<int> key,
    List<int> sealed,
    List<int> aad,
  ) async {
    if (sealed.length < 24 + 16) {
      throw const SyncCryptoException('sealed box too short');
    }
    try {
      final box = SecretBox.fromConcatenation(
        sealed,
        nonceLength: 24,
        macLength: 16,
      );
      return Uint8List.fromList(
        await _aead.decrypt(box, secretKey: SecretKey(key), aad: aad),
      );
    } on SecretBoxAuthenticationError {
      throw const SyncCryptoException('authentication failed');
    }
  }

  static Future<Uint8List> wrapAccountKey(
    Uint8List kek,
    Uint8List accountKey,
    String accountId,
  ) =>
      seal(kek, accountKey, utf8.encode('$aadAccountKey$accountId'));

  static Future<Uint8List> unwrapAccountKey(
    Uint8List kek,
    Uint8List wrapped,
    String accountId,
  ) =>
      open(kek, wrapped, utf8.encode('$aadAccountKey$accountId'));

  static Future<Uint8List> wrapAccountKeyByRecovery(
    Uint8List recoveryKek,
    Uint8List accountKey,
    String accountId,
  ) =>
      seal(recoveryKek, accountKey,
          utf8.encode('$aadAccountKeyRecovery$accountId'));

  static Future<Uint8List> unwrapAccountKeyByRecovery(
    Uint8List recoveryKek,
    Uint8List wrapped,
    String accountId,
  ) =>
      open(recoveryKek, wrapped,
          utf8.encode('$aadAccountKeyRecovery$accountId'));

  /// Hashcash: SHA-256(challenge || nonce) must have [bits] leading zero bits.
  /// Nonce is base64url(u64be counter), matching the server's `pow.Solve`.
  static Future<String> solvePow(String challenge, int bits) =>
      Isolate.run(() => solvePowSync(challenge, bits));

  static String solvePowSync(String challenge, int bits) {
    final prefix = utf8.encode(challenge);
    for (var i = 0;; i++) {
      final ctr = ByteData(8)..setUint64(0, i);
      final nonce =
          base64Url.encode(ctr.buffer.asUint8List()).replaceAll('=', '');
      final digest = c.sha256.convert([...prefix, ...utf8.encode(nonce)]).bytes;
      if (leadingZeroBits(digest) >= bits) return nonce;
    }
  }

  static int leadingZeroBits(List<int> d) {
    var n = 0;
    for (final b in d) {
      if (b == 0) {
        n += 8;
        continue;
      }
      return n + (7 - (b.bitLength - 1));
    }
    return n;
  }
}

String b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List unb64u(String s) {
  final pad = (4 - s.length % 4) % 4;
  return Uint8List.fromList(base64Url.decode(s + '=' * pad));
}

/// 20 random bytes as Crockford base32 plus one check char, grouped by 5.
class RecoveryKey {
  RecoveryKey._();

  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const int byteLength = 20;

  static Uint8List generate() => SyncCrypto.randomBytes(byteLength);

  static String encode(Uint8List key) {
    if (key.length != byteLength) {
      throw ArgumentError('recovery key must be $byteLength bytes');
    }
    final data = StringBuffer();
    var bits = 0, acc = 0;
    final values = <int>[];
    for (final b in key) {
      acc = (acc << 8) | b;
      bits += 8;
      while (bits >= 5) {
        values.add((acc >> (bits - 5)) & 31);
        bits -= 5;
      }
      acc &= (1 << bits) - 1;
    }
    values.add(_check(values));
    for (var i = 0; i < values.length; i++) {
      if (i > 0 && i % 5 == 0) data.write('-');
      data.write(_alphabet[values[i]]);
    }
    return data.toString();
  }

  static int _check(List<int> v) {
    // Prime modulus keeps every positional weight invertible, so any single
    // character substitution (except 0<->31) changes the check.
    var s = 0;
    for (var i = 0; i < v.length; i++) {
      s += ((i % 30) + 1) * v[i];
    }
    return s % 31;
  }

  /// Throws [SyncCryptoException] on bad characters, length or check char.
  static Uint8List decode(String input) {
    final s = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final values = <int>[];
    for (final ch in s.split('')) {
      final mapped = switch (ch) {
        'O' => '0',
        'I' || 'L' => '1',
        _ => ch,
      };
      final i = _alphabet.indexOf(mapped);
      if (i < 0) throw const SyncCryptoException('invalid recovery key');
      values.add(i);
    }
    if (values.length != 33) {
      throw const SyncCryptoException('invalid recovery key length');
    }
    final check = values.removeLast();
    if (_check(values) != check) {
      throw const SyncCryptoException('recovery key check failed');
    }
    final out = <int>[];
    var bits = 0, acc = 0;
    for (final v in values) {
      acc = (acc << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((acc >> (bits - 8)) & 255);
        bits -= 8;
        acc &= (1 << bits) - 1;
      }
    }
    return Uint8List.fromList(out);
  }
}
