import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// One pooled [HttpClient] shared by every outbound request.
///
/// Building a client per request meant a fresh DNS lookup, TCP handshake and
/// TLS negotiation for every lookup and every cover download, followed by a
/// forced close that threw the connection pool away. On a phone network that
/// churn is where most of the intermittent socket failures came from. A single
/// client keeps sockets warm across requests, and its pool is sized for the
/// art-fetch burst instead of the SDK default of five connections per host.
///
/// Requests go through [openUrl] / [awaitResponse] / [readUtf8]: a request
/// abandoned on timeout keeps its socket, and a wedged pool needs a restart.
class SharedHttpClient {
  SharedHttpClient._();

  /// Matches `PassiveArtFetcherService._burstConcurrency`, so a burst never
  /// queues behind the pool.
  static const int _maxConnectionsPerHost = 24;

  /// Short enough that sockets are not reused after a carrier or Wi-Fi idle
  /// timeout, which is what turns into a "connection reset" mid-download.
  static const Duration _idleTimeout = Duration(seconds: 15);

  /// Bounds the TCP/TLS phase on its own, so a dead network fails fast enough
  /// for the caller's overall timeout to still have room for a retry.
  static const Duration _connectionTimeout = Duration(seconds: 10);

  static final HttpClient _instance = _create();

  static HttpClient _create() {
    final client = HttpClient();
    client.maxConnectionsPerHost = _maxConnectionsPerHost;
    client.idleTimeout = _idleTimeout;
    client.connectionTimeout = _connectionTimeout;
    return client;
  }

  static HttpClient get instance => _instance;

  /// Opens a request, bounded so a full pool cannot hold the caller forever.
  static Future<HttpClientRequest> openUrl(
    HttpClient client,
    Uri uri, {
    String method = 'GET',
    Duration timeout = _connectionTimeout,
  }) =>
      client.openUrl(method, uri).timeout(timeout);

  /// Waits for the response headers, aborting the request when [timeout] passes.
  /// An abandoned request holds its pool slot until the OS gives up on it.
  static Future<HttpClientResponse> awaitResponse(
    HttpClientRequest request, {
    required Duration timeout,
  }) {
    return request.close().timeout(
      timeout,
      onTimeout: () {
        abort(request);
        throw TimeoutException('Request timed out', timeout);
      },
    );
  }

  /// Reads the body as UTF-8 within [timeout], aborting [request] on a stall.
  static Future<String> readUtf8(
    HttpClientResponse response, {
    required HttpClientRequest request,
    required Duration timeout,
  }) {
    return response.transform(utf8.decoder).join().timeout(
      timeout,
      onTimeout: () {
        abort(request);
        throw TimeoutException('Response body timed out', timeout);
      },
    );
  }

  /// Releases a request's connection. Safe to call once it finished.
  static void abort(HttpClientRequest request) {
    try {
      request.abort();
    } on Object {
      // Already done — nothing to release.
    }
  }

  /// For tests that need to drop pooled sockets between cases.
  @visibleForTesting
  static void close() => _instance.close(force: true);
}
