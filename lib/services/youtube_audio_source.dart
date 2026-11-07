// SPDX-License-Identifier: GPL-3.0-only

// just_audio labels its stream source API experimental, but it is the only way
// to serve audio that is fetched lazily, and LockCachingAudioSource is built on
// the same interface. The alternative is resolving every queue entry up front.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'online_audio_cache.dart';
import 'shared_http_client.dart';
import 'youtube_service.dart';

/// Audio source that resolves its stream when playback actually reaches it.
///
/// A queue built from search results can hold dozens of tracks, and resolving
/// every one up front is both slow and the fastest way to get rate limited. This
/// source is handed to just_audio as a cheap object: the InnerTube lookup, the
/// signed URL and the first byte of audio all happen on the first request, so a
/// track only costs a network round trip if it is actually played.
///
/// While streaming it also fills the disk cache, so the second play of a track
/// never touches the network. A partial file is kept when playback is
/// interrupted; the next request for the same range appends to it.
class YouTubeAudioSource extends StreamAudioSource {
  YouTubeAudioSource({
    required this.videoId,
    required this.title,
    required this.artist,
    super.tag,
  });

  final String videoId;
  final String title;
  final String artist;

  static const Duration _headTimeout = Duration(seconds: 12);
  static final Set<String> _cacheWriters = {};

  YouTubeAudioStream? _stream;

  File? _target;
  File? _partial;
  int _writtenBytes = 0;
  bool _cacheable = true;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    var attempt = 0;
    Object? failure;

    while (attempt < 2) {
      attempt++;
      try {
        return await _prepare(from, end, refresh: attempt > 1);
      } on Object catch (error) {
        failure = error;
        if (attempt > 1) break;
        // A stale or refused CDN URL is recovered by asking a different client
        // for a fresh one, which is what yt-dlp does when a media request 403s.
        YouTubeService.instance.reportStreamFailure(videoId);
        _stream = null;
      }
    }

    throw failure ??
        const YouTubeApiException(
          'Could not stream this video.',
          kind: YouTubeErrorKind.unavailable,
        );
  }

  Future<StreamAudioResponse> _prepare(
    int from,
    int? end, {
    required bool refresh,
  }) async {
    final audio = await _resolve(refresh: refresh);

    final request = await SharedHttpClient.instance.getUrl(audio.url).timeout(
          _headTimeout,
        );
    // `end` arrives exclusive, and an HTTP Range's last byte is inclusive.
    final lastByte = end == null ? '' : '${end - 1 < from ? from : end - 1}';
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-$lastByte');
    request.headers.set(HttpHeaders.userAgentHeader, _mediaUserAgent);
    final response = await request.close().timeout(_headTimeout);

    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      await response.drain<void>().catchError((_) {});
      throw YouTubeApiException(
        'YouTube CDN returned HTTP ${response.statusCode}.',
        kind: YouTubeErrorKind.blocked,
        statusCode: response.statusCode,
      );
    }

    final total = _totalLength(response, audio.contentLength);

    // A short header probe can overlap the first playback request.
    final isHeaderProbe = from == 0 && end != null && end <= 3 && end < total;
    final range = response.headers.value(HttpHeaders.contentRangeHeader);
    final startsAtRequestedByte = response.statusCode == HttpStatus.ok
        ? from == 0
        : range?.startsWith('bytes $from-') == true;
    RandomAccessFile? sink;
    if (_cacheable &&
        total > 0 &&
        !isHeaderProbe &&
        _writtenBytes < total &&
        (end == null || end > _writtenBytes) &&
        startsAtRequestedByte &&
        from <= _writtenBytes &&
        _cacheWriters.add(videoId)) {
      try {
        final cache = OnlineAudioCache.instance;
        final existing = await cache.completeFile(
          OnlineAudioCache.providerYouTube,
          videoId,
        );
        if (existing == null) {
          final target = await cache.fileFor(
            provider: OnlineAudioCache.providerYouTube,
            id: videoId,
            itag: audio.itag,
            extension: audio.containerExtension,
          );
          final sameFormat = _target?.path == target.path;
          if (sameFormat || from == 0) {
            _target = target;
            _partial = File('${target.path}.part');
            sink = await _openSink(append: sameFormat);
          }
        }
      } catch (error) {
        debugPrint('YouTube: could not open the cache for $videoId: $error');
      } finally {
        if (sink == null) _cacheWriters.remove(videoId);
      }
    }

    // just_audio forwards the client's last byte + 1 as an exclusive end, so a
    // `bytes=0-2` probe must be answered with 3 bytes. Declaring the whole
    // track here makes just_audio close the response short of contentLength,
    // which surfaces as `Content size below specified contentLength`.
    final int? available = total > 0
        ? total - from
        : (response.contentLength > 0 ? response.contentLength : null);
    final int? length = available == null
        ? null
        : end != null
            ? (end - from).clamp(0, available).toInt()
            : available;

    return StreamAudioResponse(
      sourceLength: total > 0 ? total : null,
      offset: length == null ? null : from,
      contentLength: length,
      contentType: audio.mimeType,
      stream: sink == null ? response : _tee(response, sink, from, total),
    );
  }

  Future<YouTubeAudioStream> _resolve({required bool refresh}) async {
    if (!refresh && _stream != null) return _stream!;
    try {
      final stream = await YouTubeService.instance.resolveAudioStream(videoId);
      _stream = stream;
      _cacheable = true;
      return stream;
    } on Object catch (error) {
      debugPrint('YouTube: could not resolve $videoId: $error');
      rethrow;
    }
  }

  int _totalLength(
    HttpClientResponse response,
    int? declaredLength,
  ) {
    final range = response.headers.value(HttpHeaders.contentRangeHeader);
    if (range != null) {
      final slash = range.lastIndexOf('/');
      if (slash >= 0) {
        final total = int.tryParse(range.substring(slash + 1));
        if (total != null && total > 0) return total;
      }
    }
    if (response.statusCode == HttpStatus.ok && response.contentLength > 0) {
      return response.contentLength;
    }
    if (declaredLength != null && declaredLength > 0) return declaredLength;
    return 0;
  }

  Future<RandomAccessFile?> _openSink({required bool append}) async {
    final partial = _partial;
    if (partial == null) return null;
    try {
      if (append &&
          await partial.exists() &&
          await partial.length() == _writtenBytes) {
        return await partial.open(mode: FileMode.append);
      }
      if (!append || _writtenBytes == 0) {
        _writtenBytes = 0;
        return await partial.open(mode: FileMode.write);
      }
      _writtenBytes = 0;
      return null;
    } catch (error) {
      debugPrint('YouTube: cache write disabled: $error');
      _cacheable = false;
      return null;
    }
  }

  /// The player can abandon its initial response to read the MP4 index or seek.
  /// Keep consuming that same response so the download can still finish.
  Stream<List<int>> _tee(
    HttpClientResponse response,
    RandomAccessFile sink,
    int from,
    int total,
  ) async* {
    final chunks = StreamIterator(response.timeout(_headTimeout));
    var offset = from;
    var responseEnded = false;

    Future<void> cacheChunk(List<int> chunk) async {
      final end = offset + chunk.length;
      if (end > _writtenBytes && _writtenBytes < total) {
        final writeEnd = end > total ? total : end;
        await sink.writeFrom(chunk, _writtenBytes - offset, writeEnd - offset);
        _writtenBytes = writeEnd;
      }
      offset = end;
    }

    try {
      while (await chunks.moveNext()) {
        final chunk = chunks.current;
        await cacheChunk(chunk);
        yield chunk;
      }
      responseEnded = true;
    } catch (error) {
      responseEnded = true;
      debugPrint('YouTube: stream for $videoId ended early: $error');
      rethrow;
    } finally {
      try {
        if (!responseEnded) {
          while (_writtenBytes < total && await chunks.moveNext()) {
            await cacheChunk(chunks.current);
          }
        }
      } catch (error) {
        debugPrint('YouTube: cache fill for $videoId ended early: $error');
      } finally {
        try {
          await chunks.cancel();
          await sink.close();
          if (_writtenBytes == total) await _finalize();
        } catch (error) {
          debugPrint('YouTube: could not close the cache for $videoId: $error');
        } finally {
          _cacheWriters.remove(videoId);
        }
      }
    }
  }

  Future<void> _finalize() async {
    final partial = _partial;
    final target = _target;
    if (partial == null || target == null) return;
    try {
      await partial.rename(target.path);
      await OnlineAudioCache.instance.markComplete(target);
    } catch (error) {
      debugPrint('YouTube: could not finish the cache write: $error');
    }
  }

  @override
  String toString() => 'YouTubeAudioSource($videoId)';

  static const String _mediaUserAgent =
      'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip';
}
