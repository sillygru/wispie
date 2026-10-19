import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A content id names the audio of a file, not its name, tags, cover art or
/// container padding. Two files with the same id carry the same encoded audio,
/// so it survives renames, moves, retagging and copies between devices.
///
/// Format: `<kind>:<32 hex chars>`. The kind records how the id was derived so
/// ids from different strategies can never collide.
///
/// Strategy per container:
///  * FLAC: the MD5 of the decoded samples stored in STREAMINFO. Free to read
///    and independent of compression level and tags.
///  * MP3/AAC: the frame region between the ID3v2 and ID3v1/APE tags.
///  * MP4/M4A: the `mdat` atom body.
///  * Ogg: sampled audio-page bodies and the final granule position; page
///    headers are ignored because retagging renumbers them.
///  * WAV/AIFF: the sample-data chunk.
///  * anything else: the whole file (`r1`), which is tag-sensitive.
///
/// The audio region is hashed from its length plus [_blockCount] blocks of
/// [_blockSize] bytes spread across it, so cost is constant per file.
const int _blockSize = 16 * 1024;
const int _blockCount = 8;
const int _oggBodySample = 2048;

class _Region {
  final String kind;
  final int start;
  final int end;
  const _Region(this.kind, this.start, this.end);
  int get length => end - start;
}

/// Returns the content id of the file at [path], or null when it cannot be
/// read or is empty. Synchronous reads avoid event-loop round trips; call it
/// from a worker isolate.
String? computeContentIdSync(String path) {
  RandomAccessFile? raf;
  try {
    raf = File(path).openSync();
    final size = raf.lengthSync();
    if (size <= 0) return null;

    final audioStart = _skipId3v2(raf, size);
    final magic = _readAt(raf, audioStart, 12);

    if (_isAscii(magic, 0, 'fLaC')) {
      final flac = _flac(raf, size, audioStart);
      if (flac != null) return flac;
    }
    if (audioStart == 0 && _isAscii(magic, 0, 'OggS')) {
      return _ogg(raf, size);
    }
    if (audioStart == 0 && _isAscii(magic, 4, 'ftyp')) {
      final region = _mp4(raf, size);
      if (region != null) return _hashRegion(raf, region);
    }
    if (audioStart == 0 &&
        (_isAscii(magic, 0, 'RIFF') && _isAscii(magic, 8, 'WAVE'))) {
      final region = _riff(raf, size, bigEndian: false, dataId: 'data');
      if (region != null) return _hashRegion(raf, region);
    }
    if (audioStart == 0 &&
        (_isAscii(magic, 0, 'FORM') && _isAscii(magic, 8, 'AIF'))) {
      final region = _riff(raf, size, bigEndian: true, dataId: 'SSND');
      if (region != null) return _hashRegion(raf, region);
    }
    if (_looksLikeMpegAudio(magic) || audioStart > 0) {
      final end = _stripTrailingTags(raf, size, audioStart);
      if (end > audioStart) {
        return _hashRegion(raf, _Region('m1', audioStart, end));
      }
    }
    return _hashRegion(raf, _Region('r1', 0, size));
  } catch (_) {
    return null;
  } finally {
    raf?.closeSync();
  }
}

Uint8List _readAt(RandomAccessFile raf, int offset, int length) {
  raf.setPositionSync(offset);
  return raf.readSync(length);
}

bool _isAscii(Uint8List b, int at, String s) {
  if (b.length < at + s.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[at + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

bool _looksLikeMpegAudio(Uint8List b) =>
    b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0;

int _skipId3v2(RandomAccessFile raf, int size) {
  var pos = 0;
  for (var i = 0; i < 8; i++) {
    final h = _readAt(raf, pos, 10);
    if (h.length < 10 || !_isAscii(h, 0, 'ID3')) break;
    final tagSize = (h[6] & 0x7F) << 21 |
        (h[7] & 0x7F) << 14 |
        (h[8] & 0x7F) << 7 |
        (h[9] & 0x7F);
    final footer = (h[5] & 0x10) != 0 ? 10 : 0;
    final next = pos + 10 + tagSize + footer;
    if (next >= size) break;
    pos = next;
  }
  return pos;
}

int _stripTrailingTags(RandomAccessFile raf, int size, int start) {
  var end = size;
  if (end - start > 128) {
    final v1 = _readAt(raf, end - 128, 3);
    if (_isAscii(v1, 0, 'TAG')) end -= 128;
  }
  if (end - start > 32) {
    final f = _readAt(raf, end - 32, 32);
    if (_isAscii(f, 0, 'APETAGEX')) {
      final bd = ByteData.sublistView(f);
      final tagSize = bd.getUint32(12, Endian.little);
      final flags = bd.getUint32(20, Endian.little);
      final hasHeader = (flags & 0x80000000) != 0;
      final cut = tagSize + (hasHeader ? 32 : 0);
      if (cut > 0 && end - cut > start) end -= cut;
    }
  }
  return end;
}

String? _flac(RandomAccessFile raf, int size, int start) {
  var pos = start + 4;
  for (var i = 0; i < 256; i++) {
    final h = _readAt(raf, pos, 4);
    if (h.length < 4) return null;
    final last = (h[0] & 0x80) != 0;
    final type = h[0] & 0x7F;
    final len = h[1] << 16 | h[2] << 8 | h[3];
    if (type == 0 && len >= 34) {
      final info = _readAt(raf, pos + 4, 34);
      if (info.length == 34) {
        final md5 = info.sublist(18, 34);
        if (md5.any((b) => b != 0)) return 'f1:${_hex(md5)}';
      }
    }
    pos += 4 + len;
    if (last) break;
    if (pos >= size) return null;
  }
  if (pos >= size) return null;
  return _hashRegion(raf, _Region('p1', pos, size));
}

_Region? _mp4(RandomAccessFile raf, int size) {
  _Region? best;
  var pos = 0;
  for (var i = 0; i < 10000 && pos + 8 <= size; i++) {
    final h = _readAt(raf, pos, 16);
    if (h.length < 8) break;
    final bd = ByteData.sublistView(h);
    var atomSize = bd.getUint32(0, Endian.big);
    var header = 8;
    if (atomSize == 1) {
      if (h.length < 16) break;
      atomSize = bd.getUint64(8, Endian.big);
      header = 16;
    } else if (atomSize == 0) {
      atomSize = size - pos;
    }
    if (atomSize < header) break;
    final end = min(pos + atomSize, size);
    if (_isAscii(h, 4, 'mdat')) {
      final r = _Region('a1', pos + header, end);
      if (best == null || r.length > best.length) best = r;
    }
    pos = end;
  }
  return best != null && best.length > 0 ? best : null;
}

_Region? _riff(RandomAccessFile raf, int size,
    {required bool bigEndian, required String dataId}) {
  var pos = 12;
  final endian = bigEndian ? Endian.big : Endian.little;
  for (var i = 0; i < 1000 && pos + 8 <= size; i++) {
    final h = _readAt(raf, pos, 8);
    if (h.length < 8) break;
    final len = ByteData.sublistView(h).getUint32(4, endian);
    if (_isAscii(h, 0, dataId)) {
      final start = pos + 8;
      final end = min(start + len, size);
      return end > start ? _Region('w1', start, end) : null;
    }
    pos += 8 + len + (len & 1);
  }
  return null;
}

String? _ogg(RandomAccessFile raf, int size) {
  // Header pages (identification, comments, codebook) carry granule 0 or -1;
  // the first page with a positive granule starts the audio.
  var pos = 0;
  var audioStart = -1;
  for (var i = 0; i < 4096 && pos + 27 <= size; i++) {
    final h = _readAt(raf, pos, 27);
    if (h.length < 27 || !_isAscii(h, 0, 'OggS')) break;
    final granule = ByteData.sublistView(h).getInt64(6, Endian.little);
    final segs = h[26];
    final table = _readAt(raf, pos + 27, segs);
    if (granule > 0) {
      audioStart = pos;
      break;
    }
    var body = 0;
    for (final s in table) {
      body += s;
    }
    pos += 27 + segs + body;
  }
  if (audioStart < 0 || audioStart >= size) return null;

  final tailLen = min(size - audioStart, 64 * 1024);
  final tail = _readAt(raf, size - tailLen, tailLen);
  var finalGranule = -1;
  for (var i = tail.length - 27; i >= 0; i--) {
    if (tail[i] == 0x4F && _isAscii(tail, i, 'OggS')) {
      final g = ByteData.sublistView(tail, i).getInt64(6, Endian.little);
      if (g > 0) {
        finalGranule = g;
        break;
      }
    }
  }
  if (finalGranule < 0) return null;

  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  input.add('o1'.codeUnits);
  input.add(_int64(finalGranule));
  final span = size - audioStart;
  for (var i = 0; i < _blockCount; i++) {
    final from = audioStart + (span - _blockSize) * i ~/ (_blockCount - 1);
    final page = _nextOggPage(raf, max(audioStart, from), size);
    if (page == null) continue;
    input.add(_int64(page.offsetFromStart(audioStart)));
    input.add(page.body);
  }
  input.close();
  return 'o1:${_hex(sink.value!.bytes.sublist(0, 16))}';
}

class _OggPage {
  final int offset;
  final Uint8List body;
  _OggPage(this.offset, this.body);
  int offsetFromStart(int start) => offset - start;
}

_OggPage? _nextOggPage(RandomAccessFile raf, int from, int size) {
  const window = 8 * 1024;
  var pos = from;
  while (pos + 27 < size) {
    final buf = _readAt(raf, pos, min(window, size - pos));
    for (var i = 0; i + 27 <= buf.length; i++) {
      if (buf[i] == 0x4F && _isAscii(buf, i, 'OggS') && buf[i + 4] == 0) {
        final at = pos + i;
        final h = _readAt(raf, at, 27);
        final segs = h[26];
        final table = _readAt(raf, at + 27, segs);
        var bodyLen = 0;
        for (final s in table) {
          bodyLen += s;
        }
        final body = _readAt(raf, at + 27 + segs, min(bodyLen, _oggBodySample));
        return _OggPage(at, body);
      }
    }
    if (buf.length < 28) break;
    pos += buf.length - 27;
  }
  return null;
}

String? _hashRegion(RandomAccessFile raf, _Region region) {
  if (region.length <= 0) return null;
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  input.add(region.kind.codeUnits);
  input.add(_int64(region.length));
  if (region.length <= _blockSize * _blockCount) {
    input.add(_readAt(raf, region.start, region.length));
  } else {
    for (var i = 0; i < _blockCount; i++) {
      final at =
          region.start + (region.length - _blockSize) * i ~/ (_blockCount - 1);
      input.add(_readAt(raf, at, _blockSize));
    }
  }
  input.close();
  return '${region.kind}:${_hex(sink.value!.bytes.sublist(0, 16))}';
}

Uint8List _int64(int v) {
  final b = ByteData(8)..setInt64(0, v, Endian.big);
  return b.buffer.asUint8List();
}

String _hex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

Future<String?> computeContentId(String path) async =>
    computeContentIdSync(path);

/// Result of probing one file on disk.
class FileProbe {
  final String path;
  final bool exists;
  final double? mtime;
  final String? contentId;
  const FileProbe(this.path, this.exists, this.mtime, this.contentId);
}

/// Stats every path and hashes those in [hashPaths]. Runs inside an isolate.
List<FileProbe> probeFilesSync(List<String> paths, Set<String> hashPaths) {
  final out = <FileProbe>[];
  for (final path in paths) {
    try {
      final stat = File(path).statSync();
      if (stat.type != FileSystemEntityType.file) {
        out.add(FileProbe(path, false, null, null));
        continue;
      }
      final mtime = stat.modified.millisecondsSinceEpoch / 1000.0;
      final cid = hashPaths.contains(path) ? computeContentIdSync(path) : null;
      out.add(FileProbe(path, true, mtime, cid));
    } catch (_) {
      out.add(FileProbe(path, false, null, null));
    }
  }
  return out;
}

Future<List<FileProbe>> probeFiles(
        List<String> paths, Set<String> hashPaths) async =>
    probeFilesSync(paths, hashPaths);
