import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'crypto.dart';

class SecretStoreException implements Exception {
  final String message;
  const SecretStoreException(this.message);
  @override
  String toString() => 'SecretStoreException: $message';
}

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// OS keychain. No plaintext fallback: failures surface as
/// [SecretStoreException] so the caller refuses to stay logged in.
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              // macOS builds are ad-hoc signed (no Team ID), so the data
              // protection keychain rejects every item with errSecMissingEntitlement
              // (-34018). The file-backed login keychain needs no entitlement.
              mOptions: MacOsOptions(usesDataProtectionKeychain: false),
            );
  final FlutterSecureStorage _s;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw SecretStoreException('Secure storage unavailable: $e');
    }
  }

  @override
  Future<String?> read(String key) => _guard(() => _s.read(key: key));
  @override
  Future<void> write(String key, String value) =>
      _guard(() => _s.write(key: key, value: value));
  @override
  Future<void> delete(String key) => _guard(() => _s.delete(key: key));
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

class PasswordPolicy {
  PasswordPolicy._();

  static const minLength = 10;
  static const usernamePattern = r'^[a-z0-9._-]{3,32}$';

  static const _common = {
    'password',
    'password1',
    'password123',
    '1234567890',
    '0123456789',
    '12345678910',
    'qwertyuiop',
    'qwerty12345',
    'qwerty123456',
    'iloveyou123',
    'letmein1234',
    'welcome1234',
    'admin12345',
    'abc1234567',
    'abcdefghij',
    'passw0rd123',
    'changeme123',
    'trustno1234',
    'monkey12345',
    'dragon12345',
    'football123',
    'baseball123',
    'superman123',
    'master12345',
    'princess123',
    'sunshine123',
    '1q2w3e4r5t',
    '1qaz2wsx3edc',
    'asdfghjkl1',
    'zxcvbnm1234',
  };

  /// Null when acceptable, otherwise a user-facing reason.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'Use at least $minLength characters';
    }
    final lower = password.toLowerCase();
    if (_common.contains(lower) || RegExp(r'^(.)\1+$').hasMatch(password)) {
      return 'This password is too common';
    }
    return null;
  }

  /// 0..4 rough strength for a meter.
  static int strength(String p) {
    if (validate(p) != null) return p.length < 6 ? 0 : 1;
    var classes = 0;
    if (RegExp('[a-z]').hasMatch(p)) classes++;
    if (RegExp('[A-Z]').hasMatch(p)) classes++;
    if (RegExp('[0-9]').hasMatch(p)) classes++;
    if (RegExp('[^A-Za-z0-9]').hasMatch(p)) classes++;
    var score = 1;
    if (p.length >= 14) score++;
    if (classes >= 3) score++;
    if (p.length >= 20 || (p.length >= 14 && classes == 4)) score++;
    return score.clamp(0, 4);
  }

  static String? validateUsername(String raw) {
    final u = SyncCrypto.normalizeUsername(raw);
    return RegExp(usernamePattern).hasMatch(u)
        ? null
        : 'Username must be 3-32 characters: a-z, 0-9, ".", "_" or "-"';
  }
}

class SyncSession {
  final String serverUrl;
  final String username;
  final String accountId;
  const SyncSession(this.serverUrl, this.username, this.accountId);
}

class RegisterResult {
  /// Shown to the user exactly once; never persisted.
  final String recoveryKey;
  const RegisterResult(this.recoveryKey);
}

class AccountService {
  AccountService({
    SecretStore? secrets,
    this.kdf = const KdfParams(),
    this.deviceLabel,
    SharedPreferences? prefs,
  })  : _secrets = secrets ?? SecureSecretStore(),
        _prefsOverride = prefs;

  final SecretStore _secrets;
  final SharedPreferences? _prefsOverride;
  final KdfParams kdf;
  final String? deviceLabel;

  static const prefServerUrl = 'sync_server_url';
  static const prefUsername = 'sync_username';
  static const prefAccountId = 'sync_account_id';
  static const defaultServerUrl = 'https://wispie-api.gru0.dev';
  static const _kAccountKey = 'sync_account_key';
  static const _kAccess = 'sync_access_token';
  static const _kRefresh = 'sync_refresh_token';

  SyncSession? _session;
  SyncApiClient? _client;
  Uint8List? _accountKey;

  SyncSession? get session => _session;
  bool get isLoggedIn => _session != null && _accountKey != null;

  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Restores a previous login from prefs + secure storage.
  Future<SyncSession?> load() async {
    final p = await _prefs;
    final url = p.getString(prefServerUrl);
    final user = p.getString(prefUsername);
    final id = p.getString(prefAccountId);
    final key = await _secrets.read(_kAccountKey);
    final access = await _secrets.read(_kAccess);
    final refresh = await _secrets.read(_kRefresh);
    if (url == null || user == null || id == null || key == null) {
      return null;
    }
    _accountKey = unb64u(key);
    _session = SyncSession(url, user, id);
    _client = _newClient(
      url,
      access != null && refresh != null ? SyncTokens(access, refresh) : null,
    );
    return _session;
  }

  SyncApiClient _newClient(String url, SyncTokens? t) => SyncApiClient(
        baseUrl: url,
        tokens: t,
        onTokensChanged: _persistTokens,
      );

  Future<void> _persistTokens(SyncTokens? t) async {
    if (t == null) {
      await _secrets.delete(_kAccess);
      await _secrets.delete(_kRefresh);
    } else {
      await _secrets.write(_kAccess, t.access);
      await _secrets.write(_kRefresh, t.refresh);
    }
  }

  /// Authenticated client for the sync engine. Throws when logged out.
  SyncApiClient get client {
    final c = _client;
    if (c == null) throw StateError('Not logged in');
    return c;
  }

  Future<Uint8List> dataKey() async {
    final k = _accountKey;
    if (k == null) throw StateError('Not logged in');
    return SyncCrypto.dataKey(k);
  }

  Future<void> _establish(
    String url,
    String username,
    String accountId,
    Uint8List accountKey,
    SyncApiClient client,
  ) async {
    try {
      await _secrets.write(_kAccountKey, b64u(accountKey));
      final t = client.tokens;
      if (t != null) await _persistTokens(t);
    } on SecretStoreException {
      await _clearSecrets();
      rethrow;
    }
    final p = await _prefs;
    await p.setString(prefServerUrl, url);
    await p.setString(prefUsername, username);
    await p.setString(prefAccountId, accountId);
    _accountKey = accountKey;
    _session = SyncSession(url, username, accountId);
    _client = _newClient(url, client.tokens);
  }

  Future<void> _clearSecrets() async {
    for (final k in [_kAccountKey, _kAccess, _kRefresh]) {
      try {
        await _secrets.delete(k);
      } on SecretStoreException {
        // Best effort; the key is also dropped from memory below.
      }
    }
  }

  Future<void> _clearLocal() async {
    await _clearSecrets();
    final p = await _prefs;
    for (final k in [prefUsername, prefAccountId]) {
      await p.remove(k);
    }
    _session = null;
    _client = null;
    _accountKey = null;
  }

  // ---- flows ----

  Future<RegisterResult> register({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final user = SyncCrypto.normalizeUsername(username);
    final uErr = PasswordPolicy.validateUsername(user);
    if (uErr != null) throw SyncApiException(0, 'bad_username', uErr);
    final pErr = PasswordPolicy.validate(password);
    if (pErr != null) throw SyncApiException(0, 'weak_password', pErr);

    final api = SyncApiClient(baseUrl: serverUrl);
    final info = await api.info();
    if (!info.registrationOpen) {
      throw const SyncApiException(
          403, 'registration_closed', 'Registration is closed');
    }
    final begin = await api.registerBegin(user);
    final salt = SyncCrypto.randomBytes(16);
    final powF = SyncCrypto.solvePow(begin.challenge, begin.bits);
    final masterF = SyncCrypto.deriveMasterKey(password, salt, kdf);
    final nonce = await powF;
    final master = await masterF;

    final accountKey = SyncCrypto.randomBytes(32);
    final recovery = RecoveryKey.generate();
    await api.registerFinish(
      accountId: begin.accountId,
      username: user,
      powNonce: nonce,
      powChallenge: begin.challenge,
      salt: salt,
      kdf: kdf.toJson(),
      authKey: await SyncCrypto.authKey(master),
      recoveryAuth: await SyncCrypto.recoveryAuth(recovery),
      wrappedByPw: await SyncCrypto.wrapAccountKey(
        await SyncCrypto.kek(master),
        accountKey,
        begin.accountId,
      ),
      wrappedByRk: await SyncCrypto.wrapAccountKeyByRecovery(
        await SyncCrypto.recoveryKek(recovery),
        accountKey,
        begin.accountId,
      ),
      deviceLabel: deviceLabel,
    );
    await _establish(serverUrl, user, begin.accountId, accountKey, api);
    return RegisterResult(RecoveryKey.encode(recovery));
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final user = SyncCrypto.normalizeUsername(username);
    final api = SyncApiClient(baseUrl: serverUrl);
    final pre = await api.prelogin(user);
    final master = await SyncCrypto.deriveMasterKey(
      password,
      pre.salt,
      KdfParams.fromJson(pre.kdf),
    );
    final res = await api.login(user, await SyncCrypto.authKey(master));
    final accountKey = await SyncCrypto.unwrapAccountKey(
      await SyncCrypto.kek(master),
      res.wrappedByPw!,
      res.accountId,
    );
    await _establish(serverUrl, user, res.accountId, accountKey, api);
  }

  Future<void> recover({
    required String serverUrl,
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final user = SyncCrypto.normalizeUsername(username);
    final pErr = PasswordPolicy.validate(newPassword);
    if (pErr != null) throw SyncApiException(0, 'weak_password', pErr);
    final rk = RecoveryKey.decode(recoveryKey);
    final api = SyncApiClient(baseUrl: serverUrl);
    final begin =
        await api.recoverBegin(user, await SyncCrypto.recoveryAuth(rk));
    final accountKey = await SyncCrypto.unwrapAccountKeyByRecovery(
      await SyncCrypto.recoveryKek(rk),
      begin.wrappedByRk,
      begin.accountId,
    );
    final salt = SyncCrypto.randomBytes(16);
    final master = await SyncCrypto.deriveMasterKey(newPassword, salt, kdf);
    await api.recoverFinish(
      recoverToken: begin.recoverToken,
      salt: salt,
      kdf: kdf.toJson(),
      authKey: await SyncCrypto.authKey(master),
      wrappedByPw: await SyncCrypto.wrapAccountKey(
        await SyncCrypto.kek(master),
        accountKey,
        begin.accountId,
      ),
    );
    await _establish(serverUrl, user, begin.accountId, accountKey, api);
  }

  Future<Uint8List> _currentAuthKey(String password) async {
    final s = _session!;
    final pre = await client.prelogin(s.username);
    final master = await SyncCrypto.deriveMasterKey(
      password,
      pre.salt,
      KdfParams.fromJson(pre.kdf),
    );
    return SyncCrypto.authKey(master);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final pErr = PasswordPolicy.validate(newPassword);
    if (pErr != null) throw SyncApiException(0, 'weak_password', pErr);
    final s = _session!;
    final current = await _currentAuthKey(currentPassword);
    final salt = SyncCrypto.randomBytes(16);
    final master = await SyncCrypto.deriveMasterKey(newPassword, salt, kdf);
    await client.changePassword(
      currentAuthKey: current,
      salt: salt,
      kdf: kdf.toJson(),
      authKey: await SyncCrypto.authKey(master),
      wrappedByPw: await SyncCrypto.wrapAccountKey(
        await SyncCrypto.kek(master),
        _accountKey!,
        s.accountId,
      ),
    );
  }

  /// Replaces the recovery key; the old one stops working.
  Future<String> generateRecoveryKey(String password) async {
    final current = await _currentAuthKey(password);
    final rk = RecoveryKey.generate();
    await client.replaceRecoveryKey(
      currentAuthKey: current,
      recoveryAuth: await SyncCrypto.recoveryAuth(rk),
      wrappedByRk: await SyncCrypto.wrapAccountKeyByRecovery(
        await SyncCrypto.recoveryKek(rk),
        _accountKey!,
        _session!.accountId,
      ),
    );
    return RecoveryKey.encode(rk);
  }

  /// Local state is always cleared, even if the server call fails.
  Future<void> logout() async {
    try {
      await _client?.logout();
    } on SyncApiException {
      // Offline logout still drops local credentials.
    } finally {
      await _clearLocal();
    }
  }

  /// Deletes the cloud account only; synced local data is untouched.
  Future<void> deleteAccount(String password) async {
    final key = await _currentAuthKey(password);
    await client.deleteAccount(key);
    await _clearLocal();
  }
}
