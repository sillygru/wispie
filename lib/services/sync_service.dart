import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import 'sync/account_service.dart';
import 'sync/api_client.dart'
    show SyncApiException, SyncApiClient, SyncServerInfo;
import 'sync/changeset.dart';
import 'sync/hlc.dart';
import 'sync/sync_engine.dart';

export 'sync/sync_engine.dart'
    show
        SyncPhase,
        SyncProgress,
        SyncEpochChangedException,
        SyncRollbackException,
        SyncNotReadyException;

/// What the UI needs to know about the account/engine lifecycle.
enum SyncStatus {
  loggedOut,
  needsInitialChoice,
  ready,
  syncing,
  pausedEpochChanged,
  error,
}

/// App-level owner of the sync account and engine (plan_sync.md section 1.9).
/// Single-flight: one operation at a time, requests while busy coalesce.
class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  static const _kCategories = 'sync_categories';
  static const _kAutoEnabled = 'auto_sync_enabled';
  static const _kQueuePriority = 'sync_queue_priority';
  static const Duration _startDelay = Duration(seconds: 5);
  static const Duration _foregroundGap = Duration(hours: 1);
  static const Duration _dirtyDebounce = Duration(minutes: 5);
  static const Duration _periodic = Duration(hours: 1);

  static const List<String> _legacyKeys = [
    'sync_processed_files',
    'sync_last_upload_hash',
    'sync_last_timestamp',
    'sync_signed_in',
    'google_account_email',
  ];

  final AccountService _account = AccountService();
  SyncEngine? _engine;
  SyncKv? _kv;
  String? _deviceId;
  bool _busy = false;
  bool _syncAgain = false;
  // A manual sync requested while another op ran must keep its manual intent
  // (it gates applying the cloud queue) when it is replayed.
  bool _syncAgainManual = false;
  bool _initialized = false;
  bool _foreground = true;
  String? _lastError;
  Timer? _debounce;
  Timer? _periodicTimer;
  SyncProgress? _progress;
  final StreamController<SyncProgress> _progressCtl =
      StreamController<SyncProgress>.broadcast();

  Stream<SyncProgress> get progressStream => _progressCtl.stream;
  SyncProgress? get progress => _progress;
  AccountService get account => _account;
  bool get isBusy => _busy;
  String? get lastError => _lastError;
  String? get username => _account.session?.username;
  String? get serverUrl => _account.session?.serverUrl;
  bool get isLoggedIn => _account.isLoggedIn;

  /// Kept for callers that only care about being signed in.
  bool get isSignedIn => isLoggedIn;
  bool get isSyncing => _busy;

  SyncStatus get status {
    if (!isLoggedIn) return SyncStatus.loggedOut;
    if (_busy) return SyncStatus.syncing;
    final e = _engine;
    if (e == null || !e.initialDone) return SyncStatus.needsInitialChoice;
    if (e.pausedForEpoch != null) return SyncStatus.pausedEpochChanged;
    if (_lastError != null) return SyncStatus.error;
    return SyncStatus.ready;
  }

  int? get lastSyncMs => _engine?.lastSyncMs;

  String get deviceId {
    if (_deviceId == null) {
      _deviceId = _generateDeviceId();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('sync_device_id', _deviceId!);
      });
    }
    return _deviceId!;
  }

  Set<String> get categories {
    final raw = _kv?.get(_kCategories) as String?;
    if (raw == null) return SyncCategory.all.toSet();
    return (jsonDecode(raw) as List)
        .cast<String>()
        .where(SyncCategory.all.contains)
        .toSet();
  }

  /// Whether a manual sync lets the cloud's current queue replace the local one.
  bool get preferCloudQueue => _kv?.get(_kQueuePriority) == 'cloud';

  Future<void> setPreferCloudQueue(bool cloud) async {
    await _kv?.set(_kQueuePriority, cloud ? 'cloud' : 'local');
    notifyListeners();
  }

  final StreamController<Map<String, dynamic>> _queueAppliedCtl =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Fires with the cloud queue after a manual sync replaced the local one.
  Stream<Map<String, dynamic>> get queueApplied => _queueAppliedCtl.stream;

  bool get autoSyncEnabled => _kv?.get(_kAutoEnabled) != false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('sync_device_id');
    if (_deviceId == null) {
      _deviceId = _generateDeviceId();
      await prefs.setString('sync_device_id', _deviceId!);
    }
    for (final k in _legacyKeys) {
      if (prefs.containsKey(k)) await prefs.remove(k);
    }
    _kv = PrefsSyncKv(prefs);
    await Hlc.instance.load();
    try {
      final session = await _account.load();
      if (session != null) await _buildEngine();
    } catch (e) {
      debugPrint('SyncService: restore failed: $e');
    }
    notifyListeners();
    _scheduleStart();
  }

  Future<void> _buildEngine() async {
    final stats = DatabaseService.instance.getStatsDatabase();
    final user = DatabaseService.instance.getUserDataDatabase();
    final session = _account.session;
    if (stats == null || user == null || session == null) return;
    final tmp = await getTemporaryDirectory();
    _engine = SyncEngine(
      client: _account.client,
      dataKey: await _account.dataKey(),
      accountId: session.accountId,
      changeset: Changeset(
        stats: stats,
        userData: user,
        deviceId: deviceId,
        deviceName: Platform.operatingSystem,
      ),
      kv: _kv ?? await PrefsSyncKv.open(),
      tmpDir: Directory('${tmp.path}/wispie_sync'),
      stampSetting: DatabaseService.instance.stampSettingDirty,
      categories: () => categories,
      preferCloudQueue: () => preferCloudQueue,
      onQueueApplied: _queueAppliedCtl.add,
      onProgress: _emit,
    );
  }

  void _emit(SyncProgress p) {
    _progress = p;
    if (!_progressCtl.isClosed) _progressCtl.add(p);
  }

  // -------------------------------------------------------------- account

  Future<String> register({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final r = await _account.register(
        serverUrl: serverUrl, username: username, password: password);
    await _afterAuth();
    freshAccount = true;
    return r.recoveryKey;
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await _account.login(
        serverUrl: serverUrl, username: username, password: password);
    await _afterAuth();
  }

  Future<void> recover({
    required String serverUrl,
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    await _account.recover(
      serverUrl: serverUrl,
      username: username,
      recoveryKey: recoveryKey,
      newPassword: newPassword,
    );
    await _afterAuth();
  }

  /// True between registering and the first upload; picks the onboarding step.
  bool freshAccount = false;

  /// Validates a candidate server URL via `GET /v1/info`.
  Future<SyncServerInfo> probeServer(String url) =>
      SyncApiClient(baseUrl: url).info();

  Future<void> changePassword(String current, String next) async {
    await _account.changePassword(currentPassword: current, newPassword: next);
  }

  Future<String> newRecoveryKey(String password) =>
      _account.generateRecoveryKey(password);

  /// Cloud usage, or null when offline / not logged in.
  Future<({int used, int quota})?> usage() async {
    if (!isLoggedIn) return null;
    try {
      final s = await _account.client.state();
      return (used: s.usageBytes, quota: s.quotaBytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _afterAuth() async {
    _lastError = null;
    await _clearEngineState();
    await _buildEngine();
    notifyListeners();
  }

  Future<void> logout() async {
    await _account.logout();
    freshAccount = false;
    await _clearEngineState();
    _engine = null;
    _lastError = null;
    _cancelTimers();
    notifyListeners();
  }

  Future<void> deleteAccount(String password) async {
    await _account.deleteAccount(password);
    await _clearEngineState();
    _engine = null;
    _lastError = null;
    _cancelTimers();
    notifyListeners();
  }

  Future<void> _clearEngineState() async {
    final kv = _kv;
    if (kv == null) return;
    for (final k in [
      SyncEngine.kEpoch,
      SyncEngine.kCursor,
      SyncEngine.kHighEpoch,
      SyncEngine.kHighHead,
      SyncEngine.kInitialDone,
      SyncEngine.kSnapshotApplied,
      SyncEngine.kEpochChanged,
      SyncEngine.kLastSync,
      SyncEngine.kLastCompaction,
      SyncEngine.kSettingsSeen,
      SyncEngine.kPendingPull,
      SyncEngine.kDownloadId,
    ]) {
      await kv.set(k, null);
    }
  }

  // ------------------------------------------------------------- settings

  /// Reattaches the engine to the database handles that exist now.
  ///
  /// A restore replaces the database files, and the engine holds the connections
  /// it was built with: after one, every sync write would go to a closed
  /// handle. Called after a restore completes.
  Future<void> rebuildAfterDatabaseReplace() async {
    if (!isLoggedIn) return;
    try {
      await _buildEngine();
      notifyListeners();
    } catch (e) {
      debugPrint('SyncService: could not rebuild after a restore: $e');
    }
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    await _kv?.set(_kAutoEnabled, enabled);
    if (enabled) {
      _scheduleStart();
    } else {
      _cancelTimers();
    }
    notifyListeners();
  }

  Future<void> setCategories(Set<String> next) async {
    final before = categories;
    await _kv?.set(_kCategories, jsonEncode(next.toList()..sort()));
    await _engine?.queueCategoryPull(next.difference(before));
    notifyListeners();
  }

  // ----------------------------------------------------------- operations

  /// Set by the player so a run publishes the live playhead once, right before
  /// it uploads, instead of a timer writing the row while music plays.
  Future<void> Function()? beforeRun;

  /// Runs [op] single-flight. Returns false if another operation is running.
  Future<bool> _run(Future<void> Function(SyncEngine e) op,
      {bool queueIfBusy = false}) async {
    final e = _engine;
    if (e == null) return false;
    if (_busy) {
      if (queueIfBusy) _syncAgain = true;
      return false;
    }
    _busy = true;
    _lastError = null;
    notifyListeners();
    var ok = false;
    try {
      // A local state refresh must never be able to fail the sync itself.
      try {
        await beforeRun?.call();
      } catch (err) {
        debugPrint('SyncService: pre-run state flush failed: $err');
      }
      await op(e);
      ok = true;
    } on SyncEpochChangedException {
      // Surfaced through [status]; not an error banner.
    } catch (err) {
      _lastError = _describe(err);
      _emit(SyncProgress(SyncPhase.error, message: _lastError!));
    } finally {
      _busy = false;
      notifyListeners();
    }
    if (_syncAgain) {
      final manual = _syncAgainManual;
      _syncAgain = false;
      _syncAgainManual = false;
      unawaited(syncNow(manual: manual));
    }
    return ok;
  }

  static String _describe(Object e) {
    if (e is SyncApiException) return e.message;
    return e.toString();
  }

  Future<bool> syncNow({bool manual = false}) {
    if (manual && _busy) _syncAgainManual = true;
    return _run((e) => e.sync(manual: manual), queueIfBusy: true);
  }

  /// First upload after registering, also "overwrite cloud with this device".
  Future<bool> overwriteCloud() => _run((e) => e.overwriteCloud());

  Future<bool> mergeWithCloud() => _run((e) => e.mergeWithCloud());

  /// Also covers "overwrite local with cloud" and "replace this device".
  Future<bool> setUpAsNewDevice() => _run((e) => e.setUpAsNewDevice());

  // ------------------------------------------------------------ auto-sync

  bool get _autoReady {
    final e = _engine;
    return isLoggedIn &&
        e != null &&
        e.initialDone &&
        e.pausedForEpoch == null &&
        autoSyncEnabled;
  }

  void _scheduleStart() {
    if (!_autoReady) return;
    Timer(_startDelay, () {
      if (_autoReady) unawaited(syncNow());
    });
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodic, (_) {
      if (_foreground && _autoReady) unawaited(syncNow());
    });
  }

  void _cancelTimers() {
    _debounce?.cancel();
    _periodicTimer?.cancel();
    _debounce = null;
    _periodicTimer = null;
  }

  /// Called after a user-intent write stamped a synced row.
  void notifyLocalWrite() {
    if (_busy || !_autoReady) return;
    _debounce?.cancel();
    _debounce = Timer(_dirtyDebounce, () {
      if (_autoReady) unawaited(syncNow());
    });
  }

  void onForeground() {
    _foreground = true;
    if (!_autoReady) return;
    final last = lastSyncMs;
    if (last != null &&
        DateTime.now().millisecondsSinceEpoch - last <
            _foregroundGap.inMilliseconds) {
      return;
    }
    unawaited(syncNow());
  }

  void onBackground() => _foreground = false;

  String _generateDeviceId() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return sha1.convert(bytes).toString().substring(0, 12);
  }
}

/// Re-exported so UI code can validate URLs without importing the client.
bool isInsecureSyncUrl(String url) => SyncApiClient.isInsecure(url);
