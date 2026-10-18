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
import '../../l10n/app_localizations.dart';

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

  Map<String, (AppIconData, String, String)> get _categoryLabels {
    final l = AppLocalizations.of(context);
    return {
      SyncCategory.playStats: (
        AppIcons.analytics,
        l.syncPlayStats,
        l.syncPlayStatsHint
      ),
      SyncCategory.favorites: (
        AppIcons.favorite,
        l.libraryFavorites,
        l.syncFavoritesHint
      ),
      SyncCategory.suggestless: (
        AppIcons.info,
        l.syncSuggestLess,
        l.syncSuggestLessHint
      ),
      SyncCategory.hidden: (
        AppIcons.folderOff,
        l.syncHiddenSongs,
        l.syncHiddenSongs
      ),
      SyncCategory.playlists: (
        AppIcons.playlist,
        l.playlistsTitle,
        l.syncPlaylistsHint
      ),
      SyncCategory.mergedSongs: (
        AppIcons.playlist,
        l.syncMergedSongs,
        l.syncMergedSongsHint
      ),
      SyncCategory.settings: (
        AppIcons.settings,
        l.syncAppSettings,
        l.syncAppSettingsHint
      ),
      SyncCategory.artistArt: (
        AppIcons.image,
        l.syncArtistArt,
        l.syncArtistArtHint
      ),
      SyncCategory.albumArt: (
        AppIcons.image,
        l.syncAlbumArt,
        l.syncAlbumArtHint
      ),
    };
  }

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
      appBar:
          AppTopBar(title: AppLocalizations.of(context).settingsPageSyncTitle),
      body: content,
    );
  }

  Widget _privacy() {
    final l = AppLocalizations.of(context);
    return AppSettingsGroup(
      label: l.syncPrivacy,
      children: [
        _infoTile(AppIcons.security, l.syncEncryptedTitle, l.syncEncryptedBody),
        _infoTile(AppIcons.info, l.syncRecoveryKeyTitle, l.syncRecoveryKeyBody),
      ],
    );
  }

  Widget _accountGroup(SyncState st) {
    final l = AppLocalizations.of(context);
    return AppSettingsGroup(
      label: l.syncAccount,
      children: [
        AppSettingsTile(
          icon: AppIcons.person,
          title: st.username ?? l.syncSignedIn,
          subtitle: st.serverUrl ?? l.syncConnected,
          trailing: TextButton(
            onPressed: _confirmLogout,
            child: Text(l.syncLogOut),
          ),
        ),
      ],
    );
  }

  List<Widget> _mainGroups(SyncState st, bool busy) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    _usage ??= _n.usage();
    return [
      _accountGroup(st),
      AppSettingsGroup(
        label: l.syncCloud,
        children: [
          AppSettingsTile(
            icon: AppIcons.clock,
            title: l.syncLastSynced,
            subtitle: st.lastSyncedAtMs != null
                ? _formatTimestamp(st.lastSyncedAtMs! / 1000)
                : l.syncNever,
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
                    Text(l.syncUsedOfQuota(_bytes(u.used), _bytes(u.quota)),
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
              title: l.syncAutoSync,
              subtitle: l.syncAutoSyncHint,
              value: st.autoSyncEnabled,
              onChanged: (v) => _n.setAutoSyncEnabled(v),
            ),
          AppSettingsTile(
            icon: AppIcons.syncAlt,
            title: l.syncNow,
            subtitle: st.lastError != null
                ? l.syncLastError(st.lastError!)
                : l.syncMergeDeviceHint,
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
        label: l.syncWhatGetsSynced,
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
        label: l.syncDeviceStatsAttribution,
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
                      l.syncThisDevice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      l.syncPlays(st.localPlayCount),
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
                      l.syncOtherDevices,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      l.syncPlays(st.remotePlayCount),
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
                      l.syncTotalLibraryStats,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      l.syncPlays(st.totalPlayCount),
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
        label: l.syncDangerZone,
        children: [
          AppSettingsTile(
            icon: AppIcons.upload,
            title: l.syncOverwriteCloudTile,
            subtitle: l.syncOverwriteCloudTileHint,
            onTap: busy ? null : _confirmOverwriteCloud,
          ),
          AppSettingsTile(
            icon: AppIcons.download,
            title: l.syncReplaceDeviceTile,
            subtitle: l.syncReplaceDeviceTileHint,
            onTap: busy ? null : _confirmReplaceLocal,
          ),
          AppSettingsTile(
            icon: AppIcons.security,
            title: l.syncChangePassword,
            onTap: busy ? null : _changePassword,
          ),
          AppSettingsTile(
            icon: AppIcons.security,
            title: l.syncNewRecoveryKey,
            subtitle: l.syncNewRecoveryKeyHint,
            onTap: busy ? null : _newRecoveryKey,
          ),
          AppSettingsTile(
            icon: AppIcons.person,
            title: l.syncChangeServer,
            subtitle: l.syncChangeServerHint,
            onTap: busy ? null : _changeServer,
          ),
          AppSettingsTile(
            icon: AppIcons.person,
            title: l.syncLogOut,
            onTap: _confirmLogout,
          ),
          AppSettingsTile(
            icon: AppIcons.deleteForever,
            title: l.syncDeleteCloudAccount,
            subtitle: l.syncDeleteCloudAccountHint,
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
    final l = AppLocalizations.of(context);
    final r = await showDangerConfirm(
      context,
      title: l.syncOverwriteCloud,
      message: l.syncOverwriteCloudBody,
      confirmLabel: l.syncOverwrite,
      checkboxLabel: l.syncOverwriteCloudCheckbox,
    );
    if (r != null) unawaited(_n.overwriteCloud());
  }

  Future<void> _confirmReplaceLocal() async {
    final l = AppLocalizations.of(context);
    final r = await showDangerConfirm(
      context,
      title: l.syncReplaceDevice,
      message: l.syncReplaceDeviceBody,
      confirmLabel: l.syncReplace,
      checkboxLabel: l.syncReplaceDeviceCheckbox,
    );
    if (r != null) unawaited(_n.setUpAsNewDevice());
  }

  Future<void> _confirmLogout() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        title: l.syncLogOut,
        message: l.syncLogOutBody,
        actions: [
          AppDialogAction(
              label: l.actionCancel, onPressed: () => Navigator.pop(c, false)),
          AppDialogAction(
              label: l.syncLogOut,
              isPrimary: true,
              onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok == true) await _n.logout();
  }

  Future<void> _changeServer() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AppDialog(
        title: l.syncChangeServer,
        message: l.syncChangeServerBody,
        actions: [
          AppDialogAction(
              label: l.actionCancel, onPressed: () => Navigator.pop(c, false)),
          AppDialogAction(
              label: l.syncLogOutAndChange,
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
          AppDialogAction(
              label: AppLocalizations.of(context).actionCancel,
              onPressed: () => Navigator.pop(c)),
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
    final l = AppLocalizations.of(context);
    final v = await _fields(l.syncChangePassword,
        [l.syncCurrentPassword, l.syncNewPassword], l.actionChange);
    if (v == null) return;
    try {
      await _n.changePassword(v[0], v[1]);
      if (mounted) appSnack(context, l.syncPasswordChanged);
    } catch (e) {
      if (mounted) appSnack(context, '$e', tone: AppTone.danger);
    }
  }

  Future<void> _newRecoveryKey() async {
    final l = AppLocalizations.of(context);
    final v =
        await _fields(l.syncNewRecoveryKey, [l.syncPassword], l.syncGenerate);
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
    final l = AppLocalizations.of(context);
    final pw = await showDangerConfirm(
      context,
      title: l.syncDeleteCloudAccount,
      message: l.syncDeleteCloudAccountBody,
      confirmLabel: l.actionDelete,
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

    final l = AppLocalizations.of(context);
    if (diff.inMinutes < 1) return l.syncJustNow;
    if (diff.inMinutes < 60) return l.syncMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.syncHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l.syncDaysAgo(diff.inDays);
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
