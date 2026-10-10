import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';

class BlobFormatException implements Exception {
  final String message;
  const BlobFormatException(this.message);
  @override
  String toString() => 'BlobFormatException: $message';
}

enum BlobKind {
  delta(1),
  snapshot(2);

  final int id;
  const BlobKind(this.id);
}

/// Padme padding (Nikitin et al.): leaks only O(log log L) bits of length.
int padmeLength(int l) {
  if (l < 2) return l;
  final e = l.bitLength - 1;
  final s = (e.bitLength - 1) + 1;
  final lastBits = e - s;
  if (lastBits <= 0) return l;
  final mask = (1 << lastBits) - 1;
  return (l + mask) & ~mask;
}

/// Blob format of plan_sync.md section 1.3.
///
/// Deviation: secretstream is replaced by an equivalent STREAM construction on
/// XChaCha20-Poly1305. The 24-byte header field is a random nonce base; chunk
/// nonce = base[0..15] || u64be(chunkIndex) || finalFlag, so reordering,
/// truncation and trailing data all fail authentication.
class BlobCodec {
  BlobCodec._();

  static const magic = [0x57, 0x53, 0x50, 0x42]; // WSPB
  static const version = 1;
  static const plainChunk = 65536;
  static const tagBytes = 16;
  static const cipherChunk = plainChunk + tagBytes;
  static const prefixLen = 26;
  static const headerLen = prefixLen + 24;

  static final _aead = Xchacha20.poly1305Aead();

  static Uint8List frame(List<int> json) {
    final gz = gzip.encode(json);
    final framed = Uint8List(padmeLength(8 + gz.length));
    ByteData.sublistView(framed).setUint64(0, gz.length);
    framed.setRange(8, 8 + gz.length, gz);
    return framed;
  }

  static List<int> unframe(Uint8List framed) {
    if (framed.length < 8) throw const BlobFormatException('frame too short');
    final len = ByteData.sublistView(framed).getUint64(0);
    if (len > framed.length - 8 || framed.length != padmeLength(8 + len)) {
      throw const BlobFormatException('bad frame length');
    }
    for (var i = 8 + len; i < framed.length; i++) {
      if (framed[i] != 0) throw const BlobFormatException('bad padding');
    }
    try {
      return gzip.decode(Uint8List.sublistView(framed, 8, 8 + len));
    } on FormatException {
      throw const BlobFormatException('bad gzip');
    }
  }

  static List<int> _aadFor(List<int> accountId, List<int> prefix) =>
      [...accountId, ...prefix];

  static Uint8List _nonce(List<int> base, int index, bool last) {
    final n = Uint8List(24);
    n.setRange(0, 15, base);
    ByteData.sublistView(n).setUint64(15, index);
    n[23] = last ? 1 : 0;
    return n;
  }

  static List<int> _hexBytes(String hex) {
    if (hex.length % 2 != 0) throw const BlobFormatException('bad account id');
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }

  /// Emits the header followed by one encrypted chunk at a time.
  static Stream<Uint8List> encodeStream({
    required Uint8List dataKey,
    required String accountIdHex,
    required BlobKind kind,
    required int epoch,
    required List<int> payloadJson,
    Uint8List? blobId,
  }) async* {
    final accountId = _hexBytes(accountIdHex);
    final prefix = Uint8List(prefixLen);
    prefix.setRange(0, 4, magic);
    prefix[4] = version;
    prefix[5] = kind.id;
    ByteData.sublistView(prefix).setUint32(6, epoch);
    prefix.setRange(10, 26, blobId ?? SyncCrypto.randomBytes(16));
    final base = SyncCrypto.randomBytes(24);
    yield Uint8List.fromList([...prefix, ...base]);

    final aad = _aadFor(accountId, [...prefix, ...base]);
    final plain = frame(payloadJson);
    final key = SecretKey(dataKey);
    final count = (plain.length + plainChunk - 1) ~/ plainChunk;
    for (var i = 0; i < count; i++) {
      final end = (i + 1) * plainChunk;
      final chunk = Uint8List.sublistView(
        plain,
        i * plainChunk,
        end > plain.length ? plain.length : end,
      );
      final box = await _aead.encrypt(
        chunk,
        secretKey: key,
        nonce: _nonce(base, i, i == count - 1),
        aad: aad,
      );
      yield Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    }
  }

  static Future<Uint8List> encode({
    required Uint8List dataKey,
    required String accountIdHex,
    required BlobKind kind,
    required int epoch,
    required List<int> payloadJson,
    Uint8List? blobId,
  }) async {
    final b = BytesBuilder(copy: false);
    await for (final p in encodeStream(
      dataKey: dataKey,
      accountIdHex: accountIdHex,
      kind: kind,
      epoch: epoch,
      payloadJson: payloadJson,
      blobId: blobId,
    )) {
      b.add(p);
    }
    return b.takeBytes();
  }

  /// Returns the payload JSON bytes. Throws [BlobFormatException] on any
  /// structural problem and [SyncCryptoException] on authentication failure.
  static Future<Uint8List> decode({
    required Uint8List dataKey,
    required String accountIdHex,
    required BlobKind expectedKind,
    required int expectedEpoch,
    required Stream<List<int>> input,
  }) async {
    final accountId = _hexBytes(accountIdHex);
    final key = SecretKey(dataKey);
    var pending = Uint8List(0);
    Uint8List? prefix, base;
    List<int>? aad;
    var index = 0;
    final plain = BytesBuilder(copy: false);

    Future<void> openChunk(Uint8List chunk, bool last) async {
      if (chunk.length < tagBytes) {
        throw const BlobFormatException('truncated chunk');
      }
      try {
        final clear = await _aead.decrypt(
          SecretBox(
            Uint8List.sublistView(chunk, 0, chunk.length - tagBytes),
            nonce: _nonce(base!, index, last),
            mac: Mac(Uint8List.sublistView(chunk, chunk.length - tagBytes)),
          ),
          secretKey: key,
          aad: aad!,
        );
        plain.add(clear);
      } on SecretBoxAuthenticationError {
        throw const SyncCryptoException('blob authentication failed');
      }
      index++;
    }

    Future<void> consume(bool end) async {
      if (prefix == null) {
        if (pending.length < headerLen) {
          if (end) throw const BlobFormatException('truncated header');
          return;
        }
        prefix = Uint8List.sublistView(pending, 0, prefixLen);
        base = Uint8List.sublistView(pending, prefixLen, headerLen);
        for (var i = 0; i < 4; i++) {
          if (prefix![i] != magic[i]) {
            throw const BlobFormatException('bad magic');
          }
        }
        if (prefix![4] != version) {
          throw const BlobFormatException('unsupported version');
        }
        if (prefix![5] != expectedKind.id) {
          throw const BlobFormatException('unexpected blob kind');
        }
        if (ByteData.sublistView(prefix!).getUint32(6) != expectedEpoch) {
          throw const BlobFormatException('unexpected epoch');
        }
        aad = _aadFor(accountId, Uint8List.sublistView(pending, 0, headerLen));
        pending = Uint8List.sublistView(pending, headerLen);
      }
      while (pending.length > cipherChunk) {
        await openChunk(Uint8List.sublistView(pending, 0, cipherChunk), false);
        pending = Uint8List.sublistView(pending, cipherChunk);
      }
      if (end) {
        await openChunk(pending, true);
        pending = Uint8List(0);
      }
    }

    await for (final part in input) {
      pending = Uint8List.fromList([...pending, ...part]);
      await consume(false);
    }
    await consume(true);
    return Uint8List.fromList(unframe(plain.takeBytes()));
  }

  static Map<String, dynamic> parsePayload(Uint8List json) =>
      jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
}
