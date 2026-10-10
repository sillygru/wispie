import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/sync/account_service.dart';
import '../../services/sync/api_client.dart' show SyncApiException;
import '../components/app_feedback.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';
import 'sync_server_url_field.dart';

enum SyncAuthMode { create, login, recover }

/// Logged-out entry: create account, log in, or recover with recovery key.
class SyncAuthCard extends StatefulWidget {
  final ServerProbe probe;
  final Future<String> Function(String url, String user, String pw) onRegister;
  final Future<void> Function(String url, String user, String pw) onLogin;
  final Future<void> Function(String url, String user, String key, String pw)
      onRecover;
  final void Function(String recoveryKey) onRegistered;

  const SyncAuthCard({
    super.key,
    required this.probe,
    required this.onRegister,
    required this.onLogin,
    required this.onRecover,
    required this.onRegistered,
  });

  @override
  State<SyncAuthCard> createState() => _SyncAuthCardState();
}

class _SyncAuthCardState extends State<SyncAuthCard> {
  var _mode = SyncAuthMode.create;
  final _user = TextEditingController();
  final _pw = TextEditingController();
  final _key = TextEditingController();
  final _url = TextEditingController(text: AccountService.defaultServerUrl);
  bool _busy = false;
  bool _advanced = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pw.dispose();
    _key.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uErr = PasswordPolicy.validateUsername(_user.text);
    final pErr = _mode == SyncAuthMode.login
        ? (_pw.text.isEmpty ? 'Enter your password' : null)
        : PasswordPolicy.validate(_pw.text);
    if (uErr != null || pErr != null) {
      setState(() => _error = uErr ?? pErr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final url = _url.text.trim();
    try {
      switch (_mode) {
        case SyncAuthMode.create:
          final rk = await widget.onRegister(url, _user.text, _pw.text);
          if (mounted) widget.onRegistered(rk);
        case SyncAuthMode.login:
          await widget.onLogin(url, _user.text, _pw.text);
        case SyncAuthMode.recover:
          await widget.onRecover(url, _user.text, _key.text, _pw.text);
      }
    } on SyncApiException catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(SyncApiException e) =>
      e.status == 409 && _mode == SyncAuthMode.create
          ? 'That username is already taken'
          : e.message;

  @override
  Widget build(BuildContext context) {
    final create = _mode == SyncAuthMode.create;
    final strength = PasswordPolicy.strength(_pw.text);
    return AppSurface(
      margin: const EdgeInsets.all(AppTokens.s4),
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<SyncAuthMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: SyncAuthMode.create, label: Text('Create')),
              ButtonSegment(value: SyncAuthMode.login, label: Text('Log in')),
              ButtonSegment(
                  value: SyncAuthMode.recover, label: Text('Recover')),
            ],
            selected: {_mode},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() {
                      _mode = s.first;
                      _error = null;
                    }),
          ),
          const SizedBox(height: AppTokens.s3),
          TextField(
            controller: _user,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          if (_mode == SyncAuthMode.recover) ...[
            const SizedBox(height: AppTokens.s2),
            TextField(
              controller: _key,
              enabled: !_busy,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Recovery key'),
            ),
          ],
          const SizedBox(height: AppTokens.s2),
          TextField(
            controller: _pw,
            enabled: !_busy,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText:
                  _mode == SyncAuthMode.recover ? 'New password' : 'Password',
            ),
          ),
          if (_mode != SyncAuthMode.login && _pw.text.isNotEmpty) ...[
            const SizedBox(height: AppTokens.s2),
            LinearProgressIndicator(
              key: const ValueKey('strength_meter'),
              value: (strength + 1) / 5,
              color: strength >= 3
                  ? AppTokens.success
                  : (strength == 2 ? AppTokens.warning : AppTokens.danger),
              borderRadius: AppTokens.brPill,
            ),
          ],
          if (create)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.s2),
              child: Text(
                'Your data is end-to-end encrypted. If you lose both your '
                'password and recovery key, it cannot be recovered.',
                style: AppTokens.rowSubtitle(context),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.s2),
              child: Text(_error!, style: TextStyle(color: AppTokens.danger)),
            ),
          const SizedBox(height: AppTokens.s3),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy
                ? 'Securing your account...'
                : switch (_mode) {
                    SyncAuthMode.create => 'Create account',
                    SyncAuthMode.login => 'Log in',
                    SyncAuthMode.recover => 'Recover account',
                  }),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: AppTokens.s2),
              child: LinearProgressIndicator(),
            ),
          TextButton(
            onPressed: () => setState(() => _advanced = !_advanced),
            child: Text(_advanced ? 'Hide advanced' : 'Advanced'),
          ),
          if (_advanced)
            SyncServerUrlField(
                controller: _url, probe: widget.probe, enabled: !_busy),
        ],
      ),
    );
  }
}

/// Shows the recovery key once; Continue is gated on the checkbox.
class RecoveryKeyReveal extends StatefulWidget {
  final String recoveryKey;
  final VoidCallback onContinue;
  const RecoveryKeyReveal({
    super.key,
    required this.recoveryKey,
    required this.onContinue,
  });

  @override
  State<RecoveryKeyReveal> createState() => _RecoveryKeyRevealState();
}

class _RecoveryKeyRevealState extends State<RecoveryKeyReveal> {
  bool _saved = false;

  Future<void> _saveFile() async {
    try {
      final path = await FilePicker.saveFile(
        fileName: 'wispie-recovery-key.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
        bytes: utf8.encode('Wispie recovery key\n${widget.recoveryKey}\n'),
      );
      if (path != null && mounted) appSnack(context, 'Recovery key saved');
    } catch (e) {
      if (mounted) {
        appSnack(context, 'Could not save file', tone: AppTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      margin: const EdgeInsets.all(AppTokens.s4),
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your recovery key',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.s2),
          Text(
            'This is the only way to regain access if you forget your '
            'password. It is shown once. Store it somewhere safe.',
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          SelectableText(
            widget.recoveryKey,
            key: const ValueKey('recovery_key'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: AppTokens.s3),
          Wrap(spacing: AppTokens.s2, children: [
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.recoveryKey));
                appSnack(context, 'Copied');
              },
              child: const Text('Copy'),
            ),
            OutlinedButton(
              onPressed: _saveFile,
              child: const Text('Save to file'),
            ),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _saved,
            onChanged: (v) => setState(() => _saved = v ?? false),
            title: const Text('I saved my recovery key'),
          ),
          FilledButton(
            onPressed: _saved ? widget.onContinue : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

/// Mandatory first step after auth. Fresh accounts can only upload;
/// existing accounts choose merge or set up as new device.
class SyncInitialChoice extends StatelessWidget {
  final bool freshAccount;
  final bool busy;
  final VoidCallback onSyncEverything;
  final VoidCallback onMerge;
  final VoidCallback onNewDevice;

  const SyncInitialChoice({
    super.key,
    required this.freshAccount,
    required this.busy,
    required this.onSyncEverything,
    required this.onMerge,
    required this.onNewDevice,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      margin: const EdgeInsets.all(AppTokens.s4),
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            freshAccount ? 'Upload your library data' : 'Set up this device',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.s2),
          Text(
            freshAccount
                ? 'Auto-sync turns on after your data is uploaded once.'
                : 'Choose how this device joins your cloud data. Auto-sync '
                    'turns on after this step.',
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          if (freshAccount)
            FilledButton(
              onPressed: busy ? null : onSyncEverything,
              child: const Text('Sync everything now'),
            )
          else ...[
            FilledButton(
              onPressed: busy ? null : onMerge,
              child: const Text('Merge this device with cloud'),
            ),
            const SizedBox(height: AppTokens.s2),
            OutlinedButton(
              onPressed: busy ? null : onNewDevice,
              child: const Text('Set up as new device'),
            ),
            const SizedBox(height: AppTokens.s2),
            Text(
              'Merging keeps both sides. Setting up as a new device erases '
              'this device\'s synced data first and is safer if this device '
              'already holds an older copy of the same history.',
              style: AppTokens.rowSubtitle(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Another device replaced the cloud data; sync is paused until resolved.
class SyncEpochBanner extends StatelessWidget {
  final bool busy;
  final VoidCallback onReplace;
  final VoidCallback onMerge;
  final VoidCallback onOverwrite;

  const SyncEpochBanner({
    super.key,
    required this.busy,
    required this.onReplace,
    required this.onMerge,
    required this.onOverwrite,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      margin: const EdgeInsets.all(AppTokens.s4),
      padding: const EdgeInsets.all(AppTokens.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Cloud data was replaced',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.s2),
          Text(
            'Another device overwrote the cloud. Sync is paused on this '
            'device until you choose.',
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          FilledButton(
            onPressed: busy ? null : onMerge,
            child: const Text('Merge this device into the new cloud data'),
          ),
          TextButton(
            onPressed: busy ? null : onReplace,
            child: const Text('Replace this device with cloud'),
          ),
          TextButton(
            onPressed: busy ? null : onOverwrite,
            child: Text('Overwrite cloud with this device',
                style: TextStyle(color: AppTokens.danger)),
          ),
        ],
      ),
    );
  }
}
