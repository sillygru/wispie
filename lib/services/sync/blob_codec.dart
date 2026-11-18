import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../domain/services/native_accel.dart';
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

/// Blob format of plan_sync.md section 1.3.
///
/// Deviation from the plan: secretstream is replaced by an equivalent STREAM
/// construction on XChaCha20-Poly1305. The 24-byte header field is a random
/// nonce base; chunk nonce = base[0..15] || u64be(chunkIndex) || finalFlag, so
/// reordering, truncation and trailing data all fail authentication.
///
/// The framing lives in the native core (`rust/wispie_core/src/sync.rs`); both
/// directions run off the UI isolate because a snapshot is megabytes of gzip and
/// encryption.
class BlobCodec {
  BlobCodec._();

  static Future<Uint8List> encode({
    required Uint8List dataKey,
    required String accountIdHex,
    required BlobKind kind,
    required int epoch,
    required List<int> payloadJson,
    Uint8List? blobId,
  }) async {
    final request = <String, Object?>{
      'action': 'blob_encode',
      'dataKeyHex': _hexOf(dataKey),
      'accountIdHex': accountIdHex,
      'kind': kind.id,
      'epoch': epoch,
      if (blobId != null) 'blobIdHex': _hexOf(blobId),
    };
    final payload = Uint8List.fromList(payloadJson);
    final result = await Isolate.run(() {
      try {
        return (out: NativeAccel.syncBytes(request, payload), error: null);
      } on NativeCommandException catch (error) {
        return (out: null, error: error.message);
      }
    });
    if (result.error case final message?) {
      throw _mapError(message);
    }
    return result.out!;
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
    final builder = BytesBuilder(copy: false);
    await for (final part in input) {
      builder.add(part);
    }
    final blob = builder.takeBytes();
    final request = <String, Object?>{
      'action': 'blob_decode',
      'dataKeyHex': _hexOf(dataKey),
      'accountIdHex': accountIdHex,
      'kind': expectedKind.id,
      'epoch': expectedEpoch,
    };
    final result = await Isolate.run(() {
      try {
        return (out: NativeAccel.syncBytes(request, blob), error: null);
      } on NativeCommandException catch (error) {
        return (out: null, error: error.message);
      }
    });
    if (result.error case final message?) {
      throw _mapError(message);
    }
    return result.out!;
  }

  static Map<String, dynamic> parsePayload(Uint8List json) =>
      jsonDecode(utf8.decode(json)) as Map<String, dynamic>;
}

Exception _mapError(String message) {
  if (message.startsWith('blob: ')) {
    return BlobFormatException(message.substring(6));
  }
  if (message.startsWith('crypto: ')) {
    return SyncCryptoException(message.substring(8));
  }
  return BlobFormatException(message);
}

String _hexOf(List<int> bytes) {
  final out = StringBuffer();
  for (final byte in bytes) {
    out.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}
