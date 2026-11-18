/// Recovery of the real image payload from an embedded-tag picture frame.
///
/// The signature scan lives in the native core; this keeps the value object the
/// rest of the app passes around.
library;

import 'dart:typed_data';

import '../../data/rust/wispie_core.dart';

/// An image payload recovered from a tag's picture frame.
class EmbeddedCover {
  const EmbeddedCover(this.bytes, this.extension);

  /// The payload, starting exactly at the format's magic bytes.
  final Uint8List bytes;

  /// File extension for the sniffed format, leading dot included.
  final String extension;
}

/// How many leading bytes of a file [hasImageSignature] needs to judge it.
const int imageSignatureProbeLength = 16;

/// The image payload in [raw], with any leading junk removed, or null when
/// [raw] holds no recognisable image.
EmbeddedCover? recoverEmbeddedCover(Uint8List raw) {
  if (raw.length < 4) return null;
  final reply = WispieCore.helper({
    'action': 'cover_sniff',
  }, bytes: raw);
  if (reply['present'] != true) return null;
  final offset = (reply['offset'] as num?)?.toInt() ?? 0;
  final extension = reply['extension'] as String? ?? '.jpg';
  return EmbeddedCover(
    offset == 0 ? raw : Uint8List.sublistView(raw, offset),
    extension,
  );
}

/// Whether [head] — the first [imageSignatureProbeLength] bytes of a file —
/// starts with the magic bytes of an image format a decoder will accept.
bool hasImageSignature(Uint8List head) {
  if (head.length < 4) return false;
  final reply = WispieCore.helper({
    'action': 'cover_sniff',
    'headOnly': true,
  }, bytes: head);
  return reply['present'] == true;
}
