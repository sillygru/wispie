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

  static final HttpClient _instance = () {
    final client = HttpClient();
    client.maxConnectionsPerHost = _maxConnectionsPerHost;
    client.idleTimeout = _idleTimeout;
    client.connectionTimeout = _connectionTimeout;
    return client;
  }();

  static HttpClient get instance => _instance;

  /// For tests that need to drop pooled sockets between cases.
  @visibleForTesting
  static void close() => _instance.close(force: true);
}
