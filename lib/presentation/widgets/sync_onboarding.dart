import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final pErr = _mode == SyncAuthMode.login
        ? (_pw.text.isEmpty ? l10n.syncEnterPassword : null)
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
      if (mounted) setState(() => _error = l10n.syncAuthUnexpectedError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(SyncApiException e) =>
      e.status == 409 && _mode == SyncAuthMode.create
          ? context.l10n.syncUsernameTaken
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
            segments: [
              ButtonSegment(
                  value: SyncAuthMode.create,
                  label: Text(context.l10n.actionCreate)),
              ButtonSegment(
                  value: SyncAuthMode.login,
                  label: Text(context.l10n.syncModeLogIn)),
              ButtonSegment(
                  value: SyncAuthMode.recover,
                  label: Text(context.l10n.syncModeRecover)),
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
            decoration: InputDecoration(labelText: context.l10n.syncUsername),
          ),
          if (_mode == SyncAuthMode.recover) ...[
            const SizedBox(height: AppTokens.s2),
            TextField(
              controller: _key,
              enabled: !_busy,
              autocorrect: false,
              decoration:
                  InputDecoration(labelText: context.l10n.syncRecoveryKeyTitle),
            ),
          ],
          const SizedBox(height: AppTokens.s2),
          TextField(
            controller: _pw,
            enabled: !_busy,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _mode == SyncAuthMode.recover
                  ? context.l10n.syncNewPassword
                  : context.l10n.syncPassword,
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
                context.l10n.syncEncryptionWarning,
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
                ? context.l10n.syncSecuringAccount
                : switch (_mode) {
                    SyncAuthMode.create => context.l10n.syncCreateAccount,
                    SyncAuthMode.login => context.l10n.syncLogIn,
                    SyncAuthMode.recover => context.l10n.syncRecoverAccount,
                  }),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.s2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 0.95),
                duration: AppTokens.dSlow * 10,
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => LinearProgressIndicator(
                  value: v,
                  borderRadius: AppTokens.brPill,
                ),
              ),
            ),
          TextButton(
            onPressed: () => setState(() => _advanced = !_advanced),
            child: Text(_advanced
                ? context.l10n.syncHideAdvanced
                : context.l10n.syncAdvanced),
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
        bytes: utf8.encode('wispie recovery key\n${widget.recoveryKey}\n'),
      );
      if (path != null && mounted) {
        appSnack(context, context.l10n.syncRecoveryKeySaved);
      }
    } catch (e) {
      if (mounted) {
        appSnack(context, context.l10n.syncCouldNotSaveFile,
            tone: AppTone.danger);
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
          Text(context.l10n.syncRecoveryKeyRevealTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.s2),
          Text(
            context.l10n.syncRecoveryKeyRevealBody,
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
                appSnack(context, context.l10n.syncCopied);
              },
              child: Text(context.l10n.syncCopy),
            ),
            OutlinedButton(
              onPressed: _saveFile,
              child: Text(context.l10n.syncSaveToFile),
            ),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _saved,
            onChanged: (v) => setState(() => _saved = v ?? false),
            title: Text(context.l10n.syncRecoveryKeySavedCheckbox),
          ),
          FilledButton(
            onPressed: _saved ? widget.onContinue : null,
            child: Text(context.l10n.syncContinue),
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
            freshAccount
                ? context.l10n.syncUploadTitle
                : context.l10n.syncSetupDeviceTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.s2),
          Text(
            freshAccount
                ? context.l10n.syncFreshAccountBody
                : context.l10n.syncChooseDeviceBody,
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          if (freshAccount)
            FilledButton(
              onPressed: busy ? null : onSyncEverything,
              child: Text(context.l10n.syncEverythingNow),
            )
          else ...[
            FilledButton(
              onPressed: busy ? null : onMerge,
              child: Text(context.l10n.syncMergeWithCloud),
            ),
            const SizedBox(height: AppTokens.s2),
            OutlinedButton(
              onPressed: busy ? null : onNewDevice,
              child: Text(context.l10n.syncSetupNewDevice),
            ),
            const SizedBox(height: AppTokens.s2),
            Text(
              context.l10n.syncMergeExplanation,
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
          Text(context.l10n.syncCloudReplacedTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.s2),
          Text(
            context.l10n.syncCloudReplacedBody,
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s3),
          FilledButton(
            onPressed: busy ? null : onMerge,
            child: Text(context.l10n.syncMergeIntoCloud),
          ),
          TextButton(
            onPressed: busy ? null : onReplace,
            child: Text(context.l10n.syncReplaceDeviceTile),
          ),
          TextButton(
            onPressed: busy ? null : onOverwrite,
            child: Text(context.l10n.syncOverwriteCloudTile,
                style: TextStyle(color: AppTokens.danger)),
          ),
        ],
      ),
    );
  }
}
