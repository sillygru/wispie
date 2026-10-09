import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/audio_player_manager.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_icon.dart';
import '../components/app_screen_header.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../widgets/beat_particle_field.dart';
import '../widgets/player_motion.dart';

/// Lets the listener line the particle field up with the song that is playing.
///
/// Uses the shared player and the same cached beat analysis as the player screen,
/// so any offset the user hears is output latency plus their own perception.
class BeatSyncCalibrationScreen extends ConsumerStatefulWidget {
  const BeatSyncCalibrationScreen({super.key});

  @override
  ConsumerState<BeatSyncCalibrationScreen> createState() =>
      _BeatSyncCalibrationScreenState();
}

class _BeatSyncCalibrationScreenState
    extends ConsumerState<BeatSyncCalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final AudioPlayerManager _manager;
  late final PlayerMotionController _motion;
  late int _offsetMs;
  String? _beatMapFilename;
  int _beatMapToken = 0;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _offsetMs = settings.playerMotionLatencyMs;
    _manager = ref.read(audioPlayerManagerProvider);
    _motion = PlayerMotionController(player: _manager.player)
      ..attach(this)
      ..particleIntensity = settings.particleMotionIntensity
      ..particleCustomIntensity = settings.particleMotionCustomIntensity
      ..latencyMs = _offsetMs;
    _manager.currentSongNotifier.addListener(_onSongChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onSongChanged();
    });
  }

  Future<void> _onSongChanged() async {
    if (!mounted) return;
    final Song? song = _manager.currentSongNotifier.value;
    if (song == null) {
      _beatMapFilename = null;
      _beatMapToken++;
      _motion.beatMap = null;
      setState(() => _analyzing = false);
      return;
    }
    if (song.filename == _beatMapFilename) return;
    _beatMapFilename = song.filename;
    final token = ++_beatMapToken;
    _motion.beatMap = null;
    setState(() => _analyzing = true);
    final service = ref.read(beatAnalysisServiceProvider);
    final map = await service.readCached(song.filename) ??
        await service.analyze(song.filename, song.url);
    if (!mounted || token != _beatMapToken) return;
    _motion.beatMap = map;
    setState(() => _analyzing = false);
  }

  void _setOffset(int value) {
    setState(() => _offsetMs = value);
    _motion.latencyMs = value;
    ref.read(settingsProvider.notifier).setPlayerMotionLatencyMs(value);
  }

  @override
  void dispose() {
    _manager.currentSongNotifier.removeListener(_onSongChanged);
    _motion.dispose();
    super.dispose();
  }

  String _statusText(Song? song) {
    if (song == null) return 'Play a song to calibrate.';
    if (_analyzing) return 'Analyzing beats...';
    if (!_motion.hasBeatMap) return 'No clear beat in this track.';
    return 'Drag until the particle bursts land on the clicks.';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accentOf(context, ref);
    final theme = Theme.of(context);

    return AmbientScaffold(
      appBar: const AppTopBar(title: 'Beat sync'),
      body: Stack(
        children: [
          Positioned.fill(
            child: BeatParticleField(controller: _motion, accent: accent),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.s4),
              child: Column(
                children: [
                  const Spacer(),
                  ValueListenableBuilder<Song?>(
                    valueListenable: _manager.currentSongNotifier,
                    builder: (context, song, _) => Column(
                      children: [
                        if (song != null)
                          Text(
                            song.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        const SizedBox(height: AppTokens.s2),
                        Text(
                          _statusText(song),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppTokens.s4),
                        ValueListenableBuilder<bool>(
                          valueListenable: _manager.playingNotifier,
                          builder: (context, playing, _) => IconButton.filled(
                            iconSize: AppTokens.iconLg,
                            tooltip: playing ? 'Pause' : 'Play',
                            onPressed:
                                song == null ? null : _manager.togglePlayPause,
                            icon: AppIcon(
                              playing ? AppIcons.pause : AppIcons.play,
                              size: AppTokens.iconLg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_offsetMs ms',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Slider(
                    value: _offsetMs.toDouble(),
                    min: SettingsNotifier.minMotionLatencyMs.toDouble(),
                    max: SettingsNotifier.maxMotionLatencyMs.toDouble(),
                    divisions: (SettingsNotifier.maxMotionLatencyMs -
                            SettingsNotifier.minMotionLatencyMs) ~/
                        10,
                    label: '$_offsetMs ms',
                    onChanged: (value) => _setOffset(value.round()),
                  ),
                  TextButton(
                    onPressed: _offsetMs == 0 ? null : () => _setOffset(0),
                    child: const Text('Reset to 0 ms'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
