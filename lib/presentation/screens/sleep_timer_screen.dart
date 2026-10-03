import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/sleep_timer_service.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_section_header.dart';
import '../components/app_surface.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';

/// Arms and configures the sleep timer.
///
/// Split out of the drawer file so the navigation widget only navigates.
class SleepTimerScreen extends ConsumerStatefulWidget {
  const SleepTimerScreen({super.key});

  @override
  ConsumerState<SleepTimerScreen> createState() => _SleepTimerScreenState();
}

class _SleepTimerScreenState extends ConsumerState<SleepTimerScreen> {
  SleepTimerMode _mode = SleepTimerMode.playForTime;
  int _minutes = 30;
  int _tracks = 5;
  bool _letCurrentFinish = true;

  // Start from 5 minutes, go to 120 minutes in 5-min increments
  final List<int> _minuteOptions =
      List.generate(24, (i) => (i + 1) * 5); // 5-120
  // Start from 1 track, go to 40 tracks
  final List<int> _trackOptions = List.generate(40, (i) => i + 1); // 1-40

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accentOf(context, ref);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final currentSong = audioManager.currentSongNotifier.value;

    return Scaffold(
      appBar: const AppTopBar(title: 'Sleep Timer'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.s4,
          0,
          AppTokens.s4,
          AppTokens.scrollBottomInset,
        ),
        children: [
          const AppSectionHeader(
            label: 'Timer Mode',
            padding: EdgeInsets.fromLTRB(
              AppTokens.s3,
              AppTokens.s3,
              AppTokens.s3,
              AppTokens.s2,
            ),
          ),
          _buildModeSelector(accent),
          if (_mode == SleepTimerMode.playForTime ||
              _mode == SleepTimerMode.loopCurrent) ...[
            _buildStepperSection(
              label: 'Duration',
              valueLabel: '$_minutes min',
              accent: accent,
              options: _minuteOptions,
              selected: _minutes,
              suffix: 'min',
              width: 62,
              onSelected: (value) => setState(() => _minutes = value),
            ),
            const SizedBox(height: AppTokens.s4),
            _buildFinishToggle(),
          ],
          if (_mode == SleepTimerMode.stopAfterTracks)
            _buildStepperSection(
              label: 'Number of Tracks',
              valueLabel: '$_tracks tracks',
              accent: accent,
              options: _trackOptions,
              selected: _tracks,
              width: 54,
              onSelected: (value) => setState(() => _tracks = value),
            ),
          if (_mode == SleepTimerMode.stopAfterCurrent)
            _buildCurrentSongInfo(currentSong),
          const SizedBox(height: AppTokens.s6),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildModeSelector(Color accent) {
    const modes = [
      (
        SleepTimerMode.loopCurrent,
        AppIcons.repeatOne,
        'Loop Current Song',
        'Repeat the current song for a set time'
      ),
      (
        SleepTimerMode.playForTime,
        AppIcons.timer,
        'Play for Time',
        'Stop after a specified duration'
      ),
      (
        SleepTimerMode.stopAfterCurrent,
        AppIcons.stop,
        'Stop After Current',
        'Stop when the current song ends'
      ),
      (
        SleepTimerMode.stopAfterTracks,
        AppIcons.playlist,
        'Stop After Tracks',
        'Stop after playing X more songs'
      ),
    ];

    return AppSurfaceGroup(
      children: [
        for (final (modeValue, icon, title, subtitle) in modes)
          AppListRow(
            title: title,
            subtitle: subtitle,
            accent: accent,
            isActive: _mode == modeValue,
            leading: AppRowIcon(icon: icon, active: _mode == modeValue),
            onTap: () => setState(() => _mode = modeValue),
            trailing: _mode == modeValue
                ? AppIcon(AppIcons.checkCircle,
                    color: accent, size: AppTokens.iconSm)
                : null,
          ),
      ],
    );
  }

  /// Horizontal picker of pill options. Used by both the minutes and the
  /// tracks selector, which were previously two near-identical blocks.
  Widget _buildStepperSection({
    required String label,
    required String valueLabel,
    required Color accent,
    required List<int> options,
    required int selected,
    required double width,
    required ValueChanged<int> onSelected,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.s2,
            AppTokens.s2,
            AppTokens.s2,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTokens.sectionLabel(context),
                ),
              ),
              Text(
                valueLabel,
                style: AppTokens.meta(context).copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selected == option;

              return GestureDetector(
                onTap: () => onSelected(option),
                child: Container(
                  width: width,
                  margin: const EdgeInsets.only(right: AppTokens.s2),
                  decoration: BoxDecoration(
                    color: isSelected ? accent : AppTokens.surface(1),
                    borderRadius: AppTokens.brSm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$option',
                        style: AppTokens.stat(context).copyWith(
                          fontSize: 18,
                          color: isSelected
                              ? AppTokens.onAccent(accent)
                              : Colors.white,
                        ),
                      ),
                      if (suffix != null)
                        Text(
                          suffix,
                          style: AppTokens.meta(context).copyWith(
                            color: isSelected
                                ? AppTokens.onAccent(accent)
                                    .withValues(alpha: 0.7)
                                : AppTokens.fgTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSongInfo(Song? song) {
    if (song == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppTokens.s5),
        child: AppSurface(
          child: Row(
            children: [
              const AppIcon(AppIcons.error, color: AppTokens.danger, size: 20),
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: Text(
                  'No song is currently playing',
                  style: AppTokens.rowSubtitle(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.s5),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CURRENT SONG', style: AppTokens.sectionLabel(context)),
            const SizedBox(height: AppTokens.s2),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.rowTitle(context),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.rowSubtitle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishToggle() {
    return AppSurface(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s1),
      child: SwitchListTile(
        title: const Text('Let current song finish'),
        subtitle: Text(
          _letCurrentFinish
              ? 'Wait for the current song to end before stopping'
              : 'Stop immediately when timer expires',
        ),
        value: _letCurrentFinish,
        onChanged: (value) => setState(() => _letCurrentFinish = value),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _startTimer,
          icon: const AppIcon(AppIcons.play),
          label: const Text('Start Timer'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        if (SleepTimerService.instance.isActive) ...[
          const SizedBox(height: AppTokens.s3),
          FilledButton.icon(
            onPressed: () {
              SleepTimerService.instance.cancel();
              setState(() {});
              appSnack(context, 'Sleep timer cancelled');
            },
            icon: const AppIcon(AppIcons.stop),
            label: const Text('Cancel Active Timer'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.surface(2),
              foregroundColor: AppTokens.fgPrimary,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ],
    );
  }

  void _startTimer() {
    final audioManager = ref.read(audioPlayerManagerProvider);

    SleepTimerService.instance.start(
      mode: _mode,
      minutes: _minutes,
      tracks: _tracks,
      letCurrentFinish: _letCurrentFinish,
      audioManager: audioManager,
      onComplete: () {
        if (mounted) {
          appSnack(context, 'Sleep timer finished', tone: AppTone.success);
        }
      },
    );

    Navigator.pop(context);
    appSnack(context, _getTimerConfirmationMessage(), tone: AppTone.success);
  }

  String _getTimerConfirmationMessage() {
    switch (_mode) {
      case SleepTimerMode.loopCurrent:
        return 'Looping current song for $_minutes minutes';
      case SleepTimerMode.playForTime:
        return 'Music will stop in $_minutes minutes';
      case SleepTimerMode.stopAfterCurrent:
        return 'Will stop after current song ends';
      case SleepTimerMode.stopAfterTracks:
        return 'Will stop after $_tracks more songs';
    }
  }
}
