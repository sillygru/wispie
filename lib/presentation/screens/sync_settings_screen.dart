import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_settings.dart';
import '../components/app_screen_header.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../widgets/danger_confirm_dialog.dart';
import '../widgets/sync_onboarding.dart';
import '../widgets/sync_progress_card.dart';
import '../../providers/sync_provider.dart';
import '../../services/sync/changeset.dart';
import '../../services/sync_service.dart';
import '../../providers/settings_provider.dart';

enum SyncStage { loggedOut, initialChoice, epochPaused, main }

SyncStage syncStageFor(SyncStatus s) => switch (s) {
      SyncStatus.loggedOut => SyncStage.loggedOut,
      SyncStatus.needsInitialChoice => SyncStage.initialChoice,
      SyncStatus.pausedEpochChanged => SyncStage.epochPaused,
      _ => SyncStage.main,
    };

/// Auto-sync is only offered once the first upload/setup has completed.
bool autoSyncAvailable(SyncStatus s) => syncStageFor(s) == SyncStage.main;

class SyncSettingsScreen extends ConsumerStatefulWidget {
  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const SyncSettingsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  String? _pendingRecoveryKey;
  Future<({int used, int quota})?>? _usage;

  SyncNotifier get _n => ref.read(syncProvider.notifier);

  static const _categoryLabels = <String, (AppIconData, String, String)>{
    SyncCategory.playStats: (
      AppIcons.analytics,
      'Play stats',
      'Listening history and play counts'
    ),
    SyncCategory.favorites: (AppIcons.favorite, 'Favorites', 'Favorite songs'),
    SyncCategory.suggestless: (
      AppIcons.info,
      'Suggest less',
      'Songs you asked to see less of'
    ),
    SyncCategory.hidden: (AppIcons.folderOff, 'Hidden songs', 'Hidden songs'),
    SyncCategory.playlists: (AppIcons.playlist, 'Playlists', 'All playlists'),
    SyncCategory.mergedSongs: (
      AppIcons.playlist,
      'Merged songs',
      'Merged song groups'
    ),
    SyncCategory.settings: (
      AppIcons.settings,
      'App settings',
      'Theme, playback, and UI preferences'
    ),
    SyncCategory.artistArt: (
      AppIcons.image,
      'Artist art',
      'Online artist cover choices'
    ),
    SyncCategory.albumArt: (
      AppIcons.image,
      'Album art',
      'Online album cover choices'
    ),
  };

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(syncProvider);
    final stage = syncStageFor(st.status);
    final busy = st.isSyncing;
    final children = <Widget>[];

    if (_pendingRecoveryKey != null && st.isAuthenticated) {
      children.add(RecoveryKeyReveal(
        recoveryKey: _pendingRecoveryKey!,
        onContinue: () => setState(() => _pendingRecoveryKey = null),
      ));
    } else {
      if (busy) children.add(SyncProgressCard(progress: st.progress));
      switch (stage) {
        case SyncStage.loggedOut:
          children.add(SyncAuthCard(
            probe: _n.probeServer,
            onRegister: (u, n, p) => _n.register(u, n, p),
            onLogin: (u, n, p) => _n.login(u, n, p),
            onRecover: (u, n, k, p) => _n.recover(u, n, k, p),
            onRegistered: (k) => setState(() => _pendingRecoveryKey = k),
          ));
          children.add(_privacy());
        case SyncStage.initialChoice:
          children.add(SyncInitialChoice(
            freshAccount: st.freshAccount,
            busy: busy,
            onSyncEverything: () => _n.overwriteCloud(),
            onMerge: () => _n.mergeWithCloud(),
            onNewDevice: _confirmReplaceLocal,
          ));
          children.add(_accountGroup(st));
        case SyncStage.epochPaused:
          children.add(SyncEpochBanner(
            busy: busy,
            onMerge: () => _n.mergeWithCloud(),
            onReplace: _confirmReplaceLocal,
            onOverwrite: _confirmOverwriteCloud,
          ));
          children.add(_accountGroup(st));
        case SyncStage.main:
          children.addAll(_mainGroups(st, busy));
      }
    }

    final content = AppSettingsList(children: children);
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: const AppTopBar(title: 'Sync'),
      body: content,
    );
  }

  Widget _privacy() => AppSettingsGroup(
        label: 'Privacy',
        children: [
          _infoTile(AppIcons.security, 'End-to-end encrypted',
              'Your data is encrypted on this device before upload. The server only stores ciphertext and cannot read your library, history, or settings.'),
          _infoTile(AppIcons.info, 'Recovery key',
              'If you forget your password, only your recovery key can restore access. Nobody else can.'),
        ],
      );

  Widget _accountGroup(SyncState st) => AppSettingsGroup(
        label: 'Account',
        children: [
          AppSettingsTile(
            icon: AppIcons.person,
            title: st.username ?? 'Signed in',
            subtitle: st.serverUrl ?? 'Connected',
            trailing: TextButton(
              onPressed: _confirmLogout,
              child: const Text('Log out'),
            ),
          ),
        ],
      );

  List<Widget> _mainGroups(SyncState st, bool busy) {
    final theme = Theme.of(context);
    _usage ??= _n.usage();
    return [
      _accountGroup(st),
      AppSettingsGroup(
        label: 'Cloud',
        children: [
          AppSettingsTile(
            icon: AppIcons.clock,
            title: 'Last synced',
            subtitle: st.lastSyncedAtMs != null
                ? _formatTimestamp(st.lastSyncedAtMs! / 1000)
                : 'Never',
          ),
          FutureBuilder(
            future: _usage,
            builder: (context, snap) {
              final u = snap.data;
              if (u == null || u.quota <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(AppTokens.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_bytes(u.used)} of ${_bytes(u.quota)} used',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppTokens.s2),
                    LinearProgressIndicator(
                      value: (u.used / u.quota).clamp(0.0, 1.0),
                      borderRadius: AppTokens.brPill,
                    ),
                  ],
                ),
              );
            },
          ),
          if (autoSyncAvailable(st.status))
            AppSettingsSwitch(
              icon: AppIcons.refresh,
              title: 'Auto sync',
              subtitle: 'Sync in the background while the app is open',
              value: st.autoSyncEnabled,
              onChanged: (v) => _n.setAutoSyncEnabled(v),
            ),
          AppSettingsTile(
            icon: AppIcons.syncAlt,
            title: 'Sync now',
            subtitle: st.lastError != null
                ? 'Last error: ${st.lastError}'
                : 'Merge this device with the cloud',
            onTap: busy
                ? null
                : () async {
                    await _n.sync();
                    if (mounted) setState(() => _usage = _n.usage());
                  },
          ),
        ],
      ),
      AppSettingsGroup(
        label: 'What gets synced',
        children: [
          for (final e in _categoryLabels.entries)
            AppSettingsSwitch(
              icon: e.value.$1,
              title: e.value.$2,
              subtitle: e.value.$3,
              value: st.categories.contains(e.key),
              onChanged: (v) {
                if (e.key == SyncCategory.settings) {
                  ref.read(settingsProvider.notifier).setSyncSettingsEnabled(v);
                }
                _n.setCategory(e.key, v);
              },
            ),
        ],
      ),
      AppSettingsGroup(
        label: 'Device Stats Attribution',
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTokens.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'This Device',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${st.localPlayCount} plays',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Other Devices',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${st.remotePlayCount} plays',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Library Stats',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${st.totalPlayCount} plays',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      _privacy(),
      AppSettingsGroup(
        label: 'Danger zone',
        children: [
          AppSettingsTile(
            icon: AppIcons.upload,
            title: 'Overwrite cloud with this device',
            subtitle: 'Replace all cloud data with what is on this device',
            onTap: busy ? null : _confirmOverwriteCloud,
          ),
          AppSettingsTile(
            icon: AppIcons.download,
            title: 'Replace this device with cloud',
            subtitle: 'Erase synced data on this device and use the cloud copy',
            onTap: busy ? null : _confirmReplaceLocal,
          ),
          AppSettingsTile(
            icon: AppIcons.security,
            title: 'Change password',
            onTap: busy ? null : _changePassword,
          ),
          AppSettingsTile(
            icon: AppIcons.security,
            title: 'New recovery key',
            subtitle: 'The old recovery key stops working',
            onTap: busy ? null : _newRecoveryKey,
          ),
          AppSettingsTile(
            icon: AppIcons.person,
            title: 'Change server',
            subtitle: 'Requires logging out first',
            onTap: busy ? null : _changeServer,
          ),
          AppSettingsTile(
            icon: AppIcons.person,
            title: 'Log out',
            onTap: _confirmLogout,
          ),
          AppSettingsTile(
            icon: AppIcons.deleteForever,
            title: 'Delete cloud account',
            subtitle: 'Removes cloud data permanently. Local data is kept',
            isDanger: true,
            onTap: busy ? null : _deleteAccount,
          ),
        ],
      ),
    ];
  }

  String _bytes(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _confirmOverwriteCloud() async {
    final r = await showDangerConfirm(
      context,
      title: 'Overwrite cloud',
      message:
          'All data in the cloud will be replaced by this device. Other devices will be asked to choose how to continue. This device keeps its data.',
      confirmLabel: 'Overwrite',
      checkboxLabel: 'I understand the cloud data will be lost',
    );
    if (r != null) unawaited(_n.overwriteCloud());
  }

  Future<void> _confirmReplaceLocal() async {
    final r = await showDangerConfirm(
      context,
      title: 'Replace this device',
      message:
          'Synced data on this device (stats, favorites, playlists, and so on) will be erased and replaced by the cloud copy. Music files are not touched.',
      confirmLabel: 'Replace',
      checkboxLabel: 'I understand local synced data will be lost',
    );
    if (r != null) unawaited(_n.setUpAsNewDevice());
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        title: 'Log out',
        message:
            'Sync stops on this device. Local and cloud data are both kept.',
        actions: [
          AppDialogAction(
              label: 'Cancel', onPressed: () => Navigator.pop(c, false)),
          AppDialogAction(
              label: 'Log out',
              isPrimary: true,
              onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok == true) await _n.logout();
  }

  Future<void> _changeServer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        title: 'Change server',
        message:
            'You will be logged out of the current server first. Local data is kept.',
        actions: [
          AppDialogAction(
              label: 'Cancel', onPressed: () => Navigator.pop(c, false)),
          AppDialogAction(
              label: 'Log out and change',
              isPrimary: true,
              onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok == true) await _n.logout();
  }

  Future<List<String>?> _fields(
      String title, List<String> labels, String confirm) {
    final ctrls = [for (final _ in labels) TextEditingController()];
    return showDialog<List<String>>(
      context: context,
      builder: (c) => AppDialog(
        title: title,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            TextField(
              controller: ctrls[i],
              obscureText: true,
              decoration: InputDecoration(labelText: labels[i]),
            ),
        ]),
        actions: [
          AppDialogAction(label: 'Cancel', onPressed: () => Navigator.pop(c)),
          AppDialogAction(
            label: confirm,
            isPrimary: true,
            onPressed: () => Navigator.pop(c, [for (final t in ctrls) t.text]),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final v = await _fields(
        'Change password', ['Current password', 'New password'], 'Change');
    if (v == null) return;
    try {
      await _n.changePassword(v[0], v[1]);
      if (mounted) appSnack(context, 'Password changed');
    } catch (e) {
      if (mounted) appSnack(context, '$e', tone: AppTone.danger);
    }
  }

  Future<void> _newRecoveryKey() async {
    final v = await _fields('New recovery key', ['Password'], 'Generate');
    if (v == null) return;
    try {
      final key = await _n.newRecoveryKey(v[0]);
      if (mounted) setState(() => _pendingRecoveryKey = key);
    } catch (e) {
      if (mounted) appSnack(context, '$e', tone: AppTone.danger);
    }
  }

  Future<void> _deleteAccount() async {
    final name = ref.read(syncProvider).username ?? '';
    final pw = await showDangerConfirm(
      context,
      title: 'Delete cloud account',
      message:
          'Your cloud account and all encrypted data on the server are deleted permanently. Data on this device is kept.',
      confirmLabel: 'Delete',
      countdownSeconds: 10,
      requireTypedText: name,
      requirePassword: true,
    );
    if (pw == null) return;
    try {
      await _n.deleteAccount(pw);
    } catch (e) {
      if (mounted) appSnack(context, '$e', tone: AppTone.danger);
    }
  }

  Widget _infoTile(AppIconData icon, String title, String subtitle) {
    return AppSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }

  String _formatTimestamp(double epoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch((epoch * 1000).toInt());
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
