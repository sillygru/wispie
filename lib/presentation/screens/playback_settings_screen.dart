import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../tokens/app_icons.dart';

class PlaybackSettingsScreen extends ConsumerStatefulWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const PlaybackSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  ConsumerState<PlaybackSettingsScreen> createState() =>
      _PlaybackSettingsScreenState();
}

class _PlaybackSettingsScreenState
    extends ConsumerState<PlaybackSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    // Gap and fade are mutually exclusive; whichever is non-zero disables the
    // other's sliders.
    final bool isGapMode = settings.delayDuration > 0;
    final bool isFadeMode =
        settings.fadeOutDuration > 0 || settings.fadeInDuration > 0;

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.playbackGroupTransitions,
          icon: AppIcons.swapHoriz,
          children: [
            AppSettingsSlider(
              icon: AppIcons.hourglass,
              searchId: 'playback.gap',
              title: isFadeMode
                  ? l10n.playbackGapOff
                  : l10n.settingsSearchGapTitle,
              valueLabel: l10n.playbackSecondsValue(
                  settings.delayDuration.toStringAsFixed(1)),
              value: settings.delayDuration,
              min: 0,
              max: 12,
              divisions: 24,
              onChanged: isFadeMode ? (_) {} : notifier.setDelayDuration,
            ),
            AppSettingsSlider(
              icon: AppIcons.volumeDown,
              searchId: 'playback.fade_out',
              title: isGapMode
                  ? l10n.playbackFadeOutOff
                  : l10n.settingsSearchFadeOutTitle,
              valueLabel: l10n.playbackSecondsValue(
                  settings.fadeOutDuration.toStringAsFixed(1)),
              value: settings.fadeOutDuration,
              min: 0,
              max: 12,
              divisions: 24,
              onChanged: isGapMode ? (_) {} : notifier.setFadeOutDuration,
            ),
            AppSettingsSlider(
              icon: AppIcons.volumeUp,
              searchId: 'playback.fade_in',
              title: isGapMode
                  ? l10n.playbackFadeInOff
                  : l10n.settingsSearchFadeInTitle,
              valueLabel: l10n.playbackSecondsValue(
                  settings.fadeInDuration.toStringAsFixed(1)),
              value: settings.fadeInDuration,
              min: 0,
              max: 12,
              divisions: 24,
              onChanged: isGapMode ? (_) {} : notifier.setFadeInDuration,
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.playbackGroupPlayPause,
          icon: AppIcons.playCircle,
          children: [
            AppSettingsSlider(
              icon: AppIcons.play,
              searchId: 'playback.fade_play',
              title: l10n.settingsSearchFadePlayTitle,
              valueLabel: _fadeLabel(l10n, settings.playFadeDuration),
              value: settings.playFadeDuration,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: notifier.setPlayFadeDuration,
            ),
            AppSettingsSlider(
              icon: AppIcons.pause,
              searchId: 'playback.fade_pause',
              title: l10n.settingsSearchFadePauseTitle,
              valueLabel: _fadeLabel(l10n, settings.pauseFadeDuration),
              value: settings.pauseFadeDuration,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: notifier.setPauseFadeDuration,
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.playbackGroupAudio,
          icon: AppIcons.playCircle,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.volumeOff,
              searchId: 'playback.auto_pause_mute',
              title: l10n.settingsSearchAutoPauseMuteTitle,
              subtitle: l10n.settingsSearchAutoPauseMuteSubtitle,
              value: settings.autoPauseOnVolumeZero,
              onChanged: notifier.setAutoPauseOnVolumeZero,
            ),
            AppSettingsSwitch(
              icon: AppIcons.volumeUp,
              searchId: 'playback.auto_resume_unmute',
              title: l10n.settingsSearchAutoResumeUnmuteTitle,
              subtitle: l10n.settingsSearchAutoResumeUnmuteSubtitle,
              value: settings.autoResumeOnVolumeRestore,
              onChanged: notifier.setAutoResumeOnVolumeRestore,
            ),
          ],
        ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPagePlaybackTitle),
      body: content,
    );
  }

  static String _fadeLabel(AppLocalizations l10n, double value) {
    if (value == 0) return l10n.setupOff;
    if (value >= 1.0) return l10n.playbackValueOneSecond;
    return l10n.playbackValueMilliseconds((value * 1000).round());
  }
}
