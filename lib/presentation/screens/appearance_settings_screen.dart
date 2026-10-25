import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../providers/settings_provider.dart';
import '../../services/app_icon_service.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import 'app_icon_settings_screen.dart';
import 'beat_sync_calibration_screen.dart';
import '../tokens/app_icons.dart';

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const AppearanceSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final accent = AppTokens.accentOf(context, ref);
    final l10n = AppLocalizations.of(context);

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.appearanceGroupNowPlaying,
          icon: AppIcons.playCircle,
          children: [
            AppSettingsAnchor(
              id: 'appearance.visualizer',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.waves,
                  color: accent,
                  size: 40,
                ),
                title: l10n.appearanceVisualizerTitle,
                subtitle: l10n.appearanceVisualizerSubtitle,
                trailing: DropdownButton<VisualizerMode>(
                  value: settings.visualizerMode,
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  onChanged: (value) {
                    if (value == null) return;
                    notifier.setVisualizerMode(value);
                  },
                  items: [
                    DropdownMenuItem(
                      value: VisualizerMode.off,
                      child: Text(l10n.setupOff),
                    ),
                    DropdownMenuItem(
                      value: VisualizerMode.classic,
                      child: Text(l10n.appearanceVisualizerClassic),
                    ),
                    DropdownMenuItem(
                      value: VisualizerMode.synced,
                      child: Text(l10n.appearanceVisualizerSynced),
                    ),
                  ],
                ),
              ),
            ),
            AppSettingsAnchor(
              id: 'appearance.waveform',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.graphicEq,
                  color: accent,
                  size: 40,
                ),
                title: l10n.appearanceProgressBarTitle,
                subtitle: switch (settings.progressBarType) {
                  ProgressBarType.basic => l10n.appearanceProgressBasicSubtitle,
                  ProgressBarType.waveform =>
                    l10n.appearanceProgressWaveformSubtitle,
                  ProgressBarType.reactive =>
                    l10n.appearanceProgressReactiveSubtitle,
                },
                trailing: DropdownButton<ProgressBarType>(
                  value: settings.progressBarType,
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  onChanged: (value) {
                    if (value == null) return;
                    notifier.setProgressBarType(value);
                  },
                  items: [
                    DropdownMenuItem(
                      value: ProgressBarType.basic,
                      child: Text(l10n.appearanceProgressStandard),
                    ),
                    DropdownMenuItem(
                      value: ProgressBarType.waveform,
                      child: Text(l10n.appearanceProgressWaveform),
                    ),
                    DropdownMenuItem(
                      value: ProgressBarType.reactive,
                      child: Text(l10n.appearanceProgressSoundReactive),
                    ),
                  ],
                ),
              ),
            ),
            // Haptics have no effect on desktop hardware.
            if (!WideLayout.isWide(context) && settings.showWaveform)
              AppSettingsSwitch(
                icon: AppIcons.touchApp,
                searchId: 'appearance.waveform_haptics',
                title: l10n.appearanceHapticsTitle,
                subtitle: l10n.appearanceHapticsSubtitle,
                value: settings.waveformHapticsEnabled,
                onChanged: notifier.setWaveformHapticsEnabled,
              ),
            AppSettingsAnchor(
              id: 'appearance.cover_sizing',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.photoSize,
                  color: accent,
                  size: 40,
                ),
                title: l10n.appearanceCoverSizingTitle,
                subtitle: l10n.appearanceCoverSizingSubtitle,
                trailing: DropdownButton<PlayerCoverSizingMode>(
                  value: settings.coverSizingMode,
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  onChanged: (value) {
                    if (value == null) return;
                    notifier.setCoverSizingMode(value);
                  },
                  items: [
                    DropdownMenuItem(
                      value: PlayerCoverSizingMode.autoFit,
                      child: Text(l10n.appearanceCoverAutoFit),
                    ),
                    DropdownMenuItem(
                      value: PlayerCoverSizingMode.sourceAspect,
                      child: Text(l10n.appearanceCoverSourceSize),
                    ),
                  ],
                ),
              ),
            ),
            AppSettingsSwitch(
              icon: AppIcons.autoAwesome,
              searchId: 'appearance.full_bleed_design',
              title: l10n.appearanceImmersiveTitle,
              subtitle: l10n.appearanceImmersiveSubtitle,
              value: settings.fullBleedDesignEnabled,
              onChanged: notifier.setFullBleedDesignEnabled,
            ),
            AppSettingsSwitch(
              icon: AppIcons.swapHoriz,
              searchId: 'appearance.player_swipe',
              title: l10n.appearancePlayerSwipeTitle,
              subtitle: l10n.appearancePlayerSwipeSubtitle,
              value: settings.playerSwipeChangesPane,
              onChanged: notifier.setPlayerSwipeChangesPane,
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.appearanceGroupPlayerMotion,
          icon: AppIcons.graphicEq,
          children: [
            // The immersive player bleeds the artwork off three sides and
            // dissolves its lower third, so a scale has nowhere to go but under
            // that fade. The pulse is genuinely unavailable there, so the row
            // goes dead rather than sitting there pretending to work.
            AppSettingsSwitch(
              icon: AppIcons.album,
              searchId: 'appearance.beat_cover',
              title: l10n.appearanceBeatCoverTitle,
              subtitle: settings.fullBleedDesignEnabled
                  ? l10n.appearanceBeatCoverUnavailable
                  : l10n.appearanceBeatCoverSubtitle,
              value: settings.beatReactiveCoverEnabled,
              onChanged: settings.fullBleedDesignEnabled
                  ? null
                  : notifier.setBeatReactiveCoverEnabled,
            ),
            // Cover intensity — only visible when the cover toggle is on.
            if (settings.beatReactiveCoverEnabled &&
                !settings.fullBleedDesignEnabled)
              _MotionIntensityRow(
                id: 'appearance.cover_intensity',
                accent: accent,
                title: l10n.appearanceCoverIntensityTitle,
                subtitle: l10n.appearanceCoverIntensitySubtitle,
                intensity: settings.coverMotionIntensity,
                customIntensity: settings.coverMotionCustomIntensity,
                onIntensityChanged: notifier.setCoverMotionIntensity,
                onCustomChanged: notifier.setCoverMotionCustomIntensity,
              ),
            AppSettingsSwitch(
              icon: AppIcons.album,
              searchId: 'appearance.spin_artwork',
              title: l10n.appearanceSpinArtworkTitle,
              subtitle: l10n.appearanceSpinArtworkSubtitle,
              value: settings.spinArtworkWhilePlaying,
              onChanged: notifier.setSpinArtworkWhilePlaying,
            ),
            AppSettingsSwitch(
              icon: AppIcons.autoAwesome,
              searchId: 'appearance.beat_particles',
              title: l10n.appearanceParticlesTitle,
              subtitle: l10n.appearanceParticlesSubtitle,
              value: settings.beatReactiveParticlesEnabled,
              onChanged: notifier.setBeatReactiveParticlesEnabled,
            ),
            // Particle intensity — only visible when the particle toggle is on.
            if (settings.beatReactiveParticlesEnabled)
              _MotionIntensityRow(
                id: 'appearance.particle_intensity',
                accent: accent,
                title: l10n.appearanceParticleDensityTitle,
                subtitle: l10n.appearanceParticleDensitySubtitle,
                intensity: settings.particleMotionIntensity,
                customIntensity: settings.particleMotionCustomIntensity,
                onIntensityChanged: notifier.setParticleMotionIntensity,
                onCustomChanged: notifier.setParticleMotionCustomIntensity,
              ),
            // Output latency is a property of the listener's hardware, not the
            // app: Bluetooth typically runs 150-250ms behind wired. Without
            // this the pulse is permanently early on BT with no recourse.
            AppSettingsAnchor(
              id: 'appearance.beat_offset',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.syncAlt,
                  color: accent,
                  size: 40,
                ),
                title: l10n.appearanceBeatOffsetTitle,
                subtitle: settings.playerMotionLatencyMs == 0
                    ? l10n.appearanceBeatOffsetNone
                    : l10n.appearanceBeatOffsetBluetooth(
                        settings.playerMotionLatencyMs),
                trailing: SizedBox(
                  width: 160,
                  child: Slider(
                    value: settings.playerMotionLatencyMs.toDouble(),
                    min: SettingsNotifier.minMotionLatencyMs.toDouble(),
                    max: SettingsNotifier.maxMotionLatencyMs.toDouble(),
                    divisions: (SettingsNotifier.maxMotionLatencyMs -
                            SettingsNotifier.minMotionLatencyMs) ~/
                        10,
                    label: l10n.appearanceBeatOffsetValue(
                        settings.playerMotionLatencyMs),
                    onChanged: (value) =>
                        notifier.setPlayerMotionLatencyMs(value.round()),
                  ),
                ),
              ),
            ),
            AppSettingsTile(
              icon: AppIcons.syncAlt,
              searchId: 'appearance.beat_calibrate',
              title: l10n.appearanceCalibrateTitle,
              subtitle: l10n.appearanceCalibrateSubtitle,
              onTap: () => context.pushApp(const BeatSyncCalibrationScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.settingsLanguageTitle,
          icon: AppIcons.translate,
          children: [
            AppSettingsAnchor(
              id: 'appearance.language',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.translate,
                  color: accent,
                  size: 40,
                ),
                title: l10n.settingsLanguageTitle,
                trailing: DropdownButton<Locale?>(
                  value: ref.watch(localeProvider),
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  onChanged: (value) {
                    ref.read(localeProvider.notifier).setLocale(value);
                  },
                  items: [
                    DropdownMenuItem<Locale?>(
                      value: null,
                      child: Text(l10n.settingsLanguageSystem),
                    ),
                    for (final locale in selectableLocales)
                      DropdownMenuItem<Locale?>(
                        value: locale,
                        child: Text(languageDisplayName(locale)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (AppIconService.supported)
          AppSettingsGroup(
            label: l10n.appearanceAppIcon,
            icon: AppIcons.album,
            children: [
              AppSettingsTile(
                icon: AppIcons.album,
                searchId: 'appearance.app_icon',
                title: l10n.appearanceAppIcon,
                subtitle: settings.appIconStyle.label,
                onTap: () => context.pushApp(const AppIconSettingsScreen()),
              ),
            ],
          ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageAppearanceTitle),
      body: content,
    );
  }
}

String _customIntensityLabel(AppLocalizations l10n, double value) {
  if (value <= 0.125) return l10n.appearanceIntensityMin;
  if (value <= 0.375) return l10n.appearanceIntensitySubtle;
  if (value <= 0.625) return l10n.appearanceIntensityBalanced;
  if (value <= 0.875) return l10n.appearanceIntensityBold;
  return l10n.appearanceIntensityMax;
}

Widget _sliderLabel(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
    ),
  );
}

/// A single motion-intensity row: dropdown + optional custom slider.
class _MotionIntensityRow extends StatelessWidget {
  final String id;
  final Color accent;
  final String title;
  final String subtitle;
  final PlayerMotionIntensity intensity;
  final double customIntensity;
  final ValueChanged<PlayerMotionIntensity> onIntensityChanged;
  final ValueChanged<double> onCustomChanged;

  const _MotionIntensityRow({
    required this.id,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.intensity,
    required this.customIntensity,
    required this.onIntensityChanged,
    required this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        AppSettingsAnchor(
          id: id,
          child: AppListRow(
            dense: true,
            leading: AppRowIcon(
              icon: AppIcons.tune,
              color: accent,
              size: 40,
            ),
            title: title,
            subtitle: subtitle,
            trailing: DropdownButton<PlayerMotionIntensity>(
              value: intensity,
              underline: const SizedBox.shrink(),
              borderRadius: AppTokens.brMd,
              onChanged: (value) {
                if (value == null) return;
                onIntensityChanged(value);
              },
              items: [
                DropdownMenuItem(
                  value: PlayerMotionIntensity.subtle,
                  child: Text(l10n.appearanceIntensitySubtle),
                ),
                DropdownMenuItem(
                  value: PlayerMotionIntensity.balanced,
                  child: Text(l10n.appearanceIntensityBalanced),
                ),
                DropdownMenuItem(
                  value: PlayerMotionIntensity.bold,
                  child: Text(l10n.appearanceIntensityBold),
                ),
                DropdownMenuItem(
                  value: PlayerMotionIntensity.custom,
                  child: Text(l10n.appearanceIntensityCustom),
                ),
              ],
            ),
          ),
        ),
        if (intensity == PlayerMotionIntensity.custom)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTokens.s3 + 40 + AppTokens.s3,
              right: AppTokens.s3,
              bottom: AppTokens.s2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: accent,
                    thumbColor: accent,
                    inactiveTrackColor: accent.withValues(alpha: 0.2),
                    overlayColor: accent.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: customIntensity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 4,
                    label: _customIntensityLabel(l10n, customIntensity),
                    onChanged: onCustomChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      _sliderLabel(context, l10n.appearanceIntensityMin),
                      const Spacer(),
                      _sliderLabel(context, l10n.appearanceIntensitySubtle),
                      const Spacer(),
                      _sliderLabel(context, l10n.appearanceIntensityBalanced),
                      const Spacer(),
                      _sliderLabel(context, l10n.appearanceIntensityBold),
                      const Spacer(),
                      _sliderLabel(context, l10n.appearanceIntensityMax),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
