import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../domain/services/native_accel.dart';

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
/// The contract lives in the native core (`rust/wispie_core/src/sync.rs`): every
/// derived key, sealed box and recovery key here is a byte-for-byte contract
/// with already-shipped clients and the Go server.
class SyncCrypto {
  SyncCrypto._();

  static Uint8List randomBytes(int n) => _hex(NativeAccel.sync({
        'action': 'random',
        'bytes': n,
      })['hex'] as String);

  /// NFKC + lowercase, used for usernames on both sides.
  static String normalizeUsername(String s) => NativeAccel.sync({
        'action': 'normalize',
        'text': s,
        'username': true,
      })['value'] as String;

  /// Argon2id off the UI isolate: the derivation is deliberately expensive.
  static Future<Uint8List> deriveMasterKey(
    String password,
    Uint8List salt,
    KdfParams kdf,
  ) =>
      Isolate.run(() => _hex(NativeAccel.sync({
            'action': 'argon2',
            'password': password,
            'saltHex': _hexOf(salt),
            'mKiB': kdf.memoryKib,
            'iterations': kdf.iterations,
            'parallelism': kdf.parallelism,
          })['keyHex'] as String));

  static Uint8List authKey(Uint8List masterKey) => _role(masterKey, 'auth');
  static Uint8List kek(Uint8List masterKey) => _role(masterKey, 'kek');
  static Uint8List dataKey(Uint8List accountKey) => _role(accountKey, 'data');
  static Uint8List recoveryAuth(Uint8List recoveryKey) =>
      _role(recoveryKey, 'recovery_auth');
  static Uint8List recoveryKek(Uint8List recoveryKey) =>
      _role(recoveryKey, 'recovery_kek');

  static Uint8List _role(Uint8List key, String role) => _hex(NativeAccel.sync({
        'action': 'derive_role',
        'keyHex': _hexOf(key),
        'role': role,
      })['keyHex'] as String);

  static Uint8List wrapAccountKey(
    Uint8List kek,
    Uint8List accountKey,
    String accountId,
  ) =>
      _hex(NativeAccel.sync({
        'action': 'wrap_account_key',
        'keyHex': _hexOf(kek),
        'accountKeyHex': _hexOf(accountKey),
        'accountId': accountId,
      })['sealedHex'] as String);

  static Uint8List unwrapAccountKey(
    Uint8List kek,
    Uint8List wrapped,
    String accountId,
  ) =>
      _crypto(() => _hex(NativeAccel.sync({
            'action': 'unwrap_account_key',
            'keyHex': _hexOf(kek),
            'sealedHex': _hexOf(wrapped),
            'accountId': accountId,
          })['accountKeyHex'] as String));

  static Uint8List wrapAccountKeyByRecovery(
    Uint8List recoveryKek,
    Uint8List accountKey,
    String accountId,
  ) =>
      _hex(NativeAccel.sync({
        'action': 'wrap_account_key_recovery',
        'keyHex': _hexOf(recoveryKek),
        'accountKeyHex': _hexOf(accountKey),
        'accountId': accountId,
      })['sealedHex'] as String);

  static Uint8List unwrapAccountKeyByRecovery(
    Uint8List recoveryKek,
    Uint8List wrapped,
    String accountId,
  ) =>
      _crypto(() => _hex(NativeAccel.sync({
            'action': 'unwrap_account_key_recovery',
            'keyHex': _hexOf(recoveryKek),
            'sealedHex': _hexOf(wrapped),
            'accountId': accountId,
          })['accountKeyHex'] as String));

  /// Hashcash: SHA-256(challenge || nonce) must have [bits] leading zero bits.
  /// Nonce is base64url(u64be counter), matching the server's `pow.Solve`.
  static Future<String> solvePow(String challenge, int bits) => Isolate.run(
        () => NativeAccel.sync({
          'action': 'pow',
          'challenge': challenge,
          'bits': bits,
        })['nonce'] as String,
      );

  static T _crypto<T>(T Function() body) {
    try {
      return body();
    } on NativeCommandException catch (error) {
      throw SyncCryptoException(error.message.replaceFirst('crypto: ', ''));
    }
  }
}

String _hexOf(List<int> bytes) {
  final out = StringBuffer();
  for (final byte in bytes) {
    out.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

Uint8List _hex(String text) => Uint8List.fromList([
      for (var i = 0; i < text.length; i += 2)
        int.parse(text.substring(i, i + 2), radix: 16),
    ]);

String b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List unb64u(String s) {
  final pad = (4 - s.length % 4) % 4;
  return Uint8List.fromList(base64Url.decode(s + '=' * pad));
}

/// 20 random bytes as Crockford base32 plus one check char, grouped by 5.
class RecoveryKey {
  RecoveryKey._();

  static const int byteLength = 20;

  static Uint8List generate() => SyncCrypto.randomBytes(byteLength);

  static String encode(Uint8List key) => NativeAccel.sync({
        'action': 'recovery_encode',
        'keyHex': _hexOf(key),
      })['text'] as String;

  /// Throws [SyncCryptoException] on bad characters, length or check char.
  static Uint8List decode(String input) {
    try {
      return _hex(NativeAccel.sync({
        'action': 'recovery_decode',
        'text': input,
      })['keyHex'] as String);
    } on NativeCommandException catch (error) {
      throw SyncCryptoException(error.message.replaceFirst('crypto: ', ''));
    }
  }
}
