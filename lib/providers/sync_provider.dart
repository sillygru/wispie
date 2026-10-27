import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/sync/api_client.dart' show SyncServerInfo;
import '../services/sync/changeset.dart';
import '../services/sync_service.dart';
import 'providers.dart';

class SyncState {
  final SyncStatus status;
  final String? username;
  final String? serverUrl;
  final SyncProgress? progress;
  final int? lastSyncedAtMs;
  final String? lastError;
  final bool autoSyncEnabled;
  final bool preferCloudQueue;
  final Set<String> categories;
  final int localPlayCount;
  final int remotePlayCount;
  final int totalPlayCount;

  const SyncState({
    this.status = SyncStatus.loggedOut,
    this.username,
    this.serverUrl,
    this.progress,
    this.lastSyncedAtMs,
    this.lastError,
    this.autoSyncEnabled = true,
    this.preferCloudQueue = false,
    this.categories = const {},
    this.localPlayCount = 0,
    this.remotePlayCount = 0,
    this.totalPlayCount = 0,
  });

  bool get freshAccount => SyncService.instance.freshAccount;
  bool get isAuthenticated => status != SyncStatus.loggedOut;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get isPaused => status == SyncStatus.pausedEpochChanged;
  bool get needsInitialChoice => status == SyncStatus.needsInitialChoice;
}

class SyncNotifier extends Notifier<SyncState> {
  StreamSubscription<SyncProgress>? _sub;
  bool _disposed = false;

  // Held here rather than read back off `state`: build() produces the first
  // snapshot, and reading state before build returns throws.
  int _localPlayCount = 0;
  int _remotePlayCount = 0;
  int _totalPlayCount = 0;

  SyncService get _svc => SyncService.instance;

  @override
  SyncState build() {
    _svc.addListener(_refresh);
    _sub = _svc.progressStream.listen((p) {
      if (_disposed) return;
      state = _snapshot(progress: p);
    });
    ref.onDispose(() {
      _disposed = true;
      _svc.removeListener(_refresh);
      _sub?.cancel();
    });
    unawaited(_loadBreakdown());
    return _snapshot();
  }

  SyncState _snapshot({SyncProgress? progress}) {
    final busy = _svc.status == SyncStatus.syncing;
    return SyncState(
      status: _svc.status,
      username: _svc.username,
      serverUrl: _svc.serverUrl,
      progress: busy ? (progress ?? _svc.progress) : null,
      lastSyncedAtMs: _svc.lastSyncMs,
      lastError: _svc.lastError,
      autoSyncEnabled: _svc.autoSyncEnabled,
      preferCloudQueue: _svc.preferCloudQueue,
      categories: _svc.categories,
      localPlayCount: _localPlayCount,
      remotePlayCount: _remotePlayCount,
      totalPlayCount: _totalPlayCount,
    );
  }

  void _refresh() {
    if (_disposed) return;
    final wasBusy = state.isSyncing;
    state = _snapshot();
    if (!wasBusy || state.isSyncing) return;
    unawaited(_loadBreakdown());
    // A finished cycle merged rows the open screens are still showing: the
    // playlists, favourites and streamed track rows that arrived with it.
    unawaited(ref.read(userDataProvider.notifier).refresh(force: false));
  }

  Future<void> _loadBreakdown() async {
    final b = await DatabaseService.instance
        .getPlayStatsDeviceBreakdown(_svc.deviceId);
    if (_disposed) return;
    _localPlayCount = b['localPlayCount'] ?? 0;
    _remotePlayCount = b['remotePlayCount'] ?? 0;
    _totalPlayCount = b['totalPlayCount'] ?? 0;
    state = _snapshot();
  }

  Future<void> refreshDeviceBreakdown() => _loadBreakdown();

  /// Returns the recovery key to show the user.
  Future<String> register(String serverUrl, String username, String password) =>
      _svc.register(
          serverUrl: serverUrl, username: username, password: password);

  Future<void> login(String serverUrl, String username, String password) =>
      _svc.login(serverUrl: serverUrl, username: username, password: password);

  Future<void> recover(String serverUrl, String username, String recoveryKey,
          String newPassword) =>
      _svc.recover(
        serverUrl: serverUrl,
        username: username,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
      );

  Future<SyncServerInfo> probeServer(String url) => _svc.probeServer(url);
  Future<void> changePassword(String c, String n) => _svc.changePassword(c, n);
  Future<String> newRecoveryKey(String pw) => _svc.newRecoveryKey(pw);
  Future<({int used, int quota})?> usage() => _svc.usage();

  Future<void> logout() => _svc.logout();
  Future<void> deleteAccount(String password) => _svc.deleteAccount(password);

  Future<bool> sync() => _svc.syncNow(manual: true);
  Future<bool> overwriteCloud() => _svc.overwriteCloud();
  Future<bool> mergeWithCloud() => _svc.mergeWithCloud();
  Future<bool> setUpAsNewDevice() => _svc.setUpAsNewDevice();

  Future<void> setAutoSyncEnabled(bool v) => _svc.setAutoSyncEnabled(v);
  Future<void> setPreferCloudQueue(bool v) => _svc.setPreferCloudQueue(v);
  Future<void> setCategories(Set<String> c) => _svc.setCategories(c);

  Future<void> setCategory(String id, bool on) {
    final next = {..._svc.categories};
    on ? next.add(id) : next.remove(id);
    return _svc.setCategories(next);
  }

  static const allCategories = SyncCategory.all;
}

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);
